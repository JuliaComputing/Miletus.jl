export BinomialGeomRWModel, CRRModel, TianModel, JRModel


"""
    BinomialGeomRWModel

A model for a Binomial Geometric Random Walk (aka Binomial tree). 

Arguments:

* `startdate` : start date of process
* `enddate` : start date of process
* `nsteps` : number of steps in the tree
* `S₀` : inital value
* `Δt` : the time-difference between steps, typically `days(startdate - enddate) / (365*nsteps)`
* `iR` : discount rate, `exp(-Δt*interestrate)`
* `u`  : scale factor for up
* `d`  : scale factor for down
* `p`  : up probability
* `q`  : down probability, `1-p`

"""
struct BinomialGeomRWModel{T,V,S} <: AbstractModel
    startdate::Date
    enddate::Date
    nsteps::Int
    S₀::T
    Δt::Float64
    iR::Float64 # exp(-r*Δt)
    logu::V #Float64
    logd::V #Float64
    p::S #Float64
    q::S #Float64
end

abstract type BinomialModel end
struct TianModel <: BinomialModel end
struct CRRModel <: BinomialModel end
struct JRModel <: BinomialModel end
struct JRrnModel <: BinomialModel end

numeraire(m::BinomialGeomRWModel{T}) where {T<:CurrencyQuantity} = unit(m.S₀)
numeraire(m::BinomialGeomRWModel{T}) where {T<:Real} = one(m.S₀)



"""
    CRRModel

Cox-Ross-Rubenstein binomial model.
"""
function CRRModel(startdate::Date, enddate::Date, nsteps::Int,
               startvalue, interestrate::Float64, carryrate::Float64, volatility::T) where T
    Δt = days(enddate - startdate) / (365 * nsteps)
    σ  = volatility
    b  = interestrate - carryrate
    B  = exp(b*Δt)
    iR = exp(-interestrate*Δt)
    
    logu = σ*√Δt
    logd = -σ*√Δt
    u = exp(logu)
    d = exp(logd)
    p = (B-d)/(u-d)
    q = (u-B)/(u-d)
    BinomialGeomRWModel(startdate,enddate,nsteps,startvalue,Δt,
                                iR,logu,logd,p,q)
end

function JRModel(startdate::Date, enddate::Date, nsteps::Int,
               startvalue, interestrate::Float64, carryrate::Float64, volatility::T) where T

    Δt = days(enddate - startdate) / (365 * nsteps)
    σ  = volatility
    b  = interestrate - carryrate
    iR = exp(-interestrate*Δt)

    logu = (b-σ^2/2)*Δt + σ*√Δt
    logd = (b-σ^2/2)*Δt - σ*√Δt
    p = q = 0.5

    BinomialGeomRWModel(startdate,enddate,nsteps,startvalue,Δt,
                                iR,logu,logd,p,q)
end
function JRrnModel(startdate::Date, enddate::Date, nsteps::Int,
               startvalue, interestrate::Float64, carryrate::Float64, volatility::T) where T
    Δt = days(enddate - startdate) / (365 * nsteps)
    σ  = volatility
    b  = interestrate - carryrate
    B  = exp(b*Δt)
    iR = exp(-interestrate*Δt)

    logu = (b-σ^2/2)*Δt + σ*√Δt
    logd = (b-σ^2/2)*Δt - σ*√Δt
    u = exp(logu)
    d = exp(logd)
    p = (B-d)/(u-d)
    q = (u-B)/(u-d)

    BinomialGeomRWModel(startdate,enddate,nsteps,startvalue,Δt,
                                iR,logu,logd,p,q)
end

# the value at step `n`, index `i` (i.e. `i` ups, `n-i` downs)
@inline valueat(m::BinomialGeomRWModel{T}, s::SingleStock, n, i) where {T} =
    m.S₀*exp(m.logu*i + m.logd*(n-i))


function value(m::BinomialGeomRWModel{T,V}, c::WhenAt{C}) where {C,T,V}
    m.enddate == maturitydate(c) || error("Binomial end date must match maturity of option")
    N = m.nsteps
    S = typeof(valueat(m, c.c, N, N))
    X = S[valueat(m, c.c, N, i) for i = 0:N]
    for n = N-1 : -1 : 0
        for i = 0:n
            X[i+1] = m.iR*(m.q*X[i+1] + m.p*X[i+2])
        end
    end
    X[1]
end
function value(m::BinomialGeomRWModel{T}, c::AnytimeBefore{C}) where {C,T}
    m.enddate == maturitydate(c) || error("Binomial end date must match maturity of option")
    N = m.nsteps
    S = typeof(valueat(m, c.c, N, N))
    X = S[valueat(m, c.c, N, i) for i = 0:N]
    for n = N-1 : -1 : 0
        for i = 0:n
            X[i+1] = max(m.iR*(m.q*X[i+1] + m.p*X[i+2]),
                         valueat(m, c.c, n, i))
        end
    end
    X[1]
end
                                
## Tian
"""
    TianModel

Tian binomial model.
"""
function TianModel(startdate::Date, enddate::Date, nsteps::Int,
               startvalue, interestrate::Float64, carryrate::Float64, volatility::T) where T
    Δt = days(enddate - startdate) / (365 * nsteps)
    σ = volatility
    v = exp(σ^2*Δt)
    r = interestrate - carryrate
    iR = exp(-interestrate*Δt)
    u = 1/2*exp(r*Δt)*v*(v+1+sqrt(v^2+2v-3))
    d = 1/2*exp(r*Δt)*v*(v+1-sqrt(v^2+2v-3))
    logu = log(u)
    logd = log(d)
    p = (exp(r*Δt)-d)/(u-d)
    q = (u-exp(r*Δt))/(u-d)
    BinomialGeomRWModel(startdate,enddate,nsteps,startvalue,Δt,
                                iR,logu,logd,p,q)
end



# From http://www.goddardconsulting.ca/option-pricing-binomial-alts.html

## Cox-Ross-Rubinstein
# u = exp(σ*√Δt)
# d = exp(-σ*√Δt)
# p = (exp(r*Δt)-d)/(u-d)
# q = (u-exp(r*Δt))/(u-d)

## Jarrow-Rudd
# u = exp((r-σ^2/2)*Δt + σ*√Δt)
# d = exp((r-σ^2/2)*Δt - σ*√Δt)
# p = q = 0.5
# NOTE: not risk-neutral

## Jarrow-Rudd risk-neutral
# u = exp((r-σ^2/2)*Δt + σ*√Δt)
# d = exp((r-σ^2/2)*Δt - σ*√Δt)
# p = (exp(r*Δt)-d)/(u-d)
# q = (u-exp(r*Δt))/(u-d)

## Tian
# u = 1/2*exp(r*Δt)*v*(v+1+sqrt(v^2+2v-3))
# d = 1/2*exp(r*Δt)*v*(v+1-sqrt(v^2+2v-3))
#   where v = exp(σ^2*Δt)
# p = (exp(r*Δt)-d)/(u-d)
# q = (u-exp(r*Δt))/(u-d)

## CRR with drift
# u = exp(η*Δt + σ*√Δt)
# d = exp(η*Δt - σ*√Δt)
# p = (exp(r*Δt)-d)/(u-d)
# q = (u-exp(r*Δt))/(u-d)
#   for some η
#   a common choice is η = (log(K)-log(S0))/T

## Leisen-Reimer
# p = h_inv(d1)
# p2 = h_inv(d2)
# u = exp(r*Δt) * p2/p
# d = (exp(r*Δt) - p*u) / (1-p)
#  (ensures standard form for p,q)
# h_inv is a discrete approximation to Φ


