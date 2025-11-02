//+------------------------------------------------------------------+
//|                                                   Supertrend.mq5 |
//|                        Copyright 2024, Triangle Trading System    |
//|                                      Version: 1.00               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Triangle Trading System"
#property link      ""
#property version   "1.00"
#property description "Supertrend Indicator for Triangle EA"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1
#property indicator_label1  "Supertrend"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2
#property indicator_label2  "Supertrend Direction"
#property indicator_type2   DRAW_COLORING
#property indicator_color2  clrGreen, clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Input parameters
input int               Period      = 10;     // ATR Period
input double            Multiplier  = 3.0;    // ATR Multiplier

//--- Indicator buffers
double                 SupertrendBuffer[];
double                 TrendBuffer[];

//--- Global variables
int                    atrHandle;
double                 atrBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set buffers as series
   ArraySetAsSeries(SupertrendBuffer, true);
   ArraySetAsSeries(TrendBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   
   //--- Set indicator buffers
   SetIndexBuffer(0, SupertrendBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, TrendBuffer, INDICATOR_COLOR_INDEX);
   
   //--- Set ATR handle
   atrHandle = iATR(_Symbol, _Period, Period);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator");
      return(INIT_FAILED);
   }
   
   //--- Set labels
   string shortname = "Supertrend(" + IntegerToString(Period) + "," + DoubleToString(Multiplier, 1) + ")";
   IndicatorSetString(INDICATOR_SHORTNAME, shortname);
   
   Print("Supertrend indicator initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[])
{
   //--- Copy ATR data
   if(CopyBuffer(atrHandle, 0, 0, rates_total, atrBuffer) <= 0)
      return(0);
   
   //--- Calculate Supertrend
   for(int i = rates_total - 1; i >= 0; i--)
   {
      if(i == rates_total - 1)
      {
         //--- Initialize with first values
         SupertrendBuffer[i] = close[i];
         TrendBuffer[i] = 1;
      }
      else
      {
         //--- Calculate basic upper and lower bands
         double hl2 = (high[i] + low[i]) / 2.0;
         double atr = atrBuffer[i];
         double basicUpperBand = hl2 + (Multiplier * atr);
         double basicLowerBand = hl2 - (Multiplier * atr);
         
         //--- Calculate final upper and lower bands
         double finalUpperBand = basicUpperBand;
         double finalLowerBand = basicLowerBand;
         
         if(i < rates_total - 1)
         {
            if(basicUpperBand < finalUpperBand || close[i-1] > finalUpperBand)
               finalUpperBand = basicUpperBand;
            
            if(basicLowerBand > finalLowerBand || close[i-1] < finalLowerBand)
               finalLowerBand = basicLowerBand;
         }
         
         //--- Determine trend and supertrend value
         if(TrendBuffer[i+1] == 1 && close[i] <= finalLowerBand)
         {
            TrendBuffer[i] = -1;
            SupertrendBuffer[i] = finalLowerBand;
         }
         else if(TrendBuffer[i+1] == -1 && close[i] >= finalUpperBand)
         {
            TrendBuffer[i] = 1;
            SupertrendBuffer[i] = finalUpperBand;
         }
         else if(TrendBuffer[i+1] == 1)
         {
            TrendBuffer[i] = 1;
            SupertrendBuffer[i] = finalLowerBand;
         }
         else
         {
            TrendBuffer[i] = -1;
            SupertrendBuffer[i] = finalUpperBand;
         }
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+