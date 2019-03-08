# Extended Examples

## Spread Options

Below we define a set of various spread options that show how one can combine vanilla options into more complex payoffs.

```@example spreads
using Miletus, Gadfly, Colors

import Miletus: Both, Give, Contract, WhenAt, value
import Base.strip
```

First define parameters for use in various contract and model definitions.

```@example spreads
expirydate = Date("2016-12-25")
startdate  = Date("2016-12-1")
interestrate = 0.05
carryrate    = 0.1
volatility   = 0.15
K₁ = 98.0USD  
K₂ = 100.0USD
K₃ = 102.0USD
L  = 11 # Layers in the binomial lattice / Number of time steps
nothing # hide
```

Next we define a range of prices to use for plotting payoff curves.
```@example spreads
price = K₁-1USD:0.1USD:K₃+1USD
nothing # hide
```

Then we construct example analytical, binomial, and Monte Carlo test models that will be used when valuing the various vanilla and spread options at the defined start date.

```@example spreads
gbmm = GeomBMModel(startdate, K₂, interestrate, carryrate, volatility)
crr  = CRRModel(startdate, expirydate, L, K₂, interestrate, carryrate, volatility)
mcm  = Miletus.montecarlo(gbmm, startdate:expirydate, 10_000)
nothing # hide
```

Next let's define a function for calculating the payoff curve of each spread at expiry over a range of asset prices. This function assumes that the provided date is the expiry date of all components within the contract `c`.

```@example spreads
function payoff_curve(c, d::Date, prices)
    payoff = [value(GeomBMModel(d, x, 0.0, 0.0, 0.0), c) for x in prices]
    p = [x.val for x in payoff]
    r = [x.val for x in prices]
    return r, p
end
nothing # hide
```

 Next we will create a set of vanilla call and put options at separate strikes that will be used for construction of the different spread options. The included plots show the payoff of the option at the middle strike, K₂.

#### Vanilla Call Option
```@example spreads
call₁ = EuropeanCall(expirydate, SingleStock(), K₁)
call₂ = EuropeanCall(expirydate, SingleStock(), K₂)
call₃ = EuropeanCall(expirydate, SingleStock(), K₃)
s₁,cp₁ = payoff_curve(call₁, expirydate, price)
s₂,cp₂ = payoff_curve(call₂, expirydate, price)
s₃,cp₃ = payoff_curve(call₃, expirydate, price)
plot(x = s₂, y = cp₂, Geom.line,
     Theme(default_color=colorant"blue", line_width = 1.0mm, panel_fill=nothing),
     Guide.title("Vanilla Call Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("vanilla_call.png", 4inch, 3inch), ans); nothing # hide
```

![](vanilla_call.png)

```@example spreads
value(gbmm, call₂)
```
```@example spreads
value(crr, call₂)
```
```@example spreads
value(mcm, call₂)
```

#### Vanilla Put Option
```@example spreads
put₁ = EuropeanPut(expirydate, SingleStock(), K₁)
put₂ = EuropeanPut(expirydate, SingleStock(), K₂)
put₃ = EuropeanPut(expirydate, SingleStock(), K₃)
s₁,pp₁ = payoff_curve(put₁, expirydate, price)
s₂,pp₂ = payoff_curve(put₂, expirydate, price)
s₃,pp₃ = payoff_curve(put₃, expirydate, price)
plot(x = s₂, y = pp₂, Geom.line,
     Theme(default_color=colorant"blue", line_width = 1.0mm, panel_fill=nothing),
     Guide.title("Vanilla Put Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("vanilla_put.png", 4inch, 3inch), ans); nothing # hide
```

![](vanilla_put.png)

```@example spreads
value(gbmm, put₂)
```
```@example spreads
value(crr, put₂)
```
```@example spreads
value(mcm, put₂)
```

Now we will start to combine these vanilla calls and puts into various spread options.

#### Butterfly Call Spread
```@example spreads
# Buy two calls at the high and low strikes
# Sell two calls at the middle strike
function butterfly_call(expiry::Date, K₁, K₂, K₃)
    @assert K₁ < K₂ < K₃
    c₁ = EuropeanCall(expiry, SingleStock(), K₁)
    c₂ = EuropeanCall(expiry, SingleStock(), K₂)
    c₃ = EuropeanCall(expiry, SingleStock(), K₃)
    Both(Both(c₁,c₃), Give(Both(c₂,c₂)))
end

bfly₁ = butterfly_call(expirydate, K₁, K₂, K₃)

s,p_bfly₁ = payoff_curve(bfly₁, expirydate, price)
blk = colorant"black"
red = colorant"red"
grn = colorant"green"
blu = colorant"blue"
plot(layer( x=s ,y=p_bfly₁,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁,y=  cp₁  ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₃,y=  cp₃  ,Geom.line,Theme(default_color=grn,line_width=1.0mm)),
     layer( x=s₂,y=-2cp₂  ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Butterfly Call", "call₁", "call₃", "-2call₂"],
     ["black", "red", "green", "blue"]),
     Guide.title("Butterfly Call Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("butterfly_call.png", 4inch, 3inch), ans); nothing # hide
```

![](butterfly_call.png)

```@example spreads
value(gbmm, bfly₁)
```
```@example spreads
value(crr, bfly₁)
```
```@example spreads
value(mcm, bfly₁)
```

#### Butterfly Put Spread
```@example spreads
# Buy two puts at the high and low strikes
# Sell two puts at the middle strike
function butterfly_put(expiry::Date, K₁, K₂, K₃)
    @assert K₁ < K₂ < K₃
    p₁ = EuropeanPut(expiry, SingleStock(), K₁)
    p₂ = EuropeanPut(expiry, SingleStock(), K₂)
    p₃ = EuropeanPut(expiry, SingleStock(), K₃)
    Both(Both(p₁,p₃), Give(Both(p₂,p₂)))
end

bfly₂ = butterfly_put(expirydate, K₁, K₂, K₃)
s,p_bfly₂ = payoff_curve(bfly₂, expirydate, price)
blk = colorant"black"
red = colorant"red"
grn = colorant"green"
blu = colorant"blue"
plot(layer( x=s ,y=p_bfly₂,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁,y=  pp₁  ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₃,y=  pp₃  ,Geom.line,Theme(default_color=grn,line_width=1.0mm)),
     layer( x=s₂,y=-2pp₂  ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Butterfly Put", "put₁", "put₃", "-2put₂"],
     ["black", "red", "green", "blue"]),
     Guide.title("Butterfly Put Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("butterfly_put.png", 4inch, 3inch), ans); nothing # hide
```

![](butterfly_put.png)


```@example spreads
value(gbmm, bfly₂)
```
```@example spreads
value(crr, bfly₂)
```
```@example spreads
value(mcm, bfly₂)
```

#### Bear Call Spread
```@example spreads
# Buy a call at the high strike
# Sell a call at the low strike
function bear_call(expiry::Date, K₁, K₂)
    @assert K₁ != K₂
    c₁ = EuropeanCall(expiry, SingleStock(), K₁)
    c₂ = EuropeanCall(expiry, SingleStock(), K₂)
    Both(Give(c₁), c₂)
end

bear₁ = bear_call(expirydate, K₁, K₂)
s,p_bear₁ = payoff_curve(bear₁, expirydate, price)
blk = colorant"black"
red = colorant"red"
blu = colorant"blue"
plot(layer( x=s, y=p_bear₁,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁,y=-cp₁   ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₂,y= cp₂   ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Bear Call", "-call₁", "call₂"],
     ["black", "red", "blue"]),
     Guide.title("Bear Call Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("bear_call.png", 4inch, 3inch), ans); nothing # hide
```

![](bear_call.png)

```@example spreads
value(gbmm, bear₁)
```
```@example spreads
value(crr, bear₁)
```
```@example spreads
value(mcm, bear₁)
```

#### Bear Put Spread
```@example spreads
# Buy a put at the low strike
# Sell a put at the high strike
function bear_put(expiry::Date, K₁, K₂)
    @assert K₁ != K₂
    p₁ = EuropeanPut(expiry, SingleStock(), K₁)
    p₂ = EuropeanPut(expiry, SingleStock(), K₂)
    Both(p₁, Give(p₂))
end

bear₂ = bear_put(expirydate, K₁, K₂)
r,p_bear₂ = payoff_curve(bear₂, expirydate, price)
blk = colorant"black"
red = colorant"red"
blu = colorant"blue"
plot(layer( x=s,  y=p_bear₂,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁, y= pp₁   ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₂, y=-pp₂   ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Bear Put", "call₁", "-call₂"],
     ["black", "red", "blue"]),
     Guide.title("Bear Put Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("bear_put.png", 4inch, 3inch), ans); nothing # hide
```

![](bear_put.png)

```@example spreads
value(gbmm, bear₂)
```
```@example spreads
value(crr, bear₂)
```
```@example spreads
value(mcm, bear₂)
```

#### Bull Call Spread
```@example spreads
# Buy a call at the low strike
# Sell a call at the high strike
function bull_call(expiry::Date, K₁, K₂)
    @assert K₁ != K₂
    c₁ = EuropeanCall(expiry, SingleStock(), K₁)
    c₂ = EuropeanCall(expiry, SingleStock(), K₂)
    Both(c₁, Give(c₂))
end

bull₁ = bull_call(expirydate, K₁, K₂)
r,p_bull₁ = payoff_curve(bull₁, expirydate, price)
blk = colorant"black"
red = colorant"red"
blu = colorant"blue"
plot(layer( x=s ,y=p_bull₁,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁,y= cp₁   ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₂,y=-cp₂   ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Bull Call", "call₁", "-call₂"],
     ["black", "red", "blue"]),
     Guide.title("Bull Call Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("bull_call.png", 4inch, 3inch), ans); nothing # hide
```

![](bull_call.png)

```@example spreads
value(gbmm, bull₁)
```
```@example spreads
value(crr, bull₁)
```
```@example spreads
value(mcm, bull₁)
```

#### Bull Put Spread
```@example spreads
# Buy a put at the high strike
# Sell a put at the low strike
function bull_put(expiry::Date, K₁, K₂)
    @assert K₁ != K₂
    p₁ = EuropeanPut(expiry, SingleStock(), K₁)
    p₂ = EuropeanPut(expiry, SingleStock(), K₂)
    Both(Give(p₁), p₂)
end

bull₂ = bull_put(expirydate, K₁, K₂)
r,p_bull₂ = payoff_curve(bull₂, expirydate, price)
blk = colorant"black"
red = colorant"red"
blu = colorant"blue"
plot(layer( x=s ,y=p_bull₂,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁,y=-pp₁   ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₂,y= pp₂   ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Bear Put", "-put₁", "put₂"],
     ["black", "red", "blue"]),
     Guide.title("Bear Put Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("bull_put.png", 4inch, 3inch), ans); nothing # hide
```

![](bull_put.png)

```@example spreads
value(gbmm, bull₂)
```
```@example spreads
value(crr, bull₂)
```
```@example spreads
value(mcm, bull₂)
```

#### Straddle Spread
```@example spreads
# Buy a put and a call at the same strike
function straddle(expiry::Date, K)
    p = EuropeanPut(expiry, SingleStock(), K)
    c = EuropeanCall(expiry, SingleStock(), K)
    Both(p, c)
end

strd₁ = straddle(expirydate, K₂)
r,p_strd₁ = payoff_curve(strd₁, expirydate, price)
blk = colorant"black"
red = colorant"red"
blu = colorant"blue"
plot(layer( x=s ,y=p_strd₁,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁,y=cp₂    ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₂,y=pp₂    ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Straddle", "call₂", "put₂"],
     ["black", "red", "blue"]),
     Guide.title("Straddle Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("straddle.png", 4inch, 3inch), ans); nothing # hide
```

![](straddle.png)

```@example spreads
value(gbmm, strd₁)
```
```@example spreads
value(crr, strd₁)
```
```@example spreads
value(mcm, strd₁)
```

#### Strip Spread
```@example spreads
# Buy one call and two puts at the same strike
function strip(expiry::Date, K)
    p = EuropeanPut(expiry, SingleStock(), K)
    c = EuropeanCall(expiry, SingleStock(), K)
    Both(c, Both(p, p))
end

strip₁ = strip(expirydate, K₂)
r,p_strip = payoff_curve(strip₁, expirydate, price)
blk = colorant"black"
red = colorant"red"
blu = colorant"blue"
plot(layer( x=s ,y=p_strip,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁,y=cp₂    ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₂,y=2pp₂   ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Strip", "call₂", "2put₂"],
     ["black", "red", "blue"]),
     Guide.title("Strip Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("strip.png", 4inch, 3inch), ans); nothing # hide
```

![](strip.png)

```@example spreads
value(gbmm, strip₁)
```
```@example spreads
value(crr, strip₁)
```
```@example spreads
value(mcm, strip₁)
```

#### Strap Spread
```@example spreads
# Buy one put and two calls at the same strike
function strap(expiry::Date, K)
    p = EuropeanPut(expiry, SingleStock(), K)
    c = EuropeanCall(expiry, SingleStock(), K)
    Both(p, Both(c, c))
end

strap₁ = strap(expirydate, K₂)
r,p_strap = payoff_curve(strap₁, expirydate, price)
blk = colorant"black"
red = colorant"red"
blu = colorant"blue"
plot(layer( x=s ,y=p_strap,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁,y=2cp₂   ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₂,y=pp₂    ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Strap", "2call₂", "put₂"],
     ["black", "red", "blue"]),
     Guide.title("Strap Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("strap.png", 4inch, 3inch), ans); nothing # hide
```

![](strap.png)

```@example spreads
value(gbmm, strap₁)
```
```@example spreads
value(crr, strap₁)
```
```@example spreads
value(mcm, strap₁)
```

#### Strangle Spread
```@example spreads
# Buy a put at the low strike and a call at the high strike
function strangle(expiry::Date, K₁, K₂)
    p = EuropeanPut(expiry, SingleStock(), K₁)
    c = EuropeanCall(expiry, SingleStock(), K₂)
    Both(p, c)
end

strangle₁ = strangle(expirydate, K₁, K₃)
r,p_strangle = payoff_curve(strangle₁, expirydate, price)
blk = colorant"black"
red = colorant"red"
blu = colorant"blue"
plot(layer( x=s ,y=p_strangle,Geom.line,Theme(default_color=blk,line_width=1.5mm)),
     layer( x=s₁,y=cp₃       ,Geom.line,Theme(default_color=red,line_width=1.0mm)),
     layer( x=s₂,y=pp₁       ,Geom.line,Theme(default_color=blu,line_width=1.0mm)),
     Theme(panel_fill=nothing),
     Guide.manual_color_key("",["Strangle", "call₃", "put₁"],
     ["black", "red", "blue"]),
     Guide.title("Strangle Payoff Curve at Expiry"),
     Guide.xlabel("Stock Price"), Guide.ylabel("Payoff"))
draw(PNG("strangle.png", 4inch, 3inch), ans); nothing # hide
```

![](strangle.png)

```@example spreads
value(gbmm, strangle₁)
```
```@example spreads
value(crr, strangle₁)
```
```@example spreads
value(mcm, strangle₁)
```

## Coupon Bearing Bonds

Unlike a zero coupon bond, a coupon bearing bond pays the holder a specified amount at regular intervals up to the maturity date of the bond.  These coupon payments, and the interest that can accumulate on those payments must be taken into account when pricing the coupon bond.  The structuring of a coupon bond with Miletus provides an example of how to construct a product with multiple observation dates.

```@example couponbond
using Miletus, BusinessDays
using Miletus.TermStructure
using Miletus.DayCounts

import Miletus: Both, Receive, Contract, When, AtObs, value
import Miletus: YieldModel
import BusinessDays: USGovernmentBond
import Base.Dates: today, days, Day, Year
```

First let's show an example of the creation of a zero coupon bond.  For this type of bond a payment of the par amount occurs only on the maturity date.

```@example couponbond
zcb = When(AtObs(today()+Day(360)), Receive(100USD))
```

Next let's define a function for our coupon bearing bond.  The definition of multiple coupon payments and the final par payment involves a nested set of `Both` types, with each individual payment constructed from a `When` of an date observation and a payment contract.

```@example couponbond
function couponbond(par,coupon,periods::Int,start::Date,expiry::Date)
    duration = expiry - start
    bond = When(AtObs(expiry), Receive(par))
    for p = periods-1:-1:1
        coupondate = start + duration*p/periods
        bond = Both(bond,When(AtObs(coupondate), Receive(coupon)))
    end
    return bond
end
```

To construct an individual coupon bond, we first define necessary parameters for the par, coupon, number of periods, start date and expiry date.

```@example couponbond
par = 100USD
coupon = 1USD
periods = 12
startdate = today()
expirydate = today() + Day(360)
```

Now we can construct an instance of a coupon bearing bond.

```@example couponbond
cpb = couponbond(par,coupon,periods,startdate,expirydate)
```
Finally we can value this bond by constructing a yield curve and associated yield model and operating on the coupon bond contract with the defined yield model.

```@example couponbond
yc = ConstantYieldCurve(Actual360(), .1, :Continuous, :NoFrequency, Dates.today())
```

```@example couponbond
ym = YieldModel(yc, ModFollowing(), USGovernmentBond())
```

```@example couponbond
value(ym,cpb)
```

## Asian Option pricing
Asian options are structures whose payoff depends on the average price of an underlying security over a specific period of time, not just the price of the underlying at maturity.  To price an Asian option, we will make use of a Monte Carlo pricing model, as well as a contract that considers a `MovingAveragePrice`

```@example asianoption
using Miletus
using Gadfly
using Colors

d1 = Dates.today()
d2 = d1 + Dates.Day(120)
```

Structing the model without currency units
```@example asianoption
m = GeomBMModel(d1, 100.00, 0.05, 0.0, 0.3)
mcm = montecarlo(m, d1:d2, 100_000)
```

We can view the underlying simulation paths used for our Geometric Brownian Motion Model using Gadfly as follows:

```@example asianoption
theme=Theme(default_color=Colors.RGBA{Float32}(0.1, 0.1, 0.7, 0.1))
p = plot([layer(x=mcm.dates,y=mcm.paths[i,:],Geom.line,theme) for i = 1:200]...,Theme(panel_fill=nothing))
draw(PNG("asian_simulation_paths.png", 4inch, 3inch), ans); nothing # hide
```

![](asian_simulation_paths.png)

Now let's value a vanilla European call option using a Geometric Brownian Motion Model.

```@example asianoption
o = EuropeanCall(d2, SingleStock(), 100.00)
value(m, o)
```

And value that same vanilla European call using a Monte Carlo Model

```@example asianoption
value(mcm, o)
```

Next we construct a fixed strike Asian Call option. Note the `MovingAveragePrice` embedded in the definition.
```@example asianoption
oa1 = AsianFixedStrikeCall(d2, SingleStock(), Dates.Month(1), 100.00)
```

```@example asianoption
value(mcm, oa1)
```

Similarly, we can construct a floating strike Asian Call option.

```@example asianoption
oa2 = AsianFloatingStrikeCall(d2, SingleStock(), Dates.Month(1), 100.00)
```

```@example asianoption
value(mcm, oa2)
```
