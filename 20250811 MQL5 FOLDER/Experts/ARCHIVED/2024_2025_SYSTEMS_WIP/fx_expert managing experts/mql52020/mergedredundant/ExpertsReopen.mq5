// ������������� ���������� ���������
#property script_show_inputs
#include "ExpertsAction.mqh"

input bool inAllExperts = true; // ������������� �������� �� ����/�������� (true/false) ������?











void OnStart()
{
  const string Str = GetExpertsData(inAllExperts);

  if ((Str != NULL) && 
    (MessageBox(Str + "\nReopen?", __FILE__, MB_YESNO | MB_ICONQUESTION) == IDYES))
    {
      Print(ExpertsAction(EXPERT::Reopen, inAllExperts));
    }
}