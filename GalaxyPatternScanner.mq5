//+------------------------------------------------------------------+
//| GalaxyPatternScanner.mq5                                          |
//| "Galaxy Pattern Scanner" - a standalone, MACD-free indicator.      |
//| Detects flag, triangle, and pennant patterns forming in recent     |
//| price action and draws them directly on the price chart. Purely    |
//| visual/informational - nothing here feeds any trading decision.    |
//+------------------------------------------------------------------+
//| VERSION: 1.0                                                       |
//|                                                                    |
//| History: this pattern-detection logic was originally built inside  |
//| GalaxyMACD_SignalDiagnostic.mq5, then extracted into its own file  |
//| per direct request - it never actually used any MACD data (only    |
//| raw price: high/low/close), so it belongs on its own rather than   |
//| mixed into a MACD-focused tool.                                    |
//|                                                                    |
//| The version is a single macro (IND_VERSION below), built into the  |
//| indicator's own shortname automatically, so it's always visible    |
//| directly on the chart without needing to check this file.          |
//+------------------------------------------------------------------+
//| WHAT THIS DETECTS:                                                  |
//|                                                                    |
//| Scans the most recent InpPatternLookback bars for swing highs/lows |
//| (a bar whose high/low is more extreme than InpSwingRadius bars on  |
//| each side), fits a simple line through the first and last swing on |
//| each side, and classifies the resulting shape:                    |
//|                                                                    |
//|   - Ascending Triangle  - upper boundary flat, lower boundary rising|
//|   - Descending Triangle - upper boundary falling, lower flat       |
//|   - Symmetrical Triangle - both converging (upper falling, lower   |
//|     rising), with NO genuine prior "pole" move - could form         |
//|     anywhere, including at a top or bottom, with no directional    |
//|     bias implied                                                    |
//|   - Bull/Bear Pennant - the SAME converging shape as a Symmetrical |
//|     Triangle, but WITH a genuine prior pole - a continuation       |
//|     pattern mid-trend, not a reversal setup                        |
//|   - Bull/Bear Flag - a roughly parallel (or flat) channel, but     |
//|     ONLY if a genuine sharp prior move (a real "pole") precedes it -|
//|     otherwise it's just an ordinary drifting channel, not a flag   |
//|                                                                    |
//| HONEST NOTE on reliability: at a 15-25 bar window, there's only    |
//| room for 2-3 genuine swing points per side, not the 4-5 a longer   |
//| window would give - this trades statistical confidence for         |
//| catching fast, intraday formations. Every threshold (what counts   |
//| as "flat" vs "sloping", what counts as a genuine "pole") is a       |
//| reasoned starting point, not validated against real data. Flag and |
//| triangle patterns are inherently fuzzier than mechanical indicators|
//| like a MACD zero-cross - even experienced chartists disagree on    |
//| exactly where these shapes' boundaries sit.                        |
//+------------------------------------------------------------------+
#define IND_VERSION "1.0"

#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

input bool  InpShowPatterns    = true;   // detect and draw flag/triangle/pennant patterns (visual only, no trading logic)
input int   InpPatternLookback = 25;     // how many recent bars to scan for a forming pattern
input int   InpSwingRadius     = 1;      // bars on each side needed to confirm a swing high/low - kept small given the short lookback

string objPrefix = "GPat_"; // object name prefix, avoids collisions with anything else on the chart
string indicatorShortName = ""; // set once in OnInit, single source of truth

//+------------------------------------------------------------------+
int OnInit()
{
   indicatorShortName = "Galaxy Pattern Scanner v" + IND_VERSION;
   IndicatorSetString(INDICATOR_SHORTNAME, indicatorShortName);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Everything this indicator draws lives on the main chart (window 0),
   // since it has no subwindow of its own.
   int total = ObjectsTotal(0, 0, -1);
   for(int k = total - 1; k >= 0; k--)
   {
      string nm = ObjectName(0, k, 0, -1);
      if(StringFind(nm, objPrefix) == 0)
         ObjectDelete(0, nm);
   }
}

//+------------------------------------------------------------------+
// Detects a forming flag, triangle, or pennant pattern within the most
// recent InpPatternLookback bars, and draws it directly on the price
// chart. Purely visual/informational - nothing here feeds any trading
// decision. See the file header for the full honesty note on why this
// is inherently fuzzier than a mechanical indicator.
void DetectAndDrawPattern(const int rates_total, const double &high[], const double &low[],
                          const double &close[], const datetime &time[])
{
   string upperName = objPrefix + "PatUpper";
   string lowerName = objPrefix + "PatLower";
   string labelName = objPrefix + "PatLabel";

   int winStart = rates_total - InpPatternLookback;
   if(winStart < InpSwingRadius + 1)
   {
      ObjectDelete(0, upperName);
      ObjectDelete(0, lowerName);
      ObjectDelete(0, labelName);
      return; // not enough history for even one confirmed swing
   }

   // Collect swing highs/lows within the window - fixed-size arrays,
   // comfortably more than a 15-25 bar window could ever produce.
   int swingHighIdx[20]; double swingHighPrice[20]; int swingHighCount = 0;
   int swingLowIdx[20];  double swingLowPrice[20];  int swingLowCount = 0;

   int scanStart = MathMax(InpSwingRadius, winStart);
   int scanEnd = rates_total - 1 - InpSwingRadius;

   for(int idx = scanStart; idx <= scanEnd; idx++)
   {
      bool isHigh = true, isLow = true;
      for(int k = 1; k <= InpSwingRadius; k++)
      {
         if(high[idx-k] >= high[idx] || high[idx+k] >= high[idx]) isHigh = false;
         if(low[idx-k] <= low[idx] || low[idx+k] <= low[idx]) isLow = false;
      }
      if(isHigh && swingHighCount < 20)
      {
         swingHighIdx[swingHighCount] = idx;
         swingHighPrice[swingHighCount] = high[idx];
         swingHighCount++;
      }
      if(isLow && swingLowCount < 20)
      {
         swingLowIdx[swingLowCount] = idx;
         swingLowPrice[swingLowCount] = low[idx];
         swingLowCount++;
      }
   }

   if(swingHighCount < 2 || swingLowCount < 2)
   {
      ObjectDelete(0, upperName);
      ObjectDelete(0, lowerName);
      ObjectDelete(0, labelName);
      return;
   }

   int upperFirstIdx = swingHighIdx[0], upperLastIdx = swingHighIdx[swingHighCount-1];
   double upperFirstPrice = swingHighPrice[0], upperLastPrice = swingHighPrice[swingHighCount-1];
   int lowerFirstIdx = swingLowIdx[0], lowerLastIdx = swingLowIdx[swingLowCount-1];
   double lowerFirstPrice = swingLowPrice[0], lowerLastPrice = swingLowPrice[swingLowCount-1];

   if(upperLastIdx == upperFirstIdx || lowerLastIdx == lowerFirstIdx)
   {
      ObjectDelete(0, upperName);
      ObjectDelete(0, lowerName);
      ObjectDelete(0, labelName);
      return;
   }

   double upperSlope = (upperLastPrice - upperFirstPrice) / (double)(upperLastIdx - upperFirstIdx);
   double lowerSlope = (lowerLastPrice - lowerFirstPrice) / (double)(lowerLastIdx - lowerFirstIdx);

   double avgRange = 0.0;
   int rangeCount = 0;
   for(int idx = winStart; idx < rates_total; idx++)
   {
      if(idx < 0) continue;
      avgRange += (high[idx] - low[idx]);
      rangeCount++;
   }
   if(rangeCount == 0)
   {
      ObjectDelete(0, upperName);
      ObjectDelete(0, lowerName);
      ObjectDelete(0, labelName);
      return;
   }
   avgRange /= rangeCount;

   double flatThreshold = avgRange * 0.15; // reasoned starting point, NOT validated

   bool upperFlat    = MathAbs(upperSlope) < flatThreshold;
   bool lowerFlat    = MathAbs(lowerSlope) < flatThreshold;
   bool upperRising  = upperSlope >= flatThreshold;
   bool upperFalling = upperSlope <= -flatThreshold;
   bool lowerRising  = lowerSlope >= flatThreshold;
   bool lowerFalling = lowerSlope <= -flatThreshold;

   // Computed once, reused for BOTH flag detection (channel shapes) and
   // pennant detection (converging shapes) below - a pennant is
   // geometrically the same converging shape as a Symmetrical Triangle,
   // distinguished only by whether a genuine pole precedes it, exactly
   // mirroring how a flag is distinguished from an ordinary channel.
   bool hasPole = false;
   bool poleIsUp = false;
   int poleBars = 4;
   int poleStart = winStart - poleBars;
   if(poleStart >= 0)
   {
      double poleMove = close[winStart] - close[poleStart];
      if(MathAbs(poleMove) >= avgRange * 2.0) // reasoned starting point, NOT validated
      {
         hasPole = true;
         poleIsUp = (poleMove > 0);
      }
   }

   string patternName = "";
   color patternColor = clrGray;

   if(upperFlat && lowerRising)
   {
      patternName = "Ascending Triangle";
      patternColor = clrLimeGreen;
   }
   else if(upperFalling && lowerFlat)
   {
      patternName = "Descending Triangle";
      patternColor = clrRed;
   }
   else if(upperFalling && lowerRising)
   {
      // Converging shape - a PENNANT if it follows a genuine pole (a
      // mid-trend continuation setup), otherwise a plain Symmetrical
      // Triangle (could form anywhere, including at a top or bottom,
      // with no directional context implied).
      if(hasPole)
      {
         patternName = poleIsUp ? "Bull Pennant" : "Bear Pennant";
         patternColor = clrMagenta;
      }
      else
      {
         patternName = "Symmetrical Triangle";
         patternColor = clrGold;
      }
   }
   else if((upperFlat && lowerFlat) || (upperRising && lowerRising) || (upperFalling && lowerFalling))
   {
      if(hasPole)
      {
         patternName = poleIsUp ? "Bull Flag" : "Bear Flag";
         patternColor = poleIsUp ? clrLimeGreen : clrRed;
      }
   }

   if(patternName == "")
   {
      ObjectDelete(0, upperName);
      ObjectDelete(0, lowerName);
      ObjectDelete(0, labelName);
      return;
   }

   if(ObjectFind(0, upperName) < 0)
      ObjectCreate(0, upperName, OBJ_TREND, 0, time[upperFirstIdx], upperFirstPrice, time[upperLastIdx], upperLastPrice);
   else
   {
      ObjectMove(0, upperName, 0, time[upperFirstIdx], upperFirstPrice);
      ObjectMove(0, upperName, 1, time[upperLastIdx], upperLastPrice);
   }
   ObjectSetInteger(0, upperName, OBJPROP_COLOR, patternColor);
   ObjectSetInteger(0, upperName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, upperName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, upperName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, upperName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, upperName, OBJPROP_HIDDEN, true);

   if(ObjectFind(0, lowerName) < 0)
      ObjectCreate(0, lowerName, OBJ_TREND, 0, time[lowerFirstIdx], lowerFirstPrice, time[lowerLastIdx], lowerLastPrice);
   else
   {
      ObjectMove(0, lowerName, 0, time[lowerFirstIdx], lowerFirstPrice);
      ObjectMove(0, lowerName, 1, time[lowerLastIdx], lowerLastPrice);
   }
   ObjectSetInteger(0, lowerName, OBJPROP_COLOR, patternColor);
   ObjectSetInteger(0, lowerName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lowerName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, lowerName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, lowerName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lowerName, OBJPROP_HIDDEN, true);

   datetime labelTime = time[rates_total-1];
   double labelPrice = high[rates_total-1];
   if(ObjectFind(0, labelName) < 0)
      ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, labelPrice);
   else
      ObjectMove(0, labelName, 0, labelTime, labelPrice);
   ObjectSetString(0, labelName, OBJPROP_TEXT, patternName);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, patternColor);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(InpShowPatterns)
      DetectAndDrawPattern(rates_total, high, low, close, time);

   return rates_total;
}
//+------------------------------------------------------------------+
