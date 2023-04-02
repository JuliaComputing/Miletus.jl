abstract type Observable{T} end

"""
    DateObs() <: Observable{Date}

A singleton type representing the "free" date observable.
"""
struct DateObs <: Observable{Date}
end

"""
    TimeObs{T<:Real}() <: Observable{T}

A singleton type representing the "free" time observable.
"""
struct TimeObs{T<:Real} <: Observable{T}
end


"""
    AcquisitionDateObs() <: Observable{Date}

The acquisition date of the contract.
"""
struct AcquisitionDateObs <: Observable{Date}
end

"""
    AcquisitionTimeObs() <: Observable{T}

The acquisition time of the contract.
"""
struct AcquisitionTimeObs{T<:Real} <: Observable{T}
end

"""
    ConstObs(x)

A constant observable
"""
struct ConstObs{T} <: Observable{T}
    val::T
end

obstype(::Observable{T}) where {T} = T
obstype(::Tuple{Observable{T1}}) where {T1} = Tuple{T1}
obstype(::Tuple{Observable{T1},Observable{T2}}) where {T1,T2} = Tuple{T1,T2}


struct LiftObs{F,A,R} <: Observable{R}
    f::F
    a::A
    function LiftObs{F,A,R}(f,a...) where {F,A,R}
        new{F,A,R}(f,a)
    end
end

function LiftObs(f::Function, a::Observable...)
    RR = Base.return_types(f,obstype(a))
    R = length(RR) > 1 ? Any : RR[1]
    LiftObs{typeof(f),typeof(a),R}(f,a...)
end

### Derived observables

# This is a bit of a hack
#  - we could make `at` a function
#  - we could create a separate type which is equivalent, e.g
#
#     immutable AtObs <: Observable{Bool}
#         d::Date
#     end
#

"""
    At(t::Date) <: Observable{Bool}

An observable that is `true` when the date is `t`.
"""
const At = LiftObs{typeof(==),Tuple{U,ConstObs{T}},Bool} where {T <: Union{Date,Real},U<:Union{DateObs,TimeObs}}
At(t::Date) = LiftObs(==,DateObs(),ConstObs(t))
At(t::R) where {R<:Real} = LiftObs(==,TimeObs{R}(),ConstObs(t))

"""
    Before(t::Date) <: Observable{Bool}

An observable that is `true` when the date is before or equal to `t`.
"""
const Before = LiftObs{typeof(<=),Tuple{U,ConstObs{T}},Bool} where {T <: Union{Date,Real},U<:Union{DateObs,TimeObs}}
Before(t::Date) = LiftObs(<=,DateObs(),ConstObs(t))
Before(t::R) where {R<:Real} = LiftObs(<=,TimeObs{R}(),ConstObs(t))

@deprecate AtObs At
@deprecate BeforeObs Before
