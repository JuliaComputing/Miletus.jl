# TODO
# - tests
# - calibration: typically fix β apriori, then least squares with either:
#   - fixed σATM (over ξ, ρ)
#   - free (over α,ξ,ρ)
# - plotting

"""
    SABRModel

The SABR model is a stochastic volatility model of the form

    dS = σ F^β dW
    dσ = ν σ dZ

with σ(0) = α, where W and Z are correlated Wiener processes with parameter ρ.

Unlike Black-Scholes, this is not scale invariant unless `β == 1`.

* `startdate`
* `startprice`: initial price at `startdate`
* `interestrate`: risk free rate of return.
* `carryrate`: the carry rate, i.e. the net return for holding the asset:
  - for stocks this is typically positive (i.e. dividends)
  - for commodities this is typically negative (i.e. cost-of-carry)
* `α`: initial volatlity (note: this is *not* equivalent to Black-Scholes volatlity)
* `β`: constant
* `ρ`: correlation between stock price and volatlity
* `ν`: volatility of volatility

If `ν == 0` and `β == 1`, then it is equivalent to the `GeomBMModel` with `σ = α`.
"""
struct SABRModel{C} <: AbstractModel
    core::C
    α::Float64 # initial vol (note: not Black-Scholes vol)
    β::Float64 # const
    ρ::Float64 # correlation
    ν::Float64 # vol of vol
end

SABRModel(startdate, startprice, interestrate, carryrate, α, β, ρ, ν) =
    SABRModel(CoreModel(startdate, startprice, interestrate, carryrate), α, β, ρ, ν)

numeraire(m::SABRModel) = numeraire(m.core)
yearfractionto(m::SABRModel, dt::Date) =
    yearfractionto(m.core,  dt)
forwardprice(m::SABRModel, s::SingleStock, dt::Date) =
    forwardprice(m.core, s, dt)


"""
    ivol(m::SABRModel, c::European)

Compute the implied Black-Scholes volatility of an option `c` under the SABR model `m`.

The SABR model was originally explored in detail in Hagan et. al. (2002). This uses the
correction by Obloj (2008).

* P. S. Hagan, D. Kumar, A. S. Lesniewski, and D. E. Woodward. (2002) 'Managing smile
  risk". Wilmott Magazine, pages 84–108.

* J. Obloj (2008) "Fine-tune your smile: Correction to Hagan et al", arXiv: 0708.0998
"""
function ivol(m::SABRModel, c::Union{EuropeanCall{SingleStock,T},EuropeanPut{SingleStock,T}}) where T
    t = yearfractionto(m,maturitydate(c))
    K = strikeprice(c)
    f = forwardprice(m, SingleStock(), maturitydate(c))

    α,β,ν,ρ = m.α,m.β,m.ν,m.ρ

    R = K/f
    A = α/f^(1-β)

    cβ = 1-β

    ## part1 = -ν*log(R)/x(ζ)
    
    # ζ = (ν/A) * (1-R^(1-β))/(1-β)
    ζ = -(ν/A) * (cβ == 0 ? log(R) : powm1(R,cβ)/cβ)

    if ζ == 0
        part1 = A
    else
        # x(ζ) = log((sqrt(1 - 2*ρ*ζ + ζ^2) + ζ - ρ)/(1-ρ))
        v = sqrt(1 - 2*ρ*ζ + ζ^2)
        if ζ < 1
            w = 2ζ/(v + (1-ζ))
        else
            w = (v - (1-ζ))/(1-ρ)
        end
        x = log1p(w)
        part1 = -ν*log(R)/x
    end

    ## part2
    Rpcβ = R^cβ
    part2 = 1 + t*(cβ^2/24*A^2/Rpcβ + ρ*β*ν*A/(4*sqrt(Rpcβ)) + (2-3ρ^2)/24*ν^2)

    return part1*part2
end

function value(m::SABRModel, c::Union{EuropeanCall{SingleStock,T},EuropeanPut{SingleStock,T}}) where T
    σ = ivol(m, c)
    bs = GeomBMModel(m.core, σ)
    value(bs, c)
end

"""
    fit(SABRModel, mcore::AbstractCoreModel, contracts, prices)

Fit a `SABRModel` using from a collection of contracts (`contracts`) and their respective
prices (`prices`), under the assumptions of `mcore`.
"""
function fit(::Type{SABRModel}, mcore::AbstractCoreModel, contracts, prices)
    fit_ivol(SABRModel, mcore, contracts, ivol.([mcore],contracts,prices))
end


"""
    fit_ivol(SABRModel, mcore::AbstractCoreModel, contracts, ivols)

Fit a `SABRModel` using from a collection of contracts (`contracts`) and their respective
implied volatilities (`ivols`), under the assumptions of `mcore`.
"""
function fit_ivol(::Type{SABRModel}, mcore::AbstractCoreModel, contracts, ivols)
    # TODO: we should use some gradient-based methods here, along with checking the bounds

    x_init = [1.0,0.0,0.0,1.0]
    o = Optim.optimize( x_init) do x
        abs2(norm(ivol.([SABRModel(mcore, x[1],x[2],x[3],x[4])], contracts)- ivols))
    end

    Optim.converged(o) || throw("SABR fitting did not converge.")
    x = Optim.minimizer(o)
    return SABRModel(mcore, x[1],x[2],x[3],x[4])
end






"""
    sabr_alpha(F, t, σATM, β, ν, ρ)

Compute the α parameter (initial volatility) for the SABR model from the Black-Scholes
at-the-money volatility.

 - `F`: Forward price
 - `t`: time to maturity
 - `σATM`: Black-Scholes at-the-money volatility
 - `β`, `ν`, `ρ`: parameters from SABR model.

* West, G. (2005). Calibration of the SABR model in illiquid markets. Applied Mathematical Finance, 12(4), 371-385.
"""
function sabr_alpha(F, t, σATM, β, ν, ρ)
    p3 = (1-β)^2 * t / (24 * (F^(1-β))^2)
    p2 = 0.25 * ρ * ν * β * t / F^(1-β)
    p1 = 1 + (2 - 3 * ρ^2) / 24 * ν ^2 * t
    p0 = -σATM * F^(1-β)

    poscubicroot(p3,p2,p1,p0)
end
