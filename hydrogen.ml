type var = string

type tvar = string

type expr =
  | I   of int
  | V   of var
  | Lam of var * expr
  | Fun of var * var * expr
  | Let of var * expr * expr
  | App of expr * expr

type t = Int | Arrow of t * t | TV of tvar | GV of tvar | Bad

exception IllTyped of string

let rec string_of_type : t -> string = function
  | Int            -> "Int"
  | Arrow (t1, t2) -> (
    match t1 with
    | Arrow _ -> "(" ^ string_of_type t1 ^ ") -> " ^ string_of_type t2
    | _       -> string_of_type t1 ^ " -> " ^ string_of_type t2 )
  | TV tv          -> tv
  | GV tv          -> "'" ^ tv
  | Bad            -> "ILL-TYPED"

let rec string_of_expr : expr -> string = function
  | I i            -> string_of_int i
  | V v            -> v
  | Lam (x, e)     -> "λ" ^ x ^ ". " ^ string_of_expr e
  | Fun (f, x, e)  -> "fun " ^ f ^ " " ^ x ^ ". " ^ string_of_expr e
  | Let (x, e, e') -> "let " ^ x ^ " = " ^ string_of_expr e ^ " in " ^ string_of_expr e'
  | App (f, x)     ->
      let aux = function
        | I i -> string_of_int i
        | V v -> v
        | e   -> "(" ^ string_of_expr e ^ ")"
      in
      aux f ^ " " ^ aux x

let infer_type (expr : expr) =
  let tbl : (tvar, t) Hashtbl.t = Hashtbl.create 10 in
  
  let rec gather_constraints (gamma : (var * t) list) (expr : expr) (cs : (t * t) list) :
      (var * t) list * t * (t * t) list =
    match expr with
    | I _            -> (gamma, Int, cs)
    | V v            -> (gamma, instantiate (type_of_var gamma v), cs)
    | Lam (x, e)     ->
        let tx = freshTV () in
        let _, te, cse = gather_constraints ((x, tx) :: gamma) e cs in
        (gamma, Arrow (tx, te), cse)
    | Fun (f, x, e)  ->
        let tx = freshTV () and tfx = freshTV () in
        let tf = Arrow (tx, tfx) in
        let _, te, cse = gather_constraints ((f, tf) :: (x, tx) :: gamma) e cs in
        (gamma, Arrow (tx, te), (tf, Arrow (tx, te)) :: cse)
    | Let (x, e, e') ->
        let _, te, cse = gather_constraints gamma e cs in
        gather_constraints ((x, generalize gamma (unify_types te cse)) :: gamma) e' []
    | App (f, x)     ->
        let _, tf, csf = gather_constraints gamma f cs in
        let _, tx, csx = gather_constraints gamma x csf in
        let tfx = freshTV () in
        (gamma, tfx, (tf, Arrow (tx, tfx)) :: csx)
  
  and type_of_var (gamma : (var * t) list) (v : var) =
    match gamma with
    | []                 -> raise (IllTyped ("Unbound variable " ^ v))
    | (v', t') :: gamma' -> if v' = v then find t' else type_of_var gamma' v
  
  and find = function
    | Int            -> Int
    | GV gv          -> GV gv
    | Arrow (t1, t2) -> Arrow (find t1, find t2)
    | TV tv          -> (
      match Hashtbl.find_opt tbl tv with
      | None -> TV tv
      | Some t' when TV tv = t' -> t'
      | Some (Arrow (t1, t2)) ->
          let t1', t2' = (find t1, find t2) in
          Hashtbl.replace tbl tv (Arrow (t1', t2')) ;
          Arrow (t1', t2')
      | Some t' ->
          let t'' = find t' in
          if t' == t'' then t'' else (Hashtbl.replace tbl tv t'' ; t'') )
    | t              -> t
  
  and unify_types (t : t) (cs : (t * t) list) : t =
    let rec union (t1, t2) =
      match (find t1, find t2) with
      | t1', t2' when t1' = t2' -> ()
      | Arrow (a1, b1), Arrow (a2, b2) ->
          union (a1, a2) ;
          union (b1, b2)
      | TV a, t' | t', TV a ->
          if occurs (TV a) t' then
            raise
              (IllTyped ("The type variable " ^ a ^ " occurs inside " ^ string_of_type t'))
          else Hashtbl.replace tbl a t'
      | t1', t2' ->
          raise
            (IllTyped
               ("Cannot unify " ^ string_of_type t1' ^ " with " ^ string_of_type t2'))
    in
    List.iter union cs ; find t
  
  and occurs (x : t) (t : t) : bool =
    match find t with Arrow (t1, t2) -> occurs x t1 || occurs x t2 | t' -> t' = find x
  
  and freshTV : unit -> t =
    let counter = ref (int_of_char 'a' - 1) in
    fun _ ->
      counter := !counter + 1 ;
      TV (Printf.sprintf "%c" (char_of_int !counter))
  
  and generalize (gamma : (var * t) list) (t : t) : t =
    let rec generalize' (ftv : tvar list) (t : t) : t =
      match t with
      | Arrow (t1, t2) -> Arrow (generalize' ftv t1, generalize' ftv t2)
      | TV tv          -> if List.mem tv ftv then TV tv else GV tv
      | _              -> t
    and free_type_variables : t list -> tvar list = function
      | []      -> []
      | t :: ts ->
      match find t with
      | Arrow (t1, t2) -> free_type_variables (t1 :: t2 :: ts)
      | TV tv          -> tv :: free_type_variables ts
      | _              -> free_type_variables ts
    in
    generalize' (free_type_variables (List.map snd gamma)) t
  
  and instantiate (t : t) : t =
    let rec instantiate' t instd =
      match t with
      | Arrow (t1, t2) ->
          let t1', instd' = instantiate' t1 instd in
          let t2', instd'' = instantiate' t2 instd' in
          (Arrow (t1', t2'), instd'')
      | GV gv          -> (
        match List.find_opt (fun (gv', _) -> gv' = gv) instd with
        | Some (_, t) -> (t, instd)
        | None        ->
            let ntv = freshTV () in
            (ntv, (gv, ntv) :: instd) )
      | _              -> (t, instd)
    in
    fst (instantiate' t [])
  
  in
  try
    let gamma, t, cs = gather_constraints [] expr [] in
    (gamma, unify_types t cs)
  with IllTyped e ->
    Printf.printf "Type inference error: %s\n" e ;
    ([], Bad)
