import ForwardDiff.Dual

"""
    ivol(core::CoreModel, c::Contract, value, TianModel, nsteps=100; ...)

Compute the implied volatility of `c` using the Tian binomial model with `nsteps` steps.

This uses Newton's method, the settings of which are controlled by the keyword arguments:

 - `maxiter`: maximum number of iterations (default = 20).
 - `rtol`: relative tolerance for the implied volatility (default = 1e-6).
 - `σ0`: initial guess for volatility (default = 0.1).
"""

function ivol(core::CoreModel{T}, c::Contract, val, ::Type{S}, nsteps::Int=100;
                maxiter::Int=20, rtol::Float64=1e-6, σ0::Float64=0.1) where {T,S<:BinomialModel}
    
    startdate = core.carrycurve.reference_date
    enddate = maturitydate(c)
    startvalue = core.startprice
    interestrate = core.yieldcurve.rate
    carryrate = core.carrycurve.rate
    
    f(σ) = value(S(startdate, enddate, nsteps, startvalue,
                    interestrate, carryrate, σ), c) - val

    σ = σ0
    for i = 1:maxiter
        dσ = Dual(σ, 1.0)
        dv = f(dσ)
        
        v = ForwardDiff.value(dv)
        Δ = extract_derivative(dv)
        ϵ = v / Δ
        σ -= ϵ

        if abs(ϵ) < rtol*σ
            return σ
        end
    end
    error("Failed to converge")
end
