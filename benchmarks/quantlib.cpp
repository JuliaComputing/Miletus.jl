#include <ql/quantlib.hpp>
using namespace QuantLib;


extern "C" {


  double ql_am_put_crr(double S, double K, double r, double c, double sigma,
                       int y1, int m1, int d1, int y2, int m2, int d2, int n) {

    Calendar calendar = TARGET();
    Date todaysDate(d1, Month(m1), y1);
    Date settlementDate(d1, Month(m1), y1);
    Settings::instance().evaluationDate() = todaysDate;

    Option::Type type(Option::Put);
    Date maturity(d2, Month(m2), y2);
    DayCounter dayCounter = Actual365Fixed();

        Handle<Quote> underlyingH(
            boost::shared_ptr<Quote>(new SimpleQuote(S)));
        
        Handle<YieldTermStructure> flatTermStructure(
            boost::shared_ptr<YieldTermStructure>(
                new FlatForward(settlementDate, r, dayCounter)));
        Handle<YieldTermStructure> flatDividendTS(
            boost::shared_ptr<YieldTermStructure>(
                new FlatForward(settlementDate, c, dayCounter)));
        Handle<BlackVolTermStructure> flatVolTS(
            boost::shared_ptr<BlackVolTermStructure>(
                new BlackConstantVol(settlementDate, calendar, sigma, dayCounter)));
        boost::shared_ptr<StrikedTypePayoff> payoff(
                new PlainVanillaPayoff(type, K));
    

    boost::shared_ptr<Exercise> americanExercise(
        new AmericanExercise(settlementDate,
                             maturity));
    boost::shared_ptr<BlackScholesMertonProcess> bsmProcess(
        new BlackScholesMertonProcess(underlyingH, flatDividendTS,
                                      flatTermStructure, flatVolTS));

    VanillaOption americanOption(payoff, americanExercise);
    
    americanOption.setPricingEngine(boost::shared_ptr<PricingEngine>(
        new BinomialVanillaEngine<CoxRossRubinstein>(bsmProcess, n)));

    
    return americanOption.NPV();
  }

  
}
