@testset "yield curve & fixed income" begin
    using Miletus
    using Miletus.TermStructure
    
    import Miletus: Both, Receive, Contract, When, At, value
    import Miletus: YieldModel
    using Miletus.DayCounts
    
    import BusinessDays: USGovernmentBond
    import Dates: today, days, Day, Year
    
    
    # test yield curve and coupon bond example from documentation with both dates and time

    function couponbond(par,coupon,periods::Int,start,expiry)
        duration = expiry - start
        bond = When(At(expiry), Receive(par))
        for p = periods-1:-1:1
            coupondate = start + duration*p/periods
            bond = Both(bond,When(At(coupondate), Receive(coupon)))
        end
        return bond
    end
    
    par = 100USD
    coupon = 1USD
    periods = 12
    
    datesets = [
    (desc = "dates", d1 = today(),d2 = today()+Day(360)),
    (desc = "times", d1 = 0.,d2 = 1.),
    ]
    
    startdate = datesets[2].d1
    expirydate = datesets[2].d2
    cpb = couponbond(par,coupon,periods,startdate,expirydate)
    yc = ConstantYieldCurve(.1, :Continuous, :NoFrequency, 0.)
    ym = YieldModel(yc) 
    @test value(ym,cpb) ≈ (sum(1*exp(-.1*(i/12)) for i in 1:11) + 100*exp(-.1))USD
    
    startdate = datesets[1].d1
    expirydate = datesets[1].d2
    cpb = couponbond(par,coupon,periods,startdate,expirydate)
    yc = ConstantYieldCurve(Actual360(), .1, :Continuous, :NoFrequency, Dates.today())
    ym = YieldModel(yc, ModFollowing(), USGovernmentBond())
    @test value(ym,cpb) ≈ 100.95033872353186USD
    
    
end