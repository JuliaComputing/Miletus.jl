using Miletus.DayCounts
using Dates

@test 0.497724380567 ≈ yearfraction(ISDAActualActual(), Date(2003,November,1), Date(2004, May, 1))
@test 0.50           ≈ yearfraction(ISMAActualActual(), Date(2003,November,1), Date(2004, May, 1))
@test 0.497267759563 ≈ yearfraction(AFBActualActual(), Date(2003,November,1), Date(2004, May, 1))

@test 0.410958904110 ≈ yearfraction(ISDAActualActual(), Date(1999,February,1), Date(1999, July, 1))
@test 0.410958904110 ≈ yearfraction(ISMAActualActual(), Date(1999,February,1), Date(1999, July, 1), Date(1998, July, 1), Date(1999, July, 1))
@test 0.410958904110 ≈ yearfraction(AFBActualActual(), Date(1999,February,1), Date(1999, July, 1))

@test 1.001377348600 ≈ yearfraction(ISDAActualActual(), Date(1999,July,1), Date(2000, July, 1))
@test 1.0            ≈ yearfraction(ISMAActualActual(), Date(1999,July,1), Date(2000, July, 1), Date(1999, July, 1), Date(2000, July, 1))
@test 1.0            ≈ yearfraction(AFBActualActual(), Date(1999,July,1), Date(2000, July, 1))

@test 0.915068493151 ≈ yearfraction(ISDAActualActual(), Date(2002,August,15), Date(2003, July, 15))
@test 0.915760869565 ≈ yearfraction(ISMAActualActual(), Date(2002,August,15), Date(2003, July, 15), Date(2003, January, 15), Date(2003, July, 15))
@test 0.915068493151 ≈ yearfraction(AFBActualActual(), Date(2002,August,15), Date(2003, July, 15))

@test 0.504004790778 ≈ yearfraction(ISDAActualActual(), Date(2003,July,15), Date(2004, January, 15))
@test 0.5            ≈ yearfraction(ISMAActualActual(), Date(2003,July,15), Date(2004, January, 15), Date(2003, July, 15), Date(2004, January, 15))
@test 0.504109589041 ≈ yearfraction(AFBActualActual(), Date(2003,July,15), Date(2004, January, 15))

@test 0.503892506924 ≈ yearfraction(ISDAActualActual(), Date(1999,July,30), Date(2000, January, 30))
@test 0.5            ≈ yearfraction(ISMAActualActual(), Date(1999,July,30), Date(2000, January, 30), Date(1999,July,30), Date(2000, January, 30))
@test 0.504109589041 ≈ yearfraction(AFBActualActual(), Date(1999,July,30), Date(2000, January, 30))

@test 0.415300546448 ≈ yearfraction(ISDAActualActual(), Date(2000,January,30), Date(2000, June, 30))
@test 0.417582417582 ≈ yearfraction(ISMAActualActual(), Date(2000,January,30), Date(2000, June, 30), Date(2000,January,30), Date(2000, July, 30))
@test 0.415300546448 ≈ yearfraction(AFBActualActual(), Date(2000,January,30), Date(2000, June, 30))

using BusinessDays
c=BusinessDays.UnitedKingdom()
adjust(ModPreceding(), c, Date(2016,5,2)) == Date(2016, 5, 3)
