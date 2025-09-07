#include "Expert.mqh"

string GetExpertData( const ulong Chart = 0 )
{
  string Str = NULL;

  MqlParam Parameters[];
  string Names[];

  if (EXPERT::Parameters(Chart, Parameters, Names))
  {
    Str += "\n" + ::ChartSymbol(Chart) + " " 
    + ::EnumToString(::ChartPeriod(Chart)) + " " 
    + Parameters[0].string_value 
    + "\n(Chart ID: " + (string)Chart + ")"
    + "\n\n";

    const int Amount = ::ArraySize(Names);

    for (int i = 0; i < Amount; i++)
    {
        Str += (string)i 
                + ": "+ Names[i] 
                + " = " 
                + Parameters[i + 1].string_value 
                + "\n";
    }
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
//function that loops through all charts and returns an array of type long containing the chart IDs of charts that have experts
bool GetExpertsChartIDs(long BOTCHARTID,long& C_IDS[] )
{
   
  long Chart = ::ChartFirst();

  while (Chart != -1)
  {
    if (EXPERT::Is(Chart)&& (Chart != BOTCHARTID)) // Check if the chart has an expert
    {
      ArrayResize(C_IDS, ArraySize(C_IDS) + 1); // Resize the array to add a new ID
      C_IDS[ArraySize(C_IDS) - 1] = Chart; // Add the chart ID to the array
    }
    Chart = ::ChartNext(Chart);
  }

  //return ChartIDs; // Return the array of chart IDs
  return true;
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