From Coq Require Import ssreflect ssrbool.
From Coq Require Import Program RelationClasses Morphisms.
From Coq Require Import OrderedTypeAlt OrderedTypeEx MSetList MSetAVL MSetFacts MSetProperties MSetDecide.
From MetaCoq.Template Require Import utils Universes.
From Equations Require Import Equations.
Set Equations Transparent.

Definition clause : Type := nonEmptyLevelExprSet × LevelExpr.t.
Module Clause.
  Definition t := clause.

  Definition eq : t -> t -> Prop := eq.

  Definition eq_equiv : RelationClasses.Equivalence eq := _.

  Inductive lt_ : t -> t -> Prop :=
  | lt_clause1 l e e' : LevelExpr.lt e e' -> lt_ (l, e) (l, e')
  | lt_clause2 l l' b b' : LevelExprSet.lt l.(t_set) l'.(t_set) -> lt_ (l, b) (l', b').

  Definition lt := lt_.

  Global Instance lt_strorder : RelationClasses.StrictOrder lt.
  Proof.
    constructor.
    - intros x X; inversion X; subst. now eapply LevelExpr.lt_strorder in H1.
      eapply LevelExprSet.lt_strorder; eassumption.
    - intros x y z X1 X2; invs X1; invs X2; constructor; tea.
      etransitivity; tea.
      etransitivity; tea.
  Qed.

  Definition lt_compat : Proper (Logic.eq ==> Logic.eq ==> iff) lt.
    intros x x' H1 y y' H2. unfold lt. subst. reflexivity.
  Qed.

  Definition compare (x y : t) : comparison :=
    match x, y with
    | (l1, b1), (l2, b2) =>
      match LevelExprSet.compare l1.(t_set) l2.(t_set) with
      | Eq => LevelExpr.compare b1 b2
      | x => x
      end
    end.

  Definition compare_spec :
    forall x y : t, CompareSpec (x = y) (lt x y) (lt y x) (compare x y).
  Proof.
    intros [? ?] [? ?]; cbn; repeat constructor.
    destruct (LevelExprSet.compare_spec n n0); repeat constructor; tas.
    eapply LevelExprSet.eq_leibniz in H. apply NonEmptySetFacts.eq_univ in H.
    subst. cbn in *.
    destruct (LevelExpr.compare_spec t0 t1); repeat constructor; tas. now subst.
  Qed.

  Global Instance reflect_t : ReflectEq t := reflect_prod _ _ .

  Definition eq_dec : forall (l1 l2 : t), {l1 = l2} + {l1 <> l2} := Classes.eq_dec.

  Definition eq_leibniz (x y : t) : eq x y -> x = y := id.
End Clause.

Module Clauses := MSetList.MakeWithLeibniz Clause.
Module ClausesFact := WFactsOn Clause Clauses.
Module ClausesProp := WPropertiesOn Clause Clauses.
Module ClausesDecide := WDecide (Clauses).
Ltac clsets := ClausesDecide.fsetdec.

Definition clauses := Clauses.t.

Lemma filter_add {p x s} : Clauses.Equal (Clauses.filter p (Clauses.add x s)) (if p x then Clauses.add x (Clauses.filter p s) else Clauses.filter p s).
Proof.
  intros i.
  rewrite Clauses.filter_spec.
  destruct (eqb_spec i x); subst;
  destruct (p x) eqn:px; rewrite !Clauses.add_spec !Clauses.filter_spec; intuition auto || congruence.
Qed.

Instance proper_fold_transpose {A} (f : Clauses.elt -> A -> A) :
  transpose eq f ->
  Proper (Clauses.Equal ==> eq ==> eq) (Clauses.fold f).
Proof.
  intros hf s s' Hss' x ? <-.
  eapply ClausesProp.fold_equal; tc; tea.
Qed.
Existing Class transpose.

Lemma clauses_fold_filter {A} (f : Clauses.elt -> A -> A) (p : Clauses.elt -> bool) cls acc : 
  transpose Logic.eq f ->
  Clauses.fold f (Clauses.filter p cls) acc = 
  Clauses.fold (fun elt acc => if p elt then f elt acc else acc) cls acc.
Proof.
  intros hf.
  symmetry. eapply ClausesProp.fold_rec_bis.
  - intros s s' a eq. intros ->. 
    eapply ClausesProp.fold_equal; tc. auto.
    intros x.
    rewrite !Clauses.filter_spec.
    now rewrite eq.
  - now cbn.
  - intros.
    rewrite H1.
    rewrite filter_add.
    destruct (p x) eqn:px => //.
    rewrite ClausesProp.fold_add //.
    rewrite Clauses.filter_spec. intuition auto.
Qed.

Module MoreLevel.

  Include Level.

  Lemma compare_sym : forall x y : t, (compare y x) = CompOpp (compare x y).
  Proof.
    induction x; destruct y; simpl; auto.
    apply StringOT.compare_sym.
    apply PeanoNat.Nat.compare_antisym.
  Qed.
  
  Lemma eq_refl x : eq x x.
  Proof. red. reflexivity. Qed.

  Lemma eq_sym x y : eq x y -> eq y x.
  Proof. unfold eq. apply symmetry. Qed.
 
  Lemma eq_trans x y z : eq x y -> eq y z -> eq x z.
  Proof. unfold eq. apply transitivity. Qed.

  Infix "?=" := compare.

  Lemma compare_trans :
    forall c (x y z : t), (x?=y) = c -> (y?=z) = c -> (x?=z) = c.
  Proof.
    intros c x y z.
    destruct (compare_spec x y) => <-; subst.
    destruct (compare_spec y z); auto.
    destruct (compare_spec y z); auto; try congruence.
    destruct (compare_spec x z); auto; try congruence.
    subst. elimtype False. eapply (irreflexivity (A:=t)). etransitivity; [exact H|exact H0].
    elimtype False. eapply (irreflexivity (A:=t)). etransitivity; [exact H|]. 
    eapply transitivity; [exact H0|exact H1].
    destruct (compare_spec y z); auto; try congruence.
    destruct (compare_spec x z); auto; try congruence.
    subst. elimtype False. eapply (irreflexivity (A:=t)). etransitivity; [exact H|exact H0].
    elimtype False. eapply (irreflexivity (A:=t)). etransitivity; [exact H|]. 
    eapply transitivity; [exact H1|exact H0].
  Qed.

  Lemma compare_eq {x y} : compare x y = Eq <-> x = y.
  Proof.
    destruct (compare_spec x y) => //.
    intuition auto. congruence. subst.
    now apply lt_strorder in H.
    intuition auto. congruence. subst.
    now apply lt_strorder in H.
  Qed.
End MoreLevel.

Module LevelOT := OrderedType_from_Alt MoreLevel.
Module LevelMap := FMapAVL.Make LevelOT.
Module LevelMapFact := FMapFacts.WProperties LevelMap.

Definition levelexpr_level : LevelExpr.t -> Level.t := fst.
Coercion levelexpr_level : LevelExpr.t >-> Level.t.

Definition strict_subset (s s' : LevelSet.t) :=
  LevelSet.Subset s s' /\ ~ LevelSet.Equal s s'.

Lemma strict_subset_incl (x y z : LevelSet.t) : LevelSet.Subset x y -> strict_subset y z -> strict_subset x z.
Proof.
  intros hs []. split => //. lsets.
  intros heq. apply H0. lsets.
Qed.

Lemma strict_subset_cardinal s s' : strict_subset s s' -> LevelSet.cardinal s < LevelSet.cardinal s'.
Proof.
  intros [].
  assert (LevelSet.cardinal s <> LevelSet.cardinal s').
  { intros heq. apply H0. 
    intros x. split; intros. now apply H.
    destruct (LevelSet.mem x s) eqn:hin.
    eapply LevelSet.mem_spec in hin.
    auto. eapply LevelSetProp.FM.not_mem_iff in hin.
    exfalso.
    eapply LevelSetProp.subset_cardinal_lt in hin; tea.
    lia. }
  enough (LevelSet.cardinal s <= LevelSet.cardinal s') by lia.
  now eapply LevelSetProp.subset_cardinal.
Qed.

Definition premise (cl : clause) := fst cl.

Definition concl (cl : clause) := snd cl.

Definition clause_levels cl :=
  LevelSet.union (LevelExprSet.levels (premise cl)) (LevelSet.singleton (levelexpr_level (concl cl))).

Definition clauses_levels (cls : clauses) : LevelSet.t := 
  Clauses.fold (fun cl acc => LevelSet.union (clause_levels cl) acc) cls LevelSet.empty.

Lemma Clauses_In_elements l s : 
  In l (Clauses.elements s) <-> Clauses.In l s.
Proof.
  rewrite ClausesFact.elements_iff.
  now rewrite InA_In_eq.
Qed.

Lemma clauses_levels_spec_aux l cls acc :
  LevelSet.In l (Clauses.fold (fun cl acc => LevelSet.union (clause_levels cl) acc) cls acc) <->
  (exists cl, Clauses.In cl cls /\ LevelSet.In l (clause_levels cl)) \/ LevelSet.In l acc.
Proof.
  eapply ClausesProp.fold_rec.
  - intros.
    intuition auto. destruct H1 as [k [hin hl]]. clsets.
  - intros x a s' s'' hin nin hadd ih.
    rewrite LevelSet.union_spec.
    split.
    * intros [hin'|].
      left. exists x. split => //.
      apply hadd. now left.
      apply ih in H.
      intuition auto.
      left. destruct H0 as [k Hk]. exists k. intuition auto. apply hadd. now right.
    * intros [[k [ins'' ?]]|inacc].
      eapply hadd in ins''. destruct ins''; subst.
      + now left.
      + right. apply ih. now left; exists k.
      + right. intuition auto.
Qed.
 
Lemma clauses_levels_spec l cls :
  LevelSet.In l (clauses_levels cls) <-> 
  exists cl, Clauses.In cl cls /\ LevelSet.In l (clause_levels cl).
Proof.
  unfold clauses_levels.
  rewrite clauses_levels_spec_aux.
  intuition auto. lsets.
Qed.

Lemma clause_levels_spec l cl :
  LevelSet.In l (clause_levels cl) <-> 
  LevelSet.In l (LevelExprSet.levels (premise cl)) \/ l = levelexpr_level (concl cl).
Proof.
  unfold clause_levels.
  now rewrite LevelSet.union_spec LevelSet.singleton_spec. 
Qed.

Definition model := LevelMap.t nat.

(* Print maps to nat nicely *)
Fixpoint to_bytes (s : string) : list Byte.byte :=
  match s with
  | String.EmptyString => []
  | String.String b s => b :: to_bytes s
  end.

Declare Scope levelnat_scope.
Delimit Scope levelnat_scope with levelnat.
Module LevelNatMapNotation.
  Import LevelMap.Raw.
  Notation levelmap := (tree nat) (only parsing).
  Definition parse_levelnat_map (l : list Byte.byte) : option levelmap :=
    None.
  Definition print_levelnat_map (m : levelmap) :=
    let list := LevelMap.Raw.elements m in
    print_list (fun '(l, w) => string_of_level l ^ " -> " ^ string_of_nat w) nl list.
   
  Definition print_levelmap (l : levelmap) : list Byte.byte :=
    to_bytes (print_levelnat_map l).
   
  String Notation levelmap parse_levelnat_map print_levelmap
      : levelnat_scope.
End LevelNatMapNotation.
Import LevelNatMapNotation.
Arguments LevelMap.Bst {elt} this%levelnat {is_bst}.

Definition level_value (m : model) (level : Level.t) : nat :=
  match LevelMap.find level m with
  | Some val => val
  | None => 0
  end.

Definition levelexpr_value (m : model) (atom : LevelExpr.t) :=
  level_value m (levelexpr_level atom).

Lemma non_empty_choose (l : nonEmptyLevelExprSet) : LevelExprSet.choose l = None -> False.
Proof.
  intros Heq.
  eapply LevelExprSet.choose_spec2, LevelExprSetFact.is_empty_1 in Heq.
  destruct l. cbn in *. congruence.    
Defined.

Arguments exist {A P}.  
Definition inspect {A} (x : A) : { y : A | x = y } := exist x eq_refl.

Equations choose (s : nonEmptyLevelExprSet) : LevelExpr.t :=
  choose s with inspect (LevelExprSet.choose s) := 
  | exist (Some l) _ => l
  | exist None heq => False_rect _ (non_empty_choose s heq).

Lemma choose_spec l : LevelExprSet.In (choose l) l.
Proof.
  unfold choose.
  destruct inspect.
  destruct x; simp choose. 2:bang.
  now eapply LevelExprSet.choose_spec1 in e.
Qed.

Lemma choose_spec_1 (l : nonEmptyLevelExprSet) : LevelExprSet.choose l = Some (choose l).
Proof.
  unfold choose.
  destruct inspect.
  destruct x; simp choose. bang.
Qed.

Definition min_atom_value (m : model) (atom : LevelExpr.t) :=
  let '(l, k) := atom in
  (Z.of_nat (level_value m l) - Z.of_nat k)%Z.

Definition min_premise (m : model) (l : nonEmptyLevelExprSet) : Z :=
  let (hd, tl) := NonEmptySetFacts.to_nonempty_list l in
  fold_left (fun min atom => Z.min (min_atom_value m atom) min) tl (min_atom_value m hd).

Definition satisfiable_atom (m : model) (atom : Level.t * nat) : bool :=
  let '(l, k) := atom in
  match LevelMap.find l m with
  | Some val => k <=? val
  | None => false
  end.
  
Definition satisfiable_premise (m : model) (l : nonEmptyLevelExprSet) :=
  LevelExprSet.for_all (satisfiable_atom m) l.

(* Definition valid_clause (m : model) (cl : clause) := *)
  (* implb (satisfiable_premise m (premise cl)) (satisfiable_atom m (concl cl)). *)

Definition valid_clause (m : model) (cl : clause) :=
  let k0 := min_premise m (premise cl) in
  if (k0 <? 0)%Z then true
  else let (l, k) := concl cl in 
    k + Z.to_nat k0 <=? level_value m l.
  
Definition is_model (cls : clauses) (m : model) : bool :=
  Clauses.for_all (valid_clause m) cls.

Inductive update_result := 
  | VacuouslyTrue
  | Holds
  | DoesntHold (wm : LevelSet.t × model).

Definition update_model (m : model) l v : model := LevelMap.add l v m.

Definition update_value (wm : LevelSet.t × model) (cl : clause) : update_result :=
  let (w, m) := wm in
  let k0 := min_premise m (premise cl) in
  (* cl holds vacuously as the premise doesn't hold *)
  if (k0 <? 0)%Z then VacuouslyTrue
  else 
    (* The premise does hold *)
    let (l, k) := concl cl in
    (* Does the conclusion also hold?
       We optimize a bit here, rather than adding k0 in a second stage, 
       we do it already while checking the clause. In the paper, a second
       pass computes this.
      *)
    if k + Z.to_nat k0 <=? level_value m l then Holds
    else 
      (* The conclusion doesn't hold, we need to set it higher *)
      DoesntHold (LevelSet.add l w, update_model m l (k + Z.to_nat k0)).

Definition check_clause_model cl '(modified, wm) := 
  match update_value wm cl with 
  | VacuouslyTrue => (modified, wm)
  | DoesntHold wm' => (true, wm')
  | Holds => (modified, wm)
  end.

Definition check_model_aux (cls : clauses) (wm : LevelSet.t × model) : bool × (LevelSet.t × model) :=
  Clauses.fold check_clause_model cls (false, wm).

(* If check_model = None then we have a model of all clauses, 
  othewise, we return Some (W', m') where W ⊂ W' and the model has
  been updated for at least one atom l ∈ W'. *)
Definition check_model (cls : clauses) (wm : LevelSet.t × model) := 
  let '(modified, wm) := check_model_aux cls wm in
  if modified then Some wm else None.

Lemma check_model_aux_subset {cls w v} : 
  forall b w' v', check_model_aux cls (w, v) = (b, (w', v')) -> LevelSet.Subset w w'.
Proof.
  intros w' v'.
  unfold check_model, check_model_aux, check_clause_model. revert w' v'.
  eapply ClausesProp.fold_rec => //.
  { intros. noconf H0. reflexivity. }
  intros x a s' s'' hin nin hadd IH.
  intros b w' v'. destruct a.
  destruct p as []. 
  unfold update_value.
  destruct Z.ltb. intros [= -> -> ->] => //.
  now eapply IH.
  destruct x as [prem [l k]]; cbn.
  destruct Nat.leb. intros [= -> -> ->] => //. now eapply IH.
  intros [= <- <- <-]. intros x inx.
  eapply LevelSet.add_spec.
  specialize (IH _ _ _ eq_refl).
  now right.
Qed.

Lemma check_model_subset {cls w v} : 
  forall w' v', check_model cls (w, v) = Some (w', v') -> LevelSet.Subset w w'.
Proof.
  intros w' v'. unfold check_model.
  destruct check_model_aux eqn:cm.
  destruct p as [W m].
  eapply check_model_aux_subset in cm.
  destruct b => //. now intros [= <- <-].
Qed.

Definition restrict_clauses (cls : clauses) (W : LevelSet.t) :=
  Clauses.filter (fun '(prem, concla) =>
    LevelSet.subset (LevelExprSet.levels prem) W &&
    LevelSet.mem (LevelExpr.get_level concla) W) cls.

Lemma in_restrict_clauses (cls : clauses) (concls : LevelSet.t) cl :
  Clauses.In cl (restrict_clauses cls concls) <-> 
  [/\ LevelSet.In (LevelExpr.get_level (concl cl)) concls,
    LevelSet.Subset (LevelExprSet.levels (premise cl)) concls &
    Clauses.In cl cls].
Proof.
  unfold restrict_clauses.
  rewrite Clauses.filter_spec.
  destruct cl. cbn.
  rewrite andb_true_iff LevelSet.subset_spec LevelSet.mem_spec.
  firstorder auto.
Qed.

Definition clauses_with_concl (cls : clauses) (concl : LevelSet.t) :=
  Clauses.filter (fun '(prem, concla) => LevelSet.mem (LevelExpr.get_level concla) concl) cls.

Lemma in_clauses_with_concl (cls : clauses) (concls : LevelSet.t) cl :
  Clauses.In cl (clauses_with_concl cls concls) <-> 
  LevelSet.In (LevelExpr.get_level (concl cl)) concls /\ Clauses.In cl cls.
Proof.
  unfold clauses_with_concl.
  rewrite Clauses.filter_spec.
  destruct cl. rewrite LevelSet.mem_spec. cbn. firstorder eauto.
Qed.

Definition clauses_conclusions (cls : clauses) : LevelSet.t :=
  Clauses.fold (fun cl acc => LevelSet.add (LevelExpr.get_level (concl cl)) acc) cls LevelSet.empty.
  
Lemma clauses_conclusions_spec a cls : 
  LevelSet.In a (clauses_conclusions cls) <-> 
  exists cl, Clauses.In cl cls /\ LevelExpr.get_level (concl cl) = a.
Proof.
  unfold clauses_conclusions.
  eapply ClausesProp.fold_rec; clear.
  - move=> s' he /=. rewrite LevelSetFact.empty_iff.
    firstorder auto.
  - move=> cl ls cls' cls'' hin hnin hadd ih.
    rewrite LevelSet.add_spec. firstorder eauto.
    specialize (H0 x). cbn in H0.
    apply hadd in H1. firstorder eauto.
    subst. left. now destruct x.
Qed.

Lemma clauses_conclusions_clauses_with_concl cls concl : 
  LevelSet.Subset (clauses_conclusions (clauses_with_concl cls concl)) concl.
Proof.
  intros x [cl []] % clauses_conclusions_spec.
  eapply in_clauses_with_concl in H as [].
  now rewrite H0 in H.
Qed.

Lemma clauses_conclusions_restrict_clauses cls W : 
  LevelSet.Subset (clauses_conclusions (restrict_clauses cls W)) W.
Proof.
  intros x [cl []] % clauses_conclusions_spec.
  eapply in_restrict_clauses in H as [].
  now rewrite H0 in H.
Qed.

Definition in_clauses_conclusions (cls : clauses) (x : Level.t): Prop :=
  exists cl, Clauses.In cl cls /\ (LevelExpr.get_level cl.2) = x.

Infix "⊂_lset" := LevelSet.Subset (at level 70).
Infix "∪" := LevelSet.union (at level 70).

Definition v_minus_w_bound (W : LevelSet.t) (m : model) := 
  LevelMap.fold (fun w v acc => Nat.max v acc) 
    (LevelMapFact.filter (fun l _ => ~~ LevelSet.mem l W) m) 0.

Definition levelexpr_k : LevelExpr.t -> nat := snd.
Coercion levelexpr_k : LevelExpr.t >-> nat.

Definition level_expr_elt : LevelExprSet.elt -> LevelExpr.t := fun x => x.
Coercion level_expr_elt : LevelExprSet.elt >-> LevelExpr.t.

Definition premise_min (l : nonEmptyLevelExprSet) : nat :=
  let (hd, tl) := NonEmptySetFacts.to_nonempty_list l in
  fold_left (B:=LevelExpr.t) (fun min atom => Nat.min atom min) tl hd.

Definition gain (cl : clause) : Z :=
  Z.of_nat (levelexpr_k (concl cl)) - Z.of_nat (premise_min (premise cl)).

Definition max_gain (cls : clauses) := 
  Clauses.fold (fun cl acc => Nat.max (Z.to_nat (gain cl)) acc) cls 0.

Definition model_same_domain (m m' : model) := 
  forall l, LevelMap.In l m <-> LevelMap.In l m'.

#[local] Instance model_same_domain_refl : Reflexive model_same_domain.
Proof. intros m l. reflexivity. Qed.

#[local] Instance model_same_domain_trans : Transitive model_same_domain.
Proof. intros m m' m'' h h' l. rewrite (h l). apply h'. Qed.

Definition model_le (m m' : model) := 
  forall l k, LevelMap.MapsTo l k m -> 
  exists k', LevelMap.MapsTo l k' m' /\ k <= k'.
    
Infix "⩽" := model_le (at level 70). (* \leqslant *)

Definition model_map_outside V (m m' : model) :=
  forall l, ~ LevelSet.In l V -> 
    forall k, LevelMap.MapsTo l k m <-> LevelMap.MapsTo l k m'.

#[local] Instance model_map_outside_refl V : Reflexive (model_map_outside V).
Proof. intros m l. reflexivity. Qed.

#[local] Instance model_map_outside_trans V : Transitive (model_map_outside V).
Proof.
  intros m m' m'' h h' l hnin k.
  rewrite (h l hnin k). now apply h'.
Qed.

(** The termination proof relies on the correctness of check_model: 
  it does strictly increase a value but not above [max_gain cls].
*)

Lemma clauses_conclusions_diff cls s : 
  clauses_conclusions (Clauses.diff cls (clauses_with_concl cls s)) ⊂_lset
  LevelSet.diff (clauses_conclusions cls) s.
Proof.
  intros a. rewrite LevelSet.diff_spec !clauses_conclusions_spec.
  firstorder eauto.
  exists x; split => //.
  now rewrite Clauses.diff_spec in H.
  intros ha.
  rewrite Clauses.diff_spec in H; destruct H as [].
  apply H1.
  rewrite in_clauses_with_concl. split => //.
  now rewrite H0.
Qed.

Lemma diff_eq U V : LevelSet.diff V U =_lset V <-> LevelSet.inter V U =_lset LevelSet.empty.
Proof. split. lsets. lsets. Qed.

Lemma levelset_neq U V : LevelSet.equal U V = false -> ~ LevelSet.Equal U V.
Proof. intros eq heq % LevelSet.equal_spec. congruence. Qed.

Lemma levelset_union_same U : LevelSet.union U U =_lset U.
Proof. lsets. Qed.

Lemma fold_left_comm {A B} (f : B -> A -> B) (l : list A) (x : A) (acc : B) : 
  (forall x y z, f (f z x) y = f (f z y) x) ->
  fold_left f l (f acc x) = f (fold_left f l acc) x.
Proof.
  intros.
  induction l in acc, x |- *; cbn. auto.
  rewrite -IHl. f_equal. now rewrite H.
Qed.

Lemma fold_left_le (f g : nat -> LevelSet.elt -> nat) l : 
  (forall acc acc' x, In x l -> acc <= acc' -> f acc x <= g acc' x) ->
  forall acc acc', acc <= acc' ->
  fold_left f l acc <= fold_left g l acc'.
Proof.
  intros hfg.
  induction l => //. cbn. intros.
  apply IHl. intros. apply hfg => //. now right. apply hfg => //. now left.
Qed.

Lemma fold_left_ne_lt (f g : nat -> LevelSet.elt -> nat) l acc : 
  (forall (x y : LevelSet.elt) z, f (f z x) y = f (f z y) x) ->
  (forall (x y : LevelSet.elt) z, g (g z x) y = g (g z y) x) ->
  l <> [] ->
  (forall acc acc' x, In x l -> (acc <= acc') -> (f acc x <= g acc' x)) ->
  (forall acc acc' x, In x l -> (acc < acc') -> (f acc x < g acc' x)) ->
  (exists x, In x l /\ forall acc acc', (acc <= acc') -> (f acc x < g acc' x)) ->
  fold_left f l acc < fold_left g l acc.
Proof.
  intros hf hg.
  generalize (Nat.le_refl acc).
  generalize acc at 2 4.
  induction l in acc |- * => //.
  intros.
  destruct l; cbn.
  { destruct H3 as [x []]. cbn in H3. destruct H3; subst => //.
    now eapply (H4 acc acc0). }
  cbn in IHl.
  rewrite hf hg.
  rewrite fold_left_comm //. rewrite (fold_left_comm g) //.
  destruct H3 as [min [hmin hfg]].
  destruct hmin as [<-|hel].
  - apply hfg. apply fold_left_le => //. intros; eapply H1 => //. now right; right.
    apply H1 => //. now right; left.
  - apply H2. now left. eapply IHl => //.
    * intros acc1 acc' x hin. apply (H1 acc1 acc' x). now right.
    * intros acc1 acc' x hin. apply (H2 acc1 acc' x). now right.
    * exists min. split => //.
Qed.

Infix "↓" := clauses_with_concl (at level 70). (* \downarrow *)
Infix "⇂" := restrict_clauses (at level 70). (* \downharpoonright *)

Lemma clauses_conclusions_diff_left cls W cls' : 
  clauses_conclusions (Clauses.diff (cls ↓ W) cls') ⊂_lset W.
Proof.
  intros l. 
  rewrite clauses_conclusions_spec.
  move=> [] cl. rewrite Clauses.diff_spec => [] [] [].
  move/in_clauses_with_concl => [] hin ? ? eq.
  now rewrite eq in hin.
Qed.

Lemma clauses_conclusions_diff_restrict cls W cls' : 
  clauses_conclusions (Clauses.diff (cls ⇂ W) cls') ⊂_lset W.
Proof.
  intros l. 
  rewrite clauses_conclusions_spec.
  move=> [] cl. rewrite Clauses.diff_spec => [] [] [].
  move/in_restrict_clauses => [] hin ? ? ? eq.
  now rewrite eq in hin.
Qed.

Lemma LevelSet_In_elements l s : 
  In l (LevelSet.elements s) <-> LevelSet.In l s.
Proof.
  rewrite LevelSetFact.elements_iff.
  now rewrite InA_In_eq.
Qed.

Lemma clauses_empty_eq {s} : Clauses.Empty s -> Clauses.Equal s Clauses.empty.
Proof. clsets. Qed.

Lemma update_value_valid {W m cl} : 
  match update_value (W, m) cl with
  | VacuouslyTrue | Holds => valid_clause m cl
  | DoesntHold _ => ~~ valid_clause m cl
  end.
Proof.
  unfold update_value, valid_clause.
  destruct Z.ltb => //.
  destruct cl as [prem [l k]]; cbn.
  destruct Nat.leb => //.
Qed.

Lemma valid_update_value {W m cl} : 
  valid_clause m cl -> 
  match update_value (W, m) cl with
  | VacuouslyTrue | Holds => true
  | DoesntHold _ => false
  end.
Proof.
  unfold update_value, valid_clause.
  destruct Z.ltb => //.
  destruct cl as [prem [l k]]; cbn.
  destruct Nat.leb => //.
Qed.

Lemma check_model_aux_false {cls acc acc'} : check_model_aux cls acc = (false, acc') -> acc = acc'.
Proof.
  unfold check_model_aux, check_clause_model.
  eapply ClausesProp.fold_rec.
  - intros s emp [=] => //.
  - intros cl [modified [w' m']] cls' cls'' incl nincls' incls''.
    intros IH.
    destruct update_value eqn:upd => //.
Qed.

(* Lemma check_model_aux_true {cls acc acc'} : check_model_aux cls acc = (true, acc') -> acc = acc'.
Proof.
  unfold check_model_aux.
  eapply ClausesProp.fold_rec.
  - intros s emp [=] => //.
  - intros cl [modified [w' m']] cls' cls'' incl nincls' incls''.
    intros IH.
    destruct update_value eqn:upd => //.
Qed. *)

Lemma check_model_aux_model {cls acc} : 
  check_model_aux cls acc = (false, acc) <-> is_model cls acc.2.
Proof.
  unfold check_model_aux, check_clause_model.
  unfold is_model.
  unfold is_true; rewrite -ClausesFact.for_all_iff.
  eapply ClausesProp.fold_rec.
  - intros s emp.
    split => //.
    intros [=] x hx. clsets.
  - intros cl [modified [w' m']] cls' cls'' incl nincls' incls''.
    intros IH.
    split.
    * move: (@update_value_valid w' m' cl).
      destruct update_value eqn:upd => //; intros vcl [= -> <-] ;
        destruct IH as [IH _]; specialize (IH eq_refl).
      intros x hx; apply incls'' in hx as []; subst. exact vcl. now apply IH.
      intros x hx; apply incls'' in hx as []; subst. exact vcl. now apply IH.
    * intros hf.
      assert (valid_clause acc.2 cl).
      { apply hf. apply incls''. intuition auto. }
      destruct IH as [_ IH]. forward IH.
      { intros x hx. apply hf. apply incls''. now right. }
      noconf IH.
      move: (@valid_update_value w' m' cl H).
      destruct update_value eqn:upd => //.
Qed.

Lemma clauses_for_all_neg {p s}: 
  ~~ Clauses.for_all p s <-> ~ Clauses.For_all p s.
Proof.
  intuition auto.
  rewrite ClausesFact.for_all_iff in H0. red in H. now rewrite H0 in H.
  revert H. apply contra_notN.
  rewrite ClausesFact.for_all_iff //.
Qed.

Lemma clauses_for_all_exists {p s}: 
  ~~ Clauses.for_all p s <-> Clauses.exists_ (fun x => ~~ p x) s.
Proof.
  rewrite ClausesFact.for_all_b ClausesFact.exists_b.
  induction (Clauses.elements s).
  - cbn; auto. reflexivity.
  - cbn. rewrite negb_and. intuition auto.
    move/orP: H1 => [->|] //. move/H. intros ->. now rewrite orb_true_r.
    move/orP: H1 => [->|] //. move/H0. intros ->. now rewrite orb_true_r.
Qed.
#[local] Instance model_le_refl : Reflexive model_le.
Proof. intros x l k map. exists k; split => //. Qed.

#[local] Instance model_le_trans : Transitive model_le.
Proof. intros m m' m'' mm' m'm'' l k map.
  apply mm' in map as [k' [map ?]].
  apply m'm'' in map as [k'' [map ?]]. exists k''. split => //. lia.
Qed.

Lemma update_model_monotone m l k : level_value m l <= k -> m ⩽ update_model m l k.
Proof.
  intros hl.
  intros l' k' maps. 
  unfold update_model. cbn.
  destruct (eqb_spec l l').
  - exists k. move: hl. subst l'.
    unfold level_value.
    rewrite (LevelMap.find_1 maps).
    intros hle. 
    split => //. eapply LevelMap.add_1. eapply LevelMap.E.eq_refl.
  - exists k'. split => //. apply LevelMap.add_2 => //.
    intros he. destruct (MoreLevel.compare_spec l l'); congruence.
Qed.

Lemma check_clause_model_inv {cl modified w m b wm'} : 
  check_clause_model cl (modified, (w, m)) = (b, wm') ->
  m ⩽ wm'.2.
Proof.
  unfold check_clause_model.
  destruct (update_value (w, m) cl) eqn:upd.
  * now intros [= <- <-].
  * now intros [= <- <-].
  * intros [= <- <-].
    move: upd.
    unfold update_value.
    case: Z.ltb_spec => //.
    destruct cl as [prem [l k]] => /=.
    intros hprem.
    case: Nat.leb_spec => // hlt.
    intros [= <-]. cbn.
    eapply update_model_monotone. lia.  
Qed.
  
Lemma check_clause_model_intact {cl modified w m wm'} : 
  check_clause_model cl (modified, (w, m)) = (false, wm') -> valid_clause m cl /\ wm' = (w, m).
Proof.
  unfold check_clause_model.
  move: (@update_value_valid w m cl).
  destruct (update_value (w, m) cl) eqn:upd.
  * intros valid [= -> <-]. split => //.
  * intros valid [= -> <-]. split => //.
  * intros _ [=].
Qed.

Lemma check_clause_model_modify {cl w m wm'} : 
  check_clause_model cl (false, (w, m)) = (true, wm') -> ~~ valid_clause m cl.
Proof.
  unfold check_clause_model.
  destruct (update_value (w, m) cl) eqn:upd.
  * now intros [= <- <-].
  * now intros [= <- <-].
  * intros [= <-].
    move: upd.
    unfold update_value, valid_clause.
    case: Z.ltb_spec => //.
    destruct cl as [prem [l k]] => /=.
    intros hprem.
    case: Nat.leb_spec => // hlt.
Qed.

Lemma check_model_aux_model_le {cls acc acc' b} : 
  check_model_aux cls acc = (b, acc') -> acc.2 ⩽ acc'.2.
Proof.
  unfold check_model_aux.
  revert b acc'.
  eapply ClausesProp.fold_rec.
  - intros s emp b acc'. intros [=]. subst. reflexivity. 
  - intros cl [modified [w' m']] cls' cls'' incl nincls' incls''.
    intros IH b acc'.
    move/check_clause_model_inv.
    specialize (IH _ _ eq_refl). cbn in IH. now intros; transitivity m'.
Qed.

Lemma level_value_update_model m l k : 
  level_value (update_model m l k) l = k.
Proof.
  unfold level_value, update_model.
  cbn -[LevelMap.find LevelMap.add].
  rewrite LevelMapFact.F.add_o.
  destruct LevelMap.E.eq_dec => //.
  exfalso. apply n. now apply MoreLevel.compare_eq.
Qed.


Lemma model_map_outside_weaken {W W'} {m m' : model} : 
  model_map_outside W m m' ->
  W ⊂_lset W' ->
  model_map_outside W' m m'.
Proof.
  intros hm sub x hin k.
  apply hm. intros hin'. apply sub in hin'. now apply hin.
Qed.

Lemma is_model_union {cls cls' m} : 
  is_model cls m -> is_model cls' m -> is_model (Clauses.union cls cls') m.
Proof.
  rewrite /is_model. rewrite /is_true -!ClausesFact.for_all_iff.
  now move=> ism ism' x /Clauses.union_spec [].
Qed.

#[local] Instance Clauses_For_All_proper : Proper (eq ==> Clauses.Equal ==> iff) Clauses.For_all.
Proof.
  intros x y -> cl cl' eqcl.
  unfold Clauses.For_all. now setoid_rewrite eqcl.
Qed.

#[local] Instance Clauses_for_all_proper : Proper (eq ==> Clauses.Equal ==> eq) Clauses.for_all.
Proof.
  intros x y -> cl cl' eqcl.
  apply iff_is_true_eq_bool.
  rewrite /is_true -!ClausesFact.for_all_iff. now rewrite eqcl.
Qed.

#[local] Instance is_model_proper : Proper (Clauses.Equal ==> eq ==> eq) is_model.
Proof.
  intros cl cl' eqcl x y ->. unfold is_model. now rewrite eqcl.
Qed.

Lemma model_le_values {m m' : model} x : m ⩽ m' -> level_value m x <= level_value m' x.
Proof.
  intros lem. specialize (lem x).
  unfold level_value.
  destruct LevelMap.find eqn:hl => //. 2:lia.
  apply LevelMap.find_2 in hl. specialize (lem _ hl) as [k' [mapsto leq]].
  now rewrite (LevelMap.find_1 mapsto).
Qed.

Lemma level_value_MapsTo {k e} {m : model} : 
  LevelMap.MapsTo k e m -> level_value m k = e.
Proof.
  unfold level_value.
  move=> mapto; rewrite (LevelMap.find_1 mapto) //.
Qed.

Infix "⊂_clset" := Clauses.Subset (at level 70).

Lemma max_gain_in cl cls : 
  Clauses.In cl cls ->
  Z.to_nat (gain cl) <= max_gain cls.
Proof.
  intros hin.
  unfold max_gain. revert cl hin.
  eapply ClausesProp.fold_rec.
  - intros s' ise hin. firstorder eauto.
  - intros x a s' s'' xs nxs' hadd IH cl' hin'.
    eapply hadd in hin' as [].
    * subst x. lia.
    * specialize (IH _ H). lia.
Qed.

Definition max_gain_subset (cls cls' : Clauses.t) : 
  cls ⊂_clset cls' ->
  max_gain cls <= max_gain cls'.
Proof.
  unfold max_gain at 1.
  revert cls'.
  eapply ClausesProp.fold_rec.
  - intros s' ise sub. lia.
  - intros x a s' s'' xs nxs' hadd IH cls'' hs.
    specialize (IH cls''). forward IH. transitivity s'' => //. 
    intros ??. now apply hadd.
    assert (incls'' : Clauses.In x cls'').
    { now apply hs, hadd. }
    apply max_gain_in in incls''. lia.
Qed.

Module LevelExprSetDecide := WDecide (LevelExprSet).
Ltac lesets := LevelExprSetDecide.fsetdec.
Infix "⊂_leset" := LevelExprSet.Subset (at level 70).
Notation cls_diff cls W := (Clauses.diff (cls ↓ W) (cls ⇂ W)) (only parsing).
  
(*
  Equations? extend_model {W cls} (m : valid_model W (cls ⇂ W))
    (r : result W (Clauses.diff (cls ↓ W) (cls ⇂ W)))
    : result W (cls ↓ W) :=
    extend_model _ Loop := Loop;
    extend_model m (Model w m' sub) := 
      Model w {| model_model := m'.(model_model) |} _.
  Proof.
    - apply LevelSet.subset_spec in sub. now apply clauses_conclusions_clauses_with_concl in H. 
    - eapply sub. now eapply m.(model_clauses_conclusions).
    - apply m.
    - eapply LevelSet.subset_spec. eapply LevelSet.subset_spec in sub.
      now transitivity V.
  Qed.
  
  *)

Lemma not_mem l s : ~~ LevelSet.mem l s <-> ~ LevelSet.In l s.
Proof.
  split. apply contraNnot. apply LevelSet.mem_spec.
  eapply contra_notN; tea. now move/LevelSet.mem_spec.
Qed.

Lemma v_minus_w_bound_irrel {W} m m' : 
  model_map_outside W m m' ->
  v_minus_w_bound W m = v_minus_w_bound W m'.
Proof.
  unfold v_minus_w_bound.
  intros out. eapply LevelMapFact.fold_Equal. tc. cbn.
  { intros x y eq. cbn. solve_proper. }
  { intros x y. cbn. intros e e' a neq. lia. }
  apply LevelMapFact.F.Equal_mapsto_iff.
  intros k e. rewrite -> LevelMapFact.filter_iff.
  2:{ intros x y eq. eapply MoreLevel.compare_eq in eq. subst y. solve_proper. }
  rewrite -> LevelMapFact.filter_iff.
  2:{ move=> x y /MoreLevel.compare_eq ->. solve_proper. }
  rewrite [_ = true]not_mem. intuition auto.
  - now apply out.
  - now apply out.
Qed.

Definition max_premise_value (m : model) (l : nonEmptyLevelExprSet) : nat :=
  let (hd, tl) := NonEmptySetFacts.to_nonempty_list l in
  fold_left (fun min atom => Nat.max (levelexpr_value m atom) min) tl (levelexpr_value m hd).

Definition non_W_atoms W (l : LevelExprSet.t) := 
  LevelExprSet.filter (fun lk => ~~ LevelSet.mem lk.1 W) l.

Lemma non_W_atoms_spec W l : forall x, LevelExprSet.In x (non_W_atoms W l) <-> LevelExprSet.In x l /\ ~ LevelSet.In x.1 W.
Proof.
  intros x. now rewrite /non_W_atoms LevelExprSet.filter_spec -not_mem.
Qed.
  
Lemma non_W_atoms_subset W l : non_W_atoms W l ⊂_leset l.
Proof. intros x. now rewrite /non_W_atoms LevelExprSet.filter_spec. Qed.

Lemma levelexprset_levels_spec_aux l (e : LevelExprSet.t) acc : 
  LevelSet.In l (LevelExprSet.fold (fun le : LevelExprSet.elt => LevelSet.add (LevelExpr.get_level le)) e acc) <->
  (exists k, LevelExprSet.In (l, k) e) \/ LevelSet.In l acc.
Proof.
  eapply LevelExprSetProp.fold_rec.
  - intros.
    intuition auto. destruct H1 as [k hin]. lesets.
  - intros x a s' s'' hin nin hadd ih.
    rewrite LevelSet.add_spec.
    split.
    * intros [->|].
      left. exists (levelexpr_k x).
      apply hadd. cbn. left. now destruct x.
      apply ih in H.
      intuition auto.
      left. destruct H0 as [k Hk]. exists k. apply hadd. now right.
    * intros [[k ins'']|inacc].
      eapply hadd in ins''. destruct ins''; subst.
      + now left.
      + right. apply ih. now left; exists k.
      + right. intuition auto.
Qed.

Lemma levelexprset_levels_spec l (e : LevelExprSet.t) : 
  LevelSet.In l (LevelExprSet.levels e) <-> exists k, LevelExprSet.In (l, k) e.
Proof.
  rewrite levelexprset_levels_spec_aux. intuition auto. lsets.
Qed.

Lemma levels_exprs_non_W_atoms {W prem} :
  LevelSet.Equal (LevelExprSet.levels (non_W_atoms W prem)) (LevelSet.diff (LevelExprSet.levels prem) W).
Proof.
  intros e. unfold non_W_atoms.
  rewrite levelexprset_levels_spec LevelSet.diff_spec levelexprset_levels_spec.
  firstorder eauto.
  rewrite LevelExprSet.filter_spec in H. now exists x. 
  rewrite LevelExprSet.filter_spec in H. destruct H.
  rewrite LevelSetFact.not_mem_iff.
  destruct LevelSet.mem => //.
  exists x.
  rewrite LevelExprSet.filter_spec. split => //.
  rewrite LevelSetFact.not_mem_iff in H0. now rewrite H0.
Qed.

Lemma levelexprset_empty_levels x : LevelExprSet.Empty x <-> LevelSet.Empty (LevelExprSet.levels x).
Proof.
  split.
  - intros he.
    intros l hin.
    eapply levelexprset_levels_spec in hin as [k hin]. lesets.
  - intros emp l hin. eapply emp. eapply (levelexprset_levels_spec l.1). exists l.2.
    now destruct l.
Qed.

Lemma non_W_atoms_ne W cl cls :
  Clauses.In cl (cls_diff cls W) ->
  LevelExprSet.is_empty (non_W_atoms W (premise cl)) = false.
Proof.
  intros x.
  apply Clauses.diff_spec in x as [clw clr].
  eapply in_clauses_with_concl in clw as [clw incls].
  apply/negbTE.
  apply/(contra_notN _ clr).
  intros he. rewrite in_restrict_clauses. split => //.
  epose proof (@levels_exprs_non_W_atoms W (premise cl)).
  eapply LevelExprSetFact.is_empty_2 in he.
  intros x hin. eapply levelexprset_empty_levels in he. rewrite H in he.
  specialize (he x). rewrite LevelSet.diff_spec in he. intuition auto.
  rewrite -LevelSet.mem_spec in H1 |- *. destruct LevelSet.mem; intuition auto.
Qed.

Section MoreNonEmpty.

  Import LevelExprSet.
  Import NonEmptySetFacts.

  Lemma In_elements {x} {s : nonEmptyLevelExprSet} : In x s <-> List.In x (elements s).
  Proof.
    split. now move/LevelExprSetFact.elements_1/InA_In_eq.
    now move/InA_In_eq/LevelExprSetFact.elements_2.
  Qed.     

  Lemma min_premise_spec_aux (m : model) s k :
    min_premise m s = k ->
    (forall x, LevelExprSet.In x s -> (k <= min_atom_value m x)%Z) /\ 
    (exists x, LevelExprSet.In x s /\ k = min_atom_value m x).
  Proof.
    unfold min_premise.
    move: (to_nonempty_list_spec s).
    destruct (to_nonempty_list s). intros heq.
    setoid_rewrite In_elements. rewrite -heq. clear s heq.
    intros <-.
    induction l.
    - cbn.
      split. intros x [->|] => //. reflexivity.
      now exists t0; split => //.
    - destruct IHl as [ha hex].
      split; intros.
      eapply (in_elt_inv x a [t0]) in H as [<-|inih].
      cbn. rewrite fold_left_comm. lia. lia.
      specialize (ha _ inih).
      cbn. rewrite fold_left_comm. lia. lia.
      destruct hex as [minval [inmin ih]].
      cbn. rewrite fold_left_comm. lia.
      destruct (Z.leb_spec (min_atom_value m a) (min_atom_value m minval)).
      exists a. split; [intuition|]. lia. exists minval.
      cbn in inmin; split; [intuition auto|]. lia.
  Qed.

  Lemma min_premise_spec (m : model) (s : nonEmptyLevelExprSet) :
    (forall x, LevelExprSet.In x s -> (min_premise m s <= min_atom_value m x)%Z) /\ 
    (exists x, LevelExprSet.In x s /\ min_premise m s = min_atom_value m x).
  Proof.
    now apply min_premise_spec_aux.
  Qed.

  Lemma min_premise_subset (m : model) (s s' : nonEmptyLevelExprSet) :
    LevelExprSet.Subset s s' ->
    (min_premise m s' <= min_premise m s)%Z.
  Proof.
    intros sub.
    have [has [mins [ins eqs]]] := min_premise_spec m s.
    have [has' [mins' [ins' eqs']]] := min_premise_spec m s'.
    specialize (sub _ ins). specialize (has' _ sub).
    lia.
  Qed.

  Lemma premise_min_spec_aux s k :
    premise_min s = k ->
    (forall x, LevelExprSet.In x s -> (k <= x)) /\ 
    (exists x, LevelExprSet.In x s /\ k = x).
  Proof.
    unfold premise_min.
    move: (to_nonempty_list_spec s).
    destruct (to_nonempty_list s). intros heq.
    setoid_rewrite In_elements. rewrite -heq. clear s heq.
    intros <-.
    induction l.
    - cbn.
      split. intros x [->|] => //.
      now exists t0; split => //.
    - destruct IHl as [ha hex].
      split; intros.
      eapply (in_elt_inv x a [t0]) in H as [<-|inih].
      cbn. rewrite fold_left_comm. unfold level_expr_elt in *; lia. unfold level_expr_elt in *; lia.
      specialize (ha _ inih).
      cbn. rewrite fold_left_comm. lia. lia.
      destruct hex as [minval [inmin ih]].
      cbn. rewrite fold_left_comm. lia.
      destruct (Nat.leb_spec a minval).
      exists a. split; [intuition|]. rewrite -ih in H. unfold level_expr_elt in *; lia.
      exists minval.
      cbn in inmin; split; [intuition auto|]. lia.
  Qed.

  Lemma premise_min_spec (s : nonEmptyLevelExprSet) :
    (forall x, LevelExprSet.In x s -> premise_min s <= x) /\ 
    (exists x, LevelExprSet.In x s /\ premise_min s = x).
  Proof.
    now apply premise_min_spec_aux.
  Qed.

  Lemma premise_min_subset (s s' : nonEmptyLevelExprSet) :
    LevelExprSet.Subset s s' ->
    premise_min s' <= premise_min s.
  Proof.
    intros sub.
    have [has [mins [ins eqs]]] := premise_min_spec s.
    have [has' [mins' [ins' eqs']]] := premise_min_spec s'.
    specialize (sub _ ins). specialize (has' _ sub).
    lia.
  Qed.

  Lemma max_premise_value_spec_aux (m : model) s k :
    max_premise_value m s = k ->
    (forall x, LevelExprSet.In x s -> levelexpr_value m x <= k) /\ 
    (exists x, LevelExprSet.In x s /\ k = levelexpr_value m x).
  Proof.
    unfold max_premise_value.
    move: (to_nonempty_list_spec s).
    destruct (to_nonempty_list s). intros heq.
    setoid_rewrite In_elements. rewrite -heq. clear s heq.
    intros <-.
    induction l.
    - cbn.
      split. intros x [->|] => //.
      now exists t0; split => //.
    - destruct IHl as [ha hex].
      split; intros.
      eapply (in_elt_inv x a [t0]) in H as [<-|inih].
      cbn. rewrite fold_left_comm. lia. lia.
      specialize (ha _ inih).
      cbn. rewrite fold_left_comm. lia. lia.
      destruct hex as [maxval [inmax ih]].
      cbn. rewrite fold_left_comm. lia.
      destruct (Nat.leb_spec (levelexpr_value m maxval) (levelexpr_value m a)).
      exists a. split; [intuition|]. lia. exists maxval.
      cbn in inmax; split; [intuition auto|]. lia.
  Qed.

  Lemma max_premise_value_spec (m : model) (s : nonEmptyLevelExprSet) :
    (forall x, LevelExprSet.In x s -> levelexpr_value m x <= max_premise_value m s) /\ 
    (exists x, LevelExprSet.In x s /\ max_premise_value m s = levelexpr_value m x).
  Proof.
    now apply max_premise_value_spec_aux.
  Qed.
End MoreNonEmpty.

Lemma min_premise_pos_spec {m prem} : 
  (0 <= min_premise m prem)%Z -> 
  forall x, LevelExprSet.In x prem -> levelexpr_k x <= levelexpr_value m x.
Proof.
  pose proof (min_premise_spec m prem) as [amin [exmin [inminpre eqminpre]]].
  intros hprem x hin.
  specialize (amin _ hin).
  unfold min_atom_value in amin.
  destruct x as [l k]; cbn in *. unfold levelexpr_value; cbn.
  lia.
Qed.

Definition equal_model (m m' : model) := LevelMap.Equal m m'.

#[local] Instance equal_model_equiv : Equivalence equal_model.
Proof. unfold equal_model.
  split; try econstructor; eauto.
  red. intros. now symmetry.
  red; intros. now transitivity y.
Qed.

#[local] Instance level_value_proper : Proper (equal_model ==> eq ==> eq) level_value.
Proof.
  intros x y eqm l ? <-. unfold level_value.
  unfold equal_model in eqm.
  destruct LevelMap.find eqn:hl.
  - eapply LevelMap.find_2 in hl.
    rewrite eqm in hl.
    eapply LevelMap.find_1 in hl. now rewrite hl.
  - eapply LevelMapFact.F.not_find_in_iff in hl.
    rewrite eqm in hl.
    eapply LevelMapFact.F.not_find_in_iff in hl.
    now rewrite hl.
Qed.

Lemma v_minus_w_bound_spec W m : 
  forall x, ~ LevelSet.In x W -> level_value m x <= v_minus_w_bound W m.
Proof.
  intros x him.
  unfold v_minus_w_bound.
  set (fm := LevelMapFact.filter _ _).
  replace (level_value m x) with (level_value fm x).
  2:{ unfold level_value.
      destruct LevelMap.find eqn:hl => //.
      eapply LevelMap.find_2 in hl.
      subst fm. cbn in hl.
      eapply LevelMapFact.filter_iff in hl as [].
      2:{ intros ? ? ?. eapply MoreLevel.compare_eq in H0. subst x0; solve_proper. }
      rewrite (LevelMap.find_1 H) //.
      destruct (LevelMap.find _ m) eqn:hl' => //.
      eapply LevelMap.find_2 in hl'.
      assert (LevelMap.MapsTo x n fm).
      eapply LevelMapFact.filter_iff.
      { intros ? ? ?. eapply MoreLevel.compare_eq in H. subst x0; solve_proper. }
      split => //. now rewrite [_ = true]not_mem.
      now rewrite (LevelMap.find_1 H)  in hl. }
  clearbody fm.
  eapply LevelMapFact.fold_rec.
  - intros m' em. unfold level_value.
    destruct LevelMap.find eqn:hl => //.
    eapply LevelMap.find_2 in hl.
    now apply em in hl.
  - intros k e a m' m'' map nin hadd.
    red in hadd.
    unfold level_value. cbn.
    rewrite hadd LevelMapFact.F.add_o.
    destruct LevelMap.E.eq_dec.
    eapply MoreLevel.compare_eq in e0. subst x. lia.
    destruct LevelMap.find; lia.
Qed.

Lemma clauses_levels_restrict_clauses cls W : 
  LevelSet.Subset (clauses_levels (cls ⇂ W)) W.
Proof.
  intros x [cl []] % clauses_levels_spec.
  eapply in_restrict_clauses in H as [hconc hprem incl].
  eapply clause_levels_spec in H0 as []. apply hprem, H. now subst x.
Qed.

Lemma clauses_conclusions_levels cls : 
  clauses_conclusions cls ⊂_lset clauses_levels cls.
Proof.
  intros x.
  rewrite clauses_conclusions_spec clauses_levels_spec.
  setoid_rewrite clause_levels_spec.
  firstorder auto.
Qed.

Record model_extension W m m' := 
  { model_ext_le : m ⩽ m';
    model_ext_same_domain : model_same_domain m m';
    model_ext_same_outside : model_map_outside W m m' }.

#[local] Instance model_ext_reflexive W : Reflexive (model_extension W).
Proof. 
  intros m; split; reflexivity.
Qed.

#[local] Instance model_ext_transitive W : Transitive (model_extension W).
Proof. 
  intros m m' m'' h h'; split; (etransitivity; [apply h|apply h']).
Qed.

Lemma model_extension_weaken W W' m m' :
  W ⊂_lset W' ->
  model_extension W m m' ->
  model_extension W' m m'.
Proof.
  intros leW []; split => //.
  eapply model_map_outside_weaken; tea.
Qed.

Lemma model_ext_trans_weaken W W' m m' m'' : 
  W ⊂_lset W' ->
  model_extension W m m' ->
  model_extension W' m' m'' ->
  model_extension W' m m''.
Proof.
  intros leW mext mext'. eapply model_extension_weaken in mext; tea.
  now etransitivity; tea.
Qed.

Definition check_model_invariants cls w m w' m' (modified : bool) :=
  if modified then
    [/\ w ⊂_lset w',
        w' ⊂_lset (LevelSet.union w (clauses_conclusions cls)),
        exists cl, 
          let cll := (levelexpr_level (concl cl)) in
          [/\ Clauses.In cl cls, ~~ valid_clause m cl,
          LevelSet.In cll w' &
          level_value m cll < level_value m' cll] &
        model_extension w' m m']
  else (w, m) = (w', m').

#[local] Instance clauses_conclusions_proper : Proper (Clauses.Equal ==> LevelSet.Equal) clauses_conclusions.
Proof.
  intros cls cls' eq x.
  rewrite !clauses_conclusions_spec. now setoid_rewrite eq.
Qed.

#[local] Instance And3P_proper : Proper (iff ==> iff ==> iff ==> iff) ssrbool.and3.
Proof.
  repeat intro. split; intros []; split; intuition auto.
Qed.

#[local] Instance And4P_proper : Proper (iff ==> iff ==> iff ==> iff ==> iff) ssrbool.and4.
Proof.
  repeat intro. split; intros []; split; intuition auto.
Qed.

#[local] Instance check_model_invariants_proper : 
  Proper (Clauses.Equal ==> eq ==> eq ==> eq ==> eq ==> eq ==> iff) check_model_invariants.
Proof.
  intros cls cls' eqcls. 
  repeat intro; subst.
  unfold check_model_invariants.
  destruct y3 => //.
  now setoid_rewrite <-eqcls.
Qed.

Lemma min_atom_value_levelexpr_value m l : Z.to_nat (min_atom_value m l) <= levelexpr_value m l - l.
Proof.
  destruct l as [l k]; cbn. unfold levelexpr_value. cbn. lia.
Qed.

Lemma clauses_conclusions_add cl cls : 
  clauses_conclusions (Clauses.add cl cls) =_lset 
  (LevelSet.singleton (LevelExpr.get_level (concl cl)) ∪ 
    clauses_conclusions cls).
Proof.
  intros x.
  rewrite LevelSet.union_spec !clauses_conclusions_spec.
  setoid_rewrite Clauses.add_spec; setoid_rewrite LevelSet.singleton_spec.
  firstorder eauto. subst. now left.
Qed.

Definition declared_model_level (m : model) l := LevelMap.In l m.

Definition clause_conclusion cl := levelexpr_level (concl cl).

Definition update_model_same_domain {m l k} :
  declared_model_level m l ->
  model_same_domain m (update_model m l k).
Proof.
  unfold update_model, declared_model_level.
  intros hin x.
  rewrite LevelMapFact.F.add_in_iff.
  rewrite MoreLevel.compare_eq. intuition auto. now subst.
Qed.

Definition update_model_outside {m w l k} :
  model_map_outside (LevelSet.add l w) m (update_model m l k).
Proof.
  unfold update_model, model_map_outside.
  intros l'. rewrite LevelSet.add_spec.
  intros hin k'.
  rewrite LevelMapFact.F.add_neq_mapsto_iff //.
  intros heq. rewrite MoreLevel.compare_eq in heq. subst l'. apply hin. now left.
Qed.

Lemma check_clause_model_modify' {cl cls w m w' m' w'' m'' modified modified'} : 
  check_model_invariants cls w m w' m' modified ->
  declared_model_level m (clause_conclusion cl) ->
  check_clause_model cl (modified, (w', m')) = (modified', (w'', m'')) -> 
  check_model_invariants (Clauses.add cl cls) w m w'' m'' modified'.
Proof.
  intros inv declcl.
  unfold check_clause_model.
  destruct (update_value (w', m') cl) eqn:upd.
  * intros [= <- <-]. subst.
    destruct modified. 2:{ noconf inv. reflexivity. }
    destruct inv.
    split => //. 
    + rewrite clauses_conclusions_add; lsets.
    + destruct H1 as [cl' []].
      exists cl'; split => //. now rewrite Clauses.add_spec.
  * intros [= <- <-]. subst.
    destruct modified. 2:{ noconf inv. reflexivity. }
    destruct inv.
    split => //. 
    + rewrite clauses_conclusions_add; lsets.
    + destruct H1 as [cl' []].
      exists cl'; split => //. now rewrite Clauses.add_spec.
  * intros [= <- ->].
    move: upd.
    unfold update_value.
    case: Z.ltb_spec => //.
    destruct cl as [prem [l k]] => /=.
    intros hprem.
    case: Nat.leb_spec => // hlt.
    intros [= <- <-].
    destruct modified; noconf inv.
    { destruct inv.
      split => //.
      + lsets.
      + rewrite clauses_conclusions_add. 
        intros x. rewrite LevelSet.add_spec !LevelSet.union_spec LevelSet.singleton_spec.
        intuition eauto. cbn. apply H0 in H4. lsets.
      + setoid_rewrite Clauses.add_spec; setoid_rewrite LevelSet.add_spec.
        destruct H1 as [cl []]; exists cl; split => //. eauto. eauto.
        eapply Nat.lt_le_trans; tea.
        eapply model_le_values.
        now eapply update_model_monotone.
      + transitivity m'.
        { eapply model_extension_weaken; tea. lsets. }
        split.
        { now eapply update_model_monotone. }
        { eapply update_model_same_domain.
          eapply H2, declcl. }
        { eapply update_model_outside. } }
    { split => //.
      + lsets.
      + rewrite clauses_conclusions_add. 
        intros x. rewrite LevelSet.add_spec !LevelSet.union_spec LevelSet.singleton_spec.
        intuition eauto.
      + setoid_rewrite Clauses.add_spec; setoid_rewrite LevelSet.add_spec.
        exists (prem, (l, k)).
        split; tea; eauto.
        - unfold valid_clause. cbn.
          case: Z.ltb_spec => //. cbn. lia. intros _.
          rewrite -Nat.ltb_antisym. apply Nat.ltb_lt; lia.
        - cbn. now rewrite level_value_update_model.
      + split.
        { now eapply update_model_monotone. }
        { eapply update_model_same_domain.
          eapply declcl. }
        { eapply update_model_outside. } }
Qed.

Definition model_of V (m : model) := 
  forall k, LevelSet.In k V -> LevelMap.In k m.

Lemma model_of_subset V V' m : 
  model_of V m -> V' ⊂_lset V -> model_of V' m.
Proof.
  rewrite /model_of. intros ih hv k. specialize (ih k).
  now move/hv.
Qed.

Lemma clauses_conclusions_subset {cls cls'} : 
  Clauses.Subset cls cls' ->
  clauses_conclusions cls ⊂_lset clauses_conclusions cls'.
Proof.
  intros hsub x. rewrite !clauses_conclusions_spec.
  intuition eauto. destruct H as [cl []]; exists cl; split; try clsets; auto.
Qed.

Lemma check_model_aux_spec {cls w m w' m' modified} : 
  model_of (clauses_conclusions cls) m ->
  check_model_aux cls (w, m) = (modified, (w', m')) ->
  check_model_invariants cls w m w' m' modified.
Proof.
  rewrite /check_model_aux /is_model.
  revert modified w' m'.
  eapply ClausesProp.fold_rec.
  - intros s' e modified w' m' mof [= <- <- <-].
    split.
  - intros x ? s' s'' inx nins' hadd ih modified w' m' mof.
    destruct a as [modified'' [w'' m'']].
    assert (ms' : model_of (clauses_conclusions s') m).
    { eapply model_of_subset; tea.
      eapply clauses_conclusions_subset. red in hadd. intros ?. 
      specialize (hadd a). intuition auto. }
    specialize (ih _ _ _ ms' eq_refl).
    apply ClausesProp.Add_Equal in hadd. rewrite hadd.
    eapply check_clause_model_modify' => //.
    red. apply mof.
    apply clauses_conclusions_spec. exists x; split => //.
    apply hadd. clsets.
Qed.

Lemma check_model_spec {cls w m w' m'} : 
  model_of (clauses_conclusions cls) m ->
  check_model cls (w, m) = Some (w', m') ->
  check_model_invariants cls w m w' m' true.
Proof.
  intros mof.
  unfold check_model.
  destruct check_model_aux eqn:cm.
  destruct p as [].
  eapply check_model_aux_spec in cm => //.
  destruct b => //. now intros [= <- <-].
Qed.

Lemma check_model_aux_not_model {cls w m w' m'} : 
  model_of (clauses_conclusions cls) m ->
  check_model_aux cls (w, m) = (true, (w', m')) ->
  ~~ is_model cls m.
Proof.
  intros mof. 
  move/(check_model_aux_spec mof) => [] _ _ [cl [incl inval]] _ _ _.
  unfold is_model.
  apply clauses_for_all_neg.
  intros hf. specialize (hf cl incl). cbn in hf.
  rewrite /is_true hf in inval => //.
Qed.

Lemma check_model_is_model {W cls m} :
  model_of (clauses_conclusions cls) m ->
  check_model cls (W, m) = None <-> is_model cls m.
Proof.
  intros mof; unfold check_model, is_model.
  destruct check_model_aux eqn:caux.
  destruct b => //. intuition auto. congruence.
  { destruct p; eapply check_model_aux_not_model in caux => //. 
    rewrite /is_model /= // in caux. now rewrite H in caux. }
  intuition auto.
  pose proof (check_model_aux_false caux). subst p.
  now rewrite check_model_aux_model in caux.
Qed.

Lemma check_model_update {W cls m wm'} : 
  model_of (clauses_conclusions cls) m ->
  check_model cls (W, m) = Some wm' -> ~~ is_model cls m /\ m ⩽ wm'.2.
Proof.
  intros mof; unfold check_model, is_model.
  destruct check_model_aux eqn:caux.
  destruct b => //. intros [= <-]. intuition auto.
  destruct p. 
  now eapply check_model_aux_not_model in caux.
  now eapply check_model_aux_model_le in caux.
Qed.

Definition measure_w W cls m w :=
    let bound := v_minus_w_bound W m in
    let maxgain := max_gain (cls_diff cls W) in
    (Z.of_nat bound + Z.of_nat maxgain - Z.of_nat (level_value m w))%Z.
  
Lemma invalid_clause_measure W cls cl m : 
  ~~ valid_clause m cl ->
  Clauses.In cl (cls_diff cls W) ->
  (0 < measure_w W cls m (concl cl))%Z.
Proof.
  unfold valid_clause.
  case: Z.ltb_spec => // hprem.
  destruct cl as [prem [l k]]; cbn.
  case: Nat.leb_spec => // hlt. intros _ hin.
  have hne := (non_W_atoms_ne _ _ _ hin).
  cbn. unfold measure_w. unfold gain.
  set (clsdiff := Clauses.diff _ _).
  set (bound := v_minus_w_bound W m).
  enough (Z.of_nat (level_value m l) < Z.of_nat bound + Z.of_nat (max_gain clsdiff))%Z. lia.
  set (prem' := non_W_atoms W prem).
  set (preml := {| t_set := prem'; t_ne := hne |}).
  assert (Z.to_nat (gain (preml, (l, k))) <= max_gain clsdiff).
  { transitivity (Z.to_nat (gain (prem, (l, k)))). 2:now apply max_gain_in.
    unfold gain. cbn.
    pose proof (premise_min_subset preml prem).
    rewrite !Z2Nat.inj_sub //; try lia. rewrite !Nat2Z.id.
    forward H. eapply non_W_atoms_subset. lia. }
  eapply Z.lt_le_trans with (Z.of_nat bound + Z.of_nat (Z.to_nat (gain (preml, (l, k)))))%Z; try lia.
  rewrite -Nat2Z.inj_add.
  unfold gain; cbn.
  enough (level_value m l < v_minus_w_bound W m + (k - premise_min preml)). lia.
  enough (k + Z.to_nat (min_premise m prem) <= v_minus_w_bound W m + (k - premise_min preml)). lia.
  assert (min_premise m prem <= min_premise m preml)%Z.
  { eapply min_premise_subset. eapply non_W_atoms_subset. }        
  transitivity (k + Z.to_nat (min_premise m preml)). lia.
  pose proof (min_premise_spec m preml) as [amin [exmin [inminpre eqminpre]]].
  pose proof (max_premise_value_spec m preml) as [amax [exmax [inmaxpre eqmaxpre]]].
  pose proof (premise_min_spec preml) as [apmin [expmin [inpminpre eqpminpre]]].
  assert (premise_min prem <= premise_min preml).
  { eapply premise_min_subset. eapply non_W_atoms_subset. }
  transitivity (v_minus_w_bound W m + (k - premise_min preml)). 2:lia.
  assert (Z.to_nat (min_premise m preml) <= max_premise_value m preml - premise_min preml).
  { rewrite eqpminpre eqmaxpre eqminpre.
    pose proof (min_atom_value_levelexpr_value m exmin). etransitivity; tea.
    specialize (amax _ inminpre). rewrite eqmaxpre in amax.
    assert (expmin <= exmin). specialize (apmin _ inminpre). lia.
    unfold level_expr_elt in *. lia. }
  transitivity (k + (max_premise_value m preml - premise_min preml)). lia.
  assert (premise_min preml <= max_premise_value m preml).
  { rewrite eqmaxpre.
    move/min_premise_pos_spec: hprem => hprem.
    transitivity exmax. apply apmin => //. eapply hprem.
    now apply (non_W_atoms_subset W prem). }
  assert (k + (max_premise_value m preml - premise_min preml) =
    (max_premise_value m preml + k - premise_min preml)) as ->. lia.
  enough (max_premise_value m preml <= v_minus_w_bound W m). lia.
  { rewrite eqmaxpre.
    apply v_minus_w_bound_spec.
    intros hin'. 
    have [hlevels _] := (@levels_exprs_non_W_atoms W prem (levelexpr_level exmax)).
    rewrite levelexprset_levels_spec in hlevels.
    forward hlevels.
    exists exmax.2. now destruct exmax.
    rewrite LevelSet.diff_spec in hlevels.
    now destruct hlevels. }
Qed.


Record valid_model (V : LevelSet.t) (m : model) (cls : clauses) :=
  { model_model : model;
    model_of_V :> model_of V model_model;
    model_clauses_conclusions : clauses_conclusions cls ⊂_lset V;
    model_ok :> is_model cls model_model;
    model_extends : model_extension V m model_model;
 }.
Arguments model_model {V m cls}.
Arguments model_of_V {V m cls}.
Arguments model_clauses_conclusions {V m cls}.
Arguments model_ok {V m cls}.
Arguments model_extends {V m cls}.

Inductive result (V U : LevelSet.t) (cls : clauses) (m : model) :=
  | Loop
  | Model (w : LevelSet.t) (m : valid_model V m cls) (prf : U ⊂_lset w /\ w ⊂_lset V).
Arguments Loop {V U cls m}.
Arguments Model {V U cls m}.
Arguments lexprod {A B}.

Definition option_of_result {V U m cls} (r : result V U m cls) : option model :=
  match r with
  | Loop => None
  | Model w m sub => Some m.(model_model)
  end. 

Definition extends_model {W U cls m m'} : 
  m' ⩽ m ->
  model_same_domain m' m ->
  model_map_outside W m' m ->
  result W U cls m -> result W U cls m'.
Proof.
  intros leq ldom lout []. exact Loop.
  econstructor 2; tea.
  destruct m0. econstructor; tea.
  - now transitivity m.
Qed.

(* #[tactic="idtac"]
Equations? result_inclusion {V U m cls V'} (r : result V U cls m)
  (prf : LevelSet.Subset V V') : result V' U cls m :=
  result_inclusion Loop _ := Loop;
  result_inclusion (Model w m' sub) sub' := 
    Model w {| model_model := m'.(model_model) |} _.
Proof.
  -
  - transitivity V => //. now eapply m'.(model_clauses_conclusions).
  - apply m'.
  - apply m'.
  - apply m'.
  - intros x hin. apply m'. intros hv.
    apply sub' in hv. now apply hin.
  - intuition lsets.
Qed. *)

Notation "#| V |" := (LevelSet.cardinal V).

Notation loop_measure V W := (#|V|, #|V| - #|W|).

Definition lexprod_rel := lexprod lt lt.

#[local] Instance lexprod_rel_wf : WellFounded lexprod_rel.
Proof.
  eapply (Acc_intro_generator 1000). unfold lexprod_rel. eapply wf_lexprod, lt_wf. eapply lt_wf.
Defined.

Section InnerLoop.
  Context (V : LevelSet.t) (U : LevelSet.t)
    (loop : forall (V' U' : LevelSet.t) (cls : clauses) (m : model)
    (prf : [/\ clauses_conclusions cls ⊂_lset V', U' ⊂_lset V' & model_of V' m]),
    lexprod_rel (loop_measure V' U') (loop_measure V U) -> result V' U' cls m). 
  
  Definition sum_W W (f : LevelSet.elt -> nat) := 
    LevelSet.fold (fun w acc => acc + f w) W 0.
  
  Definition measure (W : LevelSet.t) (cls : clauses) (m : model) : nat := 
    sum_W W (fun w => Z.to_nat (measure_w W cls m w)).

  Lemma measure_model W cls m :
    let clsdiff := cls_diff cls W in
    measure W cls m = 0 -> is_model clsdiff m.
  Proof using.
    clear loop V U.  
    unfold measure, sum_W, measure_w, is_model.
    set (clsdiff := Clauses.diff _ _).
    intros hm.
    assert (LevelSet.For_all (fun w => v_minus_w_bound W m + max_gain clsdiff <= level_value m w) W).
    { move: hm.
      generalize (v_minus_w_bound W m) => vbound.
      eapply LevelSetProp.fold_rec.
      intros. intros x hin. firstorder eauto.
      intros x a s' s'' inw nins' hadd ih heq.
      forward ih by lia.
      intros l hin.
      apply hadd in hin as [].
      * subst x. lia.
      * now apply ih. }
    clear hm.
    eapply ClausesFact.for_all_iff. tc.
    intros cl hl.
    unfold valid_clause.
    case: Z.ltb_spec => // hk0.
    destruct cl as [prem [l k]] => /=.
    eapply Nat.leb_le. cbn in hk0.
    rewrite /clsdiff in hl.
    destruct (proj1 (Clauses.diff_spec _ _ _) hl) as [hlcls hl'].
    eapply in_clauses_with_concl in hlcls as [lW incls].
    specialize (H _ lW). cbn -[clsdiff] in H. cbn in lW.
    etransitivity; tea.
    set (prem' := non_W_atoms W prem).
    assert (ne : LevelExprSet.is_empty prem' = false).
    { now eapply (non_W_atoms_ne W (prem, (l, k)) cls). } 
    set (preml := {| t_set := prem'; t_ne := ne |}).
    assert (min_premise m prem <= min_premise m preml)%Z.
    { eapply min_premise_subset. eapply non_W_atoms_subset. }        
    (* min_i (f(x_i)-k_i) <= max_i(f(x_i)) - min(k_i) *)
    pose proof (min_premise_spec m preml) as [amin [exmin [inminpre eqminpre]]].
    pose proof (max_premise_value_spec m preml) as [amax [exmax [inmaxpre eqmaxpre]]].
    pose proof (premise_min_spec preml) as [apmin [expmin [inpminpre eqpminpre]]].
    assert (Z.to_nat (min_premise m preml) <= 
      (max_premise_value m preml) - premise_min preml).
    { rewrite eqpminpre eqmaxpre eqminpre.
      pose proof (min_atom_value_levelexpr_value m exmin). etransitivity; tea.
      specialize (amax _ inminpre). rewrite eqmaxpre in amax.
      assert (expmin <= exmin). specialize (apmin _ inminpre). lia.
      unfold level_expr_elt in *. lia. }
    transitivity (k + (max_premise_value m preml - premise_min preml)). lia.
    assert (Z.to_nat (gain (preml, (l, k))) <= max_gain clsdiff).
    { transitivity (Z.to_nat (gain (prem, (l, k)))). 2:now apply max_gain_in.
      unfold gain. cbn.
      pose proof (premise_min_subset preml prem).
      rewrite !Z2Nat.inj_sub //; try lia. rewrite !Nat2Z.id.
      forward H2. eapply non_W_atoms_subset. lia. }
    transitivity (v_minus_w_bound W m + Z.to_nat (gain (preml, (l, k)))).
    2:lia.
    unfold gain. cbn -[max_premise_value premise_min].
    assert (premise_min preml <= max_premise_value m preml).
    { rewrite eqmaxpre.
      move/min_premise_pos_spec: hk0 => hprem.
      transitivity exmax. apply apmin => //. eapply hprem.
      now apply (non_W_atoms_subset W prem). }
    assert (k + (max_premise_value m preml - premise_min preml) =
      (max_premise_value m preml + k - premise_min preml)) as ->. lia.
    rewrite Z2Nat.inj_sub. lia.
    rewrite !Nat2Z.id.
    assert (max_premise_value m preml <= v_minus_w_bound W m).
    { rewrite eqmaxpre.
      apply v_minus_w_bound_spec.
      intros hin. 
      have [hlevels _] := (@levels_exprs_non_W_atoms W prem (levelexpr_level exmax)).
      rewrite levelexprset_levels_spec in hlevels.
      forward hlevels.
      exists exmax.2. now destruct exmax.
      rewrite LevelSet.diff_spec in hlevels.
      now destruct hlevels. }
    lia.
  Qed.
  
  Lemma measure_lt {W cls m m'} : 
    model_map_outside W m m' ->
    m ⩽ m' ->
    (exists l, [/\ LevelSet.In l W, (0 < measure_w W cls m l)%Z & level_value m l < level_value m' l]) ->
    (measure W cls m' < measure W cls m).
  Proof.
    intros hout hle.
    unfold measure, measure_w, sum_W.
    rewrite (v_minus_w_bound_irrel _ _ hout).
    intros hlt.
    rewrite !LevelSet.fold_spec.
    eapply fold_left_ne_lt.
    - intros; lia.
    - intros; lia.
    - destruct hlt as [l [hin _]]. intros he. rewrite -LevelSetProp.elements_Empty in he. lsets.
    - intros. rewrite LevelSet_In_elements in H.
      have lexx' := (model_le_values x hle).
      lia.
    - intros. rewrite LevelSet_In_elements in H.
      have lexx' := (model_le_values x hle).
      lia.
    - destruct hlt as [l [hinl hbound hlev]]. 
      exists l. rewrite LevelSet_In_elements. split => //.
      intros acc acc' accle. 
      eapply Nat.add_le_lt_mono => //. lia.
  Qed. 

  Lemma is_model_equal {cls cls' m} : Clauses.Equal cls cls' -> is_model cls m -> is_model cls' m.
  Proof. now intros ->. Qed.

  Lemma union_diff_eq {cls cls'} : Clauses.Equal (Clauses.union cls (Clauses.diff cls' cls)) 
    (Clauses.union cls cls').
  Proof. clsets. Qed.

  Lemma union_restrict_with_concl {cls W} : 
    Clauses.Equal (Clauses.union (cls ⇂ W) (cls ↓ W)) (cls ↓ W).
  Proof.
    intros cl. rewrite Clauses.union_spec.
    intuition auto. 
    eapply in_clauses_with_concl.
    now eapply in_restrict_clauses in H0 as [].
  Qed.

  Lemma maps_to_level_value x (m m' : model) : 
    (forall k, LevelMap.MapsTo x k m <-> LevelMap.MapsTo x k m') ->
    level_value m x = level_value m' x.
  Proof.
    intros heq.
    unfold level_value.
    destruct LevelMap.find eqn:hl.
    apply LevelMap.find_2 in hl. rewrite heq in hl.
    rewrite (LevelMap.find_1 hl) //.
    destruct (LevelMap.find x m') eqn:hl' => //.
    apply LevelMap.find_2 in hl'. rewrite -heq in hl'.
    now rewrite (LevelMap.find_1 hl') in hl. 
  Qed.

  Lemma measure_Z_lt x y : 
    (x < y)%Z ->
    (0 < y)%Z ->
    Z.to_nat x < Z.to_nat y.
  Proof. intros. lia. Qed.

  Lemma sum_pos W f : 
    (0 < sum_W W f) -> 
    exists w, LevelSet.In w W /\ (0 < f w).
  Proof.
    unfold sum_W.
    eapply LevelSetProp.fold_rec => //.
    intros. lia.
    intros.
    destruct (Nat.ltb_spec 0 a). 
    - destruct (H2 H4) as [w [hin hlt]]. exists w. split => //. apply H1. now right.
    - exists x. split => //. apply H1. now left. lia.
  Qed.

  Lemma measure_pos {W cls m} : 
    (0 < measure W cls m) -> 
    exists l, LevelSet.In l W /\ (0 < measure_w W cls m l)%Z.
  Proof.
    unfold measure.
    move/sum_pos => [w [hin hlt]].
    exists w. split => //. lia.
  Qed.

  Lemma model_of_diff cls W m : 
    model_of W m -> model_of (clauses_conclusions (cls_diff cls W)) m.
  Proof.
    intros; eapply model_of_subset; tea.
    eapply clauses_conclusions_diff_left.
  Qed.
  Hint Resolve model_of_diff : core.

  Lemma check_model_spec_diff {cls w m w' m'} :
    model_of w m ->
    let cls := (cls_diff cls w) in
    check_model cls (w, m) = Some (w', m') ->
    [/\ w =_lset w',
      exists cl : clause,
        let cll := levelexpr_level (concl cl) in
        [/\ Clauses.In cl cls, ~~ valid_clause m cl, LevelSet.In cll w'
          & level_value m cll < level_value m' cll]
      & model_extension w' m m'].
  Proof.
    cbn; intros mof cm. 
    pose proof (clauses_conclusions_diff_left cls w (cls ⇂ w)).
    apply check_model_spec in cm as [].
    split => //. lsets.
    eapply model_of_subset; tea.
  Qed.

  Lemma model_of_ext {W W' m m'} : 
    model_of W m -> model_extension W' m m' -> model_of W m'.
  Proof.
    intros mof [_ dom _].
    intros k hin. apply dom. now apply mof.
  Qed.

  #[tactic="idtac"]
  Equations? inner_loop (W : LevelSet.t) (cls : clauses) (init : model) 
    (m : valid_model W init (cls ⇂ W))
    (prf : [/\ strict_subset W V, ~ LevelSet.Empty W & U ⊂_lset W]) : 
    result W U (cls ↓ W) m.(model_model)
    by wf (measure W cls m.(model_model)) lt :=
    inner_loop W cls init m subWV with 
      inspect (check_model (Clauses.diff (cls ↓ W) (cls ⇂ W)) (W, m.(model_model))) := { 
        | exist None eqm => Model W {| model_model := m.(model_model) |} _
        | exist (Some (Wconcl, mconcl)) eqm with loop W W (cls ⇂ W) mconcl _ _ := {
          (* Here Wconcl = W by invariant *)
          | Loop => Loop
          | Model Wr mr hsub with inner_loop W cls mconcl mr _ := {
          (* Here Wr = W by invariant *)
            | Loop => Loop
            | Model Wr' mr' hsub' => Model Wr' {| model_model := model_model mr' |} hsub' }
            (* Here Wr' = W by invariant *)
      (* We check if the new model [mr] for (cls ⇂ W) extends to a model of (cls ↓ W). *)
      (* We're entitled to recursively compute a better model starting with mconcl, 
        as we have made the measure decrease: 
        some atom in W has been strictly updated in Wconcl. *)
          } }.
  Proof.
    all:cbn [model_model]; clear loop inner_loop.
    all:try solve [try apply LevelSet.subset_spec; try reflexivity].
    all:try apply LevelSet.subset_spec in hsub.
    all:auto.
    all:try destruct subWV as [WV neW UW].
    all:try solve [intuition auto].
    - split => //. apply clauses_conclusions_restrict_clauses.
      eapply check_model_spec_diff in eqm as [].
      eapply model_of_ext; tea. apply m. apply m.
    - left. now eapply strict_subset_cardinal.
    - eapply (check_model_spec_diff m) in eqm as [eqw hm hext] => //.
      pose proof (clauses_conclusions_diff_left cls W (cls ⇂ W)).
      destruct hm as [cll [hind nvalid inwconcl hl]].
      eapply measure_lt.
      { transitivity mconcl.
        eapply model_map_outside_weaken. eapply hext. lsets.
        apply mr. }
      { transitivity mconcl => //. apply hext. apply mr. }
      eapply invalid_clause_measure in nvalid; tea.
      exists (levelexpr_level (concl cll)).
      split => //.
      eapply clauses_conclusions_diff_left; tea.
      eapply clauses_conclusions_spec. exists cll; split => //. exact hind.
      eapply Nat.lt_le_trans; tea.
      eapply model_le_values. eapply mr.      
    - apply mr'.
    - apply clauses_conclusions_clauses_with_concl.
    - apply mr'.
    - eapply (check_model_spec_diff m) in eqm as [eqw hm hext] => //.
      eapply model_ext_trans_weaken. 2:tea. lsets.
      transitivity (model_model mr). apply mr. apply mr'.
    - apply m.
    - eapply clauses_conclusions_clauses_with_concl.
    - rewrite check_model_is_model in eqm.
      2:{ eapply model_of_diff, m. }
      have okm := (model_ok m).
      have mu := is_model_union okm eqm. rewrite union_diff_eq in mu.
      now rewrite union_restrict_with_concl in mu.
    - split => //.
  Qed.

End InnerLoop.

Lemma diff_cardinal_inter V W : #|LevelSet.diff V W| = #|V| - #|LevelSet.inter V W|.
Proof.
  pose proof (LevelSetProp.diff_inter_cardinal V W). lia.
Qed.

Lemma diff_cardinal V W : W ⊂_lset V -> #|LevelSet.diff V W| = #|V| - #|W|.
Proof.
  intros hsub.
  rewrite diff_cardinal_inter LevelSetProp.inter_sym LevelSetProp.inter_subset_equal //.
Qed.

Lemma is_modelP m cls : reflect (Clauses.For_all (valid_clause m) cls) (is_model cls m).
Proof.
  case E: is_model; constructor.
  - now move: E; rewrite /is_model -ClausesFact.for_all_iff.
  - intros hf. apply ClausesFact.for_all_iff in hf; tc. unfold is_model in E; congruence.  
Qed.

Lemma is_model_invalid_clause cl cls m : is_model cls m -> ~~ valid_clause m cl -> ~ Clauses.In cl cls.
Proof.
  move/is_modelP => ism /negP valid hin.
  now specialize (ism _ hin).
Qed.

Lemma strict_subset_leq_right U V W :
  strict_subset U V -> V ⊂_lset W -> strict_subset U W.
Proof.
  intros [] le. split. lsets. intros eq. rewrite -eq in le.
  apply H0. lsets.
Qed.

Lemma strict_subset_diff_incl V W W' :
  strict_subset W' W ->
  W ⊂_lset V ->
  W' ⊂_lset V ->
  strict_subset (LevelSet.diff V W) (LevelSet.diff V W').
Proof.
  intros [] lew lew'.
  split. lsets.
  intros eq.
  apply H0. lsets.
Qed.

(* To help equations *)
Opaque lexprod_rel_wf.

Lemma check_model_spec_V {V cls w m w' m'} :
  model_of V m -> clauses_conclusions cls ⊂_lset V ->
  check_model cls (w, m) = Some (w', m') ->
  check_model_invariants cls w m w' m' true.
Proof.
  cbn; intros mof incl cm. 
  apply check_model_spec in cm => //.
  eapply model_of_subset; tea.
Qed.

Lemma valid_model_of {V W m cls} (m' : valid_model W m cls) : 
  model_of V m -> model_of V (model_model m').
Proof.
  intros mof. eapply model_of_ext; tea. eapply m'.
Qed.

#[tactic="idtac"]
Equations? loop (V : LevelSet.t) (U : LevelSet.t) (cls : clauses) (m : model)
  (prf : [/\ clauses_conclusions cls ⊂_lset V, U ⊂_lset V & model_of V m]) : result V U cls m
  by wf (loop_measure V U) lexprod_rel :=
  loop V U cls m prf with inspect (check_model cls (U, m)) :=
    | exist None eqm => Model U {| model_model := m |} _
    | exist (Some (W, m')) eqm with inspect (LevelSet.equal W V) := {
      | exist true eq := Loop
      (* Loop on cls|W, with |W| < |V| *)
      | exist false neq with loop W W (cls ⇂ W) m' _ := {
        | Loop := Loop
        | Model Wr mwr hsub
          (* We have a model for (cls ⇂ W), we try to extend it to a model of (csl ↓ W).
             By invariant Wr = W *)
          with inner_loop V U loop W cls _ mwr _ := 
          { | Loop := Loop
            | Model Wc mwc hsub'
            (* We get a model for (cls ↓ W), we check if it extends to all clauses.
               By invariant |Wc| cannot be larger than |W|.
            *)
            with inspect (check_model cls (Wc, mwc.(model_model))) :=
            { | exist None eqm' => Model Wc {| model_model := mwc.(model_model) |} _
              | exist (Some (Wcls, mcls)) eqm' with inspect (LevelSet.equal Wcls V) := {
                | exist true _ := Loop
                | exist false neq' with loop V Wcls cls mcls _ := {
                  (* Here Wcls < V, we've found a model for all of the clauses with conclusion
                    in W, which can now be fixed. We concentrate on the clauses whose
                    conclusion is different. Clearly |W| < |V|, but |Wcls| is not 
                    necessarily < |V| *)
                    | Loop := Loop
                    | Model Wvw mcls' hsub'' := Model Wvw {| model_model := model_model mcls' |} _ } } }
          }
      }
    }.
Proof.
  all:clear loop.
  all:try solve [intuition auto].
  all:try eapply levelset_neq in neq.
  all:have cls_sub := clauses_conclusions_levels cls.
  all:destruct prf as [clsV UV mof].
  - split. apply clauses_conclusions_restrict_clauses. reflexivity.
    apply (check_model_spec_V mof clsV) in eqm as [UW WU _ ext].
    eapply model_of_ext; tea. 
    eapply model_of_subset; tea. lsets.
  - apply (check_model_spec_V mof clsV) in eqm as [UW WU _ ext] => //.
    left. 
    eapply strict_subset_cardinal. split => //. lsets.
  - apply (check_model_spec_V mof clsV) in eqm as [UW WU hcl ext] => //.
    split => //. split => //. lsets. 
    destruct hcl as [l [hl _]]. intros he. lsets.
  - eapply (check_model_spec_V mof clsV) in eqm as [UW WU hcl ext].
    eapply check_model_spec in eqm' as [].
    2:{ eapply model_of_subset. 2:exact clsV.
        exact (valid_model_of mwc (valid_model_of mwr (model_of_ext mof ext))). }
    split. lsets. lsets.
    exact (model_of_ext (valid_model_of mwc (valid_model_of mwr (model_of_ext mof ext))) H2).
  - right.
    eapply (check_model_spec_V mof clsV) in eqm as [UW WU hcl ext].
    eapply check_model_spec in eqm' as [].
    2:{ eapply model_of_subset. 2:exact clsV.
        exact (valid_model_of mwc (valid_model_of mwr (model_of_ext mof ext))). }
    destruct hsub' as [UWc WcW].
    assert (Wcls ⊂_lset V). lsets.
    rewrite -!diff_cardinal //.
    eapply strict_subset_cardinal.
    assert (strict_subset Wc Wcls).
    { split => //.
      destruct H1 as [cl [clcls nvalid hcll hv]].
      pose proof (model_ok mwc).
      eapply is_model_invalid_clause in H1; tea.
      assert (~ LevelSet.In (levelexpr_level (concl cl)) W).
      { intros hin. rewrite in_clauses_with_concl in H1. intuition auto. }
      move/(_ (levelexpr_level (concl cl))) => [] wcwcls wclswc.
      now apply H4, WcW, wclswc. }
    eapply (strict_subset_leq_right _ (LevelSet.diff V Wc)).
    2:{ clear -UWc WcW UW WU H3 H4. lsets. }
    apply strict_subset_diff_incl => //. clear -H H3; lsets.
  - eapply mcls'.
  - auto.
  - exact mcls'.
  - eapply (check_model_spec_V mof clsV) in eqm as [UW WU hcl ext].
    eapply check_model_spec in eqm' as [].
    2:{ eapply model_of_subset. 2:exact clsV.
        exact (valid_model_of mwc (valid_model_of mwr (model_of_ext mof ext))). }
    assert (WV : W ⊂_lset V).
    { clear -UV clsV WU; lsets. }
    eapply model_ext_trans_weaken => //. 2:tea. auto. 
    transitivity mcls; [|apply mcls'].
    transitivity (model_model mwc). 2:{ eapply model_extension_weaken; [|tea]. lsets. }
    transitivity (model_model mwr). 2:{ eapply model_extension_weaken; [|apply mwc]. lsets. }
    eapply model_extension_weaken. 2:apply mwr. lsets.
  - eapply (check_model_spec_V mof clsV) in eqm as [UW WU hcl ext].
    eapply check_model_spec in eqm' as [].
    2:{ eapply model_of_subset. 2:exact clsV.
      exact (valid_model_of mwc (valid_model_of mwr (model_of_ext mof ext))). }
    split. lsets. lsets.
  - eapply (check_model_spec_V mof clsV) in eqm as [UW WU hcl ext].
    refine (valid_model_of mwc _).
    refine (valid_model_of mwr _).
    refine (model_of_ext mof ext).
  - auto.
  - rewrite check_model_is_model // in eqm'.
    eapply (check_model_spec_V mof clsV) in eqm as [UW WU hcl ext].
    refine (valid_model_of mwc _).
    refine (valid_model_of mwr _).
    eapply model_of_subset.
    refine (model_of_ext mof ext). auto.
  - eapply (check_model_spec_V mof clsV) in eqm as [UW WU hcl ext].
    transitivity m'. eapply model_extension_weaken; [|tea]. lsets.
    transitivity (model_model mwr). 2:{ eapply model_extension_weaken; [|apply mwc]. lsets. }
    eapply model_extension_weaken. 2:apply mwr. lsets.
  - eapply (check_model_spec_V mof clsV) in eqm as [UW WU hcl ext].
    split; lsets.
  - exact mof.
  - exact clsV.
  - apply check_model_is_model in eqm; eauto.
    eapply model_of_subset; tea.
  - reflexivity.
  - split; lsets.
Qed.

Transparent lexprod_rel_wf.

Definition zero_model levels := 
  LevelSet.fold (fun l acc => LevelMap.add l 0 acc) levels (LevelMap.empty _).

Definition add_max l k m := 
  match LevelMap.find l m with
  | Some k' => 
    if k' <? k then LevelMap.add l k m
    else m
  | None => LevelMap.add l k m
  end.

#[local] Instance proper_levelexprset_levels : Proper (LevelExprSet.Equal ==> LevelSet.Equal)
  LevelExprSet.levels.
Proof.
  intros s s' eq l.
  rewrite !levelexprset_levels_spec.
  firstorder eauto.
Qed.

Lemma In_add_max l l' k acc :
  LevelMap.In (elt:=nat) l (add_max l' k acc) <->
  (l = l' \/ LevelMap.In l acc).
Proof.
  unfold add_max.
  destruct LevelMap.find eqn:hl.
  case: Nat.ltb_spec. 
  - rewrite LevelMapFact.F.add_in_iff MoreLevel.compare_eq.
    firstorder eauto.
  - intros. intuition auto. subst.
    now rewrite LevelMapFact.F.in_find_iff hl.
  - LevelMapFact.F.map_iff. rewrite MoreLevel.compare_eq. intuition auto.
Qed.

Lemma In_fold_add_max k n a : 
  LevelMap.In (elt:=nat) k
  (LevelExprSet.fold
      (fun '(l, k0) (acc : LevelMap.t nat) => add_max l k0 acc) n a) <-> 
  (LevelSet.In k (LevelExprSet.levels n)) \/ LevelMap.In k a.
Proof. 
  eapply LevelExprSetProp.fold_rec.
  - intros s' he.
    rewrite (LevelExprSetProp.empty_is_empty_1 he).
    cbn. rewrite LevelSetFact.empty_iff. intuition auto.
  - intros.
    destruct x as [l k'].
    rewrite In_add_max.
    rewrite H2 !levelexprset_levels_spec.
    split.
    * intros []; subst.
      left. exists k'. apply H1. now left.
      destruct H3 as [[k'' ?]|?]. left; exists k''. apply H1. now right.
      now right.
    * red in H1. setoid_rewrite H1.
      intros [[k'' []]|]. noconf H3. now left.
      right. now left; exists k''. right; right. apply H3.
Qed.


(* To handle the constraint checking decision problem,
  we must start with a model where all atoms [l + k]
  appearing in premises are true. Otherwise the 
  [l := 0] model is minimal for [l+1-> l+2]. 
  Starting with [l := 1], we see that the minimal model above it 
  has [l := ∞].
  We also ensure that all levels in the conclusions are in the model.
  
  *)

Definition min_model_map (m : LevelMap.t nat) cls : LevelMap.t nat :=
  Clauses.fold (fun '(cl, concl) acc => 
    LevelExprSet.fold (fun '(l, k) acc => 
      add_max l k acc) cl (add_max (levelexpr_level concl) 0 acc)) cls m.

Lemma min_model_map_levels m cls k : 
  LevelMap.In k (min_model_map m cls) <-> 
    LevelSet.In k (clauses_levels cls) \/ LevelMap.In k m.
Proof.
  rewrite /min_model_map.
  rewrite clauses_levels_spec.
  eapply ClausesProp.fold_rec.
  - intros s' he. intuition auto.
    destruct H0 as [cl []].
    clsets.
  - intros x a s' s'' inx ninx hadd ih.
    destruct x as [cl k'].
    rewrite In_fold_add_max In_add_max. rewrite ih.
    intuition auto. left. exists (cl, k'); intuition auto.
    apply hadd. now left. 
    rewrite clause_levels_spec. now left.
    subst. left. exists (cl, k'). split. apply hadd; now left.
    rewrite clause_levels_spec. now right.
    destruct H as [cl'' []]. left. exists cl''.
    intuition auto. apply hadd. now right.
    destruct H3 as [cl'' []].
    apply hadd in H0 as []; subst.
    rewrite clause_levels_spec in H3. destruct H3; subst.
    cbn in H0. now left. right. now left.
    right. right. left; exists cl''. split => //.
Qed.

Definition min_model m cls : model := min_model_map m cls.
      
Definition init_model cls := min_model (LevelMap.empty _) cls.

Lemma init_model_levels cls k : 
  LevelMap.In k (init_model cls) <-> LevelSet.In k (clauses_levels cls).
Proof.
  rewrite min_model_map_levels. intuition auto. 
  now rewrite LevelMapFact.F.empty_in_iff in H0.
Qed.

Definition init_w (levels : LevelSet.t) : LevelSet.t := LevelSet.empty.

(* We don't need predecessor clauses as they are trivially satisfied *)
(* Definition add_predecessors (V : LevelSet.t) cls :=
  LevelSet.fold (fun l acc => 
    Clauses.add (NonEmptySetFacts.singleton (l, 1), (l, 0)) acc) V cls. *)

Definition infer_result V cls := result V LevelSet.empty cls (init_model cls).

Equations? infer (cls : clauses) : infer_result (clauses_levels cls) cls := 
  infer cls := loop (clauses_levels cls) LevelSet.empty cls (init_model cls) (And3 _ _ _).
Proof.
  - now eapply clauses_conclusions_levels.
  - lsets.
  - now eapply init_model_levels.
Qed.

Definition mk_level x := LevelExpr.make (Level.Level x).
Definition levela := mk_level "a".
Definition levelb := mk_level "b".
Definition levelc := mk_level "c".
Definition leveld := mk_level "d".
Definition levele := mk_level "e".

Definition ex_levels : LevelSet.t := 
  LevelSetProp.of_list (List.map (LevelExpr.get_level) [levela; levelb; levelc; leveld; levele]).

Definition mk_clause (hd : LevelExpr.t) (premise : list LevelExpr.t) (e : LevelExpr.t) : clause := 
  (NonEmptySetFacts.add_list premise (NonEmptySetFacts.singleton hd), e).

Definition levelexpr_add (x : LevelExpr.t) (n : nat) : LevelExpr.t :=
  let (l, k) := x in (l, k + n).

(* Example from the paper *)  
Definition clause1 : clause := mk_clause levela [levelb] (LevelExpr.succ levelb).  
Definition clause2 : clause := mk_clause levelb [] (levelexpr_add levelc 3).
Definition clause3 := mk_clause (levelexpr_add levelc 1) [] leveld.
Definition clause4 := mk_clause levelb [levelexpr_add leveld 2] levele.
Definition clause5 := mk_clause levele [] levela.

Definition ex_clauses :=
  ClausesProp.of_list [clause1; clause2; clause3; clause4].

Definition ex_loop_clauses :=
  ClausesProp.of_list [clause1; clause2; clause3; clause4; clause5].


Example test := infer ex_clauses.
Example test_loop := infer ex_loop_clauses.

Definition print_level_nat_map (m : LevelMap.t nat) :=
  let list := LevelMap.elements m in
  print_list (fun '(l, w) => string_of_level l ^ " -> " ^ string_of_nat w) nl list.

Definition print_wset (l : LevelSet.t) :=
  let list := LevelSet.elements l in
  print_list string_of_level " " list.

Definition valuation_of_model (m : model) : LevelMap.t nat :=
  let max := LevelMap.fold (fun l k acc => Nat.max k acc) m 0 in
  LevelMap.fold (fun l k acc => LevelMap.add l (max - k) acc) m (LevelMap.empty _).
  
Definition print_result {V cls} (m : infer_result V cls) :=
  match m with
  | Loop => "looping"
  | Model w m _ => "satisfiable with model: " ^ print_level_nat_map m.(model_model) ^ nl ^ " W = " ^
    print_wset w 
    ^ nl ^ "valuation: " ^ print_level_nat_map (valuation_of_model m.(model_model))
  end.
  
Definition valuation_of_result {V cls} (m : infer_result V cls) :=
  match m with
  | Loop => "looping"
  | Model w m _ => print_level_nat_map (valuation_of_model m.(model_model))
  end.

Eval compute in print_result test.
Eval compute in print_result test_loop.

(* Testing the unfolding of the loop function "by hand" *)
Definition hasFiniteModel {V U cls m} (m : result V U cls m) :=
  match m with
  | Loop => false
  | Model _ _ _ => true
  end.

Ltac hnf_eq_left := 
  match goal with
  | |- ?x = ?y => let x' := eval hnf in x in change (x' = y)
  end.

(* Goal hasFiniteModel test.
  hnf. hnf_eq_left. exact eq_refl.
  unfold test.
  unfold infer.
  rewrite /check.
  simp loop.
  set (f := check_model _ _).
  hnf in f. simpl in f.
  unfold f. unfold inspect.
  simp loop.
  set (eq := LevelSet.equal _ _).
  hnf in eq. unfold eq, inspect.
  simp loop.
  set (f' := check_model _ _).
  hnf in f'. unfold f', inspect.
  simp loop.
  set (f'' := check_model _ _).
  hnf in f''. simpl in f''.
  unfold inspect, f''. simp loop.
  set (eq' := LevelSet.equal _ _).
  hnf in eq'. unfold eq', inspect.
  simp loop.
  set (cm := check_model _ _).
  hnf in cm. simpl in cm.
  unfold inspect, cm. simp loop.
  exact eq_refl.
Qed. *)

Eval lazy in print_result test.
Eval compute in print_result test_loop.

Definition clauses_of_constraint (cstr : UnivConstraint.t) : clauses :=
  let '(l, d, r) := cstr in
  match d with
  | ConstraintType.Le k => 
    (* Represent r >= lk + k <-> lk + k <= r *)
    if (k <? 0)%Z then
      let n := Z.to_nat (- k) in 
      let r' := NonEmptySetFacts.map (fun l => levelexpr_add l n) r in
        LevelExprSet.fold (fun lk acc => Clauses.add (r', lk) acc) l Clauses.empty
    else
      LevelExprSet.fold (fun lk acc => 
        Clauses.add (r, levelexpr_add lk (Z.to_nat k)) acc) l Clauses.empty
  | ConstraintType.Eq => 
    let cls :=
      LevelExprSet.fold (fun lk acc => Clauses.add (r, lk) acc) l Clauses.empty
    in
    let cls' :=
      LevelExprSet.fold (fun rk acc => Clauses.add (l, rk) acc) r cls
    in cls'
  end.

Definition clauses_of_constraints (cstrs : ConstraintSet.t) : clauses :=
  ConstraintSet.fold (fun cstr acc => Clauses.union (clauses_of_constraint cstr) acc) cstrs Clauses.empty.

Definition print_premise (l : LevelAlgExpr.t) : string :=
  let (e, exprs) := LevelAlgExpr.exprs l in
  string_of_level_expr e ^
  match exprs with
  | [] => "" 
  | l => ", " ^ print_list string_of_level_expr ", " exprs 
  end.

Definition print_clauses (cls : clauses) :=
  let list := Clauses.elements cls in
  print_list (fun '(l, r) => 
    print_premise l ^ " → " ^ string_of_level_expr r) nl list.

Definition add_cstr (x : LevelAlgExpr.t) d (y : LevelAlgExpr.t) cstrs :=
  ConstraintSet.add (x, d, y) cstrs.

Coercion LevelAlgExpr.make : LevelExpr.t >-> LevelAlgExpr.t.
Import ConstraintType.
Definition test_cstrs :=
  (add_cstr levela Eq (levelexpr_add levelb 1)
  (add_cstr (LevelAlgExpr.sup levela levelc) Eq (levelexpr_add levelb 1)
  (add_cstr levelb (ConstraintType.Le 0) levela
  (add_cstr levelc (ConstraintType.Le 0) levelb
    ConstraintSet.empty)))).

Definition test_clauses := clauses_of_constraints test_cstrs.

Definition test_levels : LevelSet.t := 
  LevelSetProp.of_list (List.map (LevelExpr.get_level) [levela; levelb; levelc]).

Eval compute in print_clauses test_clauses.

Definition test' := infer test_clauses.
Eval compute in print_result test'.
Import LevelAlgExpr (sup).

Definition test_levels' : LevelSet.t := 
  LevelSetProp.of_list (List.map (LevelExpr.get_level) 
    [levela; levelb;
      levelc; leveld]).

Notation " x + n " := (levelexpr_add x n).

Fixpoint chain (l : list LevelExpr.t) :=
  match l with
  | [] => ConstraintSet.empty
  | hd :: [] => ConstraintSet.empty
  | hd :: (hd' :: _) as tl => 
    add_cstr hd (Le 10) hd' (chain tl)
  end.

Definition levels_to_n n := 
  unfold n (fun i => (Level.Level (string_of_nat i), 0)).

Definition test_chain := chain (levels_to_n 50).

Eval compute in print_clauses  (clauses_of_constraints test_chain).

(** These constraints do have a finite model that makes all implications true (not vacuously) *)
Time Eval vm_compute in print_result (infer (clauses_of_constraints test_chain)).

(* Eval compute in print_result test''. *) 
Definition chainres :=  (infer (clauses_of_constraints test_chain)).



(*Goal hasFiniteModel chainres.
  hnf.
  unfold chainres.
  unfold infer.
  rewrite /check.
  simp loop.
  set (f := check_model _ _).
  compute in f.
  hnf in f. simpl in f.
  unfold f. unfold inspect.
  simp loop.
  set (eq := LevelSet.equal _ _). simpl in eq.
  hnf in eq. unfold eq, inspect.
  rewrite loop_clause_1_clause_2_equation_2.
  set (l := loop _ _ _ _ _ _). hnf in l. simpl in l.
  simp loop.
  set (f' := check_model _ _).
  hnf in f'. unfold f', inspect.
  simp loop.
  set (f'' := check_model _ _).
  hnf in f''. simpl in f''.
  unfold inspect, f''. simp loop.
  set (eq' := LevelSet.equal _ _).
  hnf in eq'. unfold eq', inspect.
  simp loop.
  set (cm := check_model _ _).
  hnf in cm. simpl in cm.
  unfold inspect, cm. simp loop.
  exact eq_refl.
Qed. *)

(*Goal chainres = Loop.
  unfold chainres.
  unfold infer.
  set (levels := Clauses.fold _ _ _).
  rewrite /check.
  simp loop.
  set (f := check_model _ _).
  hnf in f. cbn in f.
  unfold f. unfold inspect.
  simp loop.
  set (eq := LevelSet.equal _ _).
  hnf in eq. unfold eq, inspect.
  simp loop.
  set (f' := check_model _ _).
  hnf in f'. cbn in f'. unfold flip in f'. cbn in f'.

set (f := check_model _ _).
hnf in f. cbn in f.
unfold f. cbn -[forward]. unfold flip.
unfold init_w.
rewrite unfold_forward.
set (f' := check_model _ _).
cbn in f'. unfold flip in f'.
hnf in f'. cbn in f'.
cbn.

unfold check_model. cbn -[forward]. unfold flip.
set (f := update_value _ _). cbn in f.
unfold Nat.leb in f. hnf in f.

Eval compute in print_result (infer ex_levels test_clauses).

*)

Definition test_above0 := 
  (add_cstr (levelc + 1) (ConstraintType.Le 0) levelc ConstraintSet.empty).
  
Eval compute in print_clauses (clauses_of_constraints test_above0).
Definition testabove0 := infer (clauses_of_constraints test_above0).

Eval vm_compute in print_result testabove0.

(** Verify that no clause holds vacuously for the model *)

Definition premise_holds (m : model) (cl : clause) :=
  satisfiable_premise m (premise cl).

Definition premises_hold (cls : clauses) (m : model) : bool :=
  Clauses.for_all (premise_holds m) cls.

Definition print_model_premises_hold cls (m : model) :=
  if premises_hold cls m then "all premises hold"
  else "some premise doesn't hold".

Definition print_premises_hold {V U cls m} (r : result V U cls m) :=
  match r with
  | Loop => "looping"
  | Model w m _ => print_model_premises_hold cls m.(model_model)
  end.

(* Is clause [c] non-vacuous and satisfied by the model? *)
Definition check_clause (m : model) (cl : clause) : bool :=
  satisfiable_premise m (premise cl) && satisfiable_atom m (concl cl).

Definition check_clauses (m : model) cls : bool :=
  Clauses.for_all (check_clause m) cls.

Definition check_cstr (m : model) (c : UnivConstraint.t) :=
  let cls := clauses_of_constraint c in
  check_clauses m cls.

Definition check_cstrs (m : model) (c : ConstraintSet.t) :=
  let cls := clauses_of_constraints c in
  check_clauses m cls.
  
Equations? infer_model_extension (V : LevelSet.t) (m : model) (cls cls' : clauses) 
  (prf : clauses_conclusions cls ⊂_lset V /\ clauses_conclusions cls' ⊂_lset V /\ model_of V m) : result V LevelSet.empty (Clauses.union cls cls') m :=
  | V, m, cls, cls', prf := loop V LevelSet.empty (Clauses.union cls cls') m _.
Proof.
  split. 2:lsets.
  intros x. rewrite clauses_conclusions_spec.
  intros [cl [hcl hl]].
  rewrite Clauses.union_spec in hcl. destruct hcl.
  - apply H, clauses_conclusions_spec. exists cl => //.
  - apply H0, clauses_conclusions_spec. exists cl => //.
  - exact H1.
Qed.
  (* as [cl []].
  eapply Clauses.union_spec in H as [].
  apply m.(model_clauses_conclusions). 
  rewrite clauses_conclusions_spec. now exists cl.
  eapply prf. rewrite clauses_conclusions_spec.
  now exists cl. 
Qed. *)

(*Equations? weaken_model (m : model) (cls : clauses) : valid_model (LevelSet.union (clauses_levels cls) V m cls) :=
  weaken_model m cls := 
    {| model_clauses := m.(model_clauses); 
       model_model :=  |}.
Proof.
  rewrite LevelSet.union_spec. right. now apply m.
Qed. *)

(* To infer an extension, we weaken a valid model for V to a model for [V ∪ clauses_levels cls] by 
   setting a minimal value for the new atoms in [clauses_levels cls \ V]
   such that the new clauses [cls] do not hold vacuously.
*)
Equations? infer_extension {V init cls} (m : valid_model V init cls) (cls' : clauses) :
  result (LevelSet.union (clauses_levels cls') V) LevelSet.empty (Clauses.union cls cls') (min_model m.(model_model) cls') :=
  infer_extension m cls' := 
    infer_model_extension (LevelSet.union (clauses_levels cls') V) (min_model m.(model_model) cls') cls cls' _.
Proof.
  repeat split.
  - pose proof (model_clauses_conclusions m). lsets. 
  - pose proof (clauses_conclusions_levels cls'). lsets.
  - red. intros.
    unfold min_model. rewrite min_model_map_levels.
    pose proof (model_of_V m k).
    apply LevelSet.union_spec in H as []; auto.
Qed.

Definition model_variables (m : model) : LevelSet.t :=
  LevelMap.fold (fun l _ acc => LevelSet.add l acc) m LevelSet.empty.

Variant enforce_result :=
  | Looping
  | ModelExt (m : model).

Definition enforce_clauses {V init cls} (m : valid_model V init cls) cls' : option model :=
  match infer_extension m cls' with
  | Loop => None
  | Model w m _ => Some m.(model_model)
  end.

Definition enforce_clause {V init cls} (m : valid_model V init cls) cl : option model :=
  enforce_clauses m (Clauses.singleton cl).

Definition enforce_cstr {V init cls} (m : valid_model V init cls) (c : UnivConstraint.t) :=
  let cls := clauses_of_constraint c in
  enforce_clauses m cls.

Definition enforce_cstrs {V init cls} (m : valid_model V init cls) (c : ConstraintSet.t) :=
  let cls := clauses_of_constraints c in
  enforce_clauses m cls.

Definition initial_cstrs :=
  (add_cstr (sup levela levelb) Eq (levelc + 1)
  (add_cstr levelc (Le 0) (sup levela levelb)
  (add_cstr levelc (Le 0) levelb
    ConstraintSet.empty))).

Definition enforced_cstrs :=
  (* (add_cstr (sup levela levelb) Eq (sup (levelc + 1) leveld) *)
  (add_cstr (levelb + 10) (Le 0) levele
  (* (add_cstr levelc (Le 0) levelb *)
  ConstraintSet.empty).
  
Definition initial_cls := clauses_of_constraints initial_cstrs.
Definition enforced_cls := clauses_of_constraints enforced_cstrs.
  
Eval vm_compute in init_model initial_cls.

Definition abeqcS :=
  clauses_of_constraints 
    (add_cstr (sup levela levelb) Eq (levelc + 1) ConstraintSet.empty).
  
Eval compute in print_clauses initial_cls.
Eval compute in print_clauses abeqcS.

Definition test'' := infer initial_cls.
Definition testabeqS := infer abeqcS.

Eval vm_compute in print_result test''.
Eval vm_compute in print_result testabeqS.

Eval vm_compute in print_model_premises_hold initial_cls (init_model initial_cls).

Ltac get_result c :=
  let c' := eval vm_compute in c in 
  match c' with
  | Loop => fail "looping"
  | Model ?w ?m _ => exact m
  end.

Definition model_cstrs' := ltac:(get_result test'').

Eval vm_compute in check_cstrs model_cstrs'.(model_model) initial_cstrs.
(* Here c <= b, in the model b = 0 is minimal, and b's valuation gives 1 *)
Eval vm_compute in print_result (infer initial_cls).

(* Here it is still the case, we started with b = 0 but move it to 10 
  due to the b + 10 -> e clause, and reconsider the b -> c clause to move 
  c up *)
Eval vm_compute in 
  option_map valuation_of_model
  (enforce_cstrs model_cstrs' enforced_cstrs).

(* The whole set of constraints has a finite model with c <= b *)

Definition all_clauses := Clauses.union initial_cls enforced_cls.

Eval vm_compute in valuation_of_result (infer all_clauses).
Eval vm_compute in
  option_map (is_model all_clauses) (option_of_result (infer all_clauses)).
  
(* This is a model? *)
Eval vm_compute in (enforce_cstrs model_cstrs' enforced_cstrs).
Eval vm_compute in print_clauses initial_cls.

Notation "x ≡ y" := (eq_refl : x = y) (at level 70).

(** This is also a model of (the closure of) the initial clauses *)
Check (option_map (is_model initial_cls) (enforce_cstrs model_cstrs' enforced_cstrs)
  ≡ Some true).

(* And a model of the new constraints *)
Check (option_map (is_model enforced_cls) (enforce_cstrs model_cstrs' enforced_cstrs)
   ≡ Some true).

(* All premises hold *)    
Eval vm_compute in 
  option_map (print_model_premises_hold enforced_cls) 
    (enforce_cstrs model_cstrs' enforced_cstrs).