{-# LANGUAGE DeriveGeneric #-}
module Ch15 where
import Data.Semigroup
import Data.Monoid (First, Last, Sum, Product)
import Data.Bifunctor
import Generics.Deriving

import Test.QuickCheck
import Test.QuickCheck.Gen
import Test.QuickCheck.Function
import Test.HUnit

-- ============================================================================
--                                  Monoids
-- ============================================================================
{--
-- A Monoid is a binary associative operation with an identity

-- Laws for Monoids
-- Left and Right Identity
mappend mempty x = x
mappend x mempty = x

-- Associativity
mappend x (mappend y z) = mappend (mapend x y) z

mconcat = foldr mappend mempty
-}

-- Maybe has many valid monoids, two of which are First and Last
just3 = First Nothing <> First (Just 3) <> First (Just 5) <> First Nothing
just5 = Last Nothing <> Last (Just 3) <> Last (Just 5) <> Last Nothing
nothin = First Nothing <> First Nothing

-- Practice writing a Monoid Instance
data Optional a =
    Nada
  | Only a
  deriving (Eq, Show)

instance Monoid a => Monoid (Optional a) where
    mempty = Nada
    mappend Nada Nada = Nada
    mappend (Only x) Nada = Only x
    mappend Nada (Only x) = Only x
    mappend (Only x) (Only y) = Only (mappend x y)

instance Arbitrary a => Arbitrary (Optional a) where
    arbitrary = oneof [return Nada, fmap Only arbitrary]

-- Mad Lib Example
type Verb = String
type Adjective = String
type Adverb = String
type Noun = String
type Exclamation = String

madlibbin' :: Exclamation
           -> Adverb
           -> Noun
           -> Adjective
           -> String
madlibbin' e adv noun adj =
    e <> "! he said " <> adv <> " as he jumped into his car "
    <> noun <> " and drove off with his " <> adj <> " wife."

madlibbinBetter' :: Exclamation -> Adverb -> Noun -> Adjective -> String
madlibbinBetter' e adv noun adj =
    mconcat [e, "! he said ", adv, " as he jumped into his car ", noun,
             " and drove off with his ", adj, " wife."]

-- Checking associativity with QuickCheck
prop_funcAssoc :: Eq a => (a -> a -> a) -> a -> a -> a -> Bool
prop_funcAssoc (<>) a b c = a <> (b <> c) == (a <> b) <> c

prop_monoidAssoc :: (Eq m, Semigroup m) => m -> m -> m -> Bool
prop_monoidAssoc a b c = (a <> (b <> c)) == ((a <> b) <> c)

monoidLeftIdent :: (Eq m, Semigroup m, Monoid m) => m -> Bool
monoidLeftIdent a = (a <> mempty) == a

monoidRightIdent :: (Eq m, Semigroup m, Monoid m) => m -> Bool
monoidRightIdent a = (mempty <> a) == a

ok = quickCheck (monoidLeftIdent :: String -> Bool)

-- Example of something failing
data Bull = Fools | Twoo deriving (Eq, Show)

instance Arbitrary Bull where
    arbitrary = oneof [return Fools, return Twoo]

instance Semigroup Bull where
    _ <> _  = Fools

instance Monoid Bull where
    mempty = Fools
    mappend _ _ = Fools

type BullMappend = Bull -> Bull -> Bull -> Bool

pass1 = quickCheck (prop_monoidAssoc :: BullMappend)
fail2 = quickCheck (monoidLeftIdent :: Bull -> Bool)
fail3 = quickCheck (monoidRightIdent :: Bull -> Bool)

-- Writing a monoid instance for a maybe that doesn't depend on the subtype
-- being a monoid
newtype First' a = First' { getFirst' :: Optional a }
    deriving (Eq, Show)

instance Semigroup (First' a) where
    (<>) (First' Nada) (First' Nada) = First' Nada
    (<>) (First' (Only x)) (First' Nada) = First' (Only x)
    (<>) (First' Nada) (First' (Only x)) = First' (Only x)
    (<>) (First' (Only x)) (First' (Only y)) = First' (Only x)

instance Monoid (First' a) where
    mempty = First' Nada
    mappend = (<>)

instance Arbitrary a => Arbitrary (First' a) where
    arbitrary = oneof [fmap First' arbitrary]

assoc = quickCheck (prop_monoidAssoc :: First' Bull -> First' Bull -> First' Bull -> Bool)
lIdent = quickCheck (monoidLeftIdent :: First' Bull -> Bool)
rIdent = quickCheck (monoidRightIdent :: First' Bull -> Bool)

type FirstMappend = First' String -> First' String -> First' String -> Bool
isAssoc = quickCheck (prop_monoidAssoc :: FirstMappend)

-- ============================================================================
--                                Semigroups
-- ============================================================================
-- A semigroup is an associative binary operation
-- (This is a monoid without an identity)
{-
class Semigroup a where
    (<>) :: a -> a -> a

-- Law:
(a <> b) <> c == a <> (b <> c)
-}

-- Semigroups will be coming to base in GHC 8.0, and we will see:
-- class Semigroup a => Monoid a where
-- ...
-- in the definition of Monoid.

-- Consider the nonempty list type:
data NonEmpty a = a :| [a]
    deriving (Eq, Ord, Show)

-- If we remove the associativity requirement from a Semigroup, we have a 'Magma'

-- ============================================================================
--                             Chapter Exercises
-- ============================================================================
-- Semigroup
data Trivial = Trivial deriving (Eq, Show)

instance Arbitrary Trivial where
    arbitrary = return Trivial

instance Semigroup Trivial where
    _ <> _ = Trivial

semigroupAssoc :: (Eq m, Semigroup m) => m -> m -> m -> Bool
semigroupAssoc a b c = (a <> (b <> c)) == ((a <> b) <> c)
type TrivialAssoc = Trivial -> Trivial -> Trivial -> Bool

e1 = quickCheck (semigroupAssoc :: Trivial -> Trivial -> Trivial -> Bool)


instance (Arbitrary a) => Arbitrary (Sum a) where
    arbitrary = Sum <$> arbitrary

instance (Arbitrary a) => Arbitrary (Product a) where
    arbitrary = Product <$> arbitrary

newtype Identity a = Identity a
    deriving (Eq, Show)

instance Semigroup a => Semigroup (Identity a) where
    (Identity x) <> (Identity y) = Identity (x <> y)

instance Arbitrary a => Arbitrary (Identity a) where
    arbitrary = Identity <$> arbitrary

type IdentAssoc = Identity (Sum Int) -> Identity (Sum Int) -> Identity (Sum Int) -> Bool
e2 = quickCheck (semigroupAssoc :: IdentAssoc)


data Two a b = Two a b
    deriving (Eq, Show)

instance Bifunctor Two where
    bimap f g (Two a b) = Two (f a) (g b)

instance (Arbitrary a, Arbitrary b) => Arbitrary (Two a b) where
    arbitrary = Two <$> arbitrary <*> arbitrary

instance (Semigroup a, Semigroup b) => Semigroup (Two a b) where
    (Two x y) <> (Two x' y') = Two (x <> x') (y <> y')

e3 = quickCheck (semigroupAssoc :: Two (Product Int) (Sum Int) ->
                                   Two (Product Int) (Sum Int) ->
                                   Two (Product Int) (Sum Int) ->
                                   Bool)

data Three a b c = Three a b c
    deriving (Eq, Show)

instance (Semigroup a, Semigroup b, Semigroup c) => Semigroup (Three a b c) where
    (Three a b c) <> (Three a' b' c') = Three (a <> a') (b <> b') (c <> c')

newtype BoolConj = BoolConj Bool deriving (Eq, Show)

instance Semigroup BoolConj where
    (BoolConj True) <> (BoolConj True) = BoolConj True
    (BoolConj _) <> (BoolConj _) = BoolConj False

instance Arbitrary BoolConj where
    arbitrary = frequency [ (1, return (BoolConj False)), (1, return (BoolConj True)) ]

e6 = quickCheck (semigroupAssoc :: BoolConj -> BoolConj -> BoolConj -> Bool)


data Or a b = Fst a | Snd b
    deriving (Eq, Show)

-- "Sticky" Snd value that holds onto the first Snd value it sees,
instance Semigroup (Or a b) where
    (Snd a) <> _ = Snd a
    (Fst a) <> b = b

instance (Arbitrary a, Arbitrary b) => Arbitrary (Or a b) where
    arbitrary = oneof [fmap Fst arbitrary, fmap Snd arbitrary]

e8 = quickCheck (semigroupAssoc :: Or Int String -> Or Int String -> Or Int String -> Bool)

-- Behavior examples:
snd2 = Fst 1 <> Snd 2
fst2 = Fst 1 <> Fst 2
snd1 = Snd 1 <> Fst 2
snd1' = Snd 1 <> Snd 2

-- Here, we'll have only one a value, but multiple functions
-- capable of producing b values that need to be combined.
newtype Combine a b = Combine { unCombine :: a -> b }
    deriving Generic

instance Semigroup b => Semigroup (Combine a b) where
    f <> g = Combine $ unCombine f <> unCombine g

f :: Combine Integer (Sum Integer)
f = Combine $ \n -> Sum (n + 1)
g = Combine $ \n -> Sum (n - 1)
sum0 = unCombine (f <> g) 0
sum2 = unCombine (f <> g) 1
sum4 = unCombine (f <> f) 1
sum2' = unCombine (g <> f) 1

{--- TODO: Figure out the CoArbitrary instance and other dependent instances to
-- get this usable with quickcheck
instance Eq (Combine Int (Sum Int))
instance Show (Combine Int (Sum Int))
instance CoArbitrary (Sum Int)
instance CoArbitrary (Combine Int (Sum Int))

e9 = quickCheck (semigroupAssoc :: Combine Int (Sum Int)
                                  -> Combine Int (Sum Int)
                                  -> Combine Int (Sum Int)
                                  -> Bool)
-}

newtype Comp a = Comp { unComp :: a -> a }

instance Semigroup (Comp a) where
    (Comp f) <> (Comp g) = Comp (f . g)


data Validation a b = Failure' a | Success' b
    deriving (Eq, Show)

instance Semigroup a => Semigroup (Validation a b) where
    (Failure' a) <> (Failure' a') = Failure' (a <> a')
    (Failure' a) <> _ = Failure' a
    _ <> (Failure' a) = Failure' a
    (Success' b) <> (Success' b') = Success' b'

instance (Arbitrary a, Arbitrary b) => Arbitrary (Validation a b) where
    arbitrary = oneof [Failure' <$> arbitrary, Success' <$> arbitrary]

e11 = quickCheck (semigroupAssoc :: Validation String Int
                                    -> Validation String Int
                                    -> Validation String Int
                                    -> Bool)

newtype AccumulateRight a b = AccumulateRight (Validation a b)
    deriving (Eq, Show)

instance Semigroup b => Semigroup (AccumulateRight a b) where
    AccumulateRight (Success' b) <> AccumulateRight (Success' b') = AccumulateRight (Success' (b <> b'))
    AccumulateRight (Success' a) <> _ = AccumulateRight (Success' a)
    AccumulateRight _ <> b = b

newtype AccumulateBoth a b = AccumulateBoth (Validation a b)
    deriving (Eq, Show)

instance (Semigroup a, Semigroup b) => Semigroup (AccumulateBoth a b) where
    AccumulateBoth (Success' b) <> AccumulateBoth (Success' b') = AccumulateBoth (Success' (b <> b'))
    AccumulateBoth (Failure' a) <> AccumulateBoth (Failure' a') = AccumulateBoth (Failure' (a <> a'))
    AccumulateBoth (Failure' a) <> _ = AccumulateBoth (Failure' a)
    _ <> b = b

checks = assoc >> lIdent >> rIdent >> isAssoc >> e1 >> e2 >> e3 >> e6 >> e8 >> e11

-- ============================================================================
--                             Monoid Exercises
-- ============================================================================
checkMonoid :: (Eq t, Show t, Arbitrary t, Semigroup t, Monoid t) => t -> IO ()
checkMonoid t = do
    quickCheck (semigroupAssoc t)
    quickCheck (monoidLeftIdent t)
    quickCheck (monoidRightIdent t)

instance Monoid Trivial where
    mempty = Trivial
    mappend = (<>)

m1 = checkMonoid Trivial

instance (Semigroup a, Monoid a) => Monoid (Identity a) where
    mempty = Identity mempty
    mappend = (<>)

m2 = checkMonoid (Identity (Product 5 :: Product Integer))

instance (Semigroup a, Semigroup b, Monoid a, Monoid b) => Monoid (Two a b) where
    mempty = Two mempty mempty
    mappend = (<>)

m3 = checkMonoid (Two ("Foo" :: String) (Product 5 :: Product Integer))

instance Monoid BoolConj where
    mempty = BoolConj True
    mappend = (<>)

m4 = checkMonoid (BoolConj True)

instance (Semigroup a, Semigroup b, Monoid a, Monoid b) => Monoid (Combine a b) where
    mempty = Combine (unCombine mempty)
    mappend = (<>)

mchk = m1 >> m2 >> m3 >> m4

-- Exercise 8
newtype Mem s a =
    Mem {
        runMem :: s -> (a, s)
    }

-- a is a semigroup so we can use mconcat
-- s is a function, so it has to be chained
-- So, what we need to do is give the input to on
instance Semigroup a => Semigroup (Mem s a) where
    -- Compiles but discards x; essentially treats x as mempty
    -- x <> y = Mem $ \s -> runMem y s
    -- Does the same as above, but discards y
    -- x <> y = Mem $ \s -> runMem x s
    --
    -- We take the input value, and we get a new a by running both x and y
    -- and <> their fst results.  We get a new s by running the input value
    -- through x and sending it as the result to y, and taking the snd value.
    -- There's probably a much cleaer, nicer way to do this ... revisit someday.
    x <> y = Mem $ \s -> (fst (xpair s) <> fst (ypair s), snd $ ypair (snd $ xpair s))
        where xpair = runMem x
              ypair = runMem y

instance (Semigroup a, Monoid a) => Monoid (Mem s a) where
    mempty = Mem $ \s -> (mempty, s)
    mappend = (<>)

f' :: Mem Int String
f' = Mem $ \s -> ("fMon", s + 1)

g' :: Mem Int String
g' = Mem $ \s -> ("gMon", s + 100)

res = runTestTT $ test
    [ "t1" ~: "runMem (f' <> mempty) 0" ~: ("fMon",1) ~=? runMem (f' <> mempty) 0
    , "t2" ~: "runMem (mempty <> f') 0" ~: ("fMon",1) ~=? runMem (mempty <> f') 0
    , "t3" ~: "runMem mempty 0" ~: ("",0) ~=? (runMem mempty 0 :: (String, Int))
    , "t4" ~: "runMem (f' <> mempty) 0 == runMem f' 0" ~:
                    runMem (f' <> mempty) 0 ~=? runMem f' 0
    , "t5" ~: "runMem (mempty <> f') 0 == runMem f' 0" ~:
                    runMem (mempty <> f') 0 ~=? runMem f' 0
    , "t6" ~: "runMem (f' <> g') 0" ~: ("fMongMon", 101) ~=? runMem (f' <> g') 0
    ]
