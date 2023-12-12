import .DayCounts: yearfraction, Actual365, DateRoll, adjust
import .TermStructure: YieldTermStructure, ConstantContinuousYieldCurve, discount, startdate, frequency, compounding, daycount


struct SingleStock <: Contract
end

abstract type AbstractCoreModel <: AbstractModel 

end

"""
    CoreModel(startdate, startprice, interestrate, carryrate)

Contains the core parameters for the model of `SingleStock`:
* `startprice`: initial price at `startdate`
* `yieldcurve`: risk free rate of return for the numeraire.
* `carrycurve`: the carry rate, i.e. the net income for holding the asset:
  - for stocks this is typically positive (i.e. dividends)
  - for commodities this is typically negative (i.e. cost-of-carry)

The `yieldcurve` and `carryrate` are all specified on a continuously compounded, Actual/365 basis.

The exact dynamics of the model are unspecified, but has the property that

```math
E[S_t] = S_0 \\times e^{(r-q)t}
```

"""
struct CoreModel{T, S<:YieldTermStructure, R<:YieldTermStructure} <: AbstractCoreModel
    startprice::T
    yieldcurve::S
    carrycurve::R
end

CoreModel(startprice::T, yieldcurve::S, carryrate::Float64=0.0) where {T, S} =
    CoreModel(startprice, yieldcurve,
              ConstantContinuousYieldCurve(daycount(yieldcurve), carryrate, startdate(yieldcurve)))

CoreModel(startdate::Date, startprice::T, yieldrate::V, carryrate::Float64=0.0) where {T,V} =
    CoreModel(startprice,
              ConstantContinuousYieldCurve(Actual365(), yieldrate, startdate),
              ConstantContinuousYieldCurve(Actual365(), carryrate, startdate))
CoreModel(startdate::U, startprice::T, yieldrate::V, carryrate::Float64=0.0) where {U,T,V} =
    CoreModel(startprice,
              ConstantContinuousYieldCurve(yieldrate, 0.),
              ConstantContinuousYieldCurve(carryrate, 0.))


numeraire(m::CoreModel) = unit(m.startprice)
startdate(m::CoreModel) = startdate(m.yieldcurve)

yearfractionto(m::CoreModel, dt::Date) =
    yearfraction(daycount(m.yieldcurve),  startdate(m.yieldcurve),  dt)
yearfractionto(m::CoreModel, dt) =
    dt - startdate(m.yieldcurve)

function value(m::CoreModel, c::WhenAt{Receive{T}}) where T
    value(m, c.c) * discount(m.yieldcurve, maturitydate(c))
end

value(m::CoreModel, c::SingleStock) = m.startprice
function value(m::CoreModel, c::WhenAt{SingleStock})
    m.startprice * discount(m.carrycurve, maturitydate(c))
end

function forwardprice(m::CoreModel, ::SingleStock, dt::Date)
    m.startprice * discount(m.carrycurve, dt) / discount(m.yieldcurve, dt)
end

"""A model for the time value of money
"""
struct YieldModel{S<:YieldTermStructure, T<:Union{DateRoll,Nothing}, U<:Union{HolidayCalendar,Nothing}} <: AbstractModel
    yieldcurve::S
    dateroll::T
    holidaycalendar::U
    function YieldModel(yc::S,dr::T=nothing,hc::U=nothing) where {S,T,U}
        return new{S,T,U}(yc,dr,hc)
    end
end

value(m::YieldModel, c::When{A, Receive{T}}) where {A<:At,T} = value(m.dateroll,m,c)
value(dateroll::Nothing,m::YieldModel, c::When{A, Receive{T}}) where {A,T} = value(m, c.c) * discount(m.yieldcurve, maturitydate(c))
value(dateroll,m::YieldModel, c::When{A, Receive{T}}) where {A,T} = value(m, c.c) * discount(m.yieldcurve, adjust(m.dateroll, m.holidaycalendar, maturitydate(c)))
