Require Import RelationClasses.

From Paco Require Import paco.
From sflib Require Import sflib.

From PromisingLib Require Import Axioms.
From PromisingLib Require Import Basic.
From PromisingLib Require Import DataStructure.
From PromisingLib Require Import Language.
From PromisingLib Require Import Loc.
Require Import Time.
From PromisingLib Require Import Event.
Require Import View.
Require Import Cell.
Require Import Memory.
Require Import TView.
Require Import Local.
Require Import BoolMap.
Require Import Global.
Require Import Thread.
Require Import Configuration.
Require Import Behavior.

Set Implicit Arguments.



Module Trace.

  Definition t := list (Local.t * ThreadEvent.t).

  Inductive steps lang: forall (tr: t) (th0 th1: Thread.t lang), Prop :=
  | steps_refl
      th0
    :
      steps [] th0 th0
  | steps_step
      tr tr' th0 th1 th2 e
      (STEP: Thread.step e th0 th1)
      (STEPS: steps tr th1 th2)
      (TR: tr' = ((Thread.local th0), e) :: tr)
    :
      steps tr' th0 th2
  .
  #[global] Hint Constructors steps: core.

  Inductive steps_n1 lang: t -> (Thread.t lang) -> (Thread.t lang) -> Prop :=
  | steps_n1_refl
      th0
    :
      steps_n1 [] th0 th0
  | steps_n1_step
      th0 th1 th2 hds tle
      (HD: steps_n1 hds th0 th1)
      (TL: Thread.step tle th1 th2)
    :
      steps_n1 (hds++[((Thread.local th1), tle)]) th0 th2
  .
  #[global] Hint Constructors steps_n1: core.

  Lemma steps_n1_one lang (th0 th1: Thread.t lang) e
        (STEP: Thread.step e th0 th1)
    :
      steps_n1 [((Thread.local th0), e)] th0 th1.
  Proof.
    erewrite <- List.app_nil_l at 1. econs; eauto.
  Qed.

  Lemma steps_n1_trans lang (th0 th1 th2: Thread.t lang) tr0 tr1
        (STEPS0: steps_n1 tr0 th0 th1)
        (STEPS1: steps_n1 tr1 th1 th2)
    :
      steps_n1 (tr0 ++ tr1) th0 th2.
  Proof.
    ginduction STEPS1; i; ss.
    - erewrite List.app_nil_r. auto.
    - rewrite List.app_assoc. econs; eauto.
  Qed.

  Lemma steps_one lang (th0 th1: Thread.t lang) e
        (STEP: Thread.step e th0 th1)
    :
      steps [((Thread.local th0), e)] th0 th1.
  Proof.
    econs 2; eauto.
  Qed.

  Lemma steps_trans lang (th0 th1 th2: Thread.t lang) tr0 tr1
        (STEPS0: steps tr0 th0 th1)
        (STEPS1: steps tr1 th1 th2)
    :
      steps (tr0 ++ tr1) th0 th2.
  Proof.
    ginduction STEPS0; i; ss. subst. econs; eauto.
  Qed.

  Lemma steps_equivalent lang (th0 th1: Thread.t lang) tr
    :
        steps tr th0 th1 <-> steps_n1 tr th0 th1.
  Proof.
    split; intros STEP.
    - ginduction STEP.
      + econs.
      + exploit steps_n1_trans.
        * eapply steps_n1_one; eauto.
        * eauto.
        * ss. clarify.
    - ginduction STEP.
      + econs.
      + eapply steps_trans; eauto.
  Qed.

  Lemma steps_separate lang (th0 th2: Thread.t lang) tr0 tr1
        (STEPS: steps (tr0++tr1) th0 th2)
    :
      exists th1,
        (<<STEPS0: steps tr0 th0 th1>>) /\
        (<<STEPS1: steps tr1 th1 th2>>).
  Proof.
    ginduction tr0; i; ss.
    - exists th0. splits; ss.
    - inv STEPS. inv TR. eapply IHtr0 in STEPS0. des.
      exists th1. splits; ss.
      econs; eauto.
  Qed.

  Lemma steps_in lang P (th0 th1: Thread.t lang) tr e th
        (STEPS: steps tr th0 th1)
        (IN: List.In (th, e) tr)
        (PRED: List.Forall P tr)
    :
      exists th' th'' tr0 tr1,
        (<<STEPS0: steps tr0 th0 th'>>) /\
        (<<STEP: Thread.step e th' th''>>) /\
        (<<STEPS1: steps tr1 th'' th1>>) /\
        (<<TRACES: tr = tr0 ++ [(th, e)] ++ tr1>>) /\
        (<<SAT: P (th, e)>>).
  Proof.
    ginduction STEPS; i; ss. inv PRED; ss. des; clarify.
    - exists th0, th1. esplits; eauto.
    - exploit IHSTEPS; eauto. i. des. subst.
      exists th', th''. esplits; eauto.
  Qed.

  Lemma steps_disjoint
        lang tr (e1 e2: Thread.t lang) lc
        (STEPS: steps tr e1 e2)
        (WF1: Local.wf (Thread.local e1) (Thread.global e1))
        (GL1: Global.wf (Thread.global e1))
        (DISJOINT1: Local.disjoint (Thread.local e1) lc)
        (WF: Local.wf lc (Thread.global e1)):
    (<<DISJOINT2: Local.disjoint (Thread.local e2) lc>>) /\
    (<<WF: Local.wf lc (Thread.global e2)>>).
  Proof.
    induction STEPS; eauto. subst.
    exploit Thread.step_disjoint; eauto. i. des.
    exploit Thread.step_future; eauto. i. des.
    eapply IHSTEPS; eauto.
  Qed.


  Lemma steps_future
        lang tr e1 e2
        (STEPS: @steps lang tr e1 e2)
        (WF1: Local.wf (Thread.local e1) (Thread.global e1))
        (GL1: Global.wf (Thread.global e1)):
    (<<WF2: Local.wf (Thread.local e2) (Thread.global e2)>>) /\
    (<<GL2: Global.wf (Thread.global e2)>>) /\
    (<<TVIEW_FUTURE: TView.le (Local.tview (Thread.local e1)) (Local.tview (Thread.local e2))>>) /\
    (<<GL_FUTURE: Global.future (Thread.global e1) (Thread.global e2)>>)
  .
  Proof.
    ginduction STEPS.
    - i. splits; auto.
      + refl.
      + refl.
    - i. exploit Thread.step_future; eauto. i. des.
      exploit IHSTEPS; eauto. i. des. splits; auto.
      + etrans; eauto.
      + etrans; eauto.
  Qed.

  Lemma silent_steps_tau_steps lang tr (th0 th1: Thread.t lang)
        (STEPS: steps tr th0 th1)
        (SILENT: List.Forall (fun the => ThreadEvent.get_machine_event (snd the) = MachineEvent.silent) tr)
    :
      rtc (Thread.tau_step (lang:=lang)) th0 th1.
  Proof.
    ginduction STEPS; auto. i. inv SILENT; clarify. econs 2.
    - econs; eauto.
    - eauto.
  Qed.

  Lemma tau_steps_silent_steps lang (th0 th1: Thread.t lang)
        (STEPS: rtc (Thread.tau_step (lang:=lang)) th0 th1)
    :
      exists tr,
        (<<STEPS: steps tr th0 th1>>) /\
        (<<SILENT: List.Forall (fun the => ThreadEvent.get_machine_event (snd the) = MachineEvent.silent) tr>>).
  Proof.
    ginduction STEPS; eauto. inv H. des.
    exists (((Thread.local x), e)::tr). splits; eauto.
  Qed.

  Lemma steps_app lang tr0 tr1 (th0 th1 th2: Thread.t lang)
        (STEPS0: steps tr0 th0 th1)
        (STEPS1: steps tr1 th1 th2)
    :
      steps (tr0 ++ tr1) th0 th2.
  Proof.
    ginduction STEPS0; eauto. i. subst. econs; eauto.
  Qed.

  Definition consistent lang (e:Thread.t lang) (tr: t): Prop :=
    exists e2,
      (<<STEPS: steps tr (Thread.cap_of e) e2>>) /\
      (<<SILENT: List.Forall (fun lce => ThreadEvent.get_machine_event (snd lce) = MachineEvent.silent) tr>>) /\
      ((<<FAILURE: exists e e3,
           Thread.step e e2 e3 /\
           ThreadEvent.get_machine_event e = MachineEvent.failure>>) \/
       (<<PROMISES: (Local.promises (Thread.local e2)) = BoolMap.bot>>)).

  Lemma consistent_thread_consistent lang (e: Thread.t lang) tr
        (CONSISTENT: consistent e tr)
    :
      Thread.consistent e.
  Proof.
    ii. rr in CONSISTENT. des.
    { econs 1. econs.
      { eapply silent_steps_tau_steps in STEPS; eauto. }
      { eauto. }
      { ss. }
    }
    { econs 2.
      { eapply silent_steps_tau_steps in STEPS; eauto. }
      { eauto. }
    }
  Qed.

  Lemma thread_consistent_consistent lang (e: Thread.t lang)
        (CONSISTENT: Thread.consistent e)
        (CLOSED: Global.wf (Thread.global e))
    :
      exists tr,
        (<<CONSISTENT: consistent e tr>>).
  Proof.
    inv CONSISTENT.
    { inv FAILURE.
      eapply tau_steps_silent_steps in STEPS. des.
      exists tr. rr. esplits; eauto.
    }
    { eapply tau_steps_silent_steps in STEPS. des.
      exists tr. rr. esplits; eauto.
    }
  Qed.

  Lemma plus_step_steps
        lang tr e1 e2 e3 e
        (STEPS: @steps lang tr e1 e2)
        (STEP: Thread.step e e2 e3):
    steps (tr ++ [((Thread.local e2), e)]) e1 e3.
  Proof.
    rewrite steps_equivalent in *. eauto.
  Qed.

  Lemma steps_inv
        lang tr e1 e2 lc e
        (STEPS: @steps lang tr e1 e2)
        (WF1: Local.wf (Thread.local e1) (Thread.global e1))
        (GL1: Global.wf (Thread.global e1))
        (EVENT: List.In (lc, e) tr):
    exists tr' tr'' e2' e3,
      (<<STEPS: steps tr' e1 e2'>>) /\
      (<<TRACE: tr = tr' ++ tr''>>) /\
      (<<LC: (Thread.local e2') = lc>>) /\
      (<<STEP: Thread.step e e2' e3>>).
  Proof.
    rewrite steps_equivalent in STEPS.
    induction STEPS; ss.
    apply List.in_app_or in EVENT. des.
    - exploit IHSTEPS; eauto.
      i. des. subst. esplits; eauto.
      rewrite <- List.app_assoc. refl.
    - inv EVENT; ss. inv H.
      rewrite <- steps_equivalent in STEPS.
      esplits; eauto.
  Qed.

  Inductive configuration_step: forall (tr: Trace.t) (e:MachineEvent.t) (tid:Ident.t) (c1 c2:Configuration.t), Prop :=
  | configuration_step_intro
      lang tr e tr' tid c1 st1 lc1 e2 st3 lc3 gl3
      (TID: IdentMap.find tid (Configuration.threads c1) = Some (existT _ lang st1, lc1))
      (STEPS: Trace.steps tr' (Thread.mk _ st1 lc1 (Configuration.global c1)) e2)
      (SILENT: List.Forall (fun the => ThreadEvent.get_machine_event (snd the) = MachineEvent.silent) tr')
      (STEP: Thread.step e e2 (Thread.mk _ st3 lc3 gl3))
      (TR: tr = tr'++[((Thread.local e2), e)])
      (CONSISTENT: forall (EVENT: ThreadEvent.get_machine_event e <> MachineEvent.failure),
          Thread.consistent (Thread.mk _ st3 lc3 gl3))
    :
      configuration_step tr (ThreadEvent.get_machine_event e) tid c1 (Configuration.mk (IdentMap.add tid (existT _ _ st3, lc3) (Configuration.threads c1)) gl3)
  .

  Lemma step_configuration_step tr e tid c1 c2
        (STEP: configuration_step tr e tid c1 c2)
    :
      Configuration.step e tid c1 c2.
  Proof.
    inv STEP. eapply silent_steps_tau_steps in STEPS; eauto.
  Qed.

  Lemma configuration_step_step e tid c1 c2
        (STEP: Configuration.step e tid c1 c2)
    :
      exists tr,
        (<<STEP: configuration_step tr e tid c1 c2>>).
  Proof.
    inv STEP.
    replace MachineEvent.failure with (ThreadEvent.get_machine_event ThreadEvent.failure); auto.
    eapply tau_steps_silent_steps in STEPS. des. esplits.
    econs; eauto.
  Qed.

End Trace.

Module ThreadTrace.

  Definition t (lang: language) := list (Thread.t lang * ThreadEvent.t).

  Inductive steps lang: forall (tr: t lang) (th0 th1: Thread.t lang), Prop :=
  | steps_refl
      th0
    :
      steps [] th0 th0
  | steps_step
      tr tr' th0 th1 th2 e
      (STEP: Thread.step e th0 th1)
      (STEPS: steps tr th1 th2)
      (TR: tr' = (th0, e) :: tr)
    :
      steps tr' th0 th2
  .
  #[global] Hint Constructors steps: core.

  Lemma steps_trans lang (th0 th1 th2: Thread.t lang) tr0 tr1
        (STEPS0: steps tr0 th0 th1)
        (STEPS1: steps tr1 th1 th2)
    :
      steps (tr0 ++ tr1) th0 th2.
  Proof.
    ginduction STEPS0; i; ss. subst. econs; eauto.
  Qed.

  Lemma steps_separate lang (th0 th2: Thread.t lang) tr0 tr1
        (STEPS: steps (tr0++tr1) th0 th2)
    :
      exists th1,
        (<<STEPS0: steps tr0 th0 th1>>) /\
        (<<STEPS1: steps tr1 th1 th2>>).
  Proof.
    ginduction tr0; i; ss.
    - exists th0. splits; ss.
    - inv STEPS. inv TR. eapply IHtr0 in STEPS0. des.
      exists th1. splits; ss.
      econs; eauto.
  Qed.

  Lemma steps_future
        lang tr e1 e2
        (STEPS: @steps lang tr e1 e2)
        (WF1: Local.wf (Thread.local e1) (Thread.global e1))
        (GL1: Global.wf (Thread.global e1)):
    (<<WF2: Local.wf (Thread.local e2) (Thread.global e2)>>) /\
    (<<GL2: Global.wf (Thread.global e2)>>) /\
    (<<TVIEW_FUTURE: TView.le (Local.tview (Thread.local e1)) (Local.tview (Thread.local e2))>>) /\
    (<<GL_FUTURE: Global.future (Thread.global e1) (Thread.global e2)>>)
  .
  Proof.
    ginduction STEPS.
    - i. splits; auto.
      + refl.
      + refl.
    - i. exploit Thread.step_future; eauto. i. des.
      exploit IHSTEPS; eauto. i. des. splits; auto.
      + etrans; eauto.
      + etrans; eauto.
  Qed.

  Lemma trace_steps_thread_trace_steps lang (th0 th1: Thread.t lang) tr
        (STEPS: Trace.steps tr th0 th1)
    :
      exists ttr,
        (<<STEPS: steps ttr th0 th1>>) /\
        (<<MATCH: List.Forall2
                    (fun the lce =>
                       (Thread.local (fst the)) = (fst lce) /\
                       (snd the) = (snd lce)) ttr tr>>).
  Proof.
    ginduction STEPS; eauto. i. subst. des. esplits.
    { econs; eauto. }
    { econs; eauto. }
  Qed.

  Lemma thread_trace_steps_trace_steps lang (th0 th1: Thread.t lang) ttr
        (STEPS: steps ttr th0 th1)
    :
      exists tr,
        (<<STEPS: Trace.steps tr th0 th1>>) /\
        (<<MATCH: List.Forall2
                    (fun the lce =>
                       (Thread.local (fst the)) = (fst lce) /\
                       (snd the) = (snd lce)) ttr tr>>).
  Proof.
    ginduction STEPS; eauto. i. subst. des. esplits.
    { econs; eauto. }
    { econs; eauto. }
  Qed.

End ThreadTrace.
