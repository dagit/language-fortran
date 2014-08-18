{-

The following provides a string -> string preprocessor for Fortran programs that deals with
label-delimited 'do'-'continue' blocks of FORTRAN 77 era. With a traditional LR(1) parser, these are
not easily (or not at all) parsable. Consider the valid FORTRAN 77 code:

     do j = 1,5
       do 17 i=1,10
         print *,i      
       17 continue
     end do 

Here the 'continue' acts as an 'end do' (not as a usual 'continue' statement) because it is labelled with the same
label '17' as the 'do' statement which starts the block. Parsing this requires arbitrary look-ahead (e.g., LR(infinity))
which is provided by the following parsec parser, but not by the 'happy' parser generator. 

This pre processor is currently quite heavy handed. It replaces 'continue' in the above program with 'end do'. E.g., 
the above program is transformed to:

     do j = 1,5
       do 17 i=1,10
         print *,i      
       17 end do
     end do 

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
ident  =  do{ c <- small ; cs <- many idchar; return (c:cs) }
spaces = many space

manyTillEnd p end =
    scan where scan  = do{ end }
                          <|>
                       do{ x <- p; xs <- scan; return (x:xs) }
   
pre_parser label = manyTillEnd anyChar 
                      (try $ if (label == Nothing) then (end_or_start_do label) <|> (eof >> return "")
                                                   else  end_or_start_do label)                  

end_or_start_do label = (try doBlock) <|> (end_do label)

doBlock = do string "do"
             updateState (+1)
             sp <- spaces
             label <- (try numberedBlock) <|> (do { loop <- loop_control; return (Nothing, loop) })
             p <- pre_parser $ fst label
             return  $ "do" ++ sp ++ snd label ++ p 


end_do label = do label' <- optionMaybe (do {space; n <- num; space; return n})
                  sp     <- spaces
                  lookAhead (end_do_marker <|> continue)
                  ender <- 
                    case (label, label') of 
                     (Nothing, _)      -> do { ender <- end_do_marker; return $ sp ++ ender }
                     (Just n, Nothing) -> do { ender <- end_do_marker; return $ sp ++ ender }
                     (Just n, Just m)  -> if (n==m) then do ender <- end_do_marker <|> continue
                                                            return $ " " ++ m ++ " " ++ sp ++ ender

                                                    else error $ "Ill formed do blocks, labels do not match: " ++ n ++ " and " ++ m
                  level <- getState
                  ("Level " ++ show level) `trace` (updateState (\x -> x-1))
                  p <- pre_parser Nothing
                  return $ ender ++ p

continue = do string "continue"
              return "end do  " -- replaces continue with 'end do', this is the goal!
                      
end_do_marker = do string "end"
                   sp <- spaces
                   string "do"
                   return $ "end" ++ sp ++ "do"

numberedBlock = do label <- num
                   space 
                   sp1   <- spaces
                   comma <- optionMaybe (string ",")
                   sp2   <- spaces
                   loop  <- loop_control
                   return $ (Just label, label ++ " " ++ sp1 ++ (maybe "" id comma) ++ sp2 ++ loop)

loop_control = do var   <- ident
                  sp1   <- spaces
                  char '='
                  sp2   <- spaces
                  lower <- num
                  sp3   <- spaces
                  char ','
                  sp4   <- spaces
                  upper <- num
                  newline
                  return $ var ++ sp1 ++ "=" ++ sp2 ++ lower ++ sp3 ++ "," ++ sp4 ++ upper ++ "\n"

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
            x <- pre_parser Nothing
            return x

pre_process input = parseExpr "" input
             
go filename = do args <- getArgs
                 srcfile <- readFile filename
                 return $ parseExpr filename srcfile

main = do args <- getArgs
          go (head args)