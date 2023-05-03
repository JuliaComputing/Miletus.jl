using Test
using Miletus

using Miletus.TermStructure
using Miletus.DayCounts

@testset "Implied Volatility" begin
    datesets = [
    (testdesc = "Dates", d1 = Date("2016-11-01"),d2 = Date("2016-11-25")),
    (testdesc = "Real times", d1 = 0.,d2 = 25/365,)
    ]
    
    @testset "Implied Volatility - $(ds.testdesc)" for ds in datesets
        d1, d2 = ds.d1, ds.d2
        yc = ConstantYieldCurve(Actual365(), 0.01, :Continuous, :NoFrequency, d1)
        core = CoreModel(40.00, yc, 0.0)
        eucall = EuropeanCall(d2, SingleStock(), 41.00)
        euput = EuropeanPut(d2, SingleStock(), 41.00)
        
        σ = ivol(core, eucall, 1.5)
        m = fit(GeomBMModel, core, eucall, 1.5)
        
        @test m.volatility == σ
        @test value(m, eucall) ≈ 1.5
        
        
        coref = CoreForwardModel([d2], [42.0], yc)
        
        σf = ivol(coref, eucall, 1.5)
        mf = fit(GeomBMModel, coref, eucall, 1.5)
        
        @test mf.volatility == σf
        @test value(mf, eucall) ≈ 1.5
        
        
        σ = ivol(core, euput, 1.5)
        m = fit(GeomBMModel, core, euput, 1.5)
        
        @test m.volatility == σ
        @test value(m, euput) ≈ 1.5
        

    end
    datesets = [
        (testdesc = "Dates", d1 = today(),d2 = today()+Day(365)),
        (testdesc = "Real times", d1 = 0.,d2 = 365/365),
        ]
    @testset "with Models - $(ds.testdesc)" for ds in datesets
        d1, d2 = ds.d1, ds.d2
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
end