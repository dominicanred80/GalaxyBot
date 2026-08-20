//+------------------------------------------------------------------+
//| GalaxyMACD_SignalDiagnostic.mq5                                   |
//| "Galaxy Signal & Pattern Scanner" - renamed to reflect that this   |
//| indicator now does meaningfully more than MACD signal diagnostics  |
//| alone (see full capability list below).                            |
//+------------------------------------------------------------------+
//| VERSION: 1.0 (first formal version number - this file went through |
//| several structural eras before now without one: originally a       |
//| 3-way MACD-signal comparison tool -> simplified to a single         |
//| confirmed-signal diagnostic -> gained E labels + cross-dots for     |
//| exit timing -> gained flag/triangle/pennant pattern detection.      |
//| Starting the version count here, at this more mature, renamed      |
//| point, rather than retroactively numbering the earlier eras.       |
//|                                                                    |
//| The version is a single macro (IND_VERSION below) - it's built     |
//| into the indicator's own shortname automatically, so it's always   |
//| visible directly in the subwindow's top-left label without needing |
//| to check this file, and can never drift out of sync the way two    |
//| separately-maintained strings could.                               |
//+------------------------------------------------------------------+
//| WHAT THIS INDICATOR DOES - full capability list:                   |
//|                                                                    |
//| 1. MACD SIGNAL DIAGNOSTIC (the original purpose)                   |
//|    CONFIRMED via direct visual review: the signal the EA trades on |
//|    is the MAIN LINE crossing zero - the blue arrows below. Plotted |
//|    in a separate lower window:                                     |
//|      - Main line   (electric blue) = EMA(fast) - EMA(slow)          |
//|      - Signal line (amber) = SMA(main, signal period) - MT5's real |
//|        native convention                                            |
//|      - Histogram (4-color, main minus signal) - a "momentum         |
//|        breathing" style: vivid when building, muted when fading,   |
//|        distinct colors above vs below zero. Visual context only -  |
//|        not a trade signal on its own.                              |
//|      - Bold arrows exactly where the main line crosses zero -      |
//|        bright aqua triangle up for a buy, royal blue triangle down |
//|        for a sell. This is the entry condition the EA actually     |
//|        trades on.                                                   |
//|                                                                    |
//| 2. "E" EXIT-TIMING MARKER (InpShowTPLabels)                        |
//|    After each arrow, watches for whichever happens FIRST: the main |
//|    line crossing back through the signal line in the opposite      |
//|    direction, OR the histogram fading from vivid to dim on the     |
//|    same side (momentum fading, no cross needed). Marks a bolded    |
//|    "E" text label at that bar, with a thin dotted vertical line    |
//|    pinpointing the exact bar. Any new arrow (either direction)     |
//|    restarts the watching cycle fresh.                              |
//|                                                                    |
//| 3. CROSS-DOTS (InpShowTPLabels, same toggle as E)                  |
//|    A round dot at every main/signal-line crossing - but FILTERED   |
//|    to only the direction relevant to the most recently fired       |
//|    arrow: after a buy arrow, only red/bearish crosses show, as a   |
//|    potential warning; after a sell arrow, only green/bullish       |
//|    crosses show. Persists until the next arrow, independent of     |
//|    whether E already fired.                                        |
//|                                                                    |
//| 4. FLAG / TRIANGLE / PENNANT PATTERN DETECTION (InpShowPatterns)   |
//|    Drawn on the MAIN price chart (not this subwindow - patterns    |
//|    are about price action, so that's where they visually belong). |
//|    Purely visual/informational - nothing here feeds any trading    |
//|    decision. Scans the most recent InpPatternLookback bars for     |
//|    swing highs/lows, fits a simple line through each side, and     |
//|    classifies:                                                      |
//|      - Ascending / Descending / Symmetrical Triangle - based on    |
//|        which side is flat, rising, or falling                      |
//|      - Bull / Bear Flag - a roughly parallel (or flat) channel,    |
//|        but ONLY if a genuine sharp prior move (a real "pole")      |
//|        precedes it - otherwise it's just an ordinary drifting      |
//|        channel, not a flag                                         |
//|      - Bull / Bear Pennant (NEW) - the SAME converging shape as a  |
//|        Symmetrical Triangle, but specifically when a genuine pole  |
//|        precedes it too - a continuation pattern mid-trend, as      |
//|        opposed to a plain triangle which could form anywhere,      |
//|        including at a top or bottom, with no directional context   |
//|                                                                    |
//|    HONEST NOTE on reliability: at a 15-25 bar window, there's only |
//|    room for 2-3 genuine swing points per side, not the 4-5 a       |
//|    longer window would give - this trades statistical confidence   |
//|    for catching fast, intraday formations. Every threshold (what   |
//|    counts as "flat" vs "sloping", what counts as a genuine "pole") |
//|    is a reasoned starting point, not validated against real data,  |
//|    and this is inherently fuzzier than the mechanical MACD-based   |
//|    logic in sections 1-3 above.                                    |
//+------------------------------------------------------------------+
#define IND_VERSION "1.0"

#property strict
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   5

#property indicator_label1  "MACD Main"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_style1  STYLE_SOLID

#property indicator_label2  "MACD Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_width2  2
#property indicator_style2  STYLE_SOLID

#property indicator_label3  "Histogram"
#property indicator_type3   DRAW_COLOR_HISTOGRAM
#property indicator_color3  clrLimeGreen,clrPaleGreen,clrCrimson,clrLightPink
#property indicator_width3  3

#property indicator_label4  "BUY signal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrAqua
#property indicator_width4  4

#property indicator_label5  "SELL signal"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRoyalBlue
#property indicator_width5  4

input int   InpMACDFastPeriod   = 12;
input int   InpMACDSlowPeriod   = 26;
input int   InpMACDSignalPeriod = 40;
input bool  InpShowHistogram    = true;   // the 4-color momentum histogram (visual context only)
input bool  InpShowSignalLine   = true;   // the amber signal line (visual context only, not the trade signal)
input bool  InpShowTPLabels     = true;   // Show E labels and cross-dots
input int   InpTPLookbackBars   = 500;    // only process/draw TP labels for the most recent N bars - keeps object churn reasonable on long history
input bool  InpShowPatterns     = true;   // detect and draw flag/triangle patterns on the price chart (visual only, no trading logic)
input int   InpPatternLookback  = 25;     // how many recent bars to scan for a forming pattern
input int   InpSwingRadius      = 1;      // bars on each side needed to confirm a swing high/low - kept small given the short lookback

double bufMain[];
double bufSignal[];
double bufHist[];
double bufHistColor[];
double bufBuyArrow[];
double bufSellArrow[];

int macdHandle = INVALID_HANDLE;
string objPrefix = "GMDiag_"; // object name prefix for E labels and cross-dots, avoids collisions with anything else on the chart
int subWin = -1; // this indicator's own subwindow index, resolved once needed
string indicatorShortName = ""; // set once in OnInit, referenced everywhere else - single source of truth, can't drift out of sync

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, bufMain,      INDICATOR_DATA);
   SetIndexBuffer(1, bufSignal,    INDICATOR_DATA);
   SetIndexBuffer(2, bufHist,      INDICATOR_DATA);
   SetIndexBuffer(3, bufHistColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, bufBuyArrow,  INDICATOR_DATA);
   SetIndexBuffer(5, bufSellArrow, INDICATOR_DATA);

   PlotIndexSetInteger(3, PLOT_ARROW, 233); // solid triangle up
   PlotIndexSetInteger(4, PLOT_ARROW, 234); // solid triangle down

   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   if(!InpShowSignalLine)
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   if(!InpShowHistogram)
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);

   macdHandle = iMACD(_Symbol, PERIOD_CURRENT, InpMACDFastPeriod, InpMACDSlowPeriod, InpMACDSignalPeriod, PRICE_CLOSE);

   if(macdHandle == INVALID_HANDLE)
   {
      Print("GalaxyMACD_SignalDiagnostic: failed to create MACD handle. Error: ", GetLastError());
      return INIT_FAILED;
   }

   indicatorShortName = "Galaxy Signal & Pattern Scanner v" + IND_VERSION;
   IndicatorSetString(INDICATOR_SHORTNAME, indicatorShortName);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(macdHandle != INVALID_HANDLE)
      IndicatorRelease(macdHandle);

   // Clean up every E label and cross-dot this indicator ever drew, in its own subwindow
   int win = (subWin >= 0) ? subWin : ChartWindowFind(0, indicatorShortName);
   if(win >= 0)
   {
      int total = ObjectsTotal(0, win, -1);
      for(int k = total - 1; k >= 0; k--)
      {
         string nm = ObjectName(0, k, win, -1);
         if(StringFind(nm, objPrefix) == 0)
            ObjectDelete(0, nm);
      }
   }

   // Pattern trendlines/labels live on the MAIN price chart (window 0),
   // not this indicator's own subwindow - patterns are about price
   // action, so that's where they need to visually sit. Cleaned up
   // separately here since it's a different window.
   int total0 = ObjectsTotal(0, 0, -1);
   for(int k = total0 - 1; k >= 0; k--)
   {
      string nm = ObjectName(0, k, 0, -1);
      if(StringFind(nm, objPrefix) == 0)
         ObjectDelete(0, nm);
   }
}

//+------------------------------------------------------------------+
// Draws the "E" marker at the given bar: a thin vertical line pinpoints
// the EXACT bar (per direct request, so there's no ambiguity about
// which bar the indicator means), with the bolded "E" text sitting at
// the end of that line. Anchored so buy-cycle markers sit above the
// main line and sell-cycle markers sit below it, using MQL5's own
// anchor property rather than a manually-guessed price offset (which
// wouldn't scale consistently across different instruments' very
// different MACD value ranges). The line uses OBJ_VLINE, the same
// technique already proven for the EA's own cross markers.
void DrawELabel(datetime barTime, double priceLevel, int direction, int win)
{
   string lineName = objPrefix + "ELine_" + IntegerToString((long)barTime);
   string textName = objPrefix + "E_" + IntegerToString((long)barTime);
   color labelColor = (direction == 1) ? clrAqua : clrRoyalBlue;

   if(ObjectFind(0, lineName) < 0)
      ObjectCreate(0, lineName, OBJ_VLINE, win, barTime, 0);
   else
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, barTime);

   ObjectSetInteger(0, lineName, OBJPROP_COLOR, labelColor);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, true);

   if(ObjectFind(0, textName) < 0)
      ObjectCreate(0, textName, OBJ_TEXT, win, barTime, priceLevel);
   else
   {
      ObjectSetInteger(0, textName, OBJPROP_TIME, 0, barTime);
      ObjectMove(0, textName, 0, barTime, priceLevel);
   }

   ObjectSetString(0, textName, OBJPROP_TEXT, "E");
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, labelColor);
   ObjectSetInteger(0, textName, OBJPROP_ANCHOR, (direction == 1) ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, textName, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
// Draws a round dot exactly at a main-line/signal-line crossing.
// FIX, found directly from a real screenshot: OBJ_ARROW with a
// Wingdings glyph code does not center reliably on its anchor point -
// different Wingdings characters have different internal baseline/
// bounding-box quirks that throw off where they actually render,
// which is exactly why the dots appeared scattered rather than sitting
// on the crossing. Switched to OBJ_TEXT (the same technique already
// proven to anchor correctly and predictably for the E label) using
// plain ASCII character 108 rendered in the Wingdings font - this
// renders as a filled circle without needing any Unicode escape
// sequence, which MQL5 does not interpret in string literals anyway.
void DrawCrossDot(datetime barTime, double priceLevel, bool isUpCross, int win)
{
   string name = objPrefix + "Dot_" + IntegerToString((long)barTime);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, win, barTime, priceLevel);
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, barTime);
      ObjectMove(0, name, 0, barTime, priceLevel);
   }

   color dotColor = isUpCross ? clrLimeGreen : clrRed;
   ObjectSetString(0, name, OBJPROP_TEXT, CharToString(108)); // Wingdings 'l' = filled circle glyph
   ObjectSetString(0, name, OBJPROP_FONT, "Wingdings");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12); // per direct request - "not a small one"
   ObjectSetInteger(0, name, OBJPROP_COLOR, dotColor);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
// Detects a forming flag or triangle pattern within the most recent
// InpPatternLookback bars, and draws it on the MAIN price chart (not
// this indicator's own subwindow - patterns are about price action, so
// that's where they visually belong). Purely visual/informational per
// direct instruction - nothing here feeds any trading decision.
//
// HONEST NOTE on reliability: at a 10-15 bar window, there's only room
// for 2-3 genuine swing points on each side, not the 4-5 a longer
// window would allow - meaning this trades statistical confidence for
// catching fast, intraday formations. Every threshold below (what
// counts as "flat" vs "sloping", what counts as a genuine "pole") is a
// reasoned starting point, not validated against real data, and this
// is inherently fuzzier than the bot's mechanical MACD-based logic.
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
   // comfortably more than a 10-15 bar window could ever produce.
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
      // Converging shape - per direct request, a PENNANT if it follows
      // a genuine pole (a mid-trend continuation setup), otherwise a
      // plain Symmetrical Triangle (could form anywhere, including at
      // a top or bottom, with no directional context implied).
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
   if(rates_total < InpMACDSlowPeriod + InpMACDSignalPeriod + 5)
      return 0;

   double mainBuf[];
   double signalBuf[];
   ArraySetAsSeries(mainBuf, true);
   ArraySetAsSeries(signalBuf, true);

   if(CopyBuffer(macdHandle, 0, 0, rates_total, mainBuf) <= 0)
      return 0;
   if(CopyBuffer(macdHandle, 1, 0, rates_total, signalBuf) <= 0)
      return 0;

   int copiedMain = ArraySize(mainBuf);
   int copiedSignal = ArraySize(signalBuf);

   if(subWin < 0)
      subWin = ChartWindowFind(0, indicatorShortName);

   // Clean up all existing TP labels before redrawing fresh this pass -
   // this indicator recomputes its full buffers every call (matching
   // its existing, already-established pattern), so labels are cleared
   // and rebuilt the same way rather than tracked incrementally.
   if(InpShowTPLabels && subWin >= 0)
   {
      int total = ObjectsTotal(0, subWin, -1);
      for(int k = total - 1; k >= 0; k--)
      {
         string nm = ObjectName(0, k, subWin, -1);
         if(StringFind(nm, objPrefix) == 0)
            ObjectDelete(0, nm);
      }
   }

   // "E" state machine - simplified now that TP2 no longer exists:
   //  0 = idle, no active cycle
   //  1 = watching for E (main-vs-signal opposite cross, OR histogram
   //      fading from vivid to dim on the same side, whichever first)
   // direction: 1 = buy cycle, -1 = sell cycle
   // ANY new arrow (same or opposite direction) always restarts the
   // cycle fresh - there's no longer a distinction to make between
   // same-direction and opposite-direction arrows, since there's no
   // second stage to complete or interrupt.
   int eState = 0;
   int eDirection = 0;

   // Separate from eState/eDirection above - per direct request, dots
   // are now filtered to only show the direction RELEVANT to whichever
   // arrow fired most recently, and this needs to persist even after E
   // already fired and eState has gone back to idle (unlike eState,
   // which resets once E fires). 0 = no arrow yet, 1 = last arrow was
   // buy (only show red/bearish dots), -1 = last arrow was sell (only
   // show green/bullish dots).
   int lastArrowDirection = 0;

   for(int i = 1; i < rates_total; i++)
   {
      int shiftFromEnd = rates_total - 1 - i;
      int shiftPrevFromEnd = shiftFromEnd + 1;

      if(shiftFromEnd < 0 || shiftFromEnd >= copiedMain || shiftFromEnd >= copiedSignal)
         continue;
      if(shiftPrevFromEnd >= copiedMain || shiftPrevFromEnd >= copiedSignal)
         continue;

      double mainNow  = mainBuf[shiftFromEnd];
      double mainPrev = mainBuf[shiftPrevFromEnd];
      double sigNow   = signalBuf[shiftFromEnd];
      double sigPrev  = signalBuf[shiftPrevFromEnd];

      double histNow  = mainNow - sigNow;
      double histPrev = mainPrev - sigPrev;

      bufMain[i]   = mainNow;
      bufSignal[i] = sigNow;
      bufHist[i]   = histNow;

      bool rising = histNow > histPrev;
      if(histNow >= 0.0)
         bufHistColor[i] = rising ? 0 : 1;
      else
         bufHistColor[i] = rising ? 3 : 2;

      bufBuyArrow[i]  = EMPTY_VALUE;
      bufSellArrow[i] = EMPTY_VALUE;

      bool firedBuyArrow  = (mainPrev <= 0.0 && mainNow > 0.0);
      bool firedSellArrow = (mainPrev >= 0.0 && mainNow < 0.0);

      if(firedBuyArrow)
         bufBuyArrow[i] = mainNow;
      else if(firedSellArrow)
         bufSellArrow[i] = mainNow;

      // Only draw labels within the recent window - the state machine
      // itself still runs across the full history so it correctly
      // reflects reality by the time we reach that window, but object
      // creation (the expensive part) is scoped down per direct design
      // consideration to keep this reasonable on long history.
      bool withinDrawWindow = (rates_total - i) <= InpTPLookbackBars;

      if(firedBuyArrow || firedSellArrow)
      {
         // Any arrow always restarts the cycle fresh, per direct
         // instruction - no distinction needed anymore between same-
         // and opposite-direction, since there's no second stage.
         eState = 1;
         eDirection = firedBuyArrow ? 1 : -1;
         lastArrowDirection = eDirection;
      }
      else if(eState == 1)
      {
         bool crossOpposite;
         if(eDirection == 1)
            crossOpposite = (mainPrev >= sigPrev && mainNow < sigNow);
         else
            crossOpposite = (mainPrev <= sigPrev && mainNow > sigNow);

         bool dimTransition = false;
         if(i >= 2)
         {
            int prevColor = (int)bufHistColor[i-1];
            int curColor  = (int)bufHistColor[i];
            if(eDirection == 1)
               dimTransition = (prevColor == 0 && curColor == 1); // vivid positive -> dim positive
            else
               dimTransition = (prevColor == 2 && curColor == 3); // vivid negative -> dim negative
         }

         if(crossOpposite || dimTransition)
         {
            if(InpShowTPLabels && withinDrawWindow && subWin >= 0)
               DrawELabel(time[i], mainNow, eDirection, subWin);
            eState = 0; // done - idle until the next arrow starts a new cycle
         }
      }

      // Round dot at a main/signal cross - per direct revision, now
      // FILTERED by the direction of the most recent arrow: after a buy
      // arrow, only the red/bearish (downward) cross matters as a
      // potential warning; after a sell arrow, only the green/bullish
      // (upward) cross matters. This persists until the NEXT arrow,
      // regardless of whether E already fired in between.
      bool crossUpAlways   = (mainPrev <= sigPrev && mainNow > sigNow);
      bool crossDownAlways = (mainPrev >= sigPrev && mainNow < sigNow);

      bool relevantDot = (lastArrowDirection == 1 && crossDownAlways) ||   // after a buy: only red/bearish crosses
                         (lastArrowDirection == -1 && crossUpAlways);      // after a sell: only green/bullish crosses

      if(relevantDot && InpShowTPLabels && withinDrawWindow && subWin >= 0)
         DrawCrossDot(time[i], mainNow, crossUpAlways, subWin);
   }

   if(InpShowPatterns)
      DetectAndDrawPattern(rates_total, high, low, close, time);

   return rates_total;
}
//+------------------------------------------------------------------+
