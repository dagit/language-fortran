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
--    The 'Tagged' type class provides the function 'tag :: d a -> a' to 
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

data UseBlock p = UseBlock (Uses p) SrcLoc deriving (Show, Functor, Typeable, Data, Eq)

data Uses p  = Use p (String, Renames) (Uses p) p  -- (second 'p' let's you annotate the 'cons' part of the cell)
                | UseNil p deriving (Show, Functor, Typeable, Data, Eq)

             --       use's     implicit  decls  stmts
data Block    p = Block p  (UseBlock p) (Implicit p) SrcSpan (Decl p) (Fortran p)
                deriving (Show, Functor, Typeable, Data, Eq)

data Decl     p = Decl           p SrcSpan [(Expr p, Expr p, Maybe Int)] (Type p)      -- declaration stmt
                | Namelist       p [(Expr p, [Expr p])]                     -- namelist declaration
                | DataDecl       p (DataForm p)
                | Equivalence    p SrcSpan [(Expr p)]
                | AttrStmt       p (Attr p) [(Expr p, Expr p, Maybe Int)] 
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
                | Dimension p [(Expr p, Expr p)]
              deriving (Show, Functor, Typeable, Data, Eq)
			  
data GSpec   p = GName p (Expr p) | GOper p (BinOp p) | GAssg p
                 deriving (Show, Functor, Typeable, Data, Eq)
			  
data InterfaceSpec p = FunctionInterface   p (SubName p) (Arg p) (Uses p) (Implicit p) (Decl p)
                     | SubroutineInterface p (SubName p) (Arg p) (Uses p) (Implicit p) (Decl p)
                     | ModuleProcedure     p [(SubName p)]
                       deriving (Show, Functor, Typeable, Data, Eq)
		
data DataForm p = Data p [(Expr p, Expr p)] deriving (Show, Functor, Typeable, Data, Eq) -- data declaration
		   
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
                | DataStmt p SrcSpan (DataForm p)
                | Deallocate p SrcSpan [(Expr p)] (Expr p)
                | Endfile p SrcSpan [Spec p]
                | Exit p SrcSpan String
                | Format p [Spec p]
                | Forall p SrcSpan ([(String,(Expr p),(Expr p),(Expr p))],(Expr p)) (Fortran p)
                | Goto p SrcSpan String
                | Nullify p SrcSpan [(Expr p)]
                | Inquire p SrcSpan [Spec p] [(Expr p)]
                | Pause p SrcSpan String
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
             | Var p SrcSpan  [(VarName p, [Expr p])]
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
              | Floating   p (Expr p) (Expr p)
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
              | StringLit     p String 
              | Unit       p (Expr p)
              | WriteSp    p (Expr p)
              | Delimiter  p 
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

-- Extract the tag 

class Tagged d where
    tag :: d a -> a 

instance Tagged Attr where
    tag (Parameter x)   = x
    tag (Allocatable x) = x
    tag (External    x) = x
    tag (Intent x    _) = x
    tag (Intrinsic x)   = x
    tag (Optional x)    = x
    tag (Pointer x)     = x
    tag (Save x)        = x
    tag (Target x)      = x
    tag (Volatile x)    = x
    tag (Public x)      = x
    tag (Private x)     = x
    tag (Sequence x)    = x

instance Tagged BaseType where
    tag (Integer x)    = x
    tag (Real x)       = x
    tag (Character x)   = x
    tag (SomeType x)   = x
    tag (DerivedType x _) = x
    tag (Recursive x)  = x
    tag (Pure x)       = x
    tag (Elemental x)  = x
    tag (Logical x)    = x
    tag (Complex x)    = x

instance Tagged SubName where
    tag (SubName x _)  = x
    tag (NullSubName x) = x

instance Tagged VarName where
    tag (VarName x _) = x

instance Tagged Implicit where
    tag (ImplicitNone x) = x
    tag (ImplicitNull x) = x

instance Tagged Uses where 
    tag (Use x _ _ _) = x
    tag (UseNil x) = x

instance Tagged Arg where
    tag (Arg x _ _) = x

instance Tagged ArgList where 
    tag (ArgList x _) = x

instance Tagged ArgName where
    tag (ASeq x _ _) = x
    tag (NullArg x) = x
    tag (ArgName x _) = x

instance Tagged ProgUnit where
    tag (Main x sp _ _ _ _)      = x
    tag (Sub x sp _ _ _ _)       = x
    tag (Function x sp _ _ _ _)  = x
    tag (Module x sp _ _ _ _ _ ) = x
    tag (BlockData x sp _ _ _ _) = x
    tag (PSeq x sp _ _)          = x
    tag (Prog x sp _)            = x
    tag (NullProg x sp)          = x

instance Tagged Decl where
    tag (Decl x _ _ _)          = x
    tag (Namelist x _)        = x
    tag (DataDecl x _)        = x
    tag (AccessStmt x _ _)    = x
    tag (ExternalStmt x _)    = x
    tag (Interface x _ _)     = x
    tag (Common x _ _ _)        = x
    tag (Equivalence x sp _)    = x
    tag (DerivedTypeDef x sp _ _ _ _) = x
    tag (Include x _)         = x
    tag (DSeq x _ _)          = x
    tag (TextDecl x _)        = x
    tag (NullDecl x _)        = x

instance Tagged DataForm where
    tag (Data x _)         = x

instance Tagged Fortran where
    tag (Assg x s e1 e2)        = x
    tag (For x s v e1 e2 e3 fs) = x
    tag (FSeq x sp f1 f2)       = x
    tag (If x sp e f1 fes f3)   = x
    tag (Allocate x sp e1 e2)   = x
    tag (Backspace x sp _)      = x
    tag (Call x sp e as)        = x
    tag (DataStmt x sp _)       = x
    tag (Open x sp s)           = x
    tag (Close x sp s)          = x 
    tag (Continue x sp)         = x
    tag (Cycle x sp s)          = x
    tag (Deallocate x sp es e)  = x
    tag (Endfile x sp s)        = x
    tag (Exit x sp s)           = x
    tag (Forall x sp es f)      = x
    tag (Goto x sp s)           = x
    tag (Nullify x sp e)        = x
    tag (Inquire x sp s e)      = x
    tag (Rewind x sp s)         = x 
    tag (Stop x sp e)           = x
    tag (Where x sp e f)        = x 
    tag (Write x sp s e)        = x
    tag (PointerAssg x sp e1 e2) = x
    tag (Return x sp e)         = x
    tag (Label x sp s f)        = x
    tag (Print x sp e es)       = x
    tag (ReadS x sp s e)        = x
    tag (TextStmt x sp s)       = x
    tag (NullStmt x sp)         = x

instance Tagged Expr where
   tag (Con x sp _)        = x
   tag (ConL x sp _ _)     = x
   tag (ConS x sp _)       = x
   tag (Var x sp _ )       = x
   tag (Bin x sp _ _ _)    = x
   tag (Unary x sp _ _)    = x
   tag (CallExpr x sp _ _) = x
   tag (NullExpr x _)      = x
   tag (Null x _)          = x
   tag (ESeq x sp _ _)     = x
   tag (Bound x sp _ _)    = x
   tag (Sqrt x sp _)       = x
   tag (ArrayCon x sp _)   = x
   tag (AssgExpr x sp _ _) = x

instance Tagged GSpec where
   tag (GName x _) = x
   tag (GOper x _) = x
   tag (GAssg x)   = x