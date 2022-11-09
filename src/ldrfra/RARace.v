Require Import Lia.
Require Import Bool.
Require Import RelationClasses.
Require Import Program.

From sflib Require Import sflib.
From Paco Require Import paco.

From PromisingLib Require Import Axioms.
From PromisingLib Require Import Basic.
From PromisingLib Require Import DataStructure.
From PromisingLib Require Import DenseOrder.
From PromisingLib Require Import Loc.
From PromisingLib Require Import Language.
From PromisingLib Require Import Event.

Require Import Time.
Require Import View.
Require Import BoolMap.
Require Import Promises.
Require Import Cell.
Require Import Memory.
Require Import TView.
Require Import Global.
Require Import Local.
Require Import Thread.
Require Import Configuration.
Require Import PFConfiguration.
Require Import Behavior.

Require Import OrdStep.
Require Import Writes.
Require Import WStep.

Set Implicit Arguments.


Module RARace.
Section RARACE.
  Variable L: Loc.t -> bool.

  Definition wr_race (loc: Loc.t) (to: Time.t) (ordw: Ordering.t) (tview: TView.t) (ord: Ordering.t): Prop :=
    (<<LOC: L loc>>) /\
    (<<HIGHER: Time.lt ((View.rlx (TView.cur tview)) loc) to>>) /\
    ((<<ORDW: Ordering.le ordw Ordering.strong_relaxed>>) \/
     (<<ORDR: Ordering.le ord Ordering.strong_relaxed>>)).

  Definition ww_race (loc: Loc.t) (to: Time.t) (ordw: Ordering.t) (tview: TView.t) (ord: Ordering.t): Prop :=
    (<<LOC: L loc>>) /\
    (<<HIGHER: Time.lt ((View.rlx (TView.cur tview)) loc) to>>) /\
    ((<<ORDW1: Ordering.le ordw Ordering.na>>) \/
     (<<ORDW2: Ordering.le ord Ordering.na>>)).

  Definition ra_race (loc: Loc.t) (to: Time.t) (ordw: Ordering.t) (tview: TView.t) (e: ProgramEvent.t): Prop :=
    (exists val ord,
        (<<READ: ProgramEvent.is_reading e = Some (loc, val, ord)>>) /\
        (<<WRRACE: wr_race loc to ordw tview ord>>)) \/
    (exists val ord,
        (<<WRITE: ProgramEvent.is_writing e = Some (loc, val, ord)>>) /\
        (<<WWRACE: ww_race loc to ordw tview ord>>)).

  Definition race (c1: Configuration.t): Prop :=
    exists c2 c3
      tid_w e_w loc from to val released ordw
      tid_r lang st3 lc3 e st4,
      (<<WRITE_STEP: OrdConfiguration.estep L Ordering.acqrel Ordering.acqrel e_w tid_w c1 c2>>) /\
      (<<WRITE_EVENT: ThreadEvent.is_writing e_w = Some (loc, from, to, val, released, ordw)>>) /\
      (<<STEPS2: rtc (@OrdConfiguration.all_step L Ordering.acqrel Ordering.acqrel) c2 c3>>) /\
      (<<FIND: IdentMap.find tid_r (Configuration.threads c3) = Some (existT _ lang st3, lc3)>>) /\
      (<<STEP: lang.(Language.step) e st3 st4>>) /\
      (<<RACE: ra_race loc to ordw (Local.tview lc3) e>>).

  Definition racefree (c: Configuration.t): Prop :=
    forall c1 (STEPS1: rtc (@OrdConfiguration.all_step L Ordering.acqrel Ordering.acqrel) c c1),
      ~ race c1.

  Definition racefree_syn (s: Threads.syntax): Prop :=
    racefree (Configuration.init s).


  (* Lemma read_message_exists *)
  (*       lang *)
  (*       rels1 rels2 e1 e2 *)
  (*       loc to ordw *)
  (*       (LC_WF1: Local.wf (Thread.local e1) (Thread.global e1)) *)
  (*       (GL_WF1: Global.wf (Thread.global e1)) *)
  (*       (STEPS: @WThread.steps lang L Ordering.acqrel Ordering.acqrel rels1 rels2 e1 e2) *)
  (*       (RELS2: List.In (loc, to, ordw) rels2) *)
  (*       (HIGHER: Time.lt ((Local.tview (Thread.local e2)).(TView.cur).(View.rlx) loc) to): *)
  (*   (<<RELS1: List.In (loc, to, ordw) rels1>>). *)
  (* Proof. *)
  (*   dependent induction STEPS; try by (esplits; eauto). *)
  (*   hexploit WThread.step_reserve_only; try exact STEP; eauto. i. des. *)
  (*   exploit WThread.step_future; eauto. i. des. *)
  (*   exploit WThread.steps_future; try exact STEPS; eauto. i. des. *)
  (*   exploit IHSTEPS; eauto. intros x. des. *)
  (*   clear IHSTEPS. revert x. *)
  (*   inv STEP. inv STEP0; inv STEP; [|inv LOCAL]; ss; try by (esplits; eauto). *)
  (*   - unfold Writes.append. ss. condtac; ss. i. des; ss. inv x. *)
  (*     assert (Time.le to ((TView.cur (Local.tview lc2)).(View.rlx) loc)). *)
  (*     { inv LOCAL0. inv STEP. ss. *)
  (*       unfold TimeMap.join, TimeMap.singleton. *)
  (*       unfold LocFun.add, LocFun.init, LocFun.find. condtac; ss. *)
  (*       apply Time.join_r. *)
  (*     } *)
  (*     inv TVIEW_FUTURE0. inv CUR. rewrite (RLX loc) in H0. timetac. *)
  (*   - unfold Writes.append. ss. condtac; ss. i. des; ss. inv x. *)
  (*     assert (Time.le to ((TView.cur (Local.tview lc2)).(View.rlx) loc)). *)
  (*     { inv LOCAL2. inv STEP. ss. *)
  (*       unfold TimeMap.join, TimeMap.singleton. *)
  (*       unfold LocFun.add, LocFun.init, LocFun.find. condtac; ss. *)
  (*       apply Time.join_r. *)
  (*     } *)
  (*     inv TVIEW_FUTURE0. inv CUR. rewrite (RLX loc) in H0. timetac. *)
  (*   - unfold Writes.append. ss. condtac; ss. i. des; ss. inv x. *)
  (*     assert (Time.le to ((TView.cur (Local.tview lc2)).(View.rlx) loc)). *)
  (*     { inv LOCAL0. *)
  (*       - inv STEP. ss. *)
  (*         unfold TimeMap.join, TimeMap.singleton. *)
  (*         unfold LocFun.add, LocFun.init, LocFun.find. condtac; ss. *)
  (*         apply Time.join_r. *)
  (*       - inv STEP. ss. *)
  (*         unfold TimeMap.join, TimeMap.singleton. *)
  (*         unfold LocFun.add, LocFun.init, LocFun.find. condtac; ss. *)
  (*         apply Time.join_r. *)
  (*     } *)
  (*     inv TVIEW_FUTURE0. inv CUR. rewrite (RLX loc) in H0. timetac. *)
  (* Qed. *)

  Lemma write_exists
        ordr ordw
        rels1 rels2 c1 c2
        loc to ord
        (WF1: Configuration.wf c1)
        (STEPS: WConfiguration.steps L ordr ordw rels1 rels2 c1 c2)
        (LOC: L loc)
        (RELS1: ~ List.In (loc, to, ord) rels1)
        (RELS2: List.In (loc, to, ord) rels2):
    exists rels11 rels12 c11 c12 tid e from val released,
      (<<STEPS1: WConfiguration.steps L ordr ordw rels1 rels11 c1 c11>>) /\
      (<<WRITE_STEP: WConfiguration.step L ordr ordw e tid rels11 rels12 c11 c12>>) /\
      (<<WRITE_EVENT: ThreadEvent.is_writing e = Some (loc, from, to, val, released, ord)>>) /\
      (<<STEPS2: WConfiguration.steps L ordr ordw rels12 rels2 c12 c2>>).
  Proof.
    revert WF1. induction STEPS; i; try congr.
    exploit WConfiguration.step_future; eauto. i. des.
    exploit WConfiguration.step_rels; eauto. i. subst.
    destruct (classic (exists from val released,
                          ThreadEvent.is_writing e = Some (loc, from, to, val, released, ord))).
    { des. esplits; eauto. econs 1. }
    exploit IHSTEPS; eauto.
    { unfold Writes.append. des_ifs. ii. ss. des; ss. inv H0. eauto. }
    i. des. esplits; eauto. econs 2; eauto.
  Qed.

  Lemma racefree_implies
        s
        (RACEFREE: racefree_syn s):
    RARaceW.racefree_syn L Ordering.acqrel Ordering.acqrel s.
  Proof.
    specialize (@Configuration.init_wf s). intro WF.
    ii. unfold RARaceW.ra_race in *. des.
    { destruct WRRACE as [to [ordw [LOC [HIGHER [IN ORD]]]]]. guardH ORD. des.
      unfold racefree_syn in *.
      remember (Configuration.init s) as c1. clear Heqc1.
      exploit write_exists; try exact STEPS; eauto. i. des.
      exploit WConfiguration.steps_ord_steps; try exact STEPS1. i.
      exploit WConfiguration.step_ord_step; try exact WRITE_STEP. i.
      exploit WConfiguration.steps_ord_steps; try exact STEPS2. i.
      eapply RACEFREE; eauto.
      unfold race. esplits; eauto.
      left. esplits; eauto.
      unfold wr_race. splits; auto.
    }
    { destruct WWRACE as [to [ordw [LOC [HIGHER [IN ORD]]]]]. guardH ORD. des.
      unfold racefree_syn in *.
      remember (Configuration.init s) as c1. clear Heqc1.
      exploit write_exists; try exact STEPS; eauto. i. des.
      exploit WConfiguration.steps_ord_steps; try exact STEPS1. i.
      exploit WConfiguration.step_ord_step; try exact WRITE_STEP. i.
      exploit WConfiguration.steps_ord_steps; try exact STEPS2. i.
      eapply RACEFREE; eauto.
      unfold race. esplits; eauto.
      right. esplits; eauto.
      unfold ww_race. splits; auto.
    }
  Qed.
End RARACE.
End RARace.
