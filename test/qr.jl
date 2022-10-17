using Test, Random, MiletusPro

a = map(Float64, sort(randperm(1000)))
b, s, q = vanqr(a, 3)
At = q * s * b'
A = [ones(1000) a a.^2]
@test At ≈ A
