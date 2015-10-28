-- 
-- Pretty.hs  - 
-- Based on code by Martin Erwig from Parameterized Fortran
-- Fortran pretty printer 

{-# LANGUAGE ExistentialQuantification, FlexibleContexts, FlexibleInstances, UndecidableInstances, MultiParamTypeClasses, DeriveDataTypeable, QuasiQuotes, DeriveFunctor, ImplicitParams, OverlappingInstances, ConstraintKinds #-}

module Language.Fortran.Pretty where

import Language.Fortran
import Debug.Trace
import Data.List

-- | Core pretty-printing primitive
pprint :: PrettyPrintable t => t -> String
pprint = let ?variant = DefaultPP in printMaster

-- | Define default pretty-print version constructor
data DefaultPP = DefaultPP -- Default behaviour

-- | The set of all types which can be used to switch between pretty printer versions
class PPVersion a 
instance PPVersion DefaultPP

-- Pretty printable types predicate (aliases the PrintMaster constraint)
type PrettyPrintable t = PrintMaster t DefaultPP 

-- | Master print behaviour
class PrintMaster t v where
    printMaster :: (?variant :: v) => t -> String

-- | Slave print behaviour
class PrintSlave t v where
    printSlave :: (?variant :: v) => t -> String

-- | Slave print-indenting behaviour
class PrintIndSlave t v where
    printIndSlave :: (?variant :: v) => Int -> t -> String

-- | Master print-indenting behaviour
class PrintIndMaster t v where
    printIndMaster :: (?variant :: v) => Int -> t -> String

-- | Default slave behaviour
instance (PrintMaster t DefaultPP) => PrintSlave t DefaultPP where
    printSlave = printMaster
instance (PrintIndMaster t DefaultPP) => PrintIndSlave t DefaultPP where
    printIndSlave = printIndMaster

-- | Behaviours that all slaves must have, i.e., for all versions v 
instance PPVersion v => PrintSlave String v where
    printSlave = id

--------------------------------------------------------------------------

-- | Definition of the master pretty printer which, notably, is defined for all versions 'v'.
instance PPVersion v => PrintMaster String v where
    printMaster = id

instance (PPVersion v, PrintSlave (ProgUnit p) v) => PrintMaster [ProgUnit p] v where
    printMaster xs = concat $ intersperse "\n" (map printSlave xs)

instance (PrintSlave (Arg p) v, 
          PrintSlave (BaseType p) v,
          PrintSlave (Block p) v,
          PrintSlave (Decl p) v,
          PrintSlave (Fortran p) v, 
          PrintSlave (Implicit p) v,
          PrintSlave (SubName p) v,
          PrintSlave (VarName p) v,
          PrintSlave (ProgUnit p) v,
          PPVersion v) => PrintMaster (ProgUnit p) v where
  printMaster (Sub _ _ (Just p) n a b)  = printSlave p ++ " subroutine "++(printSlave n)++printSlave a++"\n"++
                             printSlave b++
                          "\nend subroutine "++(printSlave n)++"\n"
  printMaster (Sub _ _ Nothing n a b)  = "subroutine "++(printSlave n)++printSlave a++"\n"++
                             printSlave b++
                          "\nend subroutine "++(printSlave n)++"\n"
  printMaster (Function _ _ (Just p) n a (Just r) b)  = printSlave p ++ " function "++(printSlave n)++printSlave a++" result("++printSlave r++")\n"++
                             printSlave b++
                          "\nend function "++(printSlave n)++"\n"
  printMaster (Function _ _ (Just p) n a Nothing b)  = printSlave p ++ " function "++(printSlave n)++printSlave a++"\n"++
                             printSlave b++
                          "\nend function "++(printSlave n)++"\n"
  printMaster (Function _ _ Nothing n a (Just r) b) = "function "++(printSlave n)++printSlave a++" result("++printSlave r++")\n"++
                             printSlave b++
                          "\nend function "++(printSlave n)++"\n"
  printMaster (Function _ _ Nothing n a Nothing b) = "function "++(printSlave n)++printSlave a++"\n"++
                             printSlave b++
                          "\nend function "++(printSlave n)++"\n"
  printMaster (Main _ _ n a b [])     = "program "++(printSlave n) ++ 
                                (if not (isEmptyArg a) then (printSlave a) else ""++"\n") ++
                                printSlave b ++
                                "\nend program "++ (printSlave n) ++"\n"
  printMaster (Main _ _ n a b ps)     = "program "++(printSlave n) ++ 
                                (if not (isEmptyArg a) then (printSlave a) else ""++"\n") ++
                                printSlave b ++
                                "\ncontains\n" ++
                                (concatMap printSlave ps) ++
                                "\nend program "++(printSlave n)++"\n"

  printMaster (Module _ _ n us i ds []) = "module "++(printSlave n)++"\n" ++
                             showUse us ++
                             printSlave i ++
                             printSlave ds ++
                          "end module " ++ (printSlave n)++"\n"
  printMaster (Module _ _ n us i ds ps) = "module "++(printSlave n)++"\n" ++
                             showUse us ++
                             printSlave i ++
                             printSlave ds ++
			     "\ncontains\n" ++
                             concatMap printSlave ps ++
                          "end module " ++ (printSlave n)++"\n"
  printMaster (BlockData _ _ n us i ds) = "block data " ++ (printSlave n) ++ "\n" ++
                             showUse us ++
                             printSlave i ++
                             printSlave ds ++
                          "end block data " ++ (printSlave n)++"\n"
  printMaster (Prog _ _ p)     = printSlave p
  printMaster (NullProg _ _)    = ""
  printMaster (IncludeProg _ _ ds Nothing) = printSlave ds 
  printMaster (IncludeProg _ _ ds (Just f)) = printSlave ds ++ "\n" ++ printSlave f

instance (PrintSlave (Fortran p) v, PrintSlave (Decl p) v, PrintSlave (Implicit p) v, PPVersion v) =>
            PrintMaster (Block p) v where
  printMaster (Block _ (UseBlock us _) i sp ds f) = showUse us++printSlave i++(printSlave ds)++printSlave f


instance (PrintSlave (Expr p) v) => PrintMaster (DataForm p) v where
  printMaster (Data _ ds) = "data "++(concat (intersperse "\n" (map show_data ds))) 

instance (Indentor (Decl p), 
          PrintSlave (Arg p) v,
          PrintSlave (ArgList p) v,
          PrintSlave (Attr p) v,
          PrintSlave (BinOp p) v,
          PrintSlave (Decl p) v,
          PrintSlave (DataForm p) v,
          PrintSlave (Expr p) v, 
          PrintSlave (GSpec p) v, 
          PrintSlave (Implicit p) v,
          PrintSlave (InterfaceSpec p) v, 
          PrintSlave (MeasureUnitSpec p) v,
          PrintSlave (SubName p) v,
          PrintSlave (UnaryOp p) v, 
          PrintSlave (VarName p) v,
          PrintSlave (Type p) v,
           PPVersion v) => PrintMaster (Decl p) v where
  printMaster x@(Decl _ _ vs t)  = (indR x 1)++printSlave t++" :: "++asSeq id (map showDV vs)++"\n"
  printMaster (Namelist _ ns) = ind 1++"namelist "++show_namelist ns++"\n"
  printMaster (DataDecl _ ds) = ind 1++ (printSlave ds) ++"\n"
  printMaster t@(Equivalence  _ _ vs) = (indR t 1)++"equivlance ("++(concat (intersperse "," (map printMaster vs))) ++ ")\n"
  printMaster (AttrStmt _ p gs) = ind 1++printSlave p ++ " (" ++asSeq id (map showDV gs) ++ ") \n"
  printMaster (AccessStmt _ p []) = ind 1++printSlave p ++ "\n"
  printMaster (AccessStmt _ p gs) = ind 1++printSlave p ++ " :: " ++ (concat . intersperse ", " . map printSlave) gs++"\n"
  printMaster (ExternalStmt _ xs)  = ind 1++"external :: " ++ (concat (intersperse "," xs)) ++ "\n"
  printMaster (Interface _ (Just g) is) = ind 1 ++ "interface " ++ printSlave g ++ printMasterInterfaceSpecs is ++ ind 1 ++ "end interface" ++ printSlave g ++ "\n"
  printMaster (Common _ _ name exps) = ind 1++"common " ++ (case name of 
                                                     Just n -> "/" ++ n ++ "/ "
                                                     Nothing -> "") ++ (concat (intersperse "," (map printMaster exps))) ++ "\n"
  printMaster (Interface _ Nothing  is) = ind 1 ++ "interface " ++ printMasterInterfaceSpecs is ++ ind 1 ++ "end interface\n"
  printMaster (DerivedTypeDef _  _ n as ps ds) = ind 1 ++ "type " ++ printMasterList as ++  " :: " ++ printSlave n ++ "\n" ++ (concat (intersperse "\n" (map (printSlave) ps))) ++ (if (length ps > 0) then "\n" else "") ++ (concatMap (((ind 2) ++) . printSlave) ds) ++ ind 1 ++ "end type " ++ printSlave n ++ "\n\n"
  printMaster (MeasureUnitDef _ _ ds) = ind 1 ++ "unit :: " ++ (concat . intersperse ", " . map showDU) ds ++ "\n"
  printMaster (Include _ i)  = "include "++printSlave i
  printMaster (DSeq _ d d')  = printSlave d++printSlave d'
  printMaster (NullDecl _ _)    = ""
  
printMasterInterfaceSpecs xs = concat $ intersperse "\n" (map printMaster xs)

show_namelist ((x,xs):[]) = "/" ++ printSlave x ++ "/" ++ (concat (intersperse ", " (map printSlave xs)))
show_namelist ((x,xs):ys) = "/" ++ printSlave x ++ "/" ++ (concat (intersperse ", " (map printSlave xs))) ++ "," ++ show_namelist ys
show_data     ((xs,ys)) = "/" ++  printSlave xs ++ "/" ++ printSlave ys

showDV (v, NullExpr _ _, Just n)  = (printMaster v) ++ "*" ++ show n
showDV (v, NullExpr _ _, Nothing) = printMaster v
showDV (v,e,Nothing)              = printMaster v++" = "++printMaster e
showDV (v,e,Just n)              = (printMaster v) ++ "*" ++ show n ++ " = "++(printMaster e)

showDU (name,spec) = printMaster name++" = "++printMaster spec

instance (PrintSlave (ArgList p) v, 
          PrintSlave (BinOp p) v, 
          PrintSlave (UnaryOp p) v,
          PrintSlave (BaseType p) v,
          PrintSlave (Expr p) v,
          PrintSlave (MeasureUnitSpec p) v,
          PrintSlave (VarName p) v,
          PPVersion v) => PrintMaster (Type p) v where
  printMaster (BaseType _ bt as (NullExpr _ _)  (NullExpr _ _))   = printSlave bt++printMasterList as
  printMaster (BaseType _ bt as (NullExpr _ _) e')          = printSlave bt++" (len="++printSlave e'++")"++printMasterList as
  printMaster (BaseType _ bt as e (NullExpr _ _))           = printSlave bt++" (kind="++printSlave e++")"++printMasterList as
  printMaster (BaseType _ bt as e               e')                = printSlave bt++" (len="++printSlave e'++"kind="++printSlave e++")"++printMasterList as
  printMaster (ArrayT _ [] bt as (NullExpr _ _) (NullExpr _ _))   = printSlave bt++printMasterList as
  printMaster (ArrayT _ [] bt as (NullExpr _ _) e')         = printSlave bt++" (len="++printSlave e'++")"++printMasterList as
  printMaster (ArrayT _ [] bt as e (NullExpr _ _))          = printSlave bt++" (kind="++printSlave e++")"++printMasterList as
  printMaster (ArrayT _ [] bt as e                e')              = printSlave bt++" (len="++printSlave e'++"kind="++printSlave e++")"++printMasterList as
  printMaster (ArrayT _ rs bt as (NullExpr _ _)  (NullExpr _ _))  = printSlave bt++" , dimension ("++showRanges rs++")"++printMasterList as
  printMaster (ArrayT _ rs bt as (NullExpr _ _) e')         = printSlave bt++" (len="++printSlave e'++")"++" , dimension ("++showRanges rs++")"++printMasterList as
  printMaster (ArrayT _ rs bt as e (NullExpr _ _))          = printSlave bt++" (kind="++printSlave e++")"++" , dimension ("++showRanges rs++")"++printMasterList as
  printMaster (ArrayT _ rs bt as e               e')               = printSlave bt++" (len="++printSlave e'++"kind="++printSlave e++")"++" , dimension ("++showRanges rs++")"++printMasterList as


instance (PrintSlave (ArgList p) v, PrintSlave (BinOp p) v, PrintSlave (Expr p) v, PrintSlave (UnaryOp p) v, 
          PrintSlave (VarName p) v, 
          PrintSlave (MeasureUnitSpec p) v, PPVersion v) => PrintMaster (Attr p) v where --new
    printMaster (Allocatable _)      = "allocatable "
    printMaster (Parameter _)        = "parameter "
    printMaster (External _)         = "external "
    printMaster (Intent _  (In _))   = "intent(in) "
    printMaster (Intent _ (Out _))   = "intent(out) "
    printMaster (Intent _ (InOut _)) = "intent(inout) "
    printMaster (Intrinsic _)        = "intrinsic "
    printMaster (Optional _)         = "optional "
    printMaster (Pointer _)          = "pointer "
    printMaster (Save _)             = "save "
    printMaster (Target _)           = "target "
    printMaster (Volatile _)         = "volatile "
    printMaster (Public _)           = "public "
    printMaster (Private _)          = "private "
    printMaster (Sequence _)         = "sequence "
    printMaster (Dimension _ r)      = "dimension (" ++ (showRanges r) ++ ")"
    printMaster (MeasureUnit _ u)    = "unit("++printSlave u++")"

instance (PPVersion v) => PrintMaster (MeasureUnitSpec p) v where
  printMaster (UnitProduct _ units) = showUnits units
  printMaster (UnitQuotient _ units1 units2) = showUnits units1++" / "++showUnits units2
  printMaster (UnitNone _) = ""

instance (PPVersion v) => PrintMaster (Fraction p) v where
  printMaster (IntegerConst _ s) = "**"++printSlave s
  printMaster (FractionConst _ p q) = "**("++printSlave p++"/"++printSlave q++")"
  printMaster (NullFraction _) = ""

instance (PrintSlave (Arg p) v, PrintSlave (BinOp p) v, PrintSlave (Expr p) v, PPVersion v) => PrintMaster (GSpec p) v where
  printMaster (GName _ s)  = printSlave s
  printMaster (GOper _ op) = "operator("++printSlave op++")"
  printMaster (GAssg _)    = "assignment(=)"

instance (PrintSlave (Arg p) v, PrintSlave (Decl p) v, PrintSlave (Implicit p) v,
          PrintSlave (SubName p) v, PPVersion v) => PrintMaster (InterfaceSpec p) v where
  printMaster (FunctionInterface _ s as us i ds)   = (ind 1)++ "function " ++ printSlave s ++ printSlave as ++ showUse us ++ printSlave i ++ printSlave ds ++ "\nend function " ++ printSlave s
  printMaster (SubroutineInterface _ s as us i ds) = (ind 1)++ "subroutine " ++ printSlave s ++ printSlave as ++ showUse us ++ printSlave i ++ printSlave ds ++ "\nend subroutine " ++ printSlave s
  printMaster (ModuleProcedure _ ss) = (ind 2) ++ "module procedure " ++ concat (intersperse ", " (map (printSlave) ss))

instance (PPVersion v, PrintMaster (Uses p) v) => PrintMaster (UseBlock p) v where
  printMaster (UseBlock uses _) = printMaster uses

instance (PPVersion v) => PrintMaster (Uses p) v where
  printMaster u = showUse u

instance (PrintSlave (SubName p) v, PPVersion v) => PrintMaster (BaseType p) v where
  printMaster (Integer _)       = "integer"
  printMaster (Real    _)       = "real"
  printMaster (DoublePrecision _) = "double precision"
  printMaster (Character  _)    = "character"
  printMaster (Logical   _)     = "logical"
  printMaster (DerivedType _ s) = "type ("++printSlave s++")"
  printMaster (SomeType _)      = error "sometype not valid in output source file"

-- Printing statements and expressions
-- 
instance (PrintSlave (ArgList p) v,
          PrintSlave (BinOp p) v,
          PrintSlave (Expr p) v,
          PrintSlave (UnaryOp p) v,
          PrintSlave (VarName p) v,
          PPVersion v) => PrintMaster (Expr p) v where
  printMaster (Con _ _ i)         = i
  printMaster (ConL _ _ m s)        = m:("\'" ++ s ++ "\'")
  printMaster (ConS _ _ s)        = s
  printMaster (Var _ _ vs)        = showPartRefList vs
  printMaster (Bin _ _ bop e@(Bin _ _ op _ _ ) e'@(Bin _ _ op' _ _)) = checkPrec bop op (paren) (printSlave e)++printSlave bop++ checkPrec bop op' (paren) (printSlave e')
  printMaster (Bin _ _ bop e@(Bin _ _ op _ _) e')                      = checkPrec bop op (paren) (printSlave e)++printSlave bop++printSlave e'
  printMaster (Bin _ _ bop e                    e'@(Bin _ _ op' _ _))  = printSlave e++printSlave bop++checkPrec bop op' (paren) (printSlave e')
  printMaster (Bin _ _ bop e                    e')                      = printSlave e++printSlave bop++printSlave e'
  printMaster (Unary _ _ uop e)   = "("++printSlave uop++printSlave e++")"
  printMaster (CallExpr  _ _ s as) = printSlave s ++ printSlave as
  printMaster (Null _ _)          = "NULL()"
  printMaster (NullExpr _ _)      = ""
  printMaster (ESeq _ _ (NullExpr _ _) e)     = printSlave e
  printMaster (ESeq _ _ e (NullExpr _ _))     = printSlave e
  printMaster (ESeq _ _ e e')     = printSlave e++","++printSlave e'
  printMaster (Bound _ _ e e')    = printSlave e++":"++printSlave e'
  printMaster (Sqrt _ _ e)        = "sqrt("++printSlave e++")"
  printMaster (ArrayCon _ _ es)   = "(\\" ++ concat (intersperse ", " (map (printSlave) es)) ++ "\\)"
  printMaster (AssgExpr _ _ v e)  = v ++ "=" ++ printSlave e

instance (PrintIndMaster (Fortran p) v, PPVersion v) => PrintMaster (Fortran p) v where
  printMaster = printIndMaster 1

instance (PrintSlave (ArgName p) v, PPVersion v) => PrintMaster (Arg p) v where
  printMaster (Arg _ vs _) = "("++ printSlave vs ++")"
  
instance (PrintSlave (Expr p) v, PPVersion v) => PrintMaster (ArgList p) v where
  printMaster (ArgList _ es) = "("++printSlave es++")" -- asTuple printSlave es
  
instance PPVersion v => PrintMaster (BinOp p) v where
  printMaster (Plus  _) ="+"
  printMaster (Minus _) ="-" 
  printMaster (Mul   _) ="*"
  printMaster (Div   _) ="/"
  printMaster (Or    _) =".or."
  printMaster (And   _) =".and."
  printMaster (Concat _) ="//"
  printMaster (Power _) ="**"
  printMaster (RelEQ _) ="=="
  printMaster (RelNE _) ="/="
  printMaster (RelLT _) ="<"
  printMaster (RelLE _) ="<="
  printMaster (RelGT _) =">"
  printMaster (RelGE _) =">="

instance PPVersion v => PrintMaster (UnaryOp p) v where
  printMaster (UMinus _) = "-"
  printMaster (Not    _) = ".not."
  
instance PPVersion v => PrintMaster (VarName p) v where
  printMaster (VarName _ v) = v  

instance (PrintSlave (VarName p) v, PrintSlave (ArgName p) v, PPVersion v) => PrintMaster (ArgName p) v where
    printMaster (ArgName _ a)                    = a  
    printMaster (ASeq _ (NullArg _) (NullArg _)) = ""
    printMaster (ASeq _ (NullArg _)  a')         = printSlave a'
    printMaster (ASeq _ a (NullArg _))           = printSlave a
    printMaster (ASeq _ a a')                    = printSlave a++","++printSlave a'
    printMaster (NullArg _)                            = ""

instance PPVersion v => PrintMaster (SubName p) v where
  printMaster (SubName _ n)   = n
  printMaster (NullSubName _) = error "subroutine needs a name"

instance PPVersion v => PrintMaster ( Implicit p) v where
  printMaster (ImplicitNone _) = "   implicit none\n"
  printMaster (ImplicitNull _) = ""
  
instance (PrintSlave (Expr p) v, PPVersion v) => PrintMaster (Spec p) v where
  printMaster (Access        _ s) = "access = " ++ printSlave s
  printMaster (Action        _ s) = "action = "++printSlave s
  printMaster (Advance       _ s) = "advance = "++printSlave s
  printMaster (Blank         _ s) = "blank = "++printSlave s
  printMaster (Delim         _ s) = "delim = "++printSlave s
  printMaster (Direct        _ s) = "direct = "++printSlave s
  printMaster (End           _ s) = "end = "++printSlave s
  printMaster (Eor           _ s) = "eor = "++printSlave s
  printMaster (Err           _ s) = "err = "++printSlave s
  printMaster (Exist         _ s) = "exist = "++printSlave s
  printMaster (File          _ s) = "file = "++printSlave s
  printMaster (FMT           _ s) = "fmt = "++printSlave s
  printMaster (Form          _ s) = "form = "++printSlave s
  printMaster (Formatted     _ s) = "formatted = "++printSlave s
  printMaster (Unformatted   _ s) = "unformatted = "++printSlave s
  printMaster (IOLength      _ s) = "iolength = "++printSlave s
  printMaster (IOStat        _ s) = "iostat = "++printSlave s
  printMaster (Opened        _ s) = "opened = "++printSlave s
  printMaster (Name          _ s) = "name = "++printSlave s
  printMaster (Named         _ s) = "named = "++printSlave s
  printMaster (NextRec       _ s) = "nextrec = "++printSlave s
  printMaster (NML           _ s) = "nml = "++printSlave s
  printMaster (NoSpec        _ s) = printSlave s
  printMaster (Floating      _ s1 s2) = printSlave s1 ++ "F" ++ printSlave s2
  printMaster (Number        _ s) = "number = "++printSlave s
  printMaster (Pad           _ s) = "pad = "++printSlave s
  printMaster (Position      _ s) = "position = "++printSlave s
  printMaster (Read          _ s) = "read = "++printSlave s
  printMaster (ReadWrite     _ s) = "readwrite = "++printSlave s
  printMaster (WriteSp       _ s) = "write = "++printSlave s
  printMaster (Rec           _ s) = "rec = "++printSlave s
  printMaster (Recl          _ s) = "recl = "++printSlave s
  printMaster (Sequential    _ s) = "sequential = "++printSlave s
  printMaster (Size          _ s) = "size = "++printSlave s
  printMaster (Status        _ s) = "status = "++printSlave s
  printMaster (StringLit        _ s) = "'" ++ s ++ "'"
  printMaster (Unit _ s)          = "unit = "++printSlave s
  printMaster (Delimiter _)       = "/"



showElseIf i (e,f) = (ind i)++"else if ("++printSlave e++") then\n"++(ind (i+1))++printSlave f++"\n"

showForall [] = "error"
showForall ((s,e,e',NullExpr _ _):[]) = s++"="++printSlave e++":"++printSlave e'
showForall ((s,e,e',e''):[]) = s++"="++printSlave e++":"++printSlave e'++"; "++printSlave e''
showForall ((s,e,e',NullExpr _ _):is) = s++"="++printSlave e++":"++printSlave e'++", "++showForall is
showForall ((s,e,e',e''):is) = s++"="++printSlave e++":"++printSlave e'++"; "++printSlave e''++", "++showForall is

showUse :: Uses p -> String
showUse (UseNil _) = ""
showUse (Use _ (n, []) us _) = ((ind 1)++"use "++n++"\n") ++ (showUse us)
showUse (Use _ (n, renames) us _) = ((ind 1)++"use "++n++", " ++ 
                                     (concat $ intersperse ", " (map (\(a, b) -> a ++ " => " ++ b) renames)) ++
                                   "\n") ++ (showUse us)


isEmptyArg (Arg _ as _) = and (isEmptyArgName as)
isEmptyArgName (ASeq _ a a') = isEmptyArgName a ++ isEmptyArgName a'
isEmptyArgName (ArgName _ a) = [False]
isEmptyArgName (NullArg _)   = [True]

paren :: String -> String
paren s = "(" ++ s ++ ")"

checkPrec :: BinOp p -> BinOp p -> (a -> a) -> a -> a
checkPrec pop cop f s = if opPrec pop >= opPrec cop then f s else s

opPrec :: BinOp p -> Int
opPrec (Or    _) = 0
opPrec (And   _) = 1
opPrec (RelEQ _) = 2
opPrec (RelNE _) = 2
opPrec (RelLT _) = 2
opPrec (RelLE _) = 2 
opPrec (RelGT _) = 2
opPrec (RelGE _) = 2
opPrec (Concat _) = 3
opPrec (Plus  _) = 4
opPrec (Minus _) = 4
opPrec (Mul   _) = 5
opPrec (Div   _) = 5
opPrec (Power _) = 6

class Indentor t where
    indR :: t -> Int -> String

-- Default indenting for code straight out of the parser
instance Indentor (p ()) where
    indR t i = ind i

instance (Indentor (Fortran p), 
          PrintSlave (VarName p) v,
          PrintSlave (Expr p) v,
          PrintSlave (UnaryOp p) v,
          PrintSlave (BinOp p) v, 
          PrintSlave (ArgList p) v,
          PrintIndSlave (Fortran p) v,
          PrintSlave (DataForm p) v, 
          PrintSlave (Fortran p) v, PrintSlave (Spec p) v, PPVersion v) => PrintIndMaster (Fortran p) v where

    printIndMaster i t@(Assg _ _ v e)            = (indR t i)++printSlave v++" = "++printSlave e
    printIndMaster i t@(DoWhile _ _ e f)         = (indR t i)++"do while (" ++ printSlave e ++ ")\n" ++ 
                                                 printIndSlave (i+1) f ++ "\n" ++ (indR t i) ++ "end do"
    printIndMaster i t@(For _ _  (VarName _ "") e e' e'' f)   = (indR t i)++"do \n"++
                                         (printIndSlave (i+1) f)++"\n"++(indR t i)++"end do"
    printIndMaster i t@(For _ _  v e e' e'' f)   = (indR t i)++"do"++" "++printSlave v++" = "++printSlave e++", "++
                                         printSlave e'++", "++printSlave e''++"\n"++
                                         (printIndSlave (i+1) f)++"\n"++(indR t i)++"end do"
    printIndMaster i t@(FSeq _ _  f f')              = printIndSlave i f++"\n"++printIndSlave i f'
    printIndMaster i t@(If _ _  e f [] Nothing)      = (indR t i)++"if ("++printSlave e++") then\n"
                                         ++(printIndSlave (i+1) f)++"\n"
                                         ++(indR t i)++"end if"
    printIndMaster i t@(If _ _  e f [] (Just f'))    = (indR t i)++"if ("++printSlave e++") then\n"
                                         ++(printIndSlave (i+1) f)++"\n"
                                         ++(indR t i)++"else\n"
                                         ++(printIndSlave (i+1) f')++"\n"
                                         ++(indR t i)++"end if"
    printIndMaster i t@(If _ _  e f elsif Nothing)    = (indR t i)++"if ("++printSlave e++") then\n"
                                          ++(printIndSlave (i+1) f)++"\n"
                                          ++concat (map (showElseIf i) elsif)
                                          ++(indR t i)++"end if"
    printIndMaster i t@(If _ _  e f elsif (Just f')) = (indR t i)++"if ("++printSlave e++") then\n"
                                          ++(printIndSlave (i+1) f)++"\n"
                                          ++concat (map (showElseIf i) elsif)
                                          ++(indR t i)++"else\n"
                                          ++(printIndSlave (i+1) f')++"\n"
                                          ++(indR t i)++"end if"
    printIndMaster i t@(Allocate _ _  a (NullExpr _ _))    = (indR t i)++"allocate (" ++ printSlave a ++ ")"
    printIndMaster i t@(Allocate _ _  a s)              = (indR t i)++"allocate ("++ printSlave a ++ ", STAT = "++printSlave s++ ")"
    printIndMaster i t@(Backspace _ _  ss)               = (indR t i)++"backspace "++asTuple printSlave ss++"\n"
    printIndMaster i t@(Call  _ _ sub al)                = indR t i++"call "++printSlave sub++printSlave al
    printIndMaster i t@(Open  _ _ s)                     = (indR t i)++"open "++asTuple printSlave s++"\n"

    printIndMaster i t@(Close  _ _ ss)                   = (indR t i)++"close "++asTuple printSlave ss++"\n"
    printIndMaster i t@(Continue _ _)                   = (indR t i)++"continue"++"\n"
    printIndMaster i t@(Cycle _ _ s)                    = (indR t i)++"cycle "++printSlave s++"\n"
    printIndMaster i t@(DataStmt _ _ d)                 = (indR t i)++(printSlave d)++"\n"
    printIndMaster i t@(Deallocate _ _ es e)            = (indR t i)++"deallocate "++asTuple printSlave es++printSlave e++"\n"
    printIndMaster i t@(Endfile _ _ ss)                 = (indR t i)++"endfile "++asTuple printSlave ss++"\n"
    printIndMaster i t@(Exit _ _ s)                     = (indR t i)++"exit "++printSlave s
    printIndMaster i t@(Format      _  _ es)            = (indR t i)++"format " ++ (asTuple printSlave es)
    printIndMaster i t@(Forall _ _ (is, (NullExpr _ _)) f)    = (indR t i)++"forall ("++showForall is++") "++printSlave f
    printIndMaster i t@(Forall _ _ (is,e)            f) = (indR t i)++"forall ("++showForall is++","++printSlave e++") "++printSlave f
    printIndMaster i t@(Goto _ _ s)                     = (indR t i)++"goto "++printSlave s
    printIndMaster i t@(Nullify _ _ es)                 = (indR t i)++"nullify "++asTuple printSlave es++"\n"
    printIndMaster i t@(Inquire _ _ ss es)              = (indR t i)++"inquire "++asTuple printSlave ss++" "++(concat (intersperse "," (map printSlave es)))++"\n"
    printIndMaster i t@(Pause _ _ s)                  = (indR t i)++"pause "++ show s ++ "\n"
    printIndMaster i t@(Rewind _ _  ss)                  = (indR t i)++"rewind "++asTuple printSlave ss++"\n"
    printIndMaster i t@(Stop _ _ e)                     = (indR t i)++"stop "++printSlave e++"\n"
    printIndMaster i t@(Where _ _ e f Nothing)          = (indR t i)++"where ("++printSlave e++") "++printSlave f
    printIndMaster i t@(Where _ _ e f (Just f'))        = (indR t i)++"where ("++printSlave e++") "++(printIndSlave (i + 1) f)++"\n"++(indR t i)++"elsewhere\n" ++ (indR t i) ++ (printIndSlave (i + 1) f') ++ "\n" ++ (indR t i) ++ "end where"
    printIndMaster i t@(Write _ _ ss es)                = (indR t i)++"write "++asTuple printSlave ss++" "++(concat (intersperse "," (map printSlave es)))++"\n"
    printIndMaster i t@(PointerAssg _ _ e e')           = (indR t i)++printSlave e++" => "++printSlave e'++"\n"
    printIndMaster i t@(Return _ _ e)                   = (indR t i)++"return "++printSlave e++"\n"
    printIndMaster i t@(Label _ _ s f)                  = s++" "++printSlave f
    printIndMaster i t@(Print _ _ e [])                 = (indR t i)++("print ")++printSlave e++("\n")
    printIndMaster i t@(Print _ _ e es)                 = (indR t i)++("print ")++printSlave e++", "++(concat (intersperse "," (map printSlave es)))++("\n")
    printIndMaster i t@(ReadS _ _ ss es)                = (indR t i)++("read ")++(asTuple printSlave ss)++" "++(concat (intersperse "," (map printSlave es)))++("\n")
    printIndMaster i t@(NullStmt _ _)		       = ""

-- infix 7 $+
-- infix 7 $-
-- infix 8 $*
-- infix 9 $/

----------------------------------------------------------------------
-- PRINT UTILITIES
----------------------------------------------------------------------

showNQ :: Show a => a -> String
showNQ = filter ('"'/=) . show

-- Indenting

ind = indent 3 
indent i l = take (i*l) (repeat ' ')


printList sep f xs = sep!!0++concat (intersperse (sep!!1) (map f xs))++sep!!2

asTuple = printList ["(",",",")"]
asSeq   = printList ["",",",""]
asList  = printList ["[",",","]"]
asSet   = printList ["{",",","}"]
asLisp  = printList ["("," ",")"]
asPlain f xs = if null xs then "" else printList [" "," ",""] f xs
asPlain' f xs = if null xs then "" else printList [""," ",""] f xs
asCases l = printList ["\n"++ind++"   ","\n"++ind++" | ",""] where ind = indent 4 l
asDefs n = printList ["\n"++n,"\n"++n,"\n"]
asParagraphs = printList ["\n","\n\n","\n"]

-- Auxiliary functions
-- 
optTuple :: (?variant :: v, PPVersion v, PrintSlave (UnaryOp p) v, PrintMaster (Expr p) v) => [Expr p] -> String
optTuple [] = ""
optTuple xs = asTuple printMaster xs
-- *optTuple xs = ""
-- indent and showInd enable indented printing
-- 

showUnits :: (PPVersion v, ?variant :: v, PrintMaster (Fraction p) v) => [(MeasureUnit, Fraction p)] -> String
showUnits units
  | null units = "1"
  | otherwise = printList [""," ",""] (\(unit, f) -> unit++printMaster f) units


printMasterList :: (PPVersion v, ?variant :: v, PrintMaster a v) => [a] -> String
printMasterList  = concat . map (", "++) . map (printMaster)



showBounds :: (PPVersion v, ?variant :: v, PrintMaster (Expr p) v) => (Expr p,Expr p) -> String
showBounds (NullExpr _ _, NullExpr _ _) = ":"
showBounds (NullExpr _ _, e) = printMaster e
showBounds (e1,e2) = printMaster e1++":"++printMaster e2

showRanges :: (PPVersion v, ?variant :: v, PrintMaster (Expr p) v) => [(Expr p, Expr p)] -> String
showRanges = asSeq showBounds

showPartRefList :: (PPVersion v, ?variant :: v, PrintSlave (VarName p) v, 
                    PrintSlave (UnaryOp p) v, PrintMaster (Expr p) v) => [(VarName p,[Expr p])] -> String
showPartRefList []           = ""
showPartRefList ((v,es):[]) = printSlave v ++ optTuple es 
showPartRefList ((v,es):xs) = printSlave v ++ optTuple es ++ "%" ++ showPartRefList xs
