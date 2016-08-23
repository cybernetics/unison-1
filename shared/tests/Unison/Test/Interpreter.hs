module Unison.Test.Interpreter where

import Test.Tasty
import Test.Tasty.HUnit
import qualified Unison.Parsers as P
import qualified Unison.Node as Node
import qualified Unison.Note as Note
import qualified Unison.Test.Common as Common

tests :: TestTree
tests = withResource Common.node (\_ -> pure ()) $ \node ->
  let
    tests =
      [ t "1 + 1" "2"
      , t "1 + 1 + 1" "3"
      , t "(x -> x) 42" "42"
      , t "let x = 2; y = 3 ; x + y;;" "5"
      , t "if False 0 1" "1"
      , t "if True 12 13" "12"
      , t "1 > 0" "True"
      , t "1 == 1" "True"
      , t "2 == 0" "False"
      , t "1 < 2" "True"
      , t "1 <= 1" "True"
      , t "1 >= 1" "True"
      , t "let rec fac n = if (n == 0) 1 (n * fac (n - 1)); fac 5;;" "120"
      , t "let rec ping n = if (n >= 10) n (pong (n + 1)); pong n = ping (n + 1); ping 0;;"
          "10"
      , t "let id x = x; g = id 42; p = id \"hi\" ; g;;" "42"
      , t "let id : forall a . a -> a; id x = x; g = id 42; p = id \"hi\" ; g;;" "42"
      , t "(let id x = x; id;; : forall a . a -> a) 42" "42"
      , t "Optional.map ((+) 1) (Some 1)" "Optional.Some (1 + 1)"
      , t "Either.fold ((+) 1) ((+) 2) (Either.Left 1)" "2"
      , t "Either.fold ((+) 1) ((+) 2) (Either.Right 1)" "3"
      , t "Either.swap (Left 1)" "Either.Right 1"
      , t "Pair.fold (x y -> x) (1, 2)" "1"
      , t "const 41 0" "41"
      , t "1st (1,2,3,4)" "1"
      , t "2nd (1,2 + 1,3,4)" "3"
      , t "Vector.reverse [1,2,3]" "[3,2,1]"
      , t "Vector.reverse Vector.empty" "[]"
      , t "Vector.fold-right Vector.prepend Vector.empty [1,2,3]" "[1,2,3]"
      , t "Vector.fold-balanced Vector.concatenate Vector.empty (Vector.map Vector.single [1,2,3,4,5])"
          "[1,2,3,4,5]"
      , t "Vector.fold-balanced Vector.concatenate Vector.empty [[1],[2],[3,4],[5]]"
          "[1,2,3,4,5]"
      , t "Vector.fold-balanced (+) 0 [1,2,3]" "6"
      , t "if (Text.equal \"hi\" \"hi\") 1 2" "1"
      , t "if (Text.lessThan \"hi\" \"hiya\") 1 2" "1"
      , t "if (Text.lessThanOrEqual \"hi\" \"hiya\") 1 2" "1"
      , t "if (Text.greaterThan \"hiya\" \"hi\") 1 2" "1"
      , t "if (Text.greaterThanOrEqual \"hiya\" \"hi\") 1 2" "1"
      , t "if (Text.greaterThanOrEqual \"hi\" \"hi\") 1 2" "1"
      , t "if (Text.lessThanOrEqual \"hi\" \"hi\") 1 2" "1"
      , t "Vector.range 0 10" "[0,1,2,3,4,5,6,7,8,9]"
      , t "Vector.range 0 0" "[]"
      , t "Vector.fold-left (+) 0 (Vector.replicate 5 1)" "5"
      ]
    t uneval eval = testCase (uneval ++ " ⟹  " ++ eval) $ do
      (node, _, builtins) <- node
      -- putStrLn (show $ map fst builtins)
      let term = P.bindBuiltins builtins [] $ P.unsafeParseTerm uneval
      _ <- Note.run $ Node.typeAt node term []
      [(_,_,result)] <- Note.run $ Node.evaluateTerms node [([], term)]
      assertEqual "comparing results" (P.unsafeParseTerm eval) result
  in testGroup "Interpreter" tests

main = defaultMain tests