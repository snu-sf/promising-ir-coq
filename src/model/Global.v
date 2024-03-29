Require Import RelationClasses.

From sflib Require Import sflib.

From PromisingLib Require Import Axioms.
From PromisingLib Require Import Basic.
From PromisingLib Require Import DataStructure.
From PromisingLib Require Import DenseOrder.
From PromisingLib Require Import Loc.
From PromisingLib Require Import Event.

Require Import Time.
Require Import View.
Require Import BoolMap.
Require Import Promises.
Require Import Cell.
Require Import Memory.

Set Implicit Arguments.


Module Global.
  Structure t := mk {
    sc: TimeMap.t;
    promises: BoolMap.t;
    memory: Memory.t;
  }.

  Definition init := mk TimeMap.bot BoolMap.bot Memory.init.

  Variant wf (gl: t): Prop :=
  | wf_intro
      (SC_CLOSED: Memory.closed_timemap (sc gl) (memory gl))
      (MEM_CLOSED: Memory.closed (memory gl))
  .
  #[global] Hint Constructors wf: core.

  Lemma init_wf: wf init.
  Proof.
    econs; ss.
    - apply Memory.closed_timemap_bot.
      apply Memory.init_closed.
    - apply Memory.init_closed.
  Qed.

  Definition cap_of (gl: t): t :=
    mk (sc gl) (promises gl) (Memory.cap_of (memory gl)).

  Lemma cap_of_cap gl:
    (<<SC: sc gl = sc (cap_of gl)>>) /\
    (<<GPRM: promises gl = promises (cap_of gl)>>) /\
    (<<MEM: Memory.cap (memory gl) (memory (cap_of gl))>>).
  Proof.
    splits; ss.
    apply Memory.cap_of_cap.
  Qed.

  Lemma cap_wf
        gl
        (WF: wf gl):
    wf (cap_of gl).
  Proof.
    inv WF.
    econs; s; eauto using Memory.cap_of_cap,
      Memory.cap_closed, Memory.cap_closed_timemap.
  Qed.

  Variant future (gl1 gl2: t): Prop :=
  | future_intro
      (SC: TimeMap.le (sc gl1) (sc gl2))
      (MEMORY: Memory.future (memory gl1) (memory gl2))
  .
  #[global] Hint Constructors future: core.

  Global Program Instance future_PreOrder: PreOrder future.
  Next Obligation.
    ii. destruct x. econs; refl.
  Qed.
  Next Obligation.
    ii. destruct x, y, z. inv H. inv H0. ss.
    econs; etrans; eauto.
  Qed.

  Variant le (gl1 gl2: t): Prop :=
    | le_intro
        (SC: TimeMap.le (sc gl1) (sc gl2))
        (MEMORY: Memory.messages_le (memory gl1) (memory gl2))
  .
  #[global] Hint Constructors le: core.

  Global Program Instance le_PreOrder: PreOrder le.
  Next Obligation.
    ii. econs; refl.
  Qed.
  Next Obligation.
    ii. inv H. inv H0. econs; etrans; eauto.
  Qed.

  Lemma future_le
    gl1 gl2
    (FUTURE: future gl1 gl2):
    le gl1 gl2.
  Proof.
    inv FUTURE. econs; ss.
    eauto using Memory.future_messages_le.
  Qed.

  Lemma cap_le
    gl gl_cap
    (CAP: gl_cap = cap_of gl):
    le gl gl_cap.
  Proof.
    destruct gl, gl_cap. inv CAP.
    econs; s; try refl.
    apply Memory.cap_messages_le.
    apply Memory.cap_of_cap.
  Qed.

  Variant na_added_latest (gl1 gl2: t): Prop :=
  | na_added_latest_intro
      (ADDNA: forall loc,
          (<<PROMISES: implb (gl1.(promises) loc) (gl2.(promises) loc)>>) \/
          (<<LATEST: Memory.na_added_latest loc gl1.(memory) gl2.(memory)>>))
  .

  Variant strong_le (gl1 gl2: t): Prop :=
  | strong_le_intro
      (LE: le gl1 gl2)
      (ADDNA: na_added_latest gl1 gl2)
  .
  #[global] Hint Constructors strong_le: core.

  Global Program Instance strong_le_PreOrder: PreOrder strong_le.
  Next Obligation.
    ii. destruct x. econs; [refl|]. econs. i. left. ss. rewrite Bool.implb_same. auto.
  Qed.
  Next Obligation.
    ii. destruct x, y, z. inv H. inv H0. ss. econs.
    { etrans; eauto. }
    { econs. i. ss. destruct (promises0 loc) eqn:PRM0.
      { destruct (promises2 loc) eqn:PRM2.
        { left. ss. }
        destruct (promises1 loc) eqn:PRM1.
        { right. inv ADDNA0. ss. hexploit ADDNA1; eauto.
          rewrite PRM1. rewrite PRM2. i. des; ss.
          eapply Memory.na_added_latest_le.
          { inv LE. eauto. }
          { eauto. }
          { reflexivity. }
        }
        { right. inv ADDNA. ss. hexploit ADDNA1; eauto.
          rewrite PRM0. rewrite PRM1. i. des; ss.
          eapply Memory.na_added_latest_le.
          { reflexivity. }
          { eauto. }
          { inv LE0. eauto. }
        }
      }
      econs; etrans; eauto.
    }
  Qed.

  Lemma cap_strong_le
    gl gl_cap
    (CAP: gl_cap = cap_of gl):
    strong_le gl gl_cap.
  Proof.
    destruct gl, gl_cap. inv CAP. econs.
    { eapply cap_le; eauto. }
    { econs. i. left. ss. rewrite Bool.implb_same. auto. }
  Qed.
End Global.
