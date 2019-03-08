abstract type AbstractModel end
abstract type AbstractSingleModel <: AbstractModel end
# needs to be defined for each model

value(m::AbstractModel, ::DateObs) = startdate(m)
value(m::AbstractModel, x::ConstObs) = x.val
value(m::AbstractModel, ::Zero) = 0*numeraire(m)
value(m::AbstractModel, c::Amount) = value(m, c.o)
value(m::AbstractModel, c::Scale{ConstObs{T},C}) where {T,C} = c.s.val * value(m, c.c)

value(m::AbstractModel, c::Either) = max(value(m, c.c1), value(m, c.c2))
value(m::AbstractModel, c::Both) = value(m, c.c1) + value(m, c.c2)
value(m::AbstractModel, c::Give) = -value(m, c.c)


@inline valueat(m::AbstractModel, c::Either, i...) =
    max(valueat(m,c.c1,i...),valueat(m,c.c2,i...))

@inline valueat(m::AbstractModel, c::Zero, i...) =
    0.0*numeraire(m)

@inline valueat(m::AbstractModel, c::Amount, i...) =
    valueat(m, c.o, i...)

@inline valueat(m::AbstractModel, c::Both, i...) =
    valueat(m,c.c1, i...) + valueat(m,c.c2, i...)

@inline valueat(m::AbstractModel, c::Give, i...) =
    -valueat(m,c.c,i...)

@inline valueat(m::AbstractModel, c::Scale, i...) =
    valueat(m,c.s,i...)*valueat(m,c.c,i...)

@inline valueat(m::AbstractModel, o::ConstObs, i...) =
    o.val


value(m::AbstractModel, c::WhenAt{Zero}) = value(m, Zero())

value(m::AbstractModel, c::WhenAt{Both{C1,C2}}) where {C1,C2} =
    value(m, When(c.p, c.c.c1)) + value(m, When(c.p, c.c.c2))
value(m::AbstractModel, c::WhenAt{Give{C}}) where {C} =
    -value(m, When(c.p, c.c.c))
