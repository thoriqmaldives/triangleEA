//+------------------------------------------------------------------+
//|                                           TriangleIndicators.mqh |
//|                        Copyright 2024, Triangle Trading System    |
//|                                      Version: 1.00               |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Triangle Trading System"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Indicators Manager Class                                         |
//+------------------------------------------------------------------+
class CIndicatorsManager
{
private:
    //--- Symbol and timeframes
    string              m_symbol;
    ENUM_TIMEFRAMES     m_h1Timeframe;
    ENUM_TIMEFRAMES     m_m5Timeframe;
    
    //--- EMA 100 H1 for trend
    int                 m_ema100Handle;
    double              m_ema100Buffer[];
    int                 m_ema100Period;
    
    //--- Moving Averages M5
    int                 m_maFastHandle;
    int                 m_maSlowHandle;
    double              m_maFastBuffer[];
    double              m_maSlowBuffer[];
    int                 m_maFastPeriod;
    int                 m_maSlowPeriod;
    
    //--- Opening Range
    double              m_orHigh;
    double              m_orLow;
    double              m_orSize;
    bool                m_orCalculated;
    datetime            m_orDate;
    
    //--- Chart objects for OR lines
    string              m_orHighLineName;
    string              m_orLowLineName;
    color               m_orHighLineColor;
    color               m_orLowLineColor;
    int                 m_orLineWidth;
    ENUM_LINE_STYLE     m_orLineStyle;
    
    //--- Chart objects for time labels
    string              m_orStartLabelName;
    string              m_orEndLabelName;
    string              m_tradingStartLabelName;
    string              m_tradingEndLabelName;
    color               m_timeLabelColor;
    int                 m_timeLabelFontSize;
    string              m_timeLabelFont;
    
    //--- Buffer sizes
    int                 m_bufferSize;
    
    //--- Helper methods
    bool                InitializeEMA100();
    bool                InitializeMovingAverages();
    void                ResizeBuffers(int size);
    bool                CopyIndicatorData(int handle, double &buffer[], int count);
    
public:
    //--- Constructor/Destructor
    CIndicatorsManager();
    ~CIndicatorsManager();
    
    //--- Initialization
    bool                Init(string symbol, ENUM_TIMEFRAMES h1Timeframe, ENUM_TIMEFRAMES m5Timeframe,
                            int ema100Period, int maFastPeriod, int maSlowPeriod);
    void                Deinit();
    
    //--- Update methods
    void                Update();
    
    //--- EMA 100 methods
    double              GetEMA100Value(int shift);
    bool                IsEMA100Bullish(int shift);
    bool                IsEMA100Bearish(int shift);
    bool                IsPriceAboveEMA100(int shift);
    bool                IsPriceBelowEMA100(int shift);
    
    //--- Moving Average methods
    double              GetMAFast(int shift);
    double              GetMASlow(int shift);
    bool                IsMABullish();
    bool                IsMABearish();
    double              GetMADifference();
    
    //--- Opening Range methods
    bool                CalculateOpeningRange(datetime startDate, datetime endDate);
    void                DrawORLines();
    void                DeleteORLines();
    void                UpdateORLineProperties(color highColor, color lowColor, int width, ENUM_LINE_STYLE style);
    void                UpdateORLines();
    void                ForceRedrawORLines();
    void                DrawTimeLabels(datetime orStartTime, datetime orEndTime, datetime tradingStartTime, datetime tradingEndTime);
    void                DeleteTimeLabels();
    void                UpdateTimeLabelProperties(color labelColor, int fontSize, string font);
    double              GetORHigh() { return m_orHigh; }
    double              GetORLow() { return m_orLow; }
    double              GetORSize() { return m_orSize; }
    bool                IsORCalculated() { return m_orCalculated; }
    datetime            GetORDate() { return m_orDate; }
    
    //--- Utility methods
    bool                IsDataReady();
    string              GetIndicatorStatus();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIndicatorsManager::CIndicatorsManager()
{
    m_symbol = "";
    m_h1Timeframe = PERIOD_H1;
    m_m5Timeframe = PERIOD_M5;
    
    m_ema100Handle = INVALID_HANDLE;
    m_maFastHandle = INVALID_HANDLE;
    m_maSlowHandle = INVALID_HANDLE;
    
    m_ema100Period = 100;
    m_maFastPeriod = 20;
    m_maSlowPeriod = 50;
    
    m_orHigh = 0;
    m_orLow = 0;
    m_orSize = 0;
    m_orCalculated = false;
    m_orDate = 0;
    
    //--- Initialize OR line properties
    m_orHighLineName = "Triangle_OR_High";
    m_orLowLineName = "Triangle_OR_Low";
    m_orHighLineColor = clrRed;
    m_orLowLineColor = clrGreen;
    m_orLineWidth = 1;
    m_orLineStyle = STYLE_SOLID;
    
    //--- Initialize time label properties
    m_orStartLabelName = "Triangle_OR_Start";
    m_orEndLabelName = "Triangle_OR_End";
    m_tradingStartLabelName = "Triangle_Trading_Start";
    m_tradingEndLabelName = "Triangle_Trading_End";
    m_timeLabelColor = clrYellow;
    m_timeLabelFontSize = 8;
    m_timeLabelFont = "Arial";
    
    m_bufferSize = 500;
    
    //--- Initialize arrays
    ArrayResize(m_ema100Buffer, m_bufferSize);
    ArrayResize(m_maFastBuffer, m_bufferSize);
    ArrayResize(m_maSlowBuffer, m_bufferSize);
    
    ArraySetAsSeries(m_ema100Buffer, true);
    ArraySetAsSeries(m_maFastBuffer, true);
    ArraySetAsSeries(m_maSlowBuffer, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CIndicatorsManager::~CIndicatorsManager()
{
    Deinit();
}

//+------------------------------------------------------------------+
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool CIndicatorsManager::Init(string symbol, ENUM_TIMEFRAMES h1Timeframe, ENUM_TIMEFRAMES m5Timeframe,
                             int ema100Period, int maFastPeriod, int maSlowPeriod)
{
    m_symbol = symbol;
    m_h1Timeframe = h1Timeframe;
    m_m5Timeframe = m5Timeframe;
    m_ema100Period = ema100Period;
    m_maFastPeriod = maFastPeriod;
    m_maSlowPeriod = maSlowPeriod;
    
    //--- Initialize EMA 100
    if(!InitializeEMA100())
    {
        Print("Failed to initialize EMA 100 indicator");
        return false;
    }
    
    //--- Initialize Moving Averages
    if(!InitializeMovingAverages())
    {
        Print("Failed to initialize Moving Average indicators");
        return false;
    }
    
    Print("Indicators Manager initialized for ", symbol);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize EMA 100 indicator                                     |
//+------------------------------------------------------------------+
bool CIndicatorsManager::InitializeEMA100()
{
    //--- Create EMA 100 indicator
    m_ema100Handle = iMA(m_symbol, m_h1Timeframe, m_ema100Period, 0, MODE_EMA, PRICE_CLOSE);
    
    if(m_ema100Handle == INVALID_HANDLE)
    {
        Print("Error creating EMA 100 indicator. Error code: ", GetLastError());
        return false;
    }
    
    //--- Check if we have at least some data
    int ema100Calculated = BarsCalculated(m_ema100Handle);
    if(ema100Calculated < 10) // Need at least some bars
    {
        Print("Warning: EMA 100 indicator has insufficient data (", ema100Calculated, " bars)");
        // Continue anyway as we'll get more data as time passes
    }
    
    Print("EMA 100 indicator initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Moving Averages                                       |
//+------------------------------------------------------------------+
bool CIndicatorsManager::InitializeMovingAverages()
{
    //--- Create Fast Moving Average
    m_maFastHandle = iMA(m_symbol, m_m5Timeframe, m_maFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    if(m_maFastHandle == INVALID_HANDLE)
    {
        Print("Error creating Fast MA indicator. Error code: ", GetLastError());
        return false;
    }
    
    //--- Create Slow Moving Average
    m_maSlowHandle = iMA(m_symbol, m_m5Timeframe, m_maSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    if(m_maSlowHandle == INVALID_HANDLE)
    {
        Print("Error creating Slow MA indicator. Error code: ", GetLastError());
        return false;
    }
    
    //--- Check if we have at least some data
    int maFastCalculated = BarsCalculated(m_maFastHandle);
    int maSlowCalculated = BarsCalculated(m_maSlowHandle);
    
    if(maFastCalculated < 10 || maSlowCalculated < 10)
    {
        Print("Warning: Moving Average indicators have insufficient data (Fast: ",
              maFastCalculated, ", Slow: ", maSlowCalculated, " bars)");
        // Continue anyway as we'll get more data as time passes
    }
    
    Print("Moving Average indicators initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check if indicator data is ready                                 |
//+------------------------------------------------------------------+
bool CIndicatorsManager::IsDataReady()
{
    if(m_ema100Handle == INVALID_HANDLE ||
       m_maFastHandle == INVALID_HANDLE ||
       m_maSlowHandle == INVALID_HANDLE)
        return false;
    
    //--- Check if indicators have been calculated
    int ema100Calculated = BarsCalculated(m_ema100Handle);
    int maFastCalculated = BarsCalculated(m_maFastHandle);
    int maSlowCalculated = BarsCalculated(m_maSlowHandle);
    
    //--- For new symbols or low data situations, be more lenient
    int ema100Required = MathMin(m_ema100Period, 50); // Reduce requirement for EMA 100
    int maFastRequired = MathMin(m_maFastPeriod, 20); // Reduce requirement for fast MA
    int maSlowRequired = MathMin(m_maSlowPeriod, 30); // Reduce requirement for slow MA
    
    if(ema100Calculated < ema100Required)
        return false;
    
    if(maFastCalculated < maFastRequired)
        return false;
    
    if(maSlowCalculated < maSlowRequired)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Update indicator data                                            |
//+------------------------------------------------------------------+
void CIndicatorsManager::Update()
{
    //--- Check if handles are valid
    if(m_ema100Handle == INVALID_HANDLE ||
       m_maFastHandle == INVALID_HANDLE ||
       m_maSlowHandle == INVALID_HANDLE)
        return;
    
    //--- Update EMA 100 data
    int ema100Copied = CopyBuffer(m_ema100Handle, 0, 0, m_bufferSize, m_ema100Buffer);
    if(ema100Copied <= 0)
    {
        Print("Error copying EMA 100 buffer. Error: ", GetLastError());
        return;
    }
    
    //--- Update Moving Average data
    int maFastCopied = CopyBuffer(m_maFastHandle, 0, 0, m_bufferSize, m_maFastBuffer);
    if(maFastCopied <= 0)
    {
        Print("Error copying Fast MA buffer. Error: ", GetLastError());
        return;
    }
    
    int maSlowCopied = CopyBuffer(m_maSlowHandle, 0, 0, m_bufferSize, m_maSlowBuffer);
    if(maSlowCopied <= 0)
    {
        Print("Error copying Slow MA buffer. Error: ", GetLastError());
        return;
    }
    
    //--- Set buffers as series
    ArraySetAsSeries(m_ema100Buffer, true);
    ArraySetAsSeries(m_maFastBuffer, true);
    ArraySetAsSeries(m_maSlowBuffer, true);
}

//+------------------------------------------------------------------+
//| Get EMA 100 value                                                |
//+------------------------------------------------------------------+
double CIndicatorsManager::GetEMA100Value(int shift)
{
    if(shift >= ArraySize(m_ema100Buffer) || shift < 0 || ArraySize(m_ema100Buffer) == 0)
        return 0;
    
    return m_ema100Buffer[shift];
}

//+------------------------------------------------------------------+
//| Check if EMA 100 is bullish (price above EMA)                    |
//+------------------------------------------------------------------+
bool CIndicatorsManager::IsEMA100Bullish(int shift)
{
    if(shift >= ArraySize(m_ema100Buffer) || shift < 0 || ArraySize(m_ema100Buffer) == 0)
        return false;
    
    double closePrice = iClose(m_symbol, m_h1Timeframe, shift);
    double ema100 = m_ema100Buffer[shift];
    
    //--- If EMA value is 0 (not calculated yet), return false
    if(ema100 == 0)
        return false;
    
    return (closePrice > ema100);
}

//+------------------------------------------------------------------+
//| Check if EMA 100 is bearish (price below EMA)                    |
//+------------------------------------------------------------------+
bool CIndicatorsManager::IsEMA100Bearish(int shift)
{
    if(shift >= ArraySize(m_ema100Buffer) || shift < 0 || ArraySize(m_ema100Buffer) == 0)
        return false;
    
    double closePrice = iClose(m_symbol, m_h1Timeframe, shift);
    double ema100 = m_ema100Buffer[shift];
    
    //--- If EMA value is 0 (not calculated yet), return false
    if(ema100 == 0)
        return false;
    
    return (closePrice < ema100);
}

//+------------------------------------------------------------------+
//| Check if price is above EMA 100                                   |
//+------------------------------------------------------------------+
bool CIndicatorsManager::IsPriceAboveEMA100(int shift)
{
    return IsEMA100Bullish(shift);
}

//+------------------------------------------------------------------+
//| Check if price is below EMA 100                                   |
//+------------------------------------------------------------------+
bool CIndicatorsManager::IsPriceBelowEMA100(int shift)
{
    return IsEMA100Bearish(shift);
}

//+------------------------------------------------------------------+
//| Get Fast Moving Average value                                    |
//+------------------------------------------------------------------+
double CIndicatorsManager::GetMAFast(int shift)
{
    if(shift >= ArraySize(m_maFastBuffer) || shift < 0)
        return 0;
    
    return m_maFastBuffer[shift];
}

//+------------------------------------------------------------------+
//| Get Slow Moving Average value                                    |
//+------------------------------------------------------------------+
double CIndicatorsManager::GetMASlow(int shift)
{
    if(shift >= ArraySize(m_maSlowBuffer) || shift < 0)
        return 0;
    
    return m_maSlowBuffer[shift];
}

//+------------------------------------------------------------------+
//| Check if MAs are bullish                                          |
//+------------------------------------------------------------------+
bool CIndicatorsManager::IsMABullish()
{
    double maFast = GetMAFast(0);
    double maSlow = GetMASlow(0);
    
    return (maFast > maSlow);
}

//+------------------------------------------------------------------+
//| Check if MAs are bearish                                          |
//+------------------------------------------------------------------+
bool CIndicatorsManager::IsMABearish()
{
    double maFast = GetMAFast(0);
    double maSlow = GetMASlow(0);
    
    return (maFast < maSlow);
}

//+------------------------------------------------------------------+
//| Get MA difference                                                |
//+------------------------------------------------------------------+
double CIndicatorsManager::GetMADifference()
{
    double maFast = GetMAFast(0);
    double maSlow = GetMASlow(0);
    
    return (maFast - maSlow);
}

//+------------------------------------------------------------------+
//| Calculate opening range                                          |
//+------------------------------------------------------------------+
bool CIndicatorsManager::CalculateOpeningRange(datetime startDate, datetime endDate)
{
    m_orHigh = 0;
    m_orLow = DBL_MAX;
    m_orSize = 0;
    m_orCalculated = false;
    m_orDate = startDate;
    
    //--- Debug: Print input parameters
    Print("DEBUG: Calculating OR from ", TimeToString(startDate), " to ", TimeToString(endDate));
    
    //--- Convert to M5 timeframe
    int startShift = iBarShift(m_symbol, m_m5Timeframe, startDate);
    int endShift = iBarShift(m_symbol, m_m5Timeframe, endDate);
    
    Print("DEBUG: Bar shifts - Start: ", startShift, ", End: ", endShift);
    
    if(startShift == -1 || endShift == -1)
    {
        Print("Cannot find bars for opening range period");
        return false;
    }
    
    //--- Check if we have enough bars for a meaningful OR
    if(startShift - endShift < 2)
    {
        Print("Not enough bars for opening range calculation. Need at least 2 bars, got ", (startShift - endShift + 1));
        return false;
    }
    
    //--- Iterate through bars in the opening range
    int barCount = 0;
    for(int i = startShift; i >= endShift; i--)
    {
        double high = iHigh(m_symbol, m_m5Timeframe, i);
        double low = iLow(m_symbol, m_m5Timeframe, i);
        
        Print("DEBUG: Bar ", i, " - High: ", DoubleToString(high, 5), ", Low: ", DoubleToString(low, 5));
        
        if(high > m_orHigh)
        {
            m_orHigh = high;
            Print("DEBUG: New OR High: ", DoubleToString(m_orHigh, 5));
        }
        
        if(low < m_orLow)
        {
            m_orLow = low;
            Print("DEBUG: New OR Low: ", DoubleToString(m_orLow, 5));
        }
        
        barCount++;
    }
    
    Print("DEBUG: Processed ", barCount, " bars for OR calculation");
    
    //--- Calculate range size
    m_orSize = m_orHigh - m_orLow;
    
    //--- Validate range
    if(m_orSize <= 0 || m_orHigh == 0 || m_orLow == DBL_MAX)
    {
        Print("Invalid opening range calculated: High=", m_orHigh, ", Low=", m_orLow, ", Size=", m_orSize);
        return false;
    }
    
    //--- Check if OR size is too small (less than 1 pip)
    if(m_orSize * 10000 < 1.0)
    {
        Print("Warning: Opening range size is very small (", DoubleToString(m_orSize * 10000, 1), " pips)");
        //--- Expand OR to minimum 1 pip
        double halfPip = 0.0001 / 2.0;
        m_orHigh += halfPip;
        m_orLow -= halfPip;
        m_orSize = m_orHigh - m_orLow;
        Print("Expanded OR to minimum 1 pip: High=", DoubleToString(m_orHigh, 5),
              ", Low=", DoubleToString(m_orLow, 5),
              ", Size=", DoubleToString(m_orSize * 10000, 1), " pips");
    }
    
    m_orCalculated = true;
    
    Print("Opening Range calculated: High=", DoubleToString(m_orHigh, 5),
          ", Low=", DoubleToString(m_orLow, 5),
          ", Size=", DoubleToString(m_orSize * 10000, 1), " pips");
    
    //--- Draw OR lines on chart
    DrawORLines();
    
    return true;
}

//+------------------------------------------------------------------+
//| Get indicator status                                             |
//+------------------------------------------------------------------+
string CIndicatorsManager::GetIndicatorStatus()
{
    string status = "Indicator Status:\n";
    status += "================\n";
    status += "Symbol: " + m_symbol + "\n";
    status += "EMA 100 H1: " + (IsEMA100Bullish(0) ? "BULLISH" : "BEARISH") + "\n";
    status += "EMA 100 Value: " + DoubleToString(GetEMA100Value(0), 5) + "\n";
    status += "MA20: " + DoubleToString(GetMAFast(0), 5) + "\n";
    status += "MA50: " + DoubleToString(GetMASlow(0), 5) + "\n";
    status += "MA Signal: " + (IsMABullish() ? "BULLISH" : "BEARISH") + "\n";
    
    if(m_orCalculated)
    {
        status += "Opening Range: " + DoubleToString(m_orHigh, 5) + " - " +
                  DoubleToString(m_orLow, 5) + " (" +
                  DoubleToString(m_orSize * 10000, 1) + " pips)\n";
    }
    else
    {
        status += "Opening Range: Not calculated\n";
    }
    
    return status;
}

//+------------------------------------------------------------------+
//| Deinitialize indicators                                           |
//+------------------------------------------------------------------+
void CIndicatorsManager::Deinit()
{
    if(m_ema100Handle != INVALID_HANDLE)
    {
        IndicatorRelease(m_ema100Handle);
        m_ema100Handle = INVALID_HANDLE;
    }
    
    if(m_maFastHandle != INVALID_HANDLE)
    {
        IndicatorRelease(m_maFastHandle);
        m_maFastHandle = INVALID_HANDLE;
    }
    
    if(m_maSlowHandle != INVALID_HANDLE)
    {
        IndicatorRelease(m_maSlowHandle);
        m_maSlowHandle = INVALID_HANDLE;
    }
    
    Print("Indicators Manager deinitialized");
    
    //--- Delete OR lines and time labels on deinitialization
    DeleteORLines();
    DeleteTimeLabels();
}
//+------------------------------------------------------------------+
//| Draw Opening Range lines on chart                              |
//+------------------------------------------------------------------+
void CIndicatorsManager::DrawORLines()
{
    if(!m_orCalculated)
        return;
    
    //--- Debug: Print OR values before drawing
    Print("DEBUG: Drawing OR lines - High: ", DoubleToString(m_orHigh, 5),
          " Low: ", DoubleToString(m_orLow, 5),
          " Size: ", DoubleToString(m_orSize, 5));
    
    //--- Check if OR values are valid and different
    if(m_orHigh <= m_orLow)
    {
        Print("ERROR: OR High (", DoubleToString(m_orHigh, 5),
              ") is not greater than OR Low (", DoubleToString(m_orLow, 5), ")");
        return;
    }
    
    //--- Delete existing lines first
    DeleteORLines();
    
    //--- Get chart ID
    long chartID = ChartID();
    
    //--- Draw High line
    if(ObjectCreate(chartID, m_orHighLineName, OBJ_HLINE, 0, 0, 0))
    {
        ObjectSetDouble(chartID, m_orHighLineName, OBJPROP_PRICE, m_orHigh);
        ObjectSetInteger(chartID, m_orHighLineName, OBJPROP_COLOR, m_orHighLineColor);
        ObjectSetInteger(chartID, m_orHighLineName, OBJPROP_WIDTH, m_orLineWidth);
        ObjectSetInteger(chartID, m_orHighLineName, OBJPROP_STYLE, m_orLineStyle);
        ObjectSetString(chartID, m_orHighLineName, OBJPROP_TOOLTIP, "Opening Range High: " + DoubleToString(m_orHigh, 5));
        ObjectSetInteger(chartID, m_orHighLineName, OBJPROP_BACK, false);
        
        //--- Debug: Verify line was created at correct price
        double highLinePrice = ObjectGetDouble(chartID, m_orHighLineName, OBJPROP_PRICE);
        Print("DEBUG: OR High line created at price: ", DoubleToString(highLinePrice, 5));
    }
    else
    {
        Print("Error creating OR High line object. Error code: ", GetLastError());
    }
    
    //--- Draw Low line
    if(ObjectCreate(chartID, m_orLowLineName, OBJ_HLINE, 0, 0, 0))
    {
        ObjectSetDouble(chartID, m_orLowLineName, OBJPROP_PRICE, m_orLow);
        ObjectSetInteger(chartID, m_orLowLineName, OBJPROP_COLOR, m_orLowLineColor);
        ObjectSetInteger(chartID, m_orLowLineName, OBJPROP_WIDTH, m_orLineWidth);
        ObjectSetInteger(chartID, m_orLowLineName, OBJPROP_STYLE, m_orLineStyle);
        ObjectSetString(chartID, m_orLowLineName, OBJPROP_TOOLTIP, "Opening Range Low: " + DoubleToString(m_orLow, 5));
        ObjectSetInteger(chartID, m_orLowLineName, OBJPROP_BACK, false);
        
        //--- Debug: Verify line was created at correct price
        double lowLinePrice = ObjectGetDouble(chartID, m_orLowLineName, OBJPROP_PRICE);
        Print("DEBUG: OR Low line created at price: ", DoubleToString(lowLinePrice, 5));
    }
    else
    {
        Print("Error creating OR Low line object. Error code: ", GetLastError());
    }
    
    //--- Redraw chart
    ChartRedraw();
    
    Print("Opening Range lines drawn on chart");
}

//+------------------------------------------------------------------+
//| Delete Opening Range lines from chart                          |
//+------------------------------------------------------------------+
void CIndicatorsManager::DeleteORLines()
{
    long chartID = ChartID();
    
    //--- Delete High line
    if(ObjectFind(chartID, m_orHighLineName) >= 0)
    {
        if(!ObjectDelete(chartID, m_orHighLineName))
        {
            Print("Error deleting OR High line object. Error code: ", GetLastError());
        }
    }
    
    //--- Delete Low line
    if(ObjectFind(chartID, m_orLowLineName) >= 0)
    {
        if(!ObjectDelete(chartID, m_orLowLineName))
        {
            Print("Error deleting OR Low line object. Error code: ", GetLastError());
        }
    }
    
    //--- Redraw chart
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Opening Range line properties                            |
//+------------------------------------------------------------------+
void CIndicatorsManager::UpdateORLineProperties(color highColor, color lowColor, int width, ENUM_LINE_STYLE style)
{
    m_orHighLineColor = highColor;
    m_orLowLineColor = lowColor;
    m_orLineWidth = width;
    m_orLineStyle = style;
    
    //--- If OR is calculated and lines exist, update them
    if(m_orCalculated)
    {
        long chartID = ChartID();
        
        //--- Update High line
        if(ObjectFind(chartID, m_orHighLineName) >= 0)
        {
            ObjectSetInteger(chartID, m_orHighLineName, OBJPROP_COLOR, m_orHighLineColor);
            ObjectSetInteger(chartID, m_orHighLineName, OBJPROP_WIDTH, m_orLineWidth);
            ObjectSetInteger(chartID, m_orHighLineName, OBJPROP_STYLE, m_orLineStyle);
        }
        
        //--- Update Low line
        if(ObjectFind(chartID, m_orLowLineName) >= 0)
        {
            ObjectSetInteger(chartID, m_orLowLineName, OBJPROP_COLOR, m_orLowLineColor);
            ObjectSetInteger(chartID, m_orLowLineName, OBJPROP_WIDTH, m_orLineWidth);
            ObjectSetInteger(chartID, m_orLowLineName, OBJPROP_STYLE, m_orLineStyle);
        }
        
        //--- Redraw chart
        ChartRedraw();
    }
}

//+------------------------------------------------------------------+
//| Update Opening Range lines on chart                             |
//+------------------------------------------------------------------+
void CIndicatorsManager::UpdateORLines()
{
    if(!m_orCalculated)
        return;
    
    long chartID = ChartID();
    
    //--- Update High line
    if(ObjectFind(chartID, m_orHighLineName) >= 0)
    {
        ObjectSetDouble(chartID, m_orHighLineName, OBJPROP_PRICE, m_orHigh);
        ObjectSetString(chartID, m_orHighLineName, OBJPROP_TOOLTIP, "Opening Range High: " + DoubleToString(m_orHigh, 5));
    }
    else
    {
        //--- If line doesn't exist, create it
        DrawORLines();
        return;
    }
    
    //--- Update Low line
    if(ObjectFind(chartID, m_orLowLineName) >= 0)
    {
        ObjectSetDouble(chartID, m_orLowLineName, OBJPROP_PRICE, m_orLow);
        ObjectSetString(chartID, m_orLowLineName, OBJPROP_TOOLTIP, "Opening Range Low: " + DoubleToString(m_orLow, 5));
    }
    else
    {
        //--- If line doesn't exist, create it
        DrawORLines();
        return;
    }
    
    //--- Redraw chart
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Force redraw Opening Range lines on chart                       |
//+------------------------------------------------------------------+
void CIndicatorsManager::ForceRedrawORLines()
{
    if(!m_orCalculated)
        return;
    
    //--- Delete and recreate lines to ensure they're visible
    DeleteORLines();
    DrawORLines();
    
    //--- Additional redraw to ensure visibility
    ChartRedraw();
    
    Print("OR lines force redrawn at High: ", DoubleToString(m_orHigh, 5),
          " Low: ", DoubleToString(m_orLow, 5));
}

//+------------------------------------------------------------------+
//| Draw time labels on chart                                      |
//+------------------------------------------------------------------+
void CIndicatorsManager::DrawTimeLabels(datetime orStartTime, datetime orEndTime, datetime tradingStartTime, datetime tradingEndTime)
{
    //--- Delete existing labels first
    DeleteTimeLabels();
    
    //--- Get chart ID
    long chartID = ChartID();
    
    //--- Draw OR Start label
    if(ObjectCreate(chartID, m_orStartLabelName, OBJ_TEXT, 0, orStartTime, 0))
    {
        ObjectSetString(chartID, m_orStartLabelName, OBJPROP_TEXT, "OR Start");
        ObjectSetInteger(chartID, m_orStartLabelName, OBJPROP_COLOR, m_timeLabelColor);
        ObjectSetInteger(chartID, m_orStartLabelName, OBJPROP_FONTSIZE, m_timeLabelFontSize);
        ObjectSetString(chartID, m_orStartLabelName, OBJPROP_FONT, m_timeLabelFont);
        ObjectSetInteger(chartID, m_orStartLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        ObjectSetInteger(chartID, m_orStartLabelName, OBJPROP_BACK, false);
    }
    else
    {
        Print("Error creating OR Start label. Error code: ", GetLastError());
    }
    
    //--- Draw OR End label
    if(ObjectCreate(chartID, m_orEndLabelName, OBJ_TEXT, 0, orEndTime, 0))
    {
        ObjectSetString(chartID, m_orEndLabelName, OBJPROP_TEXT, "OR End");
        ObjectSetInteger(chartID, m_orEndLabelName, OBJPROP_COLOR, m_timeLabelColor);
        ObjectSetInteger(chartID, m_orEndLabelName, OBJPROP_FONTSIZE, m_timeLabelFontSize);
        ObjectSetString(chartID, m_orEndLabelName, OBJPROP_FONT, m_timeLabelFont);
        ObjectSetInteger(chartID, m_orEndLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        ObjectSetInteger(chartID, m_orEndLabelName, OBJPROP_BACK, false);
    }
    else
    {
        Print("Error creating OR End label. Error code: ", GetLastError());
    }
    
    //--- Draw Trading Start label
    if(ObjectCreate(chartID, m_tradingStartLabelName, OBJ_TEXT, 0, tradingStartTime, 0))
    {
        ObjectSetString(chartID, m_tradingStartLabelName, OBJPROP_TEXT, "Trading Start");
        ObjectSetInteger(chartID, m_tradingStartLabelName, OBJPROP_COLOR, m_timeLabelColor);
        ObjectSetInteger(chartID, m_tradingStartLabelName, OBJPROP_FONTSIZE, m_timeLabelFontSize);
        ObjectSetString(chartID, m_tradingStartLabelName, OBJPROP_FONT, m_timeLabelFont);
        ObjectSetInteger(chartID, m_tradingStartLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        ObjectSetInteger(chartID, m_tradingStartLabelName, OBJPROP_BACK, false);
    }
    else
    {
        Print("Error creating Trading Start label. Error code: ", GetLastError());
    }
    
    //--- Draw Trading End label
    if(ObjectCreate(chartID, m_tradingEndLabelName, OBJ_TEXT, 0, tradingEndTime, 0))
    {
        ObjectSetString(chartID, m_tradingEndLabelName, OBJPROP_TEXT, "Trading End");
        ObjectSetInteger(chartID, m_tradingEndLabelName, OBJPROP_COLOR, m_timeLabelColor);
        ObjectSetInteger(chartID, m_tradingEndLabelName, OBJPROP_FONTSIZE, m_timeLabelFontSize);
        ObjectSetString(chartID, m_tradingEndLabelName, OBJPROP_FONT, m_timeLabelFont);
        ObjectSetInteger(chartID, m_tradingEndLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        ObjectSetInteger(chartID, m_tradingEndLabelName, OBJPROP_BACK, false);
    }
    else
    {
        Print("Error creating Trading End label. Error code: ", GetLastError());
    }
    
    //--- Redraw chart
    ChartRedraw();
    
    Print("Time labels drawn on chart");
}

//+------------------------------------------------------------------+
//| Delete time labels from chart                                  |
//+------------------------------------------------------------------+
void CIndicatorsManager::DeleteTimeLabels()
{
    long chartID = ChartID();
    
    //--- Delete OR Start label
    if(ObjectFind(chartID, m_orStartLabelName) >= 0)
    {
        if(!ObjectDelete(chartID, m_orStartLabelName))
        {
            Print("Error deleting OR Start label. Error code: ", GetLastError());
        }
    }
    
    //--- Delete OR End label
    if(ObjectFind(chartID, m_orEndLabelName) >= 0)
    {
        if(!ObjectDelete(chartID, m_orEndLabelName))
        {
            Print("Error deleting OR End label. Error code: ", GetLastError());
        }
    }
    
    //--- Delete Trading Start label
    if(ObjectFind(chartID, m_tradingStartLabelName) >= 0)
    {
        if(!ObjectDelete(chartID, m_tradingStartLabelName))
        {
            Print("Error deleting Trading Start label. Error code: ", GetLastError());
        }
    }
    
    //--- Delete Trading End label
    if(ObjectFind(chartID, m_tradingEndLabelName) >= 0)
    {
        if(!ObjectDelete(chartID, m_tradingEndLabelName))
        {
            Print("Error deleting Trading End label. Error code: ", GetLastError());
        }
    }
    
    //--- Redraw chart
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update time label properties                                   |
//+------------------------------------------------------------------+
void CIndicatorsManager::UpdateTimeLabelProperties(color labelColor, int fontSize, string font)
{
    m_timeLabelColor = labelColor;
    m_timeLabelFontSize = fontSize;
    m_timeLabelFont = font;
    
    long chartID = ChartID();
    
    //--- Update OR Start label
    if(ObjectFind(chartID, m_orStartLabelName) >= 0)
    {
        ObjectSetInteger(chartID, m_orStartLabelName, OBJPROP_COLOR, m_timeLabelColor);
        ObjectSetInteger(chartID, m_orStartLabelName, OBJPROP_FONTSIZE, m_timeLabelFontSize);
        ObjectSetString(chartID, m_orStartLabelName, OBJPROP_FONT, m_timeLabelFont);
    }
    
    //--- Update OR End label
    if(ObjectFind(chartID, m_orEndLabelName) >= 0)
    {
        ObjectSetInteger(chartID, m_orEndLabelName, OBJPROP_COLOR, m_timeLabelColor);
        ObjectSetInteger(chartID, m_orEndLabelName, OBJPROP_FONTSIZE, m_timeLabelFontSize);
        ObjectSetString(chartID, m_orEndLabelName, OBJPROP_FONT, m_timeLabelFont);
    }
    
    //--- Update Trading Start label
    if(ObjectFind(chartID, m_tradingStartLabelName) >= 0)
    {
        ObjectSetInteger(chartID, m_tradingStartLabelName, OBJPROP_COLOR, m_timeLabelColor);
        ObjectSetInteger(chartID, m_tradingStartLabelName, OBJPROP_FONTSIZE, m_timeLabelFontSize);
        ObjectSetString(chartID, m_tradingStartLabelName, OBJPROP_FONT, m_timeLabelFont);
    }
    
    //--- Update Trading End label
    if(ObjectFind(chartID, m_tradingEndLabelName) >= 0)
    {
        ObjectSetInteger(chartID, m_tradingEndLabelName, OBJPROP_COLOR, m_timeLabelColor);
        ObjectSetInteger(chartID, m_tradingEndLabelName, OBJPROP_FONTSIZE, m_timeLabelFontSize);
        ObjectSetString(chartID, m_tradingEndLabelName, OBJPROP_FONT, m_timeLabelFont);
    }
    
    //--- Redraw chart
    ChartRedraw();
}
//+------------------------------------------------------------------+