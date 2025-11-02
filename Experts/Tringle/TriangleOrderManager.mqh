//+------------------------------------------------------------------+
//|                                            TriangleOrderManager.mqh |
//|                        Copyright 2024, Triangle Trading System    |
//|                                      Version: 1.00               |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Triangle Trading System"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Order type enumeration
enum TRIANGLE_ORDER_TYPE
{
    ORDER_NONE,
    ORDER_BUY_STOP,
    ORDER_SELL_STOP
};

//+------------------------------------------------------------------+
//| Order Manager Class                                              |
//+------------------------------------------------------------------+
class COrderManager
{
private:
    //--- Trading objects
    CTrade              m_trade;
    CPositionInfo       m_position;
    COrderInfo          m_order;
    
    //--- Order tracking
    ulong               m_magicNumber;
    ulong               m_buyStopTicket;
    ulong               m_sellStopTicket;
    bool                m_ordersPlaced;
    TRIANGLE_ORDER_TYPE m_triggeredOrder;
    
    //--- Position tracking
    double              m_entryPrice;
    double              m_stopLoss;
    double              m_takeProfit;
    double              m_breakEvenPrice;
    bool                m_breakEvenMoved;
    
    //--- Statistics
    int                 m_totalOrders;
    int                 m_successfulOrders;
    int                 m_failedOrders;
    
    //--- Helper methods
    bool                PlaceOrder(ENUM_ORDER_TYPE orderType, double price, double lots, 
                                  double sl, double tp, string comment);
    void                UpdateOrderTracking();
    bool                IsOrderValid(ulong ticket);
    void                UpdatePositionInfo();
    
public:
    //--- Constructor/Destructor
    COrderManager();
    ~COrderManager();
    
    //--- Initialization
    void                Init(ulong magicNumber);
    
    //--- Order placement methods
    bool                PlaceBuyStop(double price, double lots, double sl, double tp, string comment);
    bool                PlaceSellStop(double price, double lots, double sl, double tp, string comment);
    bool                PlaceBuyLimit(double price, double lots, double sl, double tp, string comment);
    bool                PlaceSellLimit(double price, double lots, double sl, double tp, string comment);
    bool                PlaceBuyTrade(double lots, double stopLossPips = 10.0, double takeProfitPips = 20.0, string comment = "BuyTrade");
    
    //--- Order management methods
    void                CancelAllOrders();
    void                CancelBuyStop();
    void                CancelSellStop();
    void                CancelOrderByTicket(ulong ticket);
    
    //--- Position management methods
    void                CloseAllPositions();
    void                ClosePosition(ulong ticket);
    void                ClosePositionBySymbol(string symbol);
    void                MoveToBreakEven(double breakEvenPrice);
    void                ModifyStopLoss(ulong ticket, double newSL);
    void                ModifyTakeProfit(ulong ticket, double newTP);
    
    //--- Order checking methods
    bool                HasOpenPositions();
    bool                HasPendingOrders();
    bool                CheckTriggeredOrders();
    TRIANGLE_ORDER_TYPE GetTriggeredOrderType() { return m_triggeredOrder; }
    
    //--- Position management methods
    void                ManageOpenPositions(double breakEvenRR, double currentRR);
    double              GetCurrentProfit();
    double              GetCurrentProfitBySymbol(string symbol);
    int                 GetOpenPositionsCount();
    int                 GetOpenPositionsCountBySymbol(string symbol);
    int                 GetPendingOrdersCount();
    int                 GetPendingOrdersCountBySymbol(string symbol);
    
    //--- Information methods
    string              GetOrderInfo();
    string              GetPositionInfo();
    double              GetPositionProfit(ulong ticket);
    double              GetPositionOpenPrice(ulong ticket);
    double              GetPositionStopLoss(ulong ticket);
    double              GetPositionTakeProfit(ulong ticket);
    bool                IsPositionLong(ulong ticket);
    
    //--- Statistics methods
    int                 GetTotalOrders() { return m_totalOrders; }
    int                 GetSuccessfulOrders() { return m_successfulOrders; }
    int                 GetFailedOrders() { return m_failedOrders; }
    double              GetSuccessRate();
    
    //--- Utility methods
    void                Reset();
    void                Update();
    string              GetOrderTypeString(TRIANGLE_ORDER_TYPE type);
    string              GetPositionTypeString(ENUM_POSITION_TYPE type);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrderManager::COrderManager()
{
    m_magicNumber = 0;
    m_buyStopTicket = 0;
    m_sellStopTicket = 0;
    m_ordersPlaced = false;
    m_triggeredOrder = ORDER_NONE;
    
    m_entryPrice = 0;
    m_stopLoss = 0;
    m_takeProfit = 0;
    m_breakEvenPrice = 0;
    m_breakEvenMoved = false;
    
    m_totalOrders = 0;
    m_successfulOrders = 0;
    m_failedOrders = 0;
    
    //--- Initialize trade object
    m_trade.SetExpertMagicNumber(0); // Will be set in Init
    m_trade.SetDeviationInPoints(10);
    m_trade.SetTypeFillingBySymbol(_Symbol);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrderManager::~COrderManager()
{
}

//+------------------------------------------------------------------+
//| Initialize order manager                                         |
//+------------------------------------------------------------------+
void COrderManager::Init(ulong magicNumber)
{
    m_magicNumber = magicNumber;
    m_trade.SetExpertMagicNumber(magicNumber);
    
    Print("Order Manager initialized with magic number: ", magicNumber);
}

//+------------------------------------------------------------------+
//| Place Buy Stop order                                             |
//+------------------------------------------------------------------+
bool COrderManager::PlaceBuyStop(double price, double lots, double sl, double tp, string comment)
{
    if(m_buyStopTicket != 0 && IsOrderValid(m_buyStopTicket))
    {
        Print("Buy Stop order already exists: ", m_buyStopTicket);
        return false;
    }
    
    if(!PlaceOrder(ORDER_TYPE_BUY_STOP, price, lots, sl, tp, comment))
        return false;
    
    m_buyStopTicket = m_trade.ResultOrder();
    m_ordersPlaced = true;
    
    Print("Buy Stop placed successfully: ", m_buyStopTicket, " at price: ", DoubleToString(price, 5));
    return true;
}

//+------------------------------------------------------------------+
//| Place Sell Stop order                                            |
//+------------------------------------------------------------------+
bool COrderManager::PlaceSellStop(double price, double lots, double sl, double tp, string comment)
{
    if(m_sellStopTicket != 0 && IsOrderValid(m_sellStopTicket))
    {
        Print("Sell Stop order already exists: ", m_sellStopTicket);
        return false;
    }
    
    if(!PlaceOrder(ORDER_TYPE_SELL_STOP, price, lots, sl, tp, comment))
        return false;
    
    m_sellStopTicket = m_trade.ResultOrder();
    m_ordersPlaced = true;
    
    Print("Sell Stop placed successfully: ", m_sellStopTicket, " at price: ", DoubleToString(price, 5));
    return true;
}

//+------------------------------------------------------------------+
//| Place order (internal method)                                    |
//+------------------------------------------------------------------+
bool COrderManager::PlaceOrder(ENUM_ORDER_TYPE orderType, double price, double lots, 
                               double sl, double tp, string comment)
{
    m_totalOrders++;
    
    //--- Normalize price levels
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    price = NormalizeDouble(price, digits);
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
    
    bool result = false;
    
    switch(orderType)
    {
        case ORDER_TYPE_BUY_STOP:
            result = m_trade.BuyStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
            break;
            
        case ORDER_TYPE_SELL_STOP:
            result = m_trade.SellStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
            break;
    }
    
    if(result)
    {
        m_successfulOrders++;
        Print("Order placed successfully: ", comment, " at ", DoubleToString(price, 5));
    }
    else
    {
        m_failedOrders++;
        uint errorCode = m_trade.ResultRetcode();
        string errorMsg = m_trade.ResultRetcodeDescription();
        Print("Order placement failed: ", comment, ". Error: ", errorMsg, " (", IntegerToString(errorCode), ")");
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Cancel all orders                                                |
//+------------------------------------------------------------------+
void COrderManager::CancelAllOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(m_order.SelectByIndex(i))
        {
            if(m_order.Symbol() == _Symbol && m_order.Magic() == m_magicNumber)
            {
                if(m_trade.OrderDelete(m_order.Ticket()))
                {
                    Print("Order deleted: ", m_order.Ticket());
                }
                else
                {
                    Print("Failed to delete order: ", m_order.Ticket(),
                          ". Error: ", m_trade.ResultRetcodeDescription());
                }
            }
        }
    }
    
    //--- Reset order tracking
    m_buyStopTicket = 0;
    m_sellStopTicket = 0;
    m_ordersPlaced = false;
}

//+------------------------------------------------------------------+
//| Cancel Buy Stop order                                            |
//+------------------------------------------------------------------+
void COrderManager::CancelBuyStop()
{
    if(m_buyStopTicket != 0 && IsOrderValid(m_buyStopTicket))
    {
        if(m_trade.OrderDelete(m_buyStopTicket))
        {
            Print("Buy Stop order cancelled: ", m_buyStopTicket);
            m_buyStopTicket = 0;
        }
        else
        {
            Print("Failed to cancel Buy Stop order: ", m_buyStopTicket,
                  ". Error: ", m_trade.ResultRetcodeDescription());
        }
    }
}

//+------------------------------------------------------------------+
//| Cancel Sell Stop order                                           |
//+------------------------------------------------------------------+
void COrderManager::CancelSellStop()
{
    if(m_sellStopTicket != 0 && IsOrderValid(m_sellStopTicket))
    {
        if(m_trade.OrderDelete(m_sellStopTicket))
        {
            Print("Sell Stop order cancelled: ", m_sellStopTicket);
            m_sellStopTicket = 0;
        }
        else
        {
            Print("Failed to cancel Sell Stop order: ", m_sellStopTicket,
                  ". Error: ", m_trade.ResultRetcodeDescription());
        }
    }
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void COrderManager::CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magicNumber)
            {
                if(m_trade.PositionClose(m_position.Ticket()))
                {
                    Print("Position closed: ", m_position.Ticket());
                }
                else
                {
                    Print("Failed to close position: ", m_position.Ticket(),
                          ". Error: ", m_trade.ResultRetcodeDescription());
                }
            }
        }
    }
    
    //--- Reset position tracking
    m_triggeredOrder = ORDER_NONE;
    m_breakEvenMoved = false;
}

//+------------------------------------------------------------------+
//| Close position by ticket                                         |
//+------------------------------------------------------------------+
void COrderManager::ClosePosition(ulong ticket)
{
    if(m_trade.PositionClose(ticket))
    {
        Print("Position closed: ", ticket);
    }
    else
    {
        Print("Failed to close position: ", ticket,
              ". Error: ", m_trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Move to break even                                               |
//+------------------------------------------------------------------+
void COrderManager::MoveToBreakEven(double breakEvenPrice)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magicNumber)
            {
                double currentSL = m_position.StopLoss();
                
                //--- Only move SL if it's below break even for long positions
                //--- or above break even for short positions
                if((m_position.PositionType() == POSITION_TYPE_BUY && currentSL < breakEvenPrice) ||
                   (m_position.PositionType() == POSITION_TYPE_SELL && currentSL > breakEvenPrice))
                {
                    if(m_trade.PositionModify(m_position.Ticket(), breakEvenPrice, m_position.TakeProfit()))
                    {
                        Print("Position moved to break even: ", m_position.Ticket(), 
                              " at ", DoubleToString(breakEvenPrice, 5));
                    }
                    else
                    {
                        Print("Failed to move position to break even: ", m_position.Ticket(),
                              ". Error: ", m_trade.ResultRetcodeDescription());
                    }
                }
            }
        }
    }
    
    m_breakEvenMoved = true;
}

//+------------------------------------------------------------------+
//| Check if order is valid                                          |
//+------------------------------------------------------------------+
bool COrderManager::IsOrderValid(ulong ticket)
{
    if(ticket == 0)
        return false;
    
    return OrderSelect(ticket);
}

//+------------------------------------------------------------------+
//| Check for triggered orders                                       |
//+------------------------------------------------------------------+
bool COrderManager::CheckTriggeredOrders()
{
    //--- Check for open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magicNumber)
            {
                //--- Position found, determine type
                if(m_position.PositionType() == POSITION_TYPE_BUY)
                {
                    m_triggeredOrder = ORDER_BUY_STOP;
                    //--- Cancel opposite pending order
                    CancelSellStop();
                }
                else
                {
                    m_triggeredOrder = ORDER_SELL_STOP;
                    //--- Cancel opposite pending order
                    CancelBuyStop();
                }
                
                UpdatePositionInfo();
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update position information                                      |
//+------------------------------------------------------------------+
void COrderManager::UpdatePositionInfo()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magicNumber)
            {
                m_entryPrice = m_position.PriceOpen();
                m_stopLoss = m_position.StopLoss();
                m_takeProfit = m_position.TakeProfit();
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if has open positions                                      |
//+------------------------------------------------------------------+
bool COrderManager::HasOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magicNumber)
                return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if has pending orders                                      |
//+------------------------------------------------------------------+
bool COrderManager::HasPendingOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(m_order.SelectByIndex(i))
        {
            if(m_order.Symbol() == _Symbol && m_order.Magic() == m_magicNumber)
                return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get current profit                                               |
//+------------------------------------------------------------------+
double COrderManager::GetCurrentProfit()
{
    double totalProfit = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magicNumber)
                totalProfit += m_position.Profit();
        }
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| Get open positions count                                         |
//+------------------------------------------------------------------+
int COrderManager::GetOpenPositionsCount()
{
    int count = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magicNumber)
                count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Get pending orders count                                         |
//+------------------------------------------------------------------+
int COrderManager::GetPendingOrdersCount()
{
    int count = 0;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(m_order.SelectByIndex(i))
        {
            if(m_order.Symbol() == _Symbol && m_order.Magic() == m_magicNumber)
                count++;
        }
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Get success rate                                                 |
//+------------------------------------------------------------------+
double COrderManager::GetSuccessRate()
{
    if(m_totalOrders == 0)
        return 0;
    
    return (double)m_successfulOrders / m_totalOrders * 100.0;
}

//+------------------------------------------------------------------+
//| Get order type string                                            |
//+------------------------------------------------------------------+
string COrderManager::GetOrderTypeString(TRIANGLE_ORDER_TYPE type)
{
    switch(type)
    {
        case ORDER_BUY_STOP:  return "BUY_STOP";
        case ORDER_SELL_STOP: return "SELL_STOP";
        default:              return "NONE";
    }
}

//+------------------------------------------------------------------+
//| Get position type string                                         |
//+------------------------------------------------------------------+
string COrderManager::GetPositionTypeString(ENUM_POSITION_TYPE type)
{
    switch(type)
    {
        case POSITION_TYPE_BUY:  return "BUY";
        case POSITION_TYPE_SELL: return "SELL";
        default:                 return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get order information                                            |
//+------------------------------------------------------------------+
string COrderManager::GetOrderInfo()
{
    string info = "Order Information:\n";
    info += "==================\n";
    info += "Magic Number: " + IntegerToString(m_magicNumber) + "\n";
    info += "Orders Placed: " + (m_ordersPlaced ? "Yes" : "No") + "\n";
    info += "Triggered Order: " + GetOrderTypeString(m_triggeredOrder) + "\n";
    info += "Buy Stop Ticket: " + (m_buyStopTicket > 0 ? IntegerToString(m_buyStopTicket) : "None") + "\n";
    info += "Sell Stop Ticket: " + (m_sellStopTicket > 0 ? IntegerToString(m_sellStopTicket) : "None") + "\n";
    info += "Total Orders: " + IntegerToString(m_totalOrders) + "\n";
    info += "Successful Orders: " + IntegerToString(m_successfulOrders) + "\n";
    info += "Failed Orders: " + IntegerToString(m_failedOrders) + "\n";
    info += "Success Rate: " + DoubleToString(GetSuccessRate(), 2) + "%\n";
    
    return info;
}

//+------------------------------------------------------------------+
//| Get position information                                         |
//+------------------------------------------------------------------+
string COrderManager::GetPositionInfo()
{
    string info = "Position Information:\n";
    info += "=====================\n";
    info += "Open Positions: " + IntegerToString(GetOpenPositionsCount()) + "\n";
    info += "Pending Orders: " + IntegerToString(GetPendingOrdersCount()) + "\n";
    info += "Current Profit: $" + DoubleToString(GetCurrentProfit(), 2) + "\n";
    
    if(HasOpenPositions())
    {
        info += "Entry Price: " + DoubleToString(m_entryPrice, 5) + "\n";
        info += "Stop Loss: " + DoubleToString(m_stopLoss, 5) + "\n";
        info += "Take Profit: " + DoubleToString(m_takeProfit, 5) + "\n";
        info += "Break Even Moved: " + (m_breakEvenMoved ? "Yes" : "No") + "\n";
    }
    
    return info;
}

//+------------------------------------------------------------------+
//| Reset order manager                                              |
//+------------------------------------------------------------------+
void COrderManager::Reset()
{
    m_buyStopTicket = 0;
    m_sellStopTicket = 0;
    m_ordersPlaced = false;
    m_triggeredOrder = ORDER_NONE;
    
    m_entryPrice = 0;
    m_stopLoss = 0;
    m_takeProfit = 0;
    m_breakEvenPrice = 0;
    m_breakEvenMoved = false;
}

//+------------------------------------------------------------------+
//| Update order manager                                             |
//+------------------------------------------------------------------+
void COrderManager::Update()
{
    UpdateOrderTracking();
    
    if(HasOpenPositions())
        UpdatePositionInfo();
}

//+------------------------------------------------------------------+
//| Update order tracking                                            |
//+------------------------------------------------------------------+
void COrderManager::UpdateOrderTracking()
{
    //--- Check if our tracked orders still exist
    if(m_buyStopTicket != 0 && !IsOrderValid(m_buyStopTicket))
        m_buyStopTicket = 0;
    
    if(m_sellStopTicket != 0 && !IsOrderValid(m_sellStopTicket))
        m_sellStopTicket = 0;
    
    //--- Update orders placed flag
    m_ordersPlaced = (m_buyStopTicket != 0 || m_sellStopTicket != 0);
}

//+------------------------------------------------------------------+
//| Place immediate buy trade with fixed SL/TP in pips               |
//+------------------------------------------------------------------+
bool COrderManager::PlaceBuyTrade(double lots, double stopLossPips, double takeProfitPips, string comment)
{
    m_totalOrders++;
    
    //--- Get current market price
    double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    
    //--- Adjust for 5-digit brokers
    if(digits == 3 || digits == 5)
    {
        stopLossPips *= 10;
        takeProfitPips *= 10;
    }
    
    //--- Calculate SL and TP prices
    double stopLoss = askPrice - (stopLossPips * pointValue);
    double takeProfit = askPrice + (takeProfitPips * pointValue);
    
    //--- Normalize prices
    askPrice = NormalizeDouble(askPrice, digits);
    stopLoss = NormalizeDouble(stopLoss, digits);
    takeProfit = NormalizeDouble(takeProfit, digits);
    
    //--- Validate stop loss and take profit levels
    double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * pointValue;
    
    //--- Ensure SL is at minimum distance from current price
    if(MathAbs(askPrice - stopLoss) < minStopLevel)
    {
        stopLoss = askPrice - minStopLevel;
        stopLoss = NormalizeDouble(stopLoss, digits);
        Print("Stop loss adjusted to minimum distance: ", DoubleToString(stopLoss, digits));
    }
    
    //--- Ensure TP is at minimum distance from current price
    if(MathAbs(takeProfit - askPrice) < minStopLevel)
    {
        takeProfit = askPrice + minStopLevel;
        takeProfit = NormalizeDouble(takeProfit, digits);
        Print("Take profit adjusted to minimum distance: ", DoubleToString(takeProfit, digits));
    }
    
    //--- Check if trading is allowed
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
    {
        Print("Trading is not allowed!");
        m_failedOrders++;
        return false;
    }
    
    //--- Open the buy trade
    bool result = m_trade.Buy(lots, _Symbol, askPrice, stopLoss, takeProfit, comment);
    
    //--- Check result
    if(result)
    {
        m_successfulOrders++;
        uint errorCode = m_trade.ResultRetcode();
        ulong orderTicket = m_trade.ResultOrder();
        double openPrice = m_trade.ResultPrice();
        
        Print("Buy trade opened successfully!");
        Print("Ticket: ", orderTicket);
        Print("Symbol: ", _Symbol);
        Print("Lot Size: ", lots);
        Print("Open Price: ", DoubleToString(openPrice, digits));
        Print("Stop Loss: ", DoubleToString(stopLoss, digits), " (", DoubleToString(stopLossPips/10, 1), " pips)");
        Print("Take Profit: ", DoubleToString(takeProfit, digits), " (", DoubleToString(takeProfitPips/10, 1), " pips)");
        Print("Comment: ", comment);
        Print("Magic Number: ", m_magicNumber);
        
        return true;
    }
    else
    {
        m_failedOrders++;
        uint errorCode = m_trade.ResultRetcode();
        string errorMsg = m_trade.ResultRetcodeDescription();
        Print("Failed to open buy trade!");
        Print("Error Code: ", errorCode);
        Print("Error Message: ", errorMsg);
        
        return false;
    }
}

//+------------------------------------------------------------------+
//| Place Buy Limit order                                             |
//+------------------------------------------------------------------+
bool COrderManager::PlaceBuyLimit(double price, double lots, double sl, double tp, string comment)
{
    m_totalOrders++;
    
    //--- Normalize price levels
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    price = NormalizeDouble(price, digits);
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
    
    //--- Validate stop loss and take profit levels
    double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    //--- Ensure SL is at minimum distance from current price
    double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if(MathAbs(price - sl) < minStopLevel)
    {
        sl = price - minStopLevel;
        sl = NormalizeDouble(sl, digits);
        Print("Stop loss adjusted to minimum distance: ", DoubleToString(sl, digits));
    }
    
    //--- Ensure TP is at minimum distance from current price
    if(MathAbs(tp - price) < minStopLevel)
    {
        tp = price + minStopLevel;
        tp = NormalizeDouble(tp, digits);
        Print("Take profit adjusted to minimum distance: ", DoubleToString(tp, digits));
    }
    
    //--- Check if trading is allowed
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
    {
        Print("Trading is not allowed!");
        m_failedOrders++;
        return false;
    }
    
    //--- Open the buy limit order
    bool result = m_trade.BuyLimit(lots, _Symbol, price, sl, tp, ORDER_TIME_GTC, 0, comment);
    
    //--- Check result
    if(result)
    {
        m_successfulOrders++;
        uint errorCode = m_trade.ResultRetcode();
        ulong orderTicket = m_trade.ResultOrder();
        double openPrice = m_trade.ResultPrice();
        
        Print("Buy Limit order opened successfully!");
        Print("Ticket: ", orderTicket);
        Print("Symbol: ", _Symbol);
        Print("Lot Size: ", lots);
        Print("Open Price: ", DoubleToString(openPrice, digits));
        Print("Stop Loss: ", DoubleToString(sl, digits));
        Print("Take Profit: ", DoubleToString(tp, digits));
        Print("Comment: ", comment);
        Print("Magic Number: ", m_magicNumber);
        
        return true;
    }
    else
    {
        m_failedOrders++;
        uint errorCode = m_trade.ResultRetcode();
        string errorMsg = m_trade.ResultRetcodeDescription();
        Print("Failed to open buy limit order!");
        Print("Error Code: ", errorCode);
        Print("Error Message: ", errorMsg);
        
        return false;
    }
}

//+------------------------------------------------------------------+
//| Place Sell Limit order                                            |
//+------------------------------------------------------------------+
bool COrderManager::PlaceSellLimit(double price, double lots, double sl, double tp, string comment)
{
    m_totalOrders++;
    
    //--- Normalize price levels
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    price = NormalizeDouble(price, digits);
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
    
    //--- Validate stop loss and take profit levels
    double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    //--- Ensure SL is at minimum distance from current price
    double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(MathAbs(sl - price) < minStopLevel)
    {
        sl = price + minStopLevel;
        sl = NormalizeDouble(sl, digits);
        Print("Stop loss adjusted to minimum distance: ", DoubleToString(sl, digits));
    }
    
    //--- Ensure TP is at minimum distance from current price
    if(MathAbs(tp - price) < minStopLevel)
    {
        tp = price - minStopLevel;
        tp = NormalizeDouble(tp, digits);
        Print("Take profit adjusted to minimum distance: ", DoubleToString(tp, digits));
    }
    
    //--- Check if trading is allowed
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
    {
        Print("Trading is not allowed!");
        m_failedOrders++;
        return false;
    }
    
    //--- Open the sell limit order
    bool result = m_trade.SellLimit(lots, _Symbol, price, sl, tp, ORDER_TIME_GTC, 0, comment);
    
    //--- Check result
    if(result)
    {
        m_successfulOrders++;
        uint errorCode = m_trade.ResultRetcode();
        ulong orderTicket = m_trade.ResultOrder();
        double openPrice = m_trade.ResultPrice();
        
        Print("Sell Limit order opened successfully!");
        Print("Ticket: ", orderTicket);
        Print("Symbol: ", _Symbol);
        Print("Lot Size: ", lots);
        Print("Open Price: ", DoubleToString(openPrice, digits));
        Print("Stop Loss: ", DoubleToString(sl, digits));
        Print("Take Profit: ", DoubleToString(tp, digits));
        Print("Comment: ", comment);
        Print("Magic Number: ", m_magicNumber);
        
        return true;
    }
    else
    {
        m_failedOrders++;
        uint errorCode = m_trade.ResultRetcode();
        string errorMsg = m_trade.ResultRetcodeDescription();
        Print("Failed to open sell limit order!");
        Print("Error Code: ", errorCode);
        Print("Error Message: ", errorMsg);
        
        return false;
    }
}
//+------------------------------------------------------------------+