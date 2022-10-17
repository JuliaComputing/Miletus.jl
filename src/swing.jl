"""
    DiscreteSwingContract
Represents a swing contract. The arguments are:
- `default`: this is the contract that is executed on each date if no swing occurs
- `alternate`: this is the contract that is executed if the swing occurs
- `penalty`: this contract is executed on the last exercise date, and is scaled by the number of swings below the minimum (`nxmin`)
- `exdates`: the exercise dates of the swing option
- `nxmin`: the minimum number of swings (the `penalty` contract is incurred if the total number of swings is below this number)
- `nxmax`: the maximum number of swings that may be taken
"""
struct DiscreteSwingContract{C1<:Contract,C2<:Contract,CP<:Contract,D} <: Contract
    default::C1
    alternate::C2
    penalty::CP
    exdates::D
    nxmin::Int
    nxmax::Int
end

struct LSMCSwingOptionExerciseRule
    B::Array{Float64,3}
end


function optimalexercise(m::LeastSquaresMonteCarlo, c::DiscreteSwingContract)
    @assert issorted(c.exdates)

    paths = m.m.paths
    T = eltype(paths)

    npaths = size(paths,1)

    B = Array{Float64}(undef, 1+m.degree, 1+c.nxmax, length(c.exdates))
    dt_nxt = last(c.exdates)
    dt_i = date2index(m.m, dt_nxt)

    P = [float(valueat(ms, c.penalty, dt_i)) for ms in scenarios(m.m)]
    CV = [max(c.nxmin-q, 0)*p for p in P, q in 0:c.nxmax]

    y = m.m.core.yieldcurve
    for x_i = reverse(eachindex(c.exdates))
        dt = c.exdates[x_i]
        dt_i = date2index(m.m, dt)

        X = [s^d for s in paths[:,dt_i], d in 0:m.degree]

        B[:,:,x_i] = β = X \ CV
        CV = X*β

        Δv = [valueat(ms, c.alternate, dt_i)-valueat(ms, c.default, dt_i) for ms in scenarios(m.m)]

        D = discount(y, yearfraction(daycount(y), dt, dt_nxt))

        for n = 1:npaths
            for q in 0:c.nxmax-1
                CV[n,1+q] = D*max(CV[n,1+q], CV[n,2+q] + Δv[n])
            end
            CV[n,1+c.nxmax] = D*CV[n,1+c.nxmax]
        end
        dt_nxt = dt
    end
    LSMCSwingOptionExerciseRule(B)
end

function value(m::MonteCarloModel, c::DiscreteSwingContract, r::LSMCSwingOptionExerciseRule)

    degree = size(r.B,1)-1
    paths = m.paths
    T = eltype(paths)

    y = m.core.yieldcurve

    TV = zero(T)
    for ms in scenarios(m)
        V = zero(T)
        q = 0
        for (x_i, dt) in enumerate(c.exdates)
            D = discount(y, dt)
            dt_i = date2index(m, dt)

            v0 = valueat(ms, c.default, dt_i)
            if q == c.nxmax
                V += D*v0
            else
                s = ms.path[dt_i]
                v1 = valueat(ms, c.alternate, dt_i)
                x = [s^d for d in 0:degree]
                if dot(x,r.B[:, q+2, x_i]) + v1 > dot(x,r.B[:, q+1, x_i]) + v0
                    V += D*v1
                    q += 1
                else
                    V += D*v0
                end
            end
        end
        if q < c.nxmin
            dt = last(c.exdates)
            D = discount(y, dt)
            dt_i = date2index(m, dt)

            V += D * (c.nxmin-q) * valueat(ms, c.penalty, dt_i)
        end
        TV += V
    end
    TV / size(m.paths, 1)
end

function delta(m::MonteCarloModel{C}, c::DiscreteSwingContract, r::LSMCSwingOptionExerciseRule) where C<:CoreForwardModel

    degree = size(r.B,1)-1
    paths = m.paths
    T = eltype(paths)

    y = m.core.yieldcurve

    TΔ = zeros(T, length(m.core.forwarddates))
    for ms in scenarios(m)
        q = 0
        for (x_i, dt) in enumerate(c.exdates)
            D = discount(y, dt)
            dt_i = date2index(m, dt)
            cfdt_i = date2index(m.core, dt)

            v0 = valueat(ms, c.default, dt_i, Dual)
            if q == c.nxmax
                TΔ[cfdt_i] += extract_derivative(D*v0)
            else
                s = ms.path[dt_i]
                v1 = valueat(ms, c.alternate, dt_i, Dual)
                x = [s^d for d in 0:degree]
                if dot(x,r.B[:, q+2, x_i]) + v1 > dot(x,r.B[:, q+1, x_i]) + v0
                    TΔ[cfdt_i] += extract_derivative(D*v1)
                    q += 1
                else
                    TΔ[cfdt_i] += extract_derivative(D*v0)
                end
            end
        end
        if q < c.nxmin
            dt = last(c.exdates)
            cfdt_i = date2index(m.core, dt)
            D = discount(y, dt)
            dt_i = date2index(m, dt)

            TΔ[cfdt_i] += extract_derivative(D * (c.nxmin-q) * valueat(ms, c.penalty, dt_i, Dual))
        end
    end
    TΔ ./ size(m.paths, 1)
end


function value(m::AbstractModel, c::DiscreteSwingContract, ::Type{LeastSquaresMonteCarlo}, npaths::Int, degree::Int)
    mcm1 = montecarlo(m, c.exdates, npaths)
    ox = optimalexercise(LeastSquaresMonteCarlo(mcm1, degree), c)
    mcm2 = montecarlo(m, c.exdates, npaths)
    value(mcm2, c, ox)
end

function delta(m::AbstractModel, c::DiscreteSwingContract, ::Type{LeastSquaresMonteCarlo}, npaths::Int, degree::Int)
    mcm1 = montecarlo(m, c.exdates, npaths)
    ox = optimalexercise(LeastSquaresMonteCarlo(mcm1, degree), c)
    mcm2 = montecarlo(m, c.exdates, npaths)
    delta(mcm2, c, ox)
end



function value(m::HullWhiteTrinomialModel, c::DiscreteSwingContract)
    @assert issorted(c.exdates)
    
    dt = last(c.exdates)
    dt_i = date2index(m, dt)

    Tp = typeof(float(valueat(m, c.penalty, 1, 1+m.nmax)))
    Td = typeof(float(valueat(m, c.default, 1, 1+m.nmax)))
    Ta = typeof(float(valueat(m, c.alternate, 1, 1+m.nmax)))
    T = promote_type(Tp, Td, Ta)

    P = T[float(valueat(m, c.penalty, dt_i, j)) for j in 1:1+2*m.nmax]
    V = [max(c.nxmin-q, 0)*p for p in P, q in 0:c.nxmax]

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
        Xd = [valueat(m, c.default, dt_i, j) for j in 1:1+2*m.nmax]
        Xa = [valueat(m, c.alternate, dt_i, j) for j in 1:1+2*m.nmax]
        for q = 0:c.nxmax
            for j = 1:1+2*m.nmax
                if q < c.nxmax
                    V[j,q+1] = max(D*V[j,q+1]+Xd[j], D*V[j,q+2]+Xa[j])
                else
                    V[j,q+1] = D*V[j,q+1]+Xd[j]
                end
            end
        end
    end
    dt_nxt = dt

    while startdate(m.core) < dt
        backiterate!(V,m)
        dt -= Dates.Day(1)
    end        
    D = discount(y, yearfraction(daycount(y), dt, dt_nxt))
    return V[1+m.nmax, 1]*D
end