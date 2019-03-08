# test greeks

let

    # Setup
    d1 = today()
    d2 = d1 + Day(150)
    c1 = EuropeanCall(d2, SingleStock(), 56.5USD)
    core1 = CoreModel(d1, 47.32USD, 0.0, 0.0)
    c2 = EuropeanCall(d2, SingleStock(), 56.5)
    core2 = CoreModel(d1, 47.32, 0.0, 0.0)
    gbm1 = GeomBMModel(core1, 0.1)
    gbm2 = GeomBMModel(core2, 0.1)
    Random.seed!(1)
    mc1 = montecarlo(gbm1, d1:Day(1):d2, 10000)
    Random.seed!(1)
    mc2 = montecarlo(gbm2, d1:Day(1):d2, 10000)

    # Compare with math formulae
    @test delta(gbm1, c1; autodiff = true) ≈ delta(gbm1, c1)
    @test vega(gbm1, c1; autodiff = true) ≈ vega(gbm1, c1)
    @test delta(gbm2, c2; autodiff = true) ≈ delta(gbm2, c2)
    @test vega(gbm2, c2; autodiff = true) ≈ vega(gbm2, c2)
    @test greek(gbm1, c1; metric = :vol) ≈ vega(gbm1, c1)
    @test greek(gbm2, c2; metric = :vol) ≈ vega(gbm2, c2)
    @test greek(gbm1, c1; metric = :strike) ≈ delta(gbm1, c1)
    @test greek(gbm2, c2; metric = :strike) ≈ delta(gbm2, c2)

    # Monte Carlo models greeks - vega
    let
        vol = gbm1.volatility + 1e-8
        gbm3 = GeomBMModel(gbm1.core, vol)
        Random.seed!(1)
        mc3 = montecarlo(gbm3, mc1.dates, size(mc1.paths, 1))
        x = (value(mc3, c1) - value(mc1, c1)) / 1e-8
        Random.seed!(1)
        @test isapprox(x, vega(gbm1, c1, MonteCarloModel, d1:Day(1):d2, 10000), rtol = 1e-4)
        #srand(1)
        #@test isapprox(x, greek(mc1, c1; metric = :vol), rtol = 1e-4)

        vol = gbm2.volatility + 1e-8
        gbm4 = GeomBMModel(gbm2.core, vol)
        Random.seed!(1)
        mc4 = montecarlo(gbm4, mc2.dates, size(mc2.paths, 1))
        x = (value(mc4, c2) - value(mc2, c2)) / 1e-8
        Random.seed!(1)
        @test isapprox(x, vega(gbm2, c2, MonteCarloModel, d1:Day(1):d2, 10000), rtol = 1e-4)
        #srand(1)
        #@test isapprox(x, greek(mc2, c2; metric = :vol), rtol = 1e-4)
    end

    # Monte Carlo models greeks - delta
    let
        s = gbm1.core.startprice + (1e-8 * USD)
        vol = gbm1.volatility
        gbm3 = GeomBMModel(gbm1.core.carrycurve.reference_date, s,
                            gbm1.core.yieldcurve.rate, gbm1.core.carrycurve.rate, vol)
        Random.seed!(1)
        mc3 = montecarlo(gbm3, mc1.dates, size(mc1.paths, 1))
        x = (value(mc3, c1) - value(mc1, c1)) / 1e-8
        Random.seed!(1)
        @test isapprox(x.val, delta(gbm1, c1, MonteCarloModel, d1:Day(1):d2, 10000), rtol = 1e-4)
        #srand(1)
        #@test isapprox(x.val, greek(mc1, c1; metric = :strike), rtol = 1e-4)

        s = gbm2.core.startprice + 1e-8
        vol = gbm2.volatility
        gbm4 = GeomBMModel(gbm2.core.carrycurve.reference_date, s,
                            gbm2.core.yieldcurve.rate, gbm2.core.carrycurve.rate, vol)
        Random.seed!(1)
        mc4 = montecarlo(gbm4, mc2.dates, size(mc2.paths, 1))
        x = (value(mc4, c2) - value(mc2, c2)) / 1e-8
        Random.seed!(1)
        @test isapprox(x, delta(gbm2, c2, MonteCarloModel, d1:Day(1):d2, 10000), rtol = 1e-4)
        #srand(1)
        #@test isapprox(x, greek(mc2, c2; metric = :strike), rtol = 1e-4)
    end

    # Compare rho with forward difference
    let
        r = gbm1.core.yieldcurve.rate + 1e-8
        gbm3 = GeomBMModel(gbm1.core.carrycurve.reference_date, gbm1.core.startprice,
                                 r, gbm1.core.carrycurve.rate, gbm1.volatility)
        x = (value(gbm3, c1) - value(gbm1,c1)) / 1e-8
        @test isapprox(x, rho(gbm1, c1), rtol = 1e-4)
        @test isapprox(x, greek(gbm1, c1; metric = :interest), rtol = 1e-4)

        Random.seed!(1)
        mc3 = montecarlo(gbm3, mc1.dates, size(mc1.paths,1))
        x = (value(mc3, c1) - value(mc1,c1)) / 1e-8
        Random.seed!(1)
        @test isapprox(x, rho(gbm1, c1, MonteCarloModel, d1:Day(1):d2, 10000), rtol = 1e-4)
        #srand(1)
        #@test isapprox(x, greek(mc1, c1; metric = :interest), rtol = 1e-4)


        gbm4 = GeomBMModel(gbm2.core.carrycurve.reference_date, gbm2.core.startprice,
                                 r, gbm2.core.carrycurve.rate, gbm2.volatility)
        x = (value(gbm4, c2) - value(gbm2,c2)) / 1e-8
        @test isapprox(x, rho(gbm2, c2), rtol = 1e-4)
        @test isapprox(x, greek(gbm2, c2; metric = :interest), rtol = 1e-4)

        Random.seed!(1)
        mc4 = montecarlo(gbm4, mc2.dates, size(mc2.paths,1))
        x = (value(mc4, c2) - value(mc2,c2)) / 1e-8
        Random.seed!(1)
        @test isapprox(x, rho(gbm2, c2, MonteCarloModel, d1:Day(1):d2, 10000), rtol = 1e-4)
        #srand(1)
        #@test isapprox(x, greek(mc2, c2; metric = :interest), rtol = 1e-4)
    end

    # Compare gamma with central difference
    let
        s1 = gbm1.core.startprice + (1e-4 * USD)
        s2 = gbm1.core.startprice - (1e-4 * USD)
        gbm31 = GeomBMModel(gbm1.core.carrycurve.reference_date, s1,
                            gbm1.core.yieldcurve.rate, gbm1.core.carrycurve.rate, gbm1.volatility)
        gbm32 = GeomBMModel(gbm1.core.carrycurve.reference_date, s2,
                            gbm1.core.yieldcurve.rate, gbm1.core.carrycurve.rate, gbm1.volatility)
        x = (value(gbm31,c1) + value(gbm32,c1) - (2 * value(gbm1, c1))) / (1e-4)^2
        @test isapprox(x.val, Miletus.gamma(gbm1, c1), rtol = 1e-4)
        @test isapprox(x.val, greek(gbm1, c1; metric = :strike, n = 2), rtol = 1e-4)

        Random.seed!(1)
        mc31 = montecarlo(gbm31, mc1.dates, size(mc1.paths, 1))
        Random.seed!(1)
        mc32 = montecarlo(gbm32, mc1.dates, size(mc1.paths, 1))
        x = (value(mc31,c1) + value(mc32,c1) - (2 * value(mc1, c1))) / (1e-4)^2
        Random.seed!(1)
        @test x.val - Miletus.gamma(gbm1, c1, MonteCarloModel, d1:Day(1):d2, 10000) < 1e-8
        Random.seed!(1)
        @test x.val - greek(gbm1, c1; metric = :strike, n = 2) < 1e-8

        s1 = gbm2.core.startprice + 1e-4
        s2 = gbm2.core.startprice - 1e-4
        gbm41 = GeomBMModel(gbm2.core.carrycurve.reference_date, s1,
                            gbm2.core.yieldcurve.rate, gbm2.core.carrycurve.rate, gbm2.volatility)
        gbm42 = GeomBMModel(gbm2.core.carrycurve.reference_date, s2,
                            gbm2.core.yieldcurve.rate, gbm2.core.carrycurve.rate, gbm2.volatility)
        x = (value(gbm41,c2) + value(gbm42,c2) - (2 * value(gbm2, c2))) / (1e-4)^2
        @test isapprox(x, Miletus.gamma(gbm2, c2), rtol = 1e-4)
        @test isapprox(x, greek(gbm2, c2; metric = :strike, n = 2), rtol = 1e-4)

        Random.seed!(1)
        mc41 = montecarlo(gbm41, mc2.dates, size(mc2.paths, 1))
        Random.seed!(1)
        mc42 = montecarlo(gbm42, mc2.dates, size(mc2.paths, 1))
        x = (value(mc41,c2) + value(mc42,c2) - (2 * value(mc2, c2))) / (1e-4)^2
        Random.seed!(1)
        @test x - Miletus.gamma(gbm2, c2, MonteCarloModel, d1:Day(1):d2, 10000) < 1e-8
        Random.seed!(1)
        @test x - greek(gbm2, c2; metric = :strike, n = 2) < 1e-8
    end

end

