// Restarts running advisors by changing input parameters
#property script_show_inputs

#include <fxsaber\Expert.mqh>

input bool inAllExperts = true; // Restart experts from all/current (true/false) charts?
input int inChange = 1;         // How much to change the input parameters?

template <typename T>
bool StringIs( const string Str )
{
  return((string)(T)Str == Str);
}

bool StringIsNum( const string Str )
{
  return(StringIs<long>(Str) || StringIs<double>(Str));
}

string GetExpertData( const ulong Chart = 0, const long Change = 0 )
{
  string Str = NULL;

  MqlParam Parameters[];
  string Names[];

  if (EXPERT::Parameters(Chart, Parameters, Names))
  {
    Str += "\n" + ChartSymbol(Chart) + " " + EnumToString(ChartPeriod(Chart)) + " " + Parameters[0].string_value + "\n";

    const int Amount = ArraySize(Names);

    for (int i = 0; i < Amount; i++)
      Str += (string)i + ": "+ Names[i] + " = " 
      + Parameters[i + 1].string_value +
             (StringIsNum(Parameters[i + 1].string_value) ? (" ") 
             + (Change >= 0 ? "+" : "") 
             + (string)Change : "") + "\n";
  }

  return(Str);
}

string GetExpertsData( const bool AllExperts = true, const long Change = 0 )
{
  string Str = AllExperts ? NULL : GetExpertData();

  if (AllExperts)
  {
    long Chart = ChartFirst();

    while (Chart != -1)
    {
      Str += GetExpertData(Chart, Change);

      Chart = ChartNext(Chart);
    }
  }

  return(Str);
}

bool ExpertChange( const long Chart_ID = 0, const int Change = 0 )
{
  bool Res = Change ? false : EXPERT::Reopen(Chart_ID);

  if (Change)
  {
    MqlParam Parameters[];
    string Names[];

    Res = EXPERT::Parameters(Chart_ID, Parameters, Names);

    if (Res)
    {
      const int Amount = ArraySize(Parameters);

      for (int i = 1; i < Amount; i++)
      {
        const string Str = Parameters[i].string_value;

        if (StringIsNum(Str))
          Parameters[i].string_value = (StringIs<long>(Str) ? (string)((long)Str + Change) : (string)((double)Str + Change));
      }

      Res = EXPERT::Run(Chart_ID, Parameters);
    }
  }

  return(Res);
}

bool ExpertsChange( const bool AllExperts = true, const int Change = 0 )
{
  bool Res = AllExperts ? true : ExpertChange(0, Change);

  if (AllExperts)
  {
    long Chart = ChartFirst();

    while (Chart != -1)
    {
      if ((Chart != ChartID()) && EXPERT::Is(Chart))
        Res &= ExpertChange(Chart, Change);

      Chart = ChartNext(Chart);
    }

    if (EXPERT::Is())
      Res &= ExpertChange(0, Change);
  }

  return(Res);
}

void OnStart()
{
  const string Str = GetExpertsData(inAllExperts, inChange);

  if ((Str != NULL) && (MessageBox(Str + "\nChange?", __FILE__, MB_YESNO | MB_ICONQUESTION) == IDYES))
    Print(ExpertsChange(inAllExperts, inChange));
}