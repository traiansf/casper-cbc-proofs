Require Import Coq.Reals.Reals.

(**************************************)
(** Non-empty set of validator names **)
(**************************************)

Module Type Validators.

Parameter V : Set .

Axiom v_non_empty : exists v : V, True.

Axiom v_eq_dec : forall (v1 v2 : V), {v1 = v2} + {v1 <> v2}.

End Validators.


(***********************)
(** Validator weights **)
(***********************)

Module Type Validators_Weights
              (PVal : Validators)
              .

Import PVal.

Parameter weight : V -> R.

Axiom weight_positive : forall v : V, (0 < weight v)%R.

End Validators_Weights.

(******************************)
(** Properties of validators **)
(******************************)

Module Validators_Properties
              (PVal : Validators)
              .
Import PVal.

Definition v_eq_fn  (x y : V) : bool :=
  match v_eq_dec x y with
  | left _ => true
  | right _ => false
  end.

End Validators_Properties.