open! Prelude

module Make (T : sig
  type t_
  type view_
end) =
struct
  open T

  module type NAME_POLICY = sig
    val reserved_words : string Hash_set.t
    (** List of all words that have a special meaning in the target
        language, and that should thus be escaped. *)

    val index_field_transform : string -> string
    (** Transformation applied to indexes fields name (i.e. [x.1]) *)

    val field_name_transform : struct_name:string -> string -> string
    val enum_constructor_name_transform : enum_name:string -> string -> string
    val struct_constructor_name_transform : string -> string
    val constructor_prefix : string
  end

  module type VIEW_API = sig
    val show : t_ -> string
    val pp : Formatter.t -> t_ -> unit
    val to_view : t_ -> view_
    val to_definition_name : t_ -> string
    val to_crate_name : t_ -> string
    val to_namespace : t_ -> string * string list
    val local_ident : Local_ident.t -> string
  end
end
