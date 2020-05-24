type identifier = string

type var = identifier

type instance = identifier

type typ = Int | Arrow of typ * typ | TV of tvar ref | GV of identifier | Bad

and tvar = Free of identifier | Bound of typ

type signature = Error | State of typ

type effect = Pure | Effect of signature

type type_effect = typ * effect

type expr =
  | I of int
  | V of var
  | Lam of var * expr
  | Let of var * expr * expr
  | App of expr * expr
  | ILam of instance * signature * expr
  | Op of instance * op

and op = Throw | Get | Put

type env = (var * typ) list

type ienv = (instance * signature) list

exception IllTyped of string

let rec string_of_type : typ -> string = function
  | Int -> "Int"
  | Arrow (t1, t2) -> (
    match t1 with
    | Arrow _ -> "(" ^ string_of_type t1 ^ ") -> " ^ string_of_type t2
    | _ -> string_of_type t1 ^ " -> " ^ string_of_type t2 )
  | TV {contents= Free a} -> a
  | TV {contents= Bound t} -> string_of_type t
  | GV v -> "'" ^ v
  | Bad -> "ILL-TYPED"

let string_of_signature : signature -> string = function
  | Error -> "Error"
  | State t -> "State " ^ string_of_type t

let string_of_effect : effect -> string = function
  | Pure -> "i"
  | Effect s -> string_of_signature s

let string_of_op : op -> string = function
  | Throw -> "raise"
  | Put -> "put"
  | Get -> "get"

let rec string_of_expr : expr -> string = function
  | I i -> string_of_int i
  | V v -> v
  | Lam (x, e) -> "λ" ^ x ^ ". " ^ string_of_expr e
  | Let (x, e, e') ->
      "let " ^ x ^ " = " ^ string_of_expr e ^ " in " ^ string_of_expr e'
  | App (e1, e2) ->
      let aux = function
        | I i -> string_of_int i
        | V v -> v
        | Op _ as e -> string_of_expr e
        | e -> "(" ^ string_of_expr e ^ ")"
      in
      aux e1 ^ " " ^ aux e2
  | Op (a, op) -> string_of_op op ^ "_" ^ a
  | ILam (a, s, e) ->
      "λ" ^ a ^ ":" ^ string_of_signature s ^ ". " ^ string_of_expr e

let rec occurs (x : identifier) : typ -> bool = function
  | Arrow (t1, t2) -> occurs x t1 || occurs x t2
  | TV {contents= Free a} -> x = a
  | _ -> false

let rec find : typ -> typ = function
  | Arrow (t1, t2) -> Arrow (find t1, find t2)
  | TV ({contents= Bound t} as tv) ->
      let t' = find t in
      tv := Bound t' ;
      t'
  | t -> t

let rec union ((t1, t2) : typ * typ) : unit =
  match (find t1, find t2) with
  | t1', t2' when t1' = t2' -> ()
  | Arrow (a1, b1), Arrow (a2, b2) ->
      union (a1, a2) ;
      union (b1, b2)
  | TV {contents= Bound t}, t' | t', TV {contents= Bound t} -> union (t, t')
  | TV ({contents= Free a} as tv), t' | t', TV ({contents= Free a} as tv) ->
      if occurs a t' then
        raise
          (IllTyped
             ("The type variable " ^ a ^ " occurs inside " ^ string_of_type t'))
      else tv := Bound t'
  | t1', t2' ->
      raise
        (IllTyped
           ( "Cannot unify " ^ string_of_type t1' ^ " with "
           ^ string_of_type t2' ))

let type_of_var (gamma : env) (v : var) : typ =
  match List.assoc_opt v gamma with
  | None -> raise (IllTyped ("Free variable " ^ v))
  | Some t -> find t

let (freshTV : unit -> typ), (refreshTV : unit -> unit) =
  let counter = ref (int_of_char 'a' - 1) in
  ( (fun () ->
      incr counter ;
      TV (ref (Free (Printf.sprintf "_%c" (char_of_int !counter)))) )
  , fun () -> counter := int_of_char 'a' - 1 )

let unify_types (t : typ) (cs : (typ * typ) list) : typ =
  List.iter union cs ; find t

let generalize (gamma : env) (t : typ) : typ =
  let rec generalize' ftv = function
    | Arrow (t1, t2) -> Arrow (generalize' ftv t1, generalize' ftv t2)
    | TV ({contents= Free a} as tv) as t ->
        if List.mem a ftv then t
        else (
          tv := Bound (freshGV ()) ;
          t )
    | TV {contents= Bound t} -> generalize' ftv t
    | t -> t
  and free_type_variables = function
    | [] -> []
    | t :: ts -> (
      match find t with
      | Arrow (t1, t2) -> free_type_variables (t1 :: t2 :: ts)
      | TV {contents= Free a} -> a :: free_type_variables ts
      | _ -> free_type_variables ts )
  and freshGV =
    let counter = ref (int_of_char 'a' - 1) in
    fun _ ->
      counter := !counter + 1 ;
      GV (Printf.sprintf "%c" (char_of_int !counter))
  in
  generalize' (free_type_variables (List.map snd gamma)) t

let instantiate (t : typ) : typ =
  let rec instantiate' t instd =
    match t with
    | Arrow (t1, t2) ->
        let t1', instd' = instantiate' t1 instd in
        let t2', instd'' = instantiate' t2 instd' in
        (Arrow (t1', t2'), instd'')
    | GV gv -> (
      match List.assoc_opt gv instd with
      | Some t -> (t, instd)
      | None ->
          let ntv = freshTV () in
          (ntv, (gv, ntv) :: instd) )
    | _ -> (t, instd)
  in
  fst (instantiate' t [])

let rec infer (gamma : env) (expr : expr) (cs : (typ * typ) list) :
    env * typ * (typ * typ) list =
  match expr with
  | I _ -> (gamma, Int, cs)
  | V v -> (gamma, instantiate (type_of_var gamma v), cs)
  | Lam (x, e) ->
      let tx = freshTV () in
      let _, te, cse = infer ((x, tx) :: gamma) e cs in
      (gamma, Arrow (tx, te), cse)
  | Let (x, e, e') ->
      let _, te, cse = infer gamma e cs in
      infer ((x, generalize gamma (unify_types te cse)) :: gamma) e' []
  | App (e1, e2) ->
      let _, t1, cs1 = infer gamma e1 cs in
      let _, t2, cs2 = infer gamma e2 cs1 in
      let t = freshTV () in
      (gamma, t, (t1, Arrow (t2, t)) :: cs2)
  | Op _ | ILam _ -> raise (IllTyped "not implemented")

let infer_type (expr : expr) =
  try
    refreshTV () ;
    let gamma, t, cs = infer [] expr [] in
    (gamma, unify_types t cs)
  with IllTyped e ->
    print_string ("Type inference error: " ^ e ^ "\n") ;
    ([], Bad)
