open Base
open Utils
open Ast

type visit_level = ExprLevel | TypeLevel

module TypedLocalIdent (Ty : sig
  type ty [@@deriving show, yojson]
end) =
struct
  module T = struct
    type t = Ast.LocalIdent.t * Ty.ty [@@deriving show, yojson]

    let sexp_of_t : t -> _ = fst >> Ast.LocalIdent.sexp_of_t
    let compare (a : t) (b : t) = [%compare: Ast.LocalIdent.t] (fst a) (fst b)
    let equal (a : t) (b : t) = [%eq: Ast.LocalIdent.t] (fst a) (fst b)
  end

  include Base.Comparator.Make (T)
  include T
end

module UniqueList (T : sig
  type t [@@deriving eq, show, yojson]
  type comparator_witness
end) : sig
  type t [@@deriving eq, show, yojson]

  val without : T.t -> t -> t
  val cons : T.t -> t -> t
  val to_list : t -> T.t list
  val from_set : (T.t, T.comparator_witness) Set.t -> t
  val empty : t
  val is_empty : t -> bool
  val singleton : T.t -> t
end = struct
  type t = T.t list [@@deriving eq, show, yojson]

  let without x = List.filter ~f:([%eq: T.t] x >> not)
  let cons hd tl = hd :: tl
  let to_list = Fn.id
  let from_set s = Set.to_list s
  let empty = []
  let is_empty = List.is_empty
  let singleton x = [ x ]
end

module Make (F : Features.T) = struct
  open Ast
  module AST = Ast.Make (F)
  include AST
  module TypedLocalIdent = TypedLocalIdent (AST)

  module Sets = struct
    module GlobalIdent = struct
      include Set.M (GlobalIdent)

      class ['s] monoid =
        object
          inherit ['s] VisitorsRuntime.monoid
          method private zero = Set.empty (module GlobalIdent)
          method private plus = Set.union
        end
    end

    module LocalIdent = struct
      include Set.M (LocalIdent)

      class ['s] monoid =
        object
          inherit ['s] VisitorsRuntime.monoid
          method private zero = Set.empty (module LocalIdent)
          method private plus = Set.union
        end
    end

    module TypedLocalIdent = struct
      include Set.M (TypedLocalIdent)

      class ['s] monoid =
        object
          inherit ['s] VisitorsRuntime.monoid
          method private zero = Set.empty (module TypedLocalIdent)
          method private plus = Set.union
        end
    end
  end

  module Mappers = struct
    let normalize_borrow_mut =
      object
        inherit [_] expr_map as super
        method visit_t () x = x
        method visit_mutability _ () m = m

        method! visit_expr s e =
          let rec expr e =
            match e.e with
            | App
                {
                  f = { e = GlobalVar (`Primitive Deref) };
                  args = [ { e = Borrow { e = sub } } ];
                } ->
                expr sub
            | _ -> super#visit_expr s e
          in
          expr e
      end

    let rename_global_idents (f : visit_level -> global_ident -> global_ident) =
      object
        inherit [_] item_map as super
        method visit_t (lvl : visit_level) x = x
        method visit_mutability _ (lvl : visit_level) m = m
        method! visit_global_ident (lvl : visit_level) ident = f lvl ident
        method! visit_ty _ t = super#visit_ty TypeLevel t
        (* method visit_GlobalVar (lvl : level) i = GlobalVar (f lvl i) *)
      end

    let rename_global_idents_item
        (f : visit_level -> global_ident -> global_ident) : item -> item =
      (rename_global_idents f)#visit_item ExprLevel
  end

  module Reducers = struct
    let collect_global_idents =
      object
        inherit [_] pat_reduce as super
        inherit [_] Sets.GlobalIdent.monoid as m
        method! visit_global_ident env x = Set.singleton (module GlobalIdent) x
      end

    let variables_of_pat (p : pat) : Sets.LocalIdent.t =
      (object
         inherit [_] pat_reduce as super
         inherit [_] Sets.LocalIdent.monoid as m

         method! visit_PBinding env _ _ var _ subpat =
           m#plus
             (Set.singleton (module LocalIdent) var)
             (Option.value_map subpat ~default:m#zero
                ~f:(fst >> super#visit_pat env))
      end)
        #visit_pat
        () p

    let without_pat_vars (mut_vars : Sets.TypedLocalIdent.t) (pat : pat) :
        Sets.TypedLocalIdent.t =
      let pat_vars = variables_of_pat pat in
      Set.filter mut_vars ~f:(fst >> Set.mem pat_vars >> not)

    let free_assigned_variables
        (fv_of_arbitrary_lhs :
          F.arbitrary_lhs -> expr -> Sets.TypedLocalIdent.t) =
      object
        inherit [_] expr_reduce as super
        inherit [_] Sets.TypedLocalIdent.monoid as m
        method visit_t _ _ = m#zero
        method visit_mutability f () _ = m#zero

        method visit_Assign m lhs e wit =
          let rec visit_lhs lhs =
            match lhs with
            | LhsLocalVar { var; _ } ->
                Set.singleton (module TypedLocalIdent) (var, e.typ)
            | LhsFieldAccessor { e; _ } -> visit_lhs e
            | LhsArrayAccessor { e; index } ->
                Set.union (super#visit_expr () index) (visit_lhs e)
            | LhsArbitraryExpr { witness; e } -> fv_of_arbitrary_lhs witness e
          in
          visit_lhs lhs

        method visit_Match m scrut arms =
          List.fold_left ~init:(super#visit_expr m scrut) ~f:Set.union
          @@ List.map ~f:(fun arm -> super#visit_arm m arm) arms

        method visit_Let m _monadic pat expr body =
          Set.union (super#visit_expr m expr)
          @@ without_pat_vars (super#visit_expr m body) pat

        method visit_arm' m { pat; body } =
          without_pat_vars (super#visit_expr m body) pat
      end

    class ['s] expr_list_monoid =
      object
        inherit ['s] VisitorsRuntime.monoid
        method private zero = []
        method private plus = List.append
      end

    let collect_break_payloads =
      object
        inherit [_] expr_reduce as super
        inherit [_] expr_list_monoid as m
        method visit_t _ _ = m#zero
        method visit_mutability f () _ = m#zero
        method visit_Break _ e _ _ = m#plus (super#visit_expr () e) [ e ]

        method visit_Loop _ _ _ _ = (* Do *NOT* visit sub nodes *)
                                    m#zero
      end
  end

  let unit_typ : ty = TApp { ident = `TupleType 0; args = [] }

  let unit_expr span : expr =
    { typ = unit_typ; span; e = GlobalVar (`TupleCons 0) }

  let rec remove_tuple1_pat (p : pat) : pat =
    match p.p with
    | PConstruct { name = `TupleType 1; args = [ { pat; _ } ] } ->
        remove_tuple1_pat pat
    | _ -> p

  let rec remove_tuple1 (t : ty) : ty =
    match t with
    | TApp { ident = `TupleType 1; args = [ GType t ] } -> remove_tuple1 t
    | _ -> t

  (* let rec remove_empty_tap *)

  let is_unit_typ : ty -> bool =
    remove_tuple1 >> [%matches? TApp { ident = `TupleType 0 }]

  let rec pat_is_expr (p : pat) (e : expr) =
    match (p.p, e.e) with
    | _, Construct { constructor = `TupleCons 1; fields = [ (_, e) ]; _ } ->
        pat_is_expr p e
    | PBinding { subpat = None; var = pv }, LocalVar ev ->
        [%eq: local_ident] pv ev
    | ( PConstruct { name = pn; args = pargs },
        Construct { constructor = en; fields = eargs; base = None } )
      when [%eq: global_ident] pn en -> (
        match List.zip pargs eargs with
        | Ok zip ->
            List.for_all
              ~f:(fun (x, y) ->
                [%eq: global_ident] x.field (fst y) && pat_is_expr x.pat (snd y))
              zip
        | Unequal_lengths -> false)
    | _ -> false

  let make_let (lhs : pat) (rhs : expr) (body : expr) =
    if pat_is_expr lhs body then rhs
    else { body with e = Let { monadic = None; lhs; rhs; body } }

  let make_var_pat (var : local_ident) (typ : ty) (span : span) : pat =
    {
      p = PBinding { mut = Immutable; mode = ByValue; var; typ; subpat = None };
      span;
      typ;
    }

  let let_of_binding ((var, rhs) : local_ident * expr) (body : expr) : expr =
    make_let (make_var_pat var rhs.typ rhs.span) rhs body

  let lets_of_bindings (bindings : (local_ident * expr) list) (body : expr) :
      expr =
    List.fold_right ~init:body ~f:let_of_binding bindings

  let make_tuple_typ (tuple : ty list) : ty =
    TApp
      {
        ident = `TupleType (List.length tuple);
        args = List.map ~f:(fun typ -> GType typ) tuple;
      }

  let make_wild_pat (typ : ty) (span : span) : pat = { p = PWild; span; typ }

  let make_seq (e1 : expr) (e2 : expr) : expr =
    make_let (make_wild_pat e1.typ e1.span) e1 e2

  let make_tuple_field_pat (len : int) (nth : int) (pat : pat) : field_pat =
    { field = `TupleField (nth + 1, len); pat }

  let make_tuple_pat' span (tuple : field_pat list) : pat =
    match tuple with
    | [ { pat } ] -> pat
    | _ ->
        let len = List.length tuple in
        {
          p = PConstruct { name = `TupleCons len; args = tuple; record = false };
          typ =
            make_tuple_typ @@ List.map ~f:(fun { pat = { typ } } -> typ) tuple;
          span;
        }

  let make_tuple_pat (pats : pat list) : pat =
    let len = List.length pats in
    if len == 0
    then make_tuple_pat' Dummy []
    else
      List.mapi ~f:(fun i pat -> { field = `TupleField (i, len); pat }) pats
      |> make_tuple_pat' (union_spans @@ List.map ~f:(fun p -> p.span) pats)

  let make_tuple_expr ~(span : span) (tuple : expr list) : expr =
    let len = List.length tuple in
    {
      e =
        Construct
          {
            constructor = `TupleCons len;
            constructs_record = false;
            fields =
              List.mapi ~f:(fun i x -> (`TupleField (i, len), x)) @@ tuple;
            base = None;
          };
      typ = make_tuple_typ @@ List.map ~f:(fun { typ } -> typ) tuple;
      span;
    }

  let rec collect_let_bindings' (e : expr) : (pat * expr * ty) list * expr =
    match e.e with
    | Let { monadic = _; lhs; rhs; body } ->
        let bindings, body = collect_let_bindings' body in
        ((lhs, rhs, e.typ) :: bindings, body)
    | _ -> ([], e)

  let rec collect_let_bindings (e : expr) : (pat * expr) list * expr =
    let bindings, body = collect_let_bindings' e in
    let types = List.map ~f:thd3 bindings in
    assert (
      match (List.drop_last types, types) with
      | Some init, _ :: tl ->
          List.zip_exn init tl |> List.for_all ~f:(uncurry [%eq: ty])
      | _ -> true);
    (* TODO: injecting the type of the lets in the body is bad.
       We should stay closer to Rust's inference.
       Here, we lose a bit of information.
    *)
    let body =
      { body with typ = List.hd types |> Option.value ~default:body.typ }
    in
    (List.map ~f:(fun (p, e, _) -> (p, e)) bindings, body)

  let rec map_body_of_nested_lets (f : expr -> expr) (e : expr) : expr =
    match e.e with
    | Let { monadic; lhs; rhs; body } ->
        {
          e with
          e = Let { monadic; lhs; rhs; body = map_body_of_nested_lets f body };
        }
    | _ -> f e

  let tuple_projector (tuple_typ : ty) (len : int) (nth : int)
      (type_at_nth : ty) : expr =
    {
      span = Dummy;
      typ = TArrow ([ tuple_typ ], type_at_nth);
      e = GlobalVar (`Projector (`TupleField (nth, len)));
    }

  let project_tuple (tuple : expr) (len : int) (nth : int) (type_at_nth : ty) :
      expr =
    {
      span = Dummy;
      typ = type_at_nth;
      e =
        App
          {
            f = tuple_projector tuple.typ len nth type_at_nth;
            args = [ tuple ];
          };
    }

  let group_items_by_namespace (items : item list) : item list Namespace.Map.t =
    let h = Hashtbl.create (module Namespace) in
    List.iter items ~f:(fun item ->
        let items =
          Hashtbl.find_or_add h item.parent_namespace ~default:(fun _ -> ref [])
        in
        items := !items @ [ item ]);
    Map.of_iteri_exn
      (module Namespace)
      ~iteri:(Hashtbl.map h ~f:( ! ) |> Hashtbl.iteri)

  module Std = struct
    module Ops = struct
      module ControlFlow = struct
        let ident =
          `Concrete
            { crate = "std"; path = Non_empty_list.[ "ops"; "ControlFlow" ] }

        let typ (break : ty) (continue : ty) : ty =
          TApp { ident; args = [ GType break; GType continue ] }

        let _make (name : string) (e : expr) (typ : ty) : expr =
          let constructor =
            `Concrete
              {
                crate = "std";
                path = Non_empty_list.("ops" :: "ControlFlow" :: [ name ]);
              }
          in
          {
            e with
            e =
              Construct
                {
                  constructor;
                  constructs_record = false;
                  base = None;
                  fields = [ (`TupleField (0, 1), e) ];
                };
            typ;
          }

        let break (e : expr) (continue_type : ty) : expr =
          _make "Break" e (typ e.typ continue_type)

        let continue (e : expr) (break_type : ty) : expr =
          _make "Continue" e (typ break_type e.typ)
      end
    end
  end
end
