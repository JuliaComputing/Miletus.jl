export vanqr

function vanqr(p::Vector{Float64}, n::Int)
    m = length(p)
    B = zeros(m, n)
    Q = zeros(Complex{Float64}, m, n)
    B = Matrix{Float64}(I, 2*n, n)
    σ = zeros(n)
    μ = zeros(n)
    ν = zeros(n)
    σ[1] = m
    for j = 2 : 2n-1
        B[j,1] = norm(p .^ (j - 1), 1) / σ[1]
    end
    μ[1] = B[2,1]
    ν[1] = B[3,1]
    σ[2] = σ[1] * (ν[1] - μ[1]^2)
    for j = 3 : 2n-2
        B[j,2] = (σ[1] / σ[2]) * (B[j+1, 1] - μ[1]*B[j,1])
    end
    Q[:, 1] .= 1 / sqrt(σ[1])
    Q[:, 2] .= (p .- μ[1]) ./ sqrt(σ[2])
    for k = 3:n
        μ[k-1] = B[k, k-1]
        ν[k-1] = B[k+1, k-1]
        σ[k] = σ[k-1] * (ν[k-1] - ν[k-2] + μ[k-1] * (μ[k-2] - μ[k-1]))
        for j = k+1 : 2n-k
            B[j,k] = (σ[k-1] / σ[k]) * (B[j+1, k-1] - B[j, k-2] + 
                        (μ[k-2] - μ[k-1]) * B[j, k-1])
        end
        Q[:,k] .= sqrt(complex(σ[k-1] / σ[k])) .* ((p .+ (μ[k-2] - μ[k-1])) .* Q[:,k-1] .- 
                        sqrt(complex(σ[k-1] / σ[k-2])) .* Q[:,k-2] )
    end
    Σ = diagm(0=>sqrt.(σ))
    B = B[1:n, :]
    B, Σ, map(Float64,Q)
end