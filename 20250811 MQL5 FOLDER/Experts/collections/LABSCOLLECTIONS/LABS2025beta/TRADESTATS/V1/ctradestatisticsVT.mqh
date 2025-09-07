//+------------------------------------------------------------------+
//|                                             CTradeStatistics.mqh |
//|                                                        avoitenko |
//|                        https://login.mql5.com/en/users/avoitenko |
//+------------------------------------------------------------------+
#property copyright "avoitenko"
#property link      "https://login.mql5.com/en/users/avoitenko"

#define NUMBER_OF_TRY_GET_HISTORY 20

//+------------------------------------------------------------------+
//|   Include                                                        |
//+------------------------------------------------------------------+
#include <Trade\DealInfo.mqh>
#include <Arrays\ArrayDouble.mqh>
//+------------------------------------------------------------------+
//|   Enum for calucate equity drawdown                              |
//+------------------------------------------------------------------+
enum ENUM_CALC_STATE
  {
   CALC_INIT,
   CALC_TICK,
   CALC_DEINIT
  };
//+------------------------------------------------------------------+
//|   deal result                                                    |
//+------------------------------------------------------------------+
enum deal_result
  {
   WIN=1,
   LOSS
  };
//+------------------------------------------------------------------+
//|   additional parameters                                          |
//+------------------------------------------------------------------+
enum ENUM_STATISTICS_PLUS
  {
   STAT_BALANCE=10000,
   STAT_EQUITY,
   STAT_AHPR,
   STAT_GHPR,
   STAT_Z_SCORE,
   STAT_LR_CORRELATION,
   STAT_LR_STANDARD_ERROR,
   STAT_AVG_PROFIT_TRADE,
   STAT_AVG_LOSS_TRADE,
   STAT_BALANCE_DD_ABSOLUTE
  };
//+------------------------------------------------------------------+
//|   CTradeStatistics                                               |
//+------------------------------------------------------------------+
class CTradeStatistics
  {
private:
   CDealInfo         m_deal;
   CArrayDouble      m_profit_data;    // Balance increment line
   CArrayDouble      m_balance_data;   // Balance line
   CArrayDouble      m_balance_line;   // Regression line
   string            m_err_msg;

   //---
   double            m_initial_deposit;
   double            m_withdrawal;
   int               m_deals;
   int               m_trades;

   double            m_profit_factor;

   double            m_profit;
   double            m_gross_profit;
   double            m_gross_loss;

   double            m_expected_payoff;

   double            m_balance_min;
   double            m_balance_dd;
   double            m_balance_dd_percent;
   double            m_balance_dd_relative;
   double            m_balance_dd_relative_percent;
   double            m_balance_dd_absolute;
   //---
   double            m_equity_min;
   double            m_equity_dd;
   double            m_equity_dd_percent;
   double            m_equity_dd_relative;
   double            m_equity_dd_relative_percent;
   double            m_equity_dd_absolute;
   //---
   int               m_short_trades;
   int               m_profit_short_trades;

   int               m_long_trades;
   int               m_profit_long_trades;

   int               m_profit_trades;
   double            m_profit_trades_percent;

   int               m_loss_trades;
   double            m_loss_trades_percent;

   //---
   int               m_profit_trades_avg_con;
   int               m_loss_trades_avg_con;

   //---
   double            m_larg_profit_trade;
   double            m_larg_loss_trade;

   //---
   double            m_con_profit_max;
   int               m_con_profit_max_trades;
   double            m_max_con_wins;
   int               m_max_con_profit_trades;

   double            m_con_loss_max;
   int               m_con_loss_max_trades;
   double            m_max_con_losses;
   int               m_max_con_loss_trades;

   //---
   double            m_recovery_factor;
   double            m_shape_ratio;
   double            m_min_margin_level;

   //---
   double            m_z_score;
   double            m_z_score_percent;

   double            m_sharpe_ratio;

   //---
   double            m_ghpr;
   double            m_ghpr_percent;

   double            m_ahpr;
   double            m_ahpr_percent;

   double            m_lr_correlation;
   double            m_lr_standard_error;

   //---
   int               m_series_count;
   int               m_wins_series_count;
   int               m_loss_series_count;

protected:
   bool              CalculateRL(CArrayDouble &data,CArrayDouble &line,double &Standard_Error,double &Correlation);
   void              CalcEquityDrawdown(bool finally);
   double            CalcZScorePercent(double z_score);

public:
   //--- main statistic parameters
   double            InitialDeposit(){return(m_initial_deposit);}
   double            Withdrawal(){return(m_withdrawal);}
   double            Profit(){return(m_profit);};
   double            GrossProfit(){return(m_gross_profit);}
   double            GrossLoss(){return(m_gross_loss);}
   //---
   double            LargestProfitTrade(){return(m_larg_profit_trade);}
   double            LargestLossTrade(){return(m_larg_loss_trade);};
   double            ConProfitMax(){return(m_con_profit_max);}
   int               ConProfitMaxTrades(){return(m_con_profit_max_trades);}
   double            MaxConWins(){return(m_max_con_wins);};
   int               MaxConProfitTrades(){return(m_max_con_profit_trades);}
   double            ConLossMax(){return(m_con_loss_max);}
   int               ConLossMaxTrades(){return(m_con_loss_max_trades);}
   double            MaxConLosses(){return(m_max_con_losses);}
   int               MaxConLossTrades(){return(m_max_con_loss_trades);}
   //---
   double            BalanceMin(){return(m_balance_min);};
   double            BalanceDD(){return(m_balance_dd);};
   double            BalanceDDPercent(){return(m_balance_dd_percent);};
   double            BalanceDDRelative(){return(m_balance_dd_relative);};
   double            BalanceDDRelativePercent(){return(m_balance_dd_relative_percent);};
   //---
   double            EquityMin(){return(m_equity_min);};
   double            EquityDD(){return(m_equity_dd);};
   double            EquityDDPercent(){return(m_equity_dd_percent);};
   double            EquityDDRelative(){return(m_equity_dd_relative);};
   double            EquityDDRelativePercent(){return(m_equity_dd_relative_percent);};
   //---
   double            ExpectedPayoff(){return(m_expected_payoff);}
   double            ProfitFactor(){return(m_profit_factor);}
   double            RecoveryFactor(){return(m_recovery_factor);}
   double            SharpeRatio(){return(m_sharpe_ratio);}
   double            MinMarginLevel(){return(m_min_margin_level);}
   //---
   int               Deals(){return(m_deals);}
   int               Trades(){return(m_trades);}
   int               ProfitTrades(){return(m_profit_trades);};
   int               LossTrades(){return(m_loss_trades);};
   int               ShortTrades(){return(m_short_trades);};
   int               LongTrades(){return(m_long_trades);};
   //---
   int               ProfitShortTrades(){return(m_profit_short_trades);}
   int               ProfitLongTrades(){return(m_profit_long_trades);}
   //---
   int               ProfitTradesAvgCon(){return(m_profit_trades_avg_con);}
   int               LossTradesAvgCon(){return(m_loss_trades_avg_con);}

   //---
   double            AHPR(){return(m_ahpr);}
   double            AHPRPercent(){return(m_ahpr_percent);}

   double            GHPR(){return(m_ghpr);}
   double            GHPRPercent(){return(m_ghpr_percent);}

   double            ZScore(){return(m_z_score);}
   double            ZScorePercent(){return(m_z_score_percent);}

   double            LRCorrelation(){return(m_lr_correlation);}
   double            LRStandardError(){return(m_lr_standard_error);}

   //--- general functions
   bool              Calculate(datetime time_start,datetime time_end,double initial_deposit);
   void              PrintStatistics();
   string            GetLastErrorString(){return(m_err_msg);};
   bool              CalculateEquityDD(ENUM_CALC_STATE state);
   double            Percent(double value,double divider);
   double            Divide(double value,double divider);
  };
//+------------------------------------------------------------------+
//|   GetPercent(value,divider) - result = value/diveder*100         |
//+------------------------------------------------------------------+
double CTradeStatistics::Percent(double value,double divider)
  {
   if(MathAbs(value)<=FLT_EPSILON)return(0);
   return(100*value/divider);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CTradeStatistics::Divide(double value,double divider)
  {
   if(MathAbs(value)<=FLT_EPSILON)return(0);
   return(value/divider);
  }
//+------------------------------------------------------------------+
//|   Calculate()                                                    |
//+------------------------------------------------------------------+
bool CTradeStatistics::Calculate(datetime time_start=0,datetime time_end=0,double initial_deposit=0.0)
  {
   m_err_msg="";
   if(time_end==0)time_end=TimeTradeServer();
   m_initial_deposit=initial_deposit;

//--- clear data
   m_withdrawal=0;
   m_profit=0;
   m_gross_profit=0;
   m_gross_loss=0;

   m_short_trades=0;
   m_larg_profit_trade=0;
   m_long_trades=0;
   m_larg_loss_trade=0;
   m_profit_short_trades=0;
   m_profit_long_trades=0;
//---
   m_larg_profit_trade=0;
   m_larg_loss_trade=0;

//---
   m_con_profit_max=0;
   m_con_profit_max_trades=0;
   m_con_loss_max=0;
   m_con_loss_max_trades=0;
   m_max_con_losses=0;
   m_max_con_loss_trades=0;
//---   
   m_balance_min=0.0;
   m_balance_dd_absolute=0;
   m_balance_dd=0;
   m_balance_dd_percent=0;
   m_balance_dd_relative=0;
   m_balance_dd_relative_percent=0;

//---
   m_expected_payoff=0;
   m_profit_factor=0;
   m_recovery_factor=0;
   m_sharpe_ratio=0;

   m_deals=0;
   m_trades=0;
   m_profit_trades=0;
   m_loss_trades=0;
   m_short_trades=0;
   m_long_trades=0;

//---
   m_series_count=0;
   m_wins_series_count=0;
   m_loss_series_count=0;
   m_profit_trades_avg_con=0;
   m_loss_trades_avg_con=0;

//--- calculation of data
   double min_peak = 0.0;
   double max_peak = 0.0;

   double balance=0;
   double profit=0;

   double sequential=0.0;
   int profit_length=0, loss_length=0;

   deal_result result;

//---
   m_balance_data.Clear();
   m_profit_data.Clear();

//--- try to get history
   int try=0;
   bool res=HistorySelect(time_start,time_end);
   if(!res && try<NUMBER_OF_TRY_GET_HISTORY)
     {
      Sleep(100);
      res=HistorySelect(time_start,time_end);
      try++;
     }
   if(!res){m_err_msg="Unable to get the trade history"; return(false);}

//--- calculation - main cycle
   int deals_total=HistoryDealsTotal();
   for(int i=0; i<deals_total; i++)
     {
      if(!m_deal.SelectByIndex(i)){m_err_msg="Error function SelectByIndex()"; return(false);}

      //+------------------------------------------------------------------+
      //|   DEAL_TYPE_BALANCE                                              |
      //+------------------------------------------------------------------+
      if(m_deal.DealType()==DEAL_TYPE_BALANCE)
        {
         //--- current balance
         profit=NormalizeDouble(m_deal.Profit()+m_deal.Swap(),2);
         balance=balance+profit;
         m_balance_data.Add(balance);


         if(min_peak == 0.0) min_peak = balance;
         if(max_peak == 0.0) max_peak = balance;

         //--- deposit funds
         if(profit>=0.0)
           {
            if(m_balance_min==0.0) m_balance_min=balance;

            if(initial_deposit==0.0)
               if(m_initial_deposit==0.0) m_initial_deposit=m_deal.Profit();// set initial deposit
           }
         //--- withdrawal
         else m_withdrawal-=m_deal.Profit();

        }

      if(m_deal.DealType()==DEAL_TYPE_BUY || m_deal.DealType()==DEAL_TYPE_SELL)
        {
         m_deals++; //--- number of transactions

         if(m_deal.Entry()==DEAL_ENTRY_OUT || m_deal.Entry()==DEAL_ENTRY_INOUT)
           {
            m_trades++; // number of trades

            profit=NormalizeDouble(m_deal.Profit()+m_deal.Swap()+m_deal.Commission(),2);
            m_profit_data.Add(profit);

            balance=balance+profit;
            m_balance_data.Add(balance);

            if(balance<m_balance_min) m_balance_min=balance;

            //+------------------------------------------------------------------+
            //|   Calucalte balance drawdown's                                   |
            //+------------------------------------------------------------------+
            if(min_peak == 0.0) min_peak = balance;
            if(max_peak == 0.0) max_peak = balance;

            double drawdown=max_peak-balance;
            double drawdown_percent=drawdown/max_peak*100.0;

            //--- price dd maximum
            if(drawdown>m_balance_dd)
              {
               m_balance_dd=drawdown;
               m_balance_dd_percent=drawdown_percent;
              }

            //--- relative dd maximum
            if(drawdown_percent>m_balance_dd_relative_percent)
              {
               m_balance_dd_relative_percent=drawdown_percent;
               m_balance_dd_relative=drawdown;
              }

            if(max_peak<balance) max_peak=balance;

            //+------------------------------------------------------------------+
            //|                                                                  |
            //+------------------------------------------------------------------+
            if(profit>=0.0)// positive transaction
              {
               //---
               m_profit_trades++;
               m_gross_profit+=profit;
               if(profit>m_larg_profit_trade) m_larg_profit_trade=profit;

               //--- if the previous series was not winning
               if(result!=WIN)
                 {
                  result=WIN;          // entered into a series of profitable trades
                  m_series_count++;      // increase the total number of series 
                  m_wins_series_count++; // increase the counter of winning series
                  profit_length=0;     // set the length of the current profitable series as zero
                  sequential=0.0;      // set the profit in the current series as zero
                 }

               sequential+=profit;              // accumulate profits in a series
               profit_length++;                   //  increase the length of the profitable series
               //---
               if(m_max_con_profit_trades<profit_length) // if the length of the current profitable series is more than the maximum fixed
                 {
                  m_max_con_profit_trades=profit_length;  // update a record about profitable long-time series
                  m_max_con_wins=sequential;       // update the amount of profit in it
                 }
               //---
               if(m_con_profit_max<sequential) //  if the profit of the current profitable series is more than the maximum fixed
                 {
                  m_con_profit_max = sequential;            // update the record about record profit in the profitable series
                  m_con_profit_max_trades = profit_length;  // update the length of the series for the most profitable series of wins
                 }

              }
            else
              {

               m_loss_trades++;
               m_gross_loss+=profit;
               if(profit<m_larg_loss_trade) m_larg_loss_trade=profit;

               //--- if the previous series was not losing
               if(result!=LOSS)
                 {
                  result=LOSS;         // entered into a series of losing trades
                  m_series_count++;      // increase the total number of series 
                  m_loss_series_count++; // increase the counter of losing series
                  loss_length=0;       // set the length of the current losing series as zero
                  sequential=0.0;      // set the loss in the current series as zero
                 }

               sequential+=profit;      // accumulate losses in series
               loss_length++;                     // increase the length of the losing series
               if(m_max_con_loss_trades<loss_length) // if the length of the current losing series is more than the maximum fixed
                 {
                  m_max_con_loss_trades=loss_length;     // update a record about losing long-time series
                  m_max_con_losses=sequential;         // update the amount of loss in it
                 }
               if(m_con_loss_max>sequential) // if the loss of the current losing series is more than the maximum fixed
                 {
                  m_con_loss_max=sequential;         // update the record about record loss in the losing series
                  m_con_loss_max_trades=loss_length;     // update the length of the series for the most losing series of losses
                 }
              }

            if(m_deal.DealType()==DEAL_TYPE_SELL)
              {
               if(profit>=0.0) m_profit_long_trades++;
               m_long_trades++;
              }

            if(m_deal.DealType()==DEAL_TYPE_BUY)
              {
               if(profit>=0.0) m_profit_short_trades++;
               m_short_trades++;
              }
           }
        }
     }

//+------------------------------------------------------------------+
//|   AHPR, GHPR, Sharpe_Ratio                                       |
//+------------------------------------------------------------------+
   m_ahpr=0;
   m_ahpr_percent=0;

   m_ghpr=0;
   m_ghpr_percent=0;

//---
   int limit=m_balance_data.Total();
   if(limit>1)// Little data
     {
      double hpr=0;
      double hpr2=0;

      double HPR[];
      ArrayResize(HPR,limit-1);
      for(int i=1; i<limit; i++)
        {
         if(m_balance_data.At(i)!=0.0)
           {
            HPR[i-1]=m_balance_data.At(i)/m_balance_data.At(i-1);
            m_ahpr+=HPR[i-1];
           }
        }

      m_ahpr=m_ahpr/(limit-1);
      m_ahpr_percent=(m_ahpr-1)*100;

      m_ghpr=MathPow(m_balance_data.At(m_balance_data.Total()-1)/m_initial_deposit,1.0/(m_balance_data.Total()-1));
      m_ghpr_percent=(m_ghpr-1)*100;

      //--- Sharpe_Ratio
      m_sharpe_ratio=0;
      if(limit>2)
        {
         double Std=0.0;
         double RiskFreeRate=0.0;
         for(int i=0; i<limit-2; i++)
           {
            Std+=(m_ahpr-HPR[i])*(m_ahpr-HPR[i]);
           }
         Std=MathPow(Std/(limit-2),0.5);

         m_sharpe_ratio=(m_ahpr -(1.0+RiskFreeRate))/Std;
        }
     }

//+------------------------------------------------------------------+
//|   Z-Score                                                        |
//+------------------------------------------------------------------+
   m_z_score=0.0;
   m_z_score_percent=0.0;
   long N=m_profit_data.Total();

   if(N>2)
     {
      long W = 0;
      long L = 0;
      long R = 0;
      deal_result outcome;

      for(int i=0; i<N; i++)
        {
         if(m_profit_data.At(i)>=0.0)
           {
            if(outcome!=WIN){outcome=WIN; R++;}
            W++;
           }
         else
           {
            if(outcome!=LOSS){outcome=LOSS; R++;}
            L++;
           }
        }
      double P=2.0*W*L;

      //--- check for division by zero
      if(MathAbs(MathSqrt((P*(P-N))/(N-1))) >= FLT_EPSILON)
        {
         m_z_score=(N*(R-0.5)-P)/MathSqrt((P*(P-N))/(N-1));
         m_z_score_percent=CalcZScorePercent(m_z_score)*100;
        }
     }

//+------------------------------------------------------------------+
//|   Other                                                          |
//+------------------------------------------------------------------+

//--- Total_Net_Profit
   m_profit=m_gross_profit+m_gross_loss;

//--- Profit Factor
   m_profit_factor=0.0;
   if(MathAbs(m_gross_loss)>FLT_EPSILON) m_profit_factor=MathAbs(m_gross_profit/m_gross_loss);

//--- 
   m_profit_trades_percent=0;
   m_loss_trades_percent=0;
   m_expected_payoff=0;
   if(m_trades>0)
     {
      m_expected_payoff=m_profit/m_trades;
      m_profit_trades_percent = (double)m_profit_trades/m_trades*100;
      m_loss_trades_percent   = (double)m_loss_trades/m_trades*100;
     }

   m_profit_trades_avg_con=0;
   if(m_wins_series_count>0) m_profit_trades_avg_con=(int)MathRound((double)m_profit_trades/m_wins_series_count);

   m_loss_trades_avg_con=0;
   if(m_loss_series_count>0) m_loss_trades_avg_con=(int)MathRound((double)m_loss_trades/m_loss_series_count);

   if(MathAbs(m_balance_dd)>FLT_EPSILON)
      m_recovery_factor=m_profit/m_balance_dd;

   CalculateRL(m_balance_data,m_balance_line,m_lr_standard_error,m_lr_correlation);

   return(true);
  }

//+------------------------------------------------------------------+
//|   Laplas array                                                   |
//+------------------------------------------------------------------+
const double Laplas[][2]=
  {
     {0.00,0.00000},{0.01,0.00798},{0.02,0.01596},{0.03,0.02393},{0.04,0.03191},{0.05,0.03988},
     {0.06,0.04784},{0.07,0.05581},{0.08,0.06376},{0.09,0.07171},{0.10,0.07966},{0.11,0.08759},
     {0.12,0.09552},{0.13,0.10348},{0.14,0.11134},{0.15,0.11924},{0.16,0.12712},{0.17,0.13499},
     {0.18,0.14285},{0.19,0.15069},{0.20,0.15852},{0.21,0.16633},{0.22,0.17413},{0.23,0.18191},
     {0.24,0.18967},{0.25,0.19741},{0.26,0.20514},{0.27,0.21284},{0.28,0.22052},{0.29,0.22818},
     {0.30,0.23582},{0.31,0.24344},{0.32,0.25103},{0.33,0.25860},{0.34,0.26614},{0.35,0.27366},
     {0.36,0.28115},{0.37,0.28862},{0.38,0.29605},{0.39,0.30346},{0.40,0.31084},{0.41,0.31819},
     {0.42,0.32552},{0.43,0.33280},{0.44,0.34006},{0.45,0.34729},{0.46,0.35448},{0.47,0.36164},
     {0.48,0.36877},{0.49,0.37587},{0.50,0.38292},{0.51,0.38995},{0.52,0.39694},{0.53,0.40389},
     {0.54,0.41080},{0.55,0.41768},{0.56,0.42452},{0.57,0.43132},{0.58,0.43809},{0.59,0.44481},
     {0.60,0.45149},{0.61,0.45814},{0.62,0.46474},{0.63,0.47131},{0.64,0.47783},{0.65,0.48431},
     {0.66,0.49075},{0.67,0.49714},{0.68,0.50350},{0.69,0.50981},{0.70,0.51607},{0.71,0.52230},
     {0.72,0.52848},{0.73,0.53461},{0.74,0.54070},{0.75,0.54675},{0.76,0.55275},{0.77,0.55870},
     {0.78,0.56461},{0.79,0.57047},{0.80,0.57629},{0.81,0.58206},{0.82,0.58778},{0.83,0.59346},
     {0.84,0.59909},{0.85,0.60468},{0.86,0.61021},{0.87,0.61570},{0.88,0.62114},{0.89,0.62653},
     {0.90,0.63188},{0.91,0.63718},{0.92,0.64243},{0.93,0.64763},{0.94,0.65278},{0.95,0.65789},
     {0.96,0.66294},{0.97,0.66795},{0.98,0.67291},{0.99,0.67783},{1.00,0.68269},{1.01,0.68750},
     {1.02,0.69227},{1.03,0.69699},{1.04,0.70166},{1.05,0.70628},{1.06,0.71086},{1.07,0.71538},
     {1.08,0.71986},{1.09,0.72429},{1.10,0.72867},{1.11,0.73300},{1.12,0.73729},{1.13,0.74152},
     {1.14,0.74571},{1.15,0.74986},{1.16,0.75395},{1.17,0.75800},{1.18,0.76200},{1.19,0.76595},
     {1.20,0.76986},{1.21,0.77372},{1.22,0.77754},{1.23,0.78130},{1.24,0.78502},{1.25,0.78870},
     {1.26,0.79233},{1.27,0.79592},{1.28,0.79945},{1.29,0.80295},{1.30,0.80640},{1.31,0.80980},
     {1.32,0.81316},{1.33,0.81648},{1.34,0.81975},{1.35,0.82298},{1.36,0.82617},{1.37,0.82931},
     {1.38,0.83241},{1.39,0.83547},{1.40,0.83849},{1.41,0.84146},{1.42,0.84439},{1.43,0.84728},
     {1.44,0.85013},{1.45,0.85294},{1.46,0.85571},{1.47,0.85844},{1.48,0.86113},{1.49,0.86378},
     {1.50,0.86639},{1.51,0.86696},{1.52,0.87149},{1.53,0.87398},{1.54,0.87644},{1.55,0.87886},
     {1.56,0.88124},{1.57,0.88358},{1.58,0.88589},{1.59,0.88817},{1.60,0.89040},{1.61,0.89260},
     {1.62,0.89477},{1.63,0.89690},{1.64,0.89899},{1.65,0.90106},{1.66,0.90309},{1.67,0.90508},
     {1.68,0.90704},{1.69,0.90897},{1.70,0.91087},{1.71,0.91273},{1.72,0.91457},{1.73,0.91637},
     {1.74,0.91814},{1.75,0.91988},{1.76,0.92159},{1.77,0.92327},{1.78,0.92492},{1.79,0.92655},
     {1.80,0.92814},{1.81,0.92970},{1.82,0.93124},{1.83,0.93275},{1.84,0.93423},{1.85,0.93569},
     {1.86,0.93711},{1.87,0.93852},{1.88,0.93989},{1.89,0.94124},{1.90,0.94257},{1.91,0.94387},
     {1.92,0.94514},{1.93,0.94639},{1.94,0.94762},{1.95,0.94882},{1.96,0.95000},{1.97,0.95116},
     {1.98,0.95230},{1.99,0.95341},{2.00,0.95450},{2.01,0.95557},{2.02,0.95662},{2.03,0.95764},
     {2.04,0.95865},{2.05,0.95964},{2.06,0.96060},{2.07,0.96155},{2.08,0.96247},{2.09,0.96338},
     {2.10,0.96427},{2.11,0.96514},{2.12,0.96599},{2.13,0.96683},{2.14,0.96765},{2.15,0.96844},
     {2.16,0.96923},{2.17,0.96999},{2.18,0.97074},{2.19,0.97148},{2.20,0.97219},{2.21,0.97289},
     {2.22,0.97358},{2.23,0.97425},{2.24,0.97491},{2.25,0.97555},{2.26,0.97618},{2.27,0.97679},
     {2.28,0.97739},{2.29,0.97798},{2.30,0.97855},{2.31,0.97911},{2.32,0.97966},{2.33,0.98019},
     {2.34,0.98072},{2.35,0.98123},{2.36,0.98172},{2.37,0.98221},{2.38,0.98269},{2.39,0.98315},
     {2.40,0.98360},{2.41,0.98405},{2.42,0.98448},{2.43,0.98490},{2.44,0.98531},{2.45,0.98571},
     {2.46,0.98611},{2.47,0.98649},{2.48,0.98686},{2.49,0.98723},{2.50,0.98758},{2.51,0.98793},
     {2.52,0.98826},{2.53,0.98859},{2.54,0.98891},{2.55,0.98923},{2.56,0.98953},{2.57,0.98983},
     {2.58,0.99012},{2.59,0.99040},{2.60,0.99068},{2.61,0.99095},{2.62,0.99121},{2.63,0.99146},
     {2.64,0.99171},{2.65,0.99195},{2.66,0.99219},{2.67,0.99241},{2.68,0.99263},{2.69,0.99285},
     {2.70,0.99307},{2.71,0.99327},{2.72,0.99347},{2.73,0.99367},{2.74,0.99386},{2.75,0.99404},
     {2.76,0.99422},{2.77,0.99439},{2.78,0.99456},{2.79,0.99473},{2.80,0.99489},{2.81,0.99505},
     {2.82,0.99520},{2.83,0.99535},{2.84,0.99549},{2.85,0.99563},{2.86,0.99576},{2.87,0.99590},
     {2.88,0.99602},{2.89,0.99615},{2.90,0.99627},{2.91,0.99639},{2.92,0.99650},{2.93,0.99661},
     {2.94,0.99672},{2.95,0.99682},{2.96,0.99692},{2.97,0.99702},{2.98,0.99712},{2.99,0.99721},
     {3.00,0.99730},{3.01,0.99739}
  };
//+------------------------------------------------------------------+
//|   CalcZScorePercent                                              |
//+------------------------------------------------------------------+
double CTradeStatistics::CalcZScorePercent(double z_score)
  {
   int total=ArrayRange(Laplas,0);
   double value=NormalizeDouble(MathAbs(z_score),2);

   if(value>Laplas[total-2][0]) return(Laplas[total-1][1]);

   for(int i=0;i<total;i++)
      if(Laplas[i][0]==value)return(Laplas[i][1]);

   return(0);
  }
//+------------------------------------------------------------------+
//|   PrintStatistics                                                |
//+------------------------------------------------------------------+
void CTradeStatistics::PrintStatistics()
  {

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_INITIAL_DEPOSIT),TesterStatistics(STAT_INITIAL_DEPOSIT),InitialDeposit());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_WITHDRAWAL),TesterStatistics(STAT_WITHDRAWAL),Withdrawal());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_PROFIT),TesterStatistics(STAT_PROFIT),Profit());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_GROSS_PROFIT),TesterStatistics(STAT_GROSS_PROFIT),GrossProfit());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_GROSS_LOSS),TesterStatistics(STAT_GROSS_LOSS),GrossLoss());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_MAX_PROFITTRADE),TesterStatistics(STAT_MAX_PROFITTRADE),LargestProfitTrade());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_MAX_LOSSTRADE),TesterStatistics(STAT_MAX_LOSSTRADE),LargestLossTrade());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_CONPROFITMAX),TesterStatistics(STAT_CONPROFITMAX),ConProfitMax());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_CONPROFITMAX_TRADES),TesterStatistics(STAT_CONPROFITMAX_TRADES),ConProfitMaxTrades());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_MAX_CONWINS),TesterStatistics(STAT_MAX_CONWINS),MaxConWins());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_MAX_CONPROFIT_TRADES),TesterStatistics(STAT_MAX_CONPROFIT_TRADES),MaxConProfitTrades());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_CONLOSSMAX),TesterStatistics(STAT_CONLOSSMAX),ConLossMax());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_CONLOSSMAX_TRADES),TesterStatistics(STAT_CONLOSSMAX_TRADES),ConLossMaxTrades());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_MAX_CONLOSSES),TesterStatistics(STAT_MAX_CONLOSSES),MaxConLosses());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_MAX_CONLOSS_TRADES),TesterStatistics(STAT_MAX_CONLOSS_TRADES),MaxConLossTrades());

//--- Balance
   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_BALANCEMIN),TesterStatistics(STAT_BALANCEMIN),BalanceMin());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_BALANCE_DD),TesterStatistics(STAT_BALANCE_DD),BalanceDD());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_BALANCEDD_PERCENT),TesterStatistics(STAT_BALANCEDD_PERCENT),BalanceDDPercent());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_BALANCE_DD_RELATIVE),TesterStatistics(STAT_BALANCE_DD_RELATIVE),BalanceDDRelative());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_BALANCE_DDREL_PERCENT),TesterStatistics(STAT_BALANCE_DDREL_PERCENT),BalanceDDRelativePercent());

//--- Equity
   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_EQUITYMIN),TesterStatistics(STAT_EQUITYMIN),EquityMin());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_EQUITY_DD),TesterStatistics(STAT_EQUITY_DD),EquityDD());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_EQUITYDD_PERCENT),TesterStatistics(STAT_EQUITYDD_PERCENT),EquityDDPercent());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_EQUITY_DD_RELATIVE),TesterStatistics(STAT_EQUITY_DD_RELATIVE),EquityDDRelative());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_EQUITY_DDREL_PERCENT),TesterStatistics(STAT_EQUITY_DDREL_PERCENT),EquityDDRelativePercent());

/*
   PrintFormat("%s: %.2f - %.2f",EnumToString(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_BALANCE),Balance);

   PrintFormat("%s: %.2f - %.2f",EnumToString(ACCOUNT_PROFIT),AccountInfoDouble(ACCOUNT_PROFIT),Profit);

   PrintFormat("%s: %.2f - %.2f",EnumToString(ACCOUNT_EQUITY),AccountInfoDouble(ACCOUNT_EQUITY),Equity);
*/

//---   
   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_EXPECTED_PAYOFF),TesterStatistics(STAT_EXPECTED_PAYOFF),ExpectedPayoff());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_PROFIT_FACTOR),TesterStatistics(STAT_PROFIT_FACTOR),ProfitFactor());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_RECOVERY_FACTOR),TesterStatistics(STAT_RECOVERY_FACTOR),RecoveryFactor());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_SHARPE_RATIO),TesterStatistics(STAT_SHARPE_RATIO),SharpeRatio());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_MIN_MARGINLEVEL),TesterStatistics(STAT_MIN_MARGINLEVEL),MinMarginLevel());

// PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_CUSTOM_ONTESTER),TesterStatistics(STAT_CUSTOM_ONTESTER),CustomOnTester());

//---
   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_DEALS),TesterStatistics(STAT_DEALS),Deals());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_TRADES),TesterStatistics(STAT_TRADES),Trades());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_PROFIT_TRADES),TesterStatistics(STAT_PROFIT_TRADES),ProfitTrades());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_LOSS_TRADES),TesterStatistics(STAT_LOSS_TRADES),LossTrades());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_SHORT_TRADES),TesterStatistics(STAT_SHORT_TRADES),ShortTrades());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_LONG_TRADES),TesterStatistics(STAT_LONG_TRADES),LongTrades());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_PROFIT_SHORTTRADES),TesterStatistics(STAT_PROFIT_SHORTTRADES),ProfitShortTrades());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_PROFIT_LONGTRADES),TesterStatistics(STAT_PROFIT_LONGTRADES),ProfitLongTrades());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_PROFITTRADES_AVGCON),TesterStatistics(STAT_PROFITTRADES_AVGCON),ProfitTradesAvgCon());

   PrintFormat("%s: %.0f - %.0f",EnumToString(STAT_LOSSTRADES_AVGCON),TesterStatistics(STAT_LOSSTRADES_AVGCON),LossTradesAvgCon());

//+------------------------------------------------------------------+
//|   Additional Parameetrs                                          |
//+------------------------------------------------------------------+
//--- GHPR
   PrintFormat("%s: %.4f(%.2f) - %.4f(%.2f)",EnumToString(STAT_GHPR),0,0,GHPR(),GHPRPercent());

//--- AHPR
   PrintFormat("%s: %.4f(%.2f) - %.4f(%.2f)",EnumToString(STAT_AHPR),0,0,AHPR(),AHPRPercent());

//--- Z SCORE
   PrintFormat("%s: %.2f(%.2f) - %.2f(%.2f)",EnumToString(STAT_Z_SCORE),0,0,ZScore(),ZScorePercent());

//--- LR
   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_LR_CORRELATION),0,LRCorrelation());

   PrintFormat("%s: %.2f - %.2f",EnumToString(STAT_LR_STANDARD_ERROR),0,LRStandardError());

  }
//+------------------------------------------------------------------+
//|   Caclualte equity drawdown                                      |
//+------------------------------------------------------------------+
bool CTradeStatistics::CalculateEquityDD(ENUM_CALC_STATE state)
  {
   switch(state)
     {
      case CALC_INIT:
         //--- reset the values to 0
         m_equity_min=AccountInfoDouble(ACCOUNT_EQUITY);
         m_equity_dd=0.0;
         m_equity_dd_percent=0.0;
         m_equity_dd_relative=0.0;
         m_equity_dd_relative_percent=0.0;
         m_min_margin_level=AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
         break;

      case CALC_TICK: CalcEquityDrawdown(false); break;

      case CALC_DEINIT: CalcEquityDrawdown(true); break;
     }

   return(true);
  }
//+------------------------------------------------------------------+
//|   CalcEquityDrawdown                                             |
//+------------------------------------------------------------------+
void  CTradeStatistics::CalcEquityDrawdown(bool finally)
  {

   static double maxpeak = 0.0;
   static double minpeak = 0.0;

   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<m_equity_min) m_equity_min=equity;

   if(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL)<m_min_margin_level)
      m_min_margin_level=AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   if(maxpeak == 0.0) maxpeak = equity;
   if(minpeak == 0.0) minpeak = equity;

//--- check of extremum condition
   if((maxpeak<equity) || (finally))
     {
      double drawdown=maxpeak-minpeak;
      double drawdown_percent=drawdown/maxpeak*100.0;

      if(m_equity_dd_relative_percent<drawdown_percent)
        {
         m_equity_dd_relative_percent=drawdown_percent;
         m_equity_dd_relative=drawdown;
        }

      if(m_equity_dd<drawdown)
        {
         m_equity_dd=drawdown;
         m_equity_dd_percent=drawdown_percent;
        }

      maxpeak = equity;
      minpeak = equity;
     }

   if(minpeak>equity) minpeak=equity;
  }
//+------------------------------------------------------------------+
//|   Calculate Regression Line                                      |
//+------------------------------------------------------------------+
bool CTradeStatistics::CalculateRL(CArrayDouble &data,CArrayDouble &line,double &Standard_Error,double &Correlation)
  {
   int total=data.Total();
   if(total<=2) return(true);

   double s1=0;
   double s2=0;
   double a1=0;
   double a2=0;
   double b1=0;
   double b2= total;

   for(int i=1; i<=total; i++)
     {
      s1 = s1 + data.At(i-1)*i;
      s2 = s2 + data.At(i-1);
      a1 = a1+i*i;
      a2 = a2+i;
     }

   b1=a2;

   double dif = a1*b2-a2*b1;
   double A   = (s1*b2-s2*b1) / dif;
   double B   = (a1*s2-a2*s1) / dif;

//--- sign 
   int sign=1;
   if(A<0.0)sign=-1;
// PrintFormat("A=%.2f B=%.2f",A,B);

   line.Clear();
   string str="";
   for(int i = 1; i<=total; i++)
     {
      str=str+StringFormat("| %i %.2f",i,A*i+B);
      line.Add(A*i+B);
     }
//Print(str);
//PrintFormat("A=%.5f B=%.5f",A,B);

//--- LR Standard error
   Standard_Error=0;
   double sum=0;
   for(int i=0; i<total; i++)
     {

      double delta=MathAbs(data.At(i)-line.At(i));
      sum=sum+delta*delta;
      //PrintFormat("B=%.2f L=%.2f D=%.2f",m_balance_data.At(i),BalanceLine.At(i),delta);
     }
   Standard_Error=MathSqrt(sum/(total-2));

// PrintFormat("Lr_Standard_Error = %.2f",Lr_Standard_Error);

//--- LR Correlation
   double avg_balance=0;
   double avg_line=0;
   for(int i=0; i<total; i++)
     {
      avg_balance=avg_balance+data.At(i);
      avg_line=avg_line+line.At(i);
     }

//--- Average values
   avg_balance = avg_balance / total;
   avg_line    = avg_line / total;

//PrintFormat("avg_balance = %.2f avg_line=%.2f",avg_balance,avg_line);

//---New series
   double cov=0;// covariance
   double Sx=0;
   double Sy=0;

   for(int i=0; i<total; i++)
     {
      cov = cov +(data.At(i)-avg_balance) *(line.At(i)-avg_line);
      Sx  = Sx + MathPow(data.At(i) - avg_balance, 2);
      Sy  = Sy + MathPow(line.At(i) - avg_line, 2);
     }
   cov = (cov / total);
   Sx  = MathSqrt(Sx / total);
   Sy  = MathSqrt(Sy / total);

// PrintFormat("cov = %.2f Sx=%.2f Sy=%.2f",cov,Sx,Sy);
   Correlation=sign*cov/(Sx*Sy);

   return(0);
  }
//+------------------------------------------------------------------+
