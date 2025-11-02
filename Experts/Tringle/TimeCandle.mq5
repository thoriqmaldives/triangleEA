//+------------------------------------------------------------------+
//|                                                   TimeCandle.mq5 |
//|                             Copyright 2023, TimeCandle EA        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, TimeCandle EA"
#property link      ""
#property version   "1.00"
#property description "TimeCandle EA - Places limit orders at new 5M candles during NY session"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input parameters
input group             "Trading Parameters"
input double            LotSize         = 10.0;     // Fixed lot size
input int               FirstPips       = 30;       // First limit order distance in pips
input int               SecondPips      = 45;       // Second limit order distance in pips
input int               SLTP_Pips       = 20;       // SL and TP distance in pips (same for each)
input ulong             MagicNumber     = 12345;    // Magic number for order identification

input group             "Session Filter"
input int               NY_SessionStart = 13;       // NY session start hour (UTC)
input int               NY_SessionEnd   = 22;       // NY session end hour (UTC)

input group             "Debug Options"
input bool              ShowInfo        = true;     // Show information on chart
input bool              EnableLogging   = true;     // Enable logging to Experts tab

//--- Global variables
CTrade                 trade;
CPositionInfo          position;
COrderInfo             order;

datetime               lastCandleTime   = 0;
bool                   ordersPlaced     = false;
bool                   orderTriggered   = false;
int                    triggeredType    = 0;        // 0=none, 1=buy, 2=sell

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set trade parameters
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFillingBySymbol(Symbol());
   
   //--- Initialize last candle time
   lastCandleTime = iTime(Symbol(), PERIOD_M5, 0);
   
   if(EnableLogging)
      Print("TimeCandle EA initialized on ", Symbol(), " at ", TimeToString(TimeCurrent()));
      
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(EnableLogging)
      Print("TimeCandle EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if we're within NY session
   if(!IsNYSession())
   {
      if(ordersPlaced)
      {
         CloseAllPositions();
         CancelAllOrders();
         ordersPlaced = false;
         orderTriggered = false;
         triggeredType = 0;
      }
      return;
   }
   
   //--- Check for new candle
   datetime currentCandleTime = iTime(Symbol(), PERIOD_M5, 0);
   if(currentCandleTime != lastCandleTime)
   {
      //--- New candle detected
      if(EnableLogging)
         Print("New 5M candle detected at ", TimeToString(currentCandleTime));
      
      //--- Close previous positions and cancel orders
      CloseAllPositions();
      CancelAllOrders();
      
      //--- Reset flags
      ordersPlaced = false;
      orderTriggered = false;
      triggeredType = 0;
      
      //--- Update last candle time
      lastCandleTime = currentCandleTime;
   }
   
   //--- Place orders if not already placed
   if(!ordersPlaced)
   {
      PlaceLimitOrders();
      ordersPlaced = true;
   }
   
   //--- Check if any order has been triggered
   if(!orderTriggered)
   {
      CheckTriggeredOrders();
   }
   
   //--- Display information on chart
   if(ShowInfo)
      DisplayInfo();
}

//+------------------------------------------------------------------+
//| Check if current time is within NY session                       |
//+------------------------------------------------------------------+
bool IsNYSession()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   int currentHour = timeStruct.hour;
   
   //--- Check if within session hours
   if(currentHour >= NY_SessionStart && currentHour < NY_SessionEnd)
      return true;
      
   return false;
}

//+------------------------------------------------------------------+
//| Place limit orders                                               |
//+------------------------------------------------------------------+
void PlaceLimitOrders()
{
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   
   //--- Calculate price levels
   double firstSellPrice = NormalizeDouble(ask + FirstPips * point * 10, digits);
   double secondSellPrice = NormalizeDouble(ask + SecondPips * point * 10, digits);
   double firstBuyPrice = NormalizeDouble(bid - FirstPips * point * 10, digits);
   double secondBuyPrice = NormalizeDouble(bid - SecondPips * point * 10, digits);
   
   //--- Calculate SL and TP levels
   double slDistance = SLTP_Pips * point * 10;
   
   //--- Place sell limit orders
   if(trade.SellLimit(LotSize, firstSellPrice, Symbol(), firstSellPrice + slDistance, firstSellPrice - slDistance, ORDER_TIME_GTC, 0, "TimeCandle_Sell1"))
   {
      if(EnableLogging)
         Print("Sell limit 1 placed at ", firstSellPrice);
   }
   else
   {
      if(EnableLogging)
         Print("Error placing sell limit 1: ", trade.ResultRetcodeDescription());
   }
   
   if(trade.SellLimit(LotSize, secondSellPrice, Symbol(), secondSellPrice + slDistance, secondSellPrice - slDistance, ORDER_TIME_GTC, 0, "TimeCandle_Sell2"))
   {
      if(EnableLogging)
         Print("Sell limit 2 placed at ", secondSellPrice);
   }
   else
   {
      if(EnableLogging)
         Print("Error placing sell limit 2: ", trade.ResultRetcodeDescription());
   }
   
   //--- Place buy limit orders
   if(trade.BuyLimit(LotSize, firstBuyPrice, Symbol(), firstBuyPrice - slDistance, firstBuyPrice + slDistance, ORDER_TIME_GTC, 0, "TimeCandle_Buy1"))
   {
      if(EnableLogging)
         Print("Buy limit 1 placed at ", firstBuyPrice);
   }
   else
   {
      if(EnableLogging)
         Print("Error placing buy limit 1: ", trade.ResultRetcodeDescription());
   }
   
   if(trade.BuyLimit(LotSize, secondBuyPrice, Symbol(), secondBuyPrice - slDistance, secondBuyPrice + slDistance, ORDER_TIME_GTC, 0, "TimeCandle_Buy2"))
   {
      if(EnableLogging)
         Print("Buy limit 2 placed at ", secondBuyPrice);
   }
   else
   {
      if(EnableLogging)
         Print("Error placing buy limit 2: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Check if any order has been triggered                            |
//+------------------------------------------------------------------+
void CheckTriggeredOrders()
{
   //--- Check for open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == Symbol() && position.Magic() == MagicNumber)
         {
            orderTriggered = true;
            if(position.PositionType() == POSITION_TYPE_BUY)
            {
               triggeredType = 1; // Buy triggered
               if(EnableLogging)
                  Print("Buy order triggered, deleting sell limit orders");
               DeleteSellLimitOrders();
            }
            else
            {
               triggeredType = 2; // Sell triggered
               if(EnableLogging)
                  Print("Sell order triggered, deleting buy limit orders");
               DeleteBuyLimitOrders();
            }
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Delete all sell limit orders                                     |
//+------------------------------------------------------------------+
void DeleteSellLimitOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(order.SelectByIndex(i))
      {
         if(order.Symbol() == Symbol() && 
            order.Magic() == MagicNumber && 
            order.OrderType() == ORDER_TYPE_SELL_LIMIT)
         {
            trade.OrderDelete(order.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Delete all buy limit orders                                      |
//+------------------------------------------------------------------+
void DeleteBuyLimitOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(order.SelectByIndex(i))
      {
         if(order.Symbol() == Symbol() && 
            order.Magic() == MagicNumber && 
            order.OrderType() == ORDER_TYPE_BUY_LIMIT)
         {
            trade.OrderDelete(order.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == Symbol() && position.Magic() == MagicNumber)
         {
            if(position.PositionType() == POSITION_TYPE_BUY)
               trade.PositionClose(position.Ticket());
            else
               trade.PositionClose(position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Cancel all orders                                                |
//+------------------------------------------------------------------+
void CancelAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(order.SelectByIndex(i))
      {
         if(order.Symbol() == Symbol() && order.Magic() == MagicNumber)
         {
            trade.OrderDelete(order.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Display information on chart                                     |
//+------------------------------------------------------------------+
void DisplayInfo()
{
   string info = "TimeCandle EA Status\n";
   info += "===================\n";
   info += "Symbol: " + Symbol() + "\n";
   info += "Timeframe: M5\n";
   info += "NY Session: " + (IsNYSession() ? "ACTIVE" : "INACTIVE") + "\n";
   info += "Orders Placed: " + (ordersPlaced ? "YES" : "NO") + "\n";
   info += "Order Triggered: " + (orderTriggered ? "YES" : "NO") + "\n";
   if(orderTriggered)
   {
      info += "Triggered Type: " + (triggeredType == 1 ? "BUY" : "SELL") + "\n";
   }
   info += "Open Positions: " + IntegerToString(GetOpenPositions()) + "\n";
   info += "Pending Orders: " + IntegerToString(GetPendingOrders()) + "\n";
   info += "Current Time: " + TimeToString(TimeCurrent()) + "\n";
   
   Comment(info);
}

//+------------------------------------------------------------------+
//| Get count of open positions                                      |
//+------------------------------------------------------------------+
int GetOpenPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == Symbol() && position.Magic() == MagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get count of pending orders                                      |
//+------------------------------------------------------------------+
int GetPendingOrders()
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(order.SelectByIndex(i))
      {
         if(order.Symbol() == Symbol() && order.Magic() == MagicNumber)
            count++;
      }
   }
   return count;
}
//+------------------------------------------------------------------+