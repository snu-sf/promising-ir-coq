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

Require Import Progress.

Require Import SimLocal.
Require Import SimMemory.
Require Import SimGlobal.
Require Import SimThread.
Require Import Compatibility.

Require Import ReorderStep.

Require Import ITreeLang.
Require Import ITreeLib.

Set Implicit Arguments.


Inductive reorder_fence (or1 ow1:Ordering.t): forall R (i2:MemE.t R), Prop :=
| reorder_fence_load
    l2 o2
    (ORDR1: Ordering.le or1 Ordering.acqrel)
    (ORDW1: Ordering.le ow1 Ordering.relaxed)
    (ORD2: Ordering.le o2 Ordering.plain \/ Ordering.le Ordering.acqrel o2):
    reorder_fence or1 ow1 (MemE.read l2 o2)
| reorder_fence_store
    l2 v2 o2
    (ORDR1: Ordering.le or1 Ordering.acqrel)
    (ORDW1: Ordering.le ow1 Ordering.relaxed)
    (ORD2: Ordering.le Ordering.plain o2):
    reorder_fence or1 ow1 (MemE.write l2 v2 o2)
| reorder_fence_update
    l2 rmw2 or2 ow2
    (ORDR1: Ordering.le or1 Ordering.acqrel)
    (ORDW1: Ordering.le ow1 Ordering.relaxed)
    (ORDR2: Ordering.le or2 Ordering.plain \/ Ordering.le Ordering.acqrel or2):
    reorder_fence or1 ow1 (MemE.update l2 rmw2 or2 ow2)
.

Inductive sim_fence: forall R
                            (st_src:itree MemE.t (unit * R)%type) (lc_src:Local.t) (sc1_src:TimeMap.t) (mem1_src:Memory.t)
                            (st_tgt:itree MemE.t (unit * R)%type) (lc_tgt:Local.t) (sc1_tgt:TimeMap.t) (mem1_tgt:Memory.t), Prop :=
| sim_fence_intro
    R
    or1 ow1 (i2: MemE.t R)
    lc1_src sc1_src mem1_src
    lc1_tgt sc1_tgt mem1_tgt
    lc2_src sc2_src
    (REORDER: reorder_fence or1 ow1 i2)
    (FENCE: Local.fence_step lc1_src sc1_src or1 ow1 lc2_src sc2_src)
    (LOCAL: sim_local SimPromises.bot lc2_src lc1_tgt):
    sim_fence
      (Vis i2 (fun v2 => Vis (MemE.fence or1 ow1) (fun v1 => Ret (v1, v2)))) lc1_src sc1_src mem1_src
      (Vis i2 (fun r => Ret (tt, r))) lc1_tgt sc1_tgt mem1_tgt
.

Lemma read_fence_wf
      tview ord
      (WF: TView.wf tview):
  TView.wf (TView.read_fence_tview tview ord).
Proof.
  inv WF. econs; ss; condtac; eauto. refl.
Qed.

Lemma sim_fence_sim_local
      R
      st_src lc_src sc_src mem_src
      st_tgt lc_tgt sc_tgt mem_tgt
      (WF_SRC: TView.wf lc_src.(Local.tview))
      (SIM: @sim_fence R st_src lc_src sc_src mem_src st_tgt lc_tgt sc_tgt mem_tgt):
  sim_local SimPromises.bot lc_src lc_tgt.
Proof.
  inv SIM. inv FENCE. inv LOCAL. ss.
  econs; eauto. etrans; eauto.
  etrans; cycle 1.
  { eapply TViewFacts.write_fence_tview_incr.
    eapply read_fence_wf; eauto.
  }
  eapply TViewFacts.read_fence_tview_incr. apply WF_SRC.
Qed.

Lemma sim_fence_step
      R
      st1_src lc1_src sc0_src mem0_src
      st1_tgt lc1_tgt sc0_tgt mem0_tgt
      (SIM: sim_fence st1_src lc1_src sc0_src mem0_src
                      st1_tgt lc1_tgt sc0_tgt mem0_tgt):
  forall sc1_src sc1_tgt
    mem1_src mem1_tgt
    (SC: TimeMap.le sc1_src sc1_tgt)
    (MEMORY: sim_memory mem1_src mem1_tgt)
    (SC_FUTURE_SRC: TimeMap.le sc0_src sc1_src)
    (SC_FUTURE_TGT: TimeMap.le sc0_tgt sc1_tgt)
    (MEM_FUTURE_SRC: Memory.future_weak mem0_src mem1_src)
    (MEM_FUTURE_TGT: Memory.future_weak mem0_tgt mem1_tgt)
    (WF_SRC: Local.wf lc1_src mem1_src)
    (WF_TGT: Local.wf lc1_tgt mem1_tgt)
    (SC_SRC: Memory.closed_timemap sc1_src mem1_src)
    (SC_TGT: Memory.closed_timemap sc1_tgt mem1_tgt)
    (MEM_SRC: Memory.closed mem1_src)
    (MEM_TGT: Memory.closed mem1_tgt),
  _sim_thread_step (lang (unit * R)%type) (lang (unit * R)%type)
                   ((@sim_thread (lang (unit * R)%type) (lang (unit * R)%type) (sim_terminal eq)) \8/ @sim_fence R)
                     st1_src lc1_src sc1_src mem1_src
                     st1_tgt lc1_tgt sc1_tgt mem1_tgt.
Proof.
  i. exploit sim_fence_sim_local; eauto; try apply WF_SRC. intro SIM_LC.
  destruct SIM. ii.
  exploit future_fence_step; try apply FENCE; eauto; i.
  { inv REORDER; etrans; eauto. }
  inv STEP_TGT; [inv STEP|dependent destruction STEP; inv LOCAL0; ss; dependent destruction STATE; inv REORDER]; ss.
  - (* promise *)
    right.
    exploit sim_local_promise; try exact LOCAL; eauto.
    { eapply Local.fence_step_future; eauto. }
    i. des.
    exploit reorder_fence_promise; try apply x0; try apply STEP_SRC; eauto.
    { inv REORDER; ss. }
    i. des.
    esplits; try apply SC; eauto; ss.
    + econs 2. econs 1. econs; eauto.
    + eauto.
    + right. econs; eauto.
  - (* load *)
    right.
    guardH ORD2.
    exploit sim_local_read; try exact LOCAL0; try exact LOCAL; try apply SC; eauto; try refl; viewtac.
    { eapply Local.fence_step_future; eauto. }
    i. des.
    exploit reorder_fence_read; try apply x0; try apply STEP_SRC; eauto; try by viewtac. i. des.
    esplits.
    + ss.
    + econs 2; [|econs 1]. econs.
      * econs. econs 2. econs; [|econs 2]; eauto. econs. econs.
      * eauto.
    + econs 2. econs 2. econs; [|econs 5]; eauto. econs. econs.
    + auto.
    + etrans; eauto.
    + auto.
    + left. eapply paco11_mon; [apply sim_itree_ret|]; ss.
      etrans; eauto.
  - (* update-load *)
    right.
    guardH ORDR2.
    exploit sim_local_read; try exact LOCAL0; try exact LOCAL; try apply SC; eauto; try refl; viewtac.
    { eapply Local.fence_step_future; eauto. }
    i. des.
    exploit reorder_fence_read; try apply x0; try apply STEP_SRC; eauto; try by viewtac. i. des.
    esplits.
    + ss.
    + econs 2; [|econs 1]. econs.
      * econs. econs 2. econs; [|econs 2]; eauto. econs; eauto.
      * eauto.
    + econs 2. econs 2. econs; [|econs 5]; eauto. econs. econs.
    + auto.
    + etrans; eauto.
    + auto.
    + left. eapply paco11_mon; [apply sim_itree_ret|]; ss.
      etrans; eauto.
  - (* store *)
    right.
    hexploit sim_local_write_bot; try exact LOCAL1; try exact LOCAL; try apply SC;
      try match goal with
          | [|- is_true (Ordering.le _ _)] => refl
          end; eauto; try refl; viewtac.
    { eapply Local.fence_step_future; eauto. }
    i. des.
    exploit reorder_fence_write; try apply x0; try apply STEP_SRC; eauto; try by viewtac. i. des.
    esplits.
    + ss.
    + econs 2; [|econs 1]. econs.
      * econs. econs 2. econs; [|econs 3]; eauto. econs. econs.
      * eauto.
    + econs 2. econs 2. econs; [|econs 5]; eauto. econs. econs.
    + auto.
    + etrans; eauto.
    + etrans; eauto.
    + left. eapply paco11_mon; [apply sim_itree_ret|]; ss.
      etrans; eauto.
  - (* update *)
    right.
    guardH ORDR2.
    exploit Local.read_step_future; eauto. i. des.
    exploit sim_local_read; try exact LOCAL1; try exact LOCAL; try apply SC; eauto; try refl; viewtac.
    { eapply Local.fence_step_future; eauto. }
    i. des.
    exploit reorder_fence_read; try apply x0; try apply STEP_SRC; eauto; try by viewtac. i. des.
    exploit Local.read_step_future; eauto. i. des.
    exploit Local.fence_step_future; eauto. i. des.
    generalize LOCAL3. i. rewrite LOCAL0 in LOCAL3.
    generalize SC0. i. rewrite SC in SC1.
    hexploit sim_local_write_bot; try exact LOCAL2; try apply SC1; eauto; try refl; viewtac. i. des.
    exploit reorder_fence_write; try apply STEP2; try apply STEP_SRC0; eauto; try by viewtac. i. des.
    esplits.
    + ss.
    + econs 2; [|econs 1]. econs.
      * econs. econs 2. econs; [|econs 4]; eauto. econs; eauto.
      * eauto.
    + econs 2. econs 2. econs; [|econs 5]; eauto. econs. econs.
    + auto.
    + etrans; eauto.
    + etrans; eauto.
    + left. eapply paco11_mon; [apply sim_itree_ret|]; ss.
      etrans; eauto.
  - (* na write *)
    inv LOCAL1. destruct ord; ss.
  - (* racy read *)
    right. guardH ORD2.
    exploit sim_local_racy_read; try exact SIM_LC; eauto; try refl. i. des.
    esplits.
    + ss.
    + econs 2; [|econs 1]. econs.
      * econs. econs 2. econs; [|econs 9]; eauto. econs. econs.
      * eauto.
    + econs 2. econs 2. econs; [|econs 5]; eauto. econs. econs.
    + auto.
    + ss.
    + ss.
    + left. eapply paco11_mon; [apply sim_itree_ret|]; ss.
  - (* racy read *)
    right. guardH ORDR2.
    exploit sim_local_racy_read; try exact SIM_LC; eauto; try refl. i. des.
    esplits.
    + ss.
    + econs 2; [|econs 1]. econs.
      * econs. econs 2. econs; [|econs 9]; eauto. econs; eauto.
      * eauto.
    + econs 2. econs 2. econs; [|econs 5]; eauto. econs. econs.
    + auto.
    + ss.
    + ss.
    + left. eapply paco11_mon; [apply sim_itree_ret|]; ss.
  - (* racy write *)
    left.
    exploit sim_local_racy_write; try exact LOCAL1; try exact SIM_LC;
      try match goal with
          | [|- is_true (Ordering.le _ _)] => refl
          end; eauto.
    i. des.
    unfold Thread.steps_failure. esplits; try refl.
    + econs 2. econs; [|econs 10]; eauto. econs. econs.
    + ss.
  - (* racy update *)
    left. guardH ORDR2.
    exploit sim_local_racy_update; try exact LOCAL1; try exact SIM_LC;
      try match goal with
          | [|- is_true (Ordering.le _ _)] => refl
          end; eauto.
    i. des.
    unfold Thread.steps_failure. esplits; try refl.
    + econs 2. econs; [|econs 11]; eauto. econs; eauto.
    + ss.
Qed.

Lemma sim_fence_sim_thread R:
  @sim_fence R <8= @sim_thread (lang (unit * R)%type) (lang (unit * R)%type) (sim_terminal eq).
Proof.
  pcofix CIH. i. pfold. ii. ss. splits; ss; ii.
  - right. inv TERMINAL_TGT. inv PR; ss.
  - right. esplits; eauto.
    inv PR. inversion FENCE. subst lc2_src. inversion LOCAL. ss.
    apply SimPromises.sem_bot_inv in PROMISES0; auto. rewrite PROMISES0. auto.
  - exploit sim_fence_step; try apply PR; try apply SC; eauto. i. des; eauto.
    + right. esplits; eauto.
      left. eapply paco11_mon; eauto. ss.
    + right. esplits; eauto.
Qed.
