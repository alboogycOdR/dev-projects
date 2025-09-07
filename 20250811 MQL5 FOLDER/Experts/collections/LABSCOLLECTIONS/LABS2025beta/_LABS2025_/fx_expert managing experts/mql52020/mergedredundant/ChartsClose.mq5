// ��������� ��� �����, ��� ����������� ��������� (������� ��� VPS)
#property script_show_inputs
#include "ExpertsAction.mqh"

bool ChartCloseCustom( const long Chart = 0 )
{
  return(::ChartClose(Chart));
}








void OnStart()
{
  Print(ExpertsAction(ChartCloseCustom, true, false));
}