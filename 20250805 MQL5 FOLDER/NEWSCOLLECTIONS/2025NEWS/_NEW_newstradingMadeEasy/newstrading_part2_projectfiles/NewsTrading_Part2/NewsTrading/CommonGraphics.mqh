//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+
#include "ObjectProperties.mqh"
#include "RiskManagement.mqh"
//+------------------------------------------------------------------+
//|CommonGraphics class                                              |
//+------------------------------------------------------------------+
class CCommonGraphics:CObjectProperties
  {
private:
   CRiskManagement   CRisk;//Risk management class object

public:
                     CCommonGraphics(void);//class constructor
                    ~CCommonGraphics(void) {}//class destructor
   void              GraphicsRefresh();//will create the chart objects
  };

//+------------------------------------------------------------------+
//|Constructor                                                       |
//+------------------------------------------------------------------+
CCommonGraphics::CCommonGraphics(void)
  {
   GraphicsRefresh();//calling GraphicsRefresh function
  }

//+------------------------------------------------------------------+
//|Specify Chart Objects                                             |
//+------------------------------------------------------------------+
void CCommonGraphics::GraphicsRefresh()
  {
//-- Will create the rectangle object
   Square(0,"Symbol Properties",2,20,330,183,ANCHOR_LEFT_UPPER);
//-- Will create the text object for the Symbol's name
   TextObj(0,"Symbol Name",Symbol(),5,23);
//-- Will create the text object for the contract size
   TextObj(0,"Symbol Contract Size","Contract Size: "+string(ContractSize()),5,40,CORNER_LEFT_UPPER,9);
//-- Will create the text object for the Symbol's Minimum lotsize
   TextObj(0,"Symbol MinLot","Minimum Lot: "+string(LotsMin()),5,60,CORNER_LEFT_UPPER,9);
//-- Will create the text object for the Symbol's Maximum lotsize
   TextObj(0,"Symbol MaxLot","Max Lot: "+string(LotsMax()),5,80,CORNER_LEFT_UPPER,9);
//-- Will create the text object for the Symbol's Volume Step
   TextObj(0,"Symbol Volume Step","Volume Step: "+string(LotsStep()),5,100,CORNER_LEFT_UPPER,9);
//-- Will create the text object for the Symbol's Volume Limit
   TextObj(0,"Symbol Volume Limit","Volume Limit: "+string(LotsLimit()),5,120,CORNER_LEFT_UPPER,9);
//-- Will create the text object for the trader's Risk Option
   TextObj(0,"Risk Option","Risk Option: "+CRisk.GetRiskOption(),5,140,CORNER_LEFT_UPPER,9);
//-- Will create the text object for the trader's Risk Floor
   TextObj(0,"Risk Floor","Risk Floor: "+CRisk.GetRiskFloor(),5,160,CORNER_LEFT_UPPER,9);
//-- Will create the text object for the trader's Risk Ceiling
   TextObj(0,"Risk Ceil","Risk Ceiling: "+CRisk.GetRiskCeil(),5,180,CORNER_LEFT_UPPER,9);
  }
//+------------------------------------------------------------------+
