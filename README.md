# Hydrogen
Type inference playground.

# Calculus' syntax
<img src="https://render.githubusercontent.com/render/math?math=\text{var} \ni x,\dots">

<img src="https://render.githubusercontent.com/render/math?math=\text{tvar} \ni \alpha,\dots">

<img src="https://render.githubusercontent.com/render/math?math=\text{type} \ni \tau \Coloneqq \alpha \mid \text{Int} \mid \tau \rightarrow \tau">

<img src="https://render.githubusercontent.com/render/math?math=\text{expr} \ni e \Coloneqq x \mid n \mid \lambda x . e \mid \text{fun} f x . e \mid e \: e \mid \text{let} x = e \: \text{in} \: e">

# Usage
Simply running `ocaml effect_examples.ml` should result in output like:
```
Simple effects:
Type / effect of λe:Error. λx. raise_e x is ∀e:Error. Unit -{e}-> ?τ1 / ι
Type / effect of handle put 21 {put v k. k () | get () k. k 37 | return x. x} is Unit / ι

Nested effects:
Type / effect of λy. handle_a handle_b put_a ((get_b ()) y) {get () k. k (λx. x) | put v k. k () | return x. x} {get () k. k 42 | put v k. k () | return x. x} is Int -> Unit / ι

Effect generalization:
Type / effect of let apply = λf. λx. f x in apply (λx. x) is ?τ4 -> ?τ4 / ι with env: (apply : ('τa -{'εb}-> 'τc) -> 'τa -{'εb}-> 'τc)
Type / effect of let update = λs:State 'a. λf. put_s (f (get_s ())) in update is ∀s:State ?τ2. (?τ2 -{s?ε5}-> ?τ2) -{s?ε5}-> Unit / ι with env: (update : ∀s:State 'a. ('a -{s'εa}-> 'a) -{s'εa}-> Unit)

Instance application:
Type / effect of let putx = λs:State Int. λx. put_s x in handle_a (putx<a>) 1 {put v k. k () | get () k. k 1 | return x. 2} is Int / ι with env: (putx : ∀s:State Int. Int -{s}-> Unit)
Type / effect of let update = λs:State a. λf. put_s (f (get_s ())) in handle_b (λ(). get_b ()) ((update<b>) (λx. x)) {get () k. λc. (k c) c | put v k. λc. (k ()) v | return x. λc. x} is ?τ15 -> ?τ15 / ι with env: (update : ∀s:State a. (a -{s'εa}-> a) -{s'εa}-> Unit)

Simple examples:
Type / effect of λx. x is ?τ0 -> ?τ0 / ι
Type / effect of λg. λf. λx. g (f x) is (?τ3 -{?ε3}-> ?τ4) -> (?τ2 -{?ε3}-> ?τ3) -> ?τ2 -{?ε3}-> ?τ4 / ι
Type / effect of λx. x 2 is (Int -{?ε1}-> ?τ1) -{?ε1}-> ?τ1 / ι
Type / effect of λy. (λx. x) 1 is ?τ0 -> Int / ι
Type / effect of λx. λy. x is ?τ0 -> ?τ1 -> ?τ0 / ι
Type / effect of λy. (λx. y x) 1 is (Int -{?ε3}-> ?τ3) -{?ε3}-> ?τ3 / ι
Type / effect of λx. (λx. x) (x 42) is (Int -{?ε3}-> ?τ3) -{?ε3}-> ?τ3 / ι
Type / effect of λx. λy. λz. (x z) (y z) is (?τ2 -{?ε5}-> ?τ4 -{?ε5}-> ?τ5) -> (?τ2 -{?ε5}-> ?τ4) -> ?τ2 -{?ε5}-> ?τ5 / ι

Let bindings:
Type / effect of let f = λx. x 1 in λy. f (λx. y x) is (Int -{?ε6}-> ?τ6) -{?ε6}-> ?τ6 / ι with env: (f : (Int -{'εa}-> 'τb) -{'εa}-> 'τb)
Type / effect of let g = λx. x (x 1) in let f = λx. x 1 in λy. g (f (λx. y x)) is (Int -{?ε13}-> Int -{?ε13}-> Int) -{?ε13}-> Int / ι with env: (f : (Int -{'εa}-> 'τb) -{'εa}-> 'τb) (g : (Int -{'εa}-> Int) -{'εa}-> Int)

Recursive functions:
Type / effect of fun f x. f (f 1) is Int -> Int / ι
Type / effect of let fix = fun fix f. f (fix f) in fix (λx. λy. λz. 2) is ?τ6 -> ?τ7 -> Int / ι with env: (fix : ('τa -{'εb}-> 'τa) -{'εb}-> 'τa)

Parametric polymorphism:
Type / effect of let id = λx. x in id id is ?τ2 -> ?τ2 / ι with env: (id : 'τa -> 'τa)
Type / effect of λx. (λy. y) (x 1) is (Int -{?ε3}-> ?τ3) -{?ε3}-> ?τ3 / ι
Type / effect of λx. let y = x 1 in y is (Int -{?ε2}-> ?τ1) -{?ε2}-> ?τ1 / ι with env: (y : ?τ1)

Ill-typed examples:
Type inference error: The type variable ?τ0 occurs inside ?τ0 -{?ε0}-> ?τ1
Type / effect of λx. x x is ILL-TYPED / ι
Type inference error: Instance (e : Error) application to (λx. x : ?τ0 -> ?τ0 / ι) which does not reduce to instance lambda
Type / effect of λe:Error. (λx. x)<e> is ILL-TYPED / ι
Type inference error: Nested unnamed handlers
Type / effect of handle handle put ((get ()) y) {get () k. k (λx. x) | return x. x} {put v k. k () | return x. x} is ILL-TYPED / ι

```
