using Test
using Miletus

dates = Date("2014-06-01"):Day(1):Date("2015-06-01")
fwds = [exp((log(3.9)-1.7)*exp(-1.2*t) + 1.7 + 0.59^2*(1-exp(-2.4*t))/4.8) for t = range(0, stop=1, length=length(dates))]

core = CoreForwardModel(Date("2014-06-01"),dates,fwds,0.01)
m = GeomOUModel(core, 1.2, 0.59)

h = HullWhiteTrinomialModel(m)

@test value(m, Miletus.Zero()) == 0
@test value(h, Miletus.Zero()) == 0


cb = Buy(SingleStock(), 4.69)
c = DiscreteSwingContract(Miletus.Scale(10000,cb), # default
        Miletus.Either(Miletus.Scale(2500,cb),Miletus.Scale(15000,cb)), # alternate
        Miletus.Pay(10000), # penalty
        dates[2:end], # exercise dates
                          0, 5) # min, max swings

Δh = delta(h,c)
@test length(Δh) == length(dates)


Random.seed!(1)
mcm = montecarlo(m, dates, 10_000)

# 1. Construct the optimal exercise schedule
B = Miletus.optimalexercise(LeastSquaresMonteCarlo(mcm,5), c);

# 2. Price the option under this schedule
# One should use a fresh sample to reduce bias
# In this case we want a larger sample due to reduce the large Monte Carlo error
Random.seed!(2)
mcm2 = montecarlo(m, dates, 200_000)

@test isapprox(value(mcm2, c, B), value(h,c), atol=30_000)

Δ1 = delta(mcm2, c, B)
@test isapprox(Δ1,Δh, atol=5000)

Δ2 = delta(m, c, LeastSquaresMonteCarlo, 10_000,3)
@test isapprox(Δ2,Δh, atol=5000)



c_diff = DiscreteSwingContract(
        Miletus.Zero(), # default
        Miletus.Both(
            Miletus.Either(Miletus.Scale(2500,cb),Miletus.Scale(15000,cb)),
            Miletus.Give(Miletus.Scale(10000,cb))),
        Miletus.Pay(100000), # penalty
        dates[2:end], # exercise dates
                               0,5)

B = Miletus.optimalexercise(LeastSquaresMonteCarlo(montecarlo(m, dates, 10000),5), c_diff)
@test isapprox(value(mcm2, c_diff, B), 57000, atol=1000)

@test isapprox(value(m, c_diff, LeastSquaresMonteCarlo, 10_000, 5), 57000, atol=1000)

Δ = delta(mcm2, c_diff, B)
@test length(Δ) == length(dates)