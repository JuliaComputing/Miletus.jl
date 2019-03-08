

Base.show(io::IO, c::Contract) = _show_tree(io, c)
Base.show(io::IO, o::Observable) = _show_tree(io, o)

_show_root(io::IO, x) = print(io, x)
_children(x) = ()

_show_root(io::IO, c::Contract) = printstyled(io, string(typeof(c).name.name), color=:magenta)
_children(c::Contract) = (getfield(c,i) for i = 1:nfields(c))

_show_root(io::IO, o::Observable) = printstyled(io, string(typeof(o).name.name), color=:cyan)
_children(o::Observable) = (getfield(o,i) for i = 1:nfields(o))

_show_root(io::IO, o::ConstObs) = printstyled(io, string(o.val), color=:yellow)
_children(o::ConstObs) = ()


function _show_root(io::IO, o::LiftObs)
    printstyled(io, "{", color=:cyan)
    print(io,o.f)
    printstyled(io, "}", color=:cyan)
end
_children(o::LiftObs) = o.a

function _show_tree(io::IO, x, indent_root="", indent_leaf="")
    print(io, indent_root)
    _show_root(io, x)
    print(io, '\n')
    cs = _children(x)
    for (i,c) in enumerate(cs)
        if i < length(cs)
            _show_tree(io, c, indent_leaf*" ├─",indent_leaf*" │ ")
        else
            _show_tree(io, c, indent_leaf*" └─",indent_leaf*"   ")
        end
    end
end

function Base.show(io::IO, m::GeomBMModel{C}) where C<:CoreModel
    str = "Geometric Brownian Motion Model"
    print(io, str)
    print(io, "\n")
    println(io, prod(fill("-", length(str))))
    println(io, "S₀ = $(m.core.startprice)")
    println(io, "T = $(m.core.yieldcurve.reference_date)")
    print(io, "Yield "); println(io, m.core.yieldcurve)
    print(io, "Carry "); println(io, m.core.carrycurve)
    println(io, "σ = $(m.volatility)")
end

function Base.show(io::IO, m::GeomBMModel{C}) where C<:CoreForwardModel
    str = "Geometric Brownian Motion Model"
    print(io, str)
    print(io, "\n")
    println(io, prod(fill("-", length(str))))
    println(io, "Forward-based prices")
    println(io, "T = $(m.core.yieldcurve.reference_date)")
    print(io, "Yield "); println(io, m.core.yieldcurve)
    println(io, "σ = $(m.volatility)")
end


function Base.show(io::IO, x::ConstantYieldCurve)
    print(io, "Constant Curve with r = $(x.rate), T = $(x.reference_date) and $(x.compounding) Compounding")
end

function Base.show(io::IO, x::ConstantContinuousYieldCurve)
    print(io, "Constant Continuous Curve with r = $(x.rate), T = $(x.reference_date) ")
end

function Base.show(io::IO, m::CoreModel)
    str = "Core Model"
    print(io, str)
    print(io, "\n")
    println(io, prod(fill("-", length(str))))
    println(io, "S₀ = $(m.startprice)")
    println(io, "T = $(m.yieldcurve.reference_date)")
    print(io, "Yield "); println(io, m.yieldcurve)
    print(io, "Carry "); println(io, m.carrycurve)
end

function Base.show(io::IO, m::MonteCarloModel)
    str = "Monte Carlo Model"
    print(io, str)
    print(io, "\n")
    println(io, prod(fill("-", length(str))))
    str = "every"
    if m.dates.step.value == 1
        str *= "day"
    else
        str *= " $(m.dates.step)"
    end
    println(io, "$(size(m.paths, 1)) Simulations $str from $(first(m.dates)) to $(last(m.dates))")
    print(io, "Yield "); println(io, m.core.yieldcurve)
end

function Base.show(io::IO, m::T) where T<:AbstractModel
    print(io, T)
end
