//+------------------------------------------------------------------+
//|                                         TradeStatisticsPanel.mqh |
//|                                                        avoitenko |
//|                        https://login.mql5.com/en/users/avoitenko |
//+------------------------------------------------------------------+
#property copyright "avoitenko"
#property link      "https://login.mql5.com/en/users/avoitenko"

//+------------------------------------------------------------------+
//|   Include                                                        |
//+------------------------------------------------------------------+
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>
#include <CTradeStatistics.mqh>

//+------------------------------------------------------------------+
//|   Defines                                                        |
//+------------------------------------------------------------------+
#define INDENT_LEFT     15 // left offset 
#define INDENT_TOP      30 // top offset

#define BUTTON_HEIGHT   19
#define BUTTON_WIDTH    120
#define BUTTON_OFFSET   70 // right offset button

#define VALUE_TEXT_LEN  16 // max len text(value)
#define VALUE_ROWS      15 // max rows (value)
//+------------------------------------------------------------------+
//|   Rarameters for create panel                                    |
//+------------------------------------------------------------------+
struct Params
  {
   long              chart;
   int               subwin;
   string            name;
   //---
   int               x1;
   int               y1;
   int               x2;
   int               y2;
   //---
   string            font_name;
   int               font_size;
   color             font_color;
  };
//+------------------------------------------------------------------+
//|   Class CPanelDialog                                             |
//+------------------------------------------------------------------+
class CPanelDialog : public CAppDialog
  {
private:
   CLabel            m_label[3][20];
   CLabel            m_value[3][20];
   CButton           m_button[1];

   string            FontName;
   int               FontSize;
   color             FontColor;
   int               FontHeight;

public:
   virtual bool      Create(Params &p);
   void              SetLabelParam(int index,int col,string text);
   string            GetButtonName(int index){if(index>0)index=0; return(m_button[index].Name());}

protected:
   virtual bool      OnResize(void);

   //--- create dependent controls
   bool              CreateButton(int index,bool only_move=false);
   bool              CreateLabel(int index,int col,int index,bool only_move=false);

   string            ParamCaption(int index);
  };
//+------------------------------------------------------------------+
//|   Create                                                         |
//+------------------------------------------------------------------+
bool CPanelDialog::Create(Params &p)
  {

   if(!CAppDialog::Create(p.chart,p.name,p.subwin,p.x1,p.y1,p.x2,p.y2)) return(false);

   FontName=p.font_name;
   FontSize=p.font_size;
   FontColor=p.font_color;
   FontHeight=FontSize*2;
//---   
   Caption(p.name);

//--- create controls
   if(!CreateButton(0)) return(false);

//--- col#1
   if(!CreateLabel(0,0,STAT_INITIAL_DEPOSIT))return(false);
   if(!CreateLabel(1,0,STAT_PROFIT))return(false);
   if(!CreateLabel(2,0,STAT_GROSS_PROFIT))return(false);
   if(!CreateLabel(3,0,STAT_GROSS_LOSS))return(false);
   if(!CreateLabel(4,0,STAT_PROFIT_FACTOR))return(false);
   if(!CreateLabel(5,0,STAT_RECOVERY_FACTOR))return(false);
   if(!CreateLabel(6,0,STAT_AHPR))return(false);
   if(!CreateLabel(7,0,STAT_GHPR))return(false);
   if(!CreateLabel(8,0,STAT_Z_SCORE))return(false);
   if(!CreateLabel(10,0,STAT_TRADES))return(false);
   if(!CreateLabel(11,0,STAT_DEALS))return(false);

//---col#2
   if(!CreateLabel(0,1,STAT_EXPECTED_PAYOFF))return(false);
   if(!CreateLabel(1,1,STAT_SHARPE_RATIO))return(false);
   if(!CreateLabel(2,1,STAT_LR_CORRELATION))return(false);
   if(!CreateLabel(3,1,STAT_LR_STANDARD_ERROR))return(false);

   if(!CreateLabel(5,1,STAT_SHORT_TRADES))return(false);
   if(!CreateLabel(6,1,STAT_PROFIT_TRADES))return(false);
   if(!CreateLabel(7,1,STAT_MAX_PROFITTRADE))return(false);
   if(!CreateLabel(8,1,STAT_AVG_PROFIT_TRADE))return(false);
   if(!CreateLabel(9,1,STAT_MAX_CONWINS))return(false);
   if(!CreateLabel(10,1,STAT_CONPROFITMAX))return(false);
   if(!CreateLabel(11,1,STAT_PROFITTRADES_AVGCON))return(false);

//--- col#3   
   if(!CreateLabel(1,2,STAT_BALANCE_DD_ABSOLUTE))return(false);
   if(!CreateLabel(2,2,STAT_BALANCE_DD))return(false);
   if(!CreateLabel(3,2,STAT_BALANCE_DD_RELATIVE))return(false);

   if(!CreateLabel(5,2,STAT_LONG_TRADES))return(false);
   if(!CreateLabel(6,2,STAT_LOSS_TRADES))return(false);
   if(!CreateLabel(7,2,STAT_MAX_LOSSTRADE))return(false);
   if(!CreateLabel(8,2,STAT_AVG_LOSS_TRADE))return(false);
   if(!CreateLabel(9,2,STAT_MAX_CONLOSSES))return(false);
   if(!CreateLabel(10,2,STAT_CONLOSSMAX))return(false);
   if(!CreateLabel(11,2,STAT_LOSSTRADES_AVGCON))return(false);

//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//|   ParamCaption                                                   |
//+------------------------------------------------------------------+
string CPanelDialog::ParamCaption(int index)
  {
   switch(index)
     {
      case STAT_INITIAL_DEPOSIT:       return("Initial Deposit");
      case STAT_PROFIT:                return("Total Net Profit");
      case STAT_BALANCE:               return("Balance");
      case STAT_EQUITY:                return("Equity");
      case STAT_GROSS_PROFIT:          return("Gross Profit");
      case STAT_GROSS_LOSS:            return("Gross Loss");

      case STAT_PROFIT_FACTOR:         return("Profit Factor");
      case STAT_RECOVERY_FACTOR:       return("Recovery Factor");
      case STAT_EXPECTED_PAYOFF:       return("Expected Payoff");

      case STAT_BALANCE_DD_ABSOLUTE:   return("Balance Dr. Abs.");
      case STAT_BALANCE_DD:            return("Balance Dr. Max.");
      case STAT_BALANCE_DD_RELATIVE:   return("Balance Dr. Rel.");
      case STAT_TRADES:                return("Total Trades");
      case STAT_DEALS:                 return("Total Deals");
      case STAT_SHORT_TRADES:          return("Short Trades");
      case STAT_LONG_TRADES:           return("Long Trades");
      case STAT_PROFIT_TRADES:         return("Profit Trades");
      case STAT_LOSS_TRADES:           return("Loss Trades");

      //---
      case STAT_MAX_PROFITTRADE:       return("Largest Profit Trade");
      case STAT_MAX_LOSSTRADE:         return("Largest Loss Trade");

      case STAT_CONPROFITMAX:          return("Max. Cons. Profit");
      case STAT_MAX_CONWINS:           return("Max. Cons. Wins");
      case STAT_CONLOSSMAX:            return("Max. Cons. Loss");
      case STAT_MAX_CONLOSSES:         return("Max. Cons. Losses");

      case STAT_AVG_PROFIT_TRADE:      return("Avg. Profit Trade");
      case STAT_AVG_LOSS_TRADE:        return("Avg. Loss Trade");

      case STAT_PROFITTRADES_AVGCON:   return("Avg. Cons. Wins");
      case STAT_LOSSTRADES_AVGCON:     return("Avg. Cons. Losses");

      case STAT_GHPR:                  return("GHPR");
      case STAT_AHPR:                  return("AHPR");
      case STAT_SHARPE_RATIO:          return("Sharpe Ratio");
      case STAT_Z_SCORE:               return("Z Score");
      case STAT_LR_CORRELATION:        return("LR Correlation");
      case STAT_LR_STANDARD_ERROR:     return("LR Standard Error");

      default:                         return("---");
     }
  }
//+------------------------------------------------------------------+
//|   OnResize                                                       |
//+------------------------------------------------------------------+
bool CPanelDialog::OnResize(void)
  {
//--- call method of parent class
   if(!CAppDialog::OnResize()) return(false);

//--- move button
   CreateButton(0,true);

//--- move labels
   for(int c=0;c<=2;c++)
      for(int i=0;i<=11;i++)
         CreateLabel(i,c,0,true);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//|   CreateLabel                                                    |
//+------------------------------------------------------------------+
bool CPanelDialog::CreateLabel(int i,int col,int name,bool only_move=false)
  {
   int delta=Height()-ClientAreaHeight();
//--- range check
   int range1=(int)MathMin(ArrayRange(m_label,0),ArrayRange(m_value,0));
   if(col>=range1)col=range1-1;

   int range2=(int)MathMin(ArrayRange(m_label,1),ArrayRange(m_value,1));
   if(i>=range2)i=range2-1;

   int width_3=ClientAreaWidth()/3;

   int x1,y1,x2,y2;
   int x11,y11,x22,y22;

//--- coords
   switch(col)
     {
      case 1://col#2
         //---
         x1 = INDENT_LEFT + width_3;
         y1 = INDENT_TOP + FontHeight*i;
         x2 = x1;
         y2 = y1 + FontHeight;
         //---
         x11 = (int)(width_3*1.5);
         y11 = INDENT_TOP + FontHeight*i;
         x22 = x11;
         y22 = y1 + FontHeight;
         break;

      case 2://col#3

         //---      
         x1 = INDENT_LEFT + width_3*2;
         y1 = INDENT_TOP + FontHeight*i;
         x2 = x1;
         y2 = y1 + FontHeight;

         //---
         x11 =  (int)(width_3*2.5);
         y11 = INDENT_TOP + FontHeight*i;
         x22 = x11;
         y22 = y1 + FontHeight;

         break;

      default://col#1
         //---
         x1 = INDENT_LEFT;
         y1 = INDENT_TOP + FontHeight*i;
         x2 = x1;
         y2 = y1 + FontHeight;
         //---
         x11 = width_3/2;
         y11 = INDENT_TOP + FontHeight*i;
         x22 = x11;
         y22 = y11 + FontHeight;
         break;
     }

   if(only_move)
     {
      m_label[col][i].Move(x1,y1);
      m_value[col][i].Move(x11,y11);
      return(true);
     }

//--- create label
   if(!m_label[col][i].Create(m_chart_id,m_name+"Label_"+IntegerToString(i)+"_"+IntegerToString(col),m_subwin,x1,y1-delta,x2,y2-delta)) return(false);
   if(!Add(m_label[col][i])) return(false);

   m_label[col][i].Text(ParamCaption(name));
   m_label[col][i].Font(FontName);
   m_label[col][i].FontSize(FontSize);
   m_label[col][i].Color(FontColor);

//--- create value
   if(!m_value[col][i].Create(m_chart_id,m_name+"Value_"+IntegerToString(i)+"_"+IntegerToString(col),m_subwin,x11,y11-delta,x22,y22-delta)) return(false);
   if(!Add(m_value[col][i])) return(false);

   m_value[col][i].Font(FontName);
   m_value[col][i].FontSize(FontSize);
   m_value[col][i].Color(FontColor);
   m_value[col][i].Text("");

//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//|   CreateButton                                                   |
//+------------------------------------------------------------------+
bool CPanelDialog::CreateButton(int index,bool only_move=false)
  {
   int delta=Height()-ClientAreaHeight();
   int x1,y1,x2,y2;
   string caption;
   switch(index)
     {
      case 0://--- Calculate
         x1=ClientAreaWidth()-BUTTON_WIDTH-BUTTON_OFFSET;
         y1=-delta+3;
         caption="Calculate";
         break;
     }

   if(only_move) return(m_button[index].Move(x1,1));

//--- sizes
   x2 = x1 + BUTTON_WIDTH;
   y2 = y1 + BUTTON_HEIGHT;
//--- create
   if(!m_button[index].Create(m_chart_id,m_name+"Button_"+IntegerToString(index),m_subwin,x1,y1,x2,y2)) return(false);
   m_button[index].FontSize(8);
//m_button[index].Font(FontName);
   m_button[index].Text(caption);

   if(!Add(m_button[index])) return(false);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//|   SetLabelParam                                                  |
//+------------------------------------------------------------------+
void CPanelDialog::SetLabelParam(int i,int col,string text)
  {
//--- check range
   int range1=ArrayRange(m_value,0);
   if(col>=range1)col=range1-1;

   int range2=ArrayRange(m_value,1);
   if(i>=range2)i=range2-1;

//--- fill spaces for line format
   int text_length=StringLen(text);
   if(text_length<VALUE_TEXT_LEN)
     {
      string temp;
      StringInit(temp,VALUE_TEXT_LEN-text_length,' ');
      text=temp+text;
     }

   m_value[col][i].Text(text);
   m_value[col][i].Color(FontColor);
  }
//+------------------------------------------------------------------+
