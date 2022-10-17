"""
    SplineInterpolation

This is used to model interpolation between any two discrete points on a
discrete convex curve. This implements double quadratic interpolation.

    - `x`: An Array of the discrete values on the x axis
    - `y`: An Array of the discrete values on the y axis
    - `weights`: An Array of tuples of the weights of every quadratic curve
    modelled between two discrete points on the curve

 
"""
struct SplineInterpolation 
    x::Vector{Float64}
    y::Vector{Float64}
    weights::Vector{Tuple{Float64,Float64,Float64}}
end

"""
    SplineVolatilityModel

    The SplineVolatilityModel is used to interpolate between two values of
    strikeprice to find the appropriate volatility on the volatility smile.

* `startdate`
* `startprice`: initial price at `startdate`
* `interestrate`: risk free rate of return.
* `carryrate`: the carry rate, i.e. the net return for holding the asset:
  - for stocks this is typically positive (i.e. dividends)
  - for commodities this is typically negative (i.e. cost-of-carry)
* `date`: Date of Maturity 
* `volcurve`: A SplineInterpolation type that models the interpolation 

"""
struct SplineVolatilityModel{C<:AbstractCoreModel} <: AbstractModel
    core::C
    date::Date
    volcurve::SplineInterpolation
end

function SplineInterpolation(x::Vector{Float64}, y::Vector{Float64})
    @assert length(x) == length(y)
    l = length(x)
    mat = [1. 0. 0.; 1. 0. 0.; 1. 0. 0.]
    vec = [0., 0., 0.]
    weights = Array{Tuple{Float64,Float64,Float64}}(undef, l-3+1)
    for i = 1:l-3+1
        for j = 1:3
            mat[j,2] = x[i+j-1]
            mat[j,3] = x[i+j-1]^2
            vec[j] = y[i+j-1]
        end
        weights[i] = tuple((mat\vec)...)
    end
    SplineInterpolation(x, y, weights)
end

SplineInterpolation(x::Vector{Tx}, y::Vector{Ty}) where {Tx<:Real, Ty<:Real} =
    SplineInterpolation(Float64.(x), Float64.(y))

"""
    interpolate(m::SplineInterpolation, c::European)

Compute the implied Black-Scholes volatility of an option `c` under the SplineVolatilityModel `m`.

"""
function interpolate(s::SplineInterpolation, x::Real)

    if (x < s.x[1]) || (x > s.x[end])
        throw(BoundsError("The value $x is not within $(s.x[1]) and $(s.x[end])"))
    end

    ind = findfirst(a -> x <= a, s.x)
    # => We care about ind, ind - 1
    if ind == length(s.x)
        return s.weights[end][1] + s.weights[end][2]*x + s.weights[end][3]*x^2
    end

    wind = ind - 1
    
    if (wind == 1) || (wind == 0)
        return s.weights[1][1] + s.weights[1][2]*x + s.weights[1][3]*x^2
    end

    fi = s.weights[wind][1] + s.weights[wind][2]*x + s.weights[wind][3]*(x^2)
    fim1 = s.weights[wind-1][1] + s.weights[wind-1][2]*x + s.weights[wind-1][3]*(x^2)

    #f = x -> F[i-1] * exp1(x) + F[i] * exp2(x)
    f = a -> (((s.x[ind+1] - a) / (s.x[ind+1] - s.x[ind])) * fim1) + 
            (((a - s.x[ind]) / (s.x[ind+1] - s.x[ind])) * fi)
    f(x)
end

Base.@deprecate ivol(s::SplineInterpolation, x::Real) interpolate(s::SplineInterpolation, x::Real)

function ivol(m::SplineVolatilityModel, c::Union{EuropeanCall{SingleStock,T},EuropeanPut{SingleStock,T}}) where T
    m.date == maturitydate(c) || error("Can only value options which mature on $(m.date)")
    interpolate(m.volcurve, strikeprice(c))
end

function value(m::SplineVolatilityModel, c::Union{EuropeanCall{SingleStock,T},EuropeanPut{SingleStock,T}}) where T
    m.data == maturitydate(c) || error("Can only value options which mature on $(m.date)")
    value(GeomBMModel(m.core, ivol(m.volcurve, strikeprice(c)), c))
end

"""
    fit(SplineVolatilityModel, mcore::AbstractCoreModel, contracts, prices)

Fit a `SplineVolatilityModel` using from a collection of contracts (`contracts`) and their respective
prices (`prices`), under the assumptions of `mcore`.
"""
function fit(::Type{SplineVolatilityModel}, mcore::AbstractCoreModel, contracts, prices)
    fit_ivol(SplineVolatilityModel, mcore, contracts, ivol.([mcore],contracts,prices))
end

"""
    fit_ivol(SplineVolatilityModel, mcore::AbstractCoreModel, contracts, ivols)

Fit a `SplineVolatilityModel` using from a collection of contracts (`contracts`) and their respective
implied volatilities (`ivols`), under the assumptions of `mcore`.
"""
function fit_ivol(::Type{SplineVolatilityModel}, mcore::AbstractCoreModel, contracts, ivols)
    SplineVolatilityModel(mcore, maturitydate(contracts[1]), SplineInterpolation(strikeprice.(contracts), ivols))
end
