From sflib Require Import sflib.
From Paco Require Import paco.

From PromisingLib Require Import Basic.
From PromisingLib Require Import Loc.
From PromisingLib Require Import Event.
From PromisingLib Require Import Language.

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

Set Implicit Arguments.


(* NOTE: We currently consider only finite behaviors of program: we
 * ignore non-terminating executions.  This simplification affects two
 * aspects of the development:
 *
 * - Liveness.  In our definition, the liveness matters only for
 *   non-terminating execution.
 *
 * - Simulation.  We do not introduce simulation index for inftau
 *   behaviors (i.e. infinite loop without system call interactions).
 *
 * We will consider infinite behaviors in the future work.
 *)
(* NOTE: We serialize all the events within a behavior, but it may not
 * be the case.  The *NIX kernels are re-entrant: system calls may
 * race.
 *)

Inductive behaviors (step: forall (e: MachineEvent.t) (tid: Ident.t) (c1 c2: Configuration.t), Prop):
  forall (c: Configuration.t) (b: list Event.t) (f: bool), Prop :=
| behaviors_nil
    c
    (TERMINAL: Configuration.is_terminal c):
    behaviors step c nil true
| behaviors_syscall
    e1 e2 tid c1 c2 beh f
    (STEP: step (MachineEvent.syscall e2) tid c1 c2)
    (NEXT: behaviors step c2 beh f)
    (EVENT: Event.le e1 e2):
    behaviors step c1 (e1::beh) f
| behaviors_failure
    tid c1 c2 beh f
    (STEP: step MachineEvent.failure tid c1 c2):
    behaviors step c1 beh f
| behaviors_tau
    tid c1 c2 beh f
    (STEP: step MachineEvent.silent tid c1 c2)
    (NEXT: behaviors step c2 beh f):
    behaviors step c1 beh f
| behaviors_partial_term
    c:
    behaviors step c [] false
.

Lemma rtc_tau_step_behavior
      step c1 c2 b f
      (STEPS: rtc (union (step MachineEvent.silent)) c1 c2)
      (BEH: behaviors step c2 b f):
  behaviors step c1 b f.
Proof.
  revert BEH. induction STEPS; auto. inv H.
  i. specialize (IHSTEPS BEH). econs 4; eauto.
Qed.

Lemma le_step_behavior_improve
      sem0 sem1
      (STEPLE: sem0 <4= sem1):
  behaviors sem0 <3= behaviors sem1.
Proof.
  i. ginduction PR; i.
  - econs 1; eauto.
  - econs 2; eauto.
  - econs 3; eauto.
  - econs 4; eauto.
  - econs 5; eauto.
Qed.

Inductive behaviors_partial
          (step: forall (e:MachineEvent.t) (tid:Ident.t) (c1 c2:Configuration.t), Prop):
  forall (conf1 conf2:Configuration.t) (b:list Event.t), Prop :=
| behaviors_partial_nil
    c:
    behaviors_partial step c c nil
| behaviors_partial_syscall
    e tid c1 c2 c3 beh
    (STEP: step (MachineEvent.syscall e) tid c1 c2)
    (NEXT: behaviors_partial step c2 c3 beh):
    behaviors_partial step c1 c3 (e::beh)
| behaviors_partial_tau
    tid c1 c2 c3 beh
    (STEP: step MachineEvent.silent tid c1 c2)
    (NEXT: behaviors_partial step c2 c3 beh):
    behaviors_partial step c1 c3 beh
.

Lemma rtc_tau_step_behavior_partial
      step c1 c2 c3 b
      (STEPS: rtc (union (step MachineEvent.silent)) c1 c2)
      (BEH: behaviors_partial step c2 c3 b):
  behaviors_partial step c1 c3 b.
Proof.
  revert BEH. induction STEPS; auto. inv H.
  i. specialize (IHSTEPS BEH). econs 3; eauto.
Qed.

Lemma behaviors_partial_app_partial
      step c1 c2 c3 b1 b2
      (BEH1: behaviors_partial step c1 c2 b1)
      (BEH2: behaviors_partial step c2 c3 b2)
  :
    behaviors_partial step c1 c3 (b1 ++ b2).
Proof.
  induction BEH1.
  - eauto.
  - econs 2; eauto.
  - econs 3; eauto.
Qed.

Lemma behaviors_partial_app
      step c1 c2 b1 b2 f
      (BEH1: behaviors_partial step c1 c2 b1)
      (BEH2: behaviors step c2 b2 f)
  :
    behaviors step c1 (b1 ++ b2) f.
Proof.
  induction BEH1.
  - eauto.
  - econs 2; eauto. refl.
  - econs 4; eauto.
Qed.
