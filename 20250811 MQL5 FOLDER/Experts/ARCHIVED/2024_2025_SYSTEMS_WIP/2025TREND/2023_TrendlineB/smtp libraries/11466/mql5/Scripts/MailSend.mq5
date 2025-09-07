//+------------------------------------------------------------------+
//|                                                     MailSend.mq5 |
//|                                                        avoitenko |
//|                        https://login.mql5.com/en/users/avoitenko |
//+------------------------------------------------------------------+
#property copyright "avoitenko"
#property link      "https://login.mql5.com/en/users/avoitenko"
#property version   "1.00"
#property script_show_inputs 

#include <Trade\Trade.mqh>
#include <Arrays\ArrayString.mqh>
#include <SmtpMailLibrary.mqh>
//+------------------------------------------------------------------+
//|   ENUM_MESSAGE                                                   |
//+------------------------------------------------------------------+
enum ENUM_MESSAGE
  {
   MESSAGE_TEXT,           // text
   MESSAGE_HTML,           // html
   MESSAGE_INLINE_TEXT,    // inline text
   MESSAGE_INLINE_HTML     // inline html
  };
//+------------------------------------------------------------------+
//|   Input parameers                                                |
//+------------------------------------------------------------------+
input string   mail_options="=== Mail Options ===";      // Mail Options
input string   InpMailHost="smtp.gmail.com";             // Host
input int      InpMailPort=465;                          // Port
input string   InpMailUser="user@gmail.com";             // User
input string   InpMailPassword="password";               // Password
input string   InpMailFrom="";                           // From (text)
input string   InpMailSubject="Smtp Mail Library";       // Subject (text)
input string   InpMailTo="user@ukr.net";                 // Mail To Address
input uint     InpMailConnectionTimeout=5000;            // Connection Timeout, msec
input string   msg_options="=== Message Options ===";    // Message Options
input ENUM_MESSAGE InpMessageType=MESSAGE_HTML;          // Type
input string   InpMessageAttachmentFiles="d:\\Temp\\dollar.bmp;d:\\Temp\\euro.bmp";// Attachment Files
input string   InpMessageInlineFiles="d:\\Temp\\ReportTester-20066082.html";// Inline Files
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   long smtp=0; // for x86 termianls

//--- connection
   int err=MailConnect(smtp,InpMailHost,InpMailPort,InpMailUser,InpMailPassword,InpMailConnectionTimeout);
   if(err!=0)
     {
      Print("MailConnect error: ",MailErrorDescription(err));
      return;
     }

   switch(InpMessageType)
     {

      //---
      case MESSAGE_TEXT:
        {
         //--- plain text
         string text=StringFormat("Account: %d\r\nBalance: %.2f %s",AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoString(ACCOUNT_CURRENCY));

         //--- send mail to yourself
         err=MailSendText(smtp,InpMailUser,InpMailFrom,InpMailSubject,text,InpMessageAttachmentFiles);
         if(err!=0)
            Print("MailSendText error: ",MailErrorDescription(err));
         else
            PrintFormat("Program '%s' has sent mail to '%s'",MQLInfoString(MQL_PROGRAM_NAME),InpMailUser);

         //--- send mail to MailTo address
         err=MailSendText(smtp,InpMailTo,InpMailFrom,InpMailSubject,text,InpMessageAttachmentFiles);
         if(err!=0)
            Print("MailSendText error: ",MailErrorDescription(err));
         else
            PrintFormat("Program '%s' has sent mail to '%s'",MQLInfoString(MQL_PROGRAM_NAME),InpMailTo);
        }
      break;

      //---
      case MESSAGE_HTML:
        {
         //--- build html
         string html=BuildReport();
         //--- send html
         err=MailSendHtml(smtp,InpMailTo,InpMailFrom,InpMailSubject,html,"");
         if(err!=0)
            Print("MailSendText error: ",MailErrorDescription(err));
         else
            PrintFormat("Program '%s' has sent mail to '%s'",MQLInfoString(MQL_PROGRAM_NAME),InpMailTo);
        }
      break;

      //---
      case MESSAGE_INLINE_TEXT:
        {
         err=MailSendInlineTextFile(smtp,InpMailTo,InpMailFrom,InpMailSubject,InpMessageInlineFiles);
         if(err!=0)
            Print("MailSendText error: ",MailErrorDescription(err));
         else
            PrintFormat("Program '%s' has sent mail to '%s'",MQLInfoString(MQL_PROGRAM_NAME),InpMailTo);
        }
      break;

      //---
      case MESSAGE_INLINE_HTML:
        {
         err=MailSendInlineHtmlFile(smtp,InpMailTo,InpMailFrom,InpMailSubject,InpMessageInlineFiles);
         if(err!=0)
            Print("MailSendText error: ",MailErrorDescription(err));
         else
            PrintFormat("Program '%s' has sent mail to '%s'",MQLInfoString(MQL_PROGRAM_NAME),InpMailTo);
        }
      break;

     }

//--- close connection
   MailClose(smtp);
  }
//+------------------------------------------------------------------+
//|   BuildReport                                                    |
//+------------------------------------------------------------------+
string BuildReport()
  {
   CArrayString html;
//---   
   html.Add("<html><head><title>Report</title>");
   html.Add("<meta name=\"format-detection\" content=\"telephone=no\">");
   html.Add("<style type=\"text/css\" media=\"screen\">");
   html.Add("<!--");
   html.Add("td{font: 8pt Tahoma,Arial;}");
   html.Add("//-->");
   html.Add("</style>");
   html.Add("<style type=\"text/css\" media=\"print\">");
   html.Add("<!--");
   html.Add("td{font: 7pt Tahoma,Arial;}");
   html.Add("//-->");
   html.Add("</style>");
   html.Add("</head>");
   html.Add("<body topmargin=1 marginheight=1> <font face=\"tahoma,arial\" size=1>");
   html.Add("<div align=center>");
   html.Add(StringFormat("<div style=\"font: 18pt Times New Roman\"><b>%s</b></div>",AccountInfoString(ACCOUNT_SERVER)));
   html.Add("<table cellspacing=1 cellpadding=3 border=0>");
//---
   html.Add("<tr>");
   html.Add(StringFormat("<td colspan=2>A/C No: <b>%d</b></td>",AccountInfoInteger(ACCOUNT_LOGIN)));
   html.Add(StringFormat("<td colspan=6>Name: <b>%s</b></td>",AccountInfoString(ACCOUNT_NAME)));
   html.Add("<td colspan=2>&nbsp;</td>");
   html.Add(StringFormat("<td colspan=2 align=right>%s</td>",TimeToString(TimeCurrent())));
   html.Add("</tr>");
//---
   html.Add("<tr>");
   html.Add("<td colspan=13><b>Open Trades:</b></td>");
   html.Add("</tr>");
//---
   html.Add("<tr align=center bgcolor=\"#C0C0C0\">");
   html.Add("<td>Ticket</td>");
   html.Add("<td nowrap>Open Time</td>");
   html.Add("<td>Type</td>");
   html.Add("<td>Size</td>");
   html.Add("<td>Symbol</td>");
   html.Add("<td>Price</td>");
   html.Add("<td>S/L</td>");
   html.Add("<td>T/P</td>");
   html.Add("<td>Price</td>");
   html.Add("<td nowrap>Commission</td>");
   html.Add("<td>Swap</td>");
   html.Add("<td>Profit</td>");
   html.Add("</tr>");
//---
   double profit=0.0;
   int total=PositionsTotal();
   if(total == 0)
     {
      html.Add("<tr align=right><td colspan=13 nowrap align=center>No transactions</td></tr>");
     }
   else
     {
      CPositionInfo m_position;
      for(int i=0; i<total; i++)
        {
         m_position.SelectByIndex(i);

         //--- color
         if((i&1)==0)html.Add("<tr align=right>");
         else html.Add("<tr bgcolor=#E0E0E0 align=right>");

         //--- data
         html.Add(StringFormat("<td>%d</td>",m_position.Identifier()));
         html.Add(StringFormat("<td>&nbsp;%s</td>",TimeToString(m_position.Time())));

         if(m_position.PositionType()==POSITION_TYPE_BUY) html.Add("<td>buy</td>");
         else html.Add("<td>sell</td>");

         html.Add(StringFormat("<td>%.2f</td>",m_position.Volume()));
         html.Add(StringFormat("<td>%s</td>",m_position.Symbol()));
         html.Add(StringFormat("<td>%.5f</td>",m_position.PriceOpen()));
         html.Add(StringFormat("<td>%.5f</td>",m_position.StopLoss()));
         html.Add(StringFormat("<td>%.5f</td>",m_position.TakeProfit()));
         html.Add(StringFormat("<td>%.5f</td>",m_position.PriceCurrent()));
         html.Add(StringFormat("<td>%.2f</td>",m_position.Commission()));
         html.Add(StringFormat("<td>%.2f</td>",m_position.Swap()));
         html.Add(StringFormat("<td>%.2f</td>",m_position.Profit()));
         html.Add("</tr>");
         //---
         profit+=m_position.Profit();
        }
     }
//---
   html.Add("<tr>");
   html.Add(StringFormat("<td colspan=2><b>Balance: %.2f</b></td>",AccountInfoDouble(ACCOUNT_BALANCE)));
   html.Add(StringFormat("<td colspan=5><b>Equity: %.2f</b></td>",AccountInfoDouble(ACCOUNT_EQUITY)));
   html.Add("<td colspan=3><b>Floating P/L:</b></td>");
   html.Add(StringFormat("<td colspan=4 align=right><b>%.2f</b></td>",profit));
   html.Add("</tr>");
//---
   html.Add("</table></div></font></body></html>");

//--- save to one string
   string result="";
   total=html.Total();
   for(int i=0;i<total;i++)
      result+=html.At(i);
//--- done
   return(result);
  }
//+------------------------------------------------------------------+
