export GeomOUModel

"""
    GeomOUModel
Assumes that the stock price follows a geometric Ornstein–Uhlenbeck process
```math
\\frac{dS_t}{S_t} = [k(t) - \\theta \\log S_t] dt + \\sigma dW_t
```
where the parameters:
* ``\\theta`` is the rate of mean reversion (sometimes called "speed")
* ``\\sigma`` is the OU volatility
and ``k(t)`` is chosen based on the forward curve so that ``S_t`` is risk-neutral.
This is equivalent to the "one factor model" of Clewlow and Strickland (1999), with
dynamics on the forward price of
```math
\\frac{d F_{t,T}}{F_{t,T}} = \\sigma e^{-\theta (T-t)} dW_t
```
where ``F_{t,T}`` is the forward price of maturity date ``T`` at current time ``t``.
* Clewlow, L. and Strickland, C. (1999) "Valuing Energy Options in a One Factor Model
  Fitted to Forward Prices". https://ssrn.com/abstract=160608
"""
struct GeomOUModel{C} <: AbstractModel
    core::C
    θ::Float64
    σ::Float64
end

numeraire(m::GeomOUModel) = numeraire(m.core)

forwardprice(m::GeomOUModel, s::SingleStock, dt::Date) = forwardprice(m.core, s, dt)


function montecarlo(m::GeomOUModel, dates::StepRange, npaths::Integer)
    mz = 0 * exp(-m.θ * 0.0) - m.σ^2/(4*m.θ)*(1-exp(-m.θ *  0.0))*(1+exp(-m.θ * (2* 0.0- 0.0)))
    Tm = typeof(mz)
    Tf = typeof(forwardprice(m.core, SingleStock(), first(dates)))
    T = typeof(one(Tf)*mz)


    Xt = Array{T}(undef, length(dates), npaths)
    for i = 1:npaths
        M = 0.0 # log(S_t / F_t)
        dt_prv = startdate(m.core)
        for (j, dt) in enumerate(dates)
            F = forwardprice(m.core, SingleStock(), dt)
            if dt != dt_prv
                t = yearfraction(daycount(m.core.yieldcurve), startdate(m.core), dt)
                Δt = yearfraction(daycount(m.core.yieldcurve), dt_prv, dt)
                z =  randn()
                M = M * exp(-m.θ * Δt) - m.σ^2/(4*m.θ)*(1-exp(-m.θ * Δt))*(1+exp(-m.θ * (2*t-Δt))) +
                    z * m.σ*sqrt((1-exp(-2*m.θ * Δt))/(2*m.θ))
            end
            S = F*exp(M)
            Xt[j,i] = S
            dt_prv = dt
        end
    end
    MonteCarloModel(m.core, dates, copy(transpose(Xt)))
end