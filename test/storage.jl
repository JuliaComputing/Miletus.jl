using Test
using Miletus
import Miletus: Zero

dates = Date("2017-06-01"):Day(1):Date("2017-08-01")
fwds = [exp((log(3.9)-1.7)*exp(-1.2*t) + 1.7 + 0.59^2*(1-exp(-2.4*t))/4.8) for t = range(0, stop=1, length=length(dates))]

core = CoreForwardModel(Date("2014-06-01"),dates,fwds,0.01)
m = GeomOUModel(core, 1.2, 0.59)

h = HullWhiteTrinomialModel(m)

Random.seed!(1)
mcm = montecarlo(m, dates, 10_000)
mcm2 = montecarlo(m, dates, 10_000)

import Miletus: Both, Scale, Pay, Give, Zero

states = 1:20

# ToepelitzTransition(length(states), -3:1, (

Tmat = [if to == from # same state
                           Zero()
                           elseif from - 3 <= to < from # decrease storage
                           Both(Scale(from-to, SingleStock()),Pay(0.01))
                           elseif to == from + 1 # increase storage by 1
                           Both(Give(SingleStock()), Pay(0.01))
                           else
                           Pay(1e9)
end for from in states, to in states]

Ttoe = Miletus.MaskedToepelitzTransition(BitArray(true for i=states, j=states),
                                   -3:+1,
                                   (Both(Scale(3, SingleStock()),Pay(0.01)),
                                    Both(Scale(2, SingleStock()),Pay(0.01)),
                                    Both(Scale(1, SingleStock()),Pay(0.01)),
                                    Zero(),
                                    Both(Give(SingleStock()), Pay(0.01))))

csmat = LatticeStateContract(Tmat,
                         [state == 1 ? Pay(0.0) : Pay(1e9) for state = states],
                         dates[2:end])
cstoe = LatticeStateContract(Ttoe,
                         [state == 1 ? Pay(0.0) : Pay(1e9) for state = states],
                         dates[2:end])

v = value(h,csmat)
@test v ≈ value(h,cstoe)

Bsmat = Miletus.optimalexercise(LeastSquaresMonteCarlo(mcm,5), csmat)
@test isapprox(v, value(mcm2, csmat, Bsmat), atol=2.0)
Bstoe = Miletus.optimalexercise(LeastSquaresMonteCarlo(mcm,5), cstoe)
@test isapprox(v, value(mcm2, cstoe, Bstoe), atol=2.0)

d = delta(h, csmat)
@test d ≈ delta(h,cstoe)
@test isapprox(d, delta(mcm2, csmat, Bsmat), atol=200.0)
@test isapprox(d, delta(mcm2, cstoe, Bstoe), atol=200.0)