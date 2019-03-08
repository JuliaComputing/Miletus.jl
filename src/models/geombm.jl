"""
    GeomBMModel(startdate, startprice, interestrate, carryrate, volatility)

A model for `SingleStock`, following a geometric Brownian motion.
* `startdate`
* `startprice`: initial price at `startdate`
* `interestrate`: risk free rate of return.
* `carryrate`: the carry rate, i.e. the net return for holding the asset:
  - for stocks this is typically positive (i.e. dividends)
  - for commodities this is typically negative (i.e. cost-of-carry)
* `volatility`:

The `interestrate`, `carryrate` and `volatility` are all specified on a continously compounded, Actual/365 basis.

The price is assumed to follow the PDE:

```math
d S_t = \\kappa S_t dt + \\sigma S_t dW_t
```

or

```math
d \\log S_t = (\\kappa - \\sigma^2/2) dt + \\sigma dW_t
```

where ``W_t`` is a Wiener process, and `κ = interestrate - carryrate`.
"""
struct GeomBMModel{C,V} <: AbstractModel
    core::C
    volatility::V
end

GeomBMModel(startdate, startprice, yieldrate, carryrate, volatility) =
    GeomBMModel(CoreModel(startdate, startprice, yieldrate, carryrate),
                volatility)


numeraire(m::GeomBMModel) = numeraire(m.core)
startdate(m::GeomBMModel) = startdate(m.core)

yearfractionto(m::GeomBMModel, dt::Date) =
    yearfractionto(m.core,  dt)
forwardprice(m::GeomBMModel, s::SingleStock, dt::Date) =
    forwardprice(m.core, s, dt)

value(m::GeomBMModel, c::SingleStock) = value(m.core, c)
value(m::GeomBMModel, c::WhenAt{SingleStock}) = value(m.core, c)
value(m::GeomBMModel, c::WhenAt{Receive{T}}) where {T} = value(m.core,c)

function value(m::GeomBMModel, c::EuropeanCall{SingleStock,T}) where T
    dt = maturitydate(c)
    σ = m.volatility
    black(value(m, WhenAt(dt, SingleStock())),
          value(m, WhenAt(dt, Receive(strikeprice(c)))),
          σ*sqrt(yearfractionto(m, dt)))
end
function value(m::GeomBMModel, c::EuropeanPut{SingleStock,T}) where T
    dt = maturitydate(c)
    σ = m.volatility
    black(value(m, WhenAt(dt, Receive(strikeprice(c)))),
          value(m, WhenAt(dt, SingleStock())),
          σ*sqrt(yearfractionto(m, dt)))
end

# partial derivatives
function black_p1(S′,K′,σ′)
    x  = log(S′/K′)
    d₊ = x/σ′ + σ′/2
    normcdf(d₊)
end
function black_p2(S′,K′,σ′)
    x  = log(S′/K′)
    d₋ = x/σ′ - σ′/2
    -normcdf(d₋)
end
function black_p3(S′,K′,σ′)
    x  = log(S′/K′)
    d₊ = x/σ′ + σ′/2
    S′*normpdf(d₊)
end



function delta(m::GeomBMModel, c::EuropeanCall{SingleStock,T}) where T
    dt = maturitydate(c)
    t = yearfractionto(m, dt)
    S = m.core.startprice
    K = strikeprice(c)
    σ = m.volatility
    iQ = discount(m.core.carrycurve, dt)
    iR = discount(m.core.yieldcurve, dt)
    iQ * black_p1(S*iQ, K*iR, σ*sqrt(t))
end
function delta(m::GeomBMModel, c::EuropeanPut{SingleStock,T}) where T
    dt = maturitydate(c)
    t = yearfractionto(m, dt)
    S = m.core.startprice
    K = strikeprice(c)
    σ = m.volatility
    iQ = discount(m.core.carrycurve, dt)
    iR = discount(m.core.yieldcurve, dt)
    iQ * black_p2(K*iR, S*iQ, σ*sqrt(t))
end

function vega(m::GeomBMModel, c::EuropeanCall{SingleStock,T}) where T
    dt = maturitydate(c)
    t = yearfractionto(m, dt)
    S = m.core.startprice
    K = strikeprice(c)
    σ = m.volatility
    sqrt(t) * black_p3(S*discount(m.core.carrycurve, dt), K*discount(m.core.yieldcurve, dt), σ*sqrt(t))
end
function vega(m::GeomBMModel, c::EuropeanPut{SingleStock,T}) where T
    dt = maturitydate(c)
    t = yearfractionto(m, dt)
    S = m.core.startprice
    K = strikeprice(c)
    σ = m.volatility
    sqrt(t) * black_p3(K*discount(m.core.yieldcurve, dt), S*discount(m.core.carrycurve, dt), σ*sqrt(t))
end


ivol(m::GeomBMModel, c::Contract) = m.volatility


"""
    ivol(m::CoreModel, c::Contract, price)

Compute the Black-Scholes implied volatility of contract `c` at `price`, under the assumptions of model `m` (ignoring the volatility value of `m`).

See also: `fit`
"""
function ivol(m::CoreModel, c::EuropeanCall{SingleStock,T}, price) where T
    dt = maturitydate(c)
    t = yearfractionto(m, dt)
    S = m.startprice
    K = strikeprice(c)
    black_ivol(S*discount(m.carrycurve, dt), K*discount(m.yieldcurve, dt), price)/sqrt(t)
end
function ivol(m::CoreModel, c::EuropeanPut{SingleStock,T}, price) where T
    dt = maturitydate(c)
    t = yearfractionto(m, dt)
    S = m.startprice
    K = strikeprice(c)
    black_ivol(K*discount(m.yieldcurve, dt), S*discount(m.carrycurve, dt), price)/sqrt(t)
end


function ivol(m::CoreForwardModel, c::EuropeanCall{SingleStock,T}, price) where T
    dt = maturitydate(c)
    t = yearfractionto(m, dt)
    F = forwardprice(m, SingleStock(), dt)
    K = strikeprice(c)
    D = discount(m.yieldcurve, dt)
    black_ivol(F*D, K*D, price)/sqrt(t)
end
function ivol(m::CoreForwardModel, c::EuropeanPut{SingleStock,T}, price) where T
    dt = maturitydate(c)
    t = yearfractionto(m, dt)
    F = forwardprice(m, SingleStock(), dt)
    K = strikeprice(c)
    D = discount(m.yieldcurve, dt)
    black_ivol(K*D, F*D, price)/sqrt(t)
end



"""
    fit(GeomBMModel, m::Union{CoreModel,CoreForwardModel}, c::Contract, price)

Fit a `GeomBMModel` using the implied volatility of `c` at `price`, using the parameters
of `m`.

See also: `ivol`
"""
fit(::Type{GeomBMModel}, mcore::AbstractCoreModel, c::Union{EuropeanCall{SingleStock,T},EuropeanPut{SingleStock,T}}, price) where {T} =
    GeomBMModel(mcore, ivol(mcore, c, price))
