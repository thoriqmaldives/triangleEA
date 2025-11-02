//+------------------------------------------------------------------+
//|                                                TriangleLogger.mqh |
//|                        Copyright 2024, Triangle Trading System    |
//|                                      Version: 1.00               |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Triangle Trading System"
#property link      ""
#property version   "1.00"
#property strict

//--- Log level enumeration
enum ENUM_LOG_LEVEL
{
    ERROR,      // Critical errors that may stop EA operation
    WARN,       // Warning messages for potential issues
    INFO,       // General information messages
    DEBUG       // Detailed debugging information
};

//+------------------------------------------------------------------+
//| Logger Class                                                     |
//+------------------------------------------------------------------+
class CLogger
{
private:
    //--- Configuration
    ENUM_LOG_LEVEL      m_logLevel;
    bool                m_enabled;
    string              m_logFile;
    bool                m_logToFile;
    bool                m_logToExperts;
    bool                m_logToChart;
    
    //--- Statistics
    int                 m_errorCount;
    int                 m_warnCount;
    int                 m_infoCount;
    int                 m_debugCount;
    datetime            m_startTime;
    
    //--- Formatting
    string              m_prefix;
    int                 m_maxLogEntries;    // Maximum entries to keep in memory
    string              m_logHistory[];     // In-memory log history
    
    //--- Helper methods
    void                WriteLog(ENUM_LOG_LEVEL level, string message, string function = "");
    string              GetLevelString(ENUM_LOG_LEVEL level);
    string              GetTimestamp();
    string              FormatMessage(ENUM_LOG_LEVEL level, string message, string function);
    void                AddToHistory(string entry);
    void                CleanupHistory();
    bool                ShouldLog(ENUM_LOG_LEVEL level);
    
public:
    //--- Constructor/Destructor
    CLogger();
    ~CLogger();
    
    //--- Initialization
    void                Init(ENUM_LOG_LEVEL level, bool enabled, bool logToFile = false, 
                            bool logToExperts = true, bool logToChart = false);
    
    //--- Logging methods
    void                LogError(string message, string function = "");
    void                LogWarn(string message, string function = "");
    void                LogInfo(string message, string function = "");
    void                LogDebug(string message, string function = "");
    
    //--- Specialized logging methods
    void                LogTrade(string action, double price, double lots, string comment = "");
    void                LogOrder(string action, ulong ticket, double price, double lots, string type = "");
    void                LogIndicator(string indicator, double value, int timeframe, string details = "");
    void                LogTime(string timeEvent, datetime time, string details = "");
    void                LogBasket(string basketEvent, double profit, string details = "");
    void                LogRisk(string riskEvent, double amount, string details = "");
    void                LogAccount(string accountEvent, double balance, double equity);
    
    //--- Configuration methods
    void                SetLogLevel(ENUM_LOG_LEVEL level) { m_logLevel = level; }
    ENUM_LOG_LEVEL      GetLogLevel() { return m_logLevel; }
    void                SetEnabled(bool enabled) { m_enabled = enabled; }
    bool                IsEnabled() { return m_enabled; }
    void                SetPrefix(string prefix) { m_prefix = prefix; }
    string              GetPrefix() { return m_prefix; }
    
    //--- File operations
    bool                SetLogFile(string filename);
    string              GetLogFile() { return m_logFile; }
    bool                FlushToFile();
    void                ClearLogFile();
    
    //--- Statistics methods
    int                 GetErrorCount() { return m_errorCount; }
    int                 GetWarnCount() { return m_warnCount; }
    int                 GetInfoCount() { return m_infoCount; }
    int                 GetDebugCount() { return m_debugCount; }
    void                ResetStatistics();
    string              GetStatistics();
    datetime            GetStartTime() { return m_startTime; }
    
    //--- History methods
    int                 GetHistorySize() { return ArraySize(m_logHistory); }
    string              GetLogEntry(int index);
    string              GetRecentEntries(int count = 10);
    void                ClearHistory();
    
    //--- Utility methods
    void                SetMaxLogEntries(int maxEntries) { m_maxLogEntries = maxEntries; }
    int                 GetMaxLogEntries() { return m_maxLogEntries; }
    void                PrintToChart(string message);
    void                ClearChart();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger()
{
    m_logLevel = INFO;
    m_enabled = true;
    m_logFile = "";
    m_logToFile = false;
    m_logToExperts = true;
    m_logToChart = false;
    
    m_errorCount = 0;
    m_warnCount = 0;
    m_infoCount = 0;
    m_debugCount = 0;
    m_startTime = TimeCurrent();
    
    m_prefix = "Triangle_EA";
    m_maxLogEntries = 1000;
    
    ArrayResize(m_logHistory, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLogger::~CLogger()
{
    if(m_logToFile && m_logFile != "")
        FlushToFile();
}

//+------------------------------------------------------------------+
//| Initialize logger                                                |
//+------------------------------------------------------------------+
void CLogger::Init(ENUM_LOG_LEVEL level, bool enabled, bool logToFile, bool logToExperts, bool logToChart)
{
    m_logLevel = level;
    m_enabled = enabled;
    m_logToFile = logToFile;
    m_logToExperts = logToExperts;
    m_logToChart = logToChart;
    
    m_startTime = TimeCurrent();
    
    //--- Set default log file if logging to file
    if(m_logToFile && m_logFile == "")
    {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        m_logFile = "Triangle_EA_" + IntegerToString(dt.year) + 
                   StringFormat("%02d", dt.mon) + 
                   StringFormat("%02d", dt.day) + ".log";
    }
    
    //--- Log initialization
    LogInfo("Logger initialized - Level: " + GetLevelString(level) + 
           ", Enabled: " + (enabled ? "Yes" : "No") + 
           ", File: " + (logToFile ? "Yes" : "No") + 
           ", Experts: " + (logToExperts ? "Yes" : "No") + 
           ", Chart: " + (logToChart ? "Yes" : "No"), "Init");
}

//+------------------------------------------------------------------+
//| Log error message                                                |
//+------------------------------------------------------------------+
void CLogger::LogError(string message, string function = "")
{
    if(!ShouldLog(ERROR))
        return;
    
    m_errorCount++;
    WriteLog(ERROR, message, function);
}

//+------------------------------------------------------------------+
//| Log warning message                                              |
//+------------------------------------------------------------------+
void CLogger::LogWarn(string message, string function = "")
{
    if(!ShouldLog(WARN))
        return;
    
    m_warnCount++;
    WriteLog(WARN, message, function);
}

//+------------------------------------------------------------------+
//| Log info message                                                 |
//+------------------------------------------------------------------+
void CLogger::LogInfo(string message, string function = "")
{
    if(!ShouldLog(INFO))
        return;
    
    m_infoCount++;
    WriteLog(INFO, message, function);
}

//+------------------------------------------------------------------+
//| Log debug message                                                |
//+------------------------------------------------------------------+
void CLogger::LogDebug(string message, string function = "")
{
    if(!ShouldLog(DEBUG))
        return;
    
    m_debugCount++;
    WriteLog(DEBUG, message, function);
}

//+------------------------------------------------------------------+
//| Log trade event                                                  |
//+------------------------------------------------------------------+
void CLogger::LogTrade(string action, double price, double lots, string comment = "")
{
    string message = "TRADE: " + action + 
                    " | Price: " + DoubleToString(price, 5) + 
                    " | Lots: " + DoubleToString(lots, 2);
    
    if(comment != "")
        message += " | Comment: " + comment;
    
    LogInfo(message, "LogTrade");
}

//+------------------------------------------------------------------+
//| Log order event                                                  |
//+------------------------------------------------------------------+
void CLogger::LogOrder(string action, ulong ticket, double price, double lots, string type = "")
{
    string message = "ORDER: " + action + 
                    " | Ticket: " + IntegerToString(ticket) + 
                    " | Type: " + type + 
                    " | Price: " + DoubleToString(price, 5) + 
                    " | Lots: " + DoubleToString(lots, 2);
    
    LogInfo(message, "LogOrder");
}

//+------------------------------------------------------------------+
//| Log indicator event                                              |
//+------------------------------------------------------------------+
void CLogger::LogIndicator(string indicator, double value, int timeframe, string details = "")
{
    string message = "INDICATOR: " + indicator + 
                    " | Value: " + DoubleToString(value, 5) + 
                    " | Timeframe: " + IntegerToString(timeframe);
    
    if(details != "")
        message += " | Details: " + details;
    
    LogDebug(message, "LogIndicator");
}

//+------------------------------------------------------------------+
//| Log time event                                                   |
//+------------------------------------------------------------------+
void CLogger::LogTime(string timeEvent, datetime time, string details = "")
{
    string message = "TIME: " + timeEvent + 
                    " | Time: " + TimeToString(time, TIME_SECONDS);
    
    if(details != "")
        message += " | Details: " + details;
    
    LogInfo(message, "LogTime");
}

//+------------------------------------------------------------------+
//| Log basket event                                                 |
//+------------------------------------------------------------------+
void CLogger::LogBasket(string basketEvent, double profit, string details = "")
{
    string message = "BASKET: " + basketEvent + 
                    " | Profit: $" + DoubleToString(profit, 2);
    
    if(details != "")
        message += " | Details: " + details;
    
    LogInfo(message, "LogBasket");
}

//+------------------------------------------------------------------+
//| Log risk event                                                   |
//+------------------------------------------------------------------+
void CLogger::LogRisk(string riskEvent, double amount, string details = "")
{
    string message = "RISK: " + riskEvent + 
                    " | Amount: $" + DoubleToString(amount, 2);
    
    if(details != "")
        message += " | Details: " + details;
    
    LogInfo(message, "LogRisk");
}

//+------------------------------------------------------------------+
//| Log account event                                                |
//+------------------------------------------------------------------+
void CLogger::LogAccount(string accountEvent, double balance, double equity)
{
    string message = "ACCOUNT: " + accountEvent + 
                    " | Balance: $" + DoubleToString(balance, 2) + 
                    " | Equity: $" + DoubleToString(equity, 2);
    
    LogInfo(message, "LogAccount");
}

//+------------------------------------------------------------------+
//| Check if should log based on level                               |
//+------------------------------------------------------------------+
bool CLogger::ShouldLog(ENUM_LOG_LEVEL level)
{
    return (m_enabled && level <= m_logLevel);
}

//+------------------------------------------------------------------+
//| Write log entry                                                  |
//+------------------------------------------------------------------+
void CLogger::WriteLog(ENUM_LOG_LEVEL level, string message, string function = "")
{
    string entry = FormatMessage(level, message, function);
    
    //--- Add to history
    AddToHistory(entry);
    
    //--- Log to Experts tab
    if(m_logToExperts)
    {
        if(level == ERROR)
            Print(entry);
        else if(level == WARN)
            Print(entry);
        else if(level == INFO)
            Print(entry);
        else
            Print(entry);
    }
    
    //--- Log to file
    if(m_logToFile && m_logFile != "")
    {
        //--- For performance, we'll batch file writes
        //--- File writing is done in FlushToFile()
    }
    
    //--- Log to chart
    if(m_logToChart && (level == ERROR || level == WARN))
    {
        PrintToChart(entry);
    }
}

//+------------------------------------------------------------------+
//| Format log message                                               |
//+------------------------------------------------------------------+
string CLogger::FormatMessage(ENUM_LOG_LEVEL level, string message, string function = "")
{
    string entry = GetTimestamp() + " [" + GetLevelString(level) + "]";
    
    if(m_prefix != "")
        entry += " [" + m_prefix + "]";
    
    if(function != "")
        entry += " [" + function + "]";
    
    entry += " " + message;
    
    return entry;
}

//+------------------------------------------------------------------+
//| Get level string                                                 |
//+------------------------------------------------------------------+
string CLogger::GetLevelString(ENUM_LOG_LEVEL level)
{
    switch(level)
    {
        case ERROR: return "ERROR";
        case WARN:  return "WARN";
        case INFO:  return "INFO";
        case DEBUG: return "DEBUG";
        default:    return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get timestamp                                                    |
//+------------------------------------------------------------------+
string CLogger::GetTimestamp()
{
    return TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Add entry to history                                             |
//+------------------------------------------------------------------+
void CLogger::AddToHistory(string entry)
{
    int size = ArraySize(m_logHistory);
    
    //--- Add new entry
    ArrayResize(m_logHistory, size + 1);
    m_logHistory[size] = entry;
    
    //--- Cleanup old entries if needed
    CleanupHistory();
}

//+------------------------------------------------------------------+
//| Cleanup history                                                  |
//+------------------------------------------------------------------+
void CLogger::CleanupHistory()
{
    int size = ArraySize(m_logHistory);
    
    if(size > m_maxLogEntries)
    {
        //--- Shift array to remove oldest entries
        int removeCount = size - m_maxLogEntries;
        for(int i = 0; i < m_maxLogEntries; i++)
        {
            m_logHistory[i] = m_logHistory[i + removeCount];
        }
        ArrayResize(m_logHistory, m_maxLogEntries);
    }
}

//+------------------------------------------------------------------+
//| Set log file                                                     |
//+------------------------------------------------------------------+
bool CLogger::SetLogFile(string filename)
{
    m_logFile = filename;
    m_logToFile = true;
    
    //--- Test file creation
    int fileHandle = FileOpen(m_logFile, FILE_WRITE | FILE_TXT);
    if(fileHandle == INVALID_HANDLE)
    {
        m_logToFile = false;
        LogError("Failed to create log file: " + filename, "SetLogFile");
        return false;
    }
    
    FileClose(fileHandle);
    return true;
}

//+------------------------------------------------------------------+
//| Flush log to file                                                |
//+------------------------------------------------------------------+
bool CLogger::FlushToFile()
{
    if(!m_logToFile || m_logFile == "")
        return false;
    
    int fileHandle = FileOpen(m_logFile, FILE_WRITE | FILE_TXT | FILE_READ);
    if(fileHandle == INVALID_HANDLE)
    {
        LogError("Failed to open log file for writing: " + m_logFile, "FlushToFile");
        return false;
    }
    
    //--- Move to end of file
    FileSeek(fileHandle, 0, SEEK_END);
    
    //--- Write all entries
    for(int i = 0; i < ArraySize(m_logHistory); i++)
    {
        FileWriteString(fileHandle, m_logHistory[i] + "\r\n");
    }
    
    FileClose(fileHandle);
    
    //--- Clear history after writing
    ArrayResize(m_logHistory, 0);
    
    return true;
}

//+------------------------------------------------------------------+
//| Clear log file                                                   |
//+------------------------------------------------------------------+
void CLogger::ClearLogFile()
{
    if(m_logFile == "")
        return;
    
    int fileHandle = FileOpen(m_logFile, FILE_WRITE | FILE_TXT);
    if(fileHandle != INVALID_HANDLE)
    {
        FileClose(fileHandle);
        LogInfo("Log file cleared: " + m_logFile, "ClearLogFile");
    }
}

//+------------------------------------------------------------------+
//| Reset statistics                                                 |
//+------------------------------------------------------------------+
void CLogger::ResetStatistics()
{
    m_errorCount = 0;
    m_warnCount = 0;
    m_infoCount = 0;
    m_debugCount = 0;
    m_startTime = TimeCurrent();
    
    LogInfo("Logger statistics reset", "ResetStatistics");
}

//+------------------------------------------------------------------+
//| Get statistics                                                   |
//+------------------------------------------------------------------+
string CLogger::GetStatistics()
{
    string stats = "Logger Statistics:\n";
    stats += "==================\n";
    stats += "Start Time: " + TimeToString(m_startTime, TIME_DATE | TIME_SECONDS) + "\n";
    stats += "Error Count: " + IntegerToString(m_errorCount) + "\n";
    stats += "Warning Count: " + IntegerToString(m_warnCount) + "\n";
    stats += "Info Count: " + IntegerToString(m_infoCount) + "\n";
    stats += "Debug Count: " + IntegerToString(m_debugCount) + "\n";
    stats += "Total Entries: " + IntegerToString(m_errorCount + m_warnCount + m_infoCount + m_debugCount) + "\n";
    stats += "History Size: " + IntegerToString(ArraySize(m_logHistory)) + "\n";
    stats += "Log File: " + (m_logFile != "" ? m_logFile : "None") + "\n";
    
    return stats;
}

//+------------------------------------------------------------------+
//| Get log entry from history                                       |
//+------------------------------------------------------------------+
string CLogger::GetLogEntry(int index)
{
    if(index < 0 || index >= ArraySize(m_logHistory))
        return "";
    
    return m_logHistory[index];
}

//+------------------------------------------------------------------+
//| Get recent log entries                                           |
//+------------------------------------------------------------------+
string CLogger::GetRecentEntries(int count)
{
    string entries = "";
    int size = ArraySize(m_logHistory);
    int start = MathMax(0, size - count);
    
    for(int i = start; i < size; i++)
    {
        entries += m_logHistory[i] + "\n";
    }
    
    return entries;
}

//+------------------------------------------------------------------+
//| Clear history                                                    |
//+------------------------------------------------------------------+
void CLogger::ClearHistory()
{
    ArrayResize(m_logHistory, 0);
    LogInfo("Logger history cleared", "ClearHistory");
}

//+------------------------------------------------------------------+
//| Print message to chart                                           |
//+------------------------------------------------------------------+
void CLogger::PrintToChart(string message)
{
    //--- This would require chart operations
    //--- For now, we'll just print to Experts tab
    Print("CHART: ", message);
}

//+------------------------------------------------------------------+
//| Clear chart display                                              |
//+------------------------------------------------------------------+
void CLogger::ClearChart()
{
    //--- Clear chart comments
    Comment("");
}
//+------------------------------------------------------------------+