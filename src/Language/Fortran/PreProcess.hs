{-|

The following provides a string → string preprocessor for Fortran
programs that deals with label-delimited @do@-@continue@ blocks of
FORTRAN 77 era. With a traditional LR(1) parser, these are not easily
(or not at all) parsable. Consider the valid FORTRAN 77 code:

>     do j = 1,5
>       do 17 i=1,10
>         print *,i
>       17 continue
>     end do

Here the \'continue\' acts as an \'end do\' (not as a usual
\'continue\' statement) because it is labelled with the same label
\'17\' as the \'do\' statement which starts the block. Parsing this
requires arbitrary look-ahead (e.g., LR(infinity)) which is provided
by the following parsec parser, but not by the \'happy\' parser
generator.

This pre processor is currently quite heavy handed. It replaces
\'continue\' in the above program with \'end do\'. E.g., the above
program is transformed to:

>     do j = 1,5
>       do 17 i=1,10
>         print *,i
>       17 end do
>     end do
-}
module Language.Fortran.PreProcess where

import Text.ParserCombinators.Parsec hiding (spaces)
import Text.ParserCombinators.Parsec.Expr
import qualified Text.ParserCombinators.Parsec.Token as Token
import Text.ParserCombinators.Parsec.Language
import System.Environment

import Debug.Trace

num = many1 digit
small = lower <|> char '_'
idchar = small <|> upper <|> digit 
ident  =  do{ c <- small <|> upper ; cs <- many idchar; return (c:cs) }
spaces = many space

manyTillEnd p end =
    scan where scan  = (try end) <|> do { x <- p; xs <- scan; return (x:xs) }
   
pre_parser labels = manyTillEnd anyChar 
                      (try $ if (labels == []) then (try $ end_or_start_do labels) <|> (eof >> return "")
                                               else  end_or_start_do labels)                  

end_or_start_do labels = (try $ doBlock labels) <|> (end_do labels)

doBlock labels = 
          do doStr <- string "do" <|> string "DO"
             updateState (+1)
             sp    <- spaces
             label <- (try numberedBlock) <|> (do { loop <- loop_control; return (Nothing, loop) })
             p     <- pre_parser $ (fst label) : labels
             return $ doStr ++ sp ++ snd label ++ p 


end_do labels = do label' <- optionMaybe (do {space; n <- num; space; return n})
                   sp     <- spaces
                   lookAhead (end_do_marker <|> continue)
                   ender <- 
                     case (labels, label') of 
                      ([], _)               -> do { ender <- end_do_marker; return $ sp ++ ender }
                      (Nothing:_, _)        -> do { ender <- end_do_marker; return $ sp ++ ender }
                      ((Just n):_, Nothing) -> do { ender <- end_do_marker; return $ sp ++ ender }
                      ((Just n):_, Just m)  -> if (n==m) then do ender <- end_do_marker <|> continue
                                                                 return $ " " ++ m ++ " " ++ sp ++ ender

                                                         else -- Labels don't match!
                                                              -- If the label doesn't appear anywhere in the label stack, 
                                                              --   then this is allowed (e.g. extra 'continue' points)
                                                              if (not ((Just m) `elem` labels)) then
                                                                  do ender <- end_do_marker <|> continue_non_replace
                                                                     return $ " " ++ m ++ " " ++ sp ++ ender
                                                              else
                                                              -- otherwise, we consider the do loops to be not properly bracketted
                                                               error $ "Ill formed do blocks, labels do not match: " ++ n ++ " and " ++ m ++ 
                                                                         " - with label stack " ++ (show labels)
                   level <- getState
                   updateState (\x -> x-1) -- "Level " ++ show level) `trace` (
                   p <- pre_parser (if labels == [] then [] else tail labels)
                   return $ ender ++ p

continue_non_replace = string "continue" <|> string "CONTINUE"

continue = do string "continue" <|> string "CONTINUE"
              return "end do  " -- replaces continue with 'end do', this is the goal!
                      
end_do_marker = do endStr <- string "end" <|> string "END"
                   sp <- spaces
                   doStr <- string "do" <|> string "DO"
                   return $ endStr ++ sp ++ doStr

numberedBlock = do label <- num
                   space 
                   sp1   <- spaces
                   comma <- optionMaybe (string ",")
                   sp2   <- spaces
                   loop  <- loop_control
                   return $ (Just label, label ++ " " ++ sp1 ++ (maybe "" id comma) ++ sp2 ++ loop)

newline' = 
    (try $ do { c <- char '\r'; 
                n <- newline;
                return [c,n] })
       <|> do { n <- newline; 
                return [n] }

loop_control = do var   <- ident
                  sp1   <- spaces
                  char '='
                  sp2   <- spaces
                  lower <- num <|> ident
                  sp3   <- spaces
                  char ','
                  sp4   <- spaces
                  upper <- num <|> ident
                  rest  <- manyTillEnd anyChar (try newline')
                  return $ var ++ sp1 ++ "=" ++ sp2 ++ lower ++ sp3 ++ "," ++ sp4 ++ upper ++ rest 
                  
parseExpr :: String -> String -> String
parseExpr file input =
    case (runParser p (0::Int) "" input) of
      Left err  -> fail $ show err
      Right x   -> x
  where
    p = do  pos <- getPosition
            setPosition $ (flip setSourceName) file $
                          (flip setSourceLine) 1 $
                          (flip setSourceColumn) 1 $ pos
            x <- pre_parser []
            return x

pre_process input = parseExpr "" input
             
go filename = do args <- getArgs
                 srcfile <- readFile filename
                 return $ parseExpr filename srcfile
