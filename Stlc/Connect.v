(***********************************************************************)
(**  * Connecting nominal and LN semantics *)
(***********************************************************************)

(** Our final goal is to show that the abstract nominal machine
    implements the same semantics as the LN substitution based small step
    relation. *)

Require Import Metalib.Metatheory.

Require Import Stlc.Definitions.
Require Import Stlc.Lemmas.

Require Import Stlc.Nominal.

Import StlcNotations.

(***********************************************************************)
(** * Translating nominal to LN terms *)
(***********************************************************************)

(** We translate named terms to LN terms through the use of the
    [close_exp_wrt_exp] function. This function replaces all occurrences
    of the given atom by the appropriate bound variable.

    This function is defined in the [Stlc.Lemmas] module and can be
    automatically generated by LNgen.  *)

Fixpoint nom_to_exp (ne : n_exp) : exp :=
  match ne with
  | n_var x => var_f x
  | n_app e1 e2 => app (nom_to_exp e1) (nom_to_exp e2)
  | n_abs x e1 => abs (close_exp_wrt_exp x (nom_to_exp e1))
end.

(** We also define a translation from machine configurations to LN
    terms. In this case we must substitute all definitions in the
    heap through the terms and create all of the applications in
    the stack. *)

Fixpoint apply_heap (h : heap) (e : exp) : exp  :=
  match h with
  | nil => e
  | (x , e') :: h' => apply_heap h' ([x ~> nom_to_exp e'] e)
  end.

Fixpoint apply_stack h (s : list frame) (e :exp) : exp :=
  match s with
  | nil => e
  | n_app2 e' :: s' => apply_stack h s' (app e (apply_heap h (nom_to_exp e')))
  end.

Definition decode (c:conf) : exp  :=
  match c with
  | (h,e,s) => apply_stack h s (apply_heap h (nom_to_exp e))
  end.


(***********************************************************************)
(** * Demo: connecting free variable functions.                          *)
(***********************************************************************)

(** Here is the first result about our decoding: that the two free
    variable functions agree.

    In this part of the file, we will take advantage of automation
    provided by the Lemmas module. In particular, this module defines a
    database of rewriting hints (called [lngen]) that can be used to
    automatically rewrite LN terms into simpler form. *)

Lemma fv_nom_fv_exp_eq : forall n,
    fv_nom n [=] fv_exp (nom_to_exp n).
Proof.
  induction n; intros; simpl; autorewrite with lngen; fsetdec.
Qed.

(** We can also extend the hint database with new rewritings. *)
Hint Rewrite fv_nom_fv_exp_eq : lngen.
Hint Resolve fv_nom_fv_exp_eq : lngen.



(** The Metatheory library contains two powerful tactics for simplifying
    goals:

     - [default_steps]: repeat a bunch of simplifying steps, such as
       simplifying the goal, inverting simple hypotheses, etc.

     - [default_simp]: above plus case analysis for booleans and other sums

    The behavior of these tactics can be modified by updating the
    following two definitions.
*)

Ltac default_auto        ::= auto with lngen.
Ltac default_autorewrite ::= autorewrite with lngen.

(***********************************************************************)

(** Next, we show that our decoding of nominal terms and
    configurations produces locally closed LN terms.

    Again, these proofs are highly automatable.
*)

Lemma nom_to_exp_lc : forall t, lc_exp (nom_to_exp t).
Proof.
  induction t; default_steps.
Qed.
Hint Resolve nom_to_exp_lc : lngen.

Lemma apply_heap_lc : forall h e,
    lc_exp e -> lc_exp (apply_heap h e).
Proof.
  alist induction h; default_simp.
Qed.
Hint Resolve apply_heap_lc : lngen.

(** Exercise: apply_stack_lc

    State and prove a lemma called [apply_stack_lc] and add it to the
    [lngen] hint database so that the proof for [decode_lc] goes
    through. *)

(* SOLUTION *)
Lemma apply_stack_lc : forall s h e,
    lc_exp e -> lc_exp (apply_stack h s e).
Proof.
  induction s; try destruct a; default_simp.
Qed.
Hint Resolve apply_stack_lc : lngen.
(* /SOLUTION *)

Lemma decode_lc : forall c, lc_exp (decode c).
Proof.
  intros [[h e] s]; default_simp.
  (* ADMITTED *)
Qed. (* /ADMITTED *)

(***********************************************************************)
(** Properties of apply_heap *)
(***********************************************************************)

(** Since the heap is just an iterated substitution, it inherits
    properties from [subst_exp].

    [alist induction] is a tactic from the metatheory library for
    induction over association lists (such as the heap).
*)

Lemma apply_heap_abs : forall h e,
  apply_heap h (abs e) = abs (apply_heap h e).
Proof.
  alist induction h; default_simp.
Qed.

Hint Rewrite apply_heap_abs : lngen.

Lemma apply_heap_app : forall h e1 e2,
  apply_heap h (app e1 e2) = app (apply_heap h e1) (apply_heap h e2).
Proof.
  alist induction h; default_simp.
Qed.

Hint Rewrite apply_heap_app : lngen.


(** Exercise: apply_heap_open

    This function is the [apply_heap] analogue to
    [subst_exp_open_exp_wrt_exp], commuting the heap-based
    substitution with the [open_exp_wrt_exp] operation.
 *)

Lemma apply_heap_open : forall h e e0,
    lc_exp e0 ->
    apply_heap h (open e e0)  =
       open (apply_heap h e) (apply_heap h e0).
Proof.
  alist induction h; intros;
    simpl in *;
    try rewrite subst_exp_open_exp_wrt_exp;
    default_simp.
Qed.

Hint Rewrite apply_heap_open : lngen.

(** This last lemma "unsimpl"s the [apply_heap] function. *)

Lemma combine : forall h x e e',
  apply_heap h ([x ~> nom_to_exp e] e') = (apply_heap ((x,e)::h) e').
Proof.
  simpl. auto.
Qed.

(***********************************************************************)
(** * Stacks as evaluation contexts                                    *)
(***********************************************************************)

(** Here is a quick lemma that uses the properties defined above.
    It shows that the stack does behave like an evaluation context,
    lifting a small-step reduction to a larger term.

    Which properties above does this proof implicitly rely on?
 *)


Lemma apply_stack_cong : forall s h e e',
    step e e' ->
    step (apply_stack h s e) (apply_stack h s e').
Proof.
  induction s; intros; try destruct a; default_simp.
Qed.


(***********************************************************************)
(** * Scoped heaps                                                     *)
(***********************************************************************)

(** Next, we define when a heap is *well-scoped*.  Well-scoped heaps
    behave "telescopically".  Each binding (x,e) added to the heap is for
    a unique name x and the free variables of e are bound in the
    remainder of the heap.

    The scoping relation is parameterized by [D], an "ambient
    scope". This will let us reason about the execution of the abstract
    machine for non-closed lambda terms. *)

Inductive scoped_heap (D : atoms) : heap -> Prop :=
  | scoped_nil  : scoped_heap D nil
  | scoped_cons : forall x e h,
      x `notin` dom h \u D ->
      fv_exp (nom_to_exp e) [<=] dom h \u D ->
      scoped_heap D h ->
      scoped_heap D ((x,e)::h).


(** Exercise [apply_heap_get]

    We can use get to look up expressions in the heap. However, to know that
    we have the right result we need to know that the heap is well-scoped, i.e.
    that later bindings do not affect earlier ones.

    State a lemma about the scoping of expressions that appear in the heap
    and use it to finish the apply_heap_get below.
 *)


(* SOLUTION *)
Lemma scoped_get : forall h D1 D2 x e,
  scoped_heap D1 h ->
  get x h = Some e ->
  dom h \u D1 [<=] D2 ->
  fv_exp (nom_to_exp e) [<=] D2.
Proof.
  induction 1; intros; default_simp.
  fsetdec.
  eapply IHscoped_heap; auto; fsetdec.
Qed.
(* /SOLUTION *)

Lemma apply_heap_get :  forall h D x e,
    scoped_heap D h ->
    get x h = Some e ->
    apply_heap h (var_f x) = apply_heap h (nom_to_exp e).
Proof.
  induction 1; intros; default_simp.
  - Case "x is at the current heap location".
    rewrite subst_exp_fresh_eq; auto. fsetdec.
  - Case "x is later in the heap".
    rewrite subst_exp_fresh_eq; auto.
    (* ADMITTED *)
    rewrite scoped_get with (D2:= dom h\u D ); default_simp; eauto.
Qed. (* /ADMITTED *)

(***********************************************************************)
(** * Scoped stacks                                                    *)
(***********************************************************************)

(** We also care about the free variables that can appear in stacks. (We
    will use this definition to define when configurations are
    well-scoped below.)  *)

Fixpoint fv_stack s :=
  match s with
    nil => {}
  | n_app2 e :: s => fv_exp (nom_to_exp e) \u fv_stack s
  end.

(** Stacks that are well-scoped can discard irrelevant bindings
    from the heap. *)

(* LATER *)
(* TODO: how do we get inductive proofs to automatically
   rewrite with the IH? *)
(* /LATER *)
Lemma apply_stack_fresh_eq : forall s x e1 h ,
    x `notin` fv_stack s ->
    apply_stack ((x, e1) :: h) s = apply_stack h s.
Proof.
  induction s; intros; try destruct a; default_simp.
  rewrite IHs; auto.
Qed.

(***********************************************************************)
(** * Connecting "freshening" *)
(***********************************************************************)


(** The abstract machine uses the nominal [swap] operation to make sure
    that the variables in abstractions are "fresh".  To be able prove that
    this machine implements the step relation for LN terms, we need to
    connect this operation to a LN version of "freshening".

    The [swap_spec] lemma below states that connection. If a variable [y]
    is "fresh", then substituting with it (in the LN representation) is the
    same as swapping with it (in the nominal representation).

<<
Lemma swap_spec : forall  n w y,
    y `notin` fv_exp (nom_to_exp n) ->
    w <> y ->
    [w ~> var_f y] (nom_to_exp n) =
    nom_to_exp (swap w y n).
>>

 *)

(** This proof depends on the following auxiliary lemma about the
    close operation --- that we can equivalently rename the atom that
    we are closing with. *)
(* LATER *)
(* SCW: Make LNgen generate this? *)
(* /LATER *)
Lemma close_exp_wrt_exp_freshen : forall x y e,
    y `notin` fv_exp e ->
    close_exp_wrt_exp x e =
    close_exp_wrt_exp y ([x ~> var_f y] e).
Proof.
  intros x y e.
  unfold close_exp_wrt_exp.
  generalize 0 as k.
  generalize e. clear e.
  induction e; default_simp.
Qed.

Hint Rewrite swap_size_eq : lngen.
Hint Resolve le_S_n : lngen.

(** One difficulty of [swap_spec] is that we cannot do induction on
    the structure of nominal terms. Instead, we must use a size
    based instead. That way, we will be able to call the IH on subterms
    that have had their variables swapped. *)
Lemma swap_spec_aux : forall m t w y,
    size t <= m ->
    y `notin` fv_exp (nom_to_exp t) ->
    w <> y ->
    [w ~> var_f y] (nom_to_exp t) =
    nom_to_exp (swap w y t).
Proof.
  induction m; intros t w y SZ;
  destruct t; simpl in *; try omega;
  intros.
  + unfold swap_var; default_simp.
  + unfold swap_var; default_simp.
    { (* w is the binder *)
      autorewrite with lngen in *.
      rewrite subst_exp_fresh_eq; default_simp.
      rewrite (close_exp_wrt_exp_freshen w y); try fsetdec.
      rewrite IHm; default_simp.  }
    { (* y is the binder *)
       autorewrite with lngen in *.
       (* don't know anything about w or y. Either one could
          appear in n. So our IH is useless now. *)
       (* Let's pick a fresh variable z and use it with that. *)
       pick fresh z for (
              fv_exp (nom_to_exp t) \u
              fv_exp (nom_to_exp (swap w y t)) \u {{w}} \u {{y}}).

       rewrite (close_exp_wrt_exp_freshen y z); auto.
       rewrite subst_exp_close_exp_wrt_exp; auto.

       rewrite IHm; auto with lngen.
       rewrite (close_exp_wrt_exp_freshen w z); auto.

       rewrite IHm; default_steps.
       rewrite IHm; default_steps.
       rewrite shuffle_swap; auto.

       rewrite <- fv_nom_fv_exp_eq.
       apply fv_nom_swap.
       rewrite fv_nom_fv_exp_eq.
       fsetdec.
    }
    { (* neither are binders *)
       rewrite <- IHm; default_steps.
       autorewrite with lngen in *.
       fsetdec.
    }
  + rewrite IHm; auto; try omega; try fsetdec.
    rewrite IHm; auto; try omega; try fsetdec.
Qed.

Lemma swap_spec : forall t w y,
    y `notin` fv_exp (nom_to_exp t) ->
    w <> y ->
    [w ~> var_f y] (nom_to_exp t) =
    nom_to_exp (swap w y t).
Proof.
  intros.
  eapply swap_spec_aux with (t:=t)(m:=size t); auto.
Qed.

(***********************************************************************)
(** * Connection for alpha-equivalence                                 *)
(***********************************************************************)

(** Challenge Exercise: aeq iff =

    Show that alpha-equivalence for the nominal representation is definitional
    equality for LN terms.

*)

Lemma aeq_nom_to_exp : forall n1 n2, aeq n1 n2 -> nom_to_exp n1 = nom_to_exp n2.
Proof.
  (* ADMITTED *)
  induction 1; default_simp;
  autorewrite with lngen in *.
  - congruence.
  - rewrite (close_exp_wrt_exp_freshen y x); auto.
    rewrite swap_spec; auto.
    congruence.
Qed. (* /ADMITTED *)

Hint Rewrite subst_exp_open_exp_wrt_exp : lngen.

Lemma nom_to_exp_eq_aeq : forall n1 n2, nom_to_exp n1 = nom_to_exp n2 -> aeq n1 n2.
Proof.
  (* ADMITTED *)
  induction n1; intro n2; destruct n2; default_simp.
  destruct (x == x0).
  - subst. eauto with lngen.
  - assert (FX : x `notin` fv_exp (nom_to_exp n2)).
    { intro IN.
      assert (x `in` fv_exp (nom_to_exp (n_abs x0 n2))).
      { simpl. autorewrite with lngen. fsetdec. }
      simpl in *.
      rewrite <- H0 in H.
      autorewrite with lngen in *.
      fsetdec. }
    eapply aeq_abs_diff; auto.
    + autorewrite with lngen. auto.
    + eapply IHn1.
      rewrite <- swap_spec; eauto.
      rewrite subst_exp_spec.
      rewrite <- H0.
      autorewrite with lngen.
      auto.
Qed. (* /ADMITTED *)

(***********************************************************************)
(** * SIMULATION                                                       *)
(***********************************************************************)

Inductive scoped_conf : atoms -> conf -> Prop :=
  scoped_conf_witness : forall D h e s,
    scoped_heap D h ->
    fv_exp (nom_to_exp e) [<=] dom h \u D ->
    fv_stack s [<=] dom h \u D  ->
    scoped_conf D (h,e,s).

(* Could be zero or one steps! *)
Lemma simulate_step : forall D h e s h' e' s' ,
    machine_step (dom h \u D) (h,e,s) = TakeStep _ (h',e',s') ->
    scoped_conf D (h,e,s) ->
    decode (h,e,s) = decode (h',e',s') \/
    step (decode (h,e,s)) (decode (h',e',s')).
Proof.
  intros D h e s h' e' s' STEP SCOPE.
  inversion SCOPE; subst; clear SCOPE.
  simpl in *.
  destruct (isVal e) eqn:?.
  destruct s.
  - inversion STEP.
  - destruct f eqn:?.
    + destruct e eqn:?; try solve [inversion STEP].
       right.
       destruct AtomSetProperties.In_dec;
       try destruct atom_fresh;
       inversion STEP; subst; clear STEP;
       simpl in *;
       rewrite combine;
       rewrite apply_stack_fresh_eq; auto; try fsetdec;
       apply apply_stack_cong;
       autorewrite with lngen in *;
       simpl.

       -- assert (x <> x0) by fsetdec.
          rewrite <- swap_spec; auto; try fsetdec.
          rewrite (subst_exp_spec _ _ x).
          autorewrite with lngen; auto with lngen.
          default_simp.
          rewrite subst_exp_fresh_eq; autorewrite with lngen; auto.

          apply step_beta; auto with lngen.
          rewrite <- apply_heap_abs.
          eapply apply_heap_lc.
          auto with lngen.

          rewrite H4. fsetdec.
       -- rewrite subst_exp_spec.
          rewrite apply_heap_open; auto with lngen.

          apply step_beta; auto with lngen.
          rewrite <- apply_heap_abs.
          eapply apply_heap_lc.
          auto with lngen.

  - destruct e eqn:?; try solve [inversion STEP].
    + destruct (get x h) eqn:?; inversion STEP; subst; clear STEP.
      left.
      f_equal.
      apply apply_heap_get with (D:= D); auto.
    + inversion STEP; subst; clear STEP.
      left.
      simpl.
      rewrite apply_heap_app.
      auto.
Qed.

(** Exercise [simulate_done]

    Show that if the machine says [Done] then the LN term is a value.
*)

Lemma simulate_done : forall D h e s,
    machine_step (dom h \u D) (h,e,s) = Done _ ->
    scoped_conf D (h,e,s) ->
    is_value (nom_to_exp e).
Proof. (* ADMITTED *)
  intros.
  inversion H0; subst.
  simpl in *.
  destruct (isVal e) eqn:?.
  destruct s eqn:?.
  - destruct e; simpl in Heqb; inversion Heqb.
    econstructor; eauto.
  - destruct f eqn:?.
     + destruct e eqn:?; simpl; try solve [inversion H].
       econstructor; eauto.
  - destruct e; inversion H.
    simpl in Heqb. destruct (get x h); inversion H.
Qed. (* /ADMITTED *)



(** Challenge exercise [simulate_error]

    Show that if the machine produces an error, the small step relation
    is stuck.

    This is a challenge exercise because you will need to figure out
    at least one nontrivial auxiliary lemma.

*)


(* SOLUTION *)
Lemma apply_heap_get_none : forall x h,
    get x h = None ->
    apply_heap h (var_f x) = var_f x.
Proof.
  intros.
  alist induction h; simpl in *; auto.
  default_simp.
Qed.

Lemma no_step_stack : forall s h e0,
  not (is_value e0) ->
  not (exists e0', step e0 e0') ->
  not (exists e1, step (apply_stack h s e0) e1).
Proof.
  induction s; intros; try destruct a; simpl in *; auto.
  intros [e1 STEP].
  assert (K1: not (exists e1', step (app e0 (apply_heap h (nom_to_exp n))) e1')).
  { intros [e1' SS].
    inversion SS. subst. simpl in *. contradiction.
    subst. eauto. }
  assert (K2: not (is_value (app e0 (apply_heap h (nom_to_exp n))))).
  { simpl. auto. }
  pose (K := IHs h _ K2 K1). clearbody K.
  eauto.
Qed.
(* /SOLUTION *)

Lemma simulate_error : forall D h e s,
    machine_step (dom h \u D) (h,e,s) = Error _ ->
    scoped_conf D (h,e,s) ->
    not (exists e0, step (decode (h,e,s)) e0).
Proof.
(* ADMITTED *)
  intros.
  simpl in *.
  destruct (isVal e) eqn:?.
  destruct s.
  - destruct e; try solve [inversion H]; simpl in Heqb; inversion Heqb.
  - destruct f eqn:?.
    destruct e eqn:?; try solve [inversion H]; simpl in Heqb; inversion Heqb.
    destruct (AtomSetProperties.In_dec).
    + destruct atom_fresh. inversion H.
    + inversion H.
  - destruct e; try solve [inversion H]; simpl in Heqb; inversion Heqb.
    destruct (get x h) eqn:?. inversion H.
    intros [e0 STEP].
    simpl in *.
    rewrite apply_heap_get_none in STEP; auto.
    eapply no_step_stack with (e0 := var_f x); auto.
       intros [e0' SS]. inversion SS. eauto.
Qed. (* /ADMITTED *)

(***********************************************************************)

Lemma machine_is_scoped: forall D h e s conf',
    machine_step (dom h \u D) (h,e,s) = TakeStep _ conf' ->
    scoped_conf D (h,e,s) ->
    scoped_conf D conf'.
Proof.
  (* ADMITTED *)
  intros.
  simpl in H.
  inversion H0. subst.
  destruct (isVal e) eqn:?.
  destruct s eqn:?.
  - inversion H.
  - destruct f eqn:?.
     + destruct e eqn:?; try solve [inversion H].
       destruct AtomSetProperties.In_dec.
       ++ destruct atom_fresh.
          inversion H; subst; clear H.
          simpl in *.
          econstructor.
            -- econstructor; eauto. fsetdec.
            -- assert (x <> x0). fsetdec.
               autorewrite with lngen in *.
               rewrite <- swap_spec; try fsetdec.
               rewrite fv_exp_subst_exp_upper.
               simpl.
               fsetdec.
            -- simpl. fsetdec.
       ++ inversion H; subst; clear H.
          simpl in *.
          autorewrite with lngen in *.
          econstructor.
          -- econstructor; eauto. fsetdec.
          -- simpl.
             assert ((union (add x (dom h)) D) [=] (add x (union (dom h) D))).
             fsetdec. rewrite H.
             rewrite <- H6.
             eapply FSetDecideTestCases.test_Subset_add_remove.
          -- simpl. fsetdec.
  - destruct e eqn:?; try solve [inversion H].
    destruct (get x h) eqn:?;
    inversion H; subst; clear H.
    + split. auto.
      simpl in *.
      eapply scoped_get; eauto.
      fsetdec.
      auto.
    + simpl in *.
    inversion H; subst; clear H.
    econstructor.
    auto.
    fsetdec.
    simpl. fsetdec.
Qed. (* /ADMITTED *)
