module Currency

import ForwardDiff: Dual
import ..extract_derivative
import Base.promote_type
export CurrencyUnit, CurrencyQuantity, unit, USD, GBP, currval

struct CurrencyUnit{S}
end

struct CurrencyQuantity{U<:CurrencyUnit,T<:Real} <: Number
    val::T
    CurrencyQuantity{U,T}(val::T) where {U<:CurrencyUnit,T<:Real} = new(val)
end
CurrencyQuantity{S}(x::T) where {S,T<:Real} = CurrencyQuantity{S,T}(x)


import Base: show, zero, one, length, float, convert
show(io::IO, x::CurrencyUnit{S}) where {S} = print(io, S)
show(io::IO, x::CurrencyQuantity{U}) where {U} = print(io, x.val, U())

unit(x::CurrencyQuantity{U}) where {U} = U()
unit(x::Real) = one(x)

zero(::CurrencyQuantity{U,T}) where {U,T} = CurrencyQuantity{U,T}(zero(T))
zero(::Type{CurrencyQuantity{U,T}}) where {U,T} = CurrencyQuantity{U,T}(zero(T))
one(::CurrencyQuantity{U,T}) where {U,T} = CurrencyQuantity{U,T}(one(T))
one(::Type{CurrencyQuantity{U,T}}) where {U,T} = CurrencyQuantity{U,T}(one(T))

convert(::Type{CurrencyQuantity{U,S}}, x::CurrencyQuantity{U,T}) where {U,S,T} = CurrencyQuantity{U,S}(convert(S,x.val))
float(x::CurrencyQuantity{U,T}) where {U,T} = CurrencyQuantity{U}(float(x.val))

# Make CurrencyUnit broadcast as a scalar
Base.Broadcast.broadcastable(c::CurrencyUnit) = Ref(c)

import Base: +, -, *, /, abs, ==, <, <=, div, rem, isless, isequal, isapprox

(-)(x::CurrencyQuantity{U}) where {U<:CurrencyUnit} = CurrencyQuantity{U}(-x.val)

(+)(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U<:CurrencyUnit} = CurrencyQuantity{U}(x.val+y.val)
(-)(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U<:CurrencyUnit} = CurrencyQuantity{U}(x.val-y.val)

(*)(::U, x::Real) where {U<:CurrencyUnit} = CurrencyQuantity{U}(x)
(*)(x::Real, ::U) where {U<:CurrencyUnit} = CurrencyQuantity{U}(x)

(*)(x::CurrencyQuantity{U}, y::Real) where {U<:CurrencyUnit} = CurrencyQuantity{U}(x.val*y)
(*)(x::Real, y::CurrencyQuantity{U}) where {U<:CurrencyUnit} = CurrencyQuantity{U}(x*y.val)

(/)(x::CurrencyQuantity{U}, y::Real) where {U<:CurrencyUnit} = CurrencyQuantity{U}(x.val/y)
(/)(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U<:CurrencyUnit} = x.val/y.val
(/)(x::CurrencyQuantity{U}, ::U) where {U<:CurrencyUnit} = x.val

abs(x::CurrencyQuantity{U}) where {U} = CurrencyQuantity{U}(abs(x.val))

(==)(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U} = x.val == y.val
(<)(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U} = x.val < y.val
(<=)(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U} = x.val <= y.val

div(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U} = div(x.val, y.val)
rem(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U} = CurrencyQuantity{U}(rem(x.val, y.val))

isless(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U} = isless(x.val, y.val)
isequal(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}) where {U} = isequal(x.val, y.val)

function isapprox(x::CurrencyQuantity{U}, y::CurrencyQuantity{U}; kwargs...) where U
    isapprox(x.val, y.val; kwargs...)
end

function (::Base.Colon)(start::CurrencyQuantity{U}, stop::CurrencyQuantity{U}) where {U}
    r = start.val:stop.val
    StepRangeLen{CurrencyQuantity{U,eltype(r)}}(r.ref, r.step, r.len, r.offset)
end
function (::Base.Colon)(start::CurrencyQuantity{U}, step::CurrencyQuantity{U}, stop::CurrencyQuantity{U}) where {U}
    r = start.val:step.val:stop.val
    StepRangeLen{CurrencyQuantity{U,eltype(r)}}(r.ref, r.step, r.len, r.offset)
end


macro defcurrency(S)
    :($(esc(S)) = CurrencyUnit{$(QuoteNode(S))}())
end
@defcurrency USD
@defcurrency GBP

# Play nice with Dual Numbers
Dual(x::CurrencyQuantity{U,T}, v) where {U,T} = Dual(x.val, v) * U()

promote_type(::Type{CurrencyQuantity{S,T}}, ::Type{V}) where {S,T,V} =
    CurrencyQuantity{S,promote_type(T,V)}
promote_type(::Type{CurrencyQuantity{S,T}}, ::Type{D}) where {S,T,D<:Dual} =
    CurrencyQuantity{S,promote_type(T,D)}

extract_derivative(x::CurrencyQuantity{S, D}) where {S,D<:Dual} =
    extract_derivative(x.val) * S()
currval(x::CurrencyQuantity{S,V}) where {S,V} = x.val
currval(x::T) where {T<:Real} = x

end # module Currencies
