Require Import Coq.Reals.Reals.
Require Import List.
Import ListNotations.
Require Import Coq.Lists.ListSet.

Require Import Casper.preamble.
Require Import Casper.ListSetExtras.

Require Import Casper.FullStates.consensus_values.
Require Import Casper.FullStates.validators.
Require Import Casper.FullStates.estimator.
Require Import Casper.FullStates.fault_weights.
Require Import Casper.FullStates.threshold.
Require Import Casper.FullStates.consistent_decisions_prop_protocol_states.


Module Non_triviality_Properties_Protocol_States
        (PCons : Consensus_Values) 
        (PVal : Validators)
        (PVal_Weights : Validators_Weights PVal)
        (PEstimator : Estimator PCons PVal PVal_Weights)
        (PThreshold : Threshold PVal PVal_Weights)
        .

Import PCons.
Import PVal.
Import PVal_Weights.
Import PThreshold.
Import PEstimator.

Module PProperties_Protocol_States := Properties_Protocol_States PCons PVal PVal_Weights PEstimator PThreshold.
Export PProperties_Protocol_States.

Definition potentially_pivotal (v : V) : Prop :=
    exists (vs : list V),
      NoDup vs /\
      ~In v vs /\
      (sum_weights vs <= t)%R /\
      (sum_weights vs > t - weight v)%R
      .

Lemma exists_pivotal_message : exists v, potentially_pivotal v.
Proof.
  destruct sufficient_validators_pivotal as [vs [Hnodup [Hgt [v [Hin Hlte]]]]].
  exists v.
  subst. exists (set_remove v_eq_dec v vs). repeat split.
  - apply set_remove_nodup. assumption.
  - intro. apply set_remove_iff in H; try assumption. destruct H. apply H0. reflexivity.
  - assumption.
  - rewrite (sum_weights_in v) in Hgt; try assumption.
    rewrite Rplus_comm in Hgt.
    apply (Rplus_gt_compat_r (- weight v)%R) in Hgt.
    rewrite Rplus_assoc in Hgt.
    rewrite Rplus_opp_r in Hgt.
    rewrite Rplus_0_r in Hgt.
    assumption.
Qed.

Theorem non_triviality_decisions_on_properties_of_protocol_states :
  exists p, non_trivial p.
Proof.
  destruct exists_pivotal_message as [v Hpivotal].
  destruct (estimator_total Empty) as [c Hc].
  exists (in_state (c,v,Empty)).
  split.
  - exists (next (c,v,Empty) Empty).
    split.
    + assert (add_in_sorted_fn (c, v, Empty) Empty = (next (c, v, Empty) Empty)).
      { simpl. reflexivity. }
      rewrite <- H. constructor; try assumption; try apply protocol_state_empty.
      * apply incl_refl.
      * simpl. 
        unfold fault_tolerance_condition.
        unfold fault_weight_state. unfold equivocating_senders. simpl.
        unfold equivocating_message_state. simpl.
        unfold equivocating_messages. rewrite eq_dec_if_true; try reflexivity.
        simpl.
        apply Rge_le.
        apply threshold_nonnegative.
    + intros sigma H. destruct H as [HLS1 [HLS2 H]]. apply H. simpl. left. reflexivity.
  - 
  Admitted.

End Non_triviality_Properties_Protocol_States.