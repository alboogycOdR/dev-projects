
#property script_show_inputs
#include "include/ExpertsAction.mqh"

input bool inAllExperts = true; // Remove | Restart experts from all/current (true/false) charts?

bool ChartCloseCustom( const long Chart = 0 )
{
  return(::ChartClose(Chart));
}


void OnStart()
{
  const string Str = GetExpertsData(inAllExperts);

  //REMOVE |Removes running advisors from all charts
  //if ((Str != NULL) && 
  //  (MessageBox(Str + "\nRemove?", __FILE__, MB_YESNO | MB_ICONQUESTION) == IDYES))
  //  {
  //    Print(ExpertsAction(EXPERT::Remove, inAllExperts));
  //  }
//  //REOPEN | Restarts running advisors
  //if ((Str != NULL) && 
  //  (MessageBox(Str + "\nReopen?", __FILE__, MB_YESNO | MB_ICONQUESTION) == IDYES))
  //  {
  //    Print(ExpertsAction(EXPERT::Reopen, inAllExperts));
  //  }

//  //CHARTS CLOSE |Closes all charts where there are no advisors (useful for VPS)
  //Print(ExpertsAction(ChartCloseCustom, true, false));
}