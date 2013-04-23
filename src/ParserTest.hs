module Main where

import Language.Fortran.Parser

main :: IO ()
main = return () -- TODO

parseTest s = do f <- readFile s
                 return $ parse f
