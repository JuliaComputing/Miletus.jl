using Test
using Miletus
using Dates: today, Day

using CSV, DataFrames

s = SingleStock()
d1 = today()

bs = CSV.read("bs.csv")

# 1. Test with floats
calls = EuropeanCall.(d1 .+ Day.(bs[:days]), [s], float.(bs[:strikeprice]))
puts = EuropeanPut.(d1 .+ Day.(bs[:days]), [s], float.(bs[:strikeprice]))
m = GeomBMModel.([d1], float.(bs[:startprice]), bs[:interestrate], bs[:carryrate], bs[:sigma])

atol=1e-6; rtol=1e-3

@test all(isapprox.(value.(m,calls), bs[:c], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,puts), bs[:p],  rtol=rtol,atol=atol))

# @test all(isapprox.(ivol.(m,calls,value.(m,calls)), bs[:sigma]))

crr = CSV.read("crr.csv")

eucalls = EuropeanCall.(d1 .+ Dates.Day.(crr[:days]), [s], float.(crr[:strikeprice]))
euputs  = EuropeanPut.(d1 .+ Dates.Day.(crr[:days]), [s], float.(crr[:strikeprice] ))
amcalls = AmericanCall.(d1 .+ Dates.Day.(crr[:days]), [s], float.(crr[:strikeprice]))
amputs  = AmericanPut.(d1 .+ Dates.Day.(crr[:days]), [s], float.(crr[:strikeprice] ))

m = CRRModel.(d1, d1 .+ Dates.Day.(crr[:days]), crr[:nsteps], float.(crr[:startprice]), crr[:interestrate], crr[:carryrate], crr[:sigma])

@test all(isapprox.(value.(m,eucalls) , crr[:ce], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,euputs)  , crr[:pe], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amcalls) , crr[:ca], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amputs)  , crr[:pa], rtol=rtol,atol=atol))

tian = CSV.read("tian.csv")

eucalls = EuropeanCall.(d1 .+ Dates.Day.(tian[:days]), [s], float.(tian[:strikeprice]))
euputs  = EuropeanPut.(d1 .+ Dates.Day.(tian[:days]), [s], float.(tian[:strikeprice] ))
amcalls = AmericanCall.(d1 .+ Dates.Day.(tian[:days]), [s], float.(tian[:strikeprice]))
amputs  = AmericanPut.(d1 .+ Dates.Day.(tian[:days]), [s], float.(tian[:strikeprice] ))

m = TianModel.([d1],d1 .+ Dates.Day.(tian[:days]), tian[:nsteps], float.(tian[:startprice]), tian[:interestrate], tian[:carryrate], tian[:sigma])

@test all(isapprox.(value.(m,eucalls) , tian[:ce], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,euputs)  , tian[:pe], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amcalls) , tian[:ca], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amputs)  , tian[:pa], rtol=rtol,atol=atol))


# 2. Test with currencies
calls = EuropeanCall.(d1 .+ Day.(bs[:days]), [s], float.(bs[:strikeprice].*[USD]))
puts = EuropeanPut.(d1 .+ Day.(bs[:days]), [s], float.(bs[:strikeprice].*[USD]))
m = GeomBMModel.([d1], float.(bs[:startprice].*[USD]), bs[:interestrate], bs[:carryrate], bs[:sigma])

atol=1e-6; rtol=1e-3

@test all(isapprox.(value.(m,calls) ./ [USD], bs[:c], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,puts) ./ [USD], bs[:p],  rtol=rtol,atol=atol))

crr = CSV.read("crr.csv")

eucalls = EuropeanCall.(d1 .+ Dates.Day.(crr[:days]), [s], float.(crr[:strikeprice] .* [USD]))
euputs  = EuropeanPut.(d1 .+ Dates.Day.(crr[:days]), [s], float.(crr[:strikeprice] .* [USD]))
amcalls = AmericanCall.(d1 .+ Dates.Day.(crr[:days]), [s], float.(crr[:strikeprice] .* [USD]))
amputs  = AmericanPut.(d1 .+ Dates.Day.(crr[:days]), [s], float.(crr[:strikeprice] .* [USD]))


m = CRRModel.([d1],d1 .+ Dates.Day.(crr[:days]), crr[:nsteps], float.(crr[:startprice].*[USD]), crr[:interestrate], crr[:carryrate], crr[:sigma])

@test all(isapprox.(value.(m,eucalls) ./ [USD], crr[:ce], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,euputs)  ./ [USD], crr[:pe], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amcalls) ./ [USD], crr[:ca], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amputs)  ./ [USD], crr[:pa], rtol=rtol,atol=atol))

tian = CSV.read("tian.csv")

eucalls = EuropeanCall.(d1 .+ Dates.Day.(tian[:days]), [s], float.(tian[:strikeprice] .* [USD]))
euputs  = EuropeanPut.(d1 .+ Dates.Day.(tian[:days]), [s], float.(tian[:strikeprice] .* [USD]))
amcalls = AmericanCall.(d1 .+ Dates.Day.(tian[:days]), [s], float.(tian[:strikeprice] .* [USD]))
amputs  = AmericanPut.(d1 .+ Dates.Day.(tian[:days]), [s], float.(tian[:strikeprice] .* [USD]))


m = TianModel.([d1],d1 .+ Dates.Day.(tian[:days]), tian[:nsteps], float.(tian[:startprice].*[USD]), tian[:interestrate], tian[:carryrate], tian[:sigma])

@test all(isapprox.(value.(m,eucalls) ./ [USD], tian[:ce], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,euputs)  ./ [USD], tian[:pe], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amcalls) ./ [USD], tian[:ca], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amputs)  ./ [USD], tian[:pa], rtol=rtol,atol=atol))

jr = CSV.read("jr.csv")

eucalls = EuropeanCall.(d1 .+ Dates.Day.(jr[:days]), [s], float.(jr[:strikeprice] .* [USD]))
euputs  = EuropeanPut.(d1 .+ Dates.Day.(jr[:days]), [s], float.(jr[:strikeprice] .* [USD]))
amcalls = AmericanCall.(d1 .+ Dates.Day.(jr[:days]), [s], float.(jr[:strikeprice] .* [USD]))
amputs  = AmericanPut.(d1 .+ Dates.Day.(jr[:days]), [s], float.(jr[:strikeprice] .* [USD]))


m = JRModel.([d1],d1 .+ Dates.Day.(jr[:days]), jr[:nsteps], float.(jr[:startprice].*[USD]), jr[:interestrate], jr[:carryrate], jr[:sigma])

@test all(isapprox.(value.(m,eucalls) ./ [USD], jr[:ce], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,euputs)  ./ [USD], jr[:pe], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amcalls) ./ [USD], jr[:ca], rtol=rtol,atol=atol))
@test all(isapprox.(value.(m,amputs)  ./ [USD], jr[:pa], rtol=rtol,atol=atol))

# Test Black-76 model
d2 = d1 + Day(120)
cm = CoreForwardModel(d1, d2, 110.00USD, 0.02)
m = GeomBMModel(cm, 0.3)
o = EuropeanCall( d2, s, 100.00USD)
@test isapprox(value(m,o), 13.1833USD, rtol=1e-5)
