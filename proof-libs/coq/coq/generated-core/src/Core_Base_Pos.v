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

(* TODO: Replace this dummy lib with core lib *)
Class t_Sized (T : Type) := { }.
Definition t_u8 := Z.
Definition t_u16 := Z.
Definition t_u32 := Z.
Definition t_u64 := Z.
Definition t_u128 := Z.
Definition t_usize := Z.
Definition t_i8 := Z.
Definition t_i16 := Z.
Definition t_i32 := Z.
Definition t_i64 := Z.
Definition t_i128 := Z.
Definition t_isize := Z.
Definition t_Array T (x : t_usize) := list T.
Definition t_String := string.
Definition ToString_f_to_string (x : string) := x.
Instance Sized_any : forall {t_A}, t_Sized t_A := {}.
Class t_Clone (T : Type) := { Clone_f_clone : T -> T }.
Instance Clone_any : forall {t_A}, t_Clone t_A := {Clone_f_clone := fun x => x}.
Definition t_Slice (T : Type) := list T.
Definition unsize {T : Type} : list T -> t_Slice T := id.
Definition t_PartialEq_f_eq x y := x =? y.
Definition t_Rem_f_rem (x y : Z) := x mod y.
Definition assert (b : bool) (* `{H_assert : b = true} *) : unit := tt.
Inductive globality := | t_Global.
Definition t_Vec T (_ : globality) : Type := list T.
Definition impl_1__append {T} l1 l2 : list T * list T := (app l1 l2, l2).
Definition impl_1__len {A} (l : list A) := Z.of_nat (List.length l).
Definition impl__new {A} (_ : Datatypes.unit) : list A := nil.
Definition impl__with_capacity {A} (_ : Z)  : list A := nil.
Definition impl_1__push {A} l (x : A) := cons x l.
Class t_From (A B : Type) := { From_f_from : B -> A }.
Definition impl__to_vec {T} (x : t_Slice T) : t_Vec T t_Global := x.
Class t_Into (A B : Type) := { Into_f_into : A -> B }.
Instance t_Into_from_t_From {A B : Type} `{H : t_From B A} : t_Into A B := { Into_f_into x := @From_f_from B A H x }.
Definition from_elem {A} (x : A) (l : Z) := repeat x (Z.to_nat l).
Definition t_Option := option.
Definition impl__map {A B} (x : t_Option A) (f : A -> B) : t_Option B := match x with | Some x => Some (f x) | None => None end.
Definition t_Add_f_add x y := x + y.
Class Cast A B := { cast : A -> B }.
Instance cast_t_u8_t_u32 : Cast t_u8 t_u32 := {| cast x := x |}.
(* / dummy lib *)

From Core Require Import Core_Base_Spec.
Export Core_Base_Spec.

From Core Require Import Core_Base_Binary.
Export Core_Base_Binary.

From Core Require Import Core_Cmp (t_Ordering).
Export Core_Cmp (t_Ordering).

Definition haxint_double (s : t_HaxInt) : t_HaxInt :=
  match match_pos (s) with
  | POS_ZERO =>
    v_HaxInt_ZERO
  | POS_POS (p) =>
    positive_to_int (xO (p))
  end.

Definition haxint_shr__half (s : t_HaxInt) : t_HaxInt :=
  match match_pos (s) with
  | POS_ZERO =>
    v_HaxInt_ZERO
  | POS_POS (n) =>
    match match_positive (n) with
    | POSITIVE_XH =>
      v_HaxInt_ZERO
    | POSITIVE_XO (p) =>
      positive_to_int (p)
    | POSITIVE_XI (p) =>
      positive_to_int (p)
    end
  end.

Definition haxint_sub__double_mask (lhs : t_HaxInt) : t_HaxInt :=
  match match_pos (lhs) with
  | POS_ZERO =>
    v_HaxInt_ZERO
  | POS_POS (p) =>
    positive_to_int (xO (p))
  end.

Definition haxint_sub__succ_double_mask (lhs : t_HaxInt) : t_HaxInt :=
  match match_pos (lhs) with
  | POS_ZERO =>
    positive_to_int (xH)
  | POS_POS (p) =>
    positive_to_int (xI (p))
  end.

Definition haxint_succ_double (s : t_HaxInt) : t_Positive :=
  match match_pos (s) with
  | POS_ZERO =>
    xH
  | POS_POS (p) =>
    xI (p)
  end.

Fixpoint bitand_binary (lhs : t_Positive) (rhs : t_Positive) : t_HaxInt :=
  match match_positive (lhs) with
  | POSITIVE_XH =>
    match match_positive (rhs) with
    | POSITIVE_XO (q) =>
      v_HaxInt_ZERO
    | POSITIVE_XI (_)
    | POSITIVE_XH =>
      v_HaxInt_ONE
    end
  | POSITIVE_XO (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      v_HaxInt_ZERO
    | POSITIVE_XO (q)
    | POSITIVE_XI (q) =>
      haxint_double (bitand_binary (p) (q))
    end
  | POSITIVE_XI (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      v_HaxInt_ONE
    | POSITIVE_XO (q) =>
      haxint_double (bitand_binary (p) (q))
    | POSITIVE_XI (q) =>
      positive_to_int (haxint_succ_double (bitand_binary (p) (q)))
    end
  end.

Fixpoint bitor_binary (lhs : t_Positive) (rhs : t_Positive) : t_Positive :=
  match match_positive (lhs) with
  | POSITIVE_XH =>
    match match_positive (rhs) with
    | POSITIVE_XO (q) =>
      xI (q)
    | POSITIVE_XH =>
      xH
    | POSITIVE_XI (q) =>
      xI (q)
    end
  | POSITIVE_XO (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      xI (p)
    | POSITIVE_XO (q) =>
      xO (bitor_binary (p) (q))
    | POSITIVE_XI (q) =>
      xI (bitor_binary (p) (q))
    end
  | POSITIVE_XI (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      xI (p)
    | POSITIVE_XO (q)
    | POSITIVE_XI (q) =>
      xI (bitor_binary (p) (q))
    end
  end.

Definition haxint_bitand (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  match match_pos (lhs) with
  | POS_ZERO =>
    v_HaxInt_ZERO
  | POS_POS (p) =>
    match match_pos (rhs) with
    | POS_ZERO =>
      v_HaxInt_ZERO
    | POS_POS (q) =>
      bitand_binary (p) (q)
    end
  end.

Definition haxint_bitor (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  match match_pos (lhs) with
  | POS_ZERO =>
    rhs
  | POS_POS (p) =>
    match match_pos (rhs) with
    | POS_ZERO =>
      positive_to_int (p)
    | POS_POS (q) =>
      positive_to_int (bitor_binary (p) (q))
    end
  end.

Fixpoint haxint_bitxor__bitxor_binary (lhs : t_Positive) (rhs : t_Positive) : t_HaxInt :=
  match match_positive (lhs) with
  | POSITIVE_XH =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      v_HaxInt_ZERO
    | POSITIVE_XO (q) =>
      positive_to_int (xI (q))
    | POSITIVE_XI (q) =>
      positive_to_int (xO (q))
    end
  | POSITIVE_XO (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      positive_to_int (xI (p))
    | POSITIVE_XO (q) =>
      haxint_double (haxint_bitxor__bitxor_binary (p) (q))
    | POSITIVE_XI (q) =>
      positive_to_int (haxint_succ_double (haxint_bitxor__bitxor_binary (p) (q)))
    end
  | POSITIVE_XI (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      positive_to_int (xO (p))
    | POSITIVE_XO (q) =>
      positive_to_int (haxint_succ_double (haxint_bitxor__bitxor_binary (p) (q)))
    | POSITIVE_XI (q) =>
      haxint_double (haxint_bitxor__bitxor_binary (p) (q))
    end
  end.

Definition haxint_bitxor (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  match match_pos (lhs) with
  | POS_ZERO =>
    rhs
  | POS_POS (p) =>
    match match_pos (rhs) with
    | POS_ZERO =>
      positive_to_int (p)
    | POS_POS (q) =>
      haxint_bitxor__bitxor_binary (p) (q)
    end
  end.

Definition haxint_cmp (lhs : t_HaxInt) (rhs : t_HaxInt) : t_Ordering :=
  match match_pos (lhs) with
  | POS_ZERO =>
    match match_pos (rhs) with
    | POS_ZERO =>
      Ordering_Equal
    | POS_POS (q) =>
      Ordering_Less
    end
  | POS_POS (p) =>
    match match_pos (rhs) with
    | POS_ZERO =>
      Ordering_Greater
    | POS_POS (q) =>
      positive_cmp (p) (q)
    end
  end.

Definition haxint_le (lhs : t_HaxInt) (rhs : t_HaxInt) : bool :=
  match Option_Some (haxint_cmp (lhs) (rhs)) with
  | Option_Some (Ordering_Less
  | Ordering_Equal) =>
    true
  | _ =>
    false
  end.

Definition haxint_lt (lhs : t_HaxInt) (rhs : t_HaxInt) : bool :=
  match Option_Some (haxint_cmp (lhs) (rhs)) with
  | Option_Some (Ordering_Less) =>
    true
  | _ =>
    false
  end.

Fixpoint haxint_shl__shl_helper (rhs : t_Unary) (lhs : t_HaxInt) : t_HaxInt :=
  if
    is_zero (Clone_f_clone (lhs))
  then
    lhs
  else
    match match_unary (rhs) with
    | UNARY_ZERO =>
      lhs
    | UNARY_SUCC (n) =>
      haxint_shl__shl_helper (n) (haxint_double (lhs))
    end.

Definition haxint_shl (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  haxint_shl__shl_helper (unary_from_int (rhs)) (lhs).

Fixpoint haxint_shr__shr_helper (rhs : t_Unary) (lhs : t_HaxInt) : t_HaxInt :=
  if
    is_zero (Clone_f_clone (lhs))
  then
    lhs
  else
    match match_unary (rhs) with
    | UNARY_ZERO =>
      lhs
    | UNARY_SUCC (n) =>
      haxint_shr__shr_helper (n) (haxint_shr__half (lhs))
    end.

Definition haxint_shr (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  haxint_shr__shr_helper (unary_from_int (rhs)) (lhs).

Definition haxint_sub__double_pred_mask (lhs : t_Positive) : t_HaxInt :=
  match match_positive (lhs) with
  | POSITIVE_XH =>
    v_HaxInt_ZERO
  | POSITIVE_XO (p) =>
    positive_to_int (xO (positive_pred_double (p)))
  | POSITIVE_XI (p) =>
    positive_to_int (xO (xO (p)))
  end.

Fixpoint power_of_two (s : t_Unary) : t_Positive :=
  match match_unary (s) with
  | UNARY_ZERO =>
    xH
  | UNARY_SUCC (x) =>
    xO (power_of_two (x))
  end.

Definition haxint_add (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  match match_pos (lhs) with
  | POS_ZERO =>
    rhs
  | POS_POS (p) =>
    match match_pos (rhs) with
    | POS_ZERO =>
      positive_to_int (p)
    | POS_POS (q) =>
      positive_to_int (positive_add (p) (q))
    end
  end.

Definition haxint_sub (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  match match_pos (lhs) with
  | POS_ZERO =>
    v_HaxInt_ZERO
  | POS_POS (p) =>
    match match_pos (rhs) with
    | POS_ZERO =>
      positive_to_int (p)
    | POS_POS (q) =>
      haxint_sub__sub_binary (p) (q)
    end
  end.

Fixpoint haxint_divmod__divmod_binary (a : t_Positive) (b : t_Positive) : (t_HaxInt*t_HaxInt) :=
  match match_positive (a) with
  | POSITIVE_XH =>
    match match_positive (b) with
    | POSITIVE_XH =>
      (v_HaxInt_ONE,v_HaxInt_ZERO)
    | POSITIVE_XO (q)
    | POSITIVE_XI (q) =>
      (v_HaxInt_ZERO,v_HaxInt_ONE)
    end
  | POSITIVE_XO (a___) =>
    let (q,r) := haxint_divmod__divmod_binary (a___) (Clone_f_clone (b)) in
    let r___ := haxint_double (r) in
    if
      haxint_le (positive_to_int (Clone_f_clone (b))) (Clone_f_clone (r___))
    then
      (positive_to_int (haxint_succ_double (q)),haxint_sub (r___) (positive_to_int (b)))
    else
      (haxint_double (q),r___)
  | POSITIVE_XI (a___) =>
    let (q,r) := haxint_divmod__divmod_binary (a___) (Clone_f_clone (b)) in
    let r___ := positive_to_int (haxint_succ_double (r)) in
    if
      haxint_le (positive_to_int (Clone_f_clone (b))) (Clone_f_clone (r___))
    then
      (positive_to_int (haxint_succ_double (q)),haxint_sub (r___) (positive_to_int (b)))
    else
      (haxint_double (q),r___)
  end.

Definition haxint_divmod (a : t_HaxInt) (b : t_HaxInt) : (t_HaxInt*t_HaxInt) :=
  match match_pos (a) with
  | POS_ZERO =>
    (v_HaxInt_ZERO,v_HaxInt_ZERO)
  | POS_POS (p) =>
    match match_pos (b) with
    | POS_ZERO =>
      (v_HaxInt_ZERO,positive_to_int (p))
    | POS_POS (q) =>
      haxint_divmod__divmod_binary (p) (q)
    end
  end.

Definition haxint_div (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  let (q,_) := haxint_divmod (lhs) (rhs) in
  q.

Definition haxint_mul (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  match match_pos (lhs) with
  | POS_ZERO =>
    v_HaxInt_ZERO
  | POS_POS (p) =>
    match match_pos (rhs) with
    | POS_ZERO =>
      v_HaxInt_ZERO
    | POS_POS (q) =>
      positive_to_int (positive_mul (p) (q))
    end
  end.

Definition haxint_rem (lhs : t_HaxInt) (rhs : t_HaxInt) : t_HaxInt :=
  let (_,r) := haxint_divmod (lhs) (rhs) in
  r.

Fixpoint haxint_sub__sub_binary (lhs : t_Positive) (rhs : t_Positive) : t_HaxInt :=
  match match_positive (lhs) with
  | POSITIVE_XH =>
    v_HaxInt_ZERO
  | POSITIVE_XO (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      positive_to_int (positive_pred_double (p))
    | POSITIVE_XO (q) =>
      haxint_sub__double_mask (haxint_sub__sub_binary (p) (q))
    | POSITIVE_XI (q) =>
      haxint_sub__succ_double_mask (haxint_sub__sub_carry (p) (q))
    end
  | POSITIVE_XI (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      positive_to_int (xO (p))
    | POSITIVE_XO (q) =>
      haxint_sub__succ_double_mask (haxint_sub__sub_binary (p) (q))
    | POSITIVE_XI (q) =>
      haxint_sub__double_mask (haxint_sub__sub_binary (p) (q))
    end
  end.

Fixpoint haxint_sub__sub_carry (lhs : t_Positive) (rhs : t_Positive) : t_HaxInt :=
  match match_positive (lhs) with
  | POSITIVE_XH =>
    v_HaxInt_ZERO
  | POSITIVE_XO (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      haxint_sub__double_pred_mask (p)
    | POSITIVE_XO (q) =>
      haxint_sub__succ_double_mask (haxint_sub__sub_carry (p) (q))
    | POSITIVE_XI (q) =>
      haxint_sub__double_mask (haxint_sub__sub_carry (p) (q))
    end
  | POSITIVE_XI (p) =>
    match match_positive (rhs) with
    | POSITIVE_XH =>
      positive_to_int (positive_pred_double (p))
    | POSITIVE_XO (q) =>
      haxint_sub__double_mask (haxint_sub__sub_binary (p) (q))
    | POSITIVE_XI (q) =>
      haxint_sub__succ_double_mask (haxint_sub__sub_carry (p) (q))
    end
  end.
