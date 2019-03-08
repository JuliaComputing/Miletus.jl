import Dates: Date, year, month, day

cd(dirname(@__FILE__))

function jl_am_put_crr(S,K,r,c,σ,dt1,dt2,N)
    t = Int(dt2 - dt1)/365
    Δt = t/N
    u = exp(σ*√Δt)
    d = exp(-σ*√Δt)
    B = exp((r-c)*Δt)
    p = (B-d)/(u-d)
    q = (u-B)/(u-d)
    iR = exp(-Δt*r)

    # final time
    Z = map(0:N) do i
        x = K - S*exp((2*i-N)σ*√Δt)
        max(x,0)
    end
    
    for n = N-1:-1:0
        for i = 0:n
            x = K - S*exp((2*i-n)σ*√Δt)
            y = iR*(q*Z[i+1] + p*Z[i+2])
            Z[i+1] = max(x, y)
        end
    end
    return Z[1]
end


function ql_am_put_crr(S,K,r,c,σ,dt1::Date,dt2::Date, n)
    ccall((:ql_am_put_crr, :quantlib), Cdouble,
          (Cdouble, Cdouble, Cdouble, Cdouble, Cdouble,
           Cint, Cint, Cint,
           Cint, Cint, Cint,
           Cint),
          S, K, r, c, σ,
          year(dt1), month(dt1), day(dt1),
          year(dt2), month(dt2), day(dt2),
          n)
end

using BenchmarkTools
using Miletus

println("CRR Model")
println("=========")
println()

println("Miletus")
println(@benchmark value(CRRModel(Date(2010,01,01), Date(2011,01,01), 801, 36.0, 0.06, 0.0, 0.2),
                 AmericanPut(Date(2011,01,01), SingleStock(), 40.0)))


println("Miletus Currency")
println(@benchmark value(CRRModel(Date(2010,01,01), Date(2011,01,01), 801, 36.0USD, 0.06, 0.0, 0.2),
                 AmericanPut(Date(2011,01,01), SingleStock(), 40.0USD)))

if isfile("quantlib")
    println()
    println("QuantLib")
    println(@benchmark ql_am_put_crr(40.0, 36.0, 0.06, 0.0, 0.2,
                                     Date(2010,01,01), Date(2011,01,01), 801))
end

println()
println("Pure Julia")
println(@benchmark jl_am_put_crr(40.0, 36.0, 0.06, 0.0, 0.2,
           Date(2010,01,01), Date(2011,01,01), 801))
println()
println()


println("Monte Carlo Model")
println("=========")
println()

d1 = Dates.today()
d2 = d1 + Dates.Day(120)
m = GeomBMModel(d1, 100.00, 0.05, 0.0, 0.3)
o = EuropeanCall(d2, SingleStock(), 100.00)

println("Miletus")
println(@benchmark value($m, $o, $MonteCarloModel, 10_000))
println()

m = GeomBMModel(d1, 100.00USD, 0.05, 0.0, 0.3)
o = EuropeanCall(d2, SingleStock(), 100.00USD)

println("Miletus Currency")
println(@benchmark value($m, $o, $MonteCarloModel, 10_000))
println()

println("Least Squares Monte Carlo Model")
println("=========")
println()

d1 = Dates.today()
d2 = d1 + Dates.Day(120)
m = GeomBMModel(d1, 100.00, 0.05, 0.0, 0.3)
o = AmericanPut(d2, SingleStock(), 100.00)

println("Miletus")
println(@benchmark value($m, $o, $LeastSquaresMonteCarlo, 10_000, 3))
println()
