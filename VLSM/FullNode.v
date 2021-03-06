Require Import Bool List Streams Logic.Epsilon Reals ProofIrrelevance Fin FinFun.
Import ListNotations.
From CasperCBC   
Require Import Lib.Preamble Lib.ListExtras Lib.ListSetExtras Lib.RealsExtras CBC.Definitions CBC.Common VLSM.Common VLSM.Composition VLSM.Decisions CBC.FullNode.


(* Section 2.3 Creating a full-node instance of VLSM *)

Section Full. 

  Variables (C V : Type) (about_C : StrictlyComparable C) (about_V : StrictlyComparable V) (Hm : Measurable V) (Hrt : ReachableThreshold V) (He : Estimator (@sorted_state C V message_type) C).

  Definition reach (s1 s2 : @CBC.Definitions.state C V) : Prop :=
    incl (get_messages s1) (get_messages s2).

  Definition proto_message_prop : @sorted_message C V message_type -> Prop :=
    fun msg => True. 

  Definition message : Type :=
    { m : @sorted_message C V message_type | proto_message_prop m}. 

  Lemma proto_message_decidable :
    forall (msg : @sorted_message C V message_type), {proto_message_prop msg} + {~ proto_message_prop msg}. 
  Proof. 
    intros msg.
    left.
    red. auto.
  Qed.

  Definition initial_state_prop : @sorted_state C V message_type -> Prop :=
    fun s => s = @sorted_state0 C V message_type. 

  Program Definition state0 : {s | initial_state_prop s} := _.
  Next Obligation.
    exists (@sorted_state0 C V message_type).
    reflexivity.
  Defined. 

  Program Definition proto_message0 : message := _. 
  Next Obligation.
    destruct (@Lib.Preamble.inhabited _ about_C) as [c _].
    destruct (@Lib.Preamble.inhabited _ about_V) as [v _].
    exists (c,v,@sorted_state0 C V message_type).
    red.
    auto.
  Defined.

  Definition message0 : @sorted_message C V message_type := proj1_sig proto_message0. 

  Definition initial_message_prop (m : message) : Prop := False.
  
  Definition initial_message := { m : message | initial_message_prop m }.

  Lemma protocol_state_inhabited : {_ : @sorted_state C V message_type | True}.
  Proof.
    exists (@sorted_state0 C V message_type).
    auto. 
  Qed. 

  Lemma message_inhabited : {m : @sorted_message C V message_type | True}. 
  Proof.
    destruct (@message_type C about_C V about_V).
    assert (inhabited_copy := inhabited).
    destruct inhabited_copy as [[(c, v) _] _].
    exists (c, v, exist _ Empty LSorted_Empty); auto. 
  Qed.

  Program Definition make_proto_message_prop (msg : @sorted_message C V message_type) : proto_message_prop msg := _. 
  Next Obligation.
    unfold proto_message_prop.
    auto.
  Defined.

  Definition make_proto_message (msg : @sorted_message C V message_type) : {msg : @sorted_message C V message_type | proto_message_prop msg} := 
     exist _ msg (make_proto_message_prop msg).

  Definition vtransition (l : option (C * V)) (sm : @sorted_state C V message_type * option message) :  @sorted_state C V message_type  * option message :=
    let (s, om) := sm in
    match l with 
    | None => match om with 
             | None => (s, None)
             | Some msg => (add_message_sorted (proj1_sig msg) s, None) 
             end
    | Some (c, v) =>
      let m' := make_proto_message (c,v,s) in
      let s' := add_message_sorted (c,v,s) s in
      match om with
      | None => (s', Some m')
      | Some msg => (add_message_sorted (proj1_sig msg) s', Some m')
      end
    end.

  Definition valid_client'
    (s : @sorted_state C V message_type)
    (om : option message)
    :=
    match om with 
    | None => True
    | Some pm =>
      let (m, Hm) := pm in
      let (_, j) := m in
      reach j s /\ not_heavy (add_message_sorted m s)
    end.

  Definition valid_client
     (l : option (C * V)) (sm : @sorted_state C V message_type * option message)
    :=
    let (s, om) := sm in
    match l with 
    | None => valid_client' s om
    | Some (c, v) =>
      let m' := make_proto_message (c,v,s) in
      let s' := add_message_sorted (c,v,s) s in
      (@estimator (@sorted_state C V message_type) C He) s c
      /\ valid_client' s' om
    end.


  Definition reachb : @CBC.Definitions.state C V -> CBC.Definitions.state -> bool :=
    fun s1 s2 => forallb (fun s => is_member s (get_messages s2)) (get_messages s1).

  (* 2.3.2 Minimal full client, Client1 *)

  Instance VLSM_type_full_client1 : VLSM_type message :=
    { state := @sorted_state C V message_type
    ; label := option (C * V)
    }.

  Instance LSM_full_client1 : LSM_sig VLSM_type_full_client1 :=
    { initial_state_prop := initial_state_prop
    ; initial_message_prop := initial_message_prop
    ; s0 := state0
    ; m0 := proto_message0
    ; l0 := None
    }.

  Instance VLSM_full_client1 : VLSM LSM_full_client1 := 
    { transition := vtransition
      ; valid := valid_client
    }.


  (* Converting between full node and VLSM notions *)

  (* How to avoid these solutions to awkward namespace clashes? *) 
  Definition sorted_state_union : (@state _ VLSM_type_full_client1) -> (@state _ VLSM_type_full_client1) -> (@state _ VLSM_type_full_client1) :=
    sorted_state_union.

  Definition estimator_proj1 (s : @CBC.Definitions.state C V) : C -> Prop := (@estimator _ _ He) (make_sorted_state s). 

  Lemma estimator_proj1_total : forall s : @CBC.Definitions.state C V, exists c : C, estimator_proj1 s c.
  Proof.
    intros.
    apply (@estimator_total _ _ He (make_sorted_state s)).
  Qed.

  Definition He_proj1 : Estimator (@CBC.Definitions.state C V) C :=
    {|  estimator := estimator_proj1
    ;   estimator_total := estimator_proj1_total
    |}.

  Definition PS_proj1 : @ProtocolState C V message_type Hm Hrt He_proj1.
  constructor.
  Defined.

  (* Protocol state *)
  (* How do we state this? *)
  Lemma protocol_state_equiv_left :
    forall (s : @state _ VLSM_type_full_client1),
      (@CBC.Definitions.protocol_state C V message_type Hm Hrt He_proj1 PS_proj1) (proj1_sig s)
      ->
      (protocol_state_prop VLSM_full_client1) s.
  Proof.
    intros [s Hs]; simpl; intro H.
    induction H.
    + exists None.
      assert (Heq : exist (fun s : CBC.Definitions.state => locally_sorted s) Empty Hs = proj1_sig s0)
        by (simpl; apply exist_eq; reflexivity).
      rewrite Heq; clear Heq. constructor.
    + specialize (protocol_state_sorted j H0); intros Hsj.
      specialize (protocol_state_sorted s H); intros Hss.
      remember (Some (make_proto_message (c, v, (exist _ j Hsj)))) as om.
      remember (exist _ s Hss) as ss.
      assert (Hv : valid_client None (ss,om))
        by (subst; simpl; split; assumption).
      exists None.
      assert
        (Ht :
          (@pair (@state message VLSM_type_full_client1) (option message)
            (@exist (@CBC.Definitions.state C V)
               (fun s0 : @CBC.Definitions.state C V =>
                @locally_sorted C V (@message_type C about_C V about_V) s0)
               (@add_in_sorted_fn C V (@message_type C about_C V about_V)
                  (@pair (prod C V) (@CBC.Definitions.state C V) (@pair C V c v) j) s)
               Hs) (@None message))        
          = vtransition None (ss, om)
        )
        by (subst; simpl; apply injective_projections; try reflexivity; apply exist_eq; reflexivity).
      rewrite Ht.
      specialize (IHprotocol_state1 Hss). destruct IHprotocol_state1 as [_om Pss]. 
      specialize (IHprotocol_state2 Hsj). destruct IHprotocol_state2 as [_omj Psj].
      subst.
      remember (exist (fun s : CBC.Definitions.state => locally_sorted s) s Hss) as ss.
      remember (exist (fun s : CBC.Definitions.state => locally_sorted s) j Hsj) as sj.
      remember (add_message_sorted (c,v,sj) sj) as sj'.
      specialize (protocol_generated (VLSM_full_client1) None ss _om Pss sj' (Some (make_proto_message (c,v,sj)))); intros Pss'.
      assert (Pcvj : protocol_prop (VLSM_full_client1) (sj', Some (make_proto_message (c, v, sj)))).
      { specialize (protocol_generated (VLSM_full_client1) (Some (c,v)) sj _omj Psj (proj1_sig s0) None (protocol_initial_state (VLSM_full_client1) s0)); intros Pcvj'.
        assert (Hvj' : valid_client (Some (c, v)) (sj, None)).
        { subst. simpl. split; auto. unfold valid_estimate in H2. unfold estimator in H2; simpl in H2. unfold estimator_proj1 in H2.
          rewrite (make_already_sorted_state j Hsj) in H2. assumption.
        }
        specialize (Pcvj' Hvj').
        subst. assumption.
      }
      specialize (Pss' Pcvj Hv).
      assumption.
  Qed.


  Lemma protocol_state_messages
    (s : @state _ VLSM_type_full_client1)
    (om : option {msg : sorted_message C V | proto_message_prop msg})
    (P : (protocol_prop VLSM_full_client1) (s, om))
  : forall
    (c : C)
    (v : V)
    (j : @state _ VLSM_type_full_client1)
    (Hin : in_state (c, v, (proj1_sig j)) (proj1_sig s))
    , (protocol_prop VLSM_full_client1) (add_message_sorted (c, v, j) j, Some (make_proto_message (c, v, j)))
      /\ syntactic_state_inclusion (proj1_sig j) (proj1_sig s)
    .
  Proof.
    remember (s, om) as som.
    generalize dependent om. generalize dependent s.
    induction P; intros.
    - inversion Heqsom; subst; clear Heqsom.
       destruct is as [is His]. simpl in s. unfold s in *. clear s.
       rewrite His in *. unfold sorted_state0. simpl in Hin. inversion Hin.
    - inversion Heqsom; subst; clear Heqsom. unfold s in *; clear s.
      unfold s0 in Hin; simpl in Hin. inversion Hin.
    - unfold transition in Heqsom; simpl in Heqsom.
      destruct l as [[c0 v0] |]; destruct om as [msg|].
      + specialize (IHP1 s _om eq_refl).
        destruct s as [j0 Hj0].  specialize (IHP2 _s (Some msg) eq_refl).
        unfold add_message_sorted in Heqsom. destruct msg as [[(c1, v1) [j1 Hj1]] Hmsg].
        simpl in Heqsom.
        inversion Heqsom; subst; clear Heqsom. simpl in Hv. destruct Hv as [Hejc0 [Hrj10 Hnh10]].
        assert (IHcvj := IHP1 c v j). 
        destruct j as [j Hj].
        simpl in *.
        repeat rewrite in_state_add_in_sorted_iff in Hin.
        destruct Hin as [Heq | [Heq | Hin]]; try (inversion Heq; subst; clear Heq).
        * inversion P2; try (destruct im as [m Him]; contradiction).
          { destruct l as [[c1' v1']|]; destruct om as [msg|].
          - destruct s as [j1' Hj1'].
            inversion H0; subst; clear H0.
            split.
            + specialize (IHP2 c1 v1 (exist _ j1 Hj)).
            destruct msg as [[(c2, v2) [j2 Hj2]] Hmsg2]. simpl in IHP2.
            assert (Hin : in_state (c1, v1, j1) (add_in_sorted_fn (c2, v2, j2) (add_in_sorted_fn (c1, v1, j1) j1)))
              by (apply add_preserves_message_membership; apply in_state_add_in_sorted_iff; left; reflexivity).
            specialize (IHP2 Hin). destruct IHP2 as [P _]. assumption.
            + apply add_preserves_inclusion. assumption.
          - destruct s as [j1' Hj1']. inversion H0; subst; clear H0.
            simpl in Hv. destruct Hv as [Hej1c1 _].
            split.
            + specialize (IHP2 c1 v1 (exist _ j1 Hj)).
              simpl in IHP2.
              assert (Hin : in_state (c1, v1, j1) (add_in_sorted_fn (c1, v1, j1) j1))
                by (apply in_state_add_in_sorted_iff; left; reflexivity).
              specialize (IHP2 Hin). destruct IHP2 as [P _]. assumption.
            + apply add_preserves_inclusion. assumption.
          - inversion H0.
          - inversion H0.
          }
        * { split.
          - specialize protocol_generated; intro PG.
            specialize 
              (PG (VLSM_full_client1) (Some (c0, v0))
                  (exist (fun s : CBC.Definitions.state => locally_sorted s) j0 Hj0)
                  _om
                  P1
                  (proj1_sig s0)
                  None
                  (protocol_initial_state (VLSM_full_client1) s0)
              ).
            simpl in PG.
            replace Hj with Hj0; try apply proof_irrelevance. apply PG.
            split; auto.
          - repeat apply add_preserves_inclusion. apply incl_refl.
          }
        * specialize (IHcvj Hin). destruct IHcvj as [Pcvj Hjj0].
          split; try assumption.
          repeat apply add_preserves_inclusion. assumption.
      + specialize (IHP1 s _om eq_refl). assert (IHcvj := IHP1 c v j). 
        destruct s as [j0 Hj0]. inversion Heqsom; subst; clear Heqsom.
        destruct j as [j Hj].  simpl in Hin. rewrite in_state_add_in_sorted_iff in Hin.
        simpl in IHcvj. destruct Hin as [Heq | Hin]; try (inversion Heq; subst; clear Heq).
        * clear IHcvj. simpl. split; try (apply add_preserves_inclusion; apply incl_refl).
          specialize protocol_generated; intro PG.
          specialize 
            (PG (VLSM_full_client1) (Some (c0, v0))
                (exist (fun s : CBC.Definitions.state => locally_sorted s) j0 Hj0)
                _om
                P1
                (proj1_sig s0)
                None
                (protocol_initial_state (VLSM_full_client1) s0)
                Hv
            ).
          simpl in PG.
          replace Hj with Hj0 by apply proof_irrelevance.
          assumption.
        * specialize (IHcvj Hin). destruct IHcvj as [Pcvj Hincl]. simpl. split; try assumption.
          apply add_preserves_inclusion. assumption.
      + inversion Heqsom; subst; clear Heqsom.
        specialize (IHP1 s _om eq_refl). destruct s as [s Hs].
        assert (IHcvj := IHP1 c v j). destruct j as [j Hj].
        specialize (IHP2 _s (Some msg) eq_refl).
        destruct msg as [[(cm, vm) [jm Hjm]] Hmsg]. simpl in Hin.
        rewrite in_state_add_in_sorted_iff in Hin.
        destruct Hin as [Heq | Hin]; try (inversion Heq; subst; clear Heq).
        * simpl. simpl in Hv. destruct Hv as [Hincl Hnh].
          { split.
          - inversion P2; try (destruct im as [m Him]; inversion Him).
            destruct l as [[c1' v1']|]; destruct om as [msg|].
            + destruct s0 as [j1' Hj1'].
              inversion H0; subst; clear H0.
              specialize (IHP2 cm vm (exist _ jm Hjm)).
              destruct msg as [[(c2, v2) [j2 Hj2]] Hmsg2]. simpl in IHP2.
              assert (Hin : in_state (cm, vm, jm) (add_in_sorted_fn (c2, v2, j2) (add_in_sorted_fn (cm, vm, jm) jm)))
                by (apply add_preserves_message_membership; apply in_state_add_in_sorted_iff; left; reflexivity).
              specialize (IHP2 Hin). destruct IHP2 as [P _].
              replace Hj with Hjm by apply proof_irrelevance.
              assumption.
             + destruct s0 as [j1' Hj1'].
               inversion H0; subst; clear H0.
                replace Hj1' with Hj in P2 by apply proof_irrelevance.
                replace Hmsg with I in P2 by apply proof_irrelevance.
                replace Hjm with Hj in P2 by apply proof_irrelevance.
                assumption.
             + inversion H0.
             + inversion H0.
           - apply add_preserves_inclusion. assumption. 
           }
        * specialize (IHcvj Hin). destruct IHcvj as [Pcvj Hincl]; split; try assumption.
          simpl in *. apply add_preserves_inclusion. assumption.
      + inversion Heqsom; subst; clear Heqsom.
        specialize (IHP1 s0 _om eq_refl). assert (IHcvj := IHP1 c v j Hin). assumption.
  Qed.

  Lemma protocol_state_generated_message
    (s : @state _ VLSM_type_full_client1)
    (m : {msg : sorted_message C V | proto_message_prop msg})
    (P : (protocol_prop VLSM_full_client1) (s, Some m))
    : in_state (proj1_sig m) (proj1_sig s).
  Proof.
    inversion P; try (destruct im as [im Him]; inversion Him).
    destruct l as [[c0 v0] |]; destruct om as [msg|]
    ; inversion H0; subst; clear H0
    ; destruct s0 as [j0 Hj0]
    ; try
      ( destruct msg as [[(cm, vm) [jm Hjm]] _Hmsg]
        ; apply in_state_add_in_sorted_iff; right
      )
    ; apply in_state_add_in_sorted_iff; left
    ; reflexivity
    .
  Qed.

  Lemma protocol_state_equiv_right :
    forall (s : @state _ VLSM_type_full_client1),
      (protocol_state_prop VLSM_full_client1) s
      ->
      (@CBC.Definitions.protocol_state C V message_type Hm Hrt He_proj1 PS_proj1) (proj1_sig s).
  Proof.
    intros. destruct H as [om P]. remember (s, om) as som.
    generalize dependent om. generalize dependent s.
    induction P; intros.
    - destruct is as [is His]. unfold s in *. clear s.
      simpl in Heqsom. rewrite His in Heqsom. inversion Heqsom; subst; clear Heqsom.
      constructor.
    - destruct im as [m Him]. inversion Him.
    - assert (P0 : protocol_prop (VLSM_full_client1) (s0, om0))
      by (rewrite <- Heqsom; apply (protocol_generated (VLSM_full_client1) l s _om P1 _s om P2 Hv)).
      specialize (protocol_state_messages s0 om0 P0); intro Hmsgs.
      specialize (IHP1 s _om eq_refl).
      specialize (IHP2 _s om eq_refl).
      unfold transition in Heqsom; simpl in Heqsom.
      destruct l as [[c0 v0] |]; destruct om as [msg|].
      + destruct s as [j0 Hj0].
        specialize (protocol_state_generated_message _ _ P2); simpl; intro Hin_s.
        inversion Heqsom; subst; clear Heqsom. 
        destruct msg as [[(cm, vm) jm] _Hmsg].
        assert (Hmsg := Hmsgs cm vm jm).
        destruct jm as [jm Hjm]. simpl in Hmsg.
        assert (Hin : in_state (cm, vm, jm) (add_in_sorted_fn (cm, vm, jm) (add_in_sorted_fn (c0, v0, j0) j0)))
          by (apply in_state_add_in_sorted_iff; left; reflexivity).
        specialize (Hmsg Hin).
        destruct Hmsg as [Pmsg Hincl].
        simpl in Hv. destruct Hv as [Hest [Hincl_m0 Hnh]].
        unfold estimator in Hest; simpl in Hest.
        simpl. constructor; try assumption.
        * apply copy_protocol_state; try assumption.
          unfold estimator. simpl. unfold estimator_proj1.
            rewrite (make_already_sorted_state j0 Hj0). assumption.
        * apply (protocol_state_justification _ IHP2 _ Hin_s).
        * apply (protocol_state_valid_estimate _ IHP2 _ Hin_s).
      + destruct s as [j0 Hj0]. inversion Heqsom; subst; clear Heqsom.
        simpl in Hv. destruct Hv as [Hv _]. simpl in IHP1.
        apply copy_protocol_state; try assumption.
        unfold valid_estimate. unfold estimator. simpl. unfold estimator_proj1. rewrite (make_already_sorted_state j0 Hj0). assumption.
      + inversion Heqsom; subst; clear Heqsom.
        destruct msg as [[(cm, vm) jm] _Hmsg].
        specialize (Hmsgs cm vm jm).
        destruct jm as [jm Hjm]. destruct s as [s Hs]. simpl in Hmsgs.
        simpl in Hv. destruct Hv as [Hincl_jms Hnh].
        simpl.
        specialize (protocol_state_generated_message _ _ P2); simpl; intro Hin_s.
        constructor; try assumption.
        * apply (protocol_state_justification _ IHP2 _ Hin_s).
        * apply (protocol_state_valid_estimate _ IHP2 _ Hin_s).
      + inversion Heqsom; subst; clear Heqsom. assumption.
  Qed.


  Lemma protocol_state_equiv :
    forall (s : @state _ VLSM_type_full_client1),
      (@CBC.Definitions.protocol_state C V message_type Hm Hrt He_proj1 PS_proj1) (proj1_sig s)
      <->
      (protocol_state_prop VLSM_full_client1) s.
  Proof.
    intros; split; intros.
    - apply protocol_state_equiv_left; assumption.
    - apply protocol_state_equiv_right; assumption.
  Qed.

  (* Reachability *)
  (* VLSM reachability defined in terms of protocol traces (transition and validity) *) 
(*   Definition vlsm_next : protocol_state -> protocol_state -> Prop :=
    fun s1 s2 => protocol_trace_prop (Finite [s1; s2]).
  Lemma next_equiv :
    forall (s1 s2 : protocol_state),
      vlsm_next s1 s2 <->
      exists (msg : @message C V), add_in_sorted_fn msg (proj1_sig (proj1_sig s1)) = proj1_sig (proj1_sig s2).
  Proof. Admitted.
 *)

  Definition vlsm_reach : protocol_state VLSM_full_client1 -> protocol_state VLSM_full_client1 -> Prop :=
    fun s1 s2 => exists (ls : list (@in_state_out _ VLSM_type_full_client1)), finite_ptrace (VLSM_full_client1) (proj1_sig s1) ls /\ List.In (proj1_sig s2) (List.map (@destination _ VLSM_type_full_client1) ls).

  Lemma reach_equiv :
    forall (s1 s2 : protocol_state (VLSM_full_client1)),
      vlsm_reach s1 s2 <->
      incl (get_messages (proj1_sig (proj1_sig s1))) (get_messages (proj1_sig (proj1_sig s2))).
  Proof. Admitted.
  
  (* VLSM state union *)
  Lemma join_protocol_state :
    forall (s1 s2 : @state _ VLSM_type_full_client1),
      protocol_state_prop (VLSM_full_client1) s1 ->
      protocol_state_prop (VLSM_full_client1) s2 -> 
      not_heavy (proj1_sig (sorted_state_union s1 s2)) -> 
      protocol_state_prop (VLSM_full_client1) (sorted_state_union s1 s2). 
  Proof. 
  Admitted.

  Program Definition protocol_state_union (s1 s2 : protocol_state (VLSM_full_client1)) (H_weight : not_heavy (sorted_state_union (proj1_sig s1) (proj1_sig s2))) : protocol_state (VLSM_full_client1)
  := exist (protocol_state_prop  (VLSM_full_client1)) (sorted_state_union (proj1_sig s1) (proj1_sig s2)) _.
  Next Obligation.
    destruct s1 as [s1 about_s1];
      destruct s2 as [s2 about_s2].
    now apply join_protocol_state. 
  Defined.
  
  Lemma vlsm_reach_morphism :
    forall (s1 s2 : protocol_state (VLSM_full_client1)) (H_weight : not_heavy (proj1_sig (sorted_state_union (proj1_sig s1) (proj1_sig s2)))),
      vlsm_reach s1 (protocol_state_union s1 s2 H_weight).
  Proof. Admitted.

  (* cf. this and the other definition of reach? *) 
  
  Theorem pair_common_futures :
    forall (s1 s2 : protocol_state (VLSM_full_client1)),
      not_heavy (proj1_sig (sorted_state_union (proj1_sig s1) (proj1_sig s2))) ->
      exists (s3 : protocol_state (VLSM_full_client1)),
        vlsm_reach s1 s3 /\ vlsm_reach s2 s3. 
  Proof. 
    intros.
    remember (sorted_state_union (proj1_sig s1) (proj1_sig s2)) as s3.
    assert (about_s3 : protocol_state_prop (VLSM_full_client1) s3).
    red.
  Admitted. 

(*   Theorem strong_nontriviality :
    forall (s1 : protocol_state),
    exists (s2 : protocol_state),
      vlsm_reach s1 s2 /\
      exists (s3 : protocol_state),
      forall (tr2 : protocol_trace_from (fun s => s = s2))
        (tr3 : protocol_trace_from (fun s => s = s3)),
        (exists (s : protocol_state),
            in_trace s tr2 /\ in_trace s tr3 -> False). 
  Proof. 
  Admitted. 
  
 *)
  (* 2.5.1 Minimal full client protocol: Client2 *) 
  Definition label2 : Type := unit.    

  Definition vtransition2 (l : unit) (sm : @sorted_state C V message_type * option message) : @sorted_state C V message_type * option message :=
    match l with
    | tt => match (snd sm) with
           | None => (fst sm, None)
           | Some msg => (add_message_sorted (proj1_sig msg) (fst sm), None)
           end
    end. 
  
  Inductive valid_client2 : unit -> (@sorted_state C V message_type) * option message -> Prop :=
  | client2_none : forall (s : @sorted_state C V message_type), valid_client2 tt (s, None)
  | client2_receive : forall (s : @sorted_state C V message_type) (m : message),
      reach (justification (proj1_sig m)) s -> not_heavy (add_in_sorted_fn (proj1_sig m) s) ->
      valid_client2 tt (add_message_sorted (proj1_sig m) s, Some m).

  Instance VLSM_type_full_client2 : VLSM_type message :=
    { state := @sorted_state C V message_type
    ; label := label2
    }.

  Instance LSM_full_client2 : LSM_sig VLSM_type_full_client2 :=
    { initial_state_prop := initial_state_prop
    ; initial_message_prop := initial_message_prop
    ; s0 := state0
    ; m0 := proto_message0
    ; l0 := tt
    }.

  Instance VLSM_full_client2  : VLSM LSM_full_client2 := 
    { transition := vtransition2
      ; valid := valid_client2
    }.

  (* Section 2.5.2  Minimal full validator protocol for name v: Validator(v) *)
  Definition labelv : Type := option C.

  Definition vtransitionv (v : V) (l : labelv) (sm : @sorted_state C V message_type * option message) : @sorted_state C V message_type * option message :=
    match l with
    | None => match (snd sm) with
             | None => sm 
             | Some msg => (add_message_sorted (proj1_sig msg) (fst sm), None)
           end
    | Some c => (add_message_sorted (c,v, fst sm) (fst sm), Some (make_proto_message (c,v, fst sm)))
    end. 
  
  Inductive valid_validator : labelv ->  @sorted_state C V message_type * option message -> Prop :=
  | validator_none : forall (s : @sorted_state C V message_type), valid_validator None (s, None)
  | validator_receive : forall (s : @sorted_state C V message_type) (m : message), reach (justification (proj1_sig m)) s -> valid_validator None (s, Some m)
  | validator_send : forall (c : C) (s : state) (m : option message), (@estimator (@sorted_state C V message_type) C He) s c -> valid_validator (Some c) (s, m).

  Instance VLSM_type_full_validator : VLSM_type message :=
    { state := @sorted_state C V message_type
    ; label := labelv
    }.

  Instance LSM_full_validator : LSM_sig VLSM_type_full_validator :=
    { initial_state_prop := initial_state_prop
    ; initial_message_prop := initial_message_prop
    ; s0 := state0
    ; m0 := proto_message0
    ; l0 := None
    }.

  Instance VLSM_full_validator (v : V) : VLSM LSM_full_validator := 
    { transition := vtransitionv v
      ; valid := valid_validator
    }.

  Parameter validators : list V.
  Parameter finite_validators : Listing validators.
  Parameter v0 : V.  (* non-empty set of validators *)

  Let n : nat := length validators.

  Lemma n_gt_0 : n > 0.
  Proof.
    destruct finite_validators as [_ Hfull].
    specialize (Hfull v0).
    destruct validators.
    - try inversion Hfull.
    - unfold n. simpl. apply lt_0_Sn.
  Qed.

  Parameter n' : nat. (* number of clients *)


  Definition IT_index : Fin.t (n + n') -> VLSM_type message :=
    fun i =>
      match proj1_sig (Fin.to_nat i) ?= n with
      | Gt => VLSM_type_full_client2
      | _ => VLSM_type_full_validator
      end.

  Definition IS_index : forall i : Fin.t (n + n'), LSM_sig (IT_index i).
  intros. unfold IT_index.
  destruct (proj1_sig (Fin.to_nat i) ?= n) eqn:Hi.
  - exact LSM_full_validator.
  - exact LSM_full_validator.
  - exact LSM_full_client2.
  Defined.

  Definition IM_index : forall i : Fin.t (n + n'), VLSM (IS_index i).
  intros.
  unfold IT_index. unfold IS_index. 
  remember (proj1_sig (Fin.to_nat i)) as ni.
  destruct (ni ?= n) eqn:Hi.
  - exact (VLSM_full_validator (nth (ni - 1) validators v0)).
  - exact (VLSM_full_validator (nth (ni - 1) validators v0)).
  - exact VLSM_full_client2.
  Defined.

  Fixpoint fin_listing (m : nat) : list (Fin.t m) :=
    match m with
      | 0 => []
      | S n => Fin.F1 :: List.map Fin.FS (fin_listing n)
    end.
  
  Lemma fin_finite (m : nat) : Listing (fin_listing m).
  Proof.
    induction m.
    - split; try constructor. red. inversion a.
    - destruct IHm as [Hnodup Hfull].
      split.
      + simpl. constructor.
        * intro Hin. apply in_map_iff in Hin.
          destruct Hin as [x [Hcontra Hin]]. inversion Hcontra.
        * apply Injective_map_NoDup; try assumption.
          intros x y Heq.
          apply FS_inj.
          assumption.
      + intro a. simpl. apply (caseS'  a (fun a => F1 = a \/ In a (List.map FS (fin_listing m)))).
        * left. reflexivity.
        * intro p. right.
          apply in_map. apply Hfull.
  Qed.

  Instance fin_eq_dec : EqDec (Fin.t (n + n')) := (@Fin.eq_dec (n + n')). 

  Definition nlst := n + n' - 1.

  Lemma nlst_S : S nlst = n + n'.
  Proof.
    unfold nlst.
    specialize n_gt_0; intro Hn. destruct n.
    - inversion Hn.
    - simpl. f_equal. symmetry. apply minus_n_O.
  Qed.

  Definition f1_n_plus_n' : Fin.t (n + n').
  specialize (@F1 nlst). rewrite nlst_S. intro; assumption.
  Defined.

  Definition VLSM_full_composed : VLSM (indexed_sig f1_n_plus_n' IS_index)
    := indexed_vlsm_free f1_n_plus_n' IM_index.

End Full.
