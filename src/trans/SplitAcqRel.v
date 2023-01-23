From sflib Require Import sflib.
From Paco Require Import paco.

From PromisingLib Require Import Axioms.
From PromisingLib Require Import Basic.
From PromisingLib Require Import Loc.
From PromisingLib Require Import DataStructure.
From PromisingLib Require Import DenseOrder.
From PromisingLib Require Import Language.
From PromisingLib Require Import Event.

Require Import Time.
Require Import View.
Require Import BoolMap.
Require Import Promises.
Require Import Cell.
Require Import Memory.
Require Import Global.
Require Import TView.
Require Import Local.
Require Import Thread.
Require Import Configuration.

Require Import SimLocal.
Require Import SimMemory.
Require Import SimGlobal.
Require Import SimThread.
Require Import Compatibility.

Require Import SimLocalAdvance.

Require Import ITreeLang.
Require Import ITreeLib.

Set Implicit Arguments.


Variant split_acqrel: forall R (i1: MemE.t R) (i2: MemE.t R), Prop :=
| split_acqrel_load
    l:
    split_acqrel (MemE.read l Ordering.acqrel) (MemE.read l Ordering.relaxed)
| split_acqrel_update
    l rmw ow
    (OW: Ordering.le ow Ordering.acqrel):
    split_acqrel (MemE.update l rmw Ordering.acqrel ow) (MemE.update l rmw Ordering.relaxed ow)
.

Variant sim_acqrel: forall R
                      (st_src:(Language.state (lang R))) (lc_src:Local.t) (gl1_src:Global.t)
                      (st_tgt:(Language.state (lang R))) (lc_tgt:Local.t) (gl1_tgt:Global.t), Prop :=
| sim_acqrel_intro
    R
    lc1_src gl1_src
    lc1_tgt gl1_tgt
    (LOCAL: sim_local lc1_src (local_acqrel lc1_tgt))
    (GLOBAL: sim_global gl1_src gl1_tgt)
    (LC_WF_SRC: Local.wf lc1_src gl1_src)
    (LC_WF_TGT: Local.wf lc1_tgt gl1_tgt)
    (GL_WF_SRC: Global.wf gl1_src)
    (GL_WF_TGT: Global.wf gl1_tgt)
    (r: R):
    sim_acqrel
      (Ret r) lc1_src gl1_src
      (Vis (MemE.fence Ordering.acqrel Ordering.acqrel) (fun _ => Ret r)) lc1_tgt gl1_tgt
.

Lemma sim_local_sim_acqrel
      R (r: R)
      lc_src gl_src
      lc_tgt gl_tgt
      (SIM: sim_local lc_src lc_tgt)
      (GLOBAL: sim_global gl_src gl_tgt)
      (LC_WF_SRC: Local.wf lc_src gl_src)
      (LC_WF_TGT: Local.wf lc_tgt gl_tgt)
      (GL_WF_SRC: Global.wf gl_src)
      (GL_WF_TGT: Global.wf gl_tgt):
  sim_acqrel (Ret r) lc_src gl_src
             (Vis (MemE.fence Ordering.acqrel Ordering.acqrel) (fun _ => Ret r)) lc_tgt gl_tgt.
Proof.
  econs; eauto.
  inv SIM. econs; ss. etrans; eauto.
  etrans; [|eapply TViewFacts.write_fence_tview_incr];
    try eapply TViewFacts.read_fence_tview_incr.
  - apply LC_WF_TGT.
  - exploit TViewFacts.read_fence_future; try eapply LC_WF_TGT; ss. i. des. eauto.
Qed.

Lemma sim_acqrel_mon
      R
      st_src lc_src gl1_src
      st_tgt lc_tgt gl1_tgt
      gl2_src
      gl2_tgt
      (SIM1: sim_acqrel st_src lc_src gl1_src
                        st_tgt lc_tgt gl1_tgt)
      (GLOBAL: sim_global gl2_src gl2_tgt)
      (LC_WF_SRC: Local.wf lc_src gl2_src)
      (LC_WF_TGT: Local.wf lc_tgt gl2_tgt)
      (GL_WF_SRC: Global.wf gl2_src)
      (GL_WF_TGT: Global.wf gl2_tgt):
  @sim_acqrel R
              st_src lc_src gl2_src
              st_tgt lc_tgt gl2_tgt.
Proof.
  destruct SIM1. econs; eauto.
Qed.

Lemma sim_acqrel_step
      R
      st1_src lc1_src gl1_src
      st1_tgt lc1_tgt gl1_tgt
      (SIM: sim_acqrel st1_src lc1_src gl1_src
                       st1_tgt lc1_tgt gl1_tgt):
  _sim_thread_step (lang R) (lang R)
                   ((@sim_thread (lang R) (lang R) (sim_terminal eq)) \6/ @sim_acqrel R)
                   st1_src lc1_src gl1_src
                   st1_tgt lc1_tgt gl1_tgt.
Proof.
  destruct SIM. ii.
  inv STEP_TGT; ss.
  - (* internal *)
    right.
    exploit Local.internal_step_future; eauto. i. des.
    exploit sim_local_internal_acqrel; try exact LOCAL; eauto. i. des.
    exploit Local.internal_step_future; eauto. i. des.
    esplits; try exact GLOBAL2; eauto.
    + inv LOCAL0; ss.
    + right. econs; eauto.
  - (* fence *)
    right.
    inv LOCAL0; dependent destruction STATE.
    exploit Local.fence_step_future; eauto. i. des.
    exploit Local.fence_step_non_sc; eauto. i. subst.
    esplits; (try by econs 1); eauto; ss.
    left. eapply paco9_mon; [apply sim_itree_ret|]; ss.
    inv LOCAL. ss. econs; try by (inv LOCAL1; ss).
Qed.

Lemma sim_acqrel_sim_thread R:
  @sim_acqrel R <6= @sim_thread (lang R) (lang R) (sim_terminal eq).
Proof.
  pcofix CIH. i. pfold. ii. ss. splits; ss; ii.
  - inv TERMINAL_TGT. inv PR; ss.
  - right. esplits; eauto.
    inv PR. eapply sim_local_promises_bot; eauto.
  - exploit sim_acqrel_mon; eauto. i. des.
    exploit sim_acqrel_step; eauto. i. des; eauto.
    + right. esplits; eauto.
      left. eapply paco9_mon; eauto. ss.
    + right. esplits; eauto.
Qed.

Lemma split_acqrel_sim_itree R
      (i_src i_tgt: MemE.t R)
      (SPLIT: split_acqrel i_src i_tgt):
  sim_itree eq
            (ITree.trigger i_src)
            (r <- ITree.trigger i_tgt;; ITree.trigger (MemE.fence Ordering.acqrel Ordering.acqrel);; Ret r).
Proof.
  replace (ITree.trigger i_src) with (Vis i_src (fun r => Ret r)).
  2: { unfold ITree.trigger. grind. }
  replace (r <- ITree.trigger i_tgt;; ITree.trigger (MemE.fence Ordering.acqrel Ordering.acqrel);; Ret r) with
      (Vis i_tgt (fun r => Vis (MemE.fence Ordering.acqrel Ordering.acqrel) (fun _ => Ret r))).
  2: { unfold ITree.trigger. grind. repeat f_equal. extensionality r. grind.
       repeat f_equal. extensionality u. grind. }
  pcofix CIH. ii. subst. pfold. ii. splits; ii.
  { inv TERMINAL_TGT. apply f_equal with (f:=observe) in H; ss. }
  { right. esplits; eauto.
    eapply sim_local_promises_bot; eauto.
  }
  inv STEP_TGT; ss; [|inv LOCAL0; destruct SPLIT; dependent destruction STATE; ss].
  - (* internal *)
    right.
    exploit sim_local_internal; eauto. i. des.
    esplits; try apply GL2; eauto; ss.
    inv LOCAL0; ss.
  - (* load *)
    clarify.
    right.
    exploit Local.read_step_future; eauto. i. des.
    exploit sim_local_read_acquired; eauto. i. des.
    exploit Local.read_step_future; eauto. i. des.
    esplits.
    + ss.
    + refl.
    + econs 2. econs 2; [|econs 2]; eauto. econs. refl.
    + ss.
    + ss.
    + left. eapply paco9_mon; [apply sim_acqrel_sim_thread|]; ss.
      econs; ss. inv LOCAL2. econs; ss.
      etrans; eauto. apply TViewFacts.write_fence_tview_incr.
      eapply TViewFacts.read_fence_future; apply LC_WF2.
  - (* update-load *)
    clarify.
    right.
    exploit Local.read_step_future; eauto. i. des.
    exploit sim_local_read_acquired; eauto. i. des.
    exploit Local.read_step_future; eauto. i. des.
    esplits.
    + ss.
    + refl.
    + econs 2. econs 2; [|econs 2]; eauto. econs; eauto.
    + ss.
    + ss.
    + left. eapply paco9_mon; [apply sim_acqrel_sim_thread|]; ss.
      econs; ss. inv LOCAL2. econs; ss.
      etrans; eauto. apply TViewFacts.write_fence_tview_incr.
      eapply TViewFacts.read_fence_future; apply LC_WF2.
  - (* update *)
    right.
    exploit Local.update_step_future; eauto. i. des.
    hexploit sim_local_update_acqrel; eauto; try refl. i. des.
    exploit Local.update_step_future; eauto. i. des.
    esplits.
    + ss.
    + refl.
    + econs 2. econs 2; [|econs 4]; eauto. econs; eauto.
    + ss.
    + ss.
    + left. eapply paco9_mon; [apply sim_acqrel_sim_thread|]; ss.
  - (* racy read *)
    right.
    exploit sim_local_racy_read_acquired; try exact LOCAL1; eauto. i. des.
    esplits.
    + ss.
    + refl.
    + econs 2. econs 2; [|econs 8]; eauto. econs. refl.
    + ss.
    + ss.
    + left. eapply paco9_mon; [apply sim_acqrel_sim_thread|]; ss.
      eapply sim_local_sim_acqrel; ss.
  - (* racy read *)
    right.
    exploit sim_local_racy_read_acquired; try exact LOCAL1; eauto. i. des.
    esplits.
    + ss.
    + refl.
    + econs 2. econs 2; [|econs 8]; eauto. econs; eauto.
    + ss.
    + ss.
    + left. eapply paco9_mon; [apply sim_acqrel_sim_thread|]; ss.
      eapply sim_local_sim_acqrel; ss.
  - (* racy update *)
    left.
    exploit sim_local_racy_update_acquired; try exact LOCAL1; eauto. i. des.
    econs; try refl.
    + econs 2; [|econs 10]; eauto. econs; eauto.
    + ss.
Qed.
