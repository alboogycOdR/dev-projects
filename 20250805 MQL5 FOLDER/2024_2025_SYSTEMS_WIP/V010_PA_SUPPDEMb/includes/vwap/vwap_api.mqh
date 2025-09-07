void Market_Sell(double vwaptarget)//vwap
  {
   double positionPriceASK = SymbolInfoDouble(_Symbol,SYMBOL_ASK);//AdjustAboveStopLevel(_Symbol,PositionGetDouble(POSITION_PRICE_OPEN));
   double positionPriceBID = SymbolInfoDouble(_Symbol,SYMBOL_BID);//AdjustAboveStopLevel(_Symbol,PositionGetDouble(POSITION_PRICE_OPEN));

   double TakeProfitPoint = 0;
   double StopLossPoint = 0;
   bool M_Sell = false;

//   if(Tipo_de_Profit==DISABLE_TP)
//      TakeProfitPoint = 0;
//   if(Tipo_de_Profit==ENABLE_TP)
//      TakeProfitPoint = NormalizeDouble(positionPriceBID - TakeProfit,2);
//
//   if(Tipo_de_Stop==SL_DISABLED)
//      StopLossPoint = 0;
//   if(Tipo_de_Stop==SL_ENABLED)
//      StopLossPoint = NormalizeDouble(positionPriceASK + TakeLoss,2);
//   if(Tipo_de_Stop==RETURN_TO_AVG_SL)
//      StopLossPoint = NormalizeDouble(positionPriceASK + TakeLoss,2);

 

   M_Sell = trade_vwap.Sell(1,_Symbol,positionPriceBID,NULL,vwaptarget,"vwap trigger");
//+------------------------------------------------------------------+
// Verificação da Ordem de Compra                         |
//+------------------------------------------------------------------+
   if(!M_Sell)
     {
      Print(__FUNCTION__,"::Method Failed. Return code=",trade_vwap.ResultRetcode(),
            ". Descrição do código: ",trade_vwap.ResultRetcodeDescription(),", Magic=",magic_vwap);
     }
   else
     {
      Print(__FUNCTION__,"::Method Executed Successfully. Return code=",trade_vwap.ResultRetcode(),
            " (",trade_vwap.ResultRetcodeDescription(),")",", Magic=",magic_vwap);
     }
  }

  
//+------------------------------------------------------------------+
// Ordem a MARKET_TRADE de Compra                                |
//+------------------------------------------------------------------+
void Market_Buy(double vwaptarget)//vwap
  {
   double positionPriceASK = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double positionPriceBID = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   double TakeProfitPoint = 0;
   double StopLossPoint = 0;
   bool M_Buy = false;

   //   if(Tipo_de_Profit==DISABLE_TP)
   //      TakeProfitPoint = 0;
   //   if(Tipo_de_Profit==ENABLE_TP)
   //      TakeProfitPoint = NormalizeDouble(positionPriceASK + TakeProfit,2);
   //
   //   if(Tipo_de_Stop==SL_DISABLED)
   //      StopLossPoint = 0;
   //   if(Tipo_de_Stop==SL_ENABLED)
   //      StopLossPoint = NormalizeDouble(positionPriceBID - TakeLoss,2);
   //   if(Tipo_de_Stop==RETURN_TO_AVG_SL)
   //      StopLossPoint = NormalizeDouble(positionPriceBID - TakeLoss,2);


   StopLossPoint=StopLossPoint*Point();
   StopLossPoint=positionPriceBID-StopLossPoint;
 
   M_Buy = trade_vwap.Buy(1,_Symbol,positionPriceASK,NULL,vwaptarget,"vwap trigger");
//+------------------------------------------------------------------+
// Verificação da Ordem de Compra                         |
//+------------------------------------------------------------------+
   if(!M_Buy)
     {
      Print(__FUNCTION__,"::Method Failed. Return code=",trade_vwap.ResultRetcode(),
            ". Descrição do código: ",trade_vwap.ResultRetcodeDescription(),", Magic=",magic_vwap);
     }
   else
     {
      Print(__FUNCTION__,"::Method Executed Successfully. Return code=",trade_vwap.ResultRetcode(),
            " (",trade_vwap.ResultRetcodeDescription(),")",", Magic=",magic_vwap);
     }
  }