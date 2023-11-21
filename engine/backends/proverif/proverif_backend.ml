open Hax_engine
open Utils
open Base

include
  Backend.Make
    (struct
      open Features
      include Off
      include On.Macro
    end)
    (struct
      let backend = Diagnostics.Backend.ProVerif
    end)

module SubtypeToInputLanguage
    (FA : Features.T
    (*   with *)
    (*  type loop = Features.Off.loop *)
    (* and type for_loop = Features.Off.for_loop *)
    (* and type for_index_loop = Features.Off.for_index_loop *)
    (* and type state_passing_loop = Features.Off.state_passing_loop *)
    (* and type continue = Features.Off.continue *)
    (* and type break = Features.Off.break *)
    (* and type mutable_variable = Features.Off.mutable_variable *)
    (* and type mutable_reference = Features.Off.mutable_reference *)
    (* and type mutable_pointer = Features.Off.mutable_pointer *)
    (* and type reference = Features.Off.reference *)
    (* and type slice = Features.Off.slice *)
    (* and type raw_pointer = Features.Off.raw_pointer *)
    (* and type early_exit = Features.Off.early_exit *)
    (* and type question_mark = Features.Off.question_mark *)
    (* and type macro = Features.On.macro *)
    (* and type as_pattern = Features.Off.as_pattern *)
    (* and type nontrivial_lhs = Features.Off.nontrivial_lhs *)
    (* and type arbitrary_lhs = Features.Off.arbitrary_lhs *)
    (* and type lifetime = Features.Off.lifetime *)
    (* and type construct_base = Features.Off.construct_base *)
    (* and type monadic_action = Features.Off.monadic_action *)
    (* and type monadic_binding = Features.Off.monadic_binding *)
    (* and type block = Features.Off.block *)) =
struct
  module FB = InputLanguage

  include
    Feature_gate.Make (FA) (FB)
      (struct
        module A = FA
        module B = FB
        include Feature_gate.DefaultSubtype

        let continue = reject
        let loop = reject
        let for_loop = reject
        let for_index_loop = reject
        let state_passing_loop = reject
        let continue = reject
        let break = reject
        let mutable_variable = reject
        let mutable_reference = reject
        let mutable_pointer = reject
        let reference = reject
        let slice = reject
        let raw_pointer = reject
        let early_exit = reject
        let question_mark = reject
        let macro = reject
        let as_pattern = reject
        let nontrivial_lhs = reject
        let arbitrary_lhs = reject
        let lifetime = reject
        let construct_base = reject
        let monadic_action = reject
        let monadic_binding = reject
        let block = reject
        let metadata = Phase_reject.make_metadata (NotInBackendLang ProVerif)
      end)

  let metadata = Phase_utils.Metadata.make (Reject (NotInBackendLang backend))
end

module AST = Ast.Make (InputLanguage)
module BackendOptions = Backend.UnitBackendOptions
open Ast

module ProVerifNamePolicy = struct
  include Concrete_ident.DefaultNamePolicy

  [@@@ocamlformat "disable"]

  let index_field_transform index = "_" ^ index

  let reserved_words = Hash_set.of_list (module String) [
  "among"; "axiom"; "channel"; "choice"; "clauses"; "const"; "def"; "diff"; "do"; "elimtrue"; "else"; "equation"; "equivalence"; "event"; "expand"; "fail"; "for"; "forall"; "foreach"; "free"; "fun"; "get"; "if"; "implementation"; "in"; "inj-event"; "insert"; "lemma"; "let"; "letfun"; "letproba"; "new"; "noninterf"; "noselect"; "not"; "nounif"; "or"; "otherwise"; "out"; "param"; "phase"; "pred"; "proba"; "process"; "proof"; "public vars"; "putbegin"; "query"; "reduc"; "restriction"; "secret"; "select"; "set"; "suchthat"; "sync"; "table"; "then"; "type"; "weaksecret"; "yield"
  ]
end

module U = Ast_utils.MakeWithNamePolicy (InputLanguage) (ProVerifNamePolicy)
open AST

module Print = struct
  module GenericPrint =
    Generic_printer.Make (InputLanguage) (U.Concrete_ident_view)

  open Generic_printer_base.Make (InputLanguage)
  open PPrint

  let iblock f = group >> jump 2 0 >> terminate (break 0) >> f >> group

  class print =
    object (print)
      inherit GenericPrint.print as super
      method ty_bool = string "bool"
      method ty_int _ = string "bitstring"

      method! item' item =
        let fun_and_reduc name variants =
          let constructor = List.hd variants in
          match constructor with
          | None -> empty
          | Some constructor ->
              let field_prefix =
                if constructor.is_record then string ""
                else print#concrete_ident name
              in
              let fun_args = constructor.arguments in
              let fun_args_full =
                separate_map
                  (comma ^^ break 1)
                  (fun (x, y, _z) ->
                    field_prefix ^^ print#concrete_ident x ^^ string ": "
                    ^^ print#ty_at Param_typ y)
                  fun_args
              in
              let fun_args_names =
                separate_map
                  (comma ^^ break 1)
                  (fst3 >> fun x -> field_prefix ^^ print#concrete_ident x)
                  fun_args
              in
              let fun_args_types =
                separate_map
                  (comma ^^ break 1)
                  (snd3 >> print#ty_at Param_typ)
                  fun_args
              in
              let fun_line =
                string "fun" ^^ space ^^ print#concrete_ident name
                ^^ iblock parens fun_args_types
                ^^ string ": state."
              in
              let reduc_line =
                string "reduc forall " ^^ iblock Fn.id fun_args_full
                ^^ string ";"
              in
              let build_accessor (ident, ty, attr) =
                string "accessor_" ^^ print#concrete_ident name ^^ string "_"
                ^^ print#concrete_ident ident
                ^^ iblock parens
                     (print#concrete_ident name ^^ iblock parens fun_args_names)
                ^^ string " = " ^^ field_prefix ^^ print#concrete_ident ident
              in
              let reduc_lines =
                separate_map
                  (string "." ^^ hardline)
                  (fun arg ->
                    reduc_line ^^ nest 4 (hardline ^^ build_accessor arg))
                  fun_args
              in
              fun_line ^^ hardline ^^ reduc_lines ^^ string "."
        in
        match item with
        (* `fn`s are transformed into `letfun` process macros. *)
        | Fn { name; generics; body; params } ->
            let params_string =
              iblock parens (separate_map (comma ^^ break 1) print#param params)
            in
            string "letfun" ^^ space ^^ print#concrete_ident name
            ^^ params_string ^^ string " ="
            ^^ nest 4 (hardline ^^ print#expr_at Item_Fn_body body ^^ string ".")
        (* `struct` definitions are transformed into simple constructors and `reduc`s for accessing fields. *)
        | Type { name; generics; variants; is_struct } ->
            if is_struct then fun_and_reduc name variants else empty
        | _ -> empty
    end

  include Api (struct
    let new_print () = (new print :> print_object)
  end)
end

(* Insert a (empty, for now) top level process. *)
let insert_top_level contents = contents ^ "\n\nprocess\n    0\n"

(* Insert ProVerif code that will be necessary in any development.*)
let insert_preamble contents = "channel c.\ntype state.\n" ^ contents

let translate m (bo : BackendOptions.t) (items : AST.item list) :
    Types.file list =
  let contents, _ = Print.items items in
  let contents = contents |> insert_top_level |> insert_preamble in
  let file = Types.{ path = "output.pv"; contents } in
  [ file ]

open Phase_utils
module DepGraph = Dependencies.Make (InputLanguage)
module DepGraphR = Dependencies.Make (Features.Rust)

module TransformToInputLanguage =
  [%functor_application
  Phases.Reject.RawOrMutPointer(Features.Rust)
  |> Phases.And_mut_defsite
  |> Phases.Reconstruct_for_loops
  |> Phases.Direct_and_mut
  |> Phases.Reject.Arbitrary_lhs
  |> Phases.Drop_blocks
  |> Phases.Drop_references
  |> Phases.Trivialize_assign_lhs
  |> Phases.Reconstruct_question_marks
  |> Side_effect_utils.Hoist
  |> Phases.Local_mutation
  |> Phases.Reject.Continue
  |> Phases.Cf_into_monads
  |> Phases.Reject.EarlyExit
  |> Phases.Functionalize_loops
  |> Phases.Reject.As_pattern
  |> SubtypeToInputLanguage
  |> Identity
  ]
  [@ocamlformat "disable"]

let apply_phases (bo : BackendOptions.t) (items : Ast.Rust.item list) :
    AST.item list =
  TransformToInputLanguage.ditems items
