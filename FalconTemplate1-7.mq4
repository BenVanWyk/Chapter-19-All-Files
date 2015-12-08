//+------------------------------------------------------------------+
//|                                          Falcon EA Template v1.7
//|                                        Copyright 2015,Lucas Liew 
//|                                  lucas@blackalgotechnologies.com 
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Black Algo Technologies Pte Ltd"
#property link      "lucas@blackalgotechnologies.com"

/* 

Falcon v1.7: 
- Included Hidden Trailing Stops

*/

//+------------------------------------------------------------------+
//| Setup                                               
//+------------------------------------------------------------------+
extern string  Header1 = "----------Trading Rules Variables-----------";
extern int     FastMAPeriod=10;
extern int     SlowMAPeriod=40;

extern string  Header2 = "----------Position Sizing Settings-----------";
extern string  Lot_explanation = "If IsSizingOn = true, Lots variable will be ignored";
extern double  Lots = 0;
extern bool    IsSizingOn = True;
extern double  Risk = 1; // Risk per trade (in percentage)

extern string  Header3 = "----------TP & SL Settings-----------";

extern bool    UseFixedStopLoss = True; // If this is false and IsSizingOn = True, sizing algo will not be able to calculate correct lot size. 
extern double  FixedStopLoss = 40; // Hard Stop in Pips. Will be overridden if vol-based SL is true 
extern bool    IsVolatilityStopOn = False;
extern double  VolBasedSLMultiplier = 0; // Stop Loss Amount in units of Volatility

extern bool    UseFixedTakeProfit = False;
extern double  FixedTakeProfit = 0; // Hard Take Profit in Pips. Will be overridden if vol-based TP is true 
extern bool    IsVolatilityTakeProfitOn = False; 
extern double  VolBasedTPMultiplier = 0; // Take Profit Amount in units of Volatility

extern string  Header4 = "----------Hidden TP & SL Settings-----------";

extern bool    UseHiddenStopLoss = False;
extern double  FixedStopLoss_Hidden = 0; // In Pips. Will be overridden if hidden vol-based SL is true 
extern bool    IsVolatilityStopLossOn_Hidden = False; 
extern double  VolBasedSLMultiplier_Hidden = 0; // Stop Loss Amount in units of Volatility

extern bool    UseHiddenTakeProfit = False;
extern double  FixedTakeProfit_Hidden = 0; // In Pips. Will be overridden if hidden vol-based TP is true 
extern bool    IsVolatilityTakeProfitOn_Hidden = False; 
extern double  VolBasedTPMultiplier_Hidden = 0; // Take Profit Amount in units of Volatility

extern string  Header5 = "----------Breakeven Stops Settings-----------";
extern bool    UseBreakevenStops = False;
extern double  BreakevenBuffer = 0; // In pips

extern string  Header6 = "----------Hidden Breakeven Stops Settings-----------";
extern bool    UseHiddenBreakevenStops = False;
extern double  BreakevenBuffer_Hidden = 0; // In pips

extern string  Header7 = "----------Trailing Stops Settings-----------";
extern bool    UseTrailingStops = False;
extern double  TrailingStopDistance = 0; // In pips
extern double  TrailingStopBuffer = 0; // In pips

extern string  Header8 = "----------Hidden Trailing Stops Settings-----------";
extern bool    UseHiddenTrailingStops = True;
extern double  TrailingStopDistance_Hidden = 40; // In pips
extern double  TrailingStopBuffer_Hidden = 10; // In pips

extern string  Header9 = "----------Volatility Measurement Settings-----------";
extern int     atr_period = 14;

extern string  Header10 = "----------Max Orders-----------";
extern int     MaxPositionsAllowed = 1;

extern string  Header11 = "----------Set Max Loss Limit-----------";
extern bool    IsLossLimitActivated = False;
extern double  LossLimitPercent = 50; 

extern string  Header12 = "----------EA General Settings-----------";
extern int     MagicNumber = 12345;
extern int     Slippage = 3; // In Pips
extern bool    IsECNbroker = false; // Is your broker an ECN
extern bool    OnJournaling = true; // Add EA updates in the Journal Tab

string  InternalHeader1="----------Errors Handling Settings-----------";
int     RetryInterval=100; // Pause Time before next retry (in milliseconds)
int     MaxRetriesPerTick=10;

string  InternalHeader2="----------Service Variables-----------";

double Stop, Take;
double StopHidden, TakeHidden;
double P, YenPairAdjustFactor;
double myATR;
double FastMA1, SlowMA1;
int CrossTriggered;
int OrderNumber;
double HiddenSLList[][2]; // First dimension is for position ticket numbers, second is for the SL Levels
double HiddenTPList[][2]; // First dimension is for position ticket numbers, second is for the TP Levels
double HiddenBEList[]; // First dimension is for position ticket numbers
double HiddenTrailingList[][2]; // First dimension is for position ticket numbers, second is for the hidden trailing stop levels



//+------------------------------------------------------------------+
//| End of Setup                                          
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert Initialization                                    
//+------------------------------------------------------------------+
int init()
  {
      P = GetP(); // To account for 5 digit brokers. Used to convert pips to decimal place
      YenPairAdjustFactor = GetYenAdjustFactor(); // Adjust for YenPair

      //----------(Hidden) TP, SL and Breakeven Stops Variables-----------  

      // If EA disconnects abruptly and there are open positions from this EA, records form these arrays will be gone.
      if (UseHiddenStopLoss) ArrayResize(HiddenSLList,MaxPositionsAllowed,0);
      if (UseHiddenTakeProfit) ArrayResize(HiddenTPList,MaxPositionsAllowed,0); 
      if (UseHiddenBreakevenStops) ArrayResize(HiddenBEList,MaxPositionsAllowed,0); 
      if (UseHiddenTrailingStops) ArrayResize(HiddenTrailingList,MaxPositionsAllowed,0);
            
      start();
   return(0);
  }
//+------------------------------------------------------------------+
//| End of Expert Initialization                            
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert Deinitialization                                  
//+------------------------------------------------------------------+
int deinit()
  {
//----

//----
   return(0);
  }
//+------------------------------------------------------------------+
//| End of Expert Deinitialization                          
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert start                                             
//+------------------------------------------------------------------+
int start()
  {
      
      //----------Variables to be Refreshed-----------
      
      OrderNumber = 0; // OrderNumber used in Entry Rules

      //----------Entry & Exit Variables-----------
      
      FastMA1=iMA(Symbol(),Period(),FastMAPeriod,0, MODE_SMA, PRICE_CLOSE,1); // Shift 1
      SlowMA1=iMA(Symbol(),Period(),SlowMAPeriod,0, MODE_SMA, PRICE_CLOSE,1); // Shift 1

      CrossTriggered = Crossed(FastMA1, SlowMA1);
      
      //----------TP, SL, Breakeven and Trailing Stops Variables-----------
      
      myATR = iATR(NULL,Period(),atr_period,1);
      
      if(UseFixedStopLoss == False) {
         Stop = 0;
      }  else {
         Stop=VolBasedStopLoss(IsVolatilityStopOn, FixedStopLoss, myATR, VolBasedSLMultiplier, P);
      }
      
      if(UseFixedTakeProfit == False) {
         Take = 0;
      }  else {
         Take=VolBasedTakeProfit(IsVolatilityTakeProfitOn, FixedTakeProfit, myATR, VolBasedTPMultiplier, P);
      }

      if (UseBreakevenStops) BreakevenStopAll(OnJournaling, RetryInterval, BreakevenBuffer, MagicNumber, P);
      if (UseTrailingStops) TrailingStopAll(OnJournaling, TrailingStopDistance, TrailingStopBuffer, RetryInterval, MagicNumber, P);
      
      //----------(Hidden) TP, SL, Breakeven and Trailing Stops Variables-----------  
      
      if (UseHiddenStopLoss)   TriggerStopLossHidden(OnJournaling, RetryInterval, MagicNumber, Slippage, P);      
      if (UseHiddenTakeProfit)   TriggerTakeProfitHidden(OnJournaling, RetryInterval, MagicNumber, Slippage, P);
      if (UseHiddenBreakevenStops) {
         UpdateHiddenBEList(OnJournaling, RetryInterval, MagicNumber);
         SetAndTriggerBEHidden(OnJournaling, BreakevenBuffer, MagicNumber, Slippage , P, RetryInterval);
      }
      if (UseHiddenTrailingStops) {
         UpdateHiddenTrailingList(OnJournaling, RetryInterval, MagicNumber);
         SetAndTriggerHiddenTrailing(OnJournaling, TrailingStopDistance_Hidden, TrailingStopBuffer_Hidden, Slippage, RetryInterval, MagicNumber, P);
      }
            
      //----------Exit Rules (All Opened Positions)-----------
      
      if(CountPosOrders(MagicNumber, OP_BUY)>=1 && ExitSignal(CrossTriggered)==1){ // Close Long Positions
         //CloseOrderPosition(OP_BUY, OnJournaling, MagicNumber, Slippage, P, RetryInterval); 
         
      }
      if(CountPosOrders(MagicNumber, OP_SELL)>=1 && ExitSignal(CrossTriggered)==2){ // Close Short Positions
         //CloseOrderPosition(OP_SELL, OnJournaling, MagicNumber, Slippage, P, RetryInterval);
      } 

      //----------Entry Rules (Market and Pending) -----------
      
   if(IsLossLimitBreached(IsLossLimitActivated, LossLimitPercent, OnJournaling, EntrySignal(CrossTriggered)) == False)
   if(IsMaxPositionsReached(MaxPositionsAllowed, MagicNumber, OnJournaling) == False){
      if(EntrySignal(CrossTriggered)==1){ // Open Long Positions
         OrderNumber = OpenPositionMarket(OP_BUY, GetLot(IsSizingOn, Lots, Risk, YenPairAdjustFactor, Stop, P), Stop, Take, MagicNumber, Slippage, OnJournaling, P, IsECNbroker, MaxRetriesPerTick, RetryInterval);
         
         // Set Stop Loss value for Hidden SL
         if (UseHiddenStopLoss) SetStopLossHidden(OnJournaling, IsVolatilityStopLossOn_Hidden, FixedStopLoss_Hidden, myATR, VolBasedSLMultiplier_Hidden, P, OrderNumber);  
        
         // Set Take Profit value for Hidden TP
         if (UseHiddenTakeProfit) SetTakeProfitHidden(OnJournaling, IsVolatilityTakeProfitOn_Hidden, FixedTakeProfit_Hidden, myATR, VolBasedTPMultiplier_Hidden, P, OrderNumber);  
        
        
        }

      if(EntrySignal(CrossTriggered)==2){ // Open Short Positions
         OrderNumber = OpenPositionMarket(OP_SELL, GetLot(IsSizingOn, Lots, Risk, YenPairAdjustFactor, Stop, P), Stop, Take, MagicNumber, Slippage, OnJournaling, P, IsECNbroker, MaxRetriesPerTick, RetryInterval);
         
         // Set Stop Loss value for Hidden SL
         if (UseHiddenStopLoss) SetStopLossHidden(OnJournaling, IsVolatilityStopLossOn_Hidden, FixedStopLoss_Hidden, myATR, VolBasedSLMultiplier_Hidden, P, OrderNumber);  
        
         // Set Take Profit value for Hidden TP
         if (UseHiddenTakeProfit) SetTakeProfitHidden(OnJournaling, IsVolatilityTakeProfitOn_Hidden, FixedTakeProfit_Hidden, myATR, VolBasedTPMultiplier_Hidden, P, OrderNumber);  
        
        }
   }

      //----------Pending Order Management-----------
   /*
        Not Applicable (See Desiree for example of pending order rules).
   */
      

//----
   return(0);
  }
//+------------------------------------------------------------------+
//| End of expert start function                                     |
//+------------------------------------------------------------------+

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//|                     FUNCTIONS LIBRARY                                   
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

/*

Content:
1) EntrySignal
2) ExitSignal
3) GetLot
4) CheckLot
5) CountPosOrders
6) IsMaxPositionsReached
7) OpenPositionMarket
8) OpenPositionPending
9) CloseOrderPosition
10) GetP
11) GetYenAdjustFactor
12) VolBasedStopLoss
13) VolBasedTakeProfit
14) Crossed
15) isLossLimitedBreached
16) SetStopLossHidden
17) TriggerStopLossHidden
18) SetTakeProfitHidden
19) TriggerTakeProfitHidden
20) BreakevenStopAll
21) UpdateHiddenBEList
22) SetAndTriggerBEHidden
23) TrailingStopAll
24) UpdateHiddenTrailingList
25) SetAndTriggerHiddenTrailing
26) HandleTradingEnvironment
27) GetErrorDescription

*/



//+------------------------------------------------------------------+
//| ENTRY SIGNAL                                                     |
//+------------------------------------------------------------------+
int EntrySignal(int CrossOccurred){
// Type: Customisable 
// Modify this function to suit your trading robot

// This function checks for entry signals

   int   entryOutput=0;

   if(CrossOccurred == 1){
      entryOutput=1; // Return 1 for Buy Signals
   }

   if(CrossOccurred == 2){
      entryOutput=2; // Return 2 for Short Signals
   }
     
   return(entryOutput); 
  }

//+------------------------------------------------------------------+
//| End of ENTRY SIGNAL                                              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Exit SIGNAL                                                      |
//+------------------------------------------------------------------+
int ExitSignal(int CrossOccurred){
// Type: Customisable 
// Modify this function to suit your trading robot

// This function checks for exit signals

   int   ExitOutput=0;

   if(CrossOccurred == 2)
     {
      ExitOutput=1; // Close Long Positions
     }

   if(CrossOccurred == 1)
     {
      ExitOutput=2; // Close Short Positions
     }

   return(ExitOutput); 
  }

//+------------------------------------------------------------------+
//| End of Exit SIGNAL                                               
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Position Sizing Algo               
//+------------------------------------------------------------------+
// Type: Customisable 
// Modify this function to suit your trading robot

// This is our sizing algorithm
   
double GetLot(bool IsSizingOnTrigger,double FixedLots, double RiskPerTrade, int YenAdjustment, double STOP, int K) {
   
   double output;
      
   if (IsSizingOnTrigger == true) {
      output = RiskPerTrade * 0.01 * AccountBalance() / (MarketInfo(Symbol(),MODE_LOTSIZE) * MarketInfo(Symbol(),MODE_TICKVALUE) * STOP * K * Point); // Sizing Algo based on account size
      output = output * YenAdjustment; // Adjust for Yen Pairs
   } else {
      output = FixedLots;
   }
   output = NormalizeDouble(output, 2); // Round to 2 decimal place
   return(output);
}
   
//+------------------------------------------------------------------+
//| End of Position Sizing Algo               
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CHECK LOT
//+------------------------------------------------------------------+
double CheckLot(double Lot, bool Journaling){
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function checks if our Lots to be trade satisfies any broker limitations

   double LotToOpen=0;
   LotToOpen=NormalizeDouble(Lot,2);
   LotToOpen=MathFloor(LotToOpen/MarketInfo(Symbol(),MODE_LOTSTEP))*MarketInfo(Symbol(),MODE_LOTSTEP);
   
   if(LotToOpen<MarketInfo(Symbol(),MODE_MINLOT))LotToOpen=MarketInfo(Symbol(),MODE_MINLOT);
   if(LotToOpen>MarketInfo(Symbol(),MODE_MAXLOT))LotToOpen=MarketInfo(Symbol(),MODE_MAXLOT);
   LotToOpen=NormalizeDouble(LotToOpen,2);
   
   if(Journaling && LotToOpen!=Lot)Print("EA Journaling: Trading Lot has been changed by CheckLot function. Requested lot: "+Lot+". Lot to open: "+LotToOpen);
   
   return(LotToOpen);
  }
//+------------------------------------------------------------------+
//| End of CHECK LOT
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| COUNT POSITIONS 
//+------------------------------------------------------------------+
int CountPosOrders(int Magic, int TYPE){
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function counts number of positions/orders of OrderType TYPE

   int Orders=0;
   for(int i=0; i<OrdersTotal(); i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
         Orders++;
     }
   return(Orders);
   
  }
//+------------------------------------------------------------------+
//| End of COUNT POSITIONS
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| MAX ORDERS                                              
//+------------------------------------------------------------------+
bool IsMaxPositionsReached(int MaxPositions, int Magic, bool Journaling){   
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function checks the number of positions we are holding against the maximum allowed 

      int result = False;
      if (CountPosOrders(Magic, OP_BUY) + CountPosOrders(Magic, OP_SELL) > MaxPositions) {
         result=True;
         if(Journaling)Print("Max Orders Exceeded");
      } else if (CountPosOrders(Magic, OP_BUY) + CountPosOrders(Magic, OP_SELL) == MaxPositions) {
         result=True;
      }
      
      return(result);
      
/* Definitions: Position vs Orders
   
   Position describes an opened trade
   Order is a pending trade
   
   How to use in a sentence: Jim has 5 buy limit orders pending 10 minutes ago. The market just crashed. The orders were executed and he has 5 losing positions now lol.

*/
   }
//+------------------------------------------------------------------+
//| End of MAX ORDERS                                                
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| OPEN FROM MARKET
//+------------------------------------------------------------------+
int OpenPositionMarket(int TYPE, double LOT, double SL, double TP, int Magic, int Slip, bool Journaling, int K, bool ECN, int Max_Retries_Per_Tick, int Retry_Interval){
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function submits new orders

   int tries=0;
   string symbol=Symbol();
   int cmd=TYPE;
   double volume=CheckLot(LOT, Journaling);
   if(MarketInfo(symbol,MODE_MARGINREQUIRED)*volume>AccountFreeMargin())
     {
      Print("Can not open a trade. Not enough free margin to open "+volume+" on "+symbol);
      return(-1);
     }
   int slippage=Slip*K; // Slippage is in points. 1 point = 0.0001 on 4 digit broker and 0.00001 on a 5 digit broker
   string comment=" " + TYPE + "(#" + Magic + ")";
   int magic=Magic;
   datetime expiration=0;
   color arrow_color=0;if(TYPE==OP_BUY)arrow_color=Blue;if(TYPE==OP_SELL)arrow_color=Green;
   double stoploss=0;
   double takeprofit=0;
   double initTP = TP;
   double initSL = SL;
   int Ticket=-1;
   double price=0;
   if(!ECN)
     {
      while(tries<Max_Retries_Per_Tick) // Edits stops and take profits before the market order is placed
        {
         RefreshRates();
         if(TYPE==OP_BUY)price=Ask;if(TYPE==OP_SELL)price=Bid;
         
         // Sets Take Profits and Stop Loss. Check against Stop Level Limitations.
         if(TYPE==OP_BUY && SL!=0)
           {
            stoploss=NormalizeDouble(Ask-SL*K*Point,Digits);
            if(Bid-stoploss<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               stoploss=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from " + initSL + " to " + MarketInfo(Symbol(),MODE_STOPLEVEL)/K + " pips");
            }
           }
         if(TYPE==OP_SELL && SL!=0)
           {
            stoploss=NormalizeDouble(Bid+SL*K*Point,Digits);
            if(stoploss-Ask<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               stoploss=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from " + initSL + " to " + MarketInfo(Symbol(),MODE_STOPLEVEL)/K + " pips");
            }
           }
         if(TYPE==OP_BUY && TP!=0)
           {
            takeprofit=NormalizeDouble(Ask+TP*K*Point,Digits);
            if(takeprofit-Bid<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               takeprofit=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from " + initTP + " to " + MarketInfo(Symbol(),MODE_STOPLEVEL)/K + " pips");
            }
           }
         if(TYPE==OP_SELL && TP!=0)
           {
            takeprofit=NormalizeDouble(Bid-TP*K*Point,Digits);
            if(Ask-takeprofit<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               takeprofit=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from " + initTP + " to " + MarketInfo(Symbol(),MODE_STOPLEVEL)/K + " pips");
            }
           }
         if(Journaling)Print("EA Journaling: Trying to place a market order...");
         HandleTradingEnvironment(Journaling, Retry_Interval);
         Ticket=OrderSend(symbol,cmd,volume,price,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);
         if(Ticket>0)break;
         tries++;
        }
     }
   if(ECN) // Edits stops and take profits after the market order is placed
     {
         HandleTradingEnvironment(Journaling, Retry_Interval);
         if(TYPE==OP_BUY)price=Ask;if(TYPE==OP_SELL)price=Bid;
         if(Journaling)Print("EA Journaling: Trying to place a market order...");
         Ticket=OrderSend(symbol,cmd,volume,price,slippage,0,0,comment,magic,expiration,arrow_color);
         if(Ticket>0)
      if(Ticket>0 && OrderSelect(Ticket,SELECT_BY_TICKET)==true && (SL!=0 || TP!=0))
        {
        // Sets Take Profits and Stop Loss. Check against Stop Level Limitations.
         if(TYPE==OP_BUY && SL!=0)
           {
            stoploss=NormalizeDouble(OrderOpenPrice()-SL*K*Point,Digits);
            if(Bid-stoploss<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               stoploss=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from " + initSL + " to " + (OrderOpenPrice()-stoploss)/(K*Point) + " pips");
            }
           }
         if(TYPE==OP_SELL && SL!=0)
           {
            stoploss=NormalizeDouble(OrderOpenPrice()+SL*K*Point,Digits);
            if(stoploss-Ask<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               stoploss=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from " + initSL + " to " + (stoploss-OrderOpenPrice())/(K*Point) + " pips");
            }
           }
         if(TYPE==OP_BUY && TP!=0)
           {
            takeprofit=NormalizeDouble(OrderOpenPrice()+TP*K*Point,Digits);
            if(takeprofit-Bid<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               takeprofit=NormalizeDouble(Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from " + initTP + " to " + (takeprofit-OrderOpenPrice())/(K*Point) + " pips");
            }
           }
         if(TYPE==OP_SELL && TP!=0)
           {
            takeprofit=NormalizeDouble(OrderOpenPrice()-TP*K*Point,Digits);
            if(Ask-takeprofit<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               takeprofit=NormalizeDouble(Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from " + initTP + " to " + (OrderOpenPrice()-takeprofit)/(K*Point) + " pips");
            }
           }
         bool ModifyOpen=false;
         while(!ModifyOpen)
           {
            HandleTradingEnvironment(Journaling, Retry_Interval);
            ModifyOpen=OrderModify(Ticket,OrderOpenPrice(),stoploss,takeprofit,expiration,arrow_color);
            if(Journaling && !ModifyOpen)Print("EA Journaling: Take Profit and Stop Loss not set. Error Description: "+GetErrorDescription(GetLastError()));
           }
        }
     }
   if(Journaling && Ticket<0)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
   if(Journaling && Ticket>0){
      Print("EA Journaling: Order successfully placed. Ticket: "+Ticket);
   }
   return(Ticket);
  }
//+------------------------------------------------------------------+
//| End of OPEN FROM MARKET   
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| OPEN PENDING ORDERS
//+------------------------------------------------------------------+
int OpenPositionPending(int TYPE, double OpenPrice, datetime expiration, double LOT, double SL, double TP, int Magic, int Slip, bool Journaling, int K, bool ECN, int Max_Retries_Per_Tick, int Retry_Interval){
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function submits new pending orders
   OpenPrice = NormalizeDouble(OpenPrice, Digits);
   int tries=0;
   string symbol=Symbol();
   int cmd=TYPE;
   double volume=CheckLot(LOT, Journaling);
   if(MarketInfo(symbol,MODE_MARGINREQUIRED)*volume>AccountFreeMargin())
     {
      Print("Can not open a trade. Not enough free margin to open "+volume+" on "+symbol);
      return(-1);
     }
   int slippage=Slip*K; // Slippage is in points. 1 point = 0.0001 on 4 digit broker and 0.00001 on a 5 digit broker
   string comment=" " + TYPE + "(#" + Magic + ")";
   int magic=Magic;
   color arrow_color=0;if(TYPE==OP_BUYLIMIT || TYPE==OP_BUYSTOP)arrow_color=Blue;if(TYPE==OP_SELLLIMIT || TYPE==OP_SELLSTOP)arrow_color=Green;
   double stoploss=0;
   double takeprofit=0;
   double initTP = TP;
   double initSL = SL;
   int Ticket=-1;
   double price=0;

      while(tries<Max_Retries_Per_Tick) // Edits stops and take profits before the market order is placed
        {
         RefreshRates();
         
         // We are able to send in TP and SL when we open our orders even if we are using ECN brokers
         
         // Sets Take Profits and Stop Loss. Check against Stop Level Limitations.
         if((TYPE==OP_BUYLIMIT || TYPE==OP_BUYSTOP) && SL!=0)
           {
            stoploss=NormalizeDouble(OpenPrice-SL*K*Point,Digits);
            if(OpenPrice-stoploss<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               stoploss=NormalizeDouble(OpenPrice-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from " + initSL + " to " + (OpenPrice-stoploss)/(K*Point) + " pips");
            }
           }
         if((TYPE==OP_BUYLIMIT || TYPE==OP_BUYSTOP) && TP!=0)
           {
            takeprofit=NormalizeDouble(OpenPrice+TP*K*Point,Digits);
            if(takeprofit-OpenPrice<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               takeprofit=NormalizeDouble(OpenPrice+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from " + initTP + " to " + (takeprofit-OpenPrice)/(K*Point) + " pips");
            }
           }
         if((TYPE==OP_SELLLIMIT || TYPE==OP_SELLSTOP) && SL!=0)
           {
            stoploss=NormalizeDouble(OpenPrice+SL*K*Point,Digits);
            if(stoploss-OpenPrice<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               stoploss=NormalizeDouble(OpenPrice+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Stop Loss changed from " + initSL + " to " + (OpenPrice-stoploss)/(K*Point) + " pips");
            }
           }
         if((TYPE==OP_SELLLIMIT || TYPE==OP_SELLSTOP) && TP!=0)
           {
            takeprofit=NormalizeDouble(OpenPrice-TP*K*Point,Digits);
            if(OpenPrice-takeprofit<=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point) {
               takeprofit=NormalizeDouble(OpenPrice-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point,Digits);
               if(Journaling)Print("EA Journaling: Take Profit changed from " + initTP + " to " + (OrderOpenPrice()-stoploss)/(K*Point) + " pips");
            }
           }
         if(Journaling)Print("EA Journaling: Trying to place a pending order...");
         HandleTradingEnvironment(Journaling, Retry_Interval);
         
         //Note: We did not modify Open Price if it breaches the Stop Level Limitations as Open Prices are sensitive and important. It is unsafe to change it automatically.
         Ticket=OrderSend(symbol,cmd,volume,OpenPrice,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);
         if(Ticket>0)break;
         tries++;
        }
     
   if(Journaling && Ticket<0)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
   if(Journaling && Ticket>0){
      Print("EA Journaling: Order successfully placed. Ticket: "+Ticket);
   }
   return(Ticket);
  }
//+------------------------------------------------------------------+
//| End of OPEN PENDING ORDERS 
//+------------------------------------------------------------------+ 
//+------------------------------------------------------------------+
//| CLOSE/DELETE ORDERS AND POSITIONS
//+------------------------------------------------------------------+
bool CloseOrderPosition(int TYPE, bool Journaling, int Magic, int Slip , int K, int Retry_Interval){
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function closes all positions of type TYPE or Deletes pending orders of type TYPE
   int ordersPos = OrdersTotal();
   
   for(int i=ordersPos-1; i >= 0; i--)
     {
      // Note: Once pending orders become positions, OP_BUYLIMIT AND OP_BUYSTOP becomes OP_BUY, OP_SELLLIMIT and OP_SELLSTOP becomes OP_SELL
      if(TYPE==OP_BUY || TYPE==OP_SELL)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
           {
            bool Closing=false;
            double Price=0;
            color arrow_color=0;if(TYPE==OP_BUY)arrow_color=Blue;if(TYPE==OP_SELL)arrow_color=Green;
            if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, RetryInterval);
            if(TYPE==OP_BUY)Price=Bid; if(TYPE==OP_SELL)Price=Ask;
            Closing=OrderClose(OrderTicket(),OrderLots(),Price,Slip*K,arrow_color);
            if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Closing)Print("EA Journaling: Position successfully closed.");
           }
        }
      else
        {
         bool Delete=false;
         if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic && OrderType()==TYPE)
           {
            if(Journaling)Print("EA Journaling: Trying to delete order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, RetryInterval);
            Delete=OrderDelete(OrderTicket(),CLR_NONE);
            if(Journaling && !Delete)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Delete)Print("EA Journaling: Order successfully deleted.");
           }
        }
     }
   if(CountPosOrders(Magic, TYPE)==0)return(true); else return(false);
  }
//+------------------------------------------------------------------+
//| End of CLOSE/DELETE ORDERS AND POSITIONS 
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check for 4/5 Digits Broker              
//+------------------------------------------------------------------+ 
int GetP() {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function returns P, which is used for converting pips to decimals/points

   int output;
   if(Digits == 5 || Digits == 3) output = 10;else output = 1; 
   return(output);

/* Some definitions: Pips vs Point

1 pip = 0.0001 on a 4 digit broker and 0.00010 on a 5 digit broker
1 point = 0.0001 on 4 digit broker and 0.00001 on a 5 digit broker
  
*/ 
   
}
//+------------------------------------------------------------------+
//| End of Check for 4/5 Digits Broker               
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Yen Adjustment Factor             
//+------------------------------------------------------------------+ 
int GetYenAdjustFactor() {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function returns a constant factor, which is used for position sizing for Yen pairs

   int output = 1;
   if(Digits == 3 || Digits == 2) output = 100;
   return(output);
}
//+------------------------------------------------------------------+
//| End of Yen Adjustment Factor             
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Volatility-Based Stop Loss                                             
//+------------------------------------------------------------------+
double VolBasedStopLoss(bool isVolatilitySwitchOn, double fixedStop, double volATR, double volMultiplier, int K){ // K represents our P multiplier to adjust for broker digits
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function calculates stop loss amount based on volatility

     double StopL;
         if(!isVolatilitySwitchOn){
            StopL=fixedStop; // If Volatility Stop Loss not activated. Stop Loss = Fixed Pips Stop Loss
         } else {
            StopL=volMultiplier*volATR/(K*Point); // Stop Loss in Pips
         } 
     return(StopL);
  }

//+------------------------------------------------------------------+
//| End of Volatility-Based Stop Loss                  
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Volatility-Based Take Profit                                     
//+------------------------------------------------------------------+

double VolBasedTakeProfit(bool isVolatilitySwitchOn, double fixedTP, double volATR, double volMultiplier, int K){ // K represents our P multiplier to adjust for broker digits
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function calculates take profit amount based on volatility

     double TakeP;
         if(!isVolatilitySwitchOn){
            TakeP=fixedTP; // If Volatility Take Profit not activated. Take Profit = Fixed Pips Take Profit
         } else {
            TakeP=volMultiplier*volATR/(K*Point); // Take Profit in Pips
         }
     return(TakeP);
  }

//+------------------------------------------------------------------+
//| End of Volatility-Based Take Profit                 
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Cross                                                             
//+------------------------------------------------------------------+

// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function determines if a cross happened between 2 lines/data set

/* 

If Output is 0: No cross happened
If Output is 1: Line 1 crossed Line 2 from Bottom
If Output is 2: Line 1 crossed Line 2 from top 

*/

int Crossed(double line1 , double line2){

   static int CurrentDirection1 = 0;
   static int LastDirection1 = 0;
   static bool FirstTime1 = true;

//----
   if(line1 > line2)
     CurrentDirection1 = 1;  // line1 above line2
   if(line1 < line2)
     CurrentDirection1 = 2;  // line1 below line2
   //----
   if(FirstTime1 == true) // Need to check if this is the first time the function is run
   {
     FirstTime1 = false; // Change variable to false
     LastDirection1 = CurrentDirection1; // Set new direction
     return (0);
   }
   
   if(CurrentDirection1 != LastDirection1 && FirstTime1 == false)  // If not the first time and there is a direction change
   {
     LastDirection1 = CurrentDirection1; // Set new direction
     return(CurrentDirection1); // 1 for up, 2 for down
   }
   else
   {
     return (0);  // No direction change
   }
}

//+------------------------------------------------------------------+
// End of Cross                                                      
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Is Loss Limit Breached                                       
//+------------------------------------------------------------------+
bool IsLossLimitBreached(bool LossLimitActivated, double LossLimitPercentage, bool Journaling, int EntrySignalTrigger){

// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function determines if our maximum loss threshold is breached

   static bool firstTick = False;
   static double initialCapital = 0;
   double profitAndLoss = 0;
   double profitAndLossPrint = 0;
   bool output = False;
   
   if(LossLimitActivated==False) return(output);
   
   if(firstTick == False){
      initialCapital = AccountEquity();
      firstTick = True;
   }
   
   profitAndLoss = (AccountEquity()/initialCapital)-1;
   
   if(profitAndLoss < -LossLimitPercentage/100){
      output = True;
      profitAndLossPrint = NormalizeDouble(profitAndLoss, 4)*100;
      if(Journaling)if(EntrySignalTrigger != 0) Print("Entry trade triggered but not executed. Loss threshold breached. Current Loss: " + profitAndLossPrint + "%");
   }
   
   return(output);
}
//+------------------------------------------------------------------+
//| End of Is Loss Limit Breached                                     
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Set Hidden Stop Loss                                     
//+------------------------------------------------------------------+

void SetStopLossHidden(bool Journaling, bool isVolatilitySwitchOn, double fixedSL, double volATR, double volMultiplier, int K, int orderNum){ // K represents our P multiplier to adjust for broker digits
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function calculates hidden stop loss amount and tags it to the appropriate order using an array

   double StopL;
   
   if(!isVolatilitySwitchOn){
      StopL=fixedSL; // If Volatility Stop Loss not activated. Stop Loss = Fixed Pips Stop Loss
   } else {
      StopL=volMultiplier*volATR/(K*Point); // Stop Loss in Pips
   }
   
   for (int x = 0; x < ArrayRange(HiddenSLList,0); x++) { // Number of elements in column 1
      if(HiddenSLList[x,0] == 0) { // Checks if the element is empty
         HiddenSLList[x,0] = orderNum;
         HiddenSLList[x,1] = StopL;
         if(Journaling)Print("EA Journaling: Order " + HiddenSLList[x,0] + " assigned with a hidden SL of " + NormalizeDouble(HiddenSLList[x,1],2) + " pips.");
         break;
      }
   }
  }

//+------------------------------------------------------------------+
//| End of Set Hidden Stop Loss                   
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trigger Hidden Stop Loss                                      
//+------------------------------------------------------------------+
void TriggerStopLossHidden(bool Journaling, int Retry_Interval, int Magic, int Slip, int K) {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

/* This function does two 2 things:
1) Clears appropriate elements of your HiddenSLList if positions has been closed
2) Closes positions based on its hidden stop loss levels
*/

   int ordersPos = OrdersTotal();
   int orderTicketNumber;
   double orderSL;
   int doesOrderExist;
   
   // 1) Check the HiddenSLList, match with current list of positions. Make sure the all the positions exists. 
   // If it doesn't, it means there are positions that have been closed
   
   for (int x = 0; x < ArrayRange(HiddenSLList,0); x++) { // Looping through all order number in list
      
      doesOrderExist = False;
      orderTicketNumber = HiddenSLList[x, 0]; 
      
      if (orderTicketNumber != 0) { // Order exists
         for(int y=ordersPos-1; y >= 0; y--) { // Looping through all current open positions
            if(OrderSelect(y,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic) {
               if(orderTicketNumber == OrderTicket()) { // Checks order number in list against order number of current positions
               doesOrderExist = True;
               break;
               }
            } 
         }
         
         if(doesOrderExist == False) { // Deletes elements if the order number does not match any current positions
            HiddenSLList[x, 0] = 0;
            HiddenSLList[x, 1] = 0;
         }
      }
      
   }
   
   // 2) Check each position against its hidden SL and close the position if hidden SL is hit
   
   for (int z = 0; z < ArrayRange(HiddenSLList,0); z++) { // Loops through elements in the list
      
      orderTicketNumber = HiddenSLList[z, 0]; // Records order numner
      orderSL = HiddenSLList[z, 1]; // Records SL
  
      if(OrderSelect(orderTicketNumber,SELECT_BY_TICKET)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic) {
         bool Closing=false;
         if (OrderType() == OP_BUY && OrderOpenPrice() - (orderSL * K * Point) >= Bid ) { // Checks SL condition for closing long orders
            
            if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, Retry_Interval);
            Closing=OrderClose(OrderTicket(),OrderLots(),Bid,Slip*K,Blue);
            if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Closing)Print("EA Journaling: Position successfully closed.");      
           
         }
         if (OrderType() == OP_SELL &&  OrderOpenPrice() + (orderSL * K * Point) <= Ask  ) { // Checks SL condition for closing short orders
            
            if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, Retry_Interval);
            Closing=OrderClose(OrderTicket(),OrderLots(),Ask,Slip*K,Red);
            if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Closing)Print("EA Journaling: Position successfully closed.");             
         
         }
      }
   }
}
//+------------------------------------------------------------------+
//| End of Trigger Hidden Stop Loss                                          
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Set Hidden Take Profit                                     
//+------------------------------------------------------------------+

void SetTakeProfitHidden(bool Journaling, bool isVolatilitySwitchOn, double fixedTP, double volATR, double volMultiplier, int K, int orderNum){ // K represents our P multiplier to adjust for broker digits
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function calculates hidden take profit amount and tags it to the appropriate order using an array

   double TakeP;
   
   if(!isVolatilitySwitchOn){
      TakeP=fixedTP; // If Volatility Take Profit not activated. Take Profit = Fixed Pips Take Profit
   } else {
      TakeP=volMultiplier*volATR/(K*Point); // Take Profit in Pips
   }
   
   for (int x = 0; x < ArrayRange(HiddenTPList,0); x++) { // Number of elements in column 1
      if(HiddenTPList[x,0] == 0) { // Checks if the element is empty
         HiddenTPList[x,0] = orderNum;
         HiddenTPList[x,1] = TakeP;
         if(Journaling)Print("EA Journaling: Order " + HiddenTPList[x,0] + " assigned with a hidden TP of " + NormalizeDouble(HiddenTPList[x,1],2) + " pips.");
         break;
      }
   }
  }

//+------------------------------------------------------------------+
//| End of Set Hidden Take Profit                  
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trigger Hidden Take Profit                                        
//+------------------------------------------------------------------+
void TriggerTakeProfitHidden(bool Journaling, int Retry_Interval, int Magic, int Slip, int K) {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

/* This function does two 2 things:
1) Clears appropriate elements of your HiddenTPList if positions has been closed
2) Closes positions based on its hidden take profit levels
*/

   int ordersPos = OrdersTotal();
   int orderTicketNumber;
   double orderTP;
   int doesOrderExist;
   
   // 1) Check the HiddenTPList, match with current list of positions. Make sure the all the positions exists. 
   // If it doesn't, it means there are positions that have been closed
   
   for (int x = 0; x < ArrayRange(HiddenTPList,0); x++) { // Looping through all order number in list
      
      doesOrderExist = False;
      orderTicketNumber = HiddenTPList[x, 0];
      
      if (orderTicketNumber != 0) { // Order exists
         for(int y=ordersPos-1; y >= 0; y--) { // Looping through all current open positions
            if(OrderSelect(y,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic) {
               if(orderTicketNumber == OrderTicket()) { // Checks order number in list against order number of current positions
               doesOrderExist = True;
               break;
               }
            } 
         }
         
         if(doesOrderExist == False) { // Deletes elements if the order number does not match any current positions
            HiddenTPList[x, 0] = 0;
            HiddenTPList[x, 1] = 0;
         }
      }
      
   }
   
   // 2) Check each position against its hidden TP and close the position if hidden TP is hit
   
   for (int z = 0; z < ArrayRange(HiddenTPList,0); z++) { // Loops through elements in the list
      
      orderTicketNumber = HiddenTPList[z, 0]; // Records order numner
      orderTP = HiddenTPList[z, 1]; // Records TP
  
      if(OrderSelect(orderTicketNumber,SELECT_BY_TICKET)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic) {
         bool Closing=false;
         if (OrderType() == OP_BUY && OrderOpenPrice() + (orderTP * K * Point) <= Bid ) { // Checks TP condition for closing long orders
            
            if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, Retry_Interval);
            Closing=OrderClose(OrderTicket(),OrderLots(),Bid,Slip*K,Blue);
            if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Closing)Print("EA Journaling: Position successfully closed.");      
           
         }
         if (OrderType() == OP_SELL &&  OrderOpenPrice() - (orderTP * K * Point) >= Ask  ) { // Checks TP condition for closing short orders 
            
            if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, Retry_Interval);
            Closing=OrderClose(OrderTicket(),OrderLots(),Ask,Slip*K,Red);
            if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Closing)Print("EA Journaling: Position successfully closed.");             
         
         }
      }
   }
}

//+------------------------------------------------------------------+
//| End of Trigger Hidden Take Profit                                       
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Breakeven Stop
//+------------------------------------------------------------------+
void BreakevenStopAll(bool Journaling, int Retry_Interval, double Breakeven_Buffer, int Magic, int K){
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function sets breakeven stops for all positions

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      bool Modify=false;
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic)
        {
         RefreshRates();
         if(OrderType()==OP_BUY && (Bid-OrderOpenPrice())>(Breakeven_Buffer*K*Point))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, breakeven stop updated.");
           }
         if(OrderType()==OP_SELL && (OrderOpenPrice()-Ask)>(Breakeven_Buffer*K*Point))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, breakeven stop updated.");
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| End of Breakeven Stop
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Update Hidden Breakeven Stops List                                     
//+------------------------------------------------------------------+

void UpdateHiddenBEList(bool Journaling, int Retry_Interval, int Magic) {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function clears the elements of your HiddenBEList if the corresponding positions has been closed

   int ordersPos = OrdersTotal();
   int orderTicketNumber;
   bool doesPosExist;
   
   // Check the HiddenBEList, match with current list of positions. Make sure the all the positions exists. 
   // If it doesn't, it means there are positions that have been closed
   
   for(int x = 0; x < ArrayRange(HiddenBEList,0); x++){ // Looping through all order number in list
      
      doesPosExist = False;
      orderTicketNumber = HiddenBEList[x];
      
      if(orderTicketNumber != 0){ // Order exists
         for(int y=ordersPos-1; y >= 0; y--){ // Looping through all current open positions
            if(OrderSelect(y,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic){
               if(orderTicketNumber == OrderTicket()){ // Checks order number in list against order number of current positions
                  doesPosExist = True;
                  break;
               }
            } 
         }
         
         if(doesPosExist == False){ // Deletes elements if the order number does not match any current positions
            HiddenBEList[x] = 0;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| End of Update Hidden Breakeven Stops List                                         
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Set and Trigger Hidden Breakeven Stops                                  
//+------------------------------------------------------------------+

void SetAndTriggerBEHidden(bool Journaling, double Breakeven_Buffer, int Magic, int Slip , int K, int Retry_Interval){ // K represents our P multiplier to adjust for broker digits
// Type: Fixed Template 
// Do not edit unless you know what you're doing

/* 
This function scans through the current positions and does 2 things:
1) If the position is in the hidden breakeven list, it closes it if the appropriate conditions are met
2) If the positon is not the hidden breakeven list, it adds it to the list if the appropriate conditions are met
*/

   bool isOrderInBEList = False;
   int orderTicketNumber;
   
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      bool Modify=false;
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic){ // Loop through list of current positions
         RefreshRates();
         orderTicketNumber = OrderTicket();
         for (int x = 0; x < ArrayRange(HiddenBEList,0); x++){ // Loops through hidden BE list
            if(orderTicketNumber == HiddenBEList[x]){ // Checks if the current position is in the list 
               isOrderInBEList = True; 
               break;   
            }
         }
         if(isOrderInBEList == True){ // If current position is in the list, close it if hidden breakeven stop is breached
            bool Closing=false;
            if (OrderType() == OP_BUY && OrderOpenPrice() >= Bid ) { // Checks BE condition for closing long orders    
               if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" using hidden breakeven stop...");
               HandleTradingEnvironment(Journaling, Retry_Interval);
               Closing=OrderClose(OrderTicket(),OrderLots(),Bid,Slip*K,Blue);
               if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
               if(Journaling && Closing)Print("EA Journaling: Position successfully closed due to hidden breakeven stop.");      
            }
            if (OrderType() == OP_SELL &&  OrderOpenPrice() <= Ask  ) { // Checks BE condition for closing short orders
               if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" using hidden breakeven stop...");
               HandleTradingEnvironment(Journaling, Retry_Interval);
               Closing=OrderClose(OrderTicket(),OrderLots(),Ask,Slip*K,Red);
               if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
               if(Journaling && Closing)Print("EA Journaling: Position successfully closed due to hidden breakeven stop.");             
            }
         } else { // If current position is not in the hidden BE list. We check if we need to add this position to the hidden BE list.
            if((OrderType()==OP_BUY && (Bid-OrderOpenPrice())>(Breakeven_Buffer*P*Point)) || (OrderType()==OP_SELL && (OrderOpenPrice()-Ask)>(Breakeven_Buffer*P*Point))){
               for (int y = 0; y < ArrayRange(HiddenBEList,0); y++){ // Loop through of elements in column 1
                  if(HiddenBEList[y] == 0){ // Checks if the element is empty
                     HiddenBEList[y] = orderTicketNumber;
                     if(Journaling)Print("EA Journaling: Order " + HiddenBEList[y] + " assigned with a hidden breakeven stop.");
                     break;
                  }
               } 
            }
         }
      }  
   }
}

//+------------------------------------------------------------------+
//| End of Set and Trigger Hidden Breakeven Stops                      
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trailing Stop
//+------------------------------------------------------------------+

void TrailingStopAll(bool Journaling, double TrailingStopDist, double TrailingStopBuff, int Retry_Interval, int Magic, int K){
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function sets trailing stops for all positions
   
   for(int i=OrdersTotal()-1; i>=0; i--) // Looping through all orders
     {
      bool Modify=false;
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic)
        {
         RefreshRates();
         if(OrderType()==OP_BUY && (Bid-OrderStopLoss()>(TrailingStopDist+TrailingStopBuff)*K*Point))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Bid-TrailingStopDist*K*Point,OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, trailing stop changed.");
           }
         if(OrderType()==OP_SELL && ((OrderStopLoss()-Ask>((TrailingStopDist+TrailingStopBuff)*K*Point)) || (OrderStopLoss()==0)))
           {
            if(Journaling)Print("EA Journaling: Trying to modify order "+OrderTicket()+" ...");
            HandleTradingEnvironment(Journaling, Retry_Interval);
            Modify=OrderModify(OrderTicket(),OrderOpenPrice(),Ask+TrailingStopDist*K*Point,OrderTakeProfit(),0,CLR_NONE);
            if(Journaling && !Modify)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
            if(Journaling && Modify)Print("EA Journaling: Order successfully modified, trailing stop changed.");
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| End Trailing Stop
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Update Hidden Trailing Stops List                                     
//+------------------------------------------------------------------+

void UpdateHiddenTrailingList(bool Journaling, int Retry_Interval, int Magic) {
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function clears the elements of your HiddenTrailingList if the corresponding positions has been closed

   int ordersPos = OrdersTotal();
   int orderTicketNumber;
   bool doesPosExist;
   
   // Check the HiddenTrailingList, match with current list of positions. Make sure the all the positions exists. 
   // If it doesn't, it means there are positions that have been closed
   
   for(int x = 0; x < ArrayRange(HiddenTrailingList,0); x++){ // Looping through all order number in list
      
      doesPosExist = False;
      orderTicketNumber = HiddenTrailingList[x,0];
      
      if(orderTicketNumber != 0){ // Order exists
         for(int y=ordersPos-1; y >= 0; y--){ // Looping through all current open positions
            if(OrderSelect(y,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic){
               if(orderTicketNumber == OrderTicket()){ // Checks order number in list against order number of current positions
                  doesPosExist = True;
                  break;
               }
            } 
         }
         
         if(doesPosExist == False){ // Deletes elements if the order number does not match any current positions
            HiddenTrailingList[x,0] = 0;
            HiddenTrailingList[x,1] = 0;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| End of Update Hidden Trailing Stops List                                       
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Set and Trigger Hidden Trailing Stop
//+------------------------------------------------------------------+

void SetAndTriggerHiddenTrailing(bool Journaling, double TrailingStopDist, double TrailingStopBuff, int Slip, int Retry_Interval, int Magic, int K){
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function does 2 things. 1) It sets hidden trailing stops for all positions 2) It closes the positions if hidden trailing stops levels are breached
   
   bool doesHiddenTrailingRecordExist;
   int posTicketNumber;
   
   for(int i=OrdersTotal()-1; i>=0; i--) { // Looping through all orders
      
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==true && OrderSymbol()==Symbol() && OrderMagicNumber()==Magic) {
         
         doesHiddenTrailingRecordExist = False;
         posTicketNumber = OrderTicket();
         
         // Step 1: Check if there is any hidden trailing stop records pertaining to this order. If yes, check if we need to close the order.
         
         for (int x = 0; x < ArrayRange(HiddenTrailingList,0); x++) { // Looping through all order number in list 
           
            if(posTicketNumber == HiddenTrailingList[x, 0]) { // If condition holds, it means the position have a hidden trailing stop level attached to it
               
               doesHiddenTrailingRecordExist = True; 
               bool Closing=false;
               RefreshRates();
               
               if(OrderType()==OP_BUY && HiddenTrailingList[x, 1] >= Bid) {
                  
                  if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" using hidden trailing stop...");
                  HandleTradingEnvironment(Journaling, Retry_Interval);
                  Closing=OrderClose(OrderTicket(),OrderLots(),Bid,Slip*K,Blue);
                  if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
                  if(Journaling && Closing)Print("EA Journaling: Position successfully closed due to hidden trailing stop."); 
               
               } else if (OrderType()==OP_SELL && HiddenTrailingList[x, 1] <= Ask) {
                  
                  if(Journaling)Print("EA Journaling: Trying to close position "+OrderTicket()+" using hidden trailing stop...");
                  HandleTradingEnvironment(Journaling, Retry_Interval);
                  Closing=OrderClose(OrderTicket(),OrderLots(),Ask,Slip*K,Red);
                  if(Journaling && !Closing)Print("EA Journaling: Unexpected Error has happened. Error Description: "+GetErrorDescription(GetLastError()));
                  if(Journaling && Closing)Print("EA Journaling: Position successfully closed due to hidden trailing stop."); 
               
               }  else {
                  
                  // Step 2: If there are hidden trailing stop records and the position was not closed in Step 1. We update the hidden trailing stop record.
                  
                  if(OrderType()==OP_BUY && (Bid-HiddenTrailingList[x, 1]>(TrailingStopDist+TrailingStopBuff)*K*Point)) {
                     HiddenTrailingList[x, 1] = Bid - TrailingStopDist*K*Point; // Assigns new hidden trailing stop level
                     if(Journaling)Print("EA Journaling: Order " + posTicketNumber + " successfully modified, hidden trailing stop updated to "+NormalizeDouble(HiddenTrailingList[x, 1],Digits)+".");
                  }
                  if (OrderType()==OP_SELL && (HiddenTrailingList[x, 1]-Ask>((TrailingStopDist+TrailingStopBuff)*K*Point))) {
                     HiddenTrailingList[x, 1] = Ask + TrailingStopDist*K*Point; // Assigns new hidden trailing stop level
                     if(Journaling)Print("EA Journaling: Order " + posTicketNumber + " successfully modified, hidden trailing stop updated "+NormalizeDouble(HiddenTrailingList[x, 1],Digits)+".");
                  }
               }   
               break;
            }
         }
         
         // Step 3: If there are no hidden trailing stop records, add new record.
         
        if(doesHiddenTrailingRecordExist == False) {
          
            for (int y = 0; y < ArrayRange(HiddenTrailingList,0); y++) { // Looping through list 
               
               if(HiddenTrailingList[y, 0] == 0) { // Slot is empty
                  
                  RefreshRates();
                  HiddenTrailingList[y, 0] = posTicketNumber; // Assigns Order Number
                  if(OrderType()==OP_BUY) {
                     HiddenTrailingList[y, 1] = MathMax(Bid, OrderOpenPrice()) - TrailingStopDist*K*Point; // Hidden trailing stop level = Higher of Bid or OrderOpenPrice - Trailing Stop Distance
                     if(Journaling)Print("EA Journaling: Order " + posTicketNumber + " successfully modified, hidden trailing stop added. Trailing Stop = "+NormalizeDouble(HiddenTrailingList[y, 1],Digits)+".");
                  }
                  if(OrderType()==OP_SELL) {
                     HiddenTrailingList[y, 1] = MathMin(Ask, OrderOpenPrice()) + TrailingStopDist*K*Point; // Hidden trailing stop level = Lower of Ask or OrderOpenPrice + Trailing Stop Distance
                     if(Journaling)Print("EA Journaling: Order " + posTicketNumber + " successfully modified, hidden trailing stop added. Trailing Stop = "+NormalizeDouble(HiddenTrailingList[y, 1],Digits)+".");
                  }
                  break;
               }
            }
         }    
         
      }
   }
}   
//+------------------------------------------------------------------+
//| End of Set and Trigger Hidden Trailing Stop
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| HANDLE TRADING ENVIRONMENT                                       
//+------------------------------------------------------------------+
void HandleTradingEnvironment(bool Journaling, int Retry_Interval){
// Type: Fixed Template 
// Do not edit unless you know what you're doing 

// This function checks for errors

   if(IsTradeAllowed()==true)return;
   if(!IsConnected())
     {
      if(Journaling)Print("EA Journaling: Terminal is not connected to server...");
      return;
     }
   if(!IsTradeAllowed() && Journaling)Print("EA Journaling: Trade is not alowed for some reason...");
   if(IsConnected() && !IsTradeAllowed())
     {
      while(IsTradeContextBusy()==true)
        {
         if(Journaling)Print("EA Journaling: Trading context is busy... Will wait a bit...");
         Sleep(Retry_Interval);
        }
     }
   RefreshRates();
  }
//+------------------------------------------------------------------+
//| End of HANDLE TRADING ENVIRONMENT                                
//+------------------------------------------------------------------+  
//+------------------------------------------------------------------+
//| ERROR DESCRIPTION                                                
//+------------------------------------------------------------------+
string GetErrorDescription(int error){
// Type: Fixed Template 
// Do not edit unless you know what you're doing

// This function returns the exact error

   string ErrorDescription="";
//---
   switch(error)
     {
      case 0:     ErrorDescription = "NO Error. Everything should be good.";                                    break;
      case 1:     ErrorDescription = "No error returned, but the result is unknown";                            break;
      case 2:     ErrorDescription = "Common error";                                                            break;
      case 3:     ErrorDescription = "Invalid trade parameters";                                                break;
      case 4:     ErrorDescription = "Trade server is busy";                                                    break;
      case 5:     ErrorDescription = "Old version of the client terminal";                                      break;
      case 6:     ErrorDescription = "No connection with trade server";                                         break;
      case 7:     ErrorDescription = "Not enough rights";                                                       break;
      case 8:     ErrorDescription = "Too frequent requests";                                                   break;
      case 9:     ErrorDescription = "Malfunctional trade operation";                                           break;
      case 64:    ErrorDescription = "Account disabled";                                                        break;
      case 65:    ErrorDescription = "Invalid account";                                                         break;
      case 128:   ErrorDescription = "Trade timeout";                                                           break;
      case 129:   ErrorDescription = "Invalid price";                                                           break;
      case 130:   ErrorDescription = "Invalid stops";                                                           break;
      case 131:   ErrorDescription = "Invalid trade volume";                                                    break;
      case 132:   ErrorDescription = "Market is closed";                                                        break;
      case 133:   ErrorDescription = "Trade is disabled";                                                       break;
      case 134:   ErrorDescription = "Not enough money";                                                        break;
      case 135:   ErrorDescription = "Price changed";                                                           break;
      case 136:   ErrorDescription = "Off quotes";                                                              break;
      case 137:   ErrorDescription = "Broker is busy";                                                          break;
      case 138:   ErrorDescription = "Requote";                                                                 break;
      case 139:   ErrorDescription = "Order is locked";                                                         break;
      case 140:   ErrorDescription = "Long positions only allowed";                                             break;
      case 141:   ErrorDescription = "Too many requests";                                                       break;
      case 145:   ErrorDescription = "Modification denied because order too close to market";                   break;
      case 146:   ErrorDescription = "Trade context is busy";                                                   break;
      case 147:   ErrorDescription = "Expirations are denied by broker";                                        break;
      case 148:   ErrorDescription = "Too many open and pending orders (more than allowed)";                    break;
      case 4000:  ErrorDescription = "No error";                                                                break;
      case 4001:  ErrorDescription = "Wrong function pointer";                                                  break;
      case 4002:  ErrorDescription = "Array index is out of range";                                             break;
      case 4003:  ErrorDescription = "No memory for function call stack";                                       break;
      case 4004:  ErrorDescription = "Recursive stack overflow";                                                break;
      case 4005:  ErrorDescription = "Not enough stack for parameter";                                          break;
      case 4006:  ErrorDescription = "No memory for parameter string";                                          break;
      case 4007:  ErrorDescription = "No memory for temp string";                                               break;
      case 4008:  ErrorDescription = "Not initialized string";                                                  break;
      case 4009:  ErrorDescription = "Not initialized string in array";                                         break;
      case 4010:  ErrorDescription = "No memory for array string";                                              break;
      case 4011:  ErrorDescription = "Too long string";                                                         break;
      case 4012:  ErrorDescription = "Remainder from zero divide";                                              break;
      case 4013:  ErrorDescription = "Zero divide";                                                             break;
      case 4014:  ErrorDescription = "Unknown command";                                                         break;
      case 4015:  ErrorDescription = "Wrong jump (never generated error)";                                      break;
      case 4016:  ErrorDescription = "Not initialized array";                                                   break;
      case 4017:  ErrorDescription = "DLL calls are not allowed";                                               break;
      case 4018:  ErrorDescription = "Cannot load library";                                                     break;
      case 4019:  ErrorDescription = "Cannot call function";                                                    break;
      case 4020:  ErrorDescription = "Expert function calls are not allowed";                                   break;
      case 4021:  ErrorDescription = "Not enough memory for temp string returned from function";                break;
      case 4022:  ErrorDescription = "System is busy (never generated error)";                                  break;
      case 4050:  ErrorDescription = "Invalid function parameters count";                                       break;
      case 4051:  ErrorDescription = "Invalid function parameter value";                                        break;
      case 4052:  ErrorDescription = "String function internal error";                                          break;
      case 4053:  ErrorDescription = "Some array error";                                                        break;
      case 4054:  ErrorDescription = "Incorrect series array using";                                            break;
      case 4055:  ErrorDescription = "Custom indicator error";                                                  break;
      case 4056:  ErrorDescription = "Arrays are incompatible";                                                 break;
      case 4057:  ErrorDescription = "Global variables processing error";                                       break;
      case 4058:  ErrorDescription = "Global variable not found";                                               break;
      case 4059:  ErrorDescription = "Function is not allowed in testing mode";                                 break;
      case 4060:  ErrorDescription = "Function is not confirmed";                                               break;
      case 4061:  ErrorDescription = "Send mail error";                                                         break;
      case 4062:  ErrorDescription = "String parameter expected";                                               break;
      case 4063:  ErrorDescription = "Integer parameter expected";                                              break;
      case 4064:  ErrorDescription = "Double parameter expected";                                               break;
      case 4065:  ErrorDescription = "Array as parameter expected";                                             break;
      case 4066:  ErrorDescription = "Requested history data in updating state";                                break;
      case 4067:  ErrorDescription = "Some error in trading function";                                          break;
      case 4099:  ErrorDescription = "End of file";                                                             break;
      case 4100:  ErrorDescription = "Some file error";                                                         break;
      case 4101:  ErrorDescription = "Wrong file name";                                                         break;
      case 4102:  ErrorDescription = "Too many opened files";                                                   break;
      case 4103:  ErrorDescription = "Cannot open file";                                                        break;
      case 4104:  ErrorDescription = "Incompatible access to a file";                                           break;
      case 4105:  ErrorDescription = "No order selected";                                                       break;
      case 4106:  ErrorDescription = "Unknown symbol";                                                          break;
      case 4107:  ErrorDescription = "Invalid price";                                                           break;
      case 4108:  ErrorDescription = "Invalid ticket";                                                          break;
      case 4109:  ErrorDescription = "EA is not allowed to trade is not allowed. ";                             break;
      case 4110:  ErrorDescription = "Longs are not allowed. Check the expert properties";                      break;
      case 4111:  ErrorDescription = "Shorts are not allowed. Check the expert properties";                     break;
      case 4200:  ErrorDescription = "Object exists already";                                                   break;
      case 4201:  ErrorDescription = "Unknown object property";                                                 break;
      case 4202:  ErrorDescription = "Object does not exist";                                                   break;
      case 4203:  ErrorDescription = "Unknown object type";                                                     break;
      case 4204:  ErrorDescription = "No object name";                                                          break;
      case 4205:  ErrorDescription = "Object coordinates error";                                                break;
      case 4206:  ErrorDescription = "No specified subwindow";                                                  break;
      case 4207:  ErrorDescription = "Some error in object function";                                           break;
      default:    ErrorDescription = "No error or error is unknown";
     }
   return(ErrorDescription);
  }
//+------------------------------------------------------------------+
//| End of ERROR DESCRIPTION                                         
//+------------------------------------------------------------------+


