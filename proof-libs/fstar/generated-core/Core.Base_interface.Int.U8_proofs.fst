module Core.Base_interface.Int.U8_proofs
#set-options "--fuel 0 --ifuel 1 --z3rlimit 15"
open Core
open FStar.Mul

let abstract_concretize_cancel (x: Core.Base_interface.Int.t_U8)
    : Lemma Prims.l_True
      (ensures
        (Core.Base_interface.Coerce.f_concretize #Core.Base.Spec.Haxint.t_HaxInt
            #Core.Base_interface.Int.t_U8
            #FStar.Tactics.Typeclasses.solve
            (Core.Base_interface.Coerce.f_lift #Core.Base_interface.Int.t_U8
                #FStar.Tactics.Typeclasses.solve
                (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve x
                  <:
                  Core.Base_interface.Int.t_U8)
              <:
              Core.Base.Spec.Haxint.t_HaxInt)
          <:
          Core.Base_interface.Int.t_U8) =.
        x) = ()

let mod_add (x y z: Core.Base_interface.Int.t_U8)
    : Lemma Prims.l_True
      (ensures
        Core.Base.Pos.haxint_le Core.Base.Spec.Constants.v_WORDSIZE_8_
          (Core.Base.Pos.haxint_add (Core.Base_interface.Coerce.f_lift #Core.Base_interface.Int.t_U8
                  #FStar.Tactics.Typeclasses.solve
                  (Core.Clone.f_clone #Core.Base_interface.Int.t_U8
                      #FStar.Tactics.Typeclasses.solve
                      x
                    <:
                    Core.Base_interface.Int.t_U8)
                <:
                Core.Base.Spec.Haxint.t_HaxInt)
              (Core.Base_interface.Coerce.f_lift #Core.Base_interface.Int.t_U8
                  #FStar.Tactics.Typeclasses.solve
                  (Core.Clone.f_clone #Core.Base_interface.Int.t_U8
                      #FStar.Tactics.Typeclasses.solve
                      y
                    <:
                    Core.Base_interface.Int.t_U8)
                <:
                Core.Base.Spec.Haxint.t_HaxInt)
            <:
            Core.Base.Spec.Haxint.t_HaxInt) ||
        (((Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve x
              <:
              Core.Base_interface.Int.t_U8) +!
            (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve y
              <:
              Core.Base_interface.Int.t_U8)
            <:
            Core.Base_interface.Int.t_U8) %!
          (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
            <:
            Core.Base_interface.Int.t_U8)
          <:
          Core.Base_interface.Int.t_U8) =.
        (((x %!
              (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
                <:
                Core.Base_interface.Int.t_U8)
              <:
              Core.Base_interface.Int.t_U8) +!
            (y %!
              (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
                <:
                Core.Base_interface.Int.t_U8)
              <:
              Core.Base_interface.Int.t_U8)
            <:
            Core.Base_interface.Int.t_U8) %!
          z
          <:
          Core.Base_interface.Int.t_U8)) = ()

let mod_mul (x y z: Core.Base_interface.Int.t_U8)
    : Lemma Prims.l_True
      (ensures
        Core.Base.Pos.haxint_lt Core.Base.Spec.Constants.v_WORDSIZE_8_
          (Core.Base.Pos.haxint_mul (Core.Base_interface.Coerce.f_lift #Core.Base_interface.Int.t_U8
                  #FStar.Tactics.Typeclasses.solve
                  (Core.Clone.f_clone #Core.Base_interface.Int.t_U8
                      #FStar.Tactics.Typeclasses.solve
                      x
                    <:
                    Core.Base_interface.Int.t_U8)
                <:
                Core.Base.Spec.Haxint.t_HaxInt)
              (Core.Base_interface.Coerce.f_lift #Core.Base_interface.Int.t_U8
                  #FStar.Tactics.Typeclasses.solve
                  (Core.Clone.f_clone #Core.Base_interface.Int.t_U8
                      #FStar.Tactics.Typeclasses.solve
                      y
                    <:
                    Core.Base_interface.Int.t_U8)
                <:
                Core.Base.Spec.Haxint.t_HaxInt)
            <:
            Core.Base.Spec.Haxint.t_HaxInt) ||
        (((Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve x
              <:
              Core.Base_interface.Int.t_U8) *!
            (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve y
              <:
              Core.Base_interface.Int.t_U8)
            <:
            Core.Base_interface.Int.t_U8) %!
          (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
            <:
            Core.Base_interface.Int.t_U8)
          <:
          Core.Base_interface.Int.t_U8) =.
        ((((x %!
                (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
                  <:
                  Core.Base_interface.Int.t_U8)
                <:
                Core.Base_interface.Int.t_U8) *!
              y
              <:
              Core.Base_interface.Int.t_U8) %!
            (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
              <:
              Core.Base_interface.Int.t_U8)
            <:
            Core.Base_interface.Int.t_U8) %!
          z
          <:
          Core.Base_interface.Int.t_U8)) = ()

let mod_one (x: Core.Base_interface.Int.t_U8)
    : Lemma Prims.l_True
      (ensures
        (x %!
          (Core.Base_interface.Int.f_ONE #FStar.Tactics.Typeclasses.solve
            <:
            Core.Base_interface.Int.t_U8)
          <:
          Core.Base_interface.Int.t_U8) =.
        (Core.Base_interface.Int.f_ZERO #FStar.Tactics.Typeclasses.solve
          <:
          Core.Base_interface.Int.t_U8)) = ()

let mod_sub (x y z: Core.Base_interface.Int.t_U8)
    : Lemma Prims.l_True
      (ensures
        (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve x
          <:
          Core.Base_interface.Int.t_U8) <.
        (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve y
          <:
          Core.Base_interface.Int.t_U8) ||
        (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
          <:
          Core.Base_interface.Int.t_U8) <=.
        (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve x
          <:
          Core.Base_interface.Int.t_U8) ||
        (((Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve x
              <:
              Core.Base_interface.Int.t_U8) -!
            (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve y
              <:
              Core.Base_interface.Int.t_U8)
            <:
            Core.Base_interface.Int.t_U8) %!
          (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
            <:
            Core.Base_interface.Int.t_U8)
          <:
          Core.Base_interface.Int.t_U8) =.
        (((x %!
              (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
                <:
                Core.Base_interface.Int.t_U8)
              <:
              Core.Base_interface.Int.t_U8) -!
            (y %!
              (Core.Clone.f_clone #Core.Base_interface.Int.t_U8 #FStar.Tactics.Typeclasses.solve z
                <:
                Core.Base_interface.Int.t_U8)
              <:
              Core.Base_interface.Int.t_U8)
            <:
            Core.Base_interface.Int.t_U8) %!
          z
          <:
          Core.Base_interface.Int.t_U8)) = ()
