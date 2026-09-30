(* Tests.v — executable checks of the MiniCUDA semantics extensions
   (bitwise operators + block-scope atomics), verified by `rocq make`.
   These pin the *meaning* of the new constructs (not just that they parse),
   complementing the preservation theorem in Sim.v. Rocq 9.2. *)

From Stdlib Require Import ZArith List String.
Require Import Cu2Hip.MiniCuda Cu2Hip.Map.
Import ListNotations.
Open Scope Z_scope.
Open Scope string_scope.

(* ---------------- bitwise integer operators ---------------- *)

Example ex_band  : eval_binop_int BBitAnd 6 3 = Some (VInt 2).   Proof. reflexivity. Qed.
Example ex_bor   : eval_binop_int BBitOr  6 3 = Some (VInt 7).   Proof. reflexivity. Qed.
Example ex_bxor  : eval_binop_int BBitXor 6 3 = Some (VInt 5).   Proof. reflexivity. Qed.
Example ex_shl   : eval_binop_int BShl    1 4 = Some (VInt 16).  Proof. vm_compute; reflexivity. Qed.
Example ex_shr   : eval_binop_int BShr   32 2 = Some (VInt 8).   Proof. vm_compute; reflexivity. Qed.

(* Shift counts outside [0,32) are UB in C, hence stuck (None), not modeled. *)
Example ex_shl_ub_hi  : eval_binop_int BShl 1 40   = None. Proof. vm_compute; reflexivity. Qed.
Example ex_shr_ub_neg : eval_binop_int BShr 1 (-1) = None. Proof. vm_compute; reflexivity. Qed.

(* Bitwise complement: ~x = -(x+1) under two's complement (Z.lnot). *)
Example ex_bnot :
  eval_expr host_benv empty_env default_mem (EUnop UBitNot (EInt 5)) = Some (VInt (-6)).
Proof. vm_compute; reflexivity. Qed.

(* Bitwise ops require integer operands; a non-int operand is stuck. *)
Example ex_band_nonint :
  eval_expr host_benv empty_env default_mem (EBinop BBitAnd (EInt 6) (EAddrof "p")) = None.
Proof. reflexivity. Qed.

(* ---------------- block-scope atomics ---------------- *)
(* Cell "x"[0] initialised to 5; target base is a pointer (EAddrof here for a
   self-contained test). Only the memory effect is observed. *)

Definition am (f : string) (rest : list expr) : option (env * gmem) :=
  eval_atomic host_benv empty_env (mem_upd default_mem "x" 0 (VInt 5)) f
              (ESubscript (EAddrof "x") (EInt 0) :: rest).

Definition cell (r : option (env * gmem)) : val :=
  match r with Some (_, gm') => gm' "x" 0 | None => VUnit end.

Example ex_aadd  : cell (am "atomicAdd"  [EInt 4]) = VInt 9.  Proof. vm_compute; reflexivity. Qed.
Example ex_asub  : cell (am "atomicSub"  [EInt 4]) = VInt 1.  Proof. vm_compute; reflexivity. Qed.
Example ex_amax  : cell (am "atomicMax"  [EInt 9]) = VInt 9.  Proof. vm_compute; reflexivity. Qed.
Example ex_amax2 : cell (am "atomicMax"  [EInt 2]) = VInt 5.  Proof. vm_compute; reflexivity. Qed.
Example ex_amin  : cell (am "atomicMin"  [EInt 2]) = VInt 2.  Proof. vm_compute; reflexivity. Qed.
Example ex_aexch : cell (am "atomicExch" [EInt 7]) = VInt 7.  Proof. vm_compute; reflexivity. Qed.

(* CAS swaps iff the compare value matches the cell. *)
Example ex_cas_hit  : cell (am "atomicCAS" [EInt 5; EInt 9]) = VInt 9. Proof. vm_compute; reflexivity. Qed.
Example ex_cas_miss : cell (am "atomicCAS" [EInt 7; EInt 9]) = VInt 5. Proof. vm_compute; reflexivity. Qed.

(* Arity/name mismatches are stuck, not silently accepted. *)
Example ex_cas_badarity : am "atomicCAS" [EInt 9] = None.          Proof. vm_compute; reflexivity. Qed.
Example ex_add_badarity : am "atomicAdd" [EInt 1; EInt 2] = None.  Proof. vm_compute; reflexivity. Qed.

(* All six atomics are recognised; a non-modeled name is rejected. *)
Example ex_is_atomic :
  forallb is_atomic ["atomicAdd";"atomicSub";"atomicMax";"atomicMin";"atomicExch";"atomicCAS"] = true.
Proof. reflexivity. Qed.
Example ex_not_atomic : is_atomic "atomicOr" = false. Proof. reflexivity. Qed.

(* ---------------- map is the identity on the new constructs ---------------- *)
(* The transpiler renames only APIs + header; device operators/atomics are
   identically named, so the verified core copies them verbatim. *)

Example ex_map_bitxor :
  map_expr (EBinop BBitXor (EVar "a") (EInt 3)) = EBinop BBitXor (EVar "a") (EInt 3).
Proof. reflexivity. Qed.

Example ex_map_atomic :
  map_stmt (SExpr (ECall "atomicMax" [ESubscript (EVar "d") (EInt 0); EInt 7]))
  = SExpr (ECall "atomicMax" [ESubscript (EVar "d") (EInt 0); EInt 7]).
Proof. reflexivity. Qed.

(* Atomic admission is exact: statement form, subscript target, and the
   operation-specific arity. This keeps the frontend and fixture checker from
   accepting a shape eval_atomic cannot execute. *)
Example ex_wf_atomic_stmt :
  wf_stmt (SExpr (ECall "atomicAdd"
    [ESubscript (EVar "acc") (EInt 0); EInt 1])) = true.
Proof. reflexivity. Qed.

Example ex_wf_atomic_value_rejected :
  wf_expr (ECall "atomicAdd"
    [ESubscript (EVar "acc") (EInt 0); EInt 1]) = false.
Proof. reflexivity. Qed.

Example ex_wf_atomic_target_rejected :
  wf_stmt (SExpr (ECall "atomicAdd" [EAddrof "acc"; EInt 1])) = false.
Proof. reflexivity. Qed.

Example ex_wf_atomic_arity_rejected :
  wf_stmt (SExpr (ECall "atomicCAS"
    [ESubscript (EVar "acc") (EInt 0); EInt 1])) = false.
Proof. reflexivity. Qed.


Definition atomic_wf_program : program :=
  {| pheader := "cuda_runtime.h";
     pkernels :=
       [{| kname := "k"; kparams := []; kshared := [];
          kbody := [SExpr (ECall "atomicAdd"
            [ESubscript (EVar "acc") (EInt 0); EInt 1])] |}];
     phost := [] |}.

Example ex_wf_programb_atomic_stmt :
  wf_programb [] "cuda_runtime.h" atomic_wf_program = true.
Proof. reflexivity. Qed.

Example ex_wf_programb_atomic_arity_rejected :
  wf_programb [] "cuda_runtime.h"
    {| pheader := "cuda_runtime.h";
       pkernels :=
         [{| kname := "k"; kparams := []; kshared := [];
            kbody := [SExpr (ECall "atomicAdd"
              [ESubscript (EVar "acc") (EInt 0)])] |}];
       phost := [] |} = false.
Proof. reflexivity. Qed.