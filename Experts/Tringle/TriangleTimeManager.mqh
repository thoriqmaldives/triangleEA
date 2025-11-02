//+------------------------------------------------------------------+
//|                                            TriangleTimeManager.mqh |
//|                        Copyright 2024, Triangle Trading System    |
//|                                      Version: 1.00               |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Triangle Trading System"
#property link      ""
#property version   "1.00"
#property strict

//--- Time status enumeration
enum TIME_STATUS
{
    TIME_PRE_OR,           // Before opening range (before 15:30)
    TIME_IN_OR,            // During opening range (15:30-15:45)
    TIME_POST_OR,          // After opening range (15:45-17:30)
    TIME_AFTER_TRADING,    // After trading window (17:30-21:00)
    TIME_FORCED_EXIT       // Forced exit time (after 21:00)
};

//+------------------------------------------------------------------+
//| Time Manager Class                                               |
//+------------------------------------------------------------------+
class CTimeManager
{
private:
    bool                m_autoDetect;
    int                 m_manualOffset;
    int                 m_brokerTimezone;
    datetime            m_parisTime;
    TIME_STATUS         m_timeStatus;
    datetime            m_lastUpdate;
    
    //--- Key times in Paris time (stored as hour/minute for daily calculation)
    int                 m_orStartHour;      // 15
    int                 m_orStartMinute;    // 30
    int                 m_orEndHour;        // 15
    int                 m_orEndMinute;      // 45
    int                 m_orderEndHour;     // 17
    int                 m_orderEndMinute;   // 30
    int                 m_forceExitHour;    // 21
    int                 m_forceExitMinute;  // 0
    
    //--- Helper methods
    int                 DetectBrokerTimezone();
    datetime            ConvertToParisTime(datetime serverTime);
    datetime            GetParisTimeForTime(datetime serverTime);
    void                UpdateTimeStatus();
    
public:
    //--- Constructor/Destructor
    CTimeManager();
    ~CTimeManager();
    
    //--- Initialization
    bool                Init(bool autoDetect, int manualOffset);
    bool                Init(bool autoDetect, int manualOffset,
                         int orStartHour, int orStartMinute, int orEndHour, int orEndMinute,
                         int tradingStartHour, int tradingStartMinute, int tradingEndHour, int tradingEndMinute);
    
    //--- Time conversion methods
    datetime            GetParisTime();
    datetime            GetParisTimeForHourMinute(int hour, int minute);
    datetime            GetServerTimeFromParis(datetime parisTime);
    
    //--- Time status methods
    TIME_STATUS         GetTimeStatus();
    string              GetTimeStatusString();
    bool                IsTradingTime();
    bool                IsOrderPlacementTime();
    bool                IsForceExitTime();
    bool                IsOpeningRangeTime();
    bool                IsAfterTradingTime();
    
    //--- Update methods
    void                Update();
    
    //--- Utility methods
    string              GetTimeString(datetime time);
    bool                IsSameDay(datetime time1, datetime time2);
    int                 GetDayOfWeek(datetime time);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTimeManager::CTimeManager()
{
    m_autoDetect = true;
    m_manualOffset = 0;
    m_brokerTimezone = 0;
    m_parisTime = 0;
    m_timeStatus = TIME_PRE_OR;
    m_lastUpdate = 0;
    
    //--- Initialize key times (default values)
    m_orStartHour = 15;
    m_orStartMinute = 30;
    m_orEndHour = 15;
    m_orEndMinute = 45;
    m_orderEndHour = 17;
    m_orderEndMinute = 30;
    m_forceExitHour = 21;
    m_forceExitMinute = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTimeManager::~CTimeManager()
{
}

//+------------------------------------------------------------------+
//| Initialize time manager                                          |
//+------------------------------------------------------------------+
bool CTimeManager::Init(bool autoDetect, int manualOffset)
{
    m_autoDetect = autoDetect;
    m_manualOffset = manualOffset;
    
    //--- Detect broker timezone if auto-detect is enabled
    if(m_autoDetect)
    {
        m_brokerTimezone = DetectBrokerTimezone();
        if(m_brokerTimezone == -999)
        {
            Print("Failed to detect broker timezone, using UTC");
            m_brokerTimezone = 0;
        }
    }
    else
    {
        m_brokerTimezone = manualOffset;
    }
    
    //--- Initial update
    Update();
    
    Print("Time Manager initialized - Broker timezone: ", m_brokerTimezone, 
          ", Auto detect: ", (m_autoDetect ? "Yes" : "No"));
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize time manager with custom trading times                |
//+------------------------------------------------------------------+
bool CTimeManager::Init(bool autoDetect, int manualOffset,
                       int orStartHour, int orStartMinute, int orEndHour, int orEndMinute,
                       int tradingStartHour, int tradingStartMinute, int tradingEndHour, int tradingEndMinute)
{
    m_autoDetect = autoDetect;
    m_manualOffset = manualOffset;
    
    //--- Set custom trading times
    m_orStartHour = orStartHour;
    m_orStartMinute = orStartMinute;
    m_orEndHour = orEndHour;
    m_orEndMinute = orEndMinute;
    m_orderEndHour = tradingEndHour;
    m_orderEndMinute = tradingEndMinute;
    
    //--- Detect broker timezone if auto-detect is enabled
    if(m_autoDetect)
    {
        m_brokerTimezone = DetectBrokerTimezone();
        if(m_brokerTimezone == -999)
        {
            Print("Failed to detect broker timezone, using UTC");
            m_brokerTimezone = 0;
        }
    }
    else
    {
        m_brokerTimezone = manualOffset;
    }
    
    //--- Initial update
    Update();
    
    Print("Time Manager initialized with custom trading times:");
    Print("  OR: ", orStartHour, ":", orStartMinute, " - ", orEndHour, ":", orEndMinute);
    Print("  Trading: ", tradingStartHour, ":", tradingStartMinute, " - ", tradingEndHour, ":", tradingEndMinute);
    Print("  Broker timezone: ", m_brokerTimezone, ", Auto detect: ", (m_autoDetect ? "Yes" : "No"));
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect broker timezone                                           |
//+------------------------------------------------------------------+
int CTimeManager::DetectBrokerTimezone()
{
    //--- Get current time and try to determine timezone
    datetime serverTime = TimeCurrent();
    MqlDateTime serverStruct, utcStruct;
    
    TimeToStruct(serverTime, serverStruct);
    TimeToStruct(TimeGMT(), utcStruct);
    
    //--- Calculate difference between server time and UTC
    int timezoneOffset = serverStruct.hour - utcStruct.hour;
    
    //--- Handle day differences
    if(serverStruct.day > utcStruct.day || (serverStruct.day == 1 && utcStruct.day > 20))
    {
        //--- Server time is next day relative to UTC
        if(timezoneOffset < 0)
            timezoneOffset += 24;
    }
    else if(serverStruct.day < utcStruct.day || (utcStruct.day == 1 && serverStruct.day > 20))
    {
        //--- Server time is previous day relative to UTC
        if(timezoneOffset > 0)
            timezoneOffset -= 24;
    }
    
    //--- Normalize to -12 to +12 range
    while(timezoneOffset > 12) timezoneOffset -= 24;
    while(timezoneOffset < -12) timezoneOffset += 24;
    
    Print("Detected timezone offset: ", timezoneOffset, " hours from UTC");
    return timezoneOffset;
}

//+------------------------------------------------------------------+
//| Convert server time to Paris time                                |
//+------------------------------------------------------------------+
datetime CTimeManager::ConvertToParisTime(datetime serverTime)
{
    //--- Paris is UTC+1 (standard) or UTC+2 (daylight saving)
    //--- For simplicity, we'll use UTC+1, but this can be enhanced
    
    //--- Convert server time to UTC
    MqlDateTime serverStruct;
    TimeToStruct(serverTime, serverStruct);
    
    //--- Remove broker timezone offset to get UTC
    serverStruct.hour -= m_brokerTimezone;
    
    //--- Add Paris timezone offset (UTC+1, can be adjusted for DST)
    serverStruct.hour += 1;  // Paris time (UTC+1)
    
    //--- Normalize hours
    while(serverStruct.hour >= 24)
    {
        serverStruct.hour -= 24;
        serverStruct.day++;
        if(serverStruct.day > 31)
        {
            serverStruct.day = 1;
            serverStruct.mon++;
            if(serverStruct.mon > 12)
            {
                serverStruct.mon = 1;
                serverStruct.year++;
            }
        }
    }
    
    while(serverStruct.hour < 0)
    {
        serverStruct.hour += 24;
        serverStruct.day--;
        if(serverStruct.day < 1)
        {
            serverStruct.mon--;
            if(serverStruct.mon < 1)
            {
                serverStruct.mon = 12;
                serverStruct.year--;
            }
            //--- Get days in previous month
            int prevMonth = serverStruct.mon;
            int prevYear = serverStruct.year;
            
            //--- Since we already decremented mon, we need to check what it is now
            if(prevMonth == 1) // If current month is January, previous was December
            {
                prevMonth = 12;
                prevYear--;
            }
            else
            {
                prevMonth--; // Get the actual previous month
            }
            
            if(prevMonth == 2)
            {
                serverStruct.day = (prevYear % 4 == 0) ? 29 : 28;
            }
            else if(prevMonth == 4 || prevMonth == 6 || prevMonth == 9 || prevMonth == 11)
            {
                serverStruct.day = 30;
            }
            else
            {
                serverStruct.day = 31;
            }
        }
    }
    
    return StructToTime(serverStruct);
}

//+------------------------------------------------------------------+
//| Update time manager                                              |
//+------------------------------------------------------------------+
void CTimeManager::Update()
{
    datetime currentTime = TimeCurrent();
    
    //--- Update only if time has changed (avoid excessive processing)
    if(currentTime == m_lastUpdate)
        return;
    
    m_lastUpdate = currentTime;
    m_parisTime = ConvertToParisTime(currentTime);
    UpdateTimeStatus();
}

//+------------------------------------------------------------------+
//| Update time status                                               |
//+------------------------------------------------------------------+
void CTimeManager::UpdateTimeStatus()
{
    MqlDateTime parisStruct;
    TimeToStruct(m_parisTime, parisStruct);
    
    int currentMinutes = parisStruct.hour * 60 + parisStruct.min;
    
    //--- Define time windows in minutes from midnight
    int orStartMinutes = m_orStartHour * 60 + m_orStartMinute;      // 15:30 = 930
    int orEndMinutes = m_orEndHour * 60 + m_orEndMinute;            // 15:45 = 945
    int orderEndMinutes = m_orderEndHour * 60 + m_orderEndMinute;    // 17:30 = 1050
    int forceExitMinutes = m_forceExitHour * 60 + m_forceExitMinute; // 21:00 = 1260
    
    //--- Determine time status
    if(currentMinutes < orStartMinutes)
    {
        m_timeStatus = TIME_PRE_OR;
    }
    else if(currentMinutes >= orStartMinutes && currentMinutes < orEndMinutes)
    {
        m_timeStatus = TIME_IN_OR;
    }
    else if(currentMinutes >= orEndMinutes && currentMinutes < orderEndMinutes)
    {
        m_timeStatus = TIME_POST_OR;
    }
    else if(currentMinutes >= orderEndMinutes && currentMinutes < forceExitMinutes)
    {
        m_timeStatus = TIME_AFTER_TRADING;
    }
    else
    {
        m_timeStatus = TIME_FORCED_EXIT;
    }
}

//+------------------------------------------------------------------+
//| Get current Paris time                                           |
//+------------------------------------------------------------------+
datetime CTimeManager::GetParisTime()
{
    return m_parisTime;
}

//+------------------------------------------------------------------+
//| Get Paris time for specific hour/minute                          |
//+------------------------------------------------------------------+
datetime CTimeManager::GetParisTimeForHourMinute(int hour, int minute)
{
    MqlDateTime parisStruct;
    TimeToStruct(m_parisTime, parisStruct);
    
    parisStruct.hour = hour;
    parisStruct.min = minute;
    parisStruct.sec = 0;
    
    return StructToTime(parisStruct);
}

//+------------------------------------------------------------------+
//| Convert Paris time to server time                                |
//+------------------------------------------------------------------+
datetime CTimeManager::GetServerTimeFromParis(datetime parisTime)
{
    MqlDateTime parisStruct;
    TimeToStruct(parisTime, parisStruct);
    
    //--- Remove Paris timezone offset (UTC+1)
    parisStruct.hour -= 1;
    
    //--- Add broker timezone offset
    parisStruct.hour += m_brokerTimezone;
    
    //--- Normalize hours
    while(parisStruct.hour >= 24)
    {
        parisStruct.hour -= 24;
        parisStruct.day++;
        if(parisStruct.day > 31)
        {
            parisStruct.day = 1;
            parisStruct.mon++;
            if(parisStruct.mon > 12)
            {
                parisStruct.mon = 1;
                parisStruct.year++;
            }
        }
    }
    
    while(parisStruct.hour < 0)
    {
        parisStruct.hour += 24;
        parisStruct.day--;
        if(parisStruct.day < 1)
        {
            parisStruct.mon--;
            if(parisStruct.mon < 1)
            {
                parisStruct.mon = 12;
                parisStruct.year--;
            }
        }
    }
    
    return StructToTime(parisStruct);
}

//+------------------------------------------------------------------+
//| Get current time status                                          |
//+------------------------------------------------------------------+
TIME_STATUS CTimeManager::GetTimeStatus()
{
    return m_timeStatus;
}

//+------------------------------------------------------------------+
//| Get time status as string                                        |
//+------------------------------------------------------------------+
string CTimeManager::GetTimeStatusString()
{
    switch(m_timeStatus)
    {
        case TIME_PRE_OR:        return "PRE_OR";
        case TIME_IN_OR:         return "IN_OR";
        case TIME_POST_OR:       return "POST_OR";
        case TIME_AFTER_TRADING: return "AFTER_TRADING";
        case TIME_FORCED_EXIT:   return "FORCED_EXIT";
        default:                 return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Check if it's trading time (15:45-17:30)                        |
//+------------------------------------------------------------------+
bool CTimeManager::IsTradingTime()
{
    return (m_timeStatus == TIME_POST_OR);
}

//+------------------------------------------------------------------+
//| Check if it's order placement time (15:45-17:30)                 |
//+------------------------------------------------------------------+
bool CTimeManager::IsOrderPlacementTime()
{
    return (m_timeStatus == TIME_POST_OR);
}

//+------------------------------------------------------------------+
//| Check if it's forced exit time (after 21:00)                     |
//+------------------------------------------------------------------+
bool CTimeManager::IsForceExitTime()
{
    return (m_timeStatus == TIME_FORCED_EXIT);
}

//+------------------------------------------------------------------+
//| Check if it's opening range time (15:30-15:45)                    |
//+------------------------------------------------------------------+
bool CTimeManager::IsOpeningRangeTime()
{
    return (m_timeStatus == TIME_IN_OR);
}

//+------------------------------------------------------------------+
//| Check if it's after trading time (17:30-21:00)                    |
//+------------------------------------------------------------------+
bool CTimeManager::IsAfterTradingTime()
{
    return (m_timeStatus == TIME_AFTER_TRADING);
}

//+------------------------------------------------------------------+
//| Get time string                                                  |
//+------------------------------------------------------------------+
string CTimeManager::GetTimeString(datetime time)
{
    return TimeToString(time, TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Check if two times are on the same day                           |
//+------------------------------------------------------------------+
bool CTimeManager::IsSameDay(datetime time1, datetime time2)
{
    MqlDateTime struct1, struct2;
    TimeToStruct(time1, struct1);
    TimeToStruct(time2, struct2);
    
    return (struct1.year == struct2.year && 
            struct1.mon == struct2.mon && 
            struct1.day == struct2.day);
}

//+------------------------------------------------------------------+
//| Get day of week                                                  |
//+------------------------------------------------------------------+
int CTimeManager::GetDayOfWeek(datetime time)
{
    MqlDateTime timeStruct;
    TimeToStruct(time, timeStruct);
    return timeStruct.day_of_week;
}
//+------------------------------------------------------------------+