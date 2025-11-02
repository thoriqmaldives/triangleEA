//+------------------------------------------------------------------+
//|                                             TriangleRiskManager.mqh |
//|                        Copyright 2024, Triangle Trading System    |
//|                                      Version: 1.00               |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Triangle Trading System"
#property link      ""
#property version   "1.00"
#property strict

//--- Risk method enumeration
enum ENUM_RISK_METHOD
{
    PERCENT_BALANCE,        // Risk % of account balance
    FIXED_LOTS,            // Fixed lot size
    FIXED_DOLLAR           // Fixed dollar amount risk
};

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
    //--- Risk parameters
    ENUM_RISK_METHOD    m_method;
    double              m_riskPercent;
    double              m_fixedLots;
    double              m_fixedDollarRisk;
    double              m_stopLossPercent;
    double              m_takeProfitRR;
    double              m_breakEvenRR;
    
    //--- Account information
    double              m_accountBalance;
    double              m_accountEquity;
    double              m_accountMargin;
    
    //--- Symbol information
    string              m_symbol;
    double              m_point;
    double              m_tickValue;
    double              m_tickSize;
    double              m_minLot;
    double              m_maxLot;
    double              m_lotStep;
    int                 m_digits;
    
    //--- Helper methods
    void                UpdateAccountInfo();
    void                UpdateSymbolInfo(string symbol);
    double              CalculateRiskAmount();
    double              NormalizeLotSize(double lots);
    bool                ValidatePositionSize(double positionSize, double stopLoss);
    
public:
    //--- Constructor/Destructor
    CRiskManager();
    ~CRiskManager();
    
    //--- Initialization
    void                Init(ENUM_RISK_METHOD method, double riskPercent, double fixedLots, 
                            double fixedDollarRisk, double slPercent, double tpRR, double beRR);
    
    //--- Position sizing methods
    double              CalculatePositionSize(string symbol, double orSize);
    double              CalculatePositionSizeByPercent(double riskAmount, double stopLossPoints);
    double              CalculatePositionSizeByDollar(double dollarRisk, double stopLossPoints);
    
    //--- Stop Loss and Take Profit methods
    double              CalculateStopLoss(double entryPrice, double orSize, bool isLong);
    double              CalculateTakeProfit(double entryPrice, double stopLoss, bool isLong);
    double              CalculateBreakEvenPrice(double entryPrice, double stopLoss, bool isLong);
    
    //--- Risk validation methods
    bool                ValidateRisk(double positionSize, double stopLoss);
    double              GetAccountRiskAmount();
    double              GetMaxAllowedLoss();
    
    //--- Utility methods
    double              GetAccountBalance() { return m_accountBalance; }
    double              GetAccountEquity() { return m_accountEquity; }
    double              GetRiskPercent() { return m_riskPercent; }
    ENUM_RISK_METHOD    GetRiskMethod() { return m_method; }
    string              GetRiskMethodString();
    double              GetPipValue(double lots);
    double              PointsToPips(double points);
    double              PipsToPoints(double pips);
    
    //--- Update methods
    void                Update();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
    m_method = PERCENT_BALANCE;
    m_riskPercent = 1.0;
    m_fixedLots = 0.1;
    m_fixedDollarRisk = 50.0;
    m_stopLossPercent = 50.0;
    m_takeProfitRR = 3.5;
    m_breakEvenRR = 2.0;
    
    m_accountBalance = 0;
    m_accountEquity = 0;
    m_accountMargin = 0;
    
    m_symbol = "";
    m_point = 0;
    m_tickValue = 0;
    m_tickSize = 0;
    m_minLot = 0;
    m_maxLot = 0;
    m_lotStep = 0;
    m_digits = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
}

//+------------------------------------------------------------------+
//| Initialize risk manager                                          |
//+------------------------------------------------------------------+
void CRiskManager::Init(ENUM_RISK_METHOD method, double riskPercent, double fixedLots, 
                       double fixedDollarRisk, double slPercent, double tpRR, double beRR)
{
    m_method = method;
    m_riskPercent = riskPercent;
    m_fixedLots = fixedLots;
    m_fixedDollarRisk = fixedDollarRisk;
    m_stopLossPercent = slPercent;
    m_takeProfitRR = tpRR;
    m_breakEvenRR = beRR;
    
    //--- Update account and symbol information
    UpdateAccountInfo();
    
    Print("Risk Manager initialized - Method: ", GetRiskMethodString(), 
          ", Risk %: ", DoubleToString(m_riskPercent, 2),
          ", Fixed Lots: ", DoubleToString(m_fixedLots, 2),
          ", Fixed Dollar Risk: $", DoubleToString(m_fixedDollarRisk, 2));
}

//+------------------------------------------------------------------+
//| Update account information                                       |
//+------------------------------------------------------------------+
void CRiskManager::UpdateAccountInfo()
{
    m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    m_accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    m_accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
}

//+------------------------------------------------------------------+
//| Update symbol information                                        |
//+------------------------------------------------------------------+
void CRiskManager::UpdateSymbolInfo(string symbol)
{
    m_symbol = symbol;
    m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    m_tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    m_tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    m_minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    m_maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    m_lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    m_digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(string symbol, double orSize)
{
    //--- Update symbol information
    UpdateSymbolInfo(symbol);
    UpdateAccountInfo();
    
    //--- Calculate stop loss distance (50% of OR size)
    double stopLossDistance = orSize * (m_stopLossPercent / 100.0);
    double stopLossPoints = stopLossDistance / m_point;
    
    double positionSize = 0;
    
    switch(m_method)
    {
        case PERCENT_BALANCE:
        {
            double riskAmount = CalculateRiskAmount();
            positionSize = CalculatePositionSizeByPercent(riskAmount, stopLossPoints);
            break;
        }
        
        case FIXED_LOTS:
        {
            positionSize = m_fixedLots;
            break;
        }
        
        case FIXED_DOLLAR:
        {
            positionSize = CalculatePositionSizeByDollar(m_fixedDollarRisk, stopLossPoints);
            break;
        }
    }
    
    //--- Normalize and validate position size
    positionSize = NormalizeLotSize(positionSize);
    
    if(!ValidatePositionSize(positionSize, stopLossDistance))
    {
        Print("Invalid position size calculated: ", DoubleToString(positionSize, 2), 
              ", using minimum lot size");
        positionSize = m_minLot;
    }
    
    return positionSize;
}

//+------------------------------------------------------------------+
//| Calculate risk amount based on percentage                        |
//+------------------------------------------------------------------+
double CRiskManager::CalculateRiskAmount()
{
    double riskAmount = 0;
    
    switch(m_method)
    {
        case PERCENT_BALANCE:
            riskAmount = m_accountBalance * (m_riskPercent / 100.0);
            break;
            
        case FIXED_LOTS:
            //--- Calculate risk for fixed lots
            riskAmount = m_fixedLots * GetPipValue(m_fixedLots) * 100; // Assume 100 pip risk
            break;
            
        case FIXED_DOLLAR:
            riskAmount = m_fixedDollarRisk;
            break;
    }
    
    return riskAmount;
}

//+------------------------------------------------------------------+
//| Calculate position size by percentage risk                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSizeByPercent(double riskAmount, double stopLossPoints)
{
    if(stopLossPoints <= 0)
        return 0;
    
    //--- Calculate pip value
    double pipValue = GetPipValue(1.0); // Pip value for 1 lot
    
    //--- Calculate position size
    double positionSize = riskAmount / (stopLossPoints * pipValue);
    
    return positionSize;
}

//+------------------------------------------------------------------+
//| Calculate position size by fixed dollar risk                     |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSizeByDollar(double dollarRisk, double stopLossPoints)
{
    if(stopLossPoints <= 0)
        return 0;
    
    //--- Calculate pip value
    double pipValue = GetPipValue(1.0); // Pip value for 1 lot
    
    //--- Calculate position size
    double positionSize = dollarRisk / (stopLossPoints * pipValue);
    
    return positionSize;
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+
double CRiskManager::CalculateStopLoss(double entryPrice, double orSize, bool isLong)
{
    double stopLossDistance = orSize * (m_stopLossPercent / 100.0);
    
    if(isLong)
    {
        return entryPrice - stopLossDistance;
    }
    else
    {
        return entryPrice + stopLossDistance;
    }
}

//+------------------------------------------------------------------+
//| Calculate take profit                                            |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTakeProfit(double entryPrice, double stopLoss, bool isLong)
{
    double riskDistance = MathAbs(entryPrice - stopLoss);
    double profitDistance = riskDistance * m_takeProfitRR;
    
    if(isLong)
    {
        return entryPrice + profitDistance;
    }
    else
    {
        return entryPrice - profitDistance;
    }
}

//+------------------------------------------------------------------+
//| Calculate break even price                                       |
//+------------------------------------------------------------------+
double CRiskManager::CalculateBreakEvenPrice(double entryPrice, double stopLoss, bool isLong)
{
    //--- Break even is simply the entry price
    return entryPrice;
}

//+------------------------------------------------------------------+
//| Normalize lot size                                               |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeLotSize(double lots)
{
    //--- Round to lot step
    double normalizedLots = MathRound(lots / m_lotStep) * m_lotStep;
    
    //--- Ensure within min/max limits
    if(normalizedLots < m_minLot)
        normalizedLots = m_minLot;
    
    if(normalizedLots > m_maxLot)
        normalizedLots = m_maxLot;
    
    //--- Round to 2 decimal places
    normalizedLots = NormalizeDouble(normalizedLots, 2);
    
    return normalizedLots;
}

//+------------------------------------------------------------------+
//| Validate position size                                           |
//+------------------------------------------------------------------+
bool CRiskManager::ValidatePositionSize(double positionSize, double stopLoss)
{
    //--- Check minimum lot size
    if(positionSize < m_minLot)
        return false;
    
    //--- Check maximum lot size
    if(positionSize > m_maxLot)
        return false;
    
    //--- Check margin requirements
    double marginRequired = 0;
    if(!OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, positionSize,
                       SymbolInfoDouble(m_symbol, SYMBOL_ASK), marginRequired))
    {
        Print("Failed to calculate margin requirement");
        return false;
    }
    
    if(marginRequired > m_accountEquity * 0.5) // Don't use more than 50% of equity for margin
    {
        Print("Position size requires too much margin: $", DoubleToString(marginRequired, 2), 
              ", Available equity: $", DoubleToString(m_accountEquity, 2));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate risk                                                    |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateRisk(double positionSize, double stopLoss)
{
    //--- Calculate potential loss
    double entryPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    double potentialLoss = MathAbs(entryPrice - stopLoss) * positionSize * GetPipValue(positionSize);
    
    //--- Check against account balance
    if(potentialLoss > m_accountBalance * 0.1) // Don't risk more than 10% of balance on single trade
    {
        Print("Potential loss too high: $", DoubleToString(potentialLoss, 2), 
              ", Max allowed: $", DoubleToString(m_accountBalance * 0.1, 2));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get account risk amount                                          |
//+------------------------------------------------------------------+
double CRiskManager::GetAccountRiskAmount()
{
    return CalculateRiskAmount();
}

//+------------------------------------------------------------------+
//| Get maximum allowed loss                                         |
//+------------------------------------------------------------------+
double CRiskManager::GetMaxAllowedLoss()
{
    return m_accountBalance * 0.1; // 10% of balance
}

//+------------------------------------------------------------------+
//| Get risk method as string                                        |
//+------------------------------------------------------------------+
string CRiskManager::GetRiskMethodString()
{
    switch(m_method)
    {
        case PERCENT_BALANCE: return "PERCENT_BALANCE";
        case FIXED_LOTS:       return "FIXED_LOTS";
        case FIXED_DOLLAR:     return "FIXED_DOLLAR";
        default:               return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get pip value                                                    |
//+------------------------------------------------------------------+
double CRiskManager::GetPipValue(double lots)
{
    //--- For most forex pairs, 1 pip = 10 points
    double pipValue = m_tickValue * (10.0 / m_tickSize) * lots;
    
    return pipValue;
}

//+------------------------------------------------------------------+
//| Convert points to pips                                           |
//+------------------------------------------------------------------+
double CRiskManager::PointsToPips(double points)
{
    return points / 10.0;
}

//+------------------------------------------------------------------+
//| Convert pips to points                                           |
//+------------------------------------------------------------------+
double CRiskManager::PipsToPoints(double pips)
{
    return pips * 10.0;
}

//+------------------------------------------------------------------+
//| Update risk manager                                              |
//+------------------------------------------------------------------+
void CRiskManager::Update()
{
    UpdateAccountInfo();
}
//+------------------------------------------------------------------+