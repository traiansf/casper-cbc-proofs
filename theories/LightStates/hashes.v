Require Import Coq.Lists.ListSet.
Require Import List.

Require Import Casper.ListSetExtras.

(*******************)
(** Hash universe **)
(*******************)

Parameter hash : Set .

Parameter hash_eq_dec : forall (h1 h2 : hash), {h1 = h2} + {h1 <> h2}.

Definition justification := set hash.

Definition justification_in := set_mem hash_eq_dec.

Definition justification_eq := @set_eq hash.

Definition justification_eq_dec := set_eq_dec hash_eq_dec.