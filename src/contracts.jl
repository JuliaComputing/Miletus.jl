export Give, Receive, Zero, Amount, Cond, When, Anytime, Until, Both, Either, Pay, Buy, Sell, ZCB, Forward, Option, EuropeanCall, EuropeanPut, AmericanCall, AmericanPut, Scale

abstract type Contract end

"""
    Zero() <: Contract

A "null" contract.
"""
struct Zero <: Contract
end


"""
    Amount(o::Observable) <: Contract

Receive amount of `o`.
"""
struct Amount{O} <: Contract
    o::O
end


"""
    Scale(s::Observable, c::Contract)

Scale the contract `c` by `s`.
"""
struct Scale{O<:Observable, C<:Contract} <: Contract
    s::O
    c::C
end
Scale(x::Number, c::Contract) = Scale(ConstObs(x),c)

"""
    Both(c1::Contract, c2::Contract)

Acquire both contracts `c1` and `c2` (`and` in PJE2000).
"""
struct Both{C1<:Contract,C2<:Contract} <: Contract
    c1::C1
    c2::C2
end

"""
    Either(c1::Contract, c2::Contract)

Acquire either contract `c1` or `c2` (`or` in PJE2000).
"""
struct Either{C1<:Contract,C2<:Contract} <: Contract
    c1::C1
    c2::C2
end

"""
    Give(c::Contract)

Take the opposite side of contract `c`.
"""
struct Give{C<:Contract} <: Contract
    c::C
end

"""
    Cond(p::Observable{Bool}, c1::Contract, c2::Contract)

If `p` is true at the point of aquisition, acquire `c1` else acquire `c2`.
"""
struct Cond{P<:Observable{Bool}, T1<:Contract, T2<:Contract} <: Contract
    p::P
    c1::T1
    c2::T2
end

"""
    When(p::Observable{Bool}, c::Contract)

Acquire the contract `c` at the point when `p` becomes `true`.
"""
struct When{P<:Observable{Bool},C<:Contract} <: Contract
    p::P
    c::C
end

"""
    Anytime(p::Observable{Bool}, c::Contract)

May acquire `c` at any point when `p` is `true`.
"""
struct Anytime{P<:Observable{Bool}, C<:Contract} <: Contract
    p::P
    c::C
end

"""
    Until(p::Observable{Bool}, c::Contract)

Acts like contract `c` until `p` is `true`, at which point it is abandoned (and hence worthless).
"""
struct Until{P<:Observable{Bool}, C<:Contract} <: Contract
    p::P
    c::C
end



## Derived Contracts

const Receive{T} = Amount{ConstObs{T}}
Receive(x::Union{Real,CurrencyQuantity}) = Amount(ConstObs(x))

const Pay{T} = Give{Receive{T}}
Pay(x::Union{Real,CurrencyQuantity}) = Give(Receive(x))

const Buy{C,T} = Both{C, Pay{T}}
Buy(c::Contract, x::Union{Real,CurrencyQuantity}) = Both(c, Pay(x))

const Sell{C,T} = Both{Give{C}, Receive{T}}
Sell(c::Contract, x::Union{Real,CurrencyQuantity}) = Both(Give(c), Receive(x))

const WhenAt{C} = When{At, C}
WhenAt(date::Date, c::Contract) = When(At(date), c)

const ZCB{T} = WhenAt{Receive{T}}
ZCB(date::Date, x::Union{Real,CurrencyQuantity}) = WhenAt(date, Receive(x))

const Forward{C,T} = WhenAt{Buy{C,T}}
Forward(date::Date, c::Contract, strike::Union{Real,CurrencyQuantity}) = WhenAt(date, Buy(c, strike))

const Option{C} = Either{C, Zero}
Option(c::Contract) = Either(c, Zero())

const European{C} = WhenAt{Option{C}}
European(date::Date, c::Contract) = WhenAt(date, Option(c))

"""
    EuropeanCall(date, c, strike)

A European call contract, with maturity `date`, on underlying contract `c` at price `strike`.
"""
const EuropeanCall{C,T} = European{Buy{C,T}}
EuropeanCall(date::Date, c::Contract, strike::Union{Real,CurrencyQuantity}) = European(date, Buy(c, strike))

"""
    EuropeanPut(date, c, strike)

A European put contract, with maturity `date`, on underlying contract `c` at price `strike`.
"""
const EuropeanPut{C,T} = European{Sell{C,T}}
EuropeanPut(date::Date, c::Contract, strike::Union{Real,CurrencyQuantity}) = European(date, Sell(c, strike))


const AnytimeBefore{C} = Anytime{Before, C}
AnytimeBefore(date::Date, c::Contract) = Anytime(Before(date), c)

const American{C} = AnytimeBefore{Option{C}}
American(date::Date, c::Contract) = AnytimeBefore(date, Option(c))

"""
    AmericanCall(date, c, strike)

An American call contract, with maturity `date`, on underlying contract `c` at price `strike`.
"""
const AmericanCall{C,T} = American{Buy{C,T}}
AmericanCall(date::Date, c::Contract, strike::Union{Real,CurrencyQuantity}) = American(date, Buy(c, strike))

"""
    AmericanPut(date, c, strike)

An American put contract, with maturity `date`, on underlying contract `c` at price `strike`.
"""
const AmericanPut{C,T} = American{Sell{C,T}}
AmericanPut(date::Date, c::Contract, strike::Union{Real,CurrencyQuantity}) = American(date, Sell(c, strike))




## helper functions

"""
    maturitydate(c::Contract)

The maturity date of a contract `c` is the date at which contract is completed or expires.
"""
maturitydate(c::WhenAt{C}) where {C} = c.p.a[2].val
maturitydate(c::AnytimeBefore{C}) where {C} = c.p.a[2].val
maturitydate(c::Anytime{LiftObs{F,Tuple{ValueObs{S, A},ConstObs{A}},Bool},C}) where {S,F,A,C} = maturitydate(c.c)
maturitydate(c::Anytime{LiftObs{F,Tuple{ConstObs{A}, ValueObs{S, A}},Bool},C}) where {S,F,A,C} = maturitydate(c.c)
maturitydate(c::Give{C}) where {C} = maturitydate(c.c) 

"""
    strikeprice(c::Contract)

The price at which an option or forward can be exercised.
"""
strikeprice(c::Option{C}) where {C} = price(c.c1)
strikeprice(c::American{C}) where {C} = strikeprice(c.c)
strikeprice(c::European{C}) where {C} = strikeprice(c.c)
strikeprice(c::WhenAt{C}) where {C} = price(c.c)

"""
    price(c::Contract)

The price of a `Buy` or `Sell` contract.
"""
price(c::Buy{C,T}) where {C,T} = c.c2.c.o.val
price(c::Sell{C,T}) where {C,T} = c.c2.o.val

