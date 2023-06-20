open Base
open Utils
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Imported = struct
  type def_id = { krate : string; path : disambiguated_def_path_item list }

  and disambiguated_def_path_item = {
    data : def_path_item;
    disambiguator : int;
  }

  and def_path_item =
    | CrateRoot
    | Impl
    | ForeignMod
    | Use
    | GlobalAsm
    | ClosureExpr
    | Ctor
    | AnonConst
    | ImplTrait
    | ImplTraitAssocTy
    | TypeNs of string
    | ValueNs of string
    | MacroNs of string
    | LifetimeNs of string
  [@@deriving show, yojson, compare, sexp, eq, hash]

  let of_def_path_item : Types.def_path_item -> def_path_item = function
    | CrateRoot -> CrateRoot
    | Impl -> Impl
    | ForeignMod -> ForeignMod
    | Use -> Use
    | GlobalAsm -> GlobalAsm
    | ClosureExpr -> ClosureExpr
    | Ctor -> Ctor
    | AnonConst -> AnonConst
    | ImplTrait -> ImplTrait
    | ImplTraitAssocTy -> ImplTraitAssocTy
    | TypeNs s -> TypeNs s
    | ValueNs s -> ValueNs s
    | MacroNs s -> MacroNs s
    | LifetimeNs s -> LifetimeNs s

  let of_disambiguated_def_path_item :
      Types.disambiguated_def_path_item -> disambiguated_def_path_item =
   fun Types.{ data; disambiguator } ->
    { data = of_def_path_item data; disambiguator }

  let of_def_id Types.{ krate; path } =
    { krate; path = List.map ~f:of_disambiguated_def_path_item path }

  let parent { krate; path } = { krate; path = List.drop_last_exn path }

  let drop_ctor { krate; path } =
    {
      krate;
      path =
        (match (List.drop_last path, List.last path) with
        | Some path, Some { data = Ctor; _ } -> path
        | _ -> path);
    }
end

module Kind = struct
  type t =
    | Type
    | Value
    | Lifetime
    | Constructor of { is_struct : bool }
    | Field
    | Macro
    | Trait
    | Impl
  [@@deriving show, yojson, compare, sexp, eq, hash]

  let of_def_path_item : Imported.def_path_item -> t option = function
    | TypeNs _ -> Some Type
    | ValueNs _ -> Some Value
    | LifetimeNs _ -> Some Lifetime
    | _ -> None
end

type t = { def_id : Imported.def_id; kind : Kind.t }
[@@deriving show, yojson, sexp]

(* [kind] is really a metadata, it is not relevant, `def_id`s are unique *)
let equal x y = [%equal: Imported.def_id] x.def_id y.def_id
let compare x y = [%compare: Imported.def_id] x.def_id y.def_id
let of_def_id kind def_id = { def_id = Imported.of_def_id def_id; kind }
let hash x = [%hash: Imported.def_id] x.def_id
let hash_fold_t s x = Imported.hash_fold_def_id s x.def_id

module View = struct
  module T = struct
    type view = { crate : string; path : string list; definition : string }
  end

  include T

  module Utils = struct
    let string_of_def_path_item : Imported.def_path_item -> string option =
      function
      | TypeNs s | ValueNs s | MacroNs s | LifetimeNs s -> Some s
      | Impl -> Some "impl"
      | AnonConst -> Some "anon_const"
      | _ -> None

    let string_of_disambiguated_def_path_item
        (x : Imported.disambiguated_def_path_item) : string option =
      let n = x.disambiguator in
      string_of_def_path_item x.data
      |> Option.map ~f:(fun base ->
             match n with
             | 0 -> (
                 match String.rsplit2 ~on:'_' base with
                 | Some (_, "") -> base ^ "_"
                 | Some (_, r) when Option.is_some @@ Caml.int_of_string_opt r
                   ->
                     base ^ "_" (* potentially conflicting name, adding a `_` *)
                 | _ -> base)
             | _ -> base ^ "_" ^ Int.to_string n)
  end

  open Utils

  let to_view (def_id : Imported.def_id) : view =
    let path, definition =
      List.filter_map ~f:string_of_disambiguated_def_path_item def_id.path
      |> last_init |> Option.value_exn
    in
    let fake_path, real_path =
      (* Detects paths of nested items *)
      List.rev def_id.path |> List.tl_exn
      |> List.split_while ~f:(fun (x : Imported.disambiguated_def_path_item) ->
             [%matches? Imported.ValueNs _ | Imported.Impl] x.data)
      |> Fn.id *** List.rev
      |> List.filter_map ~f:string_of_disambiguated_def_path_item
         *** List.filter_map ~f:string_of_disambiguated_def_path_item
    in
    let sep = "_under_" in
    if List.is_empty fake_path then
      let definition =
        String.substr_replace_all ~pattern:sep ~with_:(sep ^ "_") definition
      in
      { crate = def_id.krate; path; definition }
    else
      let definition = String.concat ~sep (definition :: fake_path) in
      { crate = def_id.krate; path = real_path; definition }

  let to_definition_name x = (to_view x).definition
end

let show x =
  View.to_view x.def_id
  |> (fun View.{ crate; path; definition } -> crate :: (path @ [ definition ]))
  |> String.concat ~sep:"::"

let pp fmt = show >> Caml.Format.pp_print_string fmt

type name = Concrete_ident_generated.name

let of_name k = Concrete_ident_generated.def_id_of >> of_def_id k

let eq_name name id =
  let of_name = Concrete_ident_generated.def_id_of name |> Imported.of_def_id in
  [%equal: Imported.def_id] of_name id.def_id

include View.T

let rename_definition (path : string list) (name : string) (kind : Kind.t)
    type_name =
  (* let path, name = *)
  (*   match kind with *)
  (*   | Constructor { is_struct = false } -> *)
  (*       let path, type_name = (List.drop_last_exn path, List.last_exn path) in *)
  (*       (path, type_name ^ "_" ^ name) *)
  (*   | _ -> (path, name) *)
  (* in *)
  let prefixes = [ "t"; "C"; "v"; "f" ] in
  let escape s =
    match String.lsplit2 ~on:'_' s with
    | Some (prefix, leftover) when List.mem ~equal:String.equal prefixes prefix
      ->
        prefix ^ "__" ^ leftover
    | _ -> s
  in
  match kind with
  | Type | Trait -> "t_" ^ name
  | Value | Impl -> if start_uppercase name then "v_" ^ name else escape name
  | Constructor _ -> if start_lowercase name then "C_" ^ name else escape name
  | Field -> (
      match Caml.int_of_string_opt name with
      | Some _ -> name
      (* | _ -> "f_" ^ Option.value_exn type_name ^ "_" ^ name *)
      | _ -> "f_" ^ name)
  | Lifetime | Macro -> escape name

let rec to_view ({ def_id; kind } : t) : view =
  let def_id = Imported.drop_ctor def_id in
  let View.{ crate; path; definition } = View.to_view def_id in
  let type_name =
    try
      { def_id = Imported.parent def_id; kind = Type }
      |> to_definition_name
      |> String.chop_prefix_exn ~prefix:"t_"
      |> Option.some
    with _ -> None
  in
  let path, definition =
    match kind with
    | Constructor { is_struct = false } ->
        (List.drop_last_exn path, Option.value_exn type_name ^ "_" ^ definition)
    | _ -> (path, definition)
  in
  let definition = rename_definition path definition kind type_name in
  View.{ crate; path; definition }

and to_definition_name (x : t) : string = (to_view x).definition

let to_namespace x =
  let View.{ crate; path; _ } = to_view x in
  (crate, path)
