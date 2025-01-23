(* File automatically generated by Hacspec *)
From Coq Require Import ZArith.
Require Import List.
Import List.ListNotations.
Open Scope Z_scope.
Open Scope bool_scope.
Require Import Ascii.
Require Import String.
Require Import Coq.Floats.Floats.
From RecordUpdate Require Import RecordSet.
Import RecordSetNotations.

(* From Core Require Import Core. *)

From Core Require Import Core_Marker.
Export Core_Marker.

(* NotImplementedYet *)

Class t_FnOnce (v_Self : Type) (v_Args : Type) (* `{t_Sized (v_Args)} `{t_Tuple (v_Args)} *) : Type :=
  {
    FnOnce_f_Output : Type;
    _ :: `{t_Sized (FnOnce_f_Output)};
    FnOnce_f_call_once : v_Self -> v_Args -> FnOnce_f_Output;
  }.
Arguments t_FnOnce (_) (_) (* {_} {_} *).

Class t_FnMut (v_Self : Type) (v_Args : Type) `{t_FnOnce (v_Self) (v_Args)} (* `{t_Sized (v_Args)} `{t_Tuple (v_Args)} *) : Type :=
  {
    FnMut_f_call_mut : v_Self -> v_Args -> (v_Self*FnOnce_f_Output);
  }.
Arguments t_FnMut (_) (_) {_} (* {_} {_} *).

Class t_Fn (v_Self : Type) (v_Args : Type) `{t_FnMut (v_Self) (v_Args)} (* `{t_Sized (v_Args)} `{t_Tuple (v_Args)} *) : Type :=
  {
    Fn_f_call : v_Self -> v_Args -> FnOnce_f_Output;
  }.
Arguments t_Fn (_) (_) {_} (* {_} {_} *).



#[global] Instance t_FnOnceAny {A B} : t_FnOnce (A -> B) A.
Proof.
  econstructor.
  easy.
  refine (fun f x => f x).
Defined.
