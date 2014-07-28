{-# LANGUAGE RankNTypes #-}

import Prelude hiding ( drop
                      , take
                      , takeWhile
                      , print
                      , map
                      , filter
                      , foldl
                      , foldl'
                      , foldr
                      , foldr'
                      , iterate
                      )
import FreeStream
import Data.Foldable hiding (fold, or)
import System.IO (isEOF)
import Control.Monad (forever, unless, replicateM_, when)
import Control.Monad.Trans.Free
import Data.Maybe (fromJust)
import Control.Applicative

data Arithmetic
    = Value Int
    | Add Arithmetic Arithmetic
    | Mul Arithmetic Arithmetic
    | Sub Arithmetic Arithmetic
    | Div Arithmetic Arithmetic
    deriving Show

doArith :: Arithmetic -> Int
doArith (Value v) = v
doArith (Add l r) = (doArith l) + (doArith r)
doArith (Mul l r) = (doArith l) * (doArith r)
doArith (Sub l r) = (doArith l) - (doArith r)
doArith (Div l r) = (doArith l) `div` (doArith r)

parseArith :: Sink (Stream String) IO (Maybe Arithmetic)
parseArith = loop [] where
    loop stack = do
        d <- await
        case recv d of
            Just token -> case token of
                "+" -> buildBranch (Add) stack
                "*" -> buildBranch (Mul) stack
                "-" -> buildBranch (Sub) stack
                "/" -> buildBranch (Div) stack

                _   -> do
                    v <- return token
                    loop $ (Value (read v)):stack
            Nothing -> return . Just . head $ stack

    buildBranch con stack = do
        if length stack < 2
            then return Nothing
            else do
                (l:r:rest) <- return stack
                r          <- return $ con l r
                loop $ r:rest

astring = "56 2 * 30 +"

tokenize :: Process (Stream Char) (Stream String) IO ()
tokenize = loop "" where
    loop acc = do
        d <- await
        case recv d of
            Nothing -> go acc >> return ()
            Just c -> case c of
                ' ' -> do
                    go acc
                    loop ""
                _   -> loop $ acc ++ [c]
    go acc = case acc of
        "" -> return ()
        " " -> return ()
        _ -> yield $ message acc

rpn :: String -> IO (Maybe Int)
rpn str = do
    parsed <- stream (each str) +> tokenize |> parseArith
    case parsed of
        Nothing -> return Nothing
        Just  p -> return . Just $ doArith p
