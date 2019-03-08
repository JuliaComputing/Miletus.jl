#!/usr/bin/env Rscript

# NOTE: fOptions uses non-standard definition of cost of carry: b = interestrate - carryrate, i.e. the adjusted drift κ in the geometric Brownian motion:
#   dS_t = (κ - σ^2/2) S_t dt + σ S_t dW_t

library(fOptions)

df = Reduce(function(x,y) merge(x,y,all=TRUE),
             list(data.frame(startprice=c(80,100,120)),
                  data.frame(strikeprice=c(80,100,120)),
                  data.frame(days=c(50,120)),
                  data.frame(interestrate=c(0.05,0.07)),
                  data.frame(carryrate=c(0.0,0.025)),
                  data.frame(sigma=c(0.05,0.1,0.5))
                  ))

bs = df

for (type in c("c","p")) {
    bs[type] = with(bs,
                    GBSOption(TypeFlag = type, S = startprice, X = strikeprice, Time = days/365,
                              r = interestrate, b = interestrate - carryrate, sigma = sigma)@price)
}

write.csv(bs,"bs.csv",row.names=FALSE)


crr = merge(df,data.frame(nsteps=c(20,100)),all=TRUE)
for (otype in c("ce","pe","ca","pa")) {
    crr[otype] = with(crr,
                     sapply(mapply(CRRBinomialTreeOption,TypeFlag = otype, S = startprice, X = strikeprice, Time = days/365,
                                   r = interestrate, b = interestrate - carryrate, sigma = sigma, n=nsteps),
                            function(x) x@price))
}

write.csv(crr,"crr.csv",row.names=FALSE)

tian = merge(df,data.frame(nsteps=c(20,100)),all=TRUE)
for (otype in c("ce","pe","ca","pa")) {
    tian[otype] = with(tian,
                     sapply(mapply(TIANBinomialTreeOption,TypeFlag = otype, S = startprice, X = strikeprice, Time = days/365,
                                   r = interestrate, b = interestrate - carryrate, sigma = sigma, n=nsteps),
                            function(x) x@price))
}
write.csv(tian,"tian.csv",row.names=FALSE)

jr = merge(df,data.frame(nsteps=c(20,100)),all=TRUE)
for (otype in c("ce","pe","ca","pa")) {
    tian[otype] = with(jr,
                     sapply(mapply(JRBinomialTreeOption,TypeFlag = otype, S = startprice, X = strikeprice, Time = days/365,
                                   r = interestrate, b = interestrate - carryrate, sigma = sigma, n=nsteps),
                            function(x) x@price))
}
write.csv(tian,"jr.csv",row.names=FALSE)
