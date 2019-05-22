Require Import Coq.Reals.Reals.
Require Import Coq.Sorting.Sorted.
Require Import Coq.Classes.RelationClasses.
Require Import Coq.Relations.Relation_Definitions.
Require Import Coq.Structures.Orders.

Require Import Casper.preamble.

(**
  TODO: Prove that all Inductive defining functions yield total functions.
  This is important, as if the functions are not total we might have empty
  hypothesis.
**)


(** Parameters of the protocol **)

Require Import Casper.consensus_values.
Require Import Casper.validators.
Require Import Casper.threshold.


(** Messages and States **)

Require Import Casper.full_states.
Require Import Casper.full_messages.


(***************)
(** Estimator **)
(***************)

Parameter epsilon : state -> C -> Prop.

Parameter epsilon_total : forall s : state, exists c : C, epsilon s c.


(** Canonical representation of states **)

Require Import Casper.FullStates.add_in_sorted.
Require Import Casper.FullStates.locally_sorted.


(** State equality **)
Require Import Casper.FullStates.in_state.
Require Import Casper.FullStates.syntactic_state_inclusion.
Require Import Casper.FullStates.sort.
Require Import Casper.FullStates.state_eq.
Require Import Casper.FullStates.state_inclusion.
Require Import Casper.FullStates.sorted_subset.


Theorem inclusion_state_eq : forall sigma1 sigma2,
  state_inclusion sigma1 sigma2 ->
  state_inclusion sigma2 sigma1 ->
  state_eq sigma1 sigma2.
Proof.
  intros.
  destruct (sort_total sigma1) as [sigma1s Hsort1].
  destruct (sort_total sigma2) as [sigma2s Hsort2].
  apply sort_is_sorted in Hsort1 as Hsigma1s.
  apply sort_is_sorted in Hsort2 as Hsigma2s.
  apply sort_state_eq in Hsort1.
  apply sort_state_eq in Hsort2.
  apply state_eq_inclusion in Hsort1 as Hinsigma1s.
  apply state_eq_symmetric in Hsort1.
  apply state_eq_inclusion in Hsort1 as Hinsigma1s'.

  apply state_eq_inclusion in Hsort2 as Hinsigma2s.
  apply state_eq_symmetric in Hsort2.
  apply state_eq_inclusion in Hsort2 as Hinsigma2s'.

  apply (state_inclusion_transitive _ _ _ H) in Hinsigma2s.
  apply (state_inclusion_transitive _ _ _ Hinsigma1s') in Hinsigma2s.
  apply (state_inclusion_transitive _ _ _ H0) in Hinsigma1s.
  apply (state_inclusion_transitive _ _ _ Hinsigma2s') in Hinsigma1s.
  clear H. clear H0. clear Hinsigma1s'. clear Hinsigma2s'.
  
  apply sorted_subset_inclusion in Hinsigma1s; try assumption.
  apply sorted_subset_inclusion in Hinsigma2s; try assumption.

  apply sorted_subset_syntactic_inclusion in Hinsigma1s.
  apply sorted_subset_syntactic_inclusion in Hinsigma2s.

  apply sorted_syntactic_state_inclusion_equality_predicate in Hinsigma2s
  ; try assumption.
  subst.
  apply state_eq_symmetric in Hsort1.
  apply (state_eq_transitive _ _ _ Hsort1 Hsort2).
Qed.

(*******************************)
(** Protocol state conditions **) 
(*******************************)


Require Import Casper.FullStates.fault_weights.


(** The Full Node condition. Assumes sigma1 and sigma2 are sorted **)

Definition full_node_condition (sigma1 sigma2 : state) : Prop :=
    sorted_subset sigma1 sigma2.

(** The valid message condition **)
Definition valid_msg_condition (c : C) (sigma : state) : Prop :=
    epsilon sigma c.


(** The fault tolerance condition **)
Definition fault_tolerance_condition (sigma : state) : Prop :=
  forall r,
  fault_weight_state sigma r ->
  (r <= t)%R.

Inductive protocol_state : state -> Prop :=
  | protocol_state_empty : protocol_state Empty
  | protocol_state_next : forall c v sigma sigma' sigma'',
      protocol_state sigma ->
      protocol_state sigma' ->
      full_node_condition sigma sigma' ->
      valid_msg_condition c sigma ->
      add_in_sorted (c, v, sigma) sigma' sigma'' ->
      fault_tolerance_condition sigma'' ->
      protocol_state sigma''
  .

Theorem protocol_state_sorted : forall state,
  protocol_state state -> 
  locally_sorted state.
Proof.
  intros.
  induction H.
  - constructor.
  - apply (add_in_sorted_sorted (c, v, sigma) sigma'); try assumption.
  apply locally_sorted_msg_justification. assumption.
Qed.















