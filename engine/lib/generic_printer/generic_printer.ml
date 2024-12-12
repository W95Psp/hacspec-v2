open! Prelude
open! Ast
open! PPrint
module LazyDoc = Generated_generic_printer_base.LazyDoc
open LazyDoc

module Annotation = struct
  type loc = { line : int; col : int } [@@deriving show, yojson, eq]
  type t = loc * span [@@deriving show, yojson, eq]

  let compare ((a, _) : t) ((b, _) : t) : int =
    let line = Int.compare a.line b.line in
    if Int.equal line 0 then Int.compare a.col b.col else line

  (** Converts a list of annotation and a string to a list of annotated string *)
  let split_with_string (s : string) (annots : t list) =
    let lines_position =
      String.to_list s
      |> List.filter_mapi ~f:(fun i ch ->
             match ch with '\n' -> Some i | _ -> None)
      |> List.to_array |> Array.get
    in
    let annots = List.sort ~compare annots in
    let init = ({ line = 0; col = 0 }, None) in
    let slices =
      List.folding_map
        ~f:(fun (start, start_span) (end_, end_span) ->
          let span = Option.value ~default:end_span start_span in
          ((end_, Some end_span), (span, start, end_)))
        ~init annots
    in
    List.map slices ~f:(fun (span, start, end_) ->
        let pos = lines_position start.line + start.col in
        let len = lines_position end_.line + end_.col - pos in
        (span, String.sub s ~pos ~len))

  let to_mapping ((loc, span) : t) : Sourcemaps.Source_maps.mapping option =
    let real_path (x : Types.file_name) =
      match x with
      | Real (LocalPath p) | Real (Remapped { local_path = Some p; _ }) ->
          Some p
      | _ -> None
    in
    let loc_to_loc ({ line; col } : loc) : Sourcemaps.Location.t =
      { line; col }
    in
    let to_loc ({ col; line } : Types.loc) : loc =
      { col = Int.of_string col; line = Int.of_string line - 1 }
    in
    let* span =
      Span.to_thir span
      |> List.find ~f:(fun (s : Types.span) ->
             real_path s.filename |> Option.is_some)
    in
    let* src_filename = real_path span.filename in
    let src_start = to_loc span.lo |> loc_to_loc in
    let src_end = to_loc span.hi |> loc_to_loc in
    let dst_start = loc_to_loc loc in
    Some
      Sourcemaps.Source_maps.
        {
          src = { start = src_start; end_ = Some src_end };
          gen = { start = dst_start; end_ = None };
          source = src_filename;
          name = None;
        }
end

module AnnotatedString = struct
  type t = string * Annotation.t list [@@deriving show, yojson, eq]

  let to_string = fst

  let to_spanned_strings ((s, annots) : t) : (Ast.span * string) list =
    Annotation.split_with_string s annots

  (** Lifts a string to an annotated list *)
  let pure (s : string) : t = (s, [])

  (** Concatenate two annotated strings *)
  let concat (x : t) (y : t) : t =
    let (xs, xl), (ys, yl) = (x, y) in
    let last_x =
      let lines = String.split ~on:'\n' xs in
      let last_line = List.last lines |> Option.value ~default:"" in
      let col, line = (String.length last_line, List.length lines) in
      Annotation.{ col; line }
    in
    let yl =
      let f ({ line; col } : Annotation.loc) : Annotation.loc =
        {
          line = line + last_x.line;
          col = (match col with 0 -> col + last_x.col | _ -> col);
        }
      in
      List.map ~f:(f *** Fn.id) yl
    in
    (xs ^ ys, xl @ yl)

  let to_sourcemap : t -> Types.source_map =
    snd >> List.filter_map ~f:Annotation.to_mapping >> Sourcemaps.Source_maps.mk
    >> fun ({
              mappings;
              sourceRoot;
              sources;
              sourcesContent;
              names;
              version;
              file;
            } :
             Sourcemaps.Source_maps.t) ->
    Types.
      { mappings; sourceRoot; sources; sourcesContent; names; version; file }
end

(** Helper class that brings imperative span *)
class span_helper : object
  method span_data : Annotation.t list
  (** Get the span annotation accumulated while printing *)

  method with_span : span:span -> (unit -> document) -> document
  (** Runs the printer `f` under a node of span `span` *)

  method current_span : span
  (** Get the current span *)
end =
  object (self)
    val mutable current_span = Span.default
    val mutable span_data : Annotation.t list = []
    method span_data = span_data
    method current_span = current_span

    method with_span ~(span : span) (f : unit -> document) : document =
      let prev_span = current_span in
      current_span <- span;
      let doc = f () |> self#spanned_doc |> custom in
      current_span <- prev_span;
      doc

    method private spanned_doc (doc : document) : custom =
      let span = current_span in
      object
        method requirement : requirement = requirement doc

        method pretty : output -> state -> int -> bool -> unit =
          fun o s i b ->
            span_data <- ({ line = s.line; col = s.column }, span) :: span_data;
            pretty o s i b doc

        method compact : output -> unit = fun o -> compact o doc
      end
  end

module Make (F : Features.T) = struct
  module AST = Ast.Make (F)
  open Ast.Make (F)
  module Gen = Generated_generic_printer_base.Make (F)

  type printer = (Annotation.t list, PPrint.document) Gen.object_type
  type finalized_printer = (unit, string * Annotation.t list) Gen.object_type

  let finalize (new_printer : unit -> printer) : finalized_printer =
    Gen.map (fun apply ->
        let printer = new_printer () in
        let doc = apply printer in
        let buf = Buffer.create 0 in
        PPrint.ToBuffer.pretty 1.0 80 buf doc;
        (Buffer.contents buf, printer#span_data))

  class virtual base =
    object (self)
      inherit Gen.base as super
      inherit span_helper
      val mutable current_namespace : (string * string list) option = None

      method private catch_exn (handle : string -> document)
          (f : unit -> document) : document =
        self#catch_exn'
          (fun context kind ->
            Diagnostics.pretty_print_context_kind context kind |> handle)
          f

      method private catch_exn'
          (handle : Diagnostics.Context.t -> Diagnostics.kind -> document)
          (f : unit -> document) : document =
        try f ()
        with Diagnostics.SpanFreeError.Exn (Data (context, kind)) ->
          handle context kind

      (** {2:specialize-expr Printer settings} *)

      method virtual printer_name : string
      (** Mark a path as unreachable *)

      val concrete_ident_view : (module Concrete_ident.VIEW_API) =
        (module Concrete_ident.DefaultViewAPI)
      (** The concrete ident view to be used *)

      (** {2:specialize-expr Utility functions} *)

      method assertion_failure : 'any. string -> 'any =
        fun details ->
          let span = Span.to_thir self#current_span in
          let kind = Types.AssertionFailure { details } in
          let ctx = Diagnostics.Context.GenericPrinter self#printer_name in
          Diagnostics.SpanFreeError.raise ~span ctx kind
      (** An assertion failed *)

      method unreachable : 'any. unit -> 'any =
        self#assertion_failure "Unreachable"
      (** Mark a path as unreachable *)

      method local_ident (id : local_ident) : document =
        let module View = (val concrete_ident_view) in
        View.local_ident
          (match String.chop_prefix ~prefix:"impl " id.name with
          | Some _ ->
              let name = "impl_" ^ Int.to_string ([%hash: string] id.name) in
              { id with name }
          | _ -> id)
        |> string
      (** {2:specialize-expr Printers for special types} *)

      method concrete_ident ~local (id : Concrete_ident.view) : document =
        string
          (if local then id.definition
           else
             String.concat ~sep:self#module_path_separator
               (id.crate :: (id.path @ [ id.definition ])))
      (** [concrete_ident ~local id] prints a name without path if
      [local] is true, otherwise it prints the full path, separated by
      `module_path_separator`. *)

      method quote (quote : quote) : document =
        List.map
          ~f:(function
            | `Verbatim code -> string code
            | `Expr e -> self#print_expr AstPosition_Quote e
            | `Pat p -> self#print_pat AstPosition_Quote p
            | `Typ p -> self#print_ty AstPosition_Quote p)
          quote.contents
        |> concat

      (** {2:specialize-expr Specialized printers for [expr]} *)

      method virtual expr'_App_constant
          : super:expr ->
            constant:concrete_ident lazy_doc ->
            generics:generic_value lazy_doc list ->
            document
      (** [expr'_App_constant ~super ~constant ~generics] prints the
      constant [e] with generics [generics]. [super] is the
      unspecialized [expr]. *)

      method virtual expr'_App_application
          : super:expr ->
            f:expr lazy_doc ->
            args:expr lazy_doc list ->
            generics:generic_value lazy_doc list ->
            document
      (** [expr'_App_application ~super ~f ~args ~generics] prints the
      function application [e<...generics>(...args)]. [super] is the
      unspecialized [expr]. *)

      method virtual expr'_App_tuple_projection
          : super:expr -> size:int -> nth:int -> e:expr lazy_doc -> document
      (** [expr'_App_tuple_projection ~super ~size ~nth ~e] prints
      the projection of the [nth] component of the tuple [e] of
      size [size]. [super] is the unspecialized [expr]. *)

      method virtual expr'_App_field_projection
          : super:expr ->
            field:concrete_ident lazy_doc ->
            e:expr lazy_doc ->
            document
      (** [expr'_App_field_projection ~super ~field ~e] prints the
      projection of the field [field] in the expression [e]. [super]
      is the unspecialized [expr]. *)

      method virtual expr'_Construct_inductive
          : super:expr ->
            constructor:concrete_ident lazy_doc ->
            is_record:bool ->
            is_struct:bool ->
            fields:(global_ident lazy_doc * expr lazy_doc) list ->
            base:(expr lazy_doc * F.construct_base) lazy_doc option ->
            document
      (** [expr'_Construct_inductive ~super ~is_record ~is_struct
      ~constructor ~base ~fields] prints the construction of an
      inductive with base [base] and fields [fields]. [super] is the
      unspecialized [expr]. TODO doc is_record is_struct *)

      method virtual expr'_Construct_tuple
          : super:expr -> components:expr lazy_doc list -> document

      method virtual expr'_GlobalVar_concrete
          : super:expr -> concrete_ident lazy_doc -> document

      method virtual expr'_GlobalVar_primitive
          : super:expr -> primitive_ident -> document

      (** {2:specialize-pat Specialized printers for [pat]} *)

      method virtual pat'_PConstruct_inductive
          : super:pat ->
            constructor:concrete_ident lazy_doc ->
            is_record:bool ->
            is_struct:bool ->
            fields:(global_ident lazy_doc * pat lazy_doc) list ->
            document

      method virtual pat'_PConstruct_tuple
          : super:pat -> components:pat lazy_doc list -> document

      (** {2:specialize-lhs Specialized printers for [lhs]} *)

      method virtual lhs_LhsFieldAccessor_field
          : e:lhs lazy_doc ->
            typ:ty lazy_doc ->
            field:concrete_ident lazy_doc ->
            witness:F.nontrivial_lhs ->
            document

      method virtual lhs_LhsFieldAccessor_tuple
          : e:lhs lazy_doc ->
            typ:ty lazy_doc ->
            nth:int ->
            size:int ->
            witness:F.nontrivial_lhs ->
            document

      (** {2:specialize-ty Specialized printers for [ty]} *)

      method virtual ty_TApp_tuple : types:ty list -> document
      (** [ty_TApp_tuple ~types] prints a tuple type with
      compounds types [types]. *)

      method virtual ty_TApp_application
          : typ:concrete_ident lazy_doc ->
            generics:generic_value lazy_doc list ->
            document
      (** [ty_TApp_application ~typ ~generics] prints the type
      [typ<...generics>]. *)

      (** {2:specialize-ty Specialized printers for [item]} *)

      method virtual item'_Type_struct
          : super:item ->
            name:concrete_ident lazy_doc ->
            generics:generics lazy_doc ->
            tuple_struct:bool ->
            arguments:
              (concrete_ident lazy_doc * ty lazy_doc * attr list lazy_doc) list ->
            document
      (** [item'_Type_struct ~super ~name ~generics ~tuple_struct ~arguments] prints the struct definition [struct name<generics> arguments]. `tuple_struct` says whether we are dealing with a tuple struct
            (e.g. [struct Foo(T1, T2)]) or a named struct
            (e.g. [struct Foo {field: T1, other: T2}])? *)

      method virtual item'_Type_enum
          : super:item ->
            name:concrete_ident lazy_doc ->
            generics:generics lazy_doc ->
            variants:variant lazy_doc list ->
            document
      (** [item'_Type_enum ~super ~name ~generics ~variants] prints
      the enum type [enum name<generics> { ... }]. *)

      method virtual item'_Enum_Variant
          : name:concrete_ident lazy_doc ->
            arguments:
              (concrete_ident lazy_doc * ty lazy_doc * attrs lazy_doc) list ->
            is_record:bool ->
            attrs:attrs lazy_doc ->
            document
      (** [item'_Enum_Variant] prints a variant of an enum. *)

      (** {2:common-nodes Printers for common nodes} *)

      method virtual common_array : document list -> document
      (** [common_array values] is a default for printing array-like nodes: array patterns, array expressions. *)

      (** {2:defaults Default printers} **)

      method module_path_separator = "::"
      (** [module_path_separator] is the default separator for
      paths. `::` by default *)

      method pat'_PArray ~super:_ ~args =
        List.map ~f:(fun arg -> arg#p) args |> self#common_array

      method expr'_Array ~super:_ args =
        List.map ~f:(fun arg -> arg#p) args |> self#common_array

      method pat'_POr ~super:_ ~subpats =
        List.map ~f:(fun subpat -> subpat#p) subpats
        |> separate (break 1 ^^ char '|' ^^ space)

      (**/**)
      (* This section is about defining or overriding
         `_do_not_override_` methods. This is internal logic, whence this
         is excluded from documentation (with the nice and user friendly
         `(**/**)` ocamldoc syntax) *)

      method _do_not_override_lhs_LhsFieldAccessor ~e ~typ ~field ~witness =
        let field =
          match field with
          | `Projector field -> field
          | _ ->
              self#assertion_failure
              @@ "LhsFieldAccessor: field not a [`Projector] "
        in
        match field with
        | `TupleField (nth, size) ->
            self#lhs_LhsFieldAccessor_tuple ~e ~typ ~nth ~size ~witness
        | `Concrete field ->
            let field : concrete_ident lazy_doc =
              self#_do_not_override_lazy_of_concrete_ident
                AstPos_lhs_LhsFieldAccessor_field field
            in
            self#lhs_LhsFieldAccessor_field ~e ~typ ~field ~witness

      method _do_not_override_expr'_App ~super ~f ~args ~generic_args
          ~bounds_impls ~trait =
        let _ = (super, f, args, generic_args, bounds_impls, trait) in
        match f#v with
        | { e = GlobalVar i; _ } -> (
            let expect_one_arg where =
              match args with
              | [ arg ] -> arg
              | _ -> self#assertion_failure @@ "Expected one arg at " ^ where
            in
            match i with
            | `Concrete _ | `Primitive _ -> (
                match (args, i) with
                | [], `Concrete i ->
                    let constant =
                      self#_do_not_override_lazy_of_concrete_ident
                        AstPos_expr'_App_f i
                    in
                    self#expr'_App_constant ~super ~constant
                      ~generics:generic_args
                | [], _ -> self#assertion_failure "Primitive app of arity 0"
                | _ ->
                    self#expr'_App_application ~super ~f ~args
                      ~generics:generic_args)
            | `TupleType _ | `TupleCons _ | `TupleField _ ->
                self#assertion_failure "App: unexpected tuple"
            | `Projector (`TupleField (nth, size)) ->
                let e = expect_one_arg "projector tuple field" in
                self#expr'_App_tuple_projection ~super ~size ~nth ~e
            | `Projector (`Concrete field) ->
                let e = expect_one_arg "projector concrete" in
                let field =
                  self#_do_not_override_lazy_of_concrete_ident
                    AstPos_expr'_App_f field
                in
                self#expr'_App_field_projection ~super ~field ~e)
        | _ -> self#assertion_failure "Primitive app of arity 0"

      method _do_not_override_expr'_Construct ~super ~constructor ~is_record
          ~is_struct ~fields ~base =
        match constructor with
        | `Concrete constructor ->
            let constructor =
              self#_do_not_override_lazy_of_concrete_ident
                AstPos_expr'_Construct_constructor constructor
            in
            let fields =
              List.map
                ~f:(fun field ->
                  let name, expr = field#v in
                  ( self#_do_not_override_lazy_of_global_ident
                      Generated_generic_printer_base
                      .AstPos_pat'_PConstruct_constructor name,
                    expr ))
                fields
            in
            self#expr'_Construct_inductive ~super ~constructor ~is_record
              ~is_struct ~fields ~base
        | `TupleCons _ ->
            let components = List.map ~f:(fun field -> snd field#v) fields in
            self#expr'_Construct_tuple ~super ~components
        | `Primitive _ | `TupleType _ | `TupleField _ | `Projector _ ->
            self#assertion_failure "Construct unexpected constructors"

      method _do_not_override_expr'_GlobalVar ~super global_ident =
        match global_ident with
        | `Concrete concrete ->
            let concrete =
              self#_do_not_override_lazy_of_concrete_ident
                AstPos_expr'_GlobalVar_x0 concrete
            in
            self#expr'_GlobalVar_concrete ~super concrete
        | `Primitive primitive ->
            self#expr'_GlobalVar_primitive ~super primitive
        | `TupleCons 0 ->
            self#_do_not_override_expr'_Construct ~super
              ~constructor:global_ident ~is_record:false ~is_struct:false
              ~fields:[] ~base:None
        | _ ->
            self#assertion_failure
            @@ "GlobalVar: expected a concrete or primitive global ident, got:"
            ^ [%show: global_ident] global_ident

      method _do_not_override_pat'_PConstruct ~super ~constructor ~is_record
          ~is_struct ~fields =
        match constructor with
        | `Concrete constructor ->
            let constructor =
              self#_do_not_override_lazy_of_concrete_ident
                AstPos_pat'_PConstruct_constructor constructor
            in
            let fields =
              List.map
                ~f:(fun field ->
                  let { field; pat } = field#v in
                  let field =
                    self#_do_not_override_lazy_of_global_ident
                      Generated_generic_printer_base
                      .AstPos_pat'_PConstruct_fields field
                  in
                  let pat =
                    self#_do_not_override_lazy_of_pat
                      Generated_generic_printer_base
                      .AstPos_pat'_PConstruct_fields pat
                  in
                  (field, pat))
                fields
            in
            self#pat'_PConstruct_inductive ~super ~constructor ~is_record
              ~is_struct ~fields
        | `TupleCons _ ->
            let components =
              List.map
                ~f:(fun field ->
                  self#_do_not_override_lazy_of_pat AstPos_field_pat__pat
                    field#v.pat)
                fields
            in
            self#pat'_PConstruct_tuple ~super ~components
        | `Primitive _ | `TupleType _ | `TupleField _ | `Projector _ ->
            self#assertion_failure "Construct unexpected constructors"

      method _do_not_override_ty_TApp ~ident ~args =
        match ident with
        | `Concrete ident ->
            let typ =
              self#_do_not_override_lazy_of_concrete_ident AstPos_ty_TApp_args
                ident
            in
            self#ty_TApp_application ~typ ~generics:args |> group
        | `Primitive _ | `TupleCons _ | `TupleField _ | `Projector _ ->
            self#assertion_failure "TApp not concrete"
        | `TupleType size ->
            let types =
              List.filter_map
                ~f:(fun garg ->
                  match garg#v with GType t -> Some t | _ -> None)
                args
            in
            if [%equal: int] (List.length args) size |> not then
              self#assertion_failure "malformed [ty.TApp] tuple";
            self#ty_TApp_tuple ~types

      method _do_not_override_item'_Type ~super ~name ~generics ~variants
          ~is_struct =
        let generics, _, _ = generics#v in
        if is_struct then
          match variants with
          | [ variant ] ->
              let variant_arguments =
                List.map
                  ~f:(fun (ident, typ, attrs) ->
                    ( self#_do_not_override_lazy_of_concrete_ident
                        AstPos_variant__arguments ident,
                      self#_do_not_override_lazy_of_ty AstPos_variant__arguments
                        typ,
                      self#_do_not_override_lazy_of_attrs AstPos_variant__attrs
                        attrs ))
                  variant#v.arguments
              in
              self#item'_Type_struct ~super ~name ~generics
                ~tuple_struct:(not variant#v.is_record)
                ~arguments:variant_arguments
          | _ -> self#unreachable ()
        else self#item'_Type_enum ~super ~name ~generics ~variants

      method _do_not_override_variant
          : name:concrete_ident lazy_doc ->
            arguments:
              (concrete_ident lazy_doc * ty lazy_doc * attrs lazy_doc) list ->
            is_record:bool ->
            attrs:attrs lazy_doc ->
            document =
        self#item'_Enum_Variant

      method _do_not_override_lazy_of_local_ident ast_position
          (id : local_ident) =
        lazy_doc (fun (id : local_ident) -> self#local_ident id) ast_position id

      method _do_not_override_lazy_of_concrete_ident ast_position
          (id : concrete_ident) : concrete_ident lazy_doc =
        lazy_doc
          (fun (id : concrete_ident) ->
            let module View = (val concrete_ident_view) in
            let id = View.to_view id in
            let ns_crate, ns_path =
              Option.value ~default:("", []) current_namespace
            in
            let local =
              String.(ns_crate = id.crate) && [%eq: string list] ns_path id.path
            in
            self#concrete_ident ~local id)
          ast_position id

      method _do_not_override_lazy_of_global_ident ast_position
          (id : global_ident) : global_ident lazy_doc =
        lazy_doc
          (fun (id : global_ident) ->
            match id with
            | `Concrete cid | `Projector (`Concrete cid) ->
                (self#_do_not_override_lazy_of_concrete_ident ast_position cid)
                  #p
            | _ ->
                self#assertion_failure
                  ("_do_not_override_lazy_of_global_ident: expected [`Concrete \
                    _] got ["
                  ^ [%show: global_ident] id
                  ^ "]"))
          ast_position id

      method _do_not_override_lazy_of_quote ast_position (value : quote)
          : quote lazy_doc =
        lazy_doc (fun (value : quote) -> self#quote value) ast_position value

      method! _do_not_override_lazy_of_item ast_position (value : item)
          : item lazy_doc =
        let module View = (val concrete_ident_view) in
        current_namespace <- View.to_namespace value.ident |> Option.some;
        super#_do_not_override_lazy_of_item ast_position value

      method _do_not_override_lazy_of_generics ast_position (value : generics)
          : (generics lazy_doc
            * generic_param lazy_doc list
            * generic_constraint lazy_doc list)
            lazy_doc =
        let params =
          List.map
            ~f:(fun x ->
              self#_do_not_override_lazy_of_generic_param
                AstPos_generics__params x)
            value.params
        in
        let constraints =
          List.map
            ~f:(fun x ->
              self#_do_not_override_lazy_of_generic_constraint
                AstPos_generics__constraints x)
            value.constraints
        in
        lazy_doc
          (fun (lazy_doc, _, _) -> lazy_doc#p)
          ast_position
          ( lazy_doc
              (fun (value : generics) ->
                self#wrap_generics ast_position value
                  (self#generics ~params ~constraints))
              ast_position value,
            params,
            constraints )

      (**/**)
    end
end
