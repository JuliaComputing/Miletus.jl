module Miletus

using Dates, LinearAlgebra
using Dates: days
using Statistics: mean

export CurrencyUnit, CurrencyQuantity, USD, GBP,
 value, process, ivol, fit, fit_ivol,
 SingleStock, CoreModel, CoreForwardModel, GeomBMModel,
 montecarlo, MonteCarloModel, LeastSquaresMonteCarlo

import Optim
import StatsBase: fit
import StatsFuns: normcdf, norminvcdf, normpdf, invsqrt2, sqrthalfπ, invsqrt2π, logistic, logit
import Base.Math: @horner
import ForwardDiff: Dual

extract_derivative(x::Dual) = ForwardDiff.partials(x,1)
extract_derivative(x::Real) = zero(x)

import Reexport: @reexport
@reexport using BusinessDays

const Φ = normcdf
const invΦ = norminvcdf
const ϕ = normpdf




include("daycounts.jl")
include("termstructure.jl")
using .TermStructure

include("currency.jl")
using .Currency

include("utils/math.jl")
include("utils/black.jl")
include("utils/ivol.jl")

include("observables.jl")
include("contracts.jl")
include("process.jl")


include("models/abstractmodel.jl")
include("models/core.jl")
include("models/coreforward.jl")
include("models/geombm.jl")
include("models/binomial.jl")
include("models/binomial_ivol.jl")

include("models/montecarlo.jl")
include("models/lsmc.jl")

include("print.jl")

include("greeks.jl")
export vega, delta, rho, greek

end # module
