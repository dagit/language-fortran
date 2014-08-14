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
   
parser label = manyTillEnd anyChar (try $ 
                                  if (label == Nothing) then 
                                   (end_or_start_do label) <|> (eof >> return "")
                                 else 
                                    end_or_start_do label)                  

end_or_start_do label = (try doBlock) <|> (end_do label)

doBlock = do string "do"
             updateState (+1)
             sp <- spaces
             label <- (try numberedBlock) <|> (do { loop <- loop_control; return (Nothing, loop) })
             p <- parser $ fst label
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
                  p <- parser Nothing
                  return $ ender ++ p

continue = do string "continue"
              return "end do" -- replaces continue with 'end do', this is the goal!
                      
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

parseExpr :: Monad m => String -> String -> m String
parseExpr file input =
    case (runParser p (0::Int) "" input) of
      Left err  -> fail $ show err
      Right x   -> return x
  where
    p = do  pos <- getPosition
            setPosition $ (flip setSourceName) file $
                          (flip setSourceLine) 1 $
                          (flip setSourceColumn) 1 $ pos
            x <- parser Nothing
            return x
                
go filename = do args <- getArgs
                 srcfile <- readFile filename
                 parseExpr filename srcfile

main = do args <- getArgs
          go (head args)