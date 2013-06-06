module Main where

import Control.Applicative
import Data.Char

import Language.Fortran.Lexer
import Language.Haskell.ParseMonad


main :: IO ()
main = do
  s <- map toLower <$> getContents
  l <- getSrcLocLex
  print (alexScanTokens s l)
