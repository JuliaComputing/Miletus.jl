using ForwardDiff

"""
    black_ivol(F, K, β)

The inverse black function: returns the value `s` such that

    black(K,s) == β

where `F > 0`, K > 0` and `max(F-K, 0) ≤ β ≤ F`.
"""
function black_ivol(F, K, β)
    F > zero(F) && K > zero(K) || throw(DomainError())
    if !(β < F)
        β == F ? (return Inf) : throw(DomainError())
    end

    if K ≥ F
        if !(zero(β) < β)
            β == zero(β) ? (return 0.0) : throw(DomainError())
        end
        _black_ivol(K/F, β/F)
    else
        L = F-K
        if !(L < β)
            β == L ? (return 0.0) : throw(DomainError())
        end
        _black_ivol(F/K, (β-L)/K)
    end
end

"""
    _black_ivol(K, β)

The kernel of the inverse black function: returns the value `s` such that

    black(K,s) == β

where `K ≥ 1` and `0 ≤ β ≤ 1`.
"""
function _black_ivol(K, β)
    maxiters = 4

    logK = log(K)
    x  = -logK
    s₂ = sqrt(-2*x) # point of inflection
    β₂ = 0.5 - K*Φ(-s₂) # cancelation of some terms
    ν₂ = oftype(β₂,invsqrt2π)
    if β < β₂
        s₁ = s₂ - β₂/ν₂
        h₁ = x/s₁;  t₁ = s₁/2
        β₁ = _black(h₁,t₁,K)
        if β < β₁
            # 1. Rational interpolation of transformation
            # (note scaling vs Jaeckel (2013))
            #   f(β)  = -2π*x/(3√3) * Φ(z)^3
            #            where z = x/(√3*s(β))
            #         -> 0   as β -> 0
            #   f′(β) = 2π*z² * ϕ(z)² / √K * exp(z² + s²/8)    # (eq. 4.32)/√K
            #         -> 1/√K as β -> 0
            #   f′′(β) =                                       # (eq. 4.33)/K
            #
            β₀ = 0.0; f₀ = 0.0;  d₀ = 1.0/sqrt(K)

            z₁ = x/(sqrt(3)*s₁)
            Φz₁ = Φ(z₁)
            f₁ = (-2π/(sqrt(27))) * x * Φz₁^3
            w₁ = exp(z₁^2 + s₁^2/8)
            d₁ = 2π * z₁^2 * Φz₁^2 / √K * w₁
            dd₁ = (π/6)*(z₁^2/s₁^3) * Φz₁ * w₁^2 / K *
                ((-8*sqrt(3))*s₁*x + (3*s₁^2*(s₁^2-8) - 8*x^2)*Φz₁/ϕ(z₁))

            Δ = (f₁ - f₀)/(β₁ - β₀)
            r = ((β₁ - β₀)/2*dd₁ + (d₁-d₀))/(d₁ - Δ)
            f = rational_cubic_interpolation(β, β₀,β₁, f₀,f₁, d₀,d₁, r)
            z = invΦ(cbrt(sqrt(27)*f/(-2π*x)))
            s = x/(sqrt(3)*z)

            # Use 3rd order Householder's method with objective function
            #     g(s)   = 1/log(b(s)) - 1/log(β)
            #     g′(s)  = -b′ / (b  * log(b)^2)
            #     g′′(s) = g′ * ( b′′/b′ - b′/b * (1+2/log(b)))
            #     g′′′(s) =  g′ *( b′′′/b′ +   2(b'/b)²·(1+3/ln(b)·(1+1/ln(b)))  -  3(b''/b)·(1+2/ln(b)))

            logβ = log(β)
            for iter = 1:maxiters
                h = x/s; t = s/2
                b = _black(h,t,K)
                logb = log(b)
                ν = _black_vega(h,t)
                bH2 = (h+t)*(h-t)/s
                bH3 = bH2^2 - 3*(h/s)^2 - 1/4

                g′ = -ν / (b*logb^2)
                N  = b/ν*(logβ-logb)*logb/logβ
                H2 = bH2 - ((ν/b)*(1+2/logb))
                H3 = bH3 + (ν/b)*(2*(ν/b)*(1+3/logb*(1+1/log(b))) - 3*bH2*(1+2/logb))

                ds = max(-0.5*s , householder_update(N, H2, H3))
                s += ds
                if abs(ds) < eps(typeof(s))*s
                    break
                end
            end
            return s
        else
            # 2. Rational interpolation between s₁ and s₂
            ν₁ = _black_vega(h₁,t₁)
            # choose r to obtain concave interpolant
            # (this is dominant over 2nd deriv zero at centre)
            Δ = (s₂-s₁)/(β₂-β₁)
            m,M = minmax(1/ν₁ - Δ, Δ - 1/ν₂)
            r = 1 + (1/ν₁-Δ)/(Δ-1/ν₂)
            s = rational_cubic_interpolation(β, β₁,β₂, s₁,s₂, 1/ν₁,1/ν₂, r)
            s₋ = s₁; s₊ = s₂
            @goto middle
        end
    else
        s₃ = s₂ + (1-β₂)/ν₂
        h₃ = x/s₃;  t₃ = s₃/2
        β₃ = _black(h₃,t₃,K)
        if β < β₃
            # 3. Direct rational interpolation between s₂ and s₃
            ν₃ = _black_vega(h₃,t₃)
            # choose r to obtain convex interpolant
            # (this is dominant over 2nd deriv zero at centre)
            Δ = (s₃-s₂)/(β₃-β₂)
            m,M = minmax(1/ν₃ - Δ, Δ - 1/ν₂)
            r = 1 + M/m
            s = rational_cubic_interpolation(β, β₂,β₃, s₂,s₃, 1/ν₂,1/ν₃, r)
            s₋ = s₂; s₊ = s₃

            @label middle # regions 2 & 3

            # Objective function
            #     g(s) = b(s) - β

            for iter = 1:maxiters
                h = x/s; t= s/2
                b = _black(h, t, K)
                ν = _black_vega(h, t)
                N = (β - b)/ν                # (β - b) / vega
                H2 = (h+t)*(h-t)/s           # vomma / vega
                H3 = H2^2 - 3*(h/s)^2 - 1/4  # ultima / vega

                ds = max(-0.5*s , householder_update(N, H2, H3))
                s += ds
                if abs(ds) < eps(typeof(s))
                    break
                end
            end
            return s

        else
            # 4. Rational interpolation of transformation:
            #  fᵤ(β)   = Φ(-s(β)/2)
            #           -> 0      as β -> 1
            #  fᵤ'(β)  = -1/2 * exp(1/2 * (x²/s² + x))
            #          = -1/(2*√K) * exp(h²/2)
            #           -> -1/(2*√K)   as β -> 1
            #  fᵤ''(β) = sqrt(π/2) * x² / s³ * exp(x² / s² + x + s²/8)
            #          = sqrt(π/2) * h²/(s*K) * exp(h² + s²/8)
            #
            # (note scaling 1/√K, 1/K vs Jaeckel (2013))

            β₄ = 1.0
            f₄ = 0.0
            d₄ = -1/(2*sqrt(K))

            f₃ = Φ(-t₃)
            d₃ = d₄ * exp(h₃^2/2)
            dd₃ = sqrt(π/2) * h₃^2 / (s₃*K) * exp(h₃^2 + t₃^2/2)

            Δ = (f₄ - f₃)/(β₄ - β₃)
            r = ((β₄-β₃)/2*dd₃ + (d₄-d₃))/(Δ - d₃)
            f = rational_cubic_interpolation(β, β₃,β₄, f₃,f₄, d₃,d₄, r)
            s = -2*invΦ(f)

            # b′ = _black_vega(h,t)           # vega
            # b′′ = b′ * (h+t)*(h-t)/s  # vomma
            # b′′′ = b′ * (4h^2 - (h+t)(h-t)*(1-(h+t)(h-t)))   # ultima

            # Use 3rd order Householder's method with objective function
            #     g(s)   = log(1-β) - log(1-b(s)) = -log(cb/cβ)
            #     g′(s)  = b′ / (1-b)
            #     g′′(s) = g′ * ( b′′/b′ + g′)
            #     g′′′(s) =  g′ *( b′′′/b′ +  g′ * (2g′ + 3b′′/b′))

            cβ = 1-β

            for iter = 1:maxiters
                h = x/s; t = s/2
                cb = _cblack(h,t,K)
                ν = _black_vega(h,t)
                bH2 = (h+t)*(h-t)/s
                bH3 = bH2^2 - 3*(h/s)^2 - 1/4

                g′ = ν / cb
                N  = log(cb/cβ) / g′
                H2 = bH2 + g′
                H3 = bH3 + g′ * (2*g′ + 3*bH2)

                ds = max(-0.5*s , householder_update(N, H2, H3))
                s += ds

                if abs(ds) < eps(typeof(s))
                    break
                end
            end
            return s

        end
    end
end



"""
    householder_update(N, [H2, [H3]])

The update incrememnt for `n`th order Householder's method (where `n` is the number of arguments) for finding the root of

    f(x) == 0

* `n == 1` is Newton's method
* `n == 2` is Halley's method

Arguments:

* `N`:  the Newton update `-f(x) / f′(x)`
* `H2`: the scaled 2nd order derivative `f′′(x) / f′(x)`
* `H3`: the scaled 3rd order derivative `f′′′(x) / f′(x)`
"""
householder_update(N) = N
householder_update(N, H2) = N/(1+H2*N/2)
householder_update(N, H2, H3) = N*(1+H2*N/2)/(1+N*(H2 + H3*N/6))


"""
    rational_cubic_interpolation(x, x₋, x₊, y₋, y₊, d₋, d₊, r)

Compute a shape preserving rational interpolation.

Arguments

* `x` the value at which to interpolate
* `x₋`,`x₊`: the lower and upper bounds of the interval
* `y₋`,`y₊`: the value of the function at the lower and upper bounds
* `d₋`,`d₊`: the value of the derivative at the lower and upper bounds
* `r`: the control parameter, which must be greater than -1.
  - If `r == 3`, then it is the usual Hermite cubic polynomial
  - As `r → ∞`, it approaches linear interpolation.

If `Δ = (y₊ - y₋)/(x₋ - x₊) > 0`, and `d₋ >= 0`, `d₊ >= 0`, then the interpolant is guaranteed monotonic increasing if

    r >= (d₋ + d₊)/Δ

[DG85, eq. 3.8].

If  `d₋ < Δ < d₊`, then the interpolant is convex if and only if

    r >= 1 + max(d₊ - Δ, Δ - d₋) / min(d₊ - Δ, Δ - d₋)

[DG85, eq. 3.18].

Note: for the purposes of computation, the bounds are actually interchangable (i.e. `x₋` can be the upper bound).

References

* R. Delbourgo and J. A. Gregory (1985) "Shape Preserving Piecewise Rational Interpolation", SIAM J. Sci. and Stat. Comput., 6(4), 967–976. doi:[10.1137/0906065](http://dx.doi.org/10.1137/0906065)

"""
function rational_cubic_interpolation(x, x₋, x₊, y₋, y₊, d₋, d₊, r)
    h = x₊ - x₋
    if h == 0
        return (y₋ + y₊)/2
    end

    # r should be greater than -1. We do not use  assert(r > -1)  here in order to allow values such as NaN to be propagated as they should.
    s = (x - x₋) / h
    t = (x₊ - x) / h

    if r < 2/eps(typeof(r))^2
        ((y₊*s + (r*y₊ - h*d₊)*t)*s^2 + ((r*y₋ + h*d₋)*s + y₋*t)*t^2) /
          (1 + (r - 3) * s * t)
    else
        # Linear interpolation without over-or underflow.
        y₊*s + y₋*t
    end
end
