Require Import RelationClasses.

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
Require Import Reserves.
Require Import Cell.
Require Import Memory.
Require Import TView.
Require Import Global.
Require Import Local.
Require Import Thread.


Section PFCertify.
  Variable lang: language.

  Variant pf_certify (loc: Loc.t) (th: Thread.t lang): Prop :=
    | pf_certify_failure
        pf e th1 th2
        (STEPS: rtc (tau (Thread.step (Global.max_reserved (Thread.global th)) true)) th th1)
        (STEP_FAILURE: Thread.step (Global.max_reserved (Thread.global th)) pf e th1 th2)
        (EVENT_FAILURE: ThreadEvent.get_machine_event e = MachineEvent.failure)
    | pf_certify_fulfill
        pf e th1 th2
        from to val released ord
        (STEPS: rtc (tau (Thread.step (Global.max_reserved (Thread.global th)) true)) th th1)
        (STEP_FULFILL: Thread.step (Global.max_reserved (Thread.global th)) pf e th1 th2)
        (EVENT_FULFILL: ThreadEvent.is_writing e = Some (loc, from, to, val, released, ord))
        (TO: Time.lt (Memory.max_ts loc (Global.memory (Thread.global th1))) to)
        (ORD: Ordering.le ord Ordering.na)
  .

  Variant certify (reserved: OptTimeMap.t) (loc: Loc.t) (th: Thread.t lang): Prop :=
    | certify_failure
        pf e th1 th2
        (STEPS: rtc (pstep (Thread.step_allpf reserved) (fun e => ~ ThreadEvent.is_sc e)) th th1)
        (STEP_FAILURE: Thread.step reserved pf e th1 th2)
        (EVENT_FAILURE: ThreadEvent.get_machine_event e = MachineEvent.failure)
    | certify_fulfill
        pf e th1 th2
        from to val released ord
        (STEPS: rtc (pstep (Thread.step_allpf reserved) (fun e => ~ ThreadEvent.is_sc e)) th th1)
        (STEP_FULFILL: Thread.step reserved pf e th1 th2)
        (EVENT_FULFILL: ThreadEvent.is_writing e = Some (loc, from, to, val, released, ord))
        (TO: Time.lt (Memory.max_ts loc (Global.memory (Thread.global th1))) to)
        (ORD: Ordering.le ord Ordering.na)
  .

  Variant non_sc_consistent (th: Thread.t lang): Prop :=
    | non_sc_consistent_failure
        pf e th1 th2
        (STEPS: rtc (pstep (Thread.step_allpf (Global.max_reserved (Thread.global th))) (fun e => ~ ThreadEvent.is_sc e)) th th1)
        (STEP_FAILURE: Thread.step (Global.max_reserved (Thread.global th)) pf e th1 th2)
        (EVENT_FAILURE: ThreadEvent.get_machine_event e = MachineEvent.failure)
    | non_sc_consistent_promises
        th2
        (STEPS: rtc (pstep (Thread.step_allpf (Global.max_reserved (Thread.global th))) (fun e => ~ ThreadEvent.is_sc e)) th th2)
        (PROMISES: Local.promises (Thread.local th2) = BoolMap.bot)
  .

  Lemma rtc_tau_step_rtc_non_sc_step
        reserved (th1 th2: Thread.t lang)
        (STEPS: rtc (Thread.tau_step reserved) th1 th2):
    exists th2',
      (<<STEPS1: rtc (pstep (Thread.step_allpf reserved) (fun e => ~ ThreadEvent.is_sc e)) th1 th2'>>) /\
      ((<<TH2: th2' = th2>>) \/
       (<<STEPS2: rtc (Thread.tau_step reserved) th2' th2>>) /\
       (<<PROMISES: Local.promises (Thread.local th2') = BoolMap.bot>>)).
  Proof.
    induction STEPS.
    { esplits; eauto. }
    inv H. inv TSTEP.
    destruct (classic (ThreadEvent.is_sc e)).
    - esplits; [refl|]. right. split.
      + econs 2; eauto. econs; eauto.
      + inv STEP; inv STEP0; ss. inv LOCAL. auto.
    - des.
      + esplits; [|eauto]. eauto.
      + esplits; [|eauto]. eauto.
  Qed.

  Lemma consistent_non_sc_consistent
        th
        (CONS: Thread.consistent th):
    non_sc_consistent th.
  Proof.
    inv CONS.
    - inv FAILURE.
      exploit rtc_tau_step_rtc_non_sc_step; eauto. i. des.
      + subst. econs 1; eauto.
      + econs 2; eauto.
    - exploit rtc_tau_step_rtc_non_sc_step; eauto. i. des.
      + subst. econs 2; eauto.
      + econs 2; eauto.
  Qed.

  Lemma non_sc_consistent_certify
        th loc
        (LC_WF: Local.wf (Thread.local th) (Thread.global th))
        (GL_WF: Global.wf (Thread.global th))
        (CONS: non_sc_consistent th)
        (PROMISED: Local.promises (Thread.local th) loc = true):
    certify (Global.max_reserved (Thread.global th)) loc th.
  Proof.
    inv CONS.
    { econs 1; eauto. }
    remember (Global.max_reserved (Thread.global th)) as reserved.
    clear Heqreserved. revert PROMISED.
    induction STEPS; i.
    { rewrite PROMISES in *. ss. }
    destruct (Local.promises (Thread.local y) loc) eqn:PROMISEDY.
    { dup H. inv H0. inv STEP.
      exploit Thread.step_future; try exact STEP; eauto. i. des.
      exploit IHSTEPS; eauto. i. inv x1.
      - econs 1; try exact STEP_FAILURE; eauto.
      - econs 2; try exact STEP_FULFILL; eauto.
    }

    move PROMISEDY at bottom.
    inv H. inv STEP.
    inv STEP0; inv STEP; ss; (try congr); (try by inv LOCAL; ss; congr).
    { (* promise *)
      inv LOCAL. inv PROMISE. ss.
      exploit BoolMap.add_le; try exact ADD; eauto. i. congr.
    }

    { (* write *)
      assert (loc0 = loc /\ Ordering.le ord Ordering.na).
      { inv LOCAL. inv FULFILL; ss; try congr. split; ss.
        revert PROMISEDY. erewrite BoolMap.remove_o; eauto.
        condtac; ss. congr.
      }
      des. subst.
      destruct (TimeFacts.le_lt_dec to (Memory.max_ts loc (Global.memory gl1))); cycle 1.
      { econs 2; [refl|..].
        - econs 2; [|econs 3]; eauto.
        - ss.
        - ss.
        - ss.
      }

      exploit (Memory.max_ts_spec loc); try apply GL_WF. i. des.
      destruct msg. clear MAX.
      econs 1; [refl|..].
      - econs 2; [|econs 9]; eauto.
        econs. econs 2; eauto.
        + unfold TView.racy_view.
          eapply TimeFacts.lt_le_lt; eauto.
          inv LOCAL. inv WRITABLE. ss.
          eapply TimeFacts.le_lt_lt; eauto.
          apply LC_WF.
        + destruct ord; ss.
      - ss.
    }

    { (* update *)
      assert (Ordering.le ordw Ordering.na).
      { inv LOCAL1. inv LOCAL2.  inv FULFILL; ss; try congr. }
      econs 1; [refl|..].
      - econs 2; [|econs 10]; eauto.
      - ss.
    }
  Qed.

  Variant sim_thread (th_src th_tgt: Thread.t lang): Prop :=
    | sim_thread_intro
        (STATE: Thread.state th_src = Thread.state th_tgt)
        (TVIEW: Local.tview (Thread.local th_src) = Local.tview (Thread.local th_tgt))
        (SC: Global.sc (Thread.global th_src) = Global.sc (Thread.global th_tgt))
        (PROMISES: BoolMap.minus (Global.promises (Thread.global th_src)) (Local.promises (Thread.local th_src)) =
                   BoolMap.minus (Global.promises (Thread.global th_tgt)) (Local.promises (Thread.local th_tgt)))
        (RESERVES: BoolMap.minus (Global.reserves (Thread.global th_src)) (Local.reserves (Thread.local th_src)) =
                   BoolMap.minus (Global.reserves (Thread.global th_tgt)) (Local.reserves (Thread.local th_tgt)))
        (MEMORY: Global.memory (Thread.global th_src) = Global.memory (Thread.global th_tgt))
  .

  Program Instance sim_thread_Equivalence: Equivalence sim_thread.
  Next Obligation.
    ii. econs; ss.
  Qed.
  Next Obligation.
    ii. inv H. ss.
  Qed.
  Next Obligation.
    ii. inv H. inv H0. econs; try congr.
  Qed.

  Lemma sim_thread_internal_step
        th1_src
        reserved e th1_tgt th2_tgt
        (SIM1: sim_thread th1_src th1_tgt)
        (STEP_TGT: Thread.step reserved false e th1_tgt th2_tgt):
    sim_thread th1_src th2_tgt.
  Proof.
    inv SIM1. inv STEP_TGT. ss. inv STEP.
    - inv LOCAL. econs; ss.
      rewrite PROMISES.
      eauto using Promises.promise_minus.
    - inv LOCAL. econs; ss.
      rewrite RESERVES.
      eauto using Reserves.reserve_minus.
    - inv LOCAL. econs; ss.
      rewrite RESERVES.
      eauto using Reserves.cancel_minus.
  Qed.

  Lemma sim_is_racy
        lc_src gl_src lc_tgt gl_tgt
        loc to ord
        (TVIEW: Local.tview lc_src = Local.tview lc_tgt)
        (PROMISES: BoolMap.minus (Global.promises gl_src) (Local.promises lc_src) =
                   BoolMap.minus (Global.promises gl_tgt) (Local.promises lc_tgt))
        (MEMORY: Global.memory gl_src = Global.memory gl_tgt)
        (RACE_TGT: Local.is_racy lc_tgt gl_tgt loc to ord):
    Local.is_racy lc_src gl_src loc to ord.
  Proof.
    inv RACE_TGT.
    - eapply equal_f in PROMISES.
      unfold BoolMap.minus in *.
      rewrite GET, GETP in *. ss.
      destruct (Global.promises gl_src loc) eqn:GRSV; ss.
      destruct (Local.promises lc_src loc) eqn:RSV; ss.
      econs 1; eauto.
    - rewrite <- TVIEW, <- MEMORY in *. eauto.
  Qed.

  Lemma sim_thread_program_step
        (reserved: OptTimeMap.t)
        th1_src
        e th1_tgt th2_tgt
        (RESERVED: forall loc, reserved loc <-> Global.reserves (Thread.global th1_src) loc)
        (SIM1: sim_thread th1_src th1_tgt)
        (STEP_TGT: Thread.step reserved true e th1_tgt th2_tgt)
        (NONSC: ~ ThreadEvent.is_sc e):
    exists th2_src,
      (<<STEP_SRC: Thread.step reserved true e th1_src th2_src>>) /\
      (<<SIM2: sim_thread th2_src th2_tgt>>).
  Proof.
    destruct th1_src as [st1_src [tview1_src prm1_src rsv1_src] [sc1_src gprm1_src grsv1_src mem1_src]],
        th1_tgt as [st1_tgt [tview1_tgt prm1_tgt rsv1_tgt] [sc1_tgt gprm1_tgt grsv1_tgt mem1_tgt]].
    inv SIM1. ss. subst.
    inv STEP_TGT. inv STEP; ss.
    { (* silent *)
      esplits.
      - econs; [|econs 1]; eauto.
      - ss.
    }
    { (* read *)
      inv LOCAL. ss.
      esplits.
      - econs; [|econs 2]; eauto.
      - ss.
    }
    { (* write *)
      inv LOCAL. ss.
      esplits.
      - econs; [|econs 3]; eauto.
        econs; s; eauto. i.
        exploit NON_RESERVED; eauto. i. des; auto.
        specialize (RESERVED loc). rewrite GET in *.
        destruct (grsv1_src loc) eqn:GRSV_SRC; ss; try by intuition.
        destruct (rsv1_src loc) eqn:RSV_SRC; auto.
        eapply equal_f in RESERVES.
        unfold BoolMap.minus in RESERVES.
        rewrite GRSV_SRC, RSV_SRC, x0 in RESERVES. ss.
        destruct (grsv1_tgt loc); ss.
      - econs; ss.
        rewrite PROMISES.
        eauto using Promises.fulfill_minus.
    }
    { (* update *)
      inv LOCAL1. inv LOCAL2. ss.
      esplits.
      - econs; [|econs 4]; eauto.
        econs; s; eauto. i.
        exploit NON_RESERVED; eauto. i. des; auto.
        specialize (RESERVED loc). rewrite GET0 in *.
        destruct (grsv1_src loc) eqn:GRSV_SRC; ss; try by intuition.
        destruct (rsv1_src loc) eqn:RSV_SRC; auto.
        eapply equal_f in RESERVES.
        unfold BoolMap.minus in RESERVES.
        rewrite GRSV_SRC, RSV_SRC, x0 in RESERVES. ss.
        destruct (grsv1_tgt loc); ss.
      - econs; ss.
        rewrite PROMISES.
        eauto using Promises.fulfill_minus.
    }
    { (* fence *)
      inv LOCAL. ss.
      esplits.
      - econs; [|econs 5]; eauto. econs; ss.
      - ss.
    }
    { (* failure *)
      inv LOCAL. ss.
      esplits.
      - econs; [|econs 7]; eauto.
      - ss.
    }
    { (* racy read *)
      inv LOCAL. ss.
      esplits.
      - econs; [|econs 8]; eauto.
        econs. eapply sim_is_racy; try eapply RACE; ss.
      - ss.
    }
    { (* racy write *)
      inv LOCAL. ss.
      esplits.
      - econs; [|econs 9]; eauto.
        econs. eapply sim_is_racy; try eapply RACE; ss.
      - ss.
    }
    { (* racy update *)
      esplits.
      - econs; [|econs 10]; eauto.
        inv LOCAL.
        + econs 1. ss.
        + econs 2. ss.
        + econs 3. eapply sim_is_racy; try eapply RACE; ss.
      - ss.
    }
  Qed.

  Lemma certify_pf_certify
        th loc
        (LC_WF: Local.wf (Thread.local th) (Thread.global th))
        (GL_WF: Global.wf (Thread.global th))
        (CERTIFY: certify (Global.max_reserved (Thread.global th)) loc th):
    pf_certify loc th.
  Proof.
  Admitted.

  Lemma consistent_pf_certify
        th loc
        (LC_WF: Local.wf (Thread.local th) (Thread.global th))
        (GL_WF: Global.wf (Thread.global th))
        (CONS: Thread.consistent th)
        (PROMISED: th.(Thread.local).(Local.promises) loc = true):
    pf_certify loc th.
  Proof.
    apply certify_pf_certify; auto.
    apply non_sc_consistent_certify; auto.
    apply consistent_non_sc_consistent; auto.
  Qed.
End PFCertify.
