module TermStructure

using Miletus.DayCounts
using Dates

export YieldTermStructure, VolatilityTermStructure, ConstantYieldCurve,
		compound_factor, discount_factor, implied_rate, discount, forward_rate,
		reference_date, zero_rate, par_rate

#General Interest Rate functionality

compound_factor(r::Real, compounding::Symbol, freq::Symbol,  t::Real) = compound_factor(r, compounding, eval(freq), t)
compound_factor(r::Real, compounding::Symbol,  t::Real) = compound_factor(r, compounding, NoFrequency, t)
compound_factor(r::Real, compounding::Symbol, dc::DayCount, dates::Date...) = compound_factor(r, compounding, NoFrequency, dates...)
compound_factor(r::Real, compounding::Symbol, freq::Symbol, dc::DayCount, dates::Date...) = compound_factor(r, compounding, eval(freq), dates...)
compound_factor(r::Real, compounding::Symbol, freq::Integer, dc::DayCount, dates::Date...) = compound_factor(r,  compounding, freq, yearfraction(dc, dates...))

function compound_factor(r::Real, compounding::Symbol, freq::Integer, t::Real )
	if compounding == :Simple
		return 1 + r * t
	elseif compounding == :Compounded
		@assert(freq != NoFrequency)
		return (1 + r / freq) ^ (freq * t)
	elseif compounding == :Continuous
		return exp(r * t)
	elseif compounding == :SimpleThenCompounded
		@assert(freq != NoFrequency)
		if t < (1 / freq)
            return 1 + r * t
        else
            return (1 + r / freq) ^ (freq * t)
        end
	else
		error("Unknown compounding")
	end
end

discount_factor(x...) = 1/compound_factor(x...)

implied_rate(c::Real, compounding::Symbol, freq::Symbol,  t::Real) = implied_rate(c,compounding, eval(freq), t)
implied_rate(c::Real, compounding::Symbol, freq::Symbol, dc::DayCount, dates::Date...) = implied_rate(c,compounding, eval(freq), dates...)
implied_rate(c::Real, compounding::Symbol, freq::Integer, dc::DayCount, dates::Date...) = implied_rate(c, compounding, freq, yearfraction(dc, dates...))

function implied_rate(c::Real, compounding::Symbol, freq::Integer, t::Real)
	@assert c>0 && t>0
	if compounding == :Simple
		return (c-1) / t
	elseif compounding == :Compounded
		return (c ^ (1/(f*t)) - 1) *f
	elseif compounding == :Continuous
		return log(c)/t
	elseif compounding == :SimpleThenCompounded
		if t < (1 / freq)
            return (c-1) / t
        else
            return (c ^ (1/(f*t)) - 1) *f
        end
	else
		error("Unknown compounding")
	end
end



abstract type TermStuct end

abstract type VolatilityTermStructure <: TermStuct end
abstract type YieldTermStructure <: TermStuct end

#Default values
daycount(::YieldTermStructure) = Actual365()
startdate(::YieldTermStructure) = Dates.today()
compounding(::YieldTermStructure) = :Continuous
frequency(::YieldTermStructure) = NoFrequency

discount(ts::YieldTermStructure, d::Date) = discount(ts, yearfraction(daycount(ts), startdate(ts), d))
Base.getindex(ts::YieldTermStructure, d::Date) = discount(ts, d)
implied_rate(ts::YieldTermStructure, d::Date) = implied_rate(1/ts[d], compounding(ts), frequency(ts), yearfraction(daycount(ts),  startdate(ts), d) )


#Overload this method for each concrete YieldTermStructure
discount(ts::YieldTermStructure, t::Real) = error("Must be implemented by concrete Term Structure")


function forward_rate(ts::YieldTermStructure, d1::Date, d2::Date )
	if d1==d2
		t1 = yearfraction(daycount(ts), startdate(ts), d1)
		t2 = t1+.0001
		c=discount(ts, t1) / discount(ts, t2)
		return implied_rate(c, compounding(ts), frequency(ts), t2-t1)
	elseif d1<d2
		return implied_rate(discount(ts, d1)/discount(ts, d2), compounding(ts), frequency(ts), daycount(ts), d1, d2)
	else
		error("Forward start date must be before forward end dates")
	end
end

function forward_rate(ts::YieldTermStructure, t1::Real, t2::Real )
	if (t2==t1)
		t2=t1+.0001
	end

	compound = discount(ts, t1) / discount(ts, t2)
	return implied_rate(discount(ts, t1) / discount(ts, t2), daycount(ts), t2-t1)
end

zero_rate(ts::YieldTermStructure,  d1::Date) = zero_rate(ts, yearfraction(ts.dc, reference_date(ts), d1))
function zero_rate(ts::YieldTermStructure, t::Real)
	if (t == 0)
		c = 1/discount(ts, .0001)
		return implied_rate(c, ts.compounding, ts.freq, .0001)
	else
		c = 1/discount(ts, t)
		return implied_rate(c, ts.compounding, ts.freq, t)
	end
end

par_rate(ts::YieldTermStructure, dates::AbstractVector{Date}) =
	par_rate(ts, [yearfraction(ts.dc, reference_date(ts), dt) for dt in dates])
function par_rate(ts::YieldTermStructure, tm::AbstractVector)
	s = sum([discount(ts, t) for t in tm])
	r=discount(ts, tm[1])
end

mutable struct ConstantVolatilityCurve <: VolatilityTermStructure

end

struct ConstantContinuousYieldCurve{DC,T} <: YieldTermStructure
    dc::DC
    rate::T
    reference_date::Date
end

daycount(y::ConstantContinuousYieldCurve) = y.dc
startdate(y::ConstantContinuousYieldCurve) = y.reference_date
discount(y::ConstantContinuousYieldCurve, yf::Float64) = exp(-y.rate * yf)

discount(y::ConstantContinuousYieldCurve, d::Date) = discount(y, yearfraction(daycount(y), startdate(y), d))

mutable struct ConstantYieldCurve{T} <: YieldTermStructure
	dc::DayCount
	rate::T
	compounding::Symbol
	freq::Integer
	reference_date::Date
end

ConstantYieldCurve(dc::DayCount, rate::Real, compounding::Symbol, freq::Symbol, reference_date::Date) =
		ConstantYieldCurve(dc, rate, compounding, eval(freq), reference_date)

daycount(y::ConstantYieldCurve) = y.dc
startdate(y::ConstantYieldCurve) = y.reference_date


ConstantYieldCurve(dc::DayCount, rate::Real) = ConstantYieldCurve(dc, rate, :Continuous, :NoFrequency, today())
discount(ts::ConstantYieldCurve, t::Real) = discount_factor(ts.rate, ts.compounding, ts.freq, t)

const NoFrequency       = -1
const Once			 	= 0
const Annual			= 1
const Semiannual		= 2
const EveryFourthMonth  = 3
const Quarterly		 	= 4
const Bimonthly		 	= 6
const Monthly			= 12
const EveryFourthWeek  	= 13
const Biweekly		 	= 26
const Weekly			= 52
const Daily			 	= 365
const OtherFrequency   	= 999


end #Module
