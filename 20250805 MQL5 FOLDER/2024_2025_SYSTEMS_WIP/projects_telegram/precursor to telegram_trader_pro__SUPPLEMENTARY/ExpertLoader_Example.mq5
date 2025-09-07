// Launching an advisor with specified input parameters
#property script_show_inputs

#include "include\Expert.mqh"

input bool CurrentChart = false; // Run the advisor on the current(true)/new(false) chart

string GetMyName( void )
{
  return(StringSubstr(MQLInfoString(MQL_PROGRAM_PATH), StringLen(TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\")));
}

bool RunExpert( const long Chart )
{
  MqlParam Params[2];

  // Path to the Advisor
  Params[0].string_value = "Experts\\EA.ex5";

  // The first input parameter of the advisor
  Params[1].type = TYPE_STRING;
  Params[1].string_value = "Hello World!";

  return(EXPERT::Run(Chart, Params));
}

#define NAME __FILE__

void OnStart()
{
  union UNION
  {
    double Double;
    long Long;
  } Chart;

  if (CurrentChart)
  {
    Chart.Long = ChartID();
    GlobalVariableSet(NAME, Chart.Double);

    MqlParam Params[1];

    // The Path to Yourself (script)
    Params[0].string_value = GetMyName();

    // We launch ourselves on a new chart
    EXPERT::Run(ChartOpen(_Symbol, _Period), Params);
  }
  else if (GlobalVariableCheck(NAME))
  {
    Chart.Double = GlobalVariableGet(NAME);
    GlobalVariableDel(NAME);

    RunExpert(Chart.Long);

    ChartClose();
  }
  else 
  // The easiest way is to run the advisor 
  // (with parameters other than default) 
  // not on the current chart
    RunExpert(ChartOpen(_Symbol, _Period));
}