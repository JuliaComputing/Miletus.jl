using Miletus.TermStructure
using Miletus.DayCounts
using Dates
using Test

datesets = [
(testdesc = "Dates", d1 = today(),d2 = today()+Day(360)),
(testdesc = "Real times", d1 = 0.,d2 = 360/360,)
]

@testset "Term Structure - $(ds.testdesc)" for ds in datesets[1:1]
    d1, d2 = ds.d1, ds.d2
    @test 1.7    ≈ compound_factor(0.7, :Compounded, Miletus.TermStructure.Annual, Actual360(), d1, d2)
    @test 1.35^2 ≈ compound_factor(0.7, :Compounded, Miletus.TermStructure.Semiannual, Actual360(), d1, d2)
    
    @test 1/1.7  ≈ discount_factor(0.7, :Compounded, Miletus.TermStructure.Annual, Actual360(), d1, d2)
    
    d=ConstantYieldCurve(Actual360(), 0.2, :Continuous, :NoFrequency, d1)
    
    d=ConstantYieldCurve(Actual360(), 0.2, :Continuous, :NoFrequency, d1)
    @test 1/exp(0.2) ≈ d[d2]
    
    
    @test forward_rate(d, d2, d2) - 0.2 < 10e-10
end

@testset "Term Structure - $(ds.testdesc)" for ds in datesets[2:2]
    d1, d2 = ds.d1, ds.d2
    @test 1.7    ≈ compound_factor(0.7, :Compounded, Miletus.TermStructure.Annual, d1, d2)
    @test 1.35^2 ≈ compound_factor(0.7, :Compounded, Miletus.TermStructure.Semiannual, d1, d2)
    
    @test 1/1.7  ≈ discount_factor(0.7, :Compounded, Miletus.TermStructure.Annual, d1, d2)
    
    d=ConstantYieldCurve(0.2, :Continuous, :NoFrequency, d1)
    
    d=ConstantYieldCurve(0.2, :Continuous, :NoFrequency, d1)
    @test 1/exp(0.2) ≈ d[d2]
    
    
    @test forward_rate(d, d2, d2) - 0.2 < 10e-10
end