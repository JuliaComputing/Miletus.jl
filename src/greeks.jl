_vega_model(m::GeomBMModel) = GeomBMModel(m.core, Dual(m.volatility, 1))

_delta_model(m::CoreModel) = CoreModel(Dual(m.startprice, 1), m.yieldcurve, m.carrycurve)
_delta_model(m::GeomBMModel) = GeomBMModel(_delta_model(m.core), m.volatility)

_gamma_model(m::CoreModel) = CoreModel(Dual(Dual(m.startprice, 1), 1), m.yieldcurve, m.carrycurve)
_gamma_model(m::GeomBMModel) = GeomBMModel(_gamma_model(m.core), m.volatility)


_rho_model(y::ConstantContinuousYieldCurve) =
    ConstantContinuousYieldCurve(y.dc, Dual(y.rate,1), y.reference_date)
_rho_model(m::CoreModel) =
    CoreModel(m.startprice, _rho_model(m.yieldcurve), m.carrycurve)
_rho_model(m::GeomBMModel) = GeomBMModel(_rho_model(m.core), m.volatility)


"""
    vega(m::GeomBMModel, c::Contract)
    vega(m::GeomBMModel, c::Contract, MonteCarloModel, npaths::Integer)

Calculate the vega Greek: the first derivative of the option price
with respect to volatility for the contract `c` under the model `m`

Inputs
======

* `m::GeomBMModel` - The model under which the contract is being valued
* `c::Contract` - The contract whose Greek is desired.
* `npaths::Integer` - Number of Monte Carlo paths to use.
"""
function vega(m::GeomBMModel, c::Contract, args...; autodiff=true)
    val = value(_vega_model(m), c, args...)
    extract_derivative(val)
end 

"""
    delta(m::GeomBMModel, c::Contract)
    delta(m::GeomBMModel, c::Contract, MonteCarloModel, npaths::Integer)

Calculate the delta Greek: the first derivative of the option price with respect to the
spot price of the underlying for the contract `c` under the model `m`

Inputs
======

* `m::GeomBMModel` - The model under which the contract is being valued
* `c::Contract` - The contract whose greek is desired.
* `npaths::Integer` - Number of Monte Carlo paths to use.
"""
function delta(m::GeomBMModel, c::Contract, args...; autodiff=true)
    val = value(_delta_model(m), c, args...)
    deriv = extract_derivative(val)
    currval(deriv)
end

"""
    rho(m::GeomBMModel, c::Contract)
    rho(m::GeomBMModel, c::Contract, MonteCarloModel, npaths::Integer)

Calculate the rho Greek: the first derivative of the option price with respect to the
interest rate, for the contract `c` under the model `m`

Inputs
======

* `m::GeomBMModel` - The model under which the contract is being valued
* `c::Contract` - The contract whose greek is desired.
* `npaths::Integer` - Number of Monte Carlo paths to use.
"""
function rho(m::GeomBMModel, c::Contract, args...; autodiff=true)
    val = value(_rho_model(m), c, args...)
    deriv = extract_derivative(val)
end


"""
    gamma(m::GeomBMModel, c::Contract)
    gamma(m::GeomBMModel, c::Contract, MonteCarloModel, npaths::Integer)

Calculate the gamma Greek: the second derivative of the option price
with respect to the price of the underlying for the contract `c` under the model `m`

Inputs
======

* `m::GeomBMModel` - The model under which the contract is being valued
* `c::Contract` - The contract whose greek is desired.
* `npaths::Integer` - Number of Monte Carlo paths to use.
"""
function gamma(m::GeomBMModel, c::Contract, args...; autodiff=true)
    val = value(_gamma_model(m), c, args...)
    deriv = extract_derivative(extract_derivative(val))
    currval(deriv)
end


"""
    greek(m::GeomBMModel, c::Contract; metric = :vol, n = 1)

Calculate the nth derivative of the option price with respect to different metrics. 

Inputs
======

* `m::GeomBMModel` - The model under which the contract is being valued
* `c::Contract` - The contract whose greek is desired.
* `metric::Symbol` (optional) - The metric with respect to which the derivative 
is evaluated. (default = :vol, other options - :strike, :interest)
* `n::Int` - (optional) The derivative desired. (default = 1)

"""
function greek(m::GeomBMModel, c::Contract; metric = :vol, n = 1)
    if metric == :vol
        vol = ndual(m.volatility, n)
        gbmm = GeomBMModel(m.core, vol)
        val = value(gbmm, c)
        return nderiv(val, n)
    elseif metric == :strike
        s = ndual(m.core.startprice, n)
        vol = m.volatility
        gbmm = GeomBMModel(m.core.carrycurve.reference_date, s, 
                            m.core.yieldcurve.rate, m.core.carrycurve.rate, vol)
        val = value(gbmm, c)
        return currval(nderiv(val, n))
    elseif metric == :interest
        r = ndual(m.core.yieldcurve.rate, 5)
        vol = m.volatility
        gbmm = GeomBMModel(m.core.carrycurve.reference_date, m.core.startprice, 
                            r, m.core.carrycurve.rate, vol)
        val = value(gbmm, c)
        return nderiv(val,n)
    end
end

"""
    `greek(m::MonteCarloModel, c::Contract; metric = :vol, n = 1)`

    Calculate the nth derivative of the option price with respect to different
    metrics. 

Inputs
======

* `m::MonteCarloModel` - The model under which the contract is being valued
* `c::Contract` - The contract whose greek is desired.
* `metric::Symbol` (optional) - The metric with respect to which the derivative 
is evaluated. (default = :vol, other options - :strike, :interest)
* `n::Int` - (optional) The derivative desired. (default = 1)

"""
function greek(m::MonteCarloModel, c::Contract; metric = :vol, n = 1)
    if metric == :vol
        vol = ndual(m.volatility, n)
        gbmm = GeomBMModel(m.core, vol)
        mc = montecarlo(gbmm, m.dates, size(m.paths,1))
        val = value(mc, c)
        return nderiv(val, n)
    elseif metric == :strike
        s = ndual(m.core.startprice, n)
        vol = m.volatility
        gbmm = GeomBMModel(m.core.carrycurve.reference_date, s, 
                            m.core.yieldcurve.rate, m.core.carrycurve.rate, vol)
        mc = montecarlo(gbmm, m.dates, size(m.paths,1))
        val = value(mc, c)
        return currval(nderiv(val, n))
    elseif metric == :interest
        r = ndual(m.core.yieldcurve.rate, 5)
        vol = m.volatility
        gbmm = GeomBMModel(m.core.carrycurve.reference_date, m.core.startprice, 
                            r, m.core.carrycurve.rate, vol)
        mc = montecarlo(gbmm, m.dates, size(m.paths,1))
        val = value(mc, c)
        return nderiv(val, n)
    end
end
    
function ndual(val, n::Int)
    if n == 1
        return Dual(val, 1)
    else
        return Dual(ndual(val, n-1), 1)
    end
end

function nderiv(x, n::Int)
    if n == 1
        return extract_derivative(x)
    else
        return extract_derivative(nderiv(x, n-1))
    end
end

function delta(m::MonteCarloModel{C,D,T}, args...) where {C<:CoreForwardModel,D,T}
    x = [forwardprice(m.core, SingleStock(), dt) for dt in m.dates]
    ref = m.paths ./ x'
    ForwardDiff.gradient(x) do x
        mm = MonteCarloModel(m.core, m.dates, ref .* x')
        value(mm, args...)
    end
end
