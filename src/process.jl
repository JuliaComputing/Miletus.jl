abstract type Process{T} end

struct DateProcess <: Process{Date}
end

struct ConstProcess{T} <: Process{T}
    val::T
end


struct CondProcess{T} <: Process{T}
    cond::Process{Bool}
    a::Process{T}
    b::Process{T}
end

proctype(::Process{T}) where {T} = T
proctype(::Tuple{Process{T1}}) where {T1} = Tuple{T1}
proctype(::Tuple{Process{T1},Process{T2}}) where {T1,T2} = Tuple{T1,T2}

struct LiftProc{F,A,R} <: Process{R}
    f::F
    a::A
    function LiftProc{F,A,R}(f,a...) where {F,A,R}
        new{F,A,R}(f,a)
    end
end

function LiftProc(f::Function, a::Process...)
    RR = Base.return_types(f,proctype(a))
    R = length(RR) > 1 ? Any : RR[1]
    LiftProc{typeof(f),typeof(a),R}(f,a...)
end



struct DiscountProc{T,Pr<:Process{Float64},Pp<:Process{Bool},Pv<:Process} <: Process{T}
    r::Pr
    p::Pp
    v::Pv    
end
DiscountProc(r::Process{Float64},p::Process{Bool},v::Process{T}) where {T} =  DiscountProc{T,typeof(r),typeof(p),typeof(v)}(r,p,v)
