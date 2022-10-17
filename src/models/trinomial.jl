export HullWhiteTrinomialModel


struct HullWhiteTrinomialModel{C,D,T} <: AbstractModel
    core::C
    dates::D
    scale::Vector{T}
    k::Int
    nmax::Int
    grid::Vector{Float64}
    transition::Matrix{Float64}
end

numeraire(m::HullWhiteTrinomialModel) = numeraire(m.core)


"""
    HullWhiteTrinomialModel

This is a Hull-White trinomial model, a discrete approximation of a `GeomOUModel`. The arguments are:

- `m::GeomOUModel`: the model to approximate
- `dates::AbstractVector{Date}` (optional): the dates at which to compute the approximation. By default, the forward dates are used (if available).
- `k::Int` (default=1): the number of discrete steps per day to use
- `cap::Int` (default=0.2): a parameter between 0.184 and 0.577 used to determine how to truncate the branching (larger values give less truncation).
"""
function HullWhiteTrinomialModel(m::GeomOUModel, dates::AbstractVector{Date}, k::Int=1, cap::Float64=0.2)
    δt = 1/(365*k)
    δX = m.σ*sqrt(3*δt)
    nmax = ceil(Int, cap/(m.θ*δt))
    grid = [exp(δX*n) for n = -nmax:nmax]
    transition = Array{Float64}(undef, 3,2nmax+1)
    for (j,n) = enumerate(-nmax:nmax)
        x = m.θ*n*δt
        if n == -nmax
            transition[1,j] = 7/6 + x*(x+3)/2 # straight
            transition[2,j] = -1/3 - x*(x+2)  # up 1
            transition[3,j] = 1/6 + x*(x+1)/2 # up 2
        elseif n == nmax
            transition[1,j] = 1/6 + x*(x-1)/2 # down 2
            transition[2,j] = -1/3 - x*(x-2)  # down 1
            transition[3,j] = 7/6 + x*(x-3)/2 # straight
        else
            transition[1,j] = 1/6 + x*(x+1)/2 # down
            transition[2,j] = 2/3 - x^2       # straight
            transition[3,j] = 1/6 + x*(x-1)/2 # up
        end
    end

    dt = startdate(m.core)
    P = zeros(Float64, 2*nmax+1)
    P[nmax+1] = 1.0
    Pnext = similar(P)

    scale = map(dates) do valdt
        while dt < valdt
            for i = 1:k
                fill!(Pnext, 0.0)
                for (j,n) in enumerate(-nmax:nmax)
                    if n == -nmax
                        Pnext[j]   += P[j]*transition[1,j] # straight
                        Pnext[j+1] += P[j]*transition[2,j] # up 1
                        Pnext[j+2] += P[j]*transition[3,j] # up 2
                    elseif n == nmax
                        Pnext[j-2] += P[j]*transition[1,j] # down 2
                        Pnext[j-1] += P[j]*transition[2,j] # down 1
                        Pnext[j]   += P[j]*transition[3,j] # straight
                    else
                        Pnext[j-1] += P[j]*transition[1,j] # down
                        Pnext[j]   += P[j]*transition[2,j] # straight
                        Pnext[j+1] += P[j]*transition[3,j] # up
                    end
                end
                copyto!(P,Pnext)
            end
            dt += Dates.Day(1)
        end
        forwardprice(m, SingleStock(), dt) / dot(P, grid)
    end
    HullWhiteTrinomialModel(m.core, dates, scale, k, nmax, grid, transition)
end

HullWhiteTrinomialModel(m::GeomOUModel{C}, k::Int=1, cap::Float64=0.2) where {C<:CoreForwardModel} =
    HullWhiteTrinomialModel(m, m.core.forwarddates, k, cap)

@inline valueat(m::HullWhiteTrinomialModel, s::SingleStock, dt_i, n_i) =
    m.scale[dt_i]*m.grid[n_i]

function date2index(m::HullWhiteTrinomialModel, dt::Date)
    ii = searchsorted(m.dates, dt)
    isempty(ii) && throw(DomainError())
    return ii[1]
end


function backiterate!(V, m::HullWhiteTrinomialModel)
    for i = 1:m.k
        for u = 1:size(V,2)
            va = V[1,u]
            vb = V[2,u]
            vc = V[3,u]
            for j = 1:1+2*m.nmax
                if 2 < j < 1+2*m.nmax
                    va = vb
                    vb = vc
                    vc = V[j+1,u]
                end
                V[j,u] = va*m.transition[1,j] + vb*m.transition[2,j] + vc*m.transition[3,j]
            end
        end
    end
end
