module Main where

import Control.Applicative
import Data.Char

import Language.Fortran.Lexer
import Language.Haskell.ParseMonad


main :: IO ()
main = do
  s <- map toLower <$> getContents
  print (alexScanTokens s)
