"""
    MonteCarloModel(core, dates, paths)

A `MonteCarloModel` is the result of a simulation of a series of asset prices.

* `core`: a reference `CoreModel`
* `dates`: an `AbstractVector{Date}`
* `paths`: a matrix of the scenario paths: the rows are the scenarios, and the columns are the values at each date in `dates`.
"""
struct MonteCarloModel{C,D,T} <: AbstractModel
    core::C
    dates::D
    paths::Matrix{T}
end

"""
    MonteCarloScenario(core, dates, path)

A `MonteCarloScenario` is a single simulation scenario of a `MonteCarloModel`.

* `core`: a reference `CoreModel`
* `dates`: an `AbstractVector{Date}`
* `paths`: an `AbstractVector` of the values at each date in `dates`.
"""
struct MonteCarloScenario{C,D,S} <: AbstractModel
    core::C
    dates::D
    path::S
end


numeraire(m::Union{MonteCarloModel, MonteCarloScenario}) = numeraire(m.core)
startdate(m::Union{MonteCarloModel, MonteCarloScenario}) = startdate(m.core)

yearfractionto(m::Union{MonteCarloModel, MonteCarloScenario}, dt::Date) =
    yearfractionto(m.core,  dt)

# the value of currency is the same under every scenario
value(m::MonteCarloModel, c::WhenAt{Receive{T}}) where {T} =
    value(m.core,c)
value(m::MonteCarloScenario, c::WhenAt{Receive{T}}) where {T} =
    value(m.core,c)

function value(m::MonteCarloModel, c::WhenAt{Either{C1, C2}}) where {C1<:Contract, C2<:Contract}
    N = date2index(m, maturitydate(c))
    discount(m.core.yieldcurve, maturitydate(c)) * mean(valueat(ms, c.c, N) for ms in scenarios(m))
end

function value(m::MonteCarloModel, c::WhenAt{Amount{O}}) where O <: Observable
    N = date2index(m, maturitydate(c))
    discount(m.core.yieldcurve, maturitydate(c)) * mean(valueat(ms, c.c.o, N) for ms in scenarios(m))
end

function value(m::MonteCarloModel, c::WhenAt{Scale{O, C}}) where {O<:Observable, C<:Contract}
    N = date2index(m, maturitydate(c))
    discount(m.core.yieldcurve, maturitydate(c)) * mean(valueat(ms, c.c, N) for ms in scenarios(m))
end

function value(m::MonteCarloModel, c::WhenAt{Cond{O, C1, C2}}) where {O<:Observable, C1<:Contract, C2<:Contract}
    N = date2index(m, maturitydate(c))
    discount(m.core.yieldcurve, maturitydate(c)) * mean(valueat(ms, c.c, N) for ms in scenarios(m))
end

# Martingale property of the underlying
function value(m::MonteCarloModel, c::WhenAt{SingleStock})
    value(m.core, c)
end
value(m::MonteCarloModel, c::SingleStock) = value(m.core, c)

# value of a barrier option
function value(m::MonteCarloModel, c::Anytime{LiftObs{F,Tuple{ValueObs{SingleStock, A},ConstObs{A}},Bool},C}) where {F,A,C} 
    N = date2index(m, maturitydate(c))
    ss = scenarios(m)
    discount(m.core.yieldcurve, maturitydate(c)) * sum(valueat(ms, c.c, N) for ms in scenarios(m) if observe(ms, c.p, any)) / length(ss)
end

function value(m::MonteCarloModel, c::Anytime{LiftObs{F,Tuple{ConstObs{A},ValueObs{SingleStock,A}},Bool},C}) where {F,A,C} 
    N = date2index(m, maturitydate(c))
    ss = scenarios(m)
    discount(m.core.yieldcurve, maturitydate(c)) * sum(valueat(ms, c.c, N) for ms in scenarios(m) if observe(ms, c.p, any)) / length(ss)
end

function value(m::MonteCarloModel, c::Cond{O, C1, C2}) where {O<:Observable{Bool}, C1<:Contract, C2<:Contract}
    N = date2index(m, maturitydate(c))
    discount(m.core.yieldcurve, maturitydate(c)) * mean(valueat(ms, c, N) for ms in scenarios(m))
end


struct ScenarioIterator{M<:MonteCarloModel}
    m::M
    n::Int
end


"""
    scenarios(m::MonteCarloModel)

Returns an iterator over each `MonteCarloScenario` in `m`.
"""
scenarios(m::MonteCarloModel) = ScenarioIterator(m, size(m.paths, 1))

Base.length(sc::ScenarioIterator) = sc.n
Base.iterate(sc::ScenarioIterator, i::Int=1) = i > sc.n ? nothing :
    (MonteCarloScenario(sc.m.core, sc.m.dates, view(sc.m.paths, i, :)), i+1)

"""
    date2index(m::Union{MonteCarloScenario, MonteCarloModel}, dt::Date)

Returns the index of `dt` in the path(s) of `m`.
"""
function date2index(m::Union{MonteCarloScenario, MonteCarloModel}, dt::Date)
    ii = searchsorted(m.dates, dt)
    isempty(ii) && throw(DomainError(dt))
    return ii[1]
end

index2date(m::Union{MonteCarloScenario, MonteCarloModel}, i) = m.dates[i]


function forwardprice(m::MonteCarloScenario, s::SingleStock, dt::Date)
    valueat(m,s,date2index(m,dt))
end
function forwardprice(m::MonteCarloModel, s::SingleStock, dt::Date)
    mean(forwardprice(ms, s, dt) for ms in scenarios(m))
end

valueat(m::MonteCarloScenario, ::SingleStock, i::Int) = m.path[i]
valueat(m::MonteCarloScenario, ::SingleStock, i::Int, ::Type{Dual}) =
    Dual(m.path[i], 1)

function valueat(m::MonteCarloScenario, c::WhenAt{SingleStock}, i::Int)
    t = index2date(m,i)
    T = maturitydate(c)
    j = date2index(m, T)
    forward_rate(m.core.yieldcurve, t, T) * m.path[j] 
end

function valueat(m::MonteCarloScenario, c::WhenAt{Amount{ConstObs{X}}}, i::Int) where {X}
    t = index2date(m,i)
    T = maturitydate(c)
    forward_rate(m.core.yieldcurve, t, T) * c.c.o.val
end

function valueat(m::MonteCarloScenario, c::WhenAt{Cond{O, C1, C2}}, i::Int) where {O, C1, C2}
    t = index2date(m,i)
    T = maturitydate(c)
    j = date2index(m, T)
    forward_rate(m.core.yieldcurve, t, T) * valueat(m, c.c, j)
end

function valueat(m::MonteCarloScenario, c::Cond{O, C1, C2}, i::Int) where {O<:Observable{Bool}, C1<:Contract, C2<:Contract}
    b = observeat(m, c.p, i)
    b ? valueat(m, c.c1, i) : valueat(m, c.c2, i)
end

function valueat(m::MonteCarloScenario, c::WhenAt{Either{C1,C2}}, i::Int) where {C1,C2}
    t = index2date(m,i)
    T = maturitydate(c)
    j = date2index(m, T)
    v1 = valueat(m, c.c.c1, j)
    v2 = valueat(m, c.c.c2, j)
    maximum = max(v1,v2)
    forward_rate(m.core.yieldcurve, t, T) * maximum
end

function observe(ms::MonteCarloScenario, o::LiftObs{F,Tuple{ValueObs{SingleStock,A},ConstObs{A}},Bool}, predicateFold::Function)::Bool where {F,A}
    predicateFold(p -> o.f(p, o.a[2].val), ms.path)    
end
function observe(ms::MonteCarloScenario, o::LiftObs{F,Tuple{ConstObs{A}, ValueObs{SingleStock,A}},Bool}, predicateFold::Function)::Bool where {F,A}
    predicateFold(p -> o.f(o.a[1].val, p), ms.path)    
end

observeat(_::MonteCarloScenario, o::ConstObs{T}, _::Int) where T = o.val 
function observeat(m::MonteCarloScenario, o::LiftObs{F, Tuple{DateObs, ConstObs{Date}}, Bool}, i::Int) where F
    (_, t2) = o.a
    t1 = index2date(m, i)
    o.f(t1, t2.val)
end 

"""
    montecarlo(m::GeomBMModel, dates, npaths)

Sample `npaths` Monte Carlo paths of the model `m`, at time `dates`.
"""
function montecarlo(m::GeomBMModel{CoreModel{T,R,Q}, V}, dates::StepRange{Date}, npaths::Integer) where {T,R,Q,V}
    σ = m.volatility
    S = typeof(m.core.yieldcurve.rate)
    Xt = Array{promote_type(T,V,S)}(undef, length(dates), npaths)
    Δt = yearfraction(daycount(m.core.yieldcurve), step(dates))
    df = discount(m.core.carrycurve, Δt) / discount(m.core.yieldcurve, Δt)
    for i = 1:npaths
        x = value(m, SingleStock())
        for (j, dt) in enumerate(dates)
            if j == 1
                Δt1 = yearfraction(daycount(m.core.yieldcurve), startdate(m), first(dates))
                df1 = Δt1 == 0 ? 1.0 : discount(m.core.carrycurve, Δt1) / discount(m.core.yieldcurve, Δt1)
                x *= df1 * exp(-σ^2*Δt1/2 + σ*sqrt(Δt1)*randn())
            else
                x *= df * exp(-σ^2*Δt/2 + σ*sqrt(Δt)*randn())
            end
            Xt[j,i] = x
        end
    end
    MonteCarloModel(m.core, dates, copy(transpose(Xt)))
end

function value(m::GeomBMModel, c::Contract, ::Type{MonteCarloModel}, dates::StepRange{Date}, npaths::Integer)
    mcm = montecarlo(m, dates, npaths)
    value(mcm, c)
end

value(m::GeomBMModel, c::Contract, ::Type{MonteCarloModel}, npaths::Integer) =
    value(m, c, MonteCarloModel, startdate(m):Day(1):maturitydate(c), npaths)
