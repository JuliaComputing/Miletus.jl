
s = SingleStock()
a = 100.00USD

d1 = Dates.today()
d2 = d1 + Dates.Day(120)

m = CoreModel(d1, a, 0.05, 0.0)

@test value(m, s) == a

@test value(m, Miletus.Zero()) == 0*a
@test value(m, Miletus.Receive(a)) == a

@test value(m, Pay(a)) == -a

@test value(m, Buy(s, a)) == 0USD
@test value(m, Sell(s, a)) == 0USD

@test value(m, Option(s)) == a

@test value(m, Forward(d2, s, 100.00USD)) ≈ 100.0USD * (1-exp(-0.05*120/365))

# assumes cost-of-carry
m = GeomBMModel(d1, a, 0.05, -0.1, 0.1)


@test value(m, Miletus.Zero()) == 0*a
@test value(m, Miletus.Receive(a)) == a

@test value(m, Pay(a)) == -a

@test value(m, Buy(s, a)) == 0USD
@test value(m, Sell(s, a)) == 0USD

@test value(m, Option(s)) == a

@test value(m, Scale(3, Option(s))) == 3*a


@test value(m, Forward(d2, s, 100.00USD)) ≈ 100.0USD * (exp(0.1*120/365)-exp(-0.05*120/365))


m = CoreForwardModel(d1,
                     [d1 + Dates.Day(30), d1 + Dates.Day(60), d1 + Dates.Day(120)],
                     [100.00USD, 110.00USD, 120.00USD],
                     0.05)

@test value(m, Forward(d2, s, 100.00USD)) ≈ (120.00USD - 100.0USD) * exp(-0.05*120/365)


