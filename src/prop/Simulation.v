From sflib Require Import sflib.
From Paco Require Import paco.

From PromisingLib Require Import Axioms.
From PromisingLib Require Import Basic.
From PromisingLib Require Import Loc.
From PromisingLib Require Import Language.
From PromisingLib Require Import Event.

Require Import Time.
Require Import View.
Require Import BoolMap.
Require Import Promises.
Require Import Reserves.
Require Import Cell.
Require Import Memory.
Require Import Global.
Require Import TView.
Require Import Local.
Require Import Thread.
Require Import Configuration.
Require Import Behavior.

Set Implicit Arguments.


Section Simulation.
  Definition SIM := forall (c1_src c1_tgt: Configuration.t), Prop.

  Definition _sim (sim: SIM) (c1_src c1_tgt:Configuration.t): Prop :=
    (<<TERMINAL:
      forall (TERMINAL_TGT: Configuration.is_terminal c1_tgt),
        (<<FAILURE: Configuration.steps_failure c1_src>>) \/
        exists c2_src,
          (<<STEPS_SRC: rtc Configuration.tau_step c1_src c2_src>>) /\
          (<<TERMINAL_SRC: Configuration.is_terminal c2_src>>)>>) /\
    (<<STEP:
      forall e tid c2_tgt
        (STEP_TGT: Configuration.step e tid c1_tgt c2_tgt),
        (<<FAILURE: Configuration.steps_failure c1_src>>) \/
        exists c2_src,
          (<<EVENT: e <> MachineEvent.failure>>) /\
          (<<STEP_SRC: Configuration.opt_step e tid c1_src c2_src>>) /\
          (<<SIM: sim c2_src c2_tgt>>)>>)
  .

  Lemma _sim_mon: monotone2 _sim.
  Proof.
    ii. red in IN. des.
    econs; eauto. ii.
    exploit STEP; eauto. i. des; eauto.
    right. esplits; eauto.
  Qed.
  Hint Resolve _sim_mon: paco.

  Definition sim: SIM := paco2 _sim bot2.
End Simulation.
#[export] Hint Resolve _sim_mon: paco.


Lemma sim_adequacy
      c_src c_tgt
      (SIM: sim c_src c_tgt):
  behaviors Configuration.step c_tgt <2= behaviors Configuration.step c_src.
Proof.
  i. revert c_src SIM.
  induction PR; i.
  - punfold SIM0. red in SIM0. des.
    hexploit TERMINAL0; eauto. i. des.
    + inv FAILURE.
      eapply rtc_tau_step_behavior; eauto. econs 3; eauto.
    + eapply rtc_tau_step_behavior; eauto. econs 1; eauto.
  - punfold SIM0. red in SIM0. des.
    exploit STEP0; eauto. i. des.
    + inv FAILURE.
      eapply rtc_tau_step_behavior; eauto. econs 3; eauto.
    + inv SIM0; [|done]. inv STEP_SRC. econs 2; eauto.
  - punfold SIM0. red in SIM0. des.
    exploit STEP0; eauto. i. des; ss.
    inv FAILURE.
    eapply rtc_tau_step_behavior; eauto. econs 3; eauto.
  - punfold SIM0. red in SIM0. des.
    exploit STEP0; eauto. i. des.
    + inv FAILURE.
      eapply rtc_tau_step_behavior; eauto. econs 3; eauto.
    + inv SIM0; [|done]. inv STEP_SRC; eauto. econs 4; eauto.
  - econs 5.
Qed.
