# Miletus.jl

[![Build Status](https://travis-ci.org/JuliaComputing/Miletus.jl.svg?branch=master)](https://travis-ci.org/JuliaComputing/Miletus.jl)

*Miletus* is a financial contract modelling language written in Julia, based on papers by Peyton Jones and Eber [[PJ&E2000]](#PJE2000),[[PJ&E2003]](#PJE2003) (more closely modelled on the second one).


```julia
using Miletus
using Dates: today, Day

s = SingleStock()

d1 = today()
d2 = d1 + Day(120)

# Arguments: Date, Stock, Strike
eucall = EuropeanCall(d2, s, 100.00)
euput  = EuropeanPut(d2, s, 100.00)
amcall = AmericanCall(d2, s, 100.00)
amput  = AmericanPut(d2, s, 100.00)

m = GeomBMModel(d1, 100.00, 0.05, 0.0, 0.1)
value(m, eucall)
value(m, euput)

m = CRRModel(d1,d2,100, 100.00, 0.05, 0.0, 0.1)
value(m, eucall)
value(m, euput)
value(m, amcall)
value(m, amput)
```

# References

* <a id="PJE2000">[PJ&E2000]</a>: Simon Peyton Jones and Jean-Marc Eber, ["Composing contracts: an adventure in financial engineering"](http://research.microsoft.com/en-us/um/people/simonpj/Papers/financial-contracts/contracts-icfp.htm). Julian Seward. ICFP 2000. 

* <a id="PJE2003">[PJ&E2003]</a>: Simon Peyton Jones and Jean-Marc Eber, ["How to write a financial contract"](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.14.7885), in "The Fun of Programming", ed Gibbons and de Moor, Palgrave Macmillan 2003.



