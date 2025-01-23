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

From Core Require Import Core_Option.
Export Core_Option.

Inductive t_Result (v_T : Type) (v_E : Type) `{t_Sized (v_T)} `{t_Sized (v_E)} : Type :=
| Result_Ok : v_T -> _
| Result_Err : v_E -> _.
Arguments Result_Ok {_} {_} {_} {_}.
Arguments Result_Err {_} {_} {_} {_}.

Definition impl__ok `{v_T : Type} `{v_E : Type} `{t_Sized (v_T)} `{t_Sized (v_E)} (self : t_Result ((v_T)) ((v_E))) : t_Option ((v_T)) :=
  match self with
  | Result_Ok (x) =>
    Option_Some (x)
  | Result_Err (_) =>
    Option_None
  end.
