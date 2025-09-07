//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+
#include "ChartProperties.mqh"
#include <Trade/AccountInfo.mqh>
CAccountInfo      Account;

//-- Enumeration declaration for Risk options
enum RiskOptions
  {
   MINIMUM_LOT,//MINIMUM LOTSIZE
   MAXIMUM_LOT,//MAXIMUM LOTSIZE
   PERCENTAGE_OF_BALANCE,//PERCENTAGE OF BALANCE
   PERCENTAGE_OF_FREEMARGIN,//PERCENTAGE OF FREE-MARGIN
   AMOUNT_PER_BALANCE,//AMOUNT PER BALANCE
   AMOUNT_PER_FREEMARGIN,//AMOUNT PER FREE-MARGIN
   LOTSIZE_PER_BALANCE,//LOTSIZE PER BALANCE
   LOTSIZE_PER_FREEMARGIN,//LOTSIZE PER FREE-MARGIN
   CUSTOM_LOT,//CUSTOM LOTSIZE
   PERCENTAGE_OF_MAXRISK//PERCENTAGE OF MAX-RISK
  } RiskProfileOption;//variable for Risk options

//-- Enumeration declaration for Risk floor
enum RiskFloor
  {
   RiskFloorMin,//MINIMUM LOTSIZE
   RiskFloorMax,//MAX-RISK
   RiskFloorNone//NONE
  } RiskFloorOption;//variable for Risk floor

//-- Enumeration declaration for Risk ceiling(Maximum allowable risk in terms of lot-size)
enum RiskCeil
  {
   RiskCeilMax,//MAX LOTSIZE
   RiskCeilMax2,//MAX LOTSIZE(x2)
   RiskCeilMax3,//MAX LOTSIZE(x3)
   RiskCeilMax4,//MAX LOTSIZE(x4)
   RiskCeilMax5,//MAX LOTSIZE(x5)
  } RiskCeilOption;//variable for Risk ceiling

//-- Structure declaration for Risk options (AMOUNT PER BALANCE and AMOUNT PER FREE-MARGIN)
struct RISK_AMOUNT
  {
   double            RiskAmountBoF;//store Balance or Free-Margin
   double            RiskAmount;//store risk amount
  } Risk_Profile_2;//variable for Risk options (AMOUNT PER BALANCE and AMOUNT PER FREE-MARGIN)

//-- Structure declaration for Risk options (LOTSIZE PER BALANCE and LOTSIZE PER FREE-MARGIN)
struct RISK_LOT
  {
   double            RiskLotBoF;//store Balance or Free-Margin
   double            RiskLot;//store lot-size
  } Risk_Profile_3;//variable for Risk options (LOTSIZE PER BALANCE and LOTSIZE PER FREE-MARGIN)


double            RiskFloorPercentage;//variable for RiskFloorMax
double            Risk_Profile_1;//variable for Risk options (PERCENTAGE OF BALANCE and PERCENTAGE OF FREE-MARGIN)
double            Risk_Profile_4;//variable for Risk option (CUSTOM LOTSIZE)
double            Risk_Profile_5;//variable for Risk option (PERCENTAGE OF MAX-RISK)

//+------------------------------------------------------------------+
//|RiskManagement class                                              |
//+------------------------------------------------------------------+
class CRiskManagement : public CChartProperties
  {

private:
   double            Medium;//variable to store actual Account (Balance or Free-Margin)
   double            RiskAmount,MinimumAmount;
   double            Lots;//variable to store Lot-size to open trade
   const double      max_percent;//variable to store percentage for Maximum risk

   //-- enumeration for dealing with account balance/free-margin
   enum RiskMedium
     {
      BALANCE,
      MARGIN
     };

   //-- calculations for Risk options (PERCENTAGE OF BALANCE and PERCENTAGE OF FREE-MARGIN)
   double              RiskProfile1(const RiskMedium R_Medium);
   //-- calculations for Risk options (AMOUNT PER BALANCE and AMOUNT PER FREE-MARGIN)
   double              RiskProfile2(const RiskMedium R_Medium);
   //-- calculations for Risk options (LOTSIZE PER BALANCE and LOTSIZE PER FREE-MARGIN)
   double              RiskProfile3(const RiskMedium R_Medium);
   //-- calculations for Maximum allowable Risk
   double              MaxRisk(const double percent);
   //-- Store Trade's Open-price
   double              OpenPrice;
   //-- Store Trade's Close-price
   double              ClosePrice;
   //-- Store Ordertype between (ORDER_TYPE_BUY or ORDER_TYPE_SELL) for risk calaculations
   ENUM_ORDER_TYPE     ORDERTYPE;
   //-- Set Medium variable value
   void                SetMedium(const RiskMedium R_Medium) {Medium = (R_Medium==BALANCE)?Account.Balance():Account.FreeMargin();}
   //-- Get Minimum Risk for a Trade using Minimum Lot-size
   bool                GetMinimumRisk()
     {
      return OrderCalcProfit(ORDERTYPE,Symbol(),LotsMin(),OpenPrice,ClosePrice,MinimumAmount);
     }
   //-- Retrieve Risk amount based on Risk inputs
   double            GetRisk(double Amount)
     {
      if(!GetMinimumRisk()||Amount==0)
         return 0.0;
      return ((Amount/MinimumAmount)*LotsMin());
     }

protected:
   //-- Application of Lot-size limits
   void              ValidateLotsize(double &Lotsize);
   //-- Set ORDERTYPE variable to (ORDER_TYPE_BUY or ORDER_TYPE_SELL) respectively
   void              SetOrderType(ENUM_ORDER_TYPE Type)
     {
      if(Type==ORDER_TYPE_BUY||Type==ORDER_TYPE_BUY_LIMIT||Type==ORDER_TYPE_BUY_STOP)
        {
         ORDERTYPE = ORDER_TYPE_BUY;
        }
      else
         if(Type==ORDER_TYPE_SELL||Type==ORDER_TYPE_SELL_LIMIT||Type==ORDER_TYPE_SELL_STOP)
           {
            ORDERTYPE = ORDER_TYPE_SELL;
           }
     }

public:

                     CRiskManagement();//Class's constructor
   //-- Retrieve user's Risk option
   string            GetRiskOption()
     {
      switch(RiskProfileOption)
        {
         case  MINIMUM_LOT://MINIMUM LOTSIZE - Risk Option
            return "MINIMUM LOTSIZE";
            break;
         case MAXIMUM_LOT://MAXIMUM LOTSIZE - Risk Option
            return "MAXIMUM LOTSIZE";
            break;
         case PERCENTAGE_OF_BALANCE://PERCENTAGE OF BALANCE - Risk Option
            return "PERCENTAGE OF BALANCE";
            break;
         case PERCENTAGE_OF_FREEMARGIN://PERCENTAGE OF FREE-MARGIN - Risk Option
            return "PERCENTAGE OF FREE-MARGIN";
            break;
         case AMOUNT_PER_BALANCE://AMOUNT PER BALANCE - Risk Option
            return "AMOUNT PER BALANCE";
            break;
         case AMOUNT_PER_FREEMARGIN://AMOUNT PER FREE-MARGIN - Risk Option
            return "AMOUNT PER FREE-MARGIN";
            break;
         case LOTSIZE_PER_BALANCE://LOTSIZE PER BALANCE - Risk Option
            return "LOTSIZE PER BALANCE";
            break;
         case LOTSIZE_PER_FREEMARGIN://LOTSIZE PER FREE-MARGIN - Risk Option
            return "LOTSIZE PER FREE-MARGIN";
            break;
         case CUSTOM_LOT://CUSTOM LOTSIZE - Risk Option
            return "CUSTOM LOTSIZE";
            break;
         case PERCENTAGE_OF_MAXRISK://PERCENTAGE OF MAX-RISK - Risk Option
            return "PERCENTAGE OF MAX-RISK";
            break;
         default:
            return "";
            break;
        }
     }
   //-- Retrieve user's Risk Floor Option
   string            GetRiskFloor()
     {
      switch(RiskFloorOption)
        {
         case RiskFloorMin://MINIMUM LOTSIZE for Risk floor options
            return "MINIMUM LOTSIZE";
            break;
         case RiskFloorMax://MAX-RISK for Risk floor options
            return "MAX-RISK";
            break;
         case RiskFloorNone://NONE for Risk floor options
            return "NONE";
            break;
         default:
            return "";
            break;
        }
     }
   //-- Retrieve user's Risk Ceiling option
   string            GetRiskCeil()
     {
      switch(RiskCeilOption)
        {
         case  RiskCeilMax://MAX LOTSIZE for Risk ceiling options
            return "MAX LOTSIZE";
            break;
         case RiskCeilMax2://MAX LOTSIZE(x2) for Risk ceiling options
            return "MAX LOTSIZE(x2)";
            break;
         case RiskCeilMax3://MAX LOTSIZE(x3) for Risk ceiling options
            return "MAX LOTSIZE(x3)";
            break;
         case RiskCeilMax4://MAX LOTSIZE(x4) for Risk ceiling options
            return "MAX LOTSIZE(x4)";
            break;
         case RiskCeilMax5://MAX LOTSIZE(x5) for Risk ceiling options
            return "MAX LOTSIZE(x5)";
            break;
         default:
            return "";
            break;
        }
     }

   double            Volume();//Get risk in Volume
   //Apply fixes to lot-size where applicable
   void              NormalizeLotsize(double &Lotsize);
  };

//+------------------------------------------------------------------+
//|Constructor                                                       |
//+------------------------------------------------------------------+
//Initialize values
CRiskManagement::CRiskManagement(void):Lots(0.0),max_percent(100),
   ORDERTYPE(ORDER_TYPE_BUY),OpenPrice(Ask()),
   ClosePrice(NormalizePrice(Ask()+Ask()*0.01))

  {
  }

//+------------------------------------------------------------------+
//|Get risk in Volume                                                |
//+------------------------------------------------------------------+
double CRiskManagement::Volume()
  {
   switch(RiskProfileOption)
     {
      case  MINIMUM_LOT://MINIMUM LOTSIZE - Risk Option
         return LotsMin();
         break;
      case MAXIMUM_LOT://MAXIMUM LOTSIZE - Risk Option
         Lots = LotsMax();
         break;
      case PERCENTAGE_OF_BALANCE://PERCENTAGE OF BALANCE - Risk Option
         Lots = RiskProfile1(BALANCE);
         break;
      case PERCENTAGE_OF_FREEMARGIN://PERCENTAGE OF FREE-MARGIN - Risk Option
         Lots = RiskProfile1(MARGIN);
         break;
      case AMOUNT_PER_BALANCE://AMOUNT PER BALANCE - Risk Option
         Lots = RiskProfile2(BALANCE);
         break;
      case AMOUNT_PER_FREEMARGIN://AMOUNT PER FREE-MARGIN - Risk Option
         Lots = RiskProfile2(MARGIN);
         break;
      case LOTSIZE_PER_BALANCE://LOTSIZE PER BALANCE - Risk Option
         Lots =  RiskProfile3(BALANCE);
         break;
      case LOTSIZE_PER_FREEMARGIN://LOTSIZE PER FREE-MARGIN - Risk Option
         Lots = RiskProfile3(MARGIN);
         break;
      case CUSTOM_LOT://CUSTOM LOTSIZE - Risk Option
         Lots = Risk_Profile_4;
         break;
      case PERCENTAGE_OF_MAXRISK://PERCENTAGE OF MAX-RISK - Risk Option
         Lots = MaxRisk(Risk_Profile_5);
         break;
      default:
         Lots = 0.0;
         break;
     }
   ValidateLotsize(Lots);//Check/Adjust Lotsize Limits
   NormalizeLotsize(Lots);//Normalize Lotsize
   return Lots;
  }

//+------------------------------------------------------------------+
//|calculations for Risk options                                     |
//|(PERCENTAGE OF BALANCE and PERCENTAGE OF FREE-MARGIN)             |
//+------------------------------------------------------------------+
//-- calculations for Risk options (PERCENTAGE OF BALANCE and PERCENTAGE OF FREE-MARGIN)
double CRiskManagement::RiskProfile1(const RiskMedium R_Medium)
  {
   SetMedium(R_Medium);
   RiskAmount = Medium*(Risk_Profile_1/100);
   return GetRisk(RiskAmount);
  }

//+------------------------------------------------------------------+
//|calculations for Risk options                                     |
//|(AMOUNT PER BALANCE and AMOUNT PER FREE-MARGIN)                   |
//+------------------------------------------------------------------+
//-- calculations for Risk options (AMOUNT PER BALANCE and AMOUNT PER FREE-MARGIN)
double CRiskManagement::RiskProfile2(const RiskMedium R_Medium)
  {
   SetMedium(R_Medium);
   double risk = (Risk_Profile_2.RiskAmountBoF/Risk_Profile_2.RiskAmount);
   risk = (risk<1)?1:risk;

   if(Medium<=0)
      return 0.0;

   RiskAmount = Medium/risk;
   return GetRisk(RiskAmount);
  }

//+------------------------------------------------------------------+
//|calculations for Risk options                                     |
//|(LOTSIZE PER BALANCE and LOTSIZE PER FREE-MARGIN)                 |
//+------------------------------------------------------------------+
//-- calculations for Risk options (LOTSIZE PER BALANCE and LOTSIZE PER FREE-MARGIN)
double CRiskManagement::RiskProfile3(const RiskMedium R_Medium)
  {
   SetMedium(R_Medium);
   return (Medium>0)?((Medium/Risk_Profile_3.RiskLotBoF)*Risk_Profile_3.RiskLot):0.0;
  }

//+------------------------------------------------------------------+
//|calculations for Maximum allowable Risk                           |
//+------------------------------------------------------------------+
//-- calculations for Maximum allowable Risk
double CRiskManagement::MaxRisk(const double percent)
  {
   double margin=0.0,max_risk=0.0;
//--- checks
   if(percent<0.01 || percent>100)
     {
      Print(__FUNCTION__," invalid parameters");
      return(0.0);
     }
//--- calculate margin requirements for 1 lot
   if(!OrderCalcMargin(ORDERTYPE,Symbol(),1.0,OpenPrice,margin) || margin<0.0)
     {
      Print(__FUNCTION__," margin calculation failed");
      return(0.0);
     }
//--- calculate maximum volume
   max_risk=Account.FreeMargin()*(percent/100.0)/margin;
//--- return volume
   return(max_risk);
  }

//+------------------------------------------------------------------+
//|Apply fixes to lot-size where applicable                          |
//+------------------------------------------------------------------+
void CRiskManagement::NormalizeLotsize(double &Lotsize)
  {
   if(Lotsize<=0.0)
      return;

//-- Check if the is a Volume limit for the current Symbol
   if(LotsLimit()>0.0)
     {
      if((Lots+PositionsVolume()+OrdersVolume())>LotsLimit())
        {
         //-- calculation of available lotsize remaining
         double remaining_avail_lots = (LotsLimit()-(PositionsVolume()+OrdersVolume()));
         if(remaining_avail_lots>=LotsMin())
           {
            if(RiskFloorOption==RiskFloorMin)//Check if Risk floor option is MINIMUM LOTSIZE
              {
               Print("Warning: Volume Limit Reached, minimum Lotsize selected.");
               Lotsize = LotsMin();
              }
            else
               if(RiskFloorOption==RiskFloorMax)//Check if Risk floor option is MAX-RISK
                 {
                  Print("Warning: Volume Limit Reached, Lotsize Reduced.");
                  Lotsize = ((remaining_avail_lots*(RiskFloorPercentage/100))>LotsMin())?
                            (remaining_avail_lots*(RiskFloorPercentage/100)):LotsMin();
                 }
           }
         else
           {
            Print("Volume Limit Reached!");
            Lotsize=0.0;
            return;
           }
        }
     }

//Check if there is a valid Volume Step for the current Symbol
   if(LotsStep()>0.0)
      Lotsize=LotsStep()*MathFloor(Lotsize/LotsStep());
  }

//+------------------------------------------------------------------+
//|Application of Lot-size limits                                    |
//+------------------------------------------------------------------+
void CRiskManagement::ValidateLotsize(double &Lotsize)
  {
   switch(RiskFloorOption)
     {
      case RiskFloorMin://MINIMUM LOTSIZE for Risk floor options
         //-- Check if lot-size is not less than Minimum lot or more than maximum allowable risk
         if(Lotsize<LotsMin()||Lotsize>MaxRisk(max_percent))
           {
            Lotsize=LotsMin();
           }
         break;
      case RiskFloorMax://MAX-RISK for Risk floor options
         //-- Check if lot-size is more the maximum allowable risk
         if(Lotsize>MaxRisk(max_percent))
           {
            Lotsize=(MaxRisk(RiskFloorPercentage)>LotsMin())?MaxRisk(RiskFloorPercentage):LotsMin();
           }
         else
            if(Lotsize<LotsMin())//Check if lot-size is less than Minimum lot
              {
               Lotsize=LotsMin();
              }
         break;
      case RiskFloorNone://NONE for Risk floor options
         //Check if lot-size is less than Minimum lot
         if(Lotsize<LotsMin())
           {
            Lotsize=0.0;
           }
         break;
      default:
         Lotsize=0.0;
         break;
     }

   switch(RiskCeilOption)
     {
      case  RiskCeilMax://MAX LOTSIZE for Risk ceiling options
         //Check if lot-size is more than Maximum lot
         if(Lotsize>LotsMax())
            Lotsize=LotsMax();
         break;
      case RiskCeilMax2://MAX LOTSIZE(x2) for Risk ceiling options
         //Check if lot-size is more than Maximum lot times two
         if(Lotsize>(LotsMax()*2))
            Lotsize=(LotsMax()*2);
         break;
      case RiskCeilMax3://MAX LOTSIZE(x3) for Risk ceiling options
         //Check if lot-size is more than Maximum lot times three
         if(Lotsize>(LotsMax()*3))
            Lotsize=(LotsMax()*3);
         break;
      case RiskCeilMax4://MAX LOTSIZE(x4) for Risk ceiling options
         //Check if lot-size is more than Maximum lot times four
         if(Lotsize>(LotsMax()*4))
            Lotsize=(LotsMax()*4);
         break;
      case RiskCeilMax5://MAX LOTSIZE(x5) for Risk ceiling options
         //Check if lot-size is more than Maximum lot times five
         if(Lotsize>(LotsMax()*5))
            Lotsize=(LotsMax()*5);
         break;
      default:
         break;
     }
  }
//+------------------------------------------------------------------+
