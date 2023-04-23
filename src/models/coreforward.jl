"""
    CoreForwardModel(forwarddates, forwardprices, yieldcurve)

Specifies the value of a `SingleStock` in terms of its forward prices.

* `forwarddates`: ordered dates for which forward prices are available
* `forwardprices`: forward prices of the asset
* `yieldcurve`: risk-free discount curve
"""
struct CoreForwardModel{DT <: AbstractVector, T, S<:YieldTermStructure} <: AbstractCoreModel
    forwarddates::DT
    forwardprices::Vector{T}
    yieldcurve::S
end

CoreForwardModel(startdate, forwarddates, forwardprices::Vector{T}, yieldrate::Float64) where {T} =
    CoreForwardModel(forwarddates, forwardprices,
                     ConstantContinuousYieldCurve(Actual365(), yieldrate, startdate))


CoreForwardModel(startdate, forwarddate, forwardprice, yieldrate::Float64) =
    CoreForwardModel(startdate, [forwarddate], [forwardprice], yieldrate)

numeraire(m::CoreForwardModel) = unit(m.forwardprices[1])
startdate(m::CoreForwardModel) = startdate(m.yieldcurve)

yearfractionto(m::CoreForwardModel, dt::Date) =
    yearfraction(daycount(m.yieldcurve),  startdate(m),  dt)

yearfractionto(m::CoreForwardModel, dt) =
    dt - startdate(m)

function value(m::CoreForwardModel, c::WhenAt{Receive{T}}) where T
    value(m, c.c) * discount(m.yieldcurve, maturitydate(c))
end

function date2index(m::CoreForwardModel, dt)
    ii = searchsorted(m.forwarddates, dt)
    isempty(ii) && throw(DomainError())
    return ii[1]
end

forwardprice(m::CoreForwardModel, ::SingleStock, dt) =
    m.forwardprices[date2index(m, dt)]

function value(m::CoreForwardModel, c::SingleStock)
    forwardprice(m, c, startdate(m))
end
function value(m::CoreForwardModel, c::WhenAt{SingleStock})
    dt = maturitydate(c)
    forwardprice(m, c.c, dt) * discount(m.yieldcurve, dt)
end
