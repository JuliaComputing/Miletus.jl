"""
    LatticeStateContract

Represents a contract with multiple states, where at each exercise date the holder may
move up or down states. This can represent a variety of multiple exercise contracs, such
as storage options.

- `transition`: a square matrix of contracts: at each exercise date, the contract
  `transition[from, to]` is exercised when transitioning from state `from` to `to`.
- `ends`: a vector of contracts exercised at the final exercise date. The `i`th contract
  is exercised if the contract is in state `i` after the final exercise.
- `exdates`: the exercise dates of the contract
- `initstate`: the initial state of the contract (default = `1`).

Note that `ups` and `downs` must be of the same length, and `ends` must be 1 greater (being the number of states in the lattice).
"""
struct LatticeStateContract{CT,CE,D} <: Contract
    transition::CT
    ends::CE
    exdates::D
    initstate::Int
    function LatticeStateContract{CT,CE,D}(transition::CT, ends::CE, exdates::D, initstate::Int) where {CT,CE,D}
        ifrom, ito = axes(transition)
        ifrom == ito == axes(ends,1) || error("Transition matrix must be square.")
        initstate ∈ ifrom || error("invalid initstate")
        new(transition, ends, exdates, initstate)
    end
end


LatticeStateContract(transition::CT, ends::CE, exdates::D, initstate::Int=1) where {CT,CE,D} =
    LatticeStateContract{CT,CE,D}(transition, ends, exdates, initstate)



"""
    MaskedToepelitzTransition(mask, offsets, elements)

Represents a masked Toepelitz-structured transition matrix: that is, a matrix in which the
elements on a common diagonal are identical. The aruments are:
 - `mask`: a square `BitMatrix`. Any `false` values are considered invalid transitions.
 - `offsets`: a range indicating which diagonals have values (0 = main diagonal, +1 = superdiagonal, -1 = subdiagonal).
 - `elements`: the elements on each diagonal in `offsets`.

```
MaskedToepelitzTransition(BitArray(true for i = 1:5, j = 1:5), -2:1, (Receive(2), Receive(1), Zero(), Pay(1)))
```
"""
struct MaskedToepelitzTransition{E}
    mask::BitMatrix
    offsets::UnitRange{Int}
    elements::E
end

@inline Base.size(x::MaskedToepelitzTransition) = size(x.mask)
@inline Base.axes(x::MaskedToepelitzTransition) = axes(x.mask)
@inline Base.axes(x::MaskedToepelitzTransition, i) = axes(x.mask, i)



function polyeval(s, X)
    rX = @view X[end:-1:1]
    u = zero(s)*zero(eltype(X))
    for x in rX
        u = muladd(s, u, x)
    end
    return u
end




function optimalexercise(m::LeastSquaresMonteCarlo, c::LatticeStateContract)
    @assert issorted(c.exdates)

    paths = m.m.paths
    T = eltype(paths)

    npaths = size(paths,1)

    states = axes(c.transition, 1)

    B = Array{Float64}(undef, 1+m.degree, length(states), length(c.exdates))
    dt_nxt = last(c.exdates)
    dt_i = date2index(m.m, dt_nxt)

    CV = [float(valueat(ms, c.ends[state], dt_i)) for
         ms in scenarios(m.m), state in states]


    y = m.m.core.yieldcurve
    for x_i = reverse(eachindex(c.exdates))
        dt = c.exdates[x_i]
        dt_i = date2index(m.m, dt)

        X = [s^d for s in paths[:,dt_i], d in 0:m.degree]

        B[:,:,x_i] = β = X \ CV
        CV = X*β

        D = discount(y, yearfraction(daycount(y), dt, dt_nxt))
        CV = D.* valuebacktransition(m.m, c.transition, dt_i, CV)
        dt_nxt = dt
    end
    LSMCSwingOptionExerciseRule(B)
end

function value(m::MonteCarloModel, c::LatticeStateContract, r::LSMCSwingOptionExerciseRule)

    degree = size(r.B,1)-1
    paths = m.paths
    T = eltype(paths)
    states = axes(c.transition, 1)

    y = m.core.yieldcurve

    mean(scenarios(m)) do ms
        V = zero(T)
        state = c.initstate

        for (x_i, dt) in enumerate(c.exdates)
            D = discount(y, dt)
            dt_i = date2index(m, dt)

            state, v = predicttransition(ms, ms.path[dt_i], state, @view(r.B[:,:,x_i]), c.transition, dt_i)
            V += D * v
        end

        dt = last(c.exdates)
        D = discount(y, dt)
        dt_i = date2index(m, dt)
        V += D * valueat(ms, c.ends[state], dt_i)
    end
end

function delta(m::MonteCarloModel{C}, c::LatticeStateContract, r::LSMCSwingOptionExerciseRule) where C<:CoreForwardModel

    degree = size(r.B,1)-1
    paths = m.paths
    T = eltype(paths)
    states = axes(c.transition, 1)

    y = m.core.yieldcurve

    TΔ = zeros(T, length(m.core.forwarddates))
    for ms in scenarios(m)
        state = c.initstate

        for (x_i, dt) in enumerate(c.exdates)
            D = discount(y, dt)
            dt_i = date2index(m, dt)
            cfdt_i = date2index(m.core, dt)

            state, v = predicttransition(ms, ms.path[dt_i], state, @view(r.B[:,:,x_i]), c.transition, dt_i, ForwardDiff.Dual)
            TΔ[cfdt_i] += extract_derivative(D * v)
        end

        dt = last(c.exdates)
        cfdt_i = date2index(m.core, dt)
        D = discount(y, dt)
        dt_i = date2index(m, dt)
        TΔ[cfdt_i] += extract_derivative(D * valueat(ms, c.ends[state], dt_i, Dual))

    end
    TΔ ./ size(m.paths, 1)
end

function delta(m::AbstractModel, c::LatticeStateContract, ::Type{LeastSquaresMonteCarlo}, npaths::Int, degree::Int)
    mcm1 = montecarlo(m, c.exdates, npaths)
    ox = optimalexercise(LeastSquaresMonteCarlo(mcm1, degree), c)
    mcm2 = montecarlo(m, c.exdates, npaths)
    delta(mcm2, c, ox)
end





function value(m::HullWhiteTrinomialModel, c::LatticeStateContract)
    @assert issorted(c.exdates)

    dt = last(c.exdates)
    dt_i = date2index(m, dt)

    # TODO: switch to using offset arrays
    nodes  = 1:1+2*m.nmax
    states = axes(c.transition,1)

    T = typeof(first(m.scale) * first(m.grid))
    V = T[valueat(m, c.ends[state], dt_i, node) for
          node in nodes, state in states]

    y = m.core.yieldcurve

    for x_i = reverse(eachindex(c.exdates))
        dt_nxt = dt
        xdt = c.exdates[x_i]
        while xdt < dt
            backiterate!(V,m)
            dt -= Dates.Day(1)
        end
        D = discount(y, yearfraction(daycount(y), dt, dt_nxt))
        dt_i = date2index(m, dt)

        V = valuebacktransition(m, c.transition, dt_i, V)
    end
    dt_nxt = dt

    while startdate(m.core) < dt
        backiterate!(V,m)
        dt -= Dates.Day(1)
    end
    D = discount(y, yearfraction(daycount(y), dt, dt_nxt))
    return V[1+m.nmax, c.initstate]*D
end



function valuebacktransition(m::MonteCarloModel, transition::Matrix, dt_i, CV)
    states = axes(transition, 1)
    [maximum(valueat(ms, transition[statefrom, stateto], dt_i) + CV[ms_i, stateto] for stateto in states) for (ms_i, ms) in enumerate(scenarios(m)), statefrom in states]
end
function valuebacktransition(m::HullWhiteTrinomialModel, transition::Matrix, dt_i, V)
    nodes  = 1:1+2*m.nmax
    states = axes(transition, 1)
    [maximum(valueat(m, transition[statefrom, stateto], dt_i, node) + V[node, stateto] for stateto in states) for node in nodes, statefrom in states]
end


function valuebacktransition(m::MonteCarloModel, transition::MaskedToepelitzTransition, dt_i, CV)
    states = axes(transition, 1)
    CVn = similar(CV)
    for (ms_i, ms) in enumerate(scenarios(m))
        vv = map(t -> valueat(ms, t, dt_i), transition.elements)
        for statefrom in states
            suboffs = max(first(states)-statefrom, first(transition.offsets)) : min(last(states)-statefrom, last(transition.offsets))
            CVn[ms_i, statefrom] = maximum(vv[i-first(transition.offsets)+1] + CV[ms_i, statefrom + i] for i in suboffs if transition.mask[statefrom, statefrom+i])
        end
    end
    CVn
end
function valuebacktransition(m::HullWhiteTrinomialModel, transition::MaskedToepelitzTransition, dt_i, V)
    nodes  = 1:1+2*m.nmax
    states = axes(transition, 1)
    Vn = similar(V)
    for node in nodes
        vv = map(t -> valueat(m, t, dt_i, node), transition.elements)
        for statefrom::Int in states
            suboffs = max(first(states)-statefrom, first(transition.offsets)) : min(last(states)-statefrom, last(transition.offsets))
            Vn[node, statefrom] = maximum(vv[i-first(transition.offsets)+1] + V[node, statefrom + i] for i in suboffs if transition.mask[statefrom, statefrom+i])
        end
    end
    Vn
end

@inline function predicttransition(ms::MonteCarloScenario, s, state, B::AbstractMatrix, transition::Matrix, dt_i, args...)
    states = axes(transition, 1)
    stateto = argmax([polyeval(s, @view(B[:,stateto])) + valueat(ms, transition[state, stateto], dt_i) for stateto in states])
    return (stateto, valueat(ms, transition[state, stateto], dt_i, args...))
end

@inline function predicttransition(ms::MonteCarloScenario, s, state, B::AbstractMatrix, transition::MaskedToepelitzTransition, dt_i, args...)
    states = axes(transition, 1)
    vv = map(t -> valueat(ms, t, dt_i, args...), transition.elements)

    subinds = max(first(states)-state, first(transition.offsets)) : min(last(states)-state, last(transition.offsets))

    j = argmax([polyeval(s, @view(B[:,state+i])) + vv[i-first(transition.offsets)+1] for i in subinds if transition.mask[state, state+i]])
    stateto = state + subinds[j]
    return (stateto, vv[subinds[j]-first(transition.offsets)+1])
end
