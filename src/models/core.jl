import .DayCounts: yearfraction, Actual365, DateRoll, adjust
import .TermStructure: YieldTermStructure, ConstantContinuousYieldCurve, discount, startdate, frequency, compounding, daycount


struct SingleStock <: Contract
    identifier::String
end
SingleStock() = SingleStock("")
isequal(s1::SingleStock, s2::SingleStock) = isequal(s1.identifier, s2.identifier) 

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

The `yieldcurve` and `carryrate` are all specified on a continously compounded, Actual/365 basis.

The exact dynamics of the model are unspecified, but has the property that

```math
E[S_t] = S_0 \\times e^{(r-q)t}
```

"""
struct CoreModel{T, S<:YieldTermStructure, R<:YieldTermStructure} <: AbstractCoreModel
    startprices::Dict{SingleStock,T}
    yieldcurve::S
    carrycurve::R
end

function CoreModel(startprice::T, yieldcurve::S, carryrate::Float64=0.0) where {T, S}
    CoreModel(Dict(SingleStock() => startprice), yieldcurve,
              ConstantContinuousYieldCurve(daycount(yieldcurve), carryrate, startdate(yieldcurve)))
end

function CoreModel(startdate::Date, startprice::T, yieldrate::V, carryrate::Float64=0.0) where {T,V}
    CoreModel(Dict(SingleStock() => startprice),
              ConstantContinuousYieldCurve(Actual365(), yieldrate, startdate),
              ConstantContinuousYieldCurve(Actual365(), carryrate, startdate))
end

function CoreModel(startprices::Dict{SingleStock,T}, yieldcurve::S, carryrate::Float64=0.0) where {T, S}
    if isempty(startprices)
        error("CoreModel needs to contain at least one stock to startprice mapping.")
    end
    CoreModel(startprices, yieldcurve,
              ConstantContinuousYieldCurve(daycount(yieldcurve), carryrate, startdate(yieldcurve)))
end

function CoreModel(startdate::Date, startprices::Dict{SingleStock,T}, yieldrate::V, carryrate::Float64=0.0) where {T,V}
    if isempty(startprices)
        error("CoreModel needs to contain at least one stock to startprice mapping.")
    end
    CoreModel(startprices,
              ConstantContinuousYieldCurve(Actual365(), yieldrate, startdate),
              ConstantContinuousYieldCurve(Actual365(), carryrate, startdate))
end


numeraire(m::CoreModel) = unit(first(values(m.startprices))) 
#first is save here, because we make sure that startprices are non empty in the constructor.
# TODO (drsk): we just take the numeraire of the first singlestock. We need to deal with multiple currencies.
startdate(m::CoreModel) = startdate(m.yieldcurve)

yearfractionto(m::CoreModel, dt::Date) = 
    yearfraction(daycount(m.yieldcurve),  startdate(m.yieldcurve),  dt)

function value(m::CoreModel, c::WhenAt{Receive{T}}) where T
    value(m, c.c) * discount(m.yieldcurve, maturitydate(c))
end

value(m::CoreModel, c::SingleStock) = m.startprices[c]
function value(m::CoreModel, c::WhenAt{SingleStock})
    m.startprices[c.c] * discount(m.carrycurve, maturitydate(c))
end

function forwardprice(m::CoreModel, c::SingleStock, dt::Date)
    m.startprices[c] * discount(m.carrycurve, dt) / discount(m.yieldcurve, dt)
end

"""A model for the time value of money
"""
struct YieldModel{S<:YieldTermStructure, T<:DateRoll, U<:HolidayCalendar} <: AbstractModel
    yieldcurve::S
    dateroll::T
    holidaycalendar::U
end

value(m::YieldModel, c::When{At, Receive{T}}) where {T} = value(m, c.c) * discount(m.yieldcurve, adjust(m.dateroll, m.holidaycalendar, maturitydate(c)))
