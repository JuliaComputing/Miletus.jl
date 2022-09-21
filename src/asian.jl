import Dates.Period

struct MovingAveragePrice{C<:Contract,DP<:Period} <: Contract
    c::C
    period::DP
end

AsianFixedStrikeCall(dt::Date, c::Contract, period::Period, strike) =
    European(dt, Buy(MovingAveragePrice(c, period), strike))

AsianFloatingStrikeCall(dt::Date, c::Contract, period::Period, strike) =
    European(dt, Both(c, Give(MovingAveragePrice(c, period))))


function valueat(m::MonteCarloScenario, c::MovingAveragePrice{SingleStock, DP}, i2) where DP
    dt2 = index2date(m, i2)
    dt1 = dt2 - c.period
    i1 = date2index(m, dt1)
    mean(view(m.path, i1:i2))
end