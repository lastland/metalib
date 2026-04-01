Require Export Stlc.Stlc_inf.

Export StlcNotations.

Declare Scope exp_scope.
Notation "[ z ~> u ] e" := (subst_exp u z e) (at level 0) : exp_scope.
Notation "e ^ x"        := (open_exp_wrt_exp e (var_f x)) : exp_scope.
Open Scope exp_scope.

#[export] Hint Constructors typing step lc_exp : core.
