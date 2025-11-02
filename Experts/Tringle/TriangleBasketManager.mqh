//+------------------------------------------------------------------+
//|                                           TriangleBasketManager.mqh |
//|                        Copyright 2024, Triangle Trading System    |
//|                                      Version: 1.00               |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Triangle Trading System"
#property link      ""
#property version   "1.00"
#property strict

//--- Basket information structure
struct BASKET_INFO
{
    datetime            startDate;          // Basket start date/time
    double              startBalance;       // Account balance at basket start
    double              startEquity;        // Account equity at basket start
    double              targetProfit;       // Profit target for this basket
    double              currentProfit;      // Current profit in basket
    int                 tradesCount;        // Number of trades in basket
    int                 winningTrades;      // Number of winning trades
    int                 losingTrades;       // Number of losing trades
    double              maxProfit;          // Maximum profit reached
    double              maxDrawdown;        // Maximum drawdown in basket
    bool                isActive;           // Is basket currently active
    string              basketId;           // Unique basket identifier
};

//+------------------------------------------------------------------+
//| Basket Manager Class                                             |
//+------------------------------------------------------------------+
class CBasketManager
{
private:
    //--- Basket tracking
    BASKET_INFO          m_currentBasket;
    BASKET_INFO          m_basketHistory[];  // Array of completed baskets
    int                  m_maxHistorySize;    // Maximum number of baskets to keep in history
    
    //--- Daily tracking
    datetime             m_currentDay;        // Current trading day
    double               m_dailyProfit;       // Total profit for current day
    int                  m_basketsCompleted;  // Number of baskets completed today
    double               m_dailyTarget;       // Daily profit target
    
    //--- Configuration
    ulong                m_magicNumber;       // Magic number for order identification
    double               m_profitTarget;      // Profit target per basket
    
    //--- Statistics
    int                  m_totalBaskets;      // Total baskets completed
    int                  m_profitableBaskets; // Number of profitable baskets
    double               m_totalProfit;       // Total profit from all baskets
    double               m_averageBasketProfit; // Average profit per basket
    double               m_maxBasketProfit;   // Maximum basket profit
    double               m_maxBasketLoss;     // Maximum basket loss
    
    //--- Helper methods
    void                 InitializeBasket(datetime startTime, double targetProfit);
    void                 UpdateBasketStatistics();
    void                 AddToHistory(const BASKET_INFO& basket);
    string               GenerateBasketId();
    void                 CalculateDailyStats();
    bool                 IsNewDay();
    
public:
    //--- Constructor/Destructor
    CBasketManager();
    ~CBasketManager();
    
    //--- Initialization
    void                 Init(ulong magicNumber, double dailyProfitTarget);
    
    //--- Basket management methods
    void                 StartNewBasket();
    void                 CloseBasket();
    bool                 CheckBasketTarget();
    void                 UpdateBasketProfit();
    void                 ResetBasket();
    
    //--- Daily management methods
    void                 CheckNewDay();
    void                 ResetDaily();
    void                 SetDailyTarget(double target);
    
    //--- Profit calculations
    double               GetDailyProfit() { return m_dailyProfit; }
    double               GetBasketProgress(); // Returns progress as percentage (0-100)
    double               GetCurrentBasketProfit();
    
    //--- Information methods
    int                  GetBasketsCompleted() { return m_basketsCompleted; }
    int                  GetTotalBaskets() { return m_totalBaskets; }
    bool                 IsBasketActive() { return m_currentBasket.isActive; }
    string               GetBasketInfo();
    string               GetDailyInfo();
    string               GetStatisticsInfo();
    
    //--- History methods
    int                  GetHistorySize() { return ArraySize(m_basketHistory); }
    BASKET_INFO          GetBasketFromHistory(int index);
    void                 ClearHistory();
    
    //--- Update methods
    void                 Update();
    
    //--- Utility methods
    double               GetAverageBasketProfit() { return m_averageBasketProfit; }
    double               GetProfitableBasketPercentage();
    double               GetCurrentDrawdown();
    bool                 IsDailyTargetReached();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBasketManager::CBasketManager()
{
    //--- Initialize current basket
    ZeroMemory(m_currentBasket);
    m_currentBasket.isActive = false;
    
    //--- Initialize history array
    ArrayResize(m_basketHistory, 0);
    m_maxHistorySize = 100; // Keep last 100 baskets
    
    //--- Initialize daily tracking
    m_currentDay = 0;
    m_dailyProfit = 0;
    m_basketsCompleted = 0;
    m_dailyTarget = 10.0; // Default $10 daily target
    
    //--- Initialize configuration
    m_magicNumber = 0;
    m_profitTarget = 10.0;
    
    //--- Initialize statistics
    m_totalBaskets = 0;
    m_profitableBaskets = 0;
    m_totalProfit = 0;
    m_averageBasketProfit = 0;
    m_maxBasketProfit = 0;
    m_maxBasketLoss = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBasketManager::~CBasketManager()
{
}

//+------------------------------------------------------------------+
//| Initialize basket manager                                        |
//+------------------------------------------------------------------+
void CBasketManager::Init(ulong magicNumber, double dailyProfitTarget)
{
    m_magicNumber = magicNumber;
    m_profitTarget = dailyProfitTarget;
    m_dailyTarget = dailyProfitTarget;
    
    //--- Set current day
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    currentTime.hour = 0;
    currentTime.min = 0;
    currentTime.sec = 0;
    m_currentDay = StructToTime(currentTime);
    
    //--- Start first basket
    StartNewBasket();
    
    Print("Basket Manager initialized - Magic Number: ", magicNumber, 
          ", Daily Target: $", DoubleToString(dailyProfitTarget, 2));
}

//+------------------------------------------------------------------+
//| Start new basket                                                 |
//+------------------------------------------------------------------+
void CBasketManager::StartNewBasket()
{
    InitializeBasket(TimeCurrent(), m_profitTarget);
    
    Print("New basket started: ", m_currentBasket.basketId, 
          " with target: $", DoubleToString(m_profitTarget, 2));
}

//+------------------------------------------------------------------+
//| Initialize basket                                                |
//+------------------------------------------------------------------+
void CBasketManager::InitializeBasket(datetime startTime, double targetProfit)
{
    //--- Reset current basket
    ZeroMemory(m_currentBasket);
    
    //--- Set basic information
    m_currentBasket.startDate = startTime;
    m_currentBasket.targetProfit = targetProfit;
    m_currentBasket.isActive = true;
    m_currentBasket.basketId = GenerateBasketId();
    
    //--- Get current account state
    m_currentBasket.startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_currentBasket.startEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    //--- Initialize tracking variables
    m_currentBasket.currentProfit = 0;
    m_currentBasket.tradesCount = 0;
    m_currentBasket.winningTrades = 0;
    m_currentBasket.losingTrades = 0;
    m_currentBasket.maxProfit = 0;
    m_currentBasket.maxDrawdown = 0;
}

//+------------------------------------------------------------------+
//| Generate unique basket ID                                        |
//+------------------------------------------------------------------+
string CBasketManager::GenerateBasketId()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    return "BASKET_" + IntegerToString(dt.year) + 
           StringFormat("%02d", dt.mon) + 
           StringFormat("%02d", dt.day) + "_" +
           StringFormat("%02d", dt.hour) + 
           StringFormat("%02d", dt.min) + 
           StringFormat("%02d", dt.sec) + "_" +
           IntegerToString(m_totalBaskets + 1);
}

//+------------------------------------------------------------------+
//| Update basket profit                                             |
//+------------------------------------------------------------------+
void CBasketManager::UpdateBasketProfit()
{
    if(!m_currentBasket.isActive)
        return;
    
    //--- Calculate current profit from open positions
    double currentProfit = 0;
    int tradesCount = 0;
    
    int totalPositions = PositionsTotal();
    for(int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            ulong posMagic = PositionGetInteger(POSITION_MAGIC);
            
            if(posSymbol == _Symbol && posMagic == m_magicNumber)
            {
                currentProfit += PositionGetDouble(POSITION_PROFIT);
                tradesCount++;
            }
        }
    }
    
    //--- Update basket information
    m_currentBasket.currentProfit = currentProfit;
    m_currentBasket.tradesCount = tradesCount;
    
    //--- Update maximum profit
    if(currentProfit > m_currentBasket.maxProfit)
        m_currentBasket.maxProfit = currentProfit;
    
    //--- Update maximum drawdown
    double drawdown = m_currentBasket.maxProfit - currentProfit;
    if(drawdown > m_currentBasket.maxDrawdown)
        m_currentBasket.maxDrawdown = drawdown;
    
    //--- Update daily profit
    CalculateDailyStats();
}

//+------------------------------------------------------------------+
//| Check if basket target is reached                                |
//+------------------------------------------------------------------+
bool CBasketManager::CheckBasketTarget()
{
    if(!m_currentBasket.isActive)
        return false;
    
    return (m_currentBasket.currentProfit >= m_currentBasket.targetProfit);
}

//+------------------------------------------------------------------+
//| Close basket                                                     |
//+------------------------------------------------------------------+
void CBasketManager::CloseBasket()
{
    if(!m_currentBasket.isActive)
        return;
    
    //--- Update final statistics
    UpdateBasketStatistics();
    
    //--- Add to history
    AddToHistory(m_currentBasket);
    
    //--- Update global statistics
    m_totalBaskets++;
    m_totalProfit += m_currentBasket.currentProfit;
    
    if(m_currentBasket.currentProfit > 0)
        m_profitableBaskets++;
    
    if(m_currentBasket.currentProfit > m_maxBasketProfit)
        m_maxBasketProfit = m_currentBasket.currentProfit;
    
    if(m_currentBasket.currentProfit < m_maxBasketLoss)
        m_maxBasketLoss = m_currentBasket.currentProfit;
    
    //--- Update daily statistics
    m_dailyProfit += m_currentBasket.currentProfit;
    m_basketsCompleted++;
    
    //--- Calculate average basket profit
    if(m_totalBaskets > 0)
        m_averageBasketProfit = m_totalProfit / m_totalBaskets;
    
    Print("Basket closed: ", m_currentBasket.basketId, 
          " with profit: $", DoubleToString(m_currentBasket.currentProfit, 2),
          " (", m_currentBasket.tradesCount, " trades)");
    
    //--- Deactivate basket
    m_currentBasket.isActive = false;
}

//+------------------------------------------------------------------+
//| Update basket statistics                                         |
//+------------------------------------------------------------------+
void CBasketManager::UpdateBasketStatistics()
{
    //--- Count winning and losing trades based on closed positions
    //--- This would require tracking closed positions, which is complex
    //--- For now, we'll base it on current profit
    if(m_currentBasket.currentProfit > 0)
        m_currentBasket.winningTrades = m_currentBasket.tradesCount;
    else if(m_currentBasket.currentProfit < 0)
        m_currentBasket.losingTrades = m_currentBasket.tradesCount;
}

//+------------------------------------------------------------------+
//| Add basket to history                                            |
//+------------------------------------------------------------------+
void CBasketManager::AddToHistory(const BASKET_INFO& basket)
{
    int size = ArraySize(m_basketHistory);
    
    //--- Add new basket to the end
    ArrayResize(m_basketHistory, size + 1);
    m_basketHistory[size] = basket;
    
    //--- Remove old baskets if history is too large
    if(ArraySize(m_basketHistory) > m_maxHistorySize)
    {
        //--- Shift array to remove oldest basket
        for(int i = 0; i < m_maxHistorySize - 1; i++)
        {
            m_basketHistory[i] = m_basketHistory[i + 1];
        }
        ArrayResize(m_basketHistory, m_maxHistorySize);
    }
}

//+------------------------------------------------------------------+
//| Check for new day                                                |
//+------------------------------------------------------------------+
void CBasketManager::CheckNewDay()
{
    if(IsNewDay())
    {
        ResetDaily();
        Print("New day detected - daily statistics reset");
    }
}

//+------------------------------------------------------------------+
//| Check if it's a new day                                          |
//+------------------------------------------------------------------+
bool CBasketManager::IsNewDay()
{
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    
    currentTime.hour = 0;
    currentTime.min = 0;
    currentTime.sec = 0;
    datetime today = StructToTime(currentTime);
    
    return (today > m_currentDay);
}

//+------------------------------------------------------------------+
//| Reset daily statistics                                           |
//+------------------------------------------------------------------+
void CBasketManager::ResetDaily()
{
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    
    currentTime.hour = 0;
    currentTime.min = 0;
    currentTime.sec = 0;
    m_currentDay = StructToTime(currentTime);
    
    m_dailyProfit = 0;
    m_basketsCompleted = 0;
}

//+------------------------------------------------------------------+
//| Calculate daily statistics                                       |
//+------------------------------------------------------------------+
void CBasketManager::CalculateDailyStats()
{
    //--- Daily profit is already tracked in m_dailyProfit
    //--- This method can be expanded for more complex daily calculations
}

//+------------------------------------------------------------------+
//| Get basket progress as percentage                                |
//+------------------------------------------------------------------+
double CBasketManager::GetBasketProgress()
{
    if(!m_currentBasket.isActive || m_currentBasket.targetProfit <= 0)
        return 0;
    
    double progress = (m_currentBasket.currentProfit / m_currentBasket.targetProfit) * 100.0;
    
    //--- Cap at 100%
    if(progress > 100.0)
        progress = 100.0;
    
    return progress;
}

//+------------------------------------------------------------------+
//| Get profitable basket percentage                                 |
//+------------------------------------------------------------------+
double CBasketManager::GetProfitableBasketPercentage()
{
    if(m_totalBaskets == 0)
        return 0;
    
    return (double)m_profitableBaskets / m_totalBaskets * 100.0;
}

//+------------------------------------------------------------------+
//| Get current drawdown                                             |
//+------------------------------------------------------------------+
double CBasketManager::GetCurrentDrawdown()
{
    if(!m_currentBasket.isActive)
        return 0;
    
    return m_currentBasket.maxDrawdown;
}

//+------------------------------------------------------------------+
//| Check if daily target is reached                                 |
//+------------------------------------------------------------------+
bool CBasketManager::IsDailyTargetReached()
{
    return (m_dailyProfit >= m_dailyTarget);
}

//+------------------------------------------------------------------+
//| Get basket information                                           |
//+------------------------------------------------------------------+
string CBasketManager::GetBasketInfo()
{
    string info = "Current Basket Information:\n";
    info += "==========================\n";
    info += "Basket ID: " + m_currentBasket.basketId + "\n";
    info += "Status: " + (m_currentBasket.isActive ? "ACTIVE" : "CLOSED") + "\n";
    info += "Start Time: " + TimeToString(m_currentBasket.startDate, TIME_DATE|TIME_MINUTES) + "\n";
    info += "Target Profit: $" + DoubleToString(m_currentBasket.targetProfit, 2) + "\n";
    info += "Current Profit: $" + DoubleToString(m_currentBasket.currentProfit, 2) + "\n";
    info += "Progress: " + DoubleToString(GetBasketProgress(), 1) + "%\n";
    info += "Trades Count: " + IntegerToString(m_currentBasket.tradesCount) + "\n";
    info += "Max Profit: $" + DoubleToString(m_currentBasket.maxProfit, 2) + "\n";
    info += "Max Drawdown: $" + DoubleToString(m_currentBasket.maxDrawdown, 2) + "\n";
    
    return info;
}

//+------------------------------------------------------------------+
//| Get daily information                                             |
//+------------------------------------------------------------------+
string CBasketManager::GetDailyInfo()
{
    string info = "Daily Information:\n";
    info += "==================\n";
    info += "Current Day: " + TimeToString(m_currentDay, TIME_DATE) + "\n";
    info += "Daily Target: $" + DoubleToString(m_dailyTarget, 2) + "\n";
    info += "Daily Profit: $" + DoubleToString(m_dailyProfit, 2) + "\n";
    info += "Baskets Completed: " + IntegerToString(m_basketsCompleted) + "\n";
    info += "Target Reached: " + (IsDailyTargetReached() ? "YES" : "NO") + "\n";
    
    return info;
}

//+------------------------------------------------------------------+
//| Get statistics information                                        |
//+------------------------------------------------------------------+
string CBasketManager::GetStatisticsInfo()
{
    string info = "Basket Statistics:\n";
    info += "==================\n";
    info += "Total Baskets: " + IntegerToString(m_totalBaskets) + "\n";
    info += "Profitable Baskets: " + IntegerToString(m_profitableBaskets) + "\n";
    info += "Win Rate: " + DoubleToString(GetProfitableBasketPercentage(), 1) + "%\n";
    info += "Total Profit: $" + DoubleToString(m_totalProfit, 2) + "\n";
    info += "Average Basket Profit: $" + DoubleToString(m_averageBasketProfit, 2) + "\n";
    info += "Max Basket Profit: $" + DoubleToString(m_maxBasketProfit, 2) + "\n";
    info += "Max Basket Loss: $" + DoubleToString(m_maxBasketLoss, 2) + "\n";
    info += "History Size: " + IntegerToString(ArraySize(m_basketHistory)) + "\n";
    
    return info;
}

//+------------------------------------------------------------------+
//| Get basket from history                                          |
//+------------------------------------------------------------------+
BASKET_INFO CBasketManager::GetBasketFromHistory(int index)
{
    if(index < 0 || index >= ArraySize(m_basketHistory))
    {
        BASKET_INFO emptyBasket;
        ZeroMemory(emptyBasket);
        return emptyBasket;
    }
    
    return m_basketHistory[index];
}

//+------------------------------------------------------------------+
//| Clear history                                                    |
//+------------------------------------------------------------------+
void CBasketManager::ClearHistory()
{
    ArrayResize(m_basketHistory, 0);
    Print("Basket history cleared");
}

//+------------------------------------------------------------------+
//| Reset basket                                                     |
//+------------------------------------------------------------------+
void CBasketManager::ResetBasket()
{
    if(m_currentBasket.isActive)
        CloseBasket();
    
    StartNewBasket();
}

//+------------------------------------------------------------------+
//| Set daily target                                                 |
//+------------------------------------------------------------------+
void CBasketManager::SetDailyTarget(double target)
{
    m_dailyTarget = target;
    m_profitTarget = target;
    
    Print("Daily target updated to: $", DoubleToString(target, 2));
}

//+------------------------------------------------------------------+
//| Update basket manager                                            |
//+------------------------------------------------------------------+
void CBasketManager::Update()
{
    //--- Check for new day
    CheckNewDay();
    
    //--- Update basket profit
    UpdateBasketProfit();
    
    //--- Check if target reached
    if(CheckBasketTarget())
    {
        Print("Basket target reached: $", DoubleToString(m_currentBasket.currentProfit, 2));
    }
}

//+------------------------------------------------------------------+
//| Get current basket profit                                        |
//+------------------------------------------------------------------+
double CBasketManager::GetCurrentBasketProfit()
{
    if(!m_currentBasket.isActive)
        return 0;
    
    return m_currentBasket.currentProfit;
}
//+------------------------------------------------------------------+