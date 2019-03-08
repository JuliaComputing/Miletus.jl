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



# fallback
function value(m::MonteCarloModel, c::WhenAt)
    N = date2index(m, maturitydate(c))
    discount(m.core.yieldcurve, maturitydate(c)) * mean(valueat(ms, c.c, N) for ms in scenarios(m))
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
