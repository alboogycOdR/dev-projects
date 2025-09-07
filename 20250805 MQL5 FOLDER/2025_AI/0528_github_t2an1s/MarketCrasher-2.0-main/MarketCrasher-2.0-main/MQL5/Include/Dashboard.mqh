//+------------------------------------------------------------------+
//| Dashboard include                                                |
//+------------------------------------------------------------------+

class CDashboard
  {
private:
   long   chart_id;

   int    y;

   double synergy_val;
   string bias_txt;
 



public:
   void Init()
     {
      chart_id=ChartID();

      y=20;
=======

      y=20;


      ObjectCreate(chart_id,"dash_bg",OBJ_LABEL,0,0,0);
      ObjectSetInteger(chart_id,"dash_bg",OBJPROP_CORNER,0);
      ObjectSetInteger(chart_id,"dash_bg",OBJPROP_XDISTANCE,10);
      ObjectSetInteger(chart_id,"dash_bg",OBJPROP_YDISTANCE,10);
      ObjectSetString(chart_id,"dash_bg",OBJPROP_TEXT,"MarketCrasher Dashboard");
      ObjectSetInteger(chart_id,"dash_bg",OBJPROP_FONTSIZE,12);
     }
   void Update()
     {
      // additional stats can be drawn here
     }

   void Shutdown()
     {
      ObjectDelete(chart_id,"dash_bg");
=======

   void SetSynergy(double val)
     {
      synergy_val=val;
      string txt=StringFormat("Synergy: %.2f",val);
      if(!ObjectFind(chart_id,"syn_label"))
         ObjectCreate(chart_id,"syn_label",OBJ_LABEL,0,0,0);
      ObjectSetInteger(chart_id,"syn_label",OBJPROP_CORNER,0);
      ObjectSetInteger(chart_id,"syn_label",OBJPROP_XDISTANCE,10);
      ObjectSetInteger(chart_id,"syn_label",OBJPROP_YDISTANCE,30);
      ObjectSetString(chart_id,"syn_label",OBJPROP_TEXT,txt);
      ObjectSetInteger(chart_id,"syn_label",OBJPROP_FONTSIZE,10);
     }
   void SetBias(string bias)
     {
      bias_txt=bias;
      if(!ObjectFind(chart_id,"bias_label"))
         ObjectCreate(chart_id,"bias_label",OBJ_LABEL,0,0,0);
      ObjectSetInteger(chart_id,"bias_label",OBJPROP_CORNER,0);
      ObjectSetInteger(chart_id,"bias_label",OBJPROP_XDISTANCE,10);
      ObjectSetInteger(chart_id,"bias_label",OBJPROP_YDISTANCE,45);
      ObjectSetString(chart_id,"bias_label",OBJPROP_TEXT,bias);
      ObjectSetInteger(chart_id,"bias_label",OBJPROP_FONTSIZE,10);
     }
   void Update()
     {
      // additional stats could be placed here

     }
   void Shutdown()
     {
      ObjectDelete(chart_id,"dash_bg");
      ObjectDelete(chart_id,"syn_label");
      ObjectDelete(chart_id,"bias_label");



     }
  };

static CDashboard dashboard;

void DashboardInit()
  {
   dashboard.Init();
  }

void DashboardOnTick()
  {
   dashboard.Update();

=======
  }


void DashboardShutdown()
  {
   dashboard.Shutdown();
  }
//+------------------------------------------------------------------+
