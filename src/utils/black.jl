using SpecialFunctions

"""
    black(F,K,s)

The Black function of standardised arguments:

    black(F,K,s) = F ⋅ Φ(log(F/K)/s + s/2) - K ⋅ Φ(log(F/K)/s - s/2)

This is the Black-Scholes price of a call option with spot price `F`, strike `K` and volatility `s`, assuming the discount rate `r` and carry rate `q` are zero, and the time to maturity is one.

This is monotonic increasing in `s`, with

    black(K,F,0) == max(F-K, 0)
    black(K,F,∞) == F

The corresponding put price is:

    black(K,F,s)

and so put-call parity implies:

    black(F,K,s) + K = black(K,F,s) + F

`black(F,K,s)` is the expectation of `max(exp(Y)-K,0)` where `Y` has a `Normal(log(F)-s^2/2, s)` distribution.

This can be used to compute the complementary CDF of the inverse Gaussian distribution with parameters `(λ,μ)` at `x` via,

    P[X > x] = black(1, exp(2λ/μ), 2*sqrt(λ/x))

This is largely based on the method of Jäckel (2015).

References

* Jäckel, P. (2015), Let's Be Rational. Wilmott, 2015(75): 40–53. doi:10.1002/wilm.10395

"""
function black(F,K,s)
    F > zero(F) && K > zero(K) && s ≥ 0 || throw(DomainError())
    if s == 0
        max(F-K,zero(K))
    else
        if K >= F
            x = -log(K/F)
            h = x/s
            t = s/2
            F * _black(h,t,K/F)
        else
            # use put-call parity
            x = -log(F/K)
            h = x/s
            t = s/2
            (F-K) + K * _black(h,t,F/K)
        end
    end
end



"""
    _black(h, t, K = exp(-2*h*t))

The black kernel function:

    Φ(h + t) - K*Φ(h - t)

where `K = exp(-2*h*t)` (this is provided as an extra argument, as it is typically known a priori.

Assumes `h <= 0`, `t >= 0` , which implies `K >= 1`.
"""
_black(h, t, K = exp(-2*h*t)) = _black_normcdf(h, t, K) # generic fallback

function _black(h::Float64, t::Float64, K::Float64=exp(-2*h*t))
    if h > -10 && t < 0.21022410381342865 # 2*eps()^(1/16)
        _black_small_t(h, t)
    elseif t > 0.85 - h
        _black_normcdf(h, t, K)
    else
        _black_erfcx(h, t)
    end
end

"""
    _black_normcdf(h, t, K=exp(-2*h*t))

Computes the black kernel function directly using the normal CDF.
"""
_black_normcdf(h, t, K=exp(-2*h*t)) = Φ(h+t) - K*Φ(h-t)


"""
    _black_erfcx(h, t)

Compute the black kernel function using the `erfcx` function:

    b  =  Φ(h+t) - exp(-2⋅h⋅t) ⋅ Φ(h-t)

          exp(-(h²+t²)/2)
       =  ---------------  ·  [ Φ(h+t)/ϕ(h+t) - Φ(h-t)/ϕ(h-t) ]
              √(2π)

       =  exp(-(h²+t²)/2) ⋅ [erfcx(-(h+t)/√2) - erfcx(-(h-t)/√2)]/2

"""
_black_erfcx(h,t) =
    exp(-(h+t)^2/2)*(erfcx(-invsqrt2*(h+t)) - erfcx(-invsqrt2*(h-t)))/2

"""
    _black_small_t(h, t)

Compute the black kernel function using Taylor series around `t=0`:

    b  =  Φ(h+t) - exp(-2⋅h⋅t) ⋅ Φ(h-t)

          exp(-(h²+t²)/2)
       =  ---------------  ·  [ Φ(h+t)/ϕ(h+t) - Φ(h-t)/ϕ(h-t) ]
              √(2π)

       =  exp(-(h²+t²)/2) ⋅ [erfcx(-(h+t)/√2) - erfcx(-(h-t)/√2)]/2

Using

    Y(h) = Φ(h)/φ(h) = √(π/2)·erfcx(-h/√2)
    a    = 1+h·Y(h)

Note that due to `h < 0`, and `h·Y(h) -> -1` (from above) as `h -> -∞`, we also have that `a > 0` and `a -> 0` as `h -> -∞`.
"""
function _black_small_t(h,t)
    a = 1+h*sqrthalfπ*erfcx(-invsqrt2*h)
    t2 = t*t
    h2 = h*h
    expansion = 2*t*(@horner(t2,
        a,
        @horner(h2,-1+3*a,a)/6,
        @horner(h2,-7+15*a,-1+10*a,a)/120,
        @horner(h2,-57+105*a,-18+105*a,-1+21*a,a)/5040,
        @horner(h2,-561+945*a,-285+1260*a,-33+378*a,-1+36*a,a)/362880,
        @horner(h2,-6555+10395*a,-4680+17325*a,-840+6930*a,-52+990*a,-1+55*a,a)/39916800,
        @horner(h2,-89055+135135*a,-82845+270270*a,-20370+135135*a,-1926+25740*a,-75+2145*a,-1+78*a,a)/6227020800))

    return invsqrt2π*exp(-(h+t)^2/2)*expansion
end


"""
    _cblack(h, t, K=exp(-2*h*t))

The complement of the black kernel function

    1 - _black(h, t, K)

"""
_cblack(h, t, K=exp(-2*h*t)) = Φ(-(h+t)) + K*Φ(h-t)


"""
    _black_vega(h, t)

The vega corresponding to the black kernel function:

    Φ(h + t) - K*Φ(h - t)

where `h = -log(K)/s` and `t = s/2`.
"""
_black_vega(h,t) = ϕ(h+t)
