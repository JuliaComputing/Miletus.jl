struct LeastSquaresMonteCarlo{M<:MonteCarloModel}
    m::M
    degree::Int
end


function value(m::LeastSquaresMonteCarlo, c::AnytimeBefore{C}) where C
    uc = c.c # underlying contract
    N = date2index(m.m, maturitydate(c))
    R = discount(m.m.core.yieldcurve, m.m.dates[2]) # TODO: could be better...

    V = [valueat(ms, uc, N)*R for ms in scenarios(m.m)]
    for n = N-1:-1:2
        I = V .> 0 # in the money options
        A = [x^d for d = 0:m.degree, x in m.m.paths[:,n]] # design matrix
        β = A[:,I]' \ V[I] # least squares regression
        cV = A'*β          # estimated continuation values
        for (p,ms) in enumerate(scenarios(m.m))
            ev = valueat(ms,uc,n)  # exercise value
            if I[p] && cV[p] < ev
                # in-the-money and exercise is greater than continuation
                V[p] = ev*R
            else
                V[p] *= R
            end
        end
    end
    return max(mean(V), mean(valueat(ms, uc, N) for ms in scenarios(m.m)))
end

function value(m::GeomBMModel, c::Contract, ::Type{LeastSquaresMonteCarlo}, npaths::Integer, degree::Integer)
    mcm = montecarlo(m, startdate(m):Day(1):maturitydate(c), npaths)
    value(LeastSquaresMonteCarlo(mcm, degree), c)
end

