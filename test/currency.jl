using Test
using Miletus.Currency

@test 100USD == 100.00USD
@test 100USD < 200.00USD
@test 200USD > 100.00USD
@test 100USD <= 200.00USD
@test 200USD >= 100.00USD
@test length(90.0USD:0.01USD:110.0USD) == 2001
