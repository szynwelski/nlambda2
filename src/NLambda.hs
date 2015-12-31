{-# LANGUAGE CPP #-}
{-# OPTIONS_HADDOCK prune #-}
{-|
Module:         NLambda
Description:    Module for computations over infinite structures.

Module supports computations over infinite structures using logical formulas and SMT solving.
-}
module NLambda
(
-- * Formula
-- ** Variable
module Nominal.Variable,
-- ** Type
module Nominal.Formula,
-- * Nominal type
NominalType(eq), neq,
-- * Conditional
module Nominal.Conditional,
-- * Contextual
module Nominal.Contextual,
-- * Variants
module Nominal.Variants,
-- ** Atom
module Nominal.Atom,
module Nominal.AtomsSpace,
-- ** Either
module Nominal.Either,
-- ** Maybe
module Nominal.Maybe,
-- * Nominal set
module Nominal.Set,
-- * Group action, support and orbits
module Nominal.Orbit,
-- * Graph
module Nominal.Graph,
-- * Automaton
module Nominal.Automaton.Base,
-- ** Deterministic automaton
module Nominal.Automaton.Deterministic,
-- ** Nondeterministic automaton
module Nominal.Automaton.Nondeterministic,
-- Example atoms
a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z
)
where

#if TOTAL_ORDER
import Nominal.Atom
#else
import Nominal.Atom hiding (lt, le, gt, ge)
#endif
import Nominal.AtomsSpace
import Nominal.Automaton.Base
import Nominal.Automaton.Deterministic
import Nominal.Automaton.Nondeterministic
import Nominal.Conditional
import Nominal.Contextual
import Nominal.Either
#if TOTAL_ORDER
import Nominal.Formula hiding (foldFormulaVariables, mapFormulaVariables)
#else
import Nominal.Formula hiding (foldFormulaVariables, mapFormulaVariables, lessThan, lessEquals, greaterThan, greaterEquals)
#endif
#if TOTAL_ORDER
import Nominal.Graph
#else
import Nominal.Graph hiding (monotonicGraph)
#endif
import Nominal.Maybe
import Nominal.Orbit
import Nominal.Set
import Nominal.Type (NominalType(eq), neq)
import Nominal.Variable (Variable, variable, variableName)
import Nominal.Variants (Variants, variant, fromVariant, iteV, iteV')
import Prelude hiding (or, and, not, sum, map, filter, maybe)

----------------------------------------------------------------------------------------------------
-- Examples
----------------------------------------------------------------------------------------------------
a = atom "a"
b = atom "b"
c = atom "c"
d = atom "d"
e = atom "e"
f = atom "f"
g = atom "g"
h = atom "h"
i = atom "i"
j = atom "j"
k = atom "k"
l = atom "l"
m = atom "m"
n = atom "n"
o = atom "o"
p = atom "p"
q = atom "q"
r = atom "r"
s = atom "s"
t = atom "t"
u = atom "u"
v = atom "v"
w = atom "w"
x = atom "x"
y = atom "y"
z = atom "z"

-- example program

nlProgram = do
    a <- newAtom
    b <- newAtom
    return $ let set = delete a atoms
             in delete b set
