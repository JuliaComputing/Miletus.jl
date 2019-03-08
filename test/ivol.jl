using Test
using Miletus

using Miletus.TermStructure
using Miletus.DayCounts

yc = ConstantYieldCurve(Actual365(), 0.01, :Continuous, :NoFrequency, Date("2016-11-01"))
core = CoreModel(40.00, yc, 0.0)
eucall = EuropeanCall(Date("2016-11-25"), SingleStock(), 41.00)
euput = EuropeanPut(Date("2016-11-25"), SingleStock(), 41.00)

σ = ivol(core, eucall, 1.5)
m = fit(GeomBMModel, core, eucall, 1.5)

@test m.volatility == σ
@test value(m, eucall) ≈ 1.5


coref = CoreForwardModel([Date("2016-11-25")], [42.0], yc)

σf = ivol(coref, eucall, 1.5)
mf = fit(GeomBMModel, coref, eucall, 1.5)

@test mf.volatility == σf
@test value(mf, eucall) ≈ 1.5


σ = ivol(core, euput, 1.5)
m = fit(GeomBMModel, core, euput, 1.5)

@test m.volatility == σ
@test value(m, euput) ≈ 1.5

let
    d1 = Dates.today()
    d2 = d1 + Day(365)                                                              
    c = EuropeanCall(d2, SingleStock(), 147.32)                                     
    core = CoreModel(d1, 157.32, 0.01, 0.01)                                        
    gbm = GeomBMModel(core, 0.1) 
    v = ivol(core, c, 12, TianModel)
    gbm2 = GeomBMModel(core, v)
    @test isapprox(value(gbm2, c), 12, rtol = 1e-2)
    v = ivol(core, c, 12, CRRModel)
    gbm2 = GeomBMModel(core, v)
    @test isapprox(value(gbm2, c), 12, rtol = 1e-2)
    v = ivol(core, c, 12, JRModel)
    gbm2 = GeomBMModel(core, v)
    @test isapprox(value(gbm2, c), 12, rtol = 1e-2)
end
