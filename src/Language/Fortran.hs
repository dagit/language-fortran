-- 
-- Fortran.hs  - 
-- Based on FortranP.hs from Parameterized Fortran by Martin Erwig.
--

{-# LANGUAGE DeriveFunctor, DeriveDataTypeable #-}

module Language.Fortran where

import Data.Generics -- All AST nodes are members of 'Data' and 'Typeable' so that
                     -- data type generic programming can be done with the AST

import Data.Maybe
import Data.List


import Language.Haskell.Syntax (SrcLoc)

-----------------------------------------------------------------------------------
-- Language definition for Fortran (covers a lot of standards, but still incomplete)
--
--  The AST is parameterised by type variable p which allows all nodes of the AST
--  to be annotated. The default annotation is (). This is useful for analysis. 
--    The 'Anntotation' type class provides the function 'annotation :: d a -> a' to 
--    extract these annotations.

--  Furthermore, many nodes of the tree have a 'SrcSpan' which is the start and end
--  locations of the syntax in the source file (including whitespace etc.)
--  This is useful for error reporting and refactoring. 
--    The 'Span' type class provides the function 'srcSpan :: d a -> SrcSpan' which
--    which extracts the span (where possible)

-----------------------------------------------------------------------------------



type SrcSpan = (SrcLoc, SrcLoc)

type Variable = String

type ProgName = String               -- Fortran program names

data SubName p  = SubName p String   -- Fortran subroutine names
                 | NullSubName p
                 deriving (Show, Functor, Typeable, Data, Eq)
 
data VarName  p = VarName p Variable 
                  deriving (Show, Functor, Typeable, Data, Eq, Read)

data ArgName  p = ArgName p String
                | ASeq p (ArgName p) (ArgName p)
                | NullArg p
                 deriving (Show, Functor, Typeable, Data, Eq)

-- Syntax defintions
--

data Arg      p = Arg p (ArgName p) SrcSpan -- the src span denotes the end of the arg list before ')'
                  deriving (Show, Functor, Typeable, Data, Eq)

data ArgList  p = ArgList p (Expr p)
                  deriving (Show, Functor, Typeable, Data, Eq)

type Program p = [ProgUnit p]

               -- Prog type   (type of result)   name      args  body    use's  
data ProgUnit  p = Main      p SrcSpan                      (SubName p)  (Arg p)  (Block p) [ProgUnit p]
                | Sub        p SrcSpan (Maybe (BaseType p)) (SubName p)  (Arg p)  (Block p)
                | Function   p SrcSpan (Maybe (BaseType p)) (SubName p)  (Arg p)  (Block p)
                | Module     p SrcSpan                      (SubName p)  (Uses p) (Implicit p) (Decl p) [ProgUnit p]
                | BlockData  p SrcSpan                      (SubName p)  (Uses p) (Implicit p) (Decl p)
                | PSeq       p SrcSpan (ProgUnit p) (ProgUnit p)   -- sequence of programs
                | Prog       p SrcSpan (ProgUnit p)                -- useful for {#p: #q : program ... }
                | NullProg   p SrcSpan                             -- null
                deriving (Show, Functor, Typeable, Data, Eq)

data Implicit p = ImplicitNone p | ImplicitNull p 
                -- implicit none or no implicit 
                deriving (Show, Functor, Typeable, Data, Eq)

type Renames = [(Variable, Variable)] -- renames for "use"s 

data Uses p     = Use p (String, Renames) (Uses p) p  -- (second 'p' let's you annotate the 'cons' part of the cell)
                | UseNil p deriving (Show, Functor, Typeable, Data, Eq)

             --       use's     implicit  decls  stmts
data Block    p = Block p  (Uses p) (Implicit p) SrcSpan (Decl p) (Fortran p)
                deriving (Show, Functor, Typeable, Data, Eq)

data Decl     p = Decl           p SrcSpan [(Expr p, Expr p)] (Type p)      -- declaration stmt
                | Namelist       p [(Expr p, [Expr p])]                     -- namelist declaration
                | Data           p [(Expr p, Expr p)]                       -- data declaration
                | Equivalence    p SrcSpan [(Expr p)]
                | AccessStmt     p (Attr p) [GSpec p]                       -- access stmt
                | ExternalStmt   p [String]                                 -- external stmt
                | Interface      p (Maybe (GSpec p)) [InterfaceSpec p]      -- interface declaration
                | Common         p SrcSpan (Maybe String) [Expr p]
                | DerivedTypeDef p SrcSpan (SubName p) [Attr p] [Attr p] [Decl p]  -- derivified
                | Include        p (Expr p)                                -- include stmt
                | DSeq           p (Decl p) (Decl p)                       -- list of decls
                | TextDecl       p String                                  -- cpp switches to carry over
                | NullDecl       p SrcSpan                                 -- null
                  deriving (Show, Functor, Typeable, Data, Eq)

             -- BaseType  dimensions     type        Attributes   kind   len 
data Type     p = BaseType p                    (BaseType p) [Attr p] (Expr p) (Expr p)
                | ArrayT   p [(Expr p, Expr p)] (BaseType p) [Attr p] (Expr p) (Expr p)
                  deriving (Show, Functor, Typeable, Data, Eq)

data BaseType p = Integer p | Real p | Character p | SomeType p | DerivedType p (SubName p)
                | Recursive p | Pure p | Elemental p | Logical p | Complex p
                  deriving (Show, Functor, Typeable, Data, Eq)

data Attr     p = Parameter p
                | Allocatable p
                | External p
                | Intent p (IntentAttr p) 
                | Intrinsic p
                | Optional p
                | Pointer p
                | Save p
                | Target p
                | Volatile p
                | Public p
                | Private p
                | Sequence p
--              | Dimension [(Expr,Expr)] -- in Type: ArrayT
              deriving (Show, Functor, Typeable, Data, Eq)
			  
data GSpec   p = GName p (Expr p) | GOper p (BinOp p) | GAssg p
                 deriving (Show, Functor, Typeable, Data, Eq)
			  
data InterfaceSpec p = FunctionInterface   p (SubName p) (Arg p) (Uses p) (Implicit p) (Decl p)
                     | SubroutineInterface p (SubName p) (Arg p) (Uses p) (Implicit p) (Decl p)
                     | ModuleProcedure     p [(SubName p)]
                       deriving (Show, Functor, Typeable, Data, Eq)
				   
data IntentAttr p = In p
                  | Out p
                  | InOut p
                    deriving (Show, Functor, Typeable, Data, Eq)
				
data Fortran  p = Assg p SrcSpan (Expr p) (Expr p) 
                | For  p SrcSpan (VarName p) (Expr p) (Expr p) (Expr p) (Fortran p)
                | FSeq p SrcSpan (Fortran p) (Fortran p)
                | If   p SrcSpan (Expr p) (Fortran p) [((Expr p),(Fortran p))] (Maybe (Fortran p))
                | Allocate p SrcSpan (Expr p) (Expr p)
                | Backspace p SrcSpan [Spec p]
                | Call p SrcSpan (Expr p) (ArgList p)
                | Open p SrcSpan [Spec p]
                | Close p SrcSpan [Spec p]
                | Continue p SrcSpan 
                | Cycle p SrcSpan String
                | Deallocate p SrcSpan [(Expr p)] (Expr p)
                | Endfile p SrcSpan [Spec p]
                | Exit p SrcSpan String
                | Forall p SrcSpan ([(String,(Expr p),(Expr p),(Expr p))],(Expr p)) (Fortran p)
                | Goto p SrcSpan String
                | Nullify p SrcSpan [(Expr p)]
                | Inquire p SrcSpan [Spec p] [(Expr p)]
                | Rewind p SrcSpan [Spec p]
                | Stop p SrcSpan (Expr p)
                | Where p SrcSpan (Expr p) (Fortran p)
                | Write p SrcSpan [Spec p] [(Expr p)]
                | PointerAssg p SrcSpan  (Expr p) (Expr p)
                | Return p SrcSpan  (Expr p)
                | Label p SrcSpan String (Fortran p)
                | Print p SrcSpan (Expr p) [(Expr p)]
                | ReadS p SrcSpan [Spec p] [(Expr p)]
                | TextStmt p SrcSpan String     -- cpp switches to carry over
                | NullStmt p SrcSpan
                  deriving (Show, Functor, Typeable, Data, Eq)

-- type Bound    = ((Expr p),(Expr p))

data Expr  p = Con p SrcSpan String
             | ConL p SrcSpan Char String
             | ConS p SrcSpan String  -- String representing a constant
             | Var p SrcSpan  [((VarName p),[(Expr p)])]
             | Bin p SrcSpan  (BinOp p) (Expr p) (Expr p)
             | Unary p SrcSpan (UnaryOp p) (Expr p)
             | CallExpr p SrcSpan (Expr p) (ArgList p)
             | NullExpr p SrcSpan
             | Null p SrcSpan 
             | ESeq p SrcSpan (Expr p) (Expr p)
             | Bound p SrcSpan (Expr p) (Expr p)
             | Sqrt p SrcSpan (Expr p)
             | ArrayCon p SrcSpan [(Expr p)]
             | AssgExpr p SrcSpan String (Expr p)
               deriving (Show, Functor, Typeable ,Data, Eq)

data BinOp   p = Plus p
               | Minus p
               | Mul p
               | Div p
               | Or p
               | And p
               | Concat p
               | Power p
               | RelEQ p
               | RelNE p
               | RelLT p
               | RelLE p
               | RelGT p
               | RelGE p
                deriving (Show, Functor, Typeable, Data, Eq)

data UnaryOp  p = UMinus p | Not p
                deriving (Show, Functor,Typeable,Data, Eq)

data Spec     p = Access   p (Expr p)
              | Action     p (Expr p)
              | Advance    p (Expr p)
              | Blank      p (Expr p)
              | Delim      p (Expr p)
              | Direct     p (Expr p)
              | End        p (Expr p)
              | Err        p (Expr p)
              | ExFile     p (Expr p)
              | Exist      p (Expr p)
              | Eor        p (Expr p)
              | File       p (Expr p)  
              | FMT        p (Expr p)
              | Form       p (Expr p)
              | Formatted  p (Expr p)
              | Unformatted  p (Expr p)
              | IOLength   p (Expr p)
              | IOStat     p (Expr p)
              | Name       p (Expr p)
              | Named      p (Expr p)
              | NoSpec     p (Expr p)
              | Number     p (Expr p)
              | NextRec    p (Expr p)
              | NML        p (Expr p)
              | Opened     p (Expr p) 
              | Pad        p (Expr p)
              | Position   p (Expr p)
              | Read       p (Expr p)
              | ReadWrite  p (Expr p)
              | Rec        p (Expr p) 
              | Recl       p (Expr p) 
              | Sequential p (Expr p)
              | Size       p (Expr p)
              | Status     p (Expr p)
              | Unit       p (Expr p)
              | WriteSp    p (Expr p)
                deriving (Show, Functor,Typeable,Data, Eq)

-- Extract span information from the source tree

class Span t where
    srcSpan :: t -> (SrcLoc, SrcLoc)

instance Span (Block a) where
    srcSpan (Block _ _ _ sp _ _) = sp

instance Span (Decl a) where
    srcSpan (Decl _ sp _ _)               = sp
    srcSpan (NullDecl _ sp)               = sp
    srcSpan (Common _ sp _ _)             = sp
    srcSpan (Equivalence x sp _)          = sp
    srcSpan (DerivedTypeDef x sp _ _ _ _) = sp
    srcSpan _ = error "No span for non common/equiv/type/ null declarations"

instance Span (ProgUnit a) where
    srcSpan (Main x sp _ _ _ _)      = sp
    srcSpan (Sub x sp _ _ _ _)       = sp
    srcSpan (Function x sp _ _ _ _)  = sp
    srcSpan (Module x sp _ _ _ _ _ ) = sp
    srcSpan (BlockData x sp _ _ _ _) = sp
    srcSpan (PSeq x sp _ _)          = sp
    srcSpan (Prog x sp _)            = sp
    srcSpan (NullProg x sp)          = sp

instance Span (Expr a) where
    srcSpan (Con x sp _)        = sp
    srcSpan (ConS x sp _)       = sp
    srcSpan (Var x sp _ )       = sp
    srcSpan (Bin x sp _ _ _)    = sp
    srcSpan (Unary x sp _ _)    = sp
    srcSpan (CallExpr x sp _ _) = sp
    srcSpan (NullExpr x sp)     = sp
    srcSpan (Null x sp)         = sp
    srcSpan (ESeq x sp _ _)     = sp
    srcSpan (Bound x sp _ _)    = sp
    srcSpan (Sqrt x sp _)       = sp
    srcSpan (ArrayCon x sp _)   = sp
    srcSpan (AssgExpr x sp _ _) = sp

instance Span (Fortran a) where
    srcSpan (Assg x sp e1 e2)        = sp
    srcSpan (For x sp v e1 e2 e3 fs) = sp
    srcSpan (FSeq x sp f1 f2)        = sp
    srcSpan (If x sp e f1 fes f3)    = sp
    srcSpan (Allocate x sp e1 e2)    = sp
    srcSpan (Backspace x sp _)       = sp
    srcSpan (Call x sp e as)         = sp
    srcSpan (Open x sp s)            = sp
    srcSpan (Close x sp s)           = sp 
    srcSpan (Continue x sp)          = sp
    srcSpan (Cycle x sp s)           = sp
    srcSpan (Deallocate x sp es e)   = sp
    srcSpan (Endfile x sp s)         = sp
    srcSpan (Exit x sp s)            = sp
    srcSpan (Forall x sp es f)       = sp
    srcSpan (Goto x sp s)            = sp
    srcSpan (Nullify x sp e)         = sp
    srcSpan (Inquire x sp s e)       = sp
    srcSpan (Rewind x sp s)          = sp 
    srcSpan (Stop x sp e)            = sp
    srcSpan (Where x sp e f)         = sp 
    srcSpan (Write x sp s e)         = sp
    srcSpan (PointerAssg x sp e1 e2) = sp
    srcSpan (Return x sp e)          = sp
    srcSpan (Label x sp s f)         = sp
    srcSpan (Print x sp e es)        = sp
    srcSpan (ReadS x sp s e)         = sp
    srcSpan (TextStmt x sp s)        = sp
    srcSpan (NullStmt x sp)          = sp

-- Extract the annotation 

class Annotation d where
    annotation :: d a -> a 

instance Annotation Attr where
    annotation (Parameter x)   = x
    annotation (Allocatable x) = x
    annotation (External    x) = x
    annotation (Intent x    _) = x
    annotation (Intrinsic x)   = x
    annotation (Optional x)    = x
    annotation (Pointer x)     = x
    annotation (Save x)        = x
    annotation (Target x)      = x
    annotation (Volatile x)    = x
    annotation (Public x)      = x
    annotation (Private x)     = x
    annotation (Sequence x)    = x

instance Annotation BaseType where
    annotation (Integer x)    = x
    annotation (Real x)       = x
    annotation (Character x)   = x
    annotation (SomeType x)   = x
    annotation (DerivedType x _) = x
    annotation (Recursive x)  = x
    annotation (Pure x)       = x
    annotation (Elemental x)  = x
    annotation (Logical x)    = x
    annotation (Complex x)    = x

instance Annotation SubName where
    annotation (SubName x _)  = x
    annotation (NullSubName x) = x

instance Annotation VarName where
    annotation (VarName x _) = x

instance Annotation Implicit where
    annotation (ImplicitNone x) = x
    annotation (ImplicitNull x) = x

instance Annotation Uses where 
    annotation (Use x _ _ _) = x
    annotation (UseNil x) = x

instance Annotation Arg where
    annotation (Arg x _ _) = x

instance Annotation ArgList where 
    annotation (ArgList x _) = x

instance Annotation ArgName where
    annotation (ASeq x _ _) = x
    annotation (NullArg x) = x
    annotation (ArgName x _) = x

instance Annotation ProgUnit where
    annotation (Main x sp _ _ _ _)      = x
    annotation (Sub x sp _ _ _ _)       = x
    annotation (Function x sp _ _ _ _)  = x
    annotation (Module x sp _ _ _ _ _ ) = x
    annotation (BlockData x sp _ _ _ _) = x
    annotation (PSeq x sp _ _)          = x
    annotation (Prog x sp _)            = x
    annotation (NullProg x sp)          = x

instance Annotation Decl where
    annotation (Decl x _ _ _)          = x
    annotation (Namelist x _)        = x
    annotation (Data x _)            = x
    annotation (AccessStmt x _ _)    = x
    annotation (ExternalStmt x _)    = x
    annotation (Interface x _ _)     = x
    annotation (Common x _ _ _)        = x
    annotation (Equivalence x sp _)    = x
    annotation (DerivedTypeDef x sp _ _ _ _) = x
    annotation (Include x _)         = x
    annotation (DSeq x _ _)          = x
    annotation (TextDecl x _)        = x
    annotation (NullDecl x _)        = x

instance Annotation Fortran where
    annotation (Assg x s e1 e2)        = x
    annotation (For x s v e1 e2 e3 fs) = x
    annotation (FSeq x sp f1 f2)       = x
    annotation (If x sp e f1 fes f3)   = x
    annotation (Allocate x sp e1 e2)   = x
    annotation (Backspace x sp _)      = x
    annotation (Call x sp e as)        = x
    annotation (Open x sp s)           = x
    annotation (Close x sp s)          = x 
    annotation (Continue x sp)         = x
    annotation (Cycle x sp s)          = x
    annotation (Deallocate x sp es e)  = x
    annotation (Endfile x sp s)        = x
    annotation (Exit x sp s)           = x
    annotation (Forall x sp es f)      = x
    annotation (Goto x sp s)           = x
    annotation (Nullify x sp e)        = x
    annotation (Inquire x sp s e)      = x
    annotation (Rewind x sp s)         = x 
    annotation (Stop x sp e)           = x
    annotation (Where x sp e f)        = x 
    annotation (Write x sp s e)        = x
    annotation (PointerAssg x sp e1 e2) = x
    annotation (Return x sp e)         = x
    annotation (Label x sp s f)        = x
    annotation (Print x sp e es)       = x
    annotation (ReadS x sp s e)        = x
    annotation (TextStmt x sp s)       = x
    annotation (NullStmt x sp)         = x

instance Annotation Expr where
   annotation (Con x sp _)        = x
   annotation (ConL x sp _ _)     = x
   annotation (ConS x sp _)       = x
   annotation (Var x sp _ )       = x
   annotation (Bin x sp _ _ _)    = x
   annotation (Unary x sp _ _)    = x
   annotation (CallExpr x sp _ _) = x
   annotation (NullExpr x _)      = x
   annotation (Null x _)          = x
   annotation (ESeq x sp _ _)     = x
   annotation (Bound x sp _ _)    = x
   annotation (Sqrt x sp _)       = x
   annotation (ArrayCon x sp _)   = x
   annotation (AssgExpr x sp _ _) = x

instance Annotation GSpec where
   annotation (GName x _) = x
   annotation (GOper x _) = x
   annotation (GAssg x)   = x