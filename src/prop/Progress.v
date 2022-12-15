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
Require Import Global.
Require Import TView.
Require Import Local.
Require Import Thread.

Set Implicit Arguments.


Lemma closed_timemap_max_ts
      loc tm mem
      (CLOSED: Memory.closed_timemap tm mem):
  Time.le (tm loc) (Memory.max_ts loc mem).
Proof.
  specialize (CLOSED loc). des.
  eapply Memory.max_ts_spec. eauto.
Qed.


(* Lemma progress_promise_step *)
(*       lc1 sc1 mem1 *)
(*       loc to val releasedm ord *)
(*       (LT: Time.lt (Memory.max_ts loc mem1) to) *)
(*       (WF1: Local.wf lc1 mem1) *)
(*       (MEM1: Memory.closed mem1) *)
(*       (SC1: Memory.closed_timemap sc1 mem1) *)
(*       (WF_REL: View.opt_wf releasedm) *)
(*       (CLOSED_REL: Memory.closed_opt_view releasedm mem1): *)
(*   exists promises2 mem2, *)
(*     Local.promise_step lc1 mem1 loc (Memory.max_ts loc mem1) to *)
(*                        (Message.concrete val (TView.write_released (Local.tview lc1) sc1 loc to releasedm ord)) *)
(*                        (Local.mk (Local.tview lc1) promises2) mem2 Memory.op_kind_add. *)
(* Proof. *)
(*   exploit (@Memory.add_exists_max_ts *)
(*              mem1 loc to *)
(*              (Message.concrete val (TView.write_released (Local.tview lc1) sc1 loc to releasedm ord))); eauto. *)
(*   { econs. eapply TViewFacts.write_future0; eauto. apply WF1. } *)
(*   i. des. *)
(*   exploit Memory.add_exists_le; try apply WF1; eauto. i. des. *)
(*   hexploit Memory.add_inhabited; try apply x0; [viewtac|]. i. des. *)
(*   esplits. econs; eauto. *)
(*   - econs; eauto; try congr. *)
(*     + econs. unfold TView.write_released. *)
(*       viewtac; repeat (condtac; viewtac); *)
(*         (try by apply Time.bot_spec); *)
(*         (try by unfold TimeMap.singleton, LocFun.add; condtac; [refl|congr]); *)
(*         (try by left; eapply TimeFacts.le_lt_lt; [|eauto]; *)
(*          eapply closed_timemap_max_ts; apply WF1). *)
(*       left. eapply TimeFacts.le_lt_lt; [|eauto]. *)
(*       eapply closed_timemap_max_ts. apply Memory.unwrap_closed_opt_view; viewtac. *)
(*     + i. inv x0. inv ADD. clear DISJOINT MSG_WF CELL2. *)
(*       exploit Memory.get_ts; try exact GET. i. des. *)
(*       { subst. inv TO. } *)
(*       exploit Memory.max_ts_spec; try exact GET. i. des. *)
(*       eapply Time.lt_strorder. etrans; try exact TO. *)
(*       eapply TimeFacts.lt_le_lt; eauto. *)
(*   - econs. unfold TView.write_released. condtac; econs. *)
(*     viewtac; *)
(*       repeat condtac; viewtac; *)
(*         (try eapply Memory.add_closed_view; eauto); *)
(*         (try apply WF1). *)
(*     + viewtac. *)
(*     + erewrite Memory.add_o; eauto. condtac; eauto. ss. des; congr. *)
(*     + erewrite Memory.add_o; eauto. condtac; eauto. ss. des; congr. *)
(* Qed. *)

(* Lemma progress_read_step *)
(*       lc1 mem1 *)
(*       loc ord *)
(*       (WF1: Local.wf lc1 mem1) *)
(*       (MEM1: Memory.closed mem1): *)
(*   exists val released lc2 mts, *)
(*     <<MAX: Memory.max_concrete_ts mem1 loc mts>> /\ *)
(*     <<READ: Local.read_step lc1 mem1 loc mts val released ord lc2>>. *)
(* Proof. *)
(*   dup MEM1. inv MEM0. *)
(*   exploit (Memory.max_concrete_ts_exists); eauto. i. des. *)
(*   exploit (Memory.max_concrete_ts_spec); eauto. i. des. *)
(*   esplits; eauto. econs; eauto; try refl. *)
(*   econs; i; eapply Memory.max_concrete_ts_spec2; eauto; apply WF1. *)
(* Qed. *)

Lemma progress_read_step
      lc1 gl1
      loc ord
      (LC_WF1: Local.wf lc1 gl1):
  exists val released lc2,
    <<READ: Local.read_step lc1 gl1 loc ((TView.cur (Local.tview lc1)).(View.rlx) loc) val released ord lc2>>.
Proof.
  dup LC_WF1. inv LC_WF0. inv TVIEW_CLOSED. inv CUR.
  specialize (RLX loc). des.
  esplits. econs; eauto; try refl.
  econs; try apply TVIEW_WF; try refl.
Qed.

Lemma progress_read_step_plain
      lc1 gl1
      loc ord
      (LC_WF1: Local.wf lc1 gl1)
      (ORD: Ordering.le ord Ordering.plain):
  exists val released,
    <<READ: Local.read_step lc1 gl1 loc ((TView.cur (Local.tview lc1)).(View.pln) loc) val released ord lc1>>.
Proof.
  dup LC_WF1. inv LC_WF0. inv TVIEW_CLOSED. inv CUR.
  specialize (PLN loc). des.
  esplits. econs; eauto; try refl.
  - econs; try refl. i. destruct ord; ss.
  - destruct lc1. ss. f_equal.
    apply TView.antisym.
    + apply TViewFacts.read_tview_incr.
    + unfold TView.read_tview.
      econs; repeat (condtac; aggrtac; try apply LC_WF1).
      etrans; apply LC_WF1. 
Qed.

(* Lemma progress_write_step *)
(*       lc1 sc1 mem1 *)
(*       loc to val releasedm ord *)
(*       (LT: Time.lt (Memory.max_ts loc mem1) to) *)
(*       (WF1: Local.wf lc1 mem1) *)
(*       (SC1: Memory.closed_timemap sc1 mem1) *)
(*       (MEM1: Memory.closed mem1) *)
(*       (WF_REL: View.opt_wf releasedm) *)
(*       (CLOSED_REL: Memory.closed_opt_view releasedm mem1) *)
(*       (PROMISES1: Ordering.le Ordering.strong_relaxed ord -> Memory.nonsynch_loc loc (Local.promises lc1)): *)
(*   exists released lc2 sc2 mem2, *)
(*     Local.write_step lc1 sc1 mem1 loc (Memory.max_ts loc mem1) to val releasedm released ord lc2 sc2 mem2 Memory.op_kind_add. *)
(* Proof. *)
(*   exploit progress_promise_step; eauto. i. des. *)
(*   exploit Local.promise_step_future; eauto. i. des. inv x0. *)
(*   exploit Memory.remove_exists; eauto. *)
(*   { inv PROMISE. erewrite Memory.add_o; try eexact PROMISES. *)
(*     condtac; eauto. ss. des; exfalso; apply o; eauto. *)
(*   } *)
(*   i. des. *)
(*   esplits. econs; eauto. *)
(*   econs; i; (try eapply TimeFacts.le_lt_lt; [|eauto]). *)
(*   apply Memory.max_ts_spec2. apply WF1. *)
(* Qed. *)

(* Lemma progress_fence_step *)
(*       lc1 sc1 *)
(*       ordr ordw *)
(*       (PROMISES1: Ordering.le Ordering.strong_relaxed ordw -> Memory.nonsynch (Local.promises lc1)) *)
(*       (PROMISES2: ordw = Ordering.seqcst -> (Local.promises lc1) = Memory.bot): *)
(*   exists lc2 sc2, *)
(*     Local.fence_step lc1 sc1 ordr ordw lc2 sc2. *)
(* Proof. *)
(*   esplits. econs; eauto. *)
(* Qed. *)
