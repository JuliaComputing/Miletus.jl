using Miletus, Dates
using Test

import Miletus: WhenAt, ConstObs, ValueObs, LiftObs
using Miletus.Currency
using Miletus.Currency: @defcurrency

d1 = today()
d2 = d1 + Day(120)

# without currency
m = GeomBMModel(d1, 100.00, 0.05, 0.0, 0.3)
crrm = CRRModel(d1, d2, 500, 100.00, 0.05, 0.0, 0.3)
mcm = montecarlo(m, d1:Day(1):d2, 10_000)

c = WhenAt(d2, SingleStock())
@test isapprox(value(m, c), value(mcm, c), rtol=1e-2)

o = EuropeanCall(d2, SingleStock(), 100.00)
@test isapprox(value(m, o), value(mcm, o), rtol=0.013*4) # std(y)/mean(y) = 0.013
@test isapprox(value(m, o), value(m, o, MonteCarloModel, 10_000), rtol=0.013*4) # std(y)/mean(y) = 0.013

o = AmericanPut(d2, SingleStock(), 90.0)
@test isapprox(value(crrm, o), value(m, o, LeastSquaresMonteCarlo, 10_000, 3), rtol=0.013*4)



# with currency
m = GeomBMModel(d1, 100.00USD, 0.05, 0.0, 0.3)
mcm = montecarlo(m, d1:Day(1):d2, 10_000)

c = WhenAt(d2, SingleStock())
@test isapprox(value(m, c), value(mcm, c), rtol=1e-2)

o = EuropeanCall(d2, SingleStock(), 100.00USD) # std(y)/mean(y) = 0.013
@test isapprox(value(m, o), value(mcm, o), rtol=0.013*4)

# barrier options
@defcurrency CHF

initialFixing = Date("2020-12-15")
maturity = Date("2023-12-15")
faceValue = 1000CHF

smi = SingleStock()

euput = EuropeanPut(maturity, smi, 100.00CHF)
bond = ZCB(maturity, faceValue)
knockedIn = LiftObs(<, ConstObs(1.0CHF), ValueObs{SingleStock, CurrencyQuantity{CurrencyUnit{:CHF}, Float64}}(smi))
brc = Both(bond, Anytime(knockedIn, Give(euput)))
m = GeomBMModel(initialFixing, faceValue, 0.05, 0.0, 0.3)
mcm = montecarlo(m, initialFixing:Day(1):maturity, 10_000)
@test isapprox(value(mcm, brc), 860.70CHF, rtol=1e-2)
