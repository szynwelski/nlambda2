{-# LANGUAGE KindSignatures, DefaultSignatures, FlexibleContexts, TypeOperators, RankNTypes #-}

module Meta where

import Data.Char (toLower)
import Data.Foldable (fold, foldl', foldr', toList)
import Data.List (isPrefixOf)
import qualified Data.Map as Map
import qualified Data.Set as Set
import Data.Map (Map)
import Data.Set (Set)
import GHC.Generics
import GHC.Read (readPrec, readListPrec)
import GHC.Show (showList__)
import Text.ParserCombinators.ReadPrec (ReadPrec)

------------------------------------------------------------------------------------------
-- Class WithMeta and instances
------------------------------------------------------------------------------------------

type Identifier = Int
type IdMap = Map Identifier Identifier
type IdPairSet = Set (Identifier, Identifier)
type Meta = (IdMap, IdPairSet)

data WithMeta a = WithMeta {value :: a, meta :: Meta}

instance Show a => Show (WithMeta a) where
    showsPrec n = noMetaResOp $ showsPrec n
    show = noMetaResOp show
    showList = showList . value . liftMeta

--instance Eq a => Eq (WithMeta a) where
--    (==) = noMetaResUnionOp (==)
--    (/=) = noMetaResUnionOp (/=)
--
--instance Ord a => Ord (WithMeta a) where
--    compare = noMetaResUnionOp compare
--    (<) = noMetaResUnionOp (<)
--    (<=) = noMetaResUnionOp (<=)
--    (>) = noMetaResUnionOp (>)
--    (>=) = noMetaResUnionOp (>=)
--    max = unionOp max
--    min = unionOp min
--
--instance Bounded a => Bounded (WithMeta a) where
--    minBound = noMeta minBound
--    maxBound = noMeta maxBound
--
--instance Enum a => Enum (WithMeta a) where
--    succ = idOp succ
--    pred = idOp pred
--    toEnum = noMeta . toEnum
--    fromEnum = noMetaResOp fromEnum
--    enumFrom = fmap noMeta . enumFrom . value
--    enumFromThen x = fmap noMeta . enumFromThen (value x). value
--    enumFromTo x = fmap noMeta . enumFromTo (value x). value
--    enumFromThenTo x y = fmap noMeta . enumFromThenTo (value x) (value y) . value
--
--instance Num a => Num (WithMeta a) where
--    (+) = unionOp (+)
--    (-) = unionOp (-)
--    (*) = unionOp (*)
--    negate = idOp negate
--    abs = idOp abs
--    signum = idOp signum
--    fromInteger = noMeta . fromInteger
--
instance Monoid a => Monoid (WithMeta a) where
    mempty = noMeta mempty
    mappend = unionOp mappend
    mconcat = idOp mconcat . liftMeta

------------------------------------------------------------------------------------------
-- Methods to handle meta information in expressions
------------------------------------------------------------------------------------------

type Union = (Meta, [IdMap])

-- TODO
replaceVariablesIds :: IdMap -> a -> a
replaceVariablesIds = undefined

splitMapping :: IdPairSet -> IdMap -> (IdMap, IdMap)
splitMapping s m = if Set.null s then (Map.empty, m) else Map.partitionWithKey (\k v -> Set.member (k, v) s) m

renameMaps :: Meta -> Meta -> (Meta, IdMap, IdMap)
renameMaps (m1, s1) (m2, s2) = ((Map.union m1b m2c, Set.unions [s1, s2, Set.fromList $ Map.assocs m2d]), m1a, Map.union m2a m2d)
    where (m1a, m1b) = splitMapping s2 m1
          (m2a, m2b) = splitMapping s1 m2
          (m2c, m2d) = if Map.null m1b then (m2b, Map.empty) else Map.partitionWithKey (\k v -> v == Map.findWithDefault v k m1b) m2b

metaFromMap :: IdMap -> Meta
metaFromMap map = (map, Set.empty)

emptyMeta :: Meta
emptyMeta = (Map.empty, Set.empty)

noMeta :: a -> WithMeta a
noMeta x = WithMeta x emptyMeta

create :: a -> Meta -> WithMeta a
create x m = WithMeta x m

union :: [Meta] -> Union
union [] = (emptyMeta, [])
union [m] = (m, [Map.empty])
union (m:ms) = let (m', idMap:idMaps) = union ms
                   (m'', idMap1, idMap2) = renameMaps m m'
               in (m'', idMap1 : (Map.union idMap2 idMap) : idMaps)

getMeta :: Union -> Meta
getMeta = fst

rename :: Union -> Int -> a -> a
rename (_, idMaps) n x = let idMap = idMaps !! n
                         in if null idMap then x else x

emptyList :: [a]
emptyList = []

colon :: a -> [a] -> [a]
colon = (:)

------------------------------------------------------------------------------------------
-- Conversion functions to meta operations
------------------------------------------------------------------------------------------

idOp :: (a -> b) -> WithMeta a -> WithMeta b
idOp op (WithMeta x m) = WithMeta (op x) m

noMetaArgOp :: (a -> b) -> a -> WithMeta b
noMetaArgOp op = noMeta . op

noMetaResOp :: (a -> b) -> WithMeta a -> b
noMetaResOp op = op . value

leftIdOp :: (a -> b -> c) -> WithMeta a -> b -> WithMeta c
leftIdOp op (WithMeta x m) y = WithMeta (op x y) m

rightIdOp :: (a -> b -> c) -> a -> WithMeta b -> WithMeta c
rightIdOp op x (WithMeta y m) = WithMeta (op x y) m

unionOp :: (a -> b -> c) -> WithMeta a -> WithMeta b -> WithMeta c
unionOp op (WithMeta x m1) (WithMeta y m2) = WithMeta (op x' y') (getMeta u)
    where u = union [m1, m2]
          x' = rename u 0 x
          y' = rename u 1 y

union3Op :: (a -> b -> c -> d) -> WithMeta a -> WithMeta b -> WithMeta c -> WithMeta d
union3Op op (WithMeta x m1) (WithMeta y m2) (WithMeta z m3) = WithMeta (op x' y' z') (getMeta u)
    where u = union [m1, m2]
          x' = rename u 0 x
          y' = rename u 1 y
          z' = rename u 2 z

noMetaResUnionOp :: (a -> b -> c) -> WithMeta a -> WithMeta b -> c
noMetaResUnionOp op x = value . unionOp op x

(.*) :: (c -> d) -> (a -> b -> c) -> (a -> b -> d)
(.*) = (.) . (.)

metaFun :: Meta -> (WithMeta a -> b) -> a -> b
metaFun m f x = f (WithMeta x m)

metaFunOp :: ((a -> b) -> c -> d) -> (WithMeta a -> b) -> WithMeta c -> d
metaFunOp op f (WithMeta x m) = op (metaFun m f) x

noMetaResFunOp :: ((a -> b) -> c -> d) -> (WithMeta a -> b) -> WithMeta c -> WithMeta d
noMetaResFunOp op f (WithMeta x m) = WithMeta (op (metaFun m f) x) m

------------------------------------------------------------------------------------------
-- Class MetaLevel and deriving methods
------------------------------------------------------------------------------------------

class MetaLevel (f :: * -> *) where
    liftMeta :: f (WithMeta a) -> WithMeta (f a)
    dropMeta :: WithMeta (f a) -> f (WithMeta a)
    default liftMeta :: (Generic1 f, MetaLevel (Rep1 f)) => f (WithMeta a) -> WithMeta (f a)
    liftMeta x = let (WithMeta y m) = liftMeta (from1 x) in WithMeta (to1 y) m
    default dropMeta :: (Generic1 f, MetaLevel (Rep1 f)) => WithMeta (f a) -> f (WithMeta a)
    dropMeta (WithMeta x m) = to1 $ dropMeta (WithMeta (from1 x) m)

instance MetaLevel Par1 where
    liftMeta (Par1 (WithMeta x m)) = WithMeta (Par1 x) m
    dropMeta (WithMeta (Par1 x) m) = Par1 (WithMeta x m)

instance MetaLevel f => MetaLevel (Rec1 f) where
    liftMeta (Rec1 x) = let (WithMeta y m) = liftMeta x in WithMeta (Rec1 y) m
    dropMeta (WithMeta (Rec1 x) m) = Rec1 (dropMeta (WithMeta x m))

instance MetaLevel U1 where
    liftMeta U1 = noMeta U1
    dropMeta (WithMeta U1 _) = U1

instance MetaLevel (K1 i c) where
    liftMeta (K1 x) = noMeta $ K1 x
    dropMeta (WithMeta (K1 x) m) = K1 x

instance MetaLevel f => MetaLevel (M1 i c f) where
    liftMeta (M1 x) = let (WithMeta y m) = liftMeta x in WithMeta (M1 y) m
    dropMeta (WithMeta (M1 x) m) = M1 (dropMeta (WithMeta x m))

instance (MetaLevel f, MetaLevel g) => MetaLevel (f :+: g) where
    liftMeta (L1 x) = let (WithMeta y m) = liftMeta x in WithMeta (L1 y) m
    liftMeta (R1 x) = let (WithMeta y m) = liftMeta x in WithMeta (R1 y) m
    dropMeta (WithMeta (L1 x) m) = L1 (dropMeta (WithMeta x m))
    dropMeta (WithMeta (R1 x) m) = R1 (dropMeta (WithMeta x m))

instance (MetaLevel f, MetaLevel g) => MetaLevel (f :*: g) where
    liftMeta (x :*: y) = let (WithMeta x' m1) = liftMeta x
                             (WithMeta y' m2) = liftMeta y
                             u = union [m1, m2]
                             x'' = rename u 0 x'
                             y'' = rename u 1 y'
                         in WithMeta (x'' :*: y'') (getMeta u)
    dropMeta (WithMeta (x :*: y) m) = dropMeta (WithMeta x m) :*: dropMeta (WithMeta y m)

instance MetaLevel Maybe
instance MetaLevel []
instance MetaLevel (Either a)
instance MetaLevel ((,) a)
instance MetaLevel ((->) a) where
    liftMeta f = noMeta (value . f)
    dropMeta f = noMeta . (value f)

instance MetaLevel IO where
    liftMeta x = noMeta $ fmap value x -- noMeta ???
    dropMeta (WithMeta x m) = fmap (`WithMeta` m) x

------------------------------------------------------------------------------------------
-- Meta classes from Prelude
------------------------------------------------------------------------------------------

-- TODO add instances

class Applicative f => Applicative_nlambda (f :: * -> *) where
  pure_nlambda :: WithMeta a -> WithMeta (f a)
  pure_nlambda = idOp pure
  (<*>###) :: WithMeta (f (a -> b)) -> WithMeta (f a) -> WithMeta (f b)
  (<*>###) = unionOp (<*>)
  (*>###) :: WithMeta (f a) -> WithMeta (f b) -> WithMeta (f b)
  (*>###) = unionOp (*>)
  (<*###) :: WithMeta (f a) -> WithMeta (f b) -> WithMeta (f a)
  (<*###) = unionOp (<*)

class Bounded a => Bounded_nlambda a where
  minBound_nlambda :: WithMeta a
  minBound_nlambda = noMeta minBound
  maxBound_nlambda :: WithMeta a
  maxBound_nlambda = noMeta maxBound

class Enum a => Enum_nlambda a where
  succ_nlambda :: WithMeta a -> WithMeta a
  succ_nlambda = idOp succ
  pred_nlambda :: WithMeta a -> WithMeta a
  pred_nlambda = idOp pred
  toEnum_nlambda :: Int -> WithMeta a
  toEnum_nlambda = noMeta . toEnum
  fromEnum_nlambda :: WithMeta a -> Int
  fromEnum_nlambda = noMetaResOp fromEnum
  enumFrom_nlambda :: WithMeta a -> WithMeta [a]
  enumFrom_nlambda = idOp enumFrom
  enumFromThen_nlambda :: WithMeta a -> WithMeta a -> WithMeta [a]
  enumFromThen_nlambda = unionOp enumFromThen
  enumFromTo_nlambda :: WithMeta a -> WithMeta a -> WithMeta [a]
  enumFromThenTo_nlambda :: WithMeta a -> WithMeta a -> WithMeta a -> WithMeta [a]
  enumFromThenTo_nlambda = union3Op enumFromThenTo

class Eq a => Eq_nlambda a where
  (==###) :: WithMeta a -> WithMeta a -> Bool
  (==###) = noMetaResUnionOp (==)
  (/=###) :: WithMeta a -> WithMeta a -> Bool
  (/=###) = noMetaResUnionOp (/=)

class Floating a => Floating_nlambda a where
  pi_nlambda :: WithMeta a
  pi_nlambda = noMeta pi
  exp_nlambda :: WithMeta a -> WithMeta a
  exp_nlambda = idOp exp
  log_nlambda :: WithMeta a -> WithMeta a
  log_nlambda = idOp log
  sqrt_nlambda :: WithMeta a -> WithMeta a
  sqrt_nlambda = idOp sqrt
  (**###) :: WithMeta a -> WithMeta a -> WithMeta a
  (**###) = unionOp (**)
  logBase_nlambda :: WithMeta a -> WithMeta a -> WithMeta a
  logBase_nlambda = unionOp logBase
  sin_nlambda :: WithMeta a -> WithMeta a
  sin_nlambda = idOp sin
  cos_nlambda :: WithMeta a -> WithMeta a
  cos_nlambda = idOp cos
  tan_nlambda :: WithMeta a -> WithMeta a
  tan_nlambda = idOp tan
  asin_nlambda :: WithMeta a -> WithMeta a
  asin_nlambda = idOp asin
  acos_nlambda :: WithMeta a -> WithMeta a
  acos_nlambda = idOp acos
  atan_nlambda :: WithMeta a -> WithMeta a
  atan_nlambda = idOp atan
  sinh_nlambda :: WithMeta a -> WithMeta a
  sinh_nlambda = idOp sinh
  cosh_nlambda :: WithMeta a -> WithMeta a
  cosh_nlambda = idOp cosh
  tanh_nlambda :: WithMeta a -> WithMeta a
  tanh_nlambda = idOp tanh
  asinh_nlambda :: WithMeta a -> WithMeta a
  asinh_nlambda = idOp asinh
  acosh_nlambda :: WithMeta a -> WithMeta a
  acosh_nlambda = idOp acosh
  atanh_nlambda :: WithMeta a -> WithMeta a
  atanh_nlambda = idOp atanh

class (MetaLevel t, Foldable t) => Foldable_nlambda (t :: * -> *) where
  fold_nlambda :: Monoid_nlambda m => WithMeta (t m) -> WithMeta m
  fold_nlambda = idOp fold
  foldMap_nlambda :: Monoid_nlambda m => (WithMeta a -> WithMeta m) -> WithMeta (t a) -> WithMeta m
  foldMap_nlambda = metaFunOp foldMap
  foldr_nlambda :: (WithMeta a -> WithMeta b -> WithMeta b) -> WithMeta b -> WithMeta (t a) -> WithMeta b
  foldr_nlambda f x = foldr f x . dropMeta
  foldr'_nlambda :: (WithMeta a -> WithMeta b -> WithMeta b) -> WithMeta b -> WithMeta (t a) -> WithMeta b
  foldr'_nlambda f x = foldr' f x . dropMeta
  foldl_nlambda :: (WithMeta b -> WithMeta a -> WithMeta b) -> WithMeta b -> WithMeta (t a) -> WithMeta b
  foldl_nlambda f x = foldl f x . dropMeta
  foldl'_nlambda :: (WithMeta b -> WithMeta a -> WithMeta b) -> WithMeta b -> WithMeta (t a) -> WithMeta b
  foldl'_nlambda f x = foldl' f x . dropMeta
  foldr1_nlambda :: (WithMeta a -> WithMeta a -> WithMeta a) -> WithMeta (t a) -> WithMeta a
  foldr1_nlambda f = foldr1 f . dropMeta
  foldl1_nlambda :: (WithMeta a -> WithMeta a -> WithMeta a) -> WithMeta (t a) -> WithMeta a
  foldl1_nlambda f = foldl1 f . dropMeta
  toList_nlambda :: WithMeta (t a) -> WithMeta [a]
  toList_nlambda = idOp toList
  null_nlambda :: WithMeta (t a) -> Bool
  null_nlambda = noMetaResOp null
  length_nlambda :: WithMeta (t a) -> Int
  length_nlambda = noMetaResOp length
  elem_nlambda :: Eq_nlambda a => WithMeta a -> WithMeta (t a) -> Bool
  elem_nlambda = noMetaResUnionOp elem
  maximum_nlambda :: Ord_nlambda a => WithMeta (t a) -> WithMeta a
  maximum_nlambda = idOp maximum
  minimum_nlambda :: Ord_nlambda a => WithMeta (t a) -> WithMeta a
  minimum_nlambda = idOp minimum
  sum_nlambda :: Num_nlambda a => WithMeta (t a) -> WithMeta a
  sum_nlambda = idOp sum
  product_nlambda :: Num_nlambda a => WithMeta (t a) -> WithMeta a
  product_nlambda = idOp product

class Fractional a => Fractional_nlambda a where
  (/###) :: WithMeta a -> WithMeta a -> WithMeta a
  (/###) = unionOp (/)
  recip_nlambda :: WithMeta a -> WithMeta a
  recip_nlambda = idOp recip
  fromRational_nlambda :: Rational -> WithMeta a
  fromRational_nlambda = noMeta . fromRational

class (MetaLevel f, Functor f) => Functor_nlambda (f :: * -> *) where
  fmap_nlambda :: (WithMeta a -> WithMeta b) -> WithMeta (f a) -> WithMeta (f b)
  fmap_nlambda = liftMeta .* metaFunOp fmap
  (<$###) :: WithMeta a -> WithMeta (f b) -> WithMeta (f a)
  (<$###) = unionOp (<$)

class Integral a => Integral_nlambda a where
  quot_nlambda :: WithMeta a -> WithMeta a -> WithMeta a
  quot_nlambda = unionOp quot
  rem_nlambda :: WithMeta a -> WithMeta a -> WithMeta a
  rem_nlambda = unionOp rem
  div_nlambda :: WithMeta a -> WithMeta a -> WithMeta a
  div_nlambda = unionOp div
  mod_nlambda :: WithMeta a -> WithMeta a -> WithMeta a
  mod_nlambda = unionOp mod
  quotRem_nlambda :: WithMeta a -> WithMeta a -> WithMeta (a, a)
  quotRem_nlambda = unionOp quotRem
  divMod_nlambda :: WithMeta a -> WithMeta a -> WithMeta (a, a)
  divMod_nlambda = unionOp divMod
  toInteger_nlambda :: WithMeta a -> Integer
  toInteger_nlambda = noMetaResOp toInteger

class (MetaLevel m, Monad m) => Monad_nlambda (m :: * -> *) where
  (>>=###) :: WithMeta (m a) -> (WithMeta a -> WithMeta (m b)) -> WithMeta (m b)
  (>>=###) (WithMeta x m) f = liftMeta $ x >>= (dropMeta . metaFun m f)
  (>>###) :: WithMeta (m a) -> WithMeta (m b) -> WithMeta (m b)
  (>>###) = unionOp (>>)
  return_nlambda :: WithMeta a -> WithMeta (m a)
  return_nlambda = idOp return
  fail_nlambda :: String -> WithMeta (m a)
  fail_nlambda = noMeta . fail

class Monoid a => Monoid_nlambda a where
  mempty_nlambda :: WithMeta a
  mempty_nlambda = noMeta mempty
  mappend_nlambda :: WithMeta a -> WithMeta a -> WithMeta a
  mappend_nlambda = unionOp mappend
  mconcat_nlambda :: WithMeta [a] -> WithMeta a
  mconcat_nlambda = idOp mconcat

class Num a => Num_nlambda a where
  (+###) :: WithMeta a -> WithMeta a -> WithMeta a
  (+###) = unionOp (+)
  (-###) :: WithMeta a -> WithMeta a -> WithMeta a
  (-###) = unionOp (-)
  (*###) :: WithMeta a -> WithMeta a -> WithMeta a
  (*###) = unionOp (*)
  negate_nlambda :: WithMeta a -> WithMeta a
  negate_nlambda = idOp negate
  abs_nlambda :: WithMeta a -> WithMeta a
  abs_nlambda = idOp abs
  signum_nlambda :: WithMeta a -> WithMeta a
  signum_nlambda = idOp signum
  fromInteger_nlambda :: Integer -> WithMeta a
  fromInteger_nlambda = noMeta . fromInteger

class Ord a => Ord_nlambda a where
  compare_nlambda :: WithMeta a -> WithMeta a -> Ordering
  compare_nlambda = noMetaResUnionOp compare
  (<###) :: WithMeta a -> WithMeta a -> Bool
  (<###) = noMetaResUnionOp (<)
  (<=###) :: WithMeta a -> WithMeta a -> Bool
  (<=###) = noMetaResUnionOp (<=)
  (>###) :: WithMeta a -> WithMeta a -> Bool
  (>###) = noMetaResUnionOp (>)
  (>=###) :: WithMeta a -> WithMeta a -> Bool
  (>=###) = noMetaResUnionOp (>=)
  max_nlambda :: WithMeta a -> WithMeta a -> WithMeta a
  max_nlambda = unionOp max
  min_nlambda :: WithMeta a -> WithMeta a -> WithMeta a
  min_nlambda = unionOp min

class Read a => Read_nlambda a where
  readsPrec_nlambda :: Int -> String -> WithMeta [(a, String)]
  readsPrec_nlambda n = noMeta . readsPrec n
  readList_nlambda :: String -> WithMeta [([a], String)]
  readList_nlambda = noMeta . readList
  readPrec_nlambda :: WithMeta (ReadPrec a)
  readPrec_nlambda = noMeta readPrec
  readListPrec_nlambda :: WithMeta (ReadPrec [a])
  readListPrec_nlambda = noMeta readListPrec

class Real a => Real_nlambda a where
  toRational_nlambda :: WithMeta a -> Rational
  toRational_nlambda = noMetaResOp toRational

class RealFloat a => RealFloat_nlambda a where
  floatRadix_nlambda :: WithMeta a -> Integer
  floatRadix_nlambda = noMetaResOp floatRadix
  floatDigits_nlambda :: WithMeta a -> Int
  floatDigits_nlambda = noMetaResOp floatDigits
  floatRange_nlambda :: WithMeta a -> (Int, Int)
  floatRange_nlambda = noMetaResOp floatRange
  decodeFloat_nlambda :: WithMeta a -> (Integer, Int)
  decodeFloat_nlambda = noMetaResOp decodeFloat
  encodeFloat_nlambda :: Integer -> Int -> WithMeta a
  encodeFloat_nlambda x = noMeta . encodeFloat x
  exponent_nlambda :: WithMeta a -> Int
  exponent_nlambda = noMetaResOp exponent
  significand_nlambda :: WithMeta a -> WithMeta a
  significand_nlambda = idOp significand
  scaleFloat_nlambda :: Int -> WithMeta a -> WithMeta a
  scaleFloat_nlambda = rightIdOp scaleFloat
  isNaN_nlambda :: WithMeta a -> Bool
  isNaN_nlambda = noMetaResOp isNaN
  isInfinite_nlambda :: WithMeta a -> Bool
  isInfinite_nlambda = noMetaResOp isInfinite
  isDenormalized_nlambda :: WithMeta a -> Bool
  isDenormalized_nlambda = noMetaResOp isDenormalized
  isNegativeZero_nlambda :: WithMeta a -> Bool
  isNegativeZero_nlambda = noMetaResOp isNegativeZero
  isIEEE_nlambda :: WithMeta a -> Bool
  isIEEE_nlambda = noMetaResOp isIEEE
  atan2_nlambda :: WithMeta a -> WithMeta a -> WithMeta a
  atan2_nlambda = unionOp atan2

class RealFrac a => RealFrac_nlambda a where
  properFraction_nlambda :: Integral_nlambda b => WithMeta a -> WithMeta (b, a)
  properFraction_nlambda = idOp properFraction
  truncate_nlambda :: Integral_nlambda b => WithMeta a -> WithMeta b
  truncate_nlambda = idOp truncate
  round_nlambda :: Integral_nlambda b => WithMeta a -> WithMeta b
  round_nlambda = idOp round
  ceiling_nlambda :: Integral_nlambda b => WithMeta a -> WithMeta b
  ceiling_nlambda = idOp ceiling
  floor_nlambda :: Integral_nlambda b => WithMeta a -> WithMeta b
  floor_nlambda = idOp floor

class Show a => Show_nlambda a where
  showsPrec_nlambda :: Int -> WithMeta a -> ShowS
  showsPrec_nlambda n = noMetaResOp (showsPrec n)
  show_nlambda :: WithMeta a -> String
  show_nlambda = noMetaResOp show
  showList_nlambda :: WithMeta [a] -> ShowS
  showList_nlambda = noMetaResOp showList

class (MetaLevel t, Traversable t) => Traversable_nlambda (t :: * -> *) where
  traverse_nlambda :: (MetaLevel f, Applicative_nlambda f) => (WithMeta a -> WithMeta (f b)) -> WithMeta (t a) -> WithMeta (f (t b))
  traverse_nlambda f (WithMeta x m) = liftMeta $ fmap liftMeta $ traverse (dropMeta . metaFun m f) x
  sequenceA_nlambda :: Applicative_nlambda f => WithMeta (t (f a)) -> WithMeta (f (t a))
  sequenceA_nlambda = idOp sequenceA
  mapM_nlambda :: Monad_nlambda m => (WithMeta a -> WithMeta (m b)) -> WithMeta (t a) -> WithMeta (m (t b))
  mapM_nlambda f (WithMeta x m) = liftMeta $ fmap liftMeta $ mapM (dropMeta . metaFun m f) x
  sequence_nlambda :: Monad_nlambda m => WithMeta (t (m a)) -> WithMeta (m (t a))
  sequence_nlambda = idOp sequence

showList___nlambda :: (WithMeta a -> ShowS) ->  WithMeta [a] -> ShowS
showList___nlambda f (WithMeta xs m) = showList__ (metaFun m f) xs

----------------------------------------------------------------------------------------
-- Meta equivalents
----------------------------------------------------------------------------------------

name_suffix :: String
name_suffix = "_nlambda"

op_suffix :: String
op_suffix = "###"

data ConvertFun = NoMeta | IdOp | NoMetaArgOp | NoMetaResOp | LeftIdOp | RightIdOp | UnionOp | Union3Op
    | NoMetaResUnionOp | MetaFunOp | NoMetaResFunOp | LiftMeta | DropMeta deriving (Show, Eq, Ord)

convertFunName :: ConvertFun -> String
convertFunName fun = (toLower $ head $ show fun) : (tail $ show fun)

-- FIXME remove FunSuffix and OpSuffix -> should happen automatically
data MetaEquivalentType = FunSuffix | OpSuffix | SameOp | ConvertFun ConvertFun deriving (Eq, Ord)

data MetaEquivalent = NoEquivalent | MetaFun String | MetaConvertFun String | OrigFun deriving Show

type ModuleName = String
type MethodName = String
type MetaEquivalentMap = Map ModuleName (Map MetaEquivalentType [MethodName])

createEquivalentsMap :: ModuleName -> [(MetaEquivalentType, [MethodName])] -> MetaEquivalentMap
createEquivalentsMap mod = Map.singleton mod . Map.fromList

preludeEquivalents :: Map String (Map MetaEquivalentType [String])
preludeEquivalents = Map.unions [ghcBase, ghcClasses, ghcEnum, ghcErr, ghcFloat, ghcList, ghcNum, ghcReal, ghcShow, ghcTuple, ghcTypes]

metaEquivalent :: ModuleName -> MethodName -> MetaEquivalent
metaEquivalent mod name = case maybe Nothing findMethod $ Map.lookup mod preludeEquivalents of
                            Just FunSuffix -> MetaFun (name ++ name_suffix)
                            Just OpSuffix -> MetaFun (name ++ op_suffix)
                            Just SameOp -> OrigFun
                            Just (ConvertFun fun) -> MetaConvertFun (convertFunName fun)
                            Nothing -> NoEquivalent
    where findMethod eqs | isPrefixOf "D:" name = Just FunSuffix
          findMethod eqs = maybe Nothing (Just . fst . fst) $ Map.minViewWithKey $ Map.filter (elem name) eqs

----------------------------------------------------------------------------------------
-- Meta equivalents methods
----------------------------------------------------------------------------------------

ghcBase :: MetaEquivalentMap
ghcBase = createEquivalentsMap "GHC.Base"
    [(SameOp, ["$", "$!", ".", "id", "const", "$fFunctor[]"]),
     (ConvertFun NoMeta, ["Nothing"]),
     (ConvertFun IdOp, ["Just"]),
     (ConvertFun UnionOp, ["*>", "++", "<$", "$dm<$", "<*", "<*>", ">>"])]

ghcClasses :: MetaEquivalentMap
ghcClasses = createEquivalentsMap "GHC.Classes" []

ghcEnum :: MetaEquivalentMap
ghcEnum = createEquivalentsMap "GHC.Enum" []

ghcErr :: MetaEquivalentMap
ghcErr = createEquivalentsMap "GHC.Err"
    [(ConvertFun NoMetaArgOp, ["error"])]

ghcFloat :: MetaEquivalentMap
ghcFloat = createEquivalentsMap "GHC.Float" []

ghcList :: MetaEquivalentMap
ghcList = createEquivalentsMap "GHC.List"
    [(ConvertFun LeftIdOp, ["!!"])]

ghcNum :: MetaEquivalentMap
ghcNum = createEquivalentsMap "GHC.Num" []

ghcReal :: MetaEquivalentMap
ghcReal = createEquivalentsMap "GHC.Real"
    [(ConvertFun UnionOp, ["^", "^^"])]

ghcShow :: MetaEquivalentMap
ghcShow = createEquivalentsMap "GHC.Show"
    [(FunSuffix, ["show", "showList__", "showsPrec", "$dmshow"])]

ghcTuple :: MetaEquivalentMap
ghcTuple = createEquivalentsMap "GHC.Tuple"
    [(ConvertFun UnionOp, ["(,)"])]

ghcTypes :: MetaEquivalentMap
ghcTypes = createEquivalentsMap "GHC.Types"
    [(ConvertFun NoMeta, ["[]"]),
     (ConvertFun UnionOp, [":"])]
