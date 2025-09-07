#include "Expert.mqh"

string GetExpertData( const ulong Chart = 0 )
{
  string Str = NULL;

  MqlParam Parameters[];
  string Names[];

  if (EXPERT::Parameters(Chart, Parameters, Names))
  {
    Str += "\n" + ::ChartSymbol(Chart) + " " + ::EnumToString(::ChartPeriod(Chart)) + " " + Parameters[0].string_value + "\n";

    const int Amount = ::ArraySize(Names);

    for (int i = 0; i < Amount; i++)
      Str += (string)i + ": "+ Names[i] 
      + " = " + Parameters[i + 1].string_value 
      + "\n";
  }

  return(Str);
}

string GetExpertsData( const bool AllExperts = true )
{
  string Str = AllExperts ? NULL : GetExpertData();

  if (AllExperts)
  {
    long Chart = ::ChartFirst();

    while (Chart != -1)
    {
      Str += GetExpertData(Chart);

      Chart = ::ChartNext(Chart);
    }
  }

  return(Str);
}

typedef bool (*ACTION)( const long Chart = 0 );

bool ExpertsAction( ACTION Action, const bool AllExperts = true, const bool Condition = true )
{
  bool Res = AllExperts ? true : Action();

  if (AllExperts)
  {
    long Chart = ::ChartFirst();

    while (Chart != -1)
    {
      if ((Chart != ::ChartID()) && (EXPERT::Is(Chart) == Condition))
        Res &= Action(Chart);

      Chart = ::ChartNext(Chart);
    }

    if (EXPERT::Is() == Condition)
      Res &= Action();
  }

  return(Res);
}