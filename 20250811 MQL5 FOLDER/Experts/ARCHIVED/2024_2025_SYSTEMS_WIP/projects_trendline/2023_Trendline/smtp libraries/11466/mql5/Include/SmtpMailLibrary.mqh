//+------------------------------------------------------------------+
//|                                              SmtpMailLibrary.mqh |
//|                                                        avoitenko |
//|                        https://login.mql5.com/en/users/avoitenko |
//+------------------------------------------------------------------+
#property copyright "avoitenko"
#property link      "https://login.mql5.com/en/users/avoitenko"

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
#define MAIL_NO_CONNECTION       -2
#define MAIL_NO_INITIALIZATION   -1
#define MAIL_NO_ERROR            0
#define MAIL_TIMEOUT             1
#define MAIL_WRONG_LOGIN         2
#define MAIL_WRONG_HOST          3
#define MAIL_HOST_NOT_FOUND      4

//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
#import "smtp_mail_x64.dll"
int MailConnect(long &mail,const string host,const int port,const string user,const string password,const int timeout=5000);
int MailSendText(long &mail,const string mailto,const string from,const string subject,const string text,const string files);
int MailSendHtml(long &mail,const string mailto,const string from,const string subject,const string html,const string files);
int MailSendInlineTextFile(long &mail,const string mailto,const string from,const string subject,const string files);
int MailSendInlineHtmlFile(long &mail,const string mailto,const string from,const string subject,const string files);
string MailErrorDescription(const int errno);
void MailClose(long &mail);
#import "smtp_mail_x86.dll"
int MailConnect(long &mail,const string host,const int port,const string user,const string password,const int timeout=5000);
int MailSendText(long &mail,const string mailto,const string from,const string subject,const string text,const string files);
int MailSendHtml(long &mail,const string mailto,const string from,const string subject,const string html,const string files);
int MailSendInlineTextFile(long &mail,const string mailto,const string from,const string subject,const string files);
int MailSendInlineHtmlFile(long &mail,const string mailto,const string from,const string subject,const string files);
string MailErrorDescription(const int errno);
void MailClose(long &mail);
#import
//+------------------------------------------------------------------+
//|   MailConnect                                                    |
//+------------------------------------------------------------------+
int MailConnect(long &mail,const string host,const int port,const string user,const string password,const int timeout=5000)
  {
   if(_IsX64) return(smtp_mail_x64::MailConnect(mail,host,port,user,password,timeout));
   return(smtp_mail_x86::MailConnect(mail,host,port,user,password,timeout));
  }
//+------------------------------------------------------------------+
//|   MailSendText                                                   |
//+------------------------------------------------------------------+
int MailSendText(long mail,const string mailto,const string from,const string subject,const string text,const string files)
  {
   if(_IsX64)return(smtp_mail_x64::MailSendText(mail,mailto,from,subject,text,files));
   return(smtp_mail_x86::MailSendText(mail,mailto,from,subject,text,files));
  }
//+------------------------------------------------------------------+
//|   MailSendHtml                                                   |
//+------------------------------------------------------------------+
int MailSendHtml(long &mail,const string mailto,const string from,const string subject,const string html,const string files)
  {
   if(_IsX64) return(smtp_mail_x64::MailSendHtml(mail,mailto,from,subject,html,files));
   else return(smtp_mail_x86::MailSendHtml(mail,mailto,from,subject,html,files));
  }
//+------------------------------------------------------------------+
//|   MailSendInlineTextFile                                         |
//+------------------------------------------------------------------+
int MailSendInlineTextFile(long &mail,const string mailto,const string from,const string subject,const string files)
  {
   if(_IsX64) return(smtp_mail_x64::MailSendInlineTextFile(mail,mailto,from,subject,files));
   else return(smtp_mail_x86::MailSendInlineTextFile(mail,mailto,from,subject,files));
  }
//+------------------------------------------------------------------+
//|   MailSendInlineHtmlFile                                         |
//+------------------------------------------------------------------+
int MailSendInlineHtmlFile(long &mail,const string mailto,const string from,const string subject,const string files)
  {
   if(_IsX64) return(smtp_mail_x64::MailSendInlineHtmlFile(mail,mailto,from,subject,files));
   else return(smtp_mail_x86::MailSendInlineHtmlFile(mail,mailto,from,subject,files));
  }
//+------------------------------------------------------------------+
//|   MailError                                                      |
//+------------------------------------------------------------------+
string MailErrorDescription(const int errno)
  {
   if(_IsX64) return(smtp_mail_x64::MailErrorDescription(errno));
   else return(smtp_mail_x86::MailErrorDescription(errno));
  }
//+------------------------------------------------------------------+
//|   MailClose                                                      |
//+------------------------------------------------------------------+
void MailClose(long &mail)
  {
   if(_IsX64)smtp_mail_x64::MailClose(mail);
   else smtp_mail_x86::MailClose(mail);
  }

//+------------------------------------------------------------------+
