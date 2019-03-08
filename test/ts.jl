using Miletus.TermStructure
using Miletus.DayCounts
using Dates
using Test

@test 1.7    ≈ compound_factor(0.7, :Compounded, Miletus.TermStructure.Annual, Actual360(), today(), today()+Day(360))
@test 1.35^2 ≈ compound_factor(0.7, :Compounded, Miletus.TermStructure.Semiannual, Actual360(), today(), today()+Day(360))

@test 1/1.7  ≈ discount_factor(0.7, :Compounded, Miletus.TermStructure.Annual, Actual360(), today(), today()+Day(360))

d=ConstantYieldCurve(Actual360(), 0.2, :Continuous, :NoFrequency, today())

d=ConstantYieldCurve(Actual360(), 0.2, :Continuous, :NoFrequency, today())
@test 1/exp(0.2) ≈ d[today()+Day(360)]


@test forward_rate(d, today()+Day(360), today()+Day(360)) - 0.2 < 10e-10
forward_rate(d, Date(2016, Dec, 1), Date(2016, Dec, 31))
