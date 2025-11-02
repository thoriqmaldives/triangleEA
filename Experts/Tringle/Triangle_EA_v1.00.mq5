//+------------------------------------------------------------------+
//|                                           Triangle_EA_v1.00.mq5 |
//|                        Copyright 2024, Triangle Trading System    |
//|                                      Version: 1.00               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Triangle Trading System"
#property link      ""
#property version   "1.01"
#property description "Triangle EA - Opening Range Breakout with Basket Trading"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Include custom modules
#include "TriangleTimeManager.mqh"
#include "TriangleIndicators.mqh"
#include "TriangleRiskManager.mqh"
#include "TriangleOrderManager.mqh"
#include "TriangleBasketManager.mqh"
#include "TriangleLogger.mqh"

//--- Version control
#define VERSION_MAJOR 1
#define VERSION_MINOR 00
#define VERSION_BUILD 1

//--- Input Parameters
input group             "Trading Parameters"
input ulong             MagicNumberBase     = 55555;    // Base magic number
input double            DailyProfitTarget   = 10.0;      // Daily profit target per basket

input group             "Risk Management"
input ENUM_RISK_METHOD  RiskMethod          = PERCENT_BALANCE; // Risk calculation method
input double            RiskPercent         = 1.0;       // Risk % of balance
input double            FixedLots           = 0.1;       // Fixed lot size
input double            FixedDollarRisk     = 50.0;      // Fixed dollar risk

input group             "Time Settings"
input bool              AutoDetectTimezone  = true;      // Auto-detect broker timezone
input int               ManualTimezoneOffset = 0;        // Manual timezone offset (hours)
input bool              UseParisTime        = true;      // Use Paris time calculations

input group             "Trading Schedule"
input int               ORStartHour         = 15;        // Opening Range Start Hour (Paris time)
input int               ORStartMinute       = 30;        // Opening Range Start Minute (Paris time)
input int               OREndHour           = 15;        // Opening Range End Hour (Paris time)
input int               OREndMinute         = 45;        // Opening Range End Minute (Paris time)
input int               TradingStartHour    = 15;        // Trading Start Hour (Paris time)
input int               TradingStartMinute  = 45;        // Trading Start Minute (Paris time)
input int               TradingEndHour      = 17;        // Trading End Hour (Paris time)
input int               TradingEndMinute    = 30;        // Trading End Minute (Paris time)

input group             "Indicator Settings"
input int               EMA100Period        = 100;       // EMA 100 period for trend
input int               MAPeriodFast        = 20;        // Fast MA period
input int               MAPeriodSlow        = 50;        // Slow MA period

input group             "Chart Display Settings"
input color             ORHighLineColor     = clrRed;     // Opening Range High line color
input color             ORLowLineColor      = clrGreen;   // Opening Range Low line color
input int               ORLineWidth         = 1;          // Opening Range line width
input ENUM_LINE_STYLE   ORLineStyle         = STYLE_SOLID; // Opening Range line style
input color             TimeLabelColor      = clrYellow;  // Time label color
input int               TimeLabelFontSize   = 8;          // Time label font size
input string            TimeLabelFont       = "Arial";    // Time label font

input group             "Risk Settings"
input double            StopLossPercent     = 50.0;      // SL as % of OR size
input double            TakeProfitRR        = 3.5;       // TP as R multiple
input double            BreakEvenRR         = 2.0;       // BE at R multiple

input group             "Debug Options"
input bool              ShowInfo            = true;      // Show info on chart
input bool              EnableLogging       = true;      // Enable logging
input ENUM_LOG_LEVEL    LogLevel            = INFO;      // Logging level

//--- Global variables
CTimeManager            g_timeManager;
CIndicatorsManager      g_indicators;
CRiskManager            g_riskManager;
COrderManager           g_orderManager;
CBasketManager          g_basketManager;
CLogger                 g_logger;

//--- State variables
bool                    g_initialized       = false;
bool                    g_orCalculated      = false;
datetime                g_currentDate       = 0;
datetime                g_lastUpdateTime    = 0;

//--- Magic number generation
ulong                   g_magicNumber;

//--- Version control functions
string GetVersionString()
{
   return StringFormat("%d.%02d.%d", VERSION_MAJOR, VERSION_MINOR, VERSION_BUILD);
}

void IncrementVersion()
{
   //--- This function would increment version on compilation
   //--- For now, it's a placeholder for future implementation
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Generate unique magic number
   g_magicNumber = MagicNumberBase + (ulong)Period() * 1000 + StringToInteger(StringSubstr(_Symbol, 3, 3));
   
   //--- Initialize logger first
   g_logger.Init(LogLevel, EnableLogging);
   g_logger.LogInfo("Triangle EA v" + GetVersionString() + " initializing on " + _Symbol + " with magic number " + IntegerToString(g_magicNumber), "OnInit");
   
   //--- Validate inputs
   if(!ValidateInputs())
   {
      g_logger.LogError("Input validation failed", "OnInit");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   //--- Initialize time manager with custom trading times
   if(!g_timeManager.Init(AutoDetectTimezone, ManualTimezoneOffset,
                         ORStartHour, ORStartMinute, OREndHour, OREndMinute,
                         TradingStartHour, TradingStartMinute, TradingEndHour, TradingEndMinute))
   {
      g_logger.LogError("Failed to initialize time manager", "OnInit");
      return(INIT_FAILED);
   }
   
   //--- Initialize indicators
   if(!g_indicators.Init(_Symbol, PERIOD_H1, PERIOD_M5, 100, MAPeriodFast, MAPeriodSlow))
   {
      g_logger.LogError("Failed to initialize indicators", "OnInit");
      return(INIT_FAILED);
   }
   
   //--- Update OR line appearance
   g_indicators.UpdateORLineProperties(ORHighLineColor, ORLowLineColor, ORLineWidth, ORLineStyle);
   
   //--- Update time label appearance
   g_indicators.UpdateTimeLabelProperties(TimeLabelColor, TimeLabelFontSize, TimeLabelFont);
   
   //--- Draw time labels for trading times using user-configurable times
   datetime orStartTime = g_timeManager.GetParisTimeForHourMinute(ORStartHour, ORStartMinute);
   datetime orEndTime = g_timeManager.GetParisTimeForHourMinute(OREndHour, OREndMinute);
   datetime tradingStartTime = g_timeManager.GetParisTimeForHourMinute(TradingStartHour, TradingStartMinute);
   datetime tradingEndTime = g_timeManager.GetParisTimeForHourMinute(TradingEndHour, TradingEndMinute);
   g_indicators.DrawTimeLabels(orStartTime, orEndTime, tradingStartTime, tradingEndTime);
   
   //--- Force an initial update to ensure indicators have data
   g_indicators.Update();
   
   //--- Initialize risk manager
   g_riskManager.Init(RiskMethod, RiskPercent, FixedLots, FixedDollarRisk, StopLossPercent, TakeProfitRR, BreakEvenRR);
   
   //--- Initialize order manager
   g_orderManager.Init(g_magicNumber);
   
   //--- Initialize basket manager
   g_basketManager.Init(g_magicNumber, DailyProfitTarget);
   
   //--- Set current date
   g_currentDate = g_timeManager.GetParisTime();
   
   g_initialized = true;
   g_logger.LogInfo("Triangle EA successfully initialized", "OnInit");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_logger.LogInfo("Triangle EA deinitializing, reason: " + IntegerToString(reason), "OnDeinit");
   
   //--- Clean up indicators
   g_indicators.Deinit();
   
   //--- Clear chart display
   if(ShowInfo)
      Comment("");
   
   g_logger.LogInfo("Triangle EA deinitialized", "OnDeinit");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if initialized
   if(!g_initialized)
      return;
   
   //--- Update time every second to avoid excessive processing
   datetime currentTime = TimeCurrent();
   if(currentTime == g_lastUpdateTime)
      return;
   g_lastUpdateTime = currentTime;
   
   //--- Update time manager
   g_timeManager.Update();
   
   //--- Check for new day
   if(g_timeManager.GetParisTime() > g_currentDate + 86400)
   {
      g_currentDate = g_timeManager.GetParisTime();
      g_basketManager.CheckNewDay();
      g_orCalculated = false;
      g_logger.LogInfo("New day detected: " + TimeToString(g_currentDate), "OnTick");
   }
   
   //--- Update indicators
   g_indicators.Update();
   
   //--- Check if indicators have enough data before proceeding
   if(g_indicators.GetEMA100Value(0) == 0 ||
      g_indicators.GetMAFast(0) == 0 ||
      g_indicators.GetMASlow(0) == 0)
   {
      //--- Not enough data yet, skip this tick
      return;
   }
   
   //--- Calculate opening range if needed
   if(!g_orCalculated && g_timeManager.IsOpeningRangeTime())
   {
      CalculateOpeningRange();
   }
   
   //--- Check entry conditions and place orders
   if(g_timeManager.IsOrderPlacementTime() && g_orCalculated)
   {
      CheckEntryConditions();
   }
   
   //--- Manage open positions
   ManageOpenPositions();
   
   //--- Check basket targets
   g_basketManager.UpdateBasketProfit();
   if(g_basketManager.CheckBasketTarget())
   {
      g_orderManager.CloseAllPositions();
      g_basketManager.CloseBasket();
      g_basketManager.StartNewBasket();
      g_logger.LogInfo("Basket target reached, starting new basket", "OnTick");
   }
   
   //--- Handle forced exit
   if(g_timeManager.IsForceExitTime())
   {
      HandleForcedExit();
   }
   
   //--- Cancel pending orders after 17:30
   if(!g_timeManager.IsOrderPlacementTime() && g_orderManager.HasPendingOrders())
   {
      g_orderManager.CancelAllOrders();
      g_logger.LogInfo("Cancelling pending orders after 17:30", "OnTick");
   }
   
   //--- Display information
   if(ShowInfo)
      DisplayInfo();
}

//+------------------------------------------------------------------+
//| Validate input parameters                                        |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   //--- Validate risk percent
   if(RiskMethod == PERCENT_BALANCE && (RiskPercent <= 0 || RiskPercent > 10))
   {
      g_logger.LogError("Invalid RiskPercent: " + DoubleToString(RiskPercent) + ". Must be between 0 and 10", "ValidateInputs");
      return false;
   }
   
   //--- Validate fixed lots
   if(RiskMethod == FIXED_LOTS && (FixedLots <= 0 || FixedLots > 100))
   {
      g_logger.LogError("Invalid FixedLots: " + DoubleToString(FixedLots) + ". Must be between 0 and 100", "ValidateInputs");
      return false;
   }
   
   //--- Validate fixed dollar risk
   if(RiskMethod == FIXED_DOLLAR && (FixedDollarRisk <= 0 || FixedDollarRisk > 10000))
   {
      g_logger.LogError("Invalid FixedDollarRisk: " + DoubleToString(FixedDollarRisk) + ". Must be between 0 and 10000", "ValidateInputs");
      return false;
   }
   
   //--- Validate indicator parameters
   if(EMA100Period <= 0 || EMA100Period > 200)
   {
      g_logger.LogError("Invalid EMA100Period: " + IntegerToString(EMA100Period), "ValidateInputs");
      return false;
   }
   
   //--- Validate trading schedule parameters
   if(ORStartHour < 0 || ORStartHour > 23 || ORStartMinute < 0 || ORStartMinute > 59)
   {
      g_logger.LogError("Invalid OR Start time: " + IntegerToString(ORStartHour) + ":" + IntegerToString(ORStartMinute), "ValidateInputs");
      return false;
   }
   
   if(OREndHour < 0 || OREndHour > 23 || OREndMinute < 0 || OREndMinute > 59)
   {
      g_logger.LogError("Invalid OR End time: " + IntegerToString(OREndHour) + ":" + IntegerToString(OREndMinute), "ValidateInputs");
      return false;
   }
   
   if(TradingStartHour < 0 || TradingStartHour > 23 || TradingStartMinute < 0 || TradingStartMinute > 59)
   {
      g_logger.LogError("Invalid Trading Start time: " + IntegerToString(TradingStartHour) + ":" + IntegerToString(TradingStartMinute), "ValidateInputs");
      return false;
   }
   
   if(TradingEndHour < 0 || TradingEndHour > 23 || TradingEndMinute < 0 || TradingEndMinute > 59)
   {
      g_logger.LogError("Invalid Trading End time: " + IntegerToString(TradingEndHour) + ":" + IntegerToString(TradingEndMinute), "ValidateInputs");
      return false;
   }
   
   if(MAPeriodFast <= 0 || MAPeriodFast > 200 || MAPeriodSlow <= 0 || MAPeriodSlow > 200)
   {
      g_logger.LogError("Invalid MA periods", "ValidateInputs");
      return false;
   }
   
   if(MAPeriodFast >= MAPeriodSlow)
   {
      g_logger.LogError("MA Fast period must be less than MA Slow period", "ValidateInputs");
      return false;
   }
   
   //--- Validate risk settings
   if(StopLossPercent <= 0 || StopLossPercent > 100)
   {
      g_logger.LogError("Invalid StopLossPercent: " + DoubleToString(StopLossPercent), "ValidateInputs");
      return false;
   }
   
   if(TakeProfitRR <= 0 || TakeProfitRR > 10)
   {
      g_logger.LogError("Invalid TakeProfitRR: " + DoubleToString(TakeProfitRR), "ValidateInputs");
      return false;
   }
   
   if(BreakEvenRR <= 0 || BreakEvenRR > 10)
   {
      g_logger.LogError("Invalid BreakEvenRR: " + DoubleToString(BreakEvenRR), "ValidateInputs");
      return false;
   }
   
   //--- Validate daily profit target
   if(DailyProfitTarget <= 0 || DailyProfitTarget > 10000)
   {
      g_logger.LogError("Invalid DailyProfitTarget: " + DoubleToString(DailyProfitTarget), "ValidateInputs");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate opening range                                          |
//+------------------------------------------------------------------+
void CalculateOpeningRange()
{
   datetime orStart = g_timeManager.GetParisTimeForHourMinute(ORStartHour, ORStartMinute);
   datetime orEnd = g_timeManager.GetParisTimeForHourMinute(OREndHour, OREndMinute);
   
   if(g_indicators.CalculateOpeningRange(orStart, orEnd))
   {
      g_orCalculated = true;
      g_logger.LogInfo("Opening Range calculated: " + DoubleToString(g_indicators.GetORHigh(), 5) + " - " +
                      DoubleToString(g_indicators.GetORLow(), 5) + " (" +
                      DoubleToString(g_indicators.GetORSize() * 10000, 1) + " pips)", "CalculateOpeningRange");
      
      //--- Force redraw OR lines to ensure they're visible immediately
      g_indicators.ForceRedrawORLines();
   }
   else
   {
      g_logger.LogError("Failed to calculate opening range", "CalculateOpeningRange");
   }
}

//+------------------------------------------------------------------+
//| Check entry conditions                                           |
//+------------------------------------------------------------------+
void CheckEntryConditions()
{
    //--- Check if we already have orders or positions
    if(g_orderManager.HasPendingOrders() || g_orderManager.HasOpenPositions())
       return;
    
    //--- Get current market price
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double orHigh = g_indicators.GetORHigh();
    double orLow = g_indicators.GetORLow();
    double orSize = g_indicators.GetORSize();
    
    //--- Debug: Print current prices and OR levels
    Print("DEBUG: Current Ask: ", DoubleToString(currentAsk, 5),
          ", Bid: ", DoubleToString(currentBid, 5));
    Print("DEBUG: OR High: ", DoubleToString(orHigh, 5),
          ", OR Low: ", DoubleToString(orLow, 5));
    
    //--- Check long conditions
    if(g_indicators.IsMABullish() && g_indicators.IsEMA100Bullish(0))
    {
       double positionSize = g_riskManager.CalculatePositionSize(_Symbol, orSize);
       
       //--- Determine order type based on current price vs OR High
       if(currentAsk < orHigh)
       {
          //--- Market is below OR High, use Buy Stop order
          long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
          double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
          double spread = (double)spreadPoints * pointValue;
          double buyStopPrice = orHigh + spread;
          double stopLoss = g_riskManager.CalculateStopLoss(buyStopPrice, orSize, true);
          double takeProfit = g_riskManager.CalculateTakeProfit(buyStopPrice, stopLoss, true);
          
          if(g_orderManager.PlaceBuyStop(buyStopPrice, positionSize, stopLoss, takeProfit, "Triangle_Buy"))
          {
             g_logger.LogInfo("Buy Stop placed at " + DoubleToString(buyStopPrice, 5) + ", SL: " +
                             DoubleToString(stopLoss, 5) + ", TP: " + DoubleToString(takeProfit, 5), "CheckEntryConditions");
          }
       }
       else
       {
          //--- Market is above OR High, use Buy Limit order
          double buyLimitPrice = orHigh;
          double stopLoss = g_riskManager.CalculateStopLoss(buyLimitPrice, orSize, true);
          double takeProfit = g_riskManager.CalculateTakeProfit(buyLimitPrice, stopLoss, true);
          
          if(g_orderManager.PlaceBuyLimit(buyLimitPrice, positionSize, stopLoss, takeProfit, "Triangle_Buy"))
          {
             g_logger.LogInfo("Buy Limit placed at " + DoubleToString(buyLimitPrice, 5) + ", SL: " +
                             DoubleToString(stopLoss, 5) + ", TP: " + DoubleToString(takeProfit, 5), "CheckEntryConditions");
          }
       }
    }
    
    //--- Check short conditions
    if(g_indicators.IsMABearish() && g_indicators.IsEMA100Bearish(0))
    {
       double positionSize = g_riskManager.CalculatePositionSize(_Symbol, orSize);
       
       //--- Determine order type based on current price vs OR Low
       if(currentBid > orLow)
       {
          //--- Market is above OR Low, use Sell Stop order
          double sellStopPrice = orLow;
          double stopLoss = g_riskManager.CalculateStopLoss(sellStopPrice, orSize, false);
          double takeProfit = g_riskManager.CalculateTakeProfit(sellStopPrice, stopLoss, false);
          
          if(g_orderManager.PlaceSellStop(sellStopPrice, positionSize, stopLoss, takeProfit, "Triangle_Sell"))
          {
             g_logger.LogInfo("Sell Stop placed at " + DoubleToString(sellStopPrice, 5) + ", SL: " +
                             DoubleToString(stopLoss, 5) + ", TP: " + DoubleToString(takeProfit, 5), "CheckEntryConditions");
          }
       }
       else
       {
          //--- Market is below OR Low, use Sell Limit order
          double sellLimitPrice = orLow;
          double stopLoss = g_riskManager.CalculateStopLoss(sellLimitPrice, orSize, false);
          double takeProfit = g_riskManager.CalculateTakeProfit(sellLimitPrice, stopLoss, false);
          
          if(g_orderManager.PlaceSellLimit(sellLimitPrice, positionSize, stopLoss, takeProfit, "Triangle_Sell"))
          {
             g_logger.LogInfo("Sell Limit placed at " + DoubleToString(sellLimitPrice, 5) + ", SL: " +
                             DoubleToString(stopLoss, 5) + ", TP: " + DoubleToString(takeProfit, 5), "CheckEntryConditions");
          }
       }
    }
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   if(!g_orderManager.HasOpenPositions())
      return;
   
   //--- Check for triggered orders
   g_orderManager.CheckTriggeredOrders();
   
   //--- Get current profit and calculate R multiple
   double currentProfit = g_orderManager.GetCurrentProfit();
   double riskAmount = 0;
   
   //--- Calculate risk amount for break even
   int totalPositions = PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
         {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double stopLoss = PositionGetDouble(POSITION_SL);
            riskAmount = MathAbs(openPrice - stopLoss);
            break;
         }
      }
   }
   
   //--- Move to break even if reached 2R
   if(riskAmount > 0 && currentProfit >= riskAmount * 2.0 * BreakEvenRR)
   {
      g_orderManager.MoveToBreakEven(0); // Will be implemented in order manager
      g_logger.LogInfo("Moving position to break even", "ManageOpenPositions");
   }
}

//+------------------------------------------------------------------+
//| Handle forced exit                                               |
//+------------------------------------------------------------------+
void HandleForcedExit()
{
   if(g_orderManager.HasOpenPositions() || g_orderManager.HasPendingOrders())
   {
      g_orderManager.CloseAllPositions();
      g_orderManager.CancelAllOrders();
      g_logger.LogInfo("Forced exit at 21:00 Paris time - all positions and orders closed", "HandleForcedExit");
   }
}

//+------------------------------------------------------------------+
//| Display information on chart                                     |
//+------------------------------------------------------------------+
void DisplayInfo()
{
   string info = "Triangle EA Status v" + GetVersionString() + "\n";
   info += "========================\n";
   info += "Symbol: " + _Symbol + "\n";
   info += "Timeframe: M5\n";
   info += "Paris Time: " + TimeToString(g_timeManager.GetParisTime(), TIME_SECONDS) + "\n";
   info += "Time Status: " + g_timeManager.GetTimeStatusString() + "\n";
   
   if(g_orCalculated)
   {
      info += "Opening Range: " + DoubleToString(g_indicators.GetORHigh(), 5) + " - " + 
              DoubleToString(g_indicators.GetORLow(), 5) + " (" + 
              DoubleToString(g_indicators.GetORSize() * 10000, 1) + " pips)\n";
   }
   else
   {
      info += "Opening Range: Not calculated yet\n";
   }
   
   info += "Basket Profit: $" + DoubleToString(g_basketManager.GetCurrentBasketProfit(), 2) + 
           " / $" + DoubleToString(DailyProfitTarget, 2) + "\n";
   info += "Daily Baskets: " + IntegerToString(g_basketManager.GetBasketsCompleted()) + "\n";
   info += "Active Positions: " + IntegerToString(g_orderManager.GetOpenPositionsCount()) + "\n";
   info += "Pending Orders: " + IntegerToString(g_orderManager.GetPendingOrdersCount()) + "\n";
   
   //--- Indicator status
   if(g_indicators.IsEMA100Bullish(0))
      info += "EMA 100 H1: BULLISH\n";
   else if(g_indicators.IsEMA100Bearish(0))
      info += "EMA 100 H1: BEARISH\n";
   else
      info += "EMA 100 H1: NEUTRAL\n";
   
   double maFast = g_indicators.GetMAFast(0);
   double maSlow = g_indicators.GetMASlow(0);
   if(maFast > maSlow)
      info += "MA20/50: " + DoubleToString(maFast, 5) + " > " + DoubleToString(maSlow, 5) + " (BULLISH)\n";
   else
      info += "MA20/50: " + DoubleToString(maFast, 5) + " < " + DoubleToString(maSlow, 5) + " (BEARISH)\n";
   
   info += "Current Time: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n";
   
   Comment(info);
}
//+------------------------------------------------------------------+