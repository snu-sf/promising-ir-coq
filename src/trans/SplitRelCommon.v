From sflib Require Import sflib.
From Paco Require Import paco.

From PromisingLib Require Import Basic.
From PromisingLib Require Import Loc.
From PromisingLib Require Import Language.

From PromisingLib Require Import Event.
Require Import Time.
Require Import View.
Require Import Cell.
Require Import Memory.
Require Import TView.
Require Import Local.
Require Import Thread.
Require Import Configuration.

Require Import FulfillStep.

Require Import SimMemory.
Require Import SimPromises.
Require Import SimLocal.
Require Import SimThread.

Set Implicit Arguments.


Lemma sim_local_fulfill_released
      lc1_src sc1_src mem1_src
      lc1_tgt sc1_tgt mem1_tgt
      lc2_tgt sc2_tgt
      loc from to val releasedm_src releasedm_tgt released
      (RELM_LE: View.opt_le releasedm_src releasedm_tgt)
      (RELM_WF: View.opt_wf releasedm_src)
      (RELM_CLOSED: Memory.closed_opt_view releasedm_src mem1_src)
      (WF_RELM_TGT: View.opt_wf releasedm_tgt)
      (STEP_TGT: fulfill_step lc1_tgt sc1_tgt loc from to val releasedm_tgt released Ordering.strong_relaxed lc2_tgt sc2_tgt)
      (LOCAL1: sim_local SimPromises.bot lc1_src lc1_tgt)
      (RELEASED1: View.le (TView.cur (Local.tview lc1_tgt)) (View.join ((TView.rel (Local.tview lc1_tgt)) loc) (View.singleton_ur loc to)))
      (SC1: TimeMap.le sc1_src sc1_tgt)
      (MEM1: sim_memory mem1_src mem1_tgt)
      (WF1_SRC: Local.wf lc1_src mem1_src)
      (WF1_TGT: Local.wf lc1_tgt mem1_tgt)
      (SC1_SRC: Memory.closed_timemap sc1_src mem1_src)
      (SC1_TGT: Memory.closed_timemap sc1_tgt mem1_tgt)
      (MEM1_SRC: Memory.closed mem1_src)
      (MEM1_TGT: Memory.closed mem1_tgt):
  exists lc2_src sc2_src,
    <<STEP_SRC: fulfill_step lc1_src sc1_src loc from to val releasedm_src released Ordering.acqrel lc2_src sc2_src>> /\
    <<LOCAL2: sim_local SimPromises.bot lc2_src lc2_tgt>> /\
    <<SC2: TimeMap.le sc2_src sc2_tgt>>.
Proof.
  inv STEP_TGT.
  assert (RELT_LE:
   View.opt_le
     (TView.write_released (Local.tview lc1_src) sc1_src loc to releasedm_src Ordering.acqrel)
     (TView.write_released (Local.tview lc1_tgt) sc2_tgt loc to releasedm_tgt Ordering.strong_relaxed)).
  { unfold TView.write_released, TView.write_tview. ss. viewtac;
      try econs; repeat (condtac; aggrtac); try apply WF1_TGT.
    rewrite <- View.join_r. etrans; eauto. apply LOCAL1.
  }
  assert (RELT_WF:
   View.opt_wf (TView.write_released (Local.tview lc1_src) sc1_src loc to releasedm_src Ordering.acqrel)).
  { unfold TView.write_released. condtac; econs.
    repeat (try condtac; viewtac; try apply WF1_SRC).
  }
  exploit SimPromises.remove_bot; try exact REMOVE;
    try exact MEM1; try apply LOCAL1; eauto.
  i. des. esplits.
  - econs; eauto.
    inv WRITABLE. econs; ss. eapply TimeFacts.le_lt_lt; [apply LOCAL1|apply TS].
  - econs; eauto. s.
    unfold TView.write_tview, View.singleton_ur_if. repeat (condtac; aggrtac).
    econs; repeat (condtac; aggrtac);
      (try by etrans; [apply LOCAL1|aggrtac]);
      (try by rewrite <- ? View.join_r; econs; aggrtac);
      (try apply WF1_TGT).
    + ss. i. unfold LocFun.find. repeat (condtac; aggrtac).
      * etrans; eauto. apply LOCAL1.
      * apply LOCAL1.
    + ss. aggrtac; try apply WF1_TGT. rewrite <- ? View.join_l. apply LOCAL1.
    + ss. aggrtac; try apply WF1_TGT. rewrite <- ? View.join_l. apply LOCAL1.
  - ss.
Qed.

Lemma sim_local_write_released
      lc1_src sc1_src mem1_src
      lc1_tgt sc1_tgt mem1_tgt
      lc2_tgt sc2_tgt mem2_tgt
      loc from to val releasedm_src releasedm_tgt released_tgt kind
      (RELM_LE: View.opt_le releasedm_src releasedm_tgt)
      (RELM_SRC_WF: View.opt_wf releasedm_src)
      (RELM_SRC_CLOSED: Memory.closed_opt_view releasedm_src mem1_src)
      (RELM_TGT_WF: View.opt_wf releasedm_tgt)
      (RELM_TGT_CLOSED: Memory.closed_opt_view releasedm_tgt mem1_tgt)
      (STEP_TGT: Local.write_step lc1_tgt sc1_tgt mem1_tgt loc from to val releasedm_tgt released_tgt Ordering.strong_relaxed lc2_tgt sc2_tgt mem2_tgt kind)
      (LOCAL1: sim_local SimPromises.bot lc1_src lc1_tgt)
      (RELEASED1: View.le (TView.cur (Local.tview lc1_tgt)) (View.join ((TView.rel (Local.tview lc1_tgt)) loc) (View.singleton_ur loc to)))
      (SC1: TimeMap.le sc1_src sc1_tgt)
      (MEM1: sim_memory mem1_src mem1_tgt)
      (WF1_SRC: Local.wf lc1_src mem1_src)
      (WF1_TGT: Local.wf lc1_tgt mem1_tgt)
      (SC1_SRC: Memory.closed_timemap sc1_src mem1_src)
      (SC1_TGT: Memory.closed_timemap sc1_tgt mem1_tgt)
      (MEM1_SRC: Memory.closed mem1_src)
      (MEM1_TGT: Memory.closed mem1_tgt):
  exists released_src lc2_src sc2_src mem2_src,
    <<STEP_SRC: Local.write_step lc1_src sc1_src mem1_src loc from to val releasedm_src released_src Ordering.acqrel lc2_src sc2_src mem2_src kind>> /\
    <<REL2: View.opt_le released_src released_tgt>> /\
    <<LOCAL2: sim_local SimPromises.bot lc2_src lc2_tgt>> /\
    <<SC2: TimeMap.le sc2_src sc2_tgt>> /\
    <<MEM2: sim_memory mem2_src mem2_tgt>>.
Proof.
  exploit write_promise_fulfill; eauto. i. des.
  exploit Local.promise_step_future; eauto. i. des.
  exploit sim_local_promise_bot; eauto. i. des.
  exploit Local.promise_step_future; eauto. i. des.
  exploit sim_local_fulfill_released; try apply STEP2;
    try apply LOCAL2; try apply MEM2; eauto.
  { eapply Memory.future_closed_opt_view; eauto. }
  { by inv STEP1. }
  i. des.
  exploit promise_fulfill_write_sim_memory; try exact STEP_SRC; try exact STEP_SRC0; eauto.
  { i. hexploit ORD; eauto. i. des. splits; ss.
    eapply sim_local_nonsynch_loc; eauto.
  }
  i. des. esplits; eauto. etrans; eauto.
Qed.

Lemma sim_local_racy_write_released
      lc1_src sc1_src mem1_src
      lc1_tgt sc1_tgt mem1_tgt
      loc to
      (STEP_TGT: Local.racy_write_step lc1_tgt mem1_tgt loc to Ordering.strong_relaxed)
      (LOCAL1: sim_local SimPromises.bot lc1_src lc1_tgt)
      (SC1: TimeMap.le sc1_src sc1_tgt)
      (MEM1: sim_memory mem1_src mem1_tgt)
      (WF1_SRC: Local.wf lc1_src mem1_src)
      (WF1_TGT: Local.wf lc1_tgt mem1_tgt)
      (SC1_SRC: Memory.closed_timemap sc1_src mem1_src)
      (SC1_TGT: Memory.closed_timemap sc1_tgt mem1_tgt)
      (MEM1_SRC: Memory.closed mem1_src)
      (MEM1_TGT: Memory.closed mem1_tgt):
  <<STEP_SRC: Local.racy_write_step lc1_src mem1_src loc to Ordering.acqrel>>.
Proof.
  exploit sim_local_racy_write; try exact STEP_TGT;
    try exact LOCAL1; try exact SC1; try exact MEM1; try refl; eauto. i. des.
  inv x0. econs; eauto.
  inv RACE. econs; eauto.
Qed.

Lemma sim_local_racy_update_released
      lc1_src sc1_src mem1_src
      lc1_tgt sc1_tgt mem1_tgt
      loc to ordr
      (STEP_TGT: Local.racy_update_step lc1_tgt mem1_tgt loc to ordr Ordering.strong_relaxed)
      (LOCAL1: sim_local SimPromises.bot lc1_src lc1_tgt)
      (SC1: TimeMap.le sc1_src sc1_tgt)
      (MEM1: sim_memory mem1_src mem1_tgt)
      (WF1_SRC: Local.wf lc1_src mem1_src)
      (WF1_TGT: Local.wf lc1_tgt mem1_tgt)
      (SC1_SRC: Memory.closed_timemap sc1_src mem1_src)
      (SC1_TGT: Memory.closed_timemap sc1_tgt mem1_tgt)
      (MEM1_SRC: Memory.closed mem1_src)
      (MEM1_TGT: Memory.closed mem1_tgt):
  <<STEP_SRC: Local.racy_update_step lc1_src mem1_src loc to ordr Ordering.acqrel>>.
Proof.
  exploit sim_local_racy_update; try exact STEP_TGT;
    try exact LOCAL1; try exact SC1; try exact MEM1; try refl; eauto. i. des.
  inv x0.
  - econs 1; eauto.
  - econs 2; eauto.
  - econs 3; eauto.
Qed.
