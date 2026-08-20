//+------------------------------------------------------------------+
//| GalaxyStrategy_ImprovedMACD_Dashboard.mq5                        |
//| "Improved entries" A/B testing - Version 2: BREAKOUT-CONFIRMED    |
//| + live on-chart dashboard                                          |
//+------------------------------------------------------------------+
//| Built per direct request. Entry confirmation requires BOTH:       |
//|   1) A breakout of dynamic support/resistance, using the exact    |
//|      consolidation settings from the "GALAXY Strategy by Miki     |
//|      Gala (Full Visual)" TradingView indicator: 10-bar lookback,  |
//|      0.3% breakout threshold - ported faithfully from the shared  |
//|      Pine Script logic (highest/lowest-over-N plus a same-OR      |
//|      simple prior-bar-high/low break).                             |
//|   2) MACD main line above the zero line for buys, below zero for  |
//|      sells (fast-line-vs-0 confirmation, as requested).            |
//|                                                                    |
//| Exit logic is kept IDENTICAL to the raw baseline (Version 1) -    |
//| opposite MACD zero-line cross closes the position - so the two    |
//| versions differ only in entry confirmation, isolating that as the |
//| variable under test. A reversal only opens a new position if the  |
//| new direction also satisfies the breakout+MACD confirmation;      |
//| otherwise it closes flat and waits for a valid signal.             |
//|                                                                    |
//| Signals evaluate ONLY on a completed candle close (no intrabar     |
//| repainting), matching how the Pine Script version behaves once a  |
//| bar is closed. Same wide, essentially-never-triggered emergency    |
//| stop-loss backstop as Version 1, for the same reason - not a       |
//| trading restriction, just protection against an account-destroying|
//| event with otherwise zero downside boundary. Set to 0 to disable. |
//|                                                                    |
//| NEW: live on-chart dashboard shows exactly what the bot sees each  |
//| bar - which of the four conditions (breakout up, breakout down,    |
//| MACD>0, MACD<0) are currently true, whether that adds up to a      |
//| valid signal, and full position detail (entry, live P&L, duration) |
//| whenever a trade is open. Updates every tick, no recreated objects |
//| (no flicker) - built once in OnInit, text/color updated in place.  |
//+------------------------------------------------------------------+
// Single source of truth for the version number - used both by the
// #property line below (for MT5's own display) AND in the trade
// comment sent with every order (built in OpenPosition). Bump this ONE
// value on every update; both places automatically stay in sync since
// they both reference this same macro rather than separate strings.
#define BOT_VERSION "2.48"

#property strict
#property copyright "Galaxy Strategy - Improved MACD (Breakout Confirmed)"
#property version   BOT_VERSION
#property description "v2.48: FIXED per direct feedback - Chaos Scalping (was"
#property description "group 11) was buried 8 groups away from Chaos Filter"
#property description "(2b) in the Inputs tab despite depending on it entirely"
#property description "- confirmed directly by checking the actual source"
#property description "order, which is what MT5 displays. Also, group 11 was"
#property description "displaying BEFORE group 10, numbers not even matching"
#property description "visual order. Moved Chaos Scalping to sit directly"
#property description "beside Chaos Filter and renumbered it 2c, so the"
#property description "dependency is obvious at a glance rather than"
#property description "something you have to remember exists 8 groups away."
#property description "v2.47: IMPROVED per direct feedback - the mismatched-"
#property description "dependency check no longer refuses to start the ENTIRE"
#property description "EA. A missing dependency between two settings"
#property description "shouldn't block the normal MACD strategy, which has"
#property description "nothing to do with Chaos Scalping at all. Now degrades"
#property description "gracefully: warns clearly, and Scalping simply stays"
#property description "disabled for that session (via a new chaosScalpingActive"
#property description "flag, checked everywhere instead of the raw input),"
#property description "while everything else runs completely normally."
#property description "v2.46: RESOLVED - the v2.45 diagnostic confirmed the"
#property description "root cause directly: InpEnableChaosScalping was true"
#property description "(left on from earlier testing) while InpUseChaosFilter"
#property description "was false - the safety check was working exactly as"
#property description "designed the whole time, not a bug. Removed the"
#property description "temporary diagnostic print now that its job is done."
#property description "Improved the check's own error message to show both"
#property description "actual current values directly, so this is self-"
#property description "explanatory if it ever happens again without needing"
#property description "a separate diagnostic."
#property description "v2.45: TEMPORARY DIAGNOSTIC - tracking down a real,"
#property description "unexplained init failure ('code 32767') when"
#property description "InpUseChaosFilter is turned on alone. Every explicit"
#property description "parameter check has been traced through and ruled"
#property description "out - InpEnableChaosScalping confirmed OFF the whole"
#property description "time, so the one check that requires it can't be"
#property description "firing. Added a print of every relevant input's"
#property description "actual value at the very start of OnInit, before any"
#property description "validation runs - will show concrete data on the next"
#property description "test instead of continued guessing. Will be removed"
#property description "once the actual cause is found."
#property description "v2.44: IMPROVED - per direct request, the Chaos Filter"
#property description "and Chaos Scalping input comments were shortened"
#property description "significantly - the originals were getting truncated"
#property description "in MT5's Inputs dialog, cut off mid-sentence. Full"
#property description "explanations moved into a block comment above each"
#property description "group instead - nothing lost, just relocated so the"
#property description "Inputs tab itself stays short and readable."
#property description "v2.43: NEW - per direct request, the ENTIRE dashboard"
#property description "border changes to a thick orange outline the moment"
#property description "chaos is detected, in addition to the existing red"
#property description "text in the Chaos Filter row - a whole-panel visual"
#property description "cue that's obvious at a glance, not something you have"
#property description "to read a specific line to notice."
#property description "v2.42: NEW - Chaos Scalping Mode (InpEnableChaosScalping,"
#property description "OFF by default, requires InpUseChaosFilter also ON)."
#property description "Extensively discussed before building - a completely"
#property description "separate strategy from MACD+breakout, active only"
#property description "during detected chaos: momentum direction from a very"
#property description "short-term MA, smallest lot size, independent trailing"
#property description "stop per position, pyramiding another position every"
#property description "N points of favorable movement (no cap), each new"
#property description "piece trailing on its own. REQUIRES hedging mode -"
#property description "confirmed directly from real account evidence (4"
#property description "separate simultaneous tickets on the same symbol) -"
#property description "since netting-mode accounts would merge these into one"
#property description "position, breaking the independent-trailing design."
#property description "Scalp positions are discovered by trade-comment tag"
#property description "('SCALP'), not persistent EA state - survives restarts"
#property description "naturally, and FindOurPosition() now excludes them so"
#property description "the normal strategy can never accidentally manage one."
#property description "CAUGHT DURING BUILD: the trailing/pyramid logic was"
#property description "initially placed in the once-per-bar trading section -"
#property description "would have updated only every 5 minutes on M5, directly"
#property description "contradicting 'quick' trailing. Moved to the every-tick"
#property description "section before shipping. Dashboard gained a new CHAOS"
#property description "SCALP section (status, direction, pyramid position"
#property description "count). NOT YET VALIDATED against real data -"
#property description "especially the point-based triggers for the 'Other'"
#property description "instrument bucket, which spans Gold/forex/crypto with"
#property description "very different natural price scales."
#property description "v2.41: NEW - Chaos Filter (InpUseChaosFilter, OFF by"
#property description "default), per direct request to avoid big losses"
#property description "during insane volatility with candles moving all over"
#property description "the place. Combines two measures: the Choppiness"
#property description "Index (distinguishes genuine trending from erratic"
#property description "back-and-forth churn - verified with real numbers: a"
#property description "clean trend scores 0.0, pure chop scores 73.7, well"
#property description "above the 61.8 threshold) and a volatility-spike check"
#property description "(current ATR vs its own recent percentile history,"
#property description "reusing the existing breakout ATR handle - no new"
#property description "indicator needed). New entries pause ONLY when BOTH"
#property description "are true together - a strong trend alone, or a quiet"
#property description "choppy market alone, doesn't trigger it. Does NOT"
#property description "affect managing an already-open trade. Dashboard shows"
#property description "Off/Clear/ACTIVE in Market Conditions, and the"
#property description "waiting-for banner explains it directly when active."
#property description "v2.40: FIX - found directly from a real case: the"
#property description "cross marker (vertical line at each MACD zero-cross)"
#property description "only needs the main line, but was gated behind a check"
#property description "that ALSO required the signal line - which needs a"
#property description "longer warm-up. If the signal line was ever briefly"
#property description "unavailable on the specific bar a cross happened"
#property description "(plausible right after attaching to a new symbol),"
#property description "that cross was silently skipped forever with no way"
#property description "to revisit it. Main-line data is now fetched and the"
#property description "marker drawn FIRST, fully decoupled from the signal"
#property description "line's availability. (Marker pruning via"
#property description "InpMaxChartMarkers, default 30, already existed -"
#property description "unrelated to this fix.)"
#property description "v2.39: REVISED per direct feedback - Smart"
#property description "Consolidation's width-freeze compared a MULTI-BAR"
#property description "range width against flat multiples (2-4x) of"
#property description "SINGLE-BAR ATR - an incompatible scale. Verified"
#property description "directly: the old tolerance was actually SMALLER than"
#property description "the natural width of even a genuinely tight range,"
#property description "meaning it was structurally near-impossible to ever"
#property description "accept anything - explaining reports of an obviously"
#property description "ranging market never being detected. Now scales by"
#property description "ATR x sqrt(lookback), a statistically grounded"
#property description "relationship. InpConsolidationWidthATRMult (now"
#property description "default 1.5) is a cushion on top of that baseline."
#property description "Session-awareness (2.8-2.12) REMOVED - it layered"
#property description "unvalidated complexity on top of a formula that"
#property description "wasn't correct at its base; can be revisited once"
#property description "this core mechanism is validated against real data."
#property description "v2.38: FIX - confirmed from a real screenshot: 4 chart"
#property description "objects (used while a trade is open - the historical-"
#property description "range and live-preview lines) were only ever cleaned"
#property description "up in the flat-state branch. If a trade closed and the"
#property description "bot then had no trusted range (Smart Consolidation),"
#property description "the early 'not ready' return skipped that cleanup"
#property description "entirely, leaving stale lines from the PREVIOUS trade"
#property description "visible on the chart indefinitely. Now cleaned up in"
#property description "both places."
#property description "v2.37: FIX - found directly from a real case: the"
#property description "dashboard showed the exact same 'Loading price"
#property description "history...' message whether it was genuinely still"
#property description "loading, OR Smart Consolidation had no tight-enough"
#property description "range to trust yet - the latter can persist far longer"
#property description "and isn't a data problem at all, but looked identical."
#property description "The dashboard now reports the SPECIFIC reason (MACD"
#property description "warming up / ATR warming up / no trusted range under"
#property description "current session / waiting for a genuinely different"
#property description "range after retirement), so this is never ambiguous"
#property description "again."
#property description "v2.36: NEW - Smart Consolidation range retirement, per"
#property description "direct feedback on a real risk: sustained sideways"
#property description "chop right at a frozen trusted boundary could"
#property description "repeatedly trigger fake trades from the same stale"
#property description "level. Once a trade fires from a specific trusted"
#property description "range, that exact range is now retired - it cannot"
#property description "trigger another entry until a genuinely different one"
#property description "forms (checked against an ATR-scaled tolerance, not a"
#property description "fixed distance). Dashboard's Range Status now"
#property description "distinguishes 'waiting because retired' from generic"
#property description "not-ready. Still unvalidated against real data -"
#property description "Smart Consolidation remains OFF by default."
#property description "v2.35: CRITICAL FIX - found directly from a live case:"
#property description "the v2.34 fix was correct, but persisted state from"
#property description "BEFORE that fix (the inverted resistance/support, saved"
#property description "by the old buggy calculation) was being reloaded on"
#property description "restart and treated as trustworthy, since nothing"
#property description "distinguished 'saved by old buggy code' from 'saved by"
#property description "fixed code'. Persisted state is now tagged with the"
#property description "bot version it was saved under - on ANY version change,"
#property description "ALL persisted state is discarded and starts fresh"
#property description "rather than partially trusted. This also automatically"
#property description "clears the currently-stale data, since it predates this"
#property description "tag existing at all."
#property description "v2.34: CRITICAL FIX - Smart Consolidation's percentile"
#property description "range was inverted (support showing ABOVE resistance)."
#property description "Root cause: ArraySort() does not respect"
#property description "ArraySetAsSeries - the series flag was left on before"
#property description "sorting, silently reversing the indexing used to pick"
#property description "percentiles. Confirmed directly: reproduced the exact"
#property description "inverted pattern seen live, and confirmed the fix"
#property description "(explicitly turning the series flag off before sorting)"
#property description "resolves it. If a trade opened while"
#property description "InpUseSmartConsolidation was on before this fix, its SL"
#property description "was calculated from corrupted values - check that"
#property description "position manually. Smart Consolidation remains OFF by"
#property description "default and still unvalidated against real data."
#property description "v2.33: Partial-close rounding made explicit and"
#property description "defensive, per direct request - when the target %"
#property description "doesn't divide evenly into whole lot steps, the"
#property description "CLOSED portion always rounds down and the REMAINDER"
#property description "up (e.g. 50% of 0.03 lots closes 0.01, keeps 0.02"
#property description "running - favors letting more of the position run,"
#property description "not less). Added a defensive epsilon for exact-split"
#property description "cases (e.g. 50% of 0.04 lots) where floating-point"
#property description "representation error could otherwise shave off one"
#property description "extra step. NOTE: verified the math above was already"
#property description "correct in v2.32 - if you saw the opposite behavior,"
#property description "please confirm you're running this exact version."
#property description "v2.32: NEW - critical trade state now persists"
#property description "across EA restarts/terminal crashes via MT5's Global"
#property description "Variables (rangeLocked, locked S/R, partialCloseDone,"
#property description "smaSwitchActive, Smart Consolidation's trusted range)."
#property description "Keys are built from symbol+magic number together, so"
#property description "running this on multiple instruments simultaneously"
#property description "(Gold/NAS/BTC) never collides - each gets its own"
#property description "distinct set of keys, verified with real symbol names."
#property description "OnInit reconciles loaded state against live reality:"
#property description "if a persisted 'locked' trade no longer actually"
#property description "exists (closed while the EA wasn't running), the"
#property description "stale state is detected and corrected immediately"
#property description "rather than carried forward."
#property description "v2.31: All input comments shortened - real screenshot"
#property description "showed them getting cut off mid-sentence in MT5's"
#property description "Inputs tab column (too long to display). Comment TEXT"
#property description "only - verified byte-for-byte identical: every"
#property description "variable name, type, and default value unchanged,"
#property description "and every variable-name occurrence anywhere in the"
#property description "file matches the previous version exactly. Full"
#property description "detail (validation status, defaults history, etc.)"
#property description "remains in this changelog and the Word doc guide."
#property description "v2.30: TWO major additions, both per direct request."
#property description "(1) SMA-switch exit: once floating profit crosses an"
#property description "instrument-appropriate threshold (100pts index, 500"
#property description "pips/$50 Gold-type, via the same auto-detection as lot"
#property description "sizing), the FINAL exit basis switches from MACD to a"
#property description "20 SMA cross - stays switched for the rest of that"
#property description "trade. Partial-close/breakeven is untouched, entirely"
#property description "separate mechanism. (2) Smart Consolidation (OFF by"
#property description "default - InpUseSmartConsolidation): percentile-based"
#property description "range resists a single manipulation wick dominating"
#property description "the calculation; width-vs-ATR freeze fixes the 'zombie"
#property description "grind' problem where a slow one-directional move kept"
#property description "chasing price and never registering a breakout;"
#property description "session-aware tightness thresholds apply different"
#property description "trust levels by detected trading session. NEITHER"
#property description "consolidation approach is backtested yet - Legacy"
#property description "stays the validated default until Smart Consolidation"
#property description "is properly tested against real data. Dashboard gained"
#property description "a new MARKET CONDITIONS section (timeframe, mode,"
#property description "session, range trust status) and SMA-switch status in"
#property description "the open-position block."
#property description "v2.29: CHANGED per direct request - during an open"
#property description "trade, the chart now shows all three: the broken"
#property description "level (amber, highlighted), the FULL historical range"
#property description "that was active at entry (both sides, muted gray for"
#property description "the non-broken side), AND a live, continuously-"
#property description "updating fresh range showing what's forming now -"
#property description "instead of just the single broken line alone. The"
#property description "live range is display-only, does not affect any"
#property description "trading decision - entries stay correctly locked out"
#property description "while a position is open."
#property description "v2.28: Dashboard title now shows 'GS - v' + the"
#property description "BOT_VERSION macro directly - always matches the"
#property description "actual running version automatically, same single"
#property description "source of truth used for trade comments. FIX -"
#property description "waiting-for banner text was running off the panel"
#property description "edge; now word-wraps across two lines (three lines"
#property description "total with the title) at a clean word boundary,"
#property description "reused generically for any message, not just"
#property description "manually split ones."
#property description "v2.27: FIX - found real cause of S/R lines visibly"
#property description "moving during an open trade: the dashed breakout"
#property description "trigger lines recalculated from LIVE ATR every tick"
#property description "regardless of whether the range was locked, even"
#property description "though the underlying S/R level itself was correctly"
#property description "static. Per direct request: while a trade is open, all"
#property description "searching lines now hide entirely (irrelevant - no new"
#property description "entry can happen anyway) and a single genuinely static"
#property description "BROKEN RESISTANCE/SUPPORT marker shows instead, at the"
#property description "exact locked level that was broken - removed the"
#property description "moment the trade closes, then normal searching lines"
#property description "resume for the next setup."
#property description "v2.26: CHANGED per direct request - SL moved from the"
#property description "raw opposite S/R level to the threshold-adjusted level"
#property description "beyond it (same distance used to confirm the breakout,"
#property description "whichever mode is active). Gives more room past the"
#property description "raw S/R boundary. Reuses the exact same distance"
#property description "calculation as entry confirmation, so they can never"
#property description "drift out of sync with each other."
#property description "v2.25: NEW - chart event markers. Thin vertical lines"
#property description "mark where the main line crosses zero (dotted), where"
#property description "a trade opens (solid), and where it closes (dashed) -"
#property description "green=buy, red=sell, placed behind the candles so"
#property description "price action is never obscured. A rotating buffer"
#property description "(InpMaxChartMarkers) keeps only the most recent N of"
#property description "each type so the chart never clutters up over a long"
#property description "session. Close markers work for ANY closure (EA exit,"
#property description "real SL hit, manual close) via the same detection"
#property description "used for the v2.18 range-lock fix."
#property description "v2.24: NEW - hard cap on the ATR-adaptive breakout"
#property description "distance (InpBreakoutMaxPoints, default 30). Per"
#property description "direct request: distance now never exceeds this,"
#property description "however high ATR spikes during news/extreme volatility"
#property description "- normal conditions scale freely, only genuine spikes"
#property description "get clamped. Applied identically to both the actual"
#property description "entry decision and the visual trigger lines."
#property description "v2.23: NEW - volatility-adaptive breakout mode"
#property description "(InpBreakoutMode). Per direct request: a fixed %"
#property description "threshold is too easy to trigger via noise/manipulation"
#property description "in high volatility, and unnecessarily strict when the"
#property description "market is quiet. ATR_ADAPTIVE (new default) sizes the"
#property description "breakout distance as ATR x multiplier instead of a"
#property description "flat %, shrinking in quiet markets and widening in"
#property description "volatile ones - this also naturally captures session-"
#property description "driven volatility differences without separate"
#property description "session-time logic, since ATR reflects current real"
#property description "conditions regardless of why they're occurring."
#property description "NOT YET BACKTESTED - InpBreakoutATRMult=0.5 is a"
#property description "starting estimate, not a validated value. Also:"
#property description "InpBreakoutPercent restored to validated 0.4% (the"
#property description "diagnostic 0.02% test value only applied when"
#property description "InpBreakoutMode=BREAKOUT_FIXED_PERCENT anyway)."
#property description "v2.22: DIAGNOSTIC - threshold lowered further to"
#property description "0.02% (~6pts on NAS100) for near-trivial mechanism"
#property description "testing. Still not a validated value - revert to"
#property description "0.4% once the breakout logic itself is confirmed."
#property description "v2.21: NEW - actual breakout TRIGGER level now drawn"
#property description "on the chart (dashed lines), not just the raw"
#property description "consolidation resistance/support. Shows exactly where"
#property description "price must close beyond to register as a breakout,"
#property description "so you can see precisely what's still missing."
#property description "v2.20: DIAGNOSTIC - InpBreakoutPercent temporarily"
#property description "lowered to 0.1% (from validated 0.4%) for faster"
#property description "breakout confirmation while testing. Full code audit"
#property description "of the breakout path (confluence toggles, range-lock"
#property description "mechanism, GetConsolidationRange) found no bug -"
#property description "0.4% requires ~118pts on NAS100, a genuinely large,"
#property description "selective move that may simply not occur often in a"
#property description "short testing window. Revert to 0.4% once confirmed."
#property description "v2.19: NEW - configurable entry confluence toggles"
#property description "(InpRequireMainLineSignal, InpRequireConsolBreakout)"
#property description "so you can pick just the MACD cross alone, or cross +"
#property description "breakout together, or (in future) other combinations."
#property description "Trade comments now automatically include the bot"
#property description "version and which confluences were active for that"
#property description "trade - version is a single macro (BOT_VERSION), not"
#property description "a separate hardcoded string, so it can never drift out"
#property description "of sync with the actual file version again."
#property description "v2.18: CRITICAL FIX - rangeLocked/partialCloseDone only"
#property description "ever reset inside the EA's OWN close path. If a"
#property description "position was ever closed EXTERNALLY (the real broker-"
#property description "side stop-loss actually hit, or a manual close) - a"
#property description "completely normal, expected event - the bot got"
#property description "permanently stuck comparing price against a stale,"
#property description "outdated consolidation range forever afterward,"
#property description "explaining a real 'stops taking trades' pattern found"
#property description "during live testing. Now detects any position closing"
#property description "since the last check, regardless of how, and resets"
#property description "state correctly either way."
#property description "v2.17: MAJOR CHANGE, deliberate - entry no longer"
#property description "requires the main-line cross and breakout on the"
#property description "SAME bar. Per direct instruction + repeated real-chart"
#property description "evidence of confirmed conditions with no trade taken."
#property description "Entry now fires on breakout + current main-line sign,"
#property description "however many bars ago it actually crossed."
#property description "HONEST NOTE: real-data testing showed this performs"
#property description "meaningfully worse than same-bar (PF 1.75-1.94 before,"
#property description "vs 1.02-1.21 for every relaxed variant tested) - this"
#property description "was a fully informed, deliberate choice, not an"
#property description "oversight. Re-tuned: lookback 20, threshold 0.4%"
#property description "(was 25/0.08%) for this new entry definition."
#property description "v2.16: NEW - live MACD Main value shown alongside the"
#property description "official (last closed bar) value. Same root cause as"
#property description "the breakout live-preview: the diagnostic indicator"
#property description "updates every tick including the still-forming bar,"
#property description "while the EA deliberately only acts on closed bars -"
#property description "now both are visible together instead of appearing to"
#property description "silently disagree."
#property description "v2.15: REAL FIX found from a live screenshot - the"
#property description "dashboard was telling you 'waiting for THIS candle to"
#property description "close to confirm' even when the main line's cross had"
#property description "ALREADY happened several bars earlier. Since entry"
#property description "requires the cross AND breakout on the SAME bar, a"
#property description "stale cross means that move is genuinely missed, no"
#property description "matter how the current candle closes. Dashboard now"
#property description "distinguishes a fresh cross from a stale one and says"
#property description "so honestly. Trading logic itself is unchanged."
#property description "v2.14: Dashboard now explains WHY a trade wasn't taken"
#property description "after a visible breakout - the 'waiting for' banner"
#property description "now distinguishes 'live price already clears this' from"
#property description "'the deciding bar hasn't closed yet', which was the exact"
#property description "confusion found from a real screenshot. Also expanded"
#property description "into a full RISK MANAGEMENT section - now shows the"
#property description "active exit mode and both would-be SL prices, not just"
#property description "position sizing."
#property description "v2.13: Every individual input now numbered (e.g. 3.2,"
#property description "matching its group) for easy reference, not just the"
#property description "group headers. Comment text only - every variable"
#property description "name, type, and default value verified byte-for-byte"
#property description "unchanged via automated diff before this was shipped."
#property description "v2.12: Input groups numbered 1-10 in the Inputs tab"
#property description "for easier navigation. Group LABELS only - every"
#property description "actual variable name is byte-for-byte unchanged and"
#property description "verified, so nothing else in the code was affected."
#property description "v2.11: FIX - instrument detection missed brokers using"
#property description "bare 'NAS' without '100' (e.g. NAS.r) - confirmed gap,"
#property description "added. Also expanded SPX/GER/other bare short-forms"
#property description "for broader real-world broker naming coverage."
#property description "v2.10: NEW - two selectable exit modes (InpExitMode)."
#property description "Mode 1 (default, DECELERATION): partial close +"
#property description "true breakeven (entry +/- spread) the moment"
#property description "momentum decelerates (dark->light) while in"
#property description "profit - earlier than a full zero-cross."
#property description "Mode 2 (FULL_REVERSAL): Miki's original spec,"
#property description "unchanged - histogram fully crosses zero, SL to"
#property description "exact entry, no profit requirement."
#property description "v2.00: Dashboard fully redesigned - wider panel (360px),"
#property description "cursor-based layout (eliminates any overlap risk),"
#property description "resistance/support and sizing qualifier each split"
#property description "onto their own line so long values never overflow"
#property description "the box. Also fixed a real ordering bug found during"
#property description "the rebuild (Next Lot row was rendering above Mode)."
#property description "No trading logic touched - purely visual."
#property description "v1.92: CORRECTED per direct visual confirmation - a"
#property description "diagnostic indicator was built to compare main line,"
#property description "signal line, and histogram zero-crosses side by side."
#property description "Confirmed: entries use the MAIN LINE crossing zero"
#property description "(the cyan arrows), reverting the v1.70 histogram"
#property description "change, which was an incorrect interpretation. Also"
#property description "removed the v1.91 gating patch - no longer needed,"
#property description "since entry and full-exit now share the same signal."
#property description "Re-validated: lookback 25, threshold 0.08% (was 10/"
#property description "0.05%) - 258 trades, 40.3% WR, PF 1.75, net +3534pts."
#property description "v1.91: REAL BUG FOUND & FIXED - entry uses the"
#property description "histogram crossing zero, but full-exit checked the"
#property description "raw main line's own sign - a DIFFERENT signal. 26% of"
#property description "real entries had the main line already wrong-side at"
#property description "entry; 59% of those closed within 1 bar. Full-exit"
#property description "now gated behind partial-close having fired first."
#property description "Re-tuned after the fix: lookback 10, threshold 0.05%"
#property description "(was 15/0.08%) - net +856->+3351pts on real M5 data."
#property description "v1.90: Dashboard rebuilt with a modern layout, refined"
#property description "color palette, and a dedicated 'waiting for' banner"
#property description "that dynamically explains exactly what's missing for"
#property description "the next trade. No trading logic touched - visual only."
#property description "v1.80: NEW DEFAULT - auto fixed-lot sizing by instrument"
#property description "type: 0.30 lots for NAS100/US30/GER40/SP500/other major"
#property description "indices, 0.03 lots for everything else (Gold, forex)."
#property description "Detects instrument via broad symbol-name matching."
#property description "v1.70: MAJOR FIX - entries now use the HISTOGRAM (main"
#property description "line minus signal line) crossing zero, not the raw"
#property description "main line crossing zero. This is a real, substantive"
#property description "change to the entry signal itself - the v1.60 tuning"
#property description "(15-bar lookback, 0.08% breakout) was validated"
#property description "against the OLD definition and needs re-validation"
#property description "against real data before trusting those numbers here."
#property description "v1.61: FIX - SL was placed at the exact broken level;"
#property description "corrected to the FAR side of the range instead (support"
#property description "for a buy, resistance/\"top of the range\" for a sell) -"
#property description "gives room for a retest rather than stopping right at"
#property description "the boundary most prone to a fakeout pullback."
#property description "MACD zero-line + support/resistance breakout confirmation."
#property description "Consolidation settings TUNED against real M5 NAS100 data"
#property description "(15-bar lookback, 0.08% breakout) - see v1.60 note below."
#property description "v1.60: TUNED against real M5 NAS100 data (14mo). The"
#property description "original Miki Gala defaults (10 bars, 0.3%) backtested"
#property description "at 23.2% win rate, PF 0.60 - a real losing system, not"
#property description "just a rough edge. Tested lookback 10-100 bars and"
#property description "breakout 0.05%-0.5% against real M5 price data; also"
#property description "confirmed the fresh-MACD-cross requirement is genuinely"
#property description "correct (PF 1.5+ with it vs ~1.05 without, at every"
#property description "tested setting) - the problem was never that choice,"
#property description "just its pairing with too-tight defaults. New values"
#property description "(15 bars, 0.08%): 38.9% win rate, PF 1.56, net +2959pts"
#property description "on the same real data the original setting lost on."
#property description "v1.50: NEW - partial close + move SL to breakeven when"
#property description "the histogram first turns against the trade (main"
#property description "crosses signal), ahead of the full exit signal."
#property description "v1.40: FIX - removed weak prev-bar-high/low OR trigger"
#property description "that caused trades INSIDE consolidation. Entry now"
#property description "needs a genuine range breakout + FRESH MACD cross."
#property description "NEW: real SL at the broken level; range locks until"
#property description "trade closes, then a fresh consolidation is read."
#property description "v1.30: FIX - exit checks current MACD sign every bar"
#property description "(self-healing), not just a one-shot fresh cross."
#property description "v1.20: sizing mode menu - Fixed Lot / Risk% / Kelly."
#property description "v1.10: added live on-chart status dashboard."

#include <Trade/Trade.mqh>
CTrade trade;

enum ENUM_SIZING_MODE
{
   SIZING_FIXED_LOT           = 0,   // always trade a fixed lot size (InpFixedLots, same for every instrument)
   SIZING_RISK_PERCENT        = 1,   // % of equity, sized against an ATR-based typical-move reference
   SIZING_KELLY               = 2,   // fractional Kelly, calculated from this EA's own real trade history
   SIZING_FIXED_LOT_AUTO      = 3    // fixed lot size that auto-adjusts by detected instrument type (index vs other)
};

enum ENUM_EXIT_MODE
{
   EXIT_MODE_DECELERATION   = 0,   // (default) histogram decelerates (dark->light) while in profit - earlier, no zero-cross needed
   EXIT_MODE_FULL_REVERSAL  = 1    // Miki's original spec - histogram fully crosses zero against the trade
};

enum ENUM_BREAKOUT_MODE
{
   BREAKOUT_FIXED_PERCENT  = 0,   // fixed % of the range level, same distance regardless of current volatility
   BREAKOUT_ATR_ADAPTIVE   = 1    // (default) distance = ATR x multiplier - shrinks in quiet markets, widens in volatile ones
};

input group "1. MACD Settings"
input int    InpMACDFastPeriod   = 12; // 1.1 Fast EMA period (standard: 12)
input int    InpMACDSlowPeriod   = 26; // 1.2 Slow EMA period (standard: 26)
input int    InpMACDSignalPeriod = 40; // 1.3 Signal line period (for partial-close only)
input ENUM_TIMEFRAMES InpSignalTimeframe = PERIOD_M5; // 1.4 Timeframe this bot trades on

input group "2. Support/Resistance & Breakout (matches the Miki Gala indicator defaults)"
input int    InpConsolidationLookback = 20;    // 2.1 Bars used to define the S/R range
input ENUM_BREAKOUT_MODE InpBreakoutMode = BREAKOUT_ATR_ADAPTIVE; // 2.2a Fixed % or ATR-adaptive breakout
input double InpBreakoutPercent       = 0.4;   // 2.2b % threshold (Fixed mode only)
input int    InpBreakoutATRPeriod     = 14;    // 2.2c ATR period (Adaptive mode only)
input double InpBreakoutATRMult       = 0.5;   // 2.2d Breakout distance = ATR x this
input double InpBreakoutMaxPoints     = 30.0;  // 2.2e Max breakout distance, in points
input bool   InpRequireMainLineSignal      = true; // 2.3 Require MACD direction to enter
input bool   InpRequireConsolidationBreakout = true; // 2.4 Require a breakout to enter
input bool   InpUseSmartConsolidation = false; // 2.5 ON = smarter S/R detection
input double InpConsolidationPercentile = 90.0; // 2.6 Percentile used for S/R (Smart mode)
input double InpConsolidationWidthATRMult = 1.5; // 2.7 Max range width vs ATR x sqrt(lookback) - REVISED formula, see below

// Chaos Filter: pauses new entries when the market is BOTH choppy and
// showing a genuine volatility spike at the same time. Turns off
// automatically once either condition clears.
//   - Choppiness Index: measures back-and-forth churn vs. real net
//     movement. Above the threshold = choppy, sideways, going nowhere.
//   - Volatility spike: current ATR compared to its own recent
//     history - a genuine spike relative to what's been normal lately,
//     not just "this instrument is generally volatile."
input group "2b. Chaos Filter (pause entries when choppy + volatile)"
input bool   InpUseChaosFilter = false;      // 2.8 Turn Chaos Filter ON/OFF
input int    InpChoppinessPeriod = 14;       // 2.9 Choppiness Index: bars used
input double InpChoppinessThreshold = 61.8;  // 2.10 Choppiness Index: choppy above this
input int    InpVolSpikeLookback = 100;      // 2.11 Volatility spike: ATR history length
input double InpVolSpikePercentile = 85.0;   // 2.12 Volatility spike: percentile to count as a spike

// Chaos Scalping Mode: a completely separate strategy from MACD +
// breakout, active ONLY while the Chaos Filter above (2b) has detected
// real chaos - REQUIRES InpUseChaosFilter (2.8) to also be ON, which is
// why this sits directly beside it rather than elsewhere in the list.
// When active:
//   1. Direction comes from price vs. a very short-term MA (3-5 bars) -
//      going WITH the current momentum, not betting on a reversal.
//   2. Opens the smallest possible lot size, with a real initial stop.
//   3. Every N points of favorable movement, adds ANOTHER position at
//      the same minimum size - no cap on how many can stack up.
//   4. Each position trails its OWN stop independently - REQUIRES
//      hedging mode (confirmed on this account via real evidence: 4
//      separate simultaneous tickets on the same symbol). A netting-
//      mode account would merge these into one position and break the
//      independent-trailing design entirely.
// NOTE on 2c.3/2c.4: "Other" spans Gold, forex majors, and crypto,
// which have very different natural price scales - may need
// per-instrument attention once tested, especially on forex pairs.
input group "2c. Chaos Scalping (requires 2b Chaos Filter also ON)"
input bool   InpEnableChaosScalping    = false; // 2c.1 Turn Chaos Scalping ON/OFF
input int    InpScalpDirectionMAPeriod = 4;     // 2c.2 Direction MA period (3-5 bars)
input double InpPyramidTriggerPointsIndex = 10.0; // 2c.3 Add position every X points - indices
input double InpPyramidTriggerPointsOther = 10.0; // 2c.4 Add position every X points - other
input double InpScalpTrailPointsIndex = 10.0;   // 2c.5 Trailing stop distance - indices
input double InpScalpTrailPointsOther = 10.0;   // 2c.6 Trailing stop distance - other
input double InpScalpInitialStopATRMult = 1.0;  // 2c.7 Initial stop, in x ATR

input group "3. Position Sizing (sizing is separate from entry/exit restrictions)"
input ENUM_SIZING_MODE InpSizingMode = SIZING_FIXED_LOT_AUTO; // 3.1 How lot size is calculated
input double InpFixedLots        = 0.10;    // 3.2 Lot size (Fixed Lot mode)
input double InpRiskPercent      = 1.0;     // 3.3 % equity risked (Risk % mode)
input int    InpSizingATRPeriod  = 14;      // 3.4 ATR period used for sizing
input double InpSizingATRMult    = 2.0;     // 3.5 Risk distance = ATR x this

input group "4. Auto Fixed-Lot Sizing (used when InpSizingMode = SIZING_FIXED_LOT_AUTO, the default)"
input double InpFixedLotsIndex = 0.30;   // 4.1 Lot size for major indices
input double InpFixedLotsOther = 0.03;   // 4.2 Lot size for everything else

input group "5. Kelly Sizing (used when InpSizingMode = SIZING_KELLY)"
input double InpKellyFraction         = 0.25;  // 5.1 Fraction of full Kelly used
input int    InpKellyMinTrades        = 10;    // 5.2 Min trades before Kelly is trusted
input int    InpKellyLookbackTrades   = 30;    // 5.3 Trades used for the Kelly calc
input double InpKellyFloorRiskPercent = 0.5;   // 5.4 Risk % before enough history exists
input double InpKellyMaxRiskPercent   = 5.0;   // 5.5 Max risk % Kelly can ever use

input group "6. Stop-Loss (real protective stop, at the broken consolidation level)"
input bool   InpUseConsolidationSL = true;   // 6.1 SL beyond opposite S/R, plus buffer

input group "7. Partial Close + Breakeven (two selectable modes - see header comment)"
input ENUM_EXIT_MODE InpExitMode    = EXIT_MODE_DECELERATION; // 7.1 Which exit mode is active
input bool   InpEnablePartialClose  = true; // 7.2 Turn partial close on/off
input double InpPartialClosePercent = 50.0;  // 7.3 % of position closed at partial-close
input bool   InpEnableSmaSwitchExit  = true;  // 7.4 Switch final exit to SMA once triggered
input int    InpSmaSwitchPeriod      = 20;    // 7.5 SMA period once switched
input double InpSmaSwitchThresholdIndex = 100.0; // 7.6 Profit (points) to trigger switch - index
input double InpSmaSwitchThresholdOther = 50.0;  // 7.7 Profit (points) to trigger switch - other

input group "8. Safety Backstop (NOT a trading restriction - see header comment)"
input double InpEmergencyStopUnits = 2000.0; // 8.1 Wide backup SL (0 = disabled)

input group "9. Dashboard"
input bool   InpShowDashboard   = true; // 9.1 Show/hide the dashboard panel
input int    InpDashX           = 15; // 9.2 Dashboard X position
input int    InpDashY           = 25; // 9.3 Dashboard Y position
input int    InpDashWidth       = 360; // 9.4 Dashboard panel width
input bool   InpShowCrossMarkers = true;  // 9.5 Show MACD zero-cross markers
input bool   InpShowTradeMarkers = true;  // 9.6 Show open/close trade markers
input int    InpMaxChartMarkers  = 30;    // 9.7 Max markers kept on chart

input group "10. Magic / Comment"
input int    InpMagicNumber = 570002; // 10.1 Unique ID for this bot's trades
input string InpTradeComment = "MACD+Breakout"; // 10.2 Base comment on every trade

int macdHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
int breakoutAtrHandle = INVALID_HANDLE; // separate from the sizing ATR - independent period control
int smaSwitchHandle = INVALID_HANDLE;   // 20 SMA used once the profit threshold triggers the exit-basis switch
int scalpDirectionMaHandle = INVALID_HANDLE; // very short-term MA used to detect the starting direction for a new Chaos Scalp cycle
bool chaosScalpingActive = false; // InpEnableChaosScalping AND InpUseChaosFilter both true - set once in OnInit, checked everywhere instead of the raw input, so a missing dependency degrades gracefully (warn + disable) rather than refusing to start the whole EA
double lockedResistance = 0.0;
double lockedSupport    = 0.0;
bool   rangeLocked      = false; // true while a trade is open on the range that broke it
bool   partialCloseDone = false; // true once the current trade's partial close + breakeven has fired
bool   wasInPositionLastCheck = false; // detects a position closed EXTERNALLY (SL hit, manual close) - see fix below
bool   smaSwitchActive = false; // true once THIS trade's profit crossed the threshold - stays true for the rest of the trade, even if profit later dips back below it
double smartTrustedResistance = 0.0; // last-accepted resistance under Smart Consolidation - only updates when a new candidate range is tight enough to trust
double smartTrustedSupport    = 0.0; // last-accepted support under Smart Consolidation
bool   smartHasTrustedRange   = false; // false until the first genuinely tight range is found
double smartRetiredResistance = 0.0; // per direct request: once a trade fires from a trusted range, that
double smartRetiredSupport    = 0.0; // exact range is retired - prevents repeated fake trades from the same
bool   smartHasRetiredRange   = false; // stale level during sustained sideways chop right at the boundary
bool   smartRangeIsFrozenNow  = false; // true if the most recent width-check failed and the trusted range was held over unchanged
string dashPrefix = "GMD_"; // Galaxy MACD Dashboard - object name prefix, avoids collisions
datetime lastProcessedBarTime = 0;

// Global Variable (terminal-wide, disk-persisted) keys for state that
// must survive an EA restart or terminal crash - built ONCE in OnInit
// from the symbol + magic number, so running this same EA on multiple
// instruments (Gold, NAS, BTC, etc.) simultaneously never collides:
// each instrument's state lives under its own uniquely-named set of
// keys. GlobalVariableSet() itself updates an existing variable in
// place if the name already exists - so as long as these names stay
// stable and deterministic (never regenerated with something like a
// timestamp), calling it repeatedly can never create duplicates.
string gvPrefix = "";
string gvRangeLocked, gvLockedRes, gvLockedSup, gvPartialDone, gvSmaSwitch;
string gvSmartTrustedRes, gvSmartTrustedSup, gvSmartHasTrusted, gvVersionTag;
string gvSmartRetiredRes, gvSmartRetiredSup, gvSmartHasRetired;

//+------------------------------------------------------------------+
// Builds the unique Global Variable key names for this exact
// symbol+magic combination - called once from OnInit. Using both the
// symbol AND the magic number in the prefix means two different
// instruments (or two different magic numbers on the same instrument)
// never share a key, even though every instance is running the exact
// same EA file.
void BuildStateKeys()
{
   gvPrefix = "GalaxyMACD_" + _Symbol + "_" + IntegerToString((int)InpMagicNumber) + "_";
   gvRangeLocked      = gvPrefix + "RangeLocked";
   gvLockedRes        = gvPrefix + "LockedRes";
   gvLockedSup        = gvPrefix + "LockedSup";
   gvPartialDone      = gvPrefix + "PartialDone";
   gvSmaSwitch        = gvPrefix + "SmaSwitch";
   gvSmartTrustedRes  = gvPrefix + "SmartTrustedRes";
   gvSmartTrustedSup  = gvPrefix + "SmartTrustedSup";
   gvSmartHasTrusted  = gvPrefix + "SmartHasTrusted";
   gvVersionTag       = gvPrefix + "VersionTag";
   gvSmartRetiredRes  = gvPrefix + "SmartRetiredRes";
   gvSmartRetiredSup  = gvPrefix + "SmartRetiredSup";
   gvSmartHasRetired  = gvPrefix + "SmartHasRetired";
}

//+------------------------------------------------------------------+
// Restores state from the terminal's Global Variables, if they exist
// from a previous run AND were saved by the SAME bot version. This is
// a critical safety check found directly from a real case: if the
// persisted values were computed by an OLDER version of this file -
// one that may have since had a calculation bug fixed - blindly
// trusting them could silently carry a stale, incorrect value forward
// across an upgrade, with no way to tell it apart from genuinely valid
// data. So on ANY version change (upgrade or downgrade), ALL persisted
// state is discarded and started fresh rather than partially trusted -
// erring on the side of correctness over continuity. Called once from
// OnInit, after BuildStateKeys().
void LoadPersistedState()
{
   double savedVersion = GlobalVariableCheck(gvVersionTag) ? GlobalVariableGet(gvVersionTag) : -1.0;
   double currentVersion = StringToDouble(BOT_VERSION);

   if(MathAbs(savedVersion - currentVersion) > 0.0001)
   {
      if(savedVersion > 0.0)
         Print("ImprovedMACD: persisted state was saved by a different bot version (",
               DoubleToString(savedVersion,2), " vs current ", DoubleToString(currentVersion,2),
               ") - discarding it and starting fresh rather than risk carrying forward stale data.");
      return; // leave everything at its in-memory default - genuinely fresh start
   }

   if(GlobalVariableCheck(gvRangeLocked))
      rangeLocked = (GlobalVariableGet(gvRangeLocked) > 0.5);
   if(GlobalVariableCheck(gvLockedRes))
      lockedResistance = GlobalVariableGet(gvLockedRes);
   if(GlobalVariableCheck(gvLockedSup))
      lockedSupport = GlobalVariableGet(gvLockedSup);
   if(GlobalVariableCheck(gvPartialDone))
      partialCloseDone = (GlobalVariableGet(gvPartialDone) > 0.5);
   if(GlobalVariableCheck(gvSmaSwitch))
      smaSwitchActive = (GlobalVariableGet(gvSmaSwitch) > 0.5);
   if(GlobalVariableCheck(gvSmartTrustedRes))
      smartTrustedResistance = GlobalVariableGet(gvSmartTrustedRes);
   if(GlobalVariableCheck(gvSmartTrustedSup))
      smartTrustedSupport = GlobalVariableGet(gvSmartTrustedSup);
   if(GlobalVariableCheck(gvSmartHasTrusted))
      smartHasTrustedRange = (GlobalVariableGet(gvSmartHasTrusted) > 0.5);
   if(GlobalVariableCheck(gvSmartRetiredRes))
      smartRetiredResistance = GlobalVariableGet(gvSmartRetiredRes);
   if(GlobalVariableCheck(gvSmartRetiredSup))
      smartRetiredSupport = GlobalVariableGet(gvSmartRetiredSup);
   if(GlobalVariableCheck(gvSmartHasRetired))
      smartHasRetiredRange = (GlobalVariableGet(gvSmartHasRetired) > 0.5);
}

//+------------------------------------------------------------------+
// Writes the current in-memory state out to the terminal's Global
// Variables, tagged with the current bot version. GlobalVariableSet()
// updates an existing variable in place if the name already exists
// (confirmed - this is standard MT5 behavior, not something this code
// needs to manage itself), so calling this repeatedly throughout a run
// can never create duplicate or stale entries - it simply keeps
// overwriting the same nine keys built once in BuildStateKeys(). Called
// immediately after any of these values actually changes, not on a
// timer or every tick.
void SavePersistedState()
{
   GlobalVariableSet(gvRangeLocked, rangeLocked ? 1.0 : 0.0);
   GlobalVariableSet(gvLockedRes, lockedResistance);
   GlobalVariableSet(gvLockedSup, lockedSupport);
   GlobalVariableSet(gvPartialDone, partialCloseDone ? 1.0 : 0.0);
   GlobalVariableSet(gvSmaSwitch, smaSwitchActive ? 1.0 : 0.0);
   GlobalVariableSet(gvSmartTrustedRes, smartTrustedResistance);
   GlobalVariableSet(gvSmartTrustedSup, smartTrustedSupport);
   GlobalVariableSet(gvSmartHasTrusted, smartHasTrustedRange ? 1.0 : 0.0);
   GlobalVariableSet(gvVersionTag, StringToDouble(BOT_VERSION));
   GlobalVariableSet(gvSmartRetiredRes, smartRetiredResistance);
   GlobalVariableSet(gvSmartRetiredSup, smartRetiredSupport);
   GlobalVariableSet(gvSmartHasRetired, smartHasRetiredRange ? 1.0 : 0.0);
}

//+------------------------------------------------------------------+
// Per direct request: once a trade fires from a specific Smart
// Consolidation trusted range, that exact range is retired - it can
// never trigger another entry, no matter how many more times price
// crosses it. Only a genuinely NEW range (checked in
// GetSmartConsolidationRange, see below) can be trusted again. This is
// the direct fix for sustained sideways chop right at a frozen
// boundary repeatedly firing fake trades from the same stale level.
// Call this at every point a trade actually closes, before resetting
// the other trade-state flags.
void RetireSmartRangeIfActive()
{
   if(InpUseSmartConsolidation && smartHasTrustedRange)
   {
      smartRetiredResistance = smartTrustedResistance;
      smartRetiredSupport    = smartTrustedSupport;
      smartHasRetiredRange   = true;
      smartHasTrustedRange   = false; // force a fresh, genuinely different range before trusting again
      Print("ImprovedMACD: Smart Consolidation range retired after this trade closed - "
            "requiring a genuinely different range before the next entry.");
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   BuildStateKeys();
   LoadPersistedState();

   macdHandle = iMACD(_Symbol, InpSignalTimeframe, InpMACDFastPeriod, InpMACDSlowPeriod, InpMACDSignalPeriod, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, InpSignalTimeframe, InpSizingATRPeriod);
   breakoutAtrHandle = iATR(_Symbol, InpSignalTimeframe, InpBreakoutATRPeriod);
   smaSwitchHandle = iMA(_Symbol, InpSignalTimeframe, InpSmaSwitchPeriod, 0, MODE_SMA, PRICE_CLOSE);
   scalpDirectionMaHandle = iMA(_Symbol, InpSignalTimeframe, InpScalpDirectionMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

   if(macdHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE || breakoutAtrHandle == INVALID_HANDLE ||
      smaSwitchHandle == INVALID_HANDLE || scalpDirectionMaHandle == INVALID_HANDLE)
   {
      Print("ImprovedMACD: failed to create indicator handle(s). Error: ", GetLastError());
      return INIT_FAILED;
   }

   if(InpConsolidationLookback < 2)
   {
      Print("ImprovedMACD: Consolidation lookback must be at least 2 bars.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(!InpRequireMainLineSignal && !InpRequireConsolidationBreakout)
   {
      Print("ImprovedMACD: BOTH entry confluences are disabled (InpRequireMainLineSignal "
            "and InpRequireConsolidationBreakout are both false) - there would be no entry "
            "requirement left at all, so this EA will refuse to trade. Enable at least one.");
      return INIT_PARAMETERS_INCORRECT;
   }

   // Per direct feedback: a missing dependency between two settings
   // shouldn't block the ENTIRE EA from starting - that's needlessly
   // fragile when the normal MACD strategy has nothing to do with
   // Chaos Scalping at all. Degrades gracefully instead: warn clearly,
   // and simply treat Scalping as disabled for this session (chaosScalpingActive
   // stays false), while everything else - including the Chaos Filter
   // itself, if that's on - runs completely normally.
   chaosScalpingActive = InpEnableChaosScalping && InpUseChaosFilter;
   if(InpEnableChaosScalping && !InpUseChaosFilter)
   {
      Print("ImprovedMACD: WARNING - InpEnableChaosScalping=", InpEnableChaosScalping,
            " but InpUseChaosFilter=", InpUseChaosFilter, ". Chaos Scalping requires the Chaos "
            "Filter to also be on, so it will stay DISABLED for this session (the rest of the "
            "bot runs normally). Turn InpUseChaosFilter ON too if you want Scalping active.");
   }

   trade.SetExpertMagicNumber(InpMagicNumber);

   // Reconcile loaded state against reality: if the persisted state
   // says a trade was locked/active, but no such position actually
   // exists right now, that trade must have closed while this EA was
   // not running (removed, terminal restarted, etc.) - the persisted
   // state is stale and must be corrected immediately, not carried
   // forward, or the bot would stay permanently stuck thinking a
   // position is open when it isn't.
   ulong syncTicket = 0;
   ENUM_POSITION_TYPE syncType;
   bool syncHasPosition = FindOurPosition(syncTicket, syncType);
   if(!syncHasPosition && (rangeLocked || partialCloseDone || smaSwitchActive))
   {
      Print("ImprovedMACD: persisted state referenced an open trade that no longer exists "
            "(closed while this EA wasn't running) - resetting to flat state.");
      rangeLocked = false;
      partialCloseDone = false;
      smaSwitchActive = false;
      RetireSmartRangeIfActive();
      SavePersistedState();
   }
   wasInPositionLastCheck = syncHasPosition;

   CreateDashboard();

   Print("ImprovedMACD initialized on ", _Symbol, " ", EnumToString(InpSignalTimeframe),
         " - breakout(", InpConsolidationLookback, " bars, ", InpBreakoutPercent,
         "%) + MACD zero-line confirmation.");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(macdHandle != INVALID_HANDLE)
      IndicatorRelease(macdHandle);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   if(breakoutAtrHandle != INVALID_HANDLE)
      IndicatorRelease(breakoutAtrHandle);
   if(smaSwitchHandle != INVALID_HANDLE)
      IndicatorRelease(smaSwitchHandle);
   if(scalpDirectionMaHandle != INVALID_HANDLE)
      IndicatorRelease(scalpDirectionMaHandle);

   RemoveDashboard();
}

//+------------------------------------------------------------------+
bool GetMACDMain(int shift, double &value)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(macdHandle, 0, shift, 1, buf) != 1)
      return false;
   value = buf[0];
   return true;
}

//+------------------------------------------------------------------+
bool GetMACDSignal(int shift, double &value)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(macdHandle, 1, shift, 1, buf) != 1)
      return false;
   value = buf[0];
   return true;
}

//+------------------------------------------------------------------+
// Current ATR for the breakout threshold - a genuine, well-established
// way to make the threshold scale with actual current volatility
// (which naturally also reflects the current trading session, since
// quiet sessions produce lower ATR and active sessions produce higher
// ATR, without needing separate explicit session-time logic). Shrinks
// the required breakout distance in quiet markets, widens it in
// volatile ones - directly addressing the concern that a fixed
// percentage is too easy to trigger via noise/manipulation when
// volatility spikes, and unnecessarily strict when the market is quiet.
bool GetBreakoutATR(double &value)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(breakoutAtrHandle, 0, 1, 1, buf) != 1)
      return false;
   value = buf[0];
   return true;
}

//+------------------------------------------------------------------+
// Choppiness Index: measures whether recent price action has been
// genuinely trending or just churning sideways with large, erratic
// swings - the "candles moving all over the place" scenario. Formula:
// 100 x log10(sum of true range over N bars / (highest high - lowest
// low over the same N bars)) / log10(N). A HIGH reading (commonly,
// above ~61.8) means lots of back-and-forth movement without going
// anywhere; a LOW reading means a clean, directional move. This is
// genuinely different from ATR - a strong trend can have high ATR but
// LOW choppiness, while a violent, directionless whipsaw has high ATR
// AND high choppiness, which is specifically what this is trying to
// isolate.
bool GetChoppinessIndex(double &choppinessOut)
{
   int period = InpChoppinessPeriod;
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(closes, true);

   if(CopyHigh(_Symbol, InpSignalTimeframe, 1, period, highs) != period)
      return false;
   if(CopyLow(_Symbol, InpSignalTimeframe, 1, period, lows) != period)
      return false;
   if(CopyClose(_Symbol, InpSignalTimeframe, 1, period + 1, closes) != period + 1)
      return false;

   double sumTR = 0.0;
   for(int i = 0; i < period; i++)
   {
      double prevClose = closes[i + 1]; // the bar just before highs[i]/lows[i]'s own bar
      double tr = highs[i] - lows[i];
      tr = MathMax(tr, MathAbs(highs[i] - prevClose));
      tr = MathMax(tr, MathAbs(lows[i] - prevClose));
      sumTR += tr;
   }

   int highestIdx = ArrayMaximum(highs, 0, period);
   int lowestIdx = ArrayMinimum(lows, 0, period);
   double range = highs[highestIdx] - lows[lowestIdx];

   if(range <= 0.0)
      return false;

   choppinessOut = 100.0 * MathLog10(sumTR / range) / MathLog10((double)period);
   return true;
}

//+------------------------------------------------------------------+
// Detects a genuine volatility SPIKE - not just "this instrument is
// generally volatile," but "current ATR is meaningfully higher than
// its own recent normal range." Compares the current ATR value
// against the distribution of its own last InpVolSpikeLookback values
// - if it's at or above InpVolSpikePercentile of that history, it
// counts as a spike. Reuses the SAME breakoutAtrHandle already created
// for the breakout threshold - no separate indicator handle needed.
bool IsVolatilitySpike()
{
   double currentAtr = 0.0;
   if(!GetBreakoutATR(currentAtr))
      return false;

   int lookback = InpVolSpikeLookback;
   double atrHistory[];
   ArraySetAsSeries(atrHistory, true);
   if(CopyBuffer(breakoutAtrHandle, 0, 1, lookback, atrHistory) != lookback)
      return false;

   int belowCount = 0;
   for(int i = 0; i < lookback; i++)
   {
      if(atrHistory[i] < currentAtr)
         belowCount++;
   }

   double percentile = 100.0 * belowCount / (double)lookback;
   return percentile >= InpVolSpikePercentile;
}

//+------------------------------------------------------------------+
// Combines both measures: entries only pause when conditions are
// choppy AND a genuine volatility spike is happening AT THE SAME TIME
// - not either alone. A strong, clean trend can have high ATR without
// being choppy; a quiet market can be choppy without a volatility
// spike. It's specifically the combination that matches "insane
// volatility with candles moving all over the place."
bool IsChaosDetected(string &reasonOut)
{
   double chop = 0.0;
   bool haveChop = GetChoppinessIndex(chop);
   bool choppy = haveChop && (chop >= InpChoppinessThreshold);
   bool volSpike = IsVolatilitySpike();

   if(choppy && volSpike)
   {
      reasonOut = "Chaos filter active: choppy (" + DoubleToString(chop, 1) +
                  ") + volatility spike - new entries paused until conditions calm down.";
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool GetSmaSwitchValue(int shift, double &value)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(smaSwitchHandle, 0, shift, 1, buf) != 1)
      return false;
   value = buf[0];
   return true;
}

//+------------------------------------------------------------------+
// The correct profit threshold for the current instrument, per direct
// request - reuses the same Index/Other auto-detection already driving
// lot sizing (4.1/4.2), applied here for a completely different
// purpose: which threshold triggers the SMA-switch exit.
double GetSmaSwitchThreshold()
{
   return IsIndexInstrument() ? InpSmaSwitchThresholdIndex : InpSmaSwitchThresholdOther;
}

//+------------------------------------------------------------------+
// The correct pyramid-add and trailing distances for the current
// instrument - same Index/Other auto-detection pattern used
// throughout this bot. NOTE: the "Other" bucket spans Gold, forex
// majors, and crypto, which have genuinely different natural price
// scales - this may need per-instrument attention once tested on
// forex specifically (e.g. USDJPY vs Gold), flagged directly rather
// than silently assumed to be correct.
double GetPyramidTriggerPoints()
{
   return IsIndexInstrument() ? InpPyramidTriggerPointsIndex : InpPyramidTriggerPointsOther;
}

double GetScalpTrailPoints()
{
   return IsIndexInstrument() ? InpScalpTrailPointsIndex : InpScalpTrailPointsOther;
}

//+------------------------------------------------------------------+
// Discovers all currently-open Chaos Scalp positions by their trade
// comment tag ("SCALP") - deliberately NOT tracked via persistent EA
// state, since hedging mode means multiple independent positions can
// exist simultaneously, and the broker's own records (comment, open
// time, open price) already contain everything needed to manage them,
// with no risk of the EA's own memory drifting out of sync with
// reality. Returns the count found; direction/most-recent-entry info
// come back via the reference parameters (direction is shared by all
// pieces in one pyramid cycle, so the first one found sets it).
int CountScalpPositions(int &directionOut, datetime &mostRecentTimeOut, double &mostRecentPriceOut)
{
   int count = 0;
   directionOut = 0;
   mostRecentTimeOut = 0;
   mostRecentPriceOut = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), "SCALP") < 0) continue;

      count++;
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(directionOut == 0)
         directionOut = (posType == POSITION_TYPE_BUY) ? 1 : -1;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(openTime > mostRecentTimeOut)
      {
         mostRecentTimeOut = openTime;
         mostRecentPriceOut = PositionGetDouble(POSITION_PRICE_OPEN);
      }
   }
   return count;
}

//+------------------------------------------------------------------+
// Updates the trailing stop on EVERY open Chaos Scalp position
// independently - each piece trails on its own, per direct request,
// not a single shared stop for the combined exposure. Only ever
// tightens an existing stop, never loosens it.
void TrailAllScalpPositions()
{
   double trailDist = GetScalpTrailPoints();
   if(trailDist <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), "SCALP") < 0) continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentSL = PositionGetDouble(POSITION_SL);
      double curPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double newSL = (posType == POSITION_TYPE_BUY) ? (curPrice - trailDist) : (curPrice + trailDist);

      bool shouldUpdate = (posType == POSITION_TYPE_BUY)
         ? (currentSL <= 0.0 || newSL > currentSL)
         : (currentSL <= 0.0 || newSL < currentSL);

      if(shouldUpdate)
      {
         double normalizedSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
         double currentTP = PositionGetDouble(POSITION_TP);
         trade.PositionModify(t, normalizedSL, currentTP);
      }
   }
}

//+------------------------------------------------------------------+
// Very short-term direction check (3-5 bars) for STARTING a new Chaos
// Scalp cycle, per direct request - going WITH whatever the market is
// currently doing, not betting on a reversal. Price above the MA means
// upward momentum (buy); below means downward momentum (sell).
bool EvaluateScalpDirection(int &directionOut)
{
   double maBuf[];
   ArraySetAsSeries(maBuf, true);
   if(CopyBuffer(scalpDirectionMaHandle, 0, 1, 1, maBuf) != 1)
      return false;
   double maValue = maBuf[0];

   double closePrice = iClose(_Symbol, InpSignalTimeframe, 1);

   if(closePrice > maValue)
   {
      directionOut = 1;
      return true;
   }
   else if(closePrice < maValue)
   {
      directionOut = -1;
      return true;
   }
   return false; // exactly equal - no clear direction yet
}

//+------------------------------------------------------------------+
// Opens one Chaos Scalp position - always the broker's minimum lot
// size, per direct request ("open the lowest lot size"), with a real
// broker-side initial stop (ATR-based) as a safety net until the
// trailing logic above has price movement to work with. Completely
// separate from the normal strategy's OpenPosition - no consolidation
// range concept applies here at all.
void OpenScalpPosition(bool buySide)
{
   double price = buySide ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double atrValue = 0.0;
   GetBreakoutATR(atrValue);
   double initialStopDist = atrValue * InpScalpInitialStopATRMult;
   double stopPrice = 0.0;
   if(initialStopDist > 0.0)
      stopPrice = buySide ? (price - initialStopDist) : (price + initialStopDist);

   string tradeComment = BuildTradeComment(true);
   double normalizedSL = (stopPrice > 0.0) ? NormalizeDouble(stopPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) : 0.0;

   bool sent = buySide
      ? trade.Buy(minLot, _Symbol, 0.0, normalizedSL, 0.0, tradeComment)
      : trade.Sell(minLot, _Symbol, 0.0, normalizedSL, 0.0, tradeComment);

   if(!sent)
      Print("ImprovedMACD: Chaos Scalp order failed. Retcode: ", trade.ResultRetcodeDescription());
   else
      DrawTradeOpenMarker(TimeCurrent(), buySide, price);
}

//+------------------------------------------------------------------+
// Percentile-based range - resistant to a single manipulation wick
// dominating the whole calculation, unlike strict highest-high/lowest-
// low. E.g. with InpConsolidationPercentile=90: resistance = the level
// only the top 10% of highs exceed, support = the mirrored bottom 10%
// for lows. A single outlier bar needs company (several bars genuinely
// trading near that extreme) before it can meaningfully move the level.
bool GetPercentileRange(double percentileUpper, double &highOut, double &lowOut)
{
   int count = InpConsolidationLookback;
   double highs[], lows[];

   // CRITICAL FIX: ArraySort() always sorts the underlying memory in
   // plain ascending order and does NOT respect ArraySetAsSeries - so
   // setting the series flag before sorting silently reverses the
   // indexing relative to what the rest of this function assumes,
   // making the percentile picks backwards (confirmed directly: this
   // was the cause of resistance/support showing inverted on a live
   // chart). These arrays are sorted then indexed directly - series
   // ordering serves no purpose here - so it must be explicitly off.
   ArraySetAsSeries(highs, false);
   ArraySetAsSeries(lows, false);

   if(CopyHigh(_Symbol, InpSignalTimeframe, 2, count, highs) != count)
      return false;
   if(CopyLow(_Symbol, InpSignalTimeframe, 2, count, lows) != count)
      return false;

   ArraySort(highs); // ascending - index 0 = smallest, index count-1 = largest
   ArraySort(lows);

   double percentileLower = 100.0 - percentileUpper;

   int idxHigh = (int)MathRound((percentileUpper / 100.0) * (count - 1));
   int idxLow  = (int)MathRound((percentileLower / 100.0) * (count - 1));

   idxHigh = (int)MathMax(0, MathMin(count - 1, idxHigh));
   idxLow  = (int)MathMax(0, MathMin(count - 1, idxLow));

   highOut = highs[idxHigh];
   lowOut  = lows[idxLow];
   return true;
}

//+------------------------------------------------------------------+
// Orchestrates Smart Consolidation: computes the percentile-based
// range, checks whether its width is tight enough (relative to ATR x
// the current session's multiplier) to trust, and only updates the
// "trusted" range when it is - otherwise keeps the last trusted range
// completely frozen. This is the direct fix for the "zombie grind"
// problem: a slow, steady one-directional move keeps producing a wider
// and wider window every bar, so it keeps failing the tightness check
// and the range simply stays put at wherever it last was genuinely
// tight - instead of endlessly chasing price and never actually
// registering a breakout.
bool GetSmartConsolidationRange(double &highOut, double &lowOut)
{
   double percHigh = 0.0, percLow = 0.0;
   if(!GetPercentileRange(InpConsolidationPercentile, percHigh, percLow))
      return false;

   double atrNow = 0.0;
   if(!GetBreakoutATR(atrNow))
      return false;

   // REVISED per direct feedback: the previous formula compared a
   // MULTI-BAR range width against a flat multiple of SINGLE-BAR ATR
   // (2-4x) - an incompatible scale. Price naturally spreads out over a
   // lookback window roughly proportional to the square root of the
   // number of bars, even in a genuinely quiet, tight market - so even
   // a real consolidation would often fail the old check, which is
   // exactly the "can't detect an obvious range" problem this was
   // built to fix. This scales the tolerance with sqrt(lookback), a
   // statistically grounded relationship rather than an arbitrary flat
   // multiplier. InpConsolidationWidthATRMult is now a cushion ON TOP
   // of that statistical baseline (1.0 = the pure baseline itself).
   // Session-awareness has been removed for now - it was adding a
   // second unvalidated layer on top of a formula that wasn't correct
   // at its base; it can be reintroduced once this core mechanism is
   // itself proven against real data.
   double maxWidth = atrNow * InpConsolidationWidthATRMult * MathSqrt((double)InpConsolidationLookback);
   double currentWidth = percHigh - percLow;

   if(currentWidth <= maxWidth)
   {
      // Reject a candidate that's too similar to the retired range -
      // per direct request, once a trade fires from a specific range,
      // that exact range must not immediately re-trigger another entry
      // from continued chop at the same level. "Too similar" scales
      // with current ATR, consistent with every other distance already
      // used in this bot, rather than a fixed price distance.
      bool tooSimilarToRetired = smartHasRetiredRange &&
         (MathAbs(percHigh - smartRetiredResistance) < atrNow * 0.5) &&
         (MathAbs(percLow  - smartRetiredSupport)    < atrNow * 0.5);

      if(tooSimilarToRetired)
      {
         smartRangeIsFrozenNow = true; // still not trustworthy - waiting for a genuinely different range
      }
      else
      {
         bool actuallyChanged = (!smartHasTrustedRange) ||
                                (MathAbs(percHigh - smartTrustedResistance) > 0.0000001) ||
                                (MathAbs(percLow - smartTrustedSupport) > 0.0000001);

         smartTrustedResistance = percHigh;
         smartTrustedSupport    = percLow;
         smartHasTrustedRange   = true;
         smartRangeIsFrozenNow  = false;

         // A genuinely different range has now been accepted - the
         // retirement has done its job of blocking the stale level, so
         // clear it. If another trade fires from THIS new range later,
         // it will be retired again at that point.
         smartHasRetiredRange = false;

         // Only persist when the value genuinely changed - this function
         // runs every tick while flat, but the underlying closed-bar data
         // (and therefore the result) only actually changes once per new
         // bar, so this avoids calling GlobalVariableSet repeatedly for no
         // reason within the same bar.
         if(actuallyChanged)
            SavePersistedState();
      }
   }
   else
   {
      // Too wide right now - keep whatever the trusted range currently
      // is (if any), completely unchanged this bar. Flagged so the
      // dashboard can show this state directly.
      smartRangeIsFrozenNow = true;
   }

   if(!smartHasTrustedRange)
      return false; // nothing trustworthy yet - same as "not enough history"

   highOut = smartTrustedResistance;
   lowOut  = smartTrustedSupport;
   return true;
}

//+------------------------------------------------------------------+
// Highest high / lowest low over InpConsolidationLookback CLOSED bars,
// measured from shift=2 back (i.e. excluding the just-closed signal bar
// itself at shift=1) - matches the Pine Script's ta.highest/ta.lowest
// evaluated on history, without the signal bar trivially "breaking out"
// of a range that includes its own extreme.
bool GetConsolidationRange(double &highOut, double &lowOut)
{
   int startShift = 2;
   int count = InpConsolidationLookback;

   double highs[];
   double lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   if(CopyHigh(_Symbol, InpSignalTimeframe, startShift, count, highs) != count)
      return false;
   if(CopyLow(_Symbol, InpSignalTimeframe, startShift, count, lows) != count)
      return false;

   highOut = highs[ArrayMaximum(highs)];
   lowOut  = lows[ArrayMinimum(lows)];
   return true;
}

//+------------------------------------------------------------------+
bool FindOurPosition(ulong &ticket, ENUM_POSITION_TYPE &type)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      // Chaos Scalp positions are managed entirely separately (see
      // CountScalpPositions/TrailAllScalpPositions) - excluded here so
      // the normal strategy's exit/partial-close logic can never
      // accidentally pick one up and try to manage it incorrectly.
      // Hedging mode allows both systems to have positions open on the
      // same symbol at once, so this exclusion is essential, not
      // theoretical.
      if(StringFind(PositionGetString(POSITION_COMMENT), "SCALP") >= 0) continue;

      ticket = t;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// Computes a fractional-Kelly risk % from this EA's OWN real closed
// trade history - filtered strictly by this EA's magic number AND the
// current symbol, so it never mixes in trades from a different
// instance, instrument, or manual trades. Falls back to the floor risk
// % until enough trade history exists to make the calculation
// meaningful.
// Fetches the most recent CLOSING deal (DEAL_ENTRY_OUT) for this EA's
// own magic number and symbol - used for the close marker, since by
// the time an external close (SL hit, manual close) is detected, the
// position no longer exists to query directly. Returns false if no
// matching deal is found in the recent history window.
bool GetLastClosedDealInfo(double &closePriceOut, double &profitOut)
{
   if(!HistorySelect(TimeCurrent() - 86400, TimeCurrent())) // last 24h is plenty for "just closed"
      return false;

   int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      if((int)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      closePriceOut = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      profitOut = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                  HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                  HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
double CalculateKellyRiskPercent()
{
   if(!HistorySelect(0, TimeCurrent()))
      return InpKellyFloorRiskPercent;

   int total = HistoryDealsTotal();
   double pnls[];
   ArrayResize(pnls, 0);

   for(int i = total - 1; i >= 0 && ArraySize(pnls) < InpKellyLookbackTrades; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      if((int)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                       HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                       HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

      int sz = ArraySize(pnls);
      ArrayResize(pnls, sz+1);
      pnls[sz] = profit;
   }

   int n = ArraySize(pnls);
   if(n < InpKellyMinTrades)
      return InpKellyFloorRiskPercent;

   int wins = 0, lossCount = 0;
   double sumWin = 0.0, sumLoss = 0.0;

   for(int i=0; i<n; i++)
   {
      if(pnls[i] > 0.0)      { wins++;      sumWin  += pnls[i]; }
      else if(pnls[i] < 0.0) { lossCount++; sumLoss += MathAbs(pnls[i]); }
   }

   if(wins == 0 || lossCount == 0)
      return InpKellyFloorRiskPercent;

   double winRate = (double)wins / n;
   double avgWin  = sumWin / wins;
   double avgLoss = sumLoss / lossCount;

   if(avgLoss <= 0.0)
      return InpKellyFloorRiskPercent;

   double payoffRatio = avgWin / avgLoss;
   double fullKelly = winRate - (1.0 - winRate) / payoffRatio;
   double fractionalKellyPct = MathMax(0.0, fullKelly) * InpKellyFraction * 100.0;

   double floorRisk = MathMax(0.0, InpKellyFloorRiskPercent);
   double capRisk   = MathMax(floorRisk, InpKellyMaxRiskPercent);

   return MathMax(floorRisk, MathMin(capRisk, fractionalKellyPct));
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Case-insensitive substring check against the current symbol name.
bool SymbolContains(string needle)
{
   string sym = _Symbol;
   StringToUpper(sym);
   StringToUpper(needle);
   return StringFind(sym, needle) >= 0;
}

//+------------------------------------------------------------------+
// Broad detection of major stock indices at a similar point-scale to
// NAS100 (thousands-to-tens-of-thousands price level, moving in whole
// points) - covers the most common broker naming conventions for each.
// Anything NOT matching one of these (Gold, forex, etc.) falls through
// to the "other" fixed-lot size, since those trade at a very different
// point/pip scale.
bool IsIndexInstrument()
{
   // US tech / Nasdaq 100 - includes bare "NAS" for brokers that append
   // only an account-type suffix without the "100" (e.g. "NAS.r",
   // "NASm", "NASc") - confirmed gap: "NAS.r" contained none of the
   // longer tokens below and would have silently fallen through to
   // "Other" sizing before this fix.
   if(SymbolContains("NAS100") || SymbolContains("US100") || SymbolContains("USTEC") ||
      SymbolContains("USTECH") || SymbolContains("NASDAQ") || SymbolContains("NQ100") ||
      SymbolContains("NDX") || SymbolContains("NAS"))
      return true;

   // US Dow Jones 30
   if(SymbolContains("US30") || SymbolContains("DJ30") || SymbolContains("WS30") ||
      SymbolContains("DOW") || SymbolContains("DJI") || SymbolContains("YM"))
      return true;

   // US S&P 500
   if(SymbolContains("SP500") || SymbolContains("US500") || SymbolContains("SPX500") ||
      SymbolContains("S&P500") || SymbolContains("S&P") || SymbolContains("SPXUSD") ||
      SymbolContains("US.500") || SymbolContains("SPX"))
      return true;

   // German DAX (both old 30 and current 40 naming), plus bare "GER"
   if(SymbolContains("GER30") || SymbolContains("GER40") || SymbolContains("DE30") ||
      SymbolContains("DE40") || SymbolContains("DAX30") || SymbolContains("DAX40") ||
      SymbolContains("DAX") || SymbolContains("GERMANY40") || SymbolContains("GER"))
      return true;

   // UK FTSE 100
   if(SymbolContains("UK100") || SymbolContains("FTSE100") || SymbolContains("FTSE"))
      return true;

   // French CAC 40
   if(SymbolContains("FRA40") || SymbolContains("CAC40") || SymbolContains("CAC") ||
      SymbolContains("FRANCE40"))
      return true;

   // Eurozone STOXX 50
   if(SymbolContains("EU50") || SymbolContains("STOXX50") || SymbolContains("ESTX50") ||
      SymbolContains("EUSTX50"))
      return true;

   // Japan Nikkei 225
   if(SymbolContains("JP225") || SymbolContains("NI225") || SymbolContains("NIKKEI") ||
      SymbolContains("JPN225") || SymbolContains("JAPAN225"))
      return true;

   // Australia ASX 200
   if(SymbolContains("AUS200") || SymbolContains("ASX200") || SymbolContains("ASX") ||
      SymbolContains("AUSTRALIA200"))
      return true;

   // Hong Kong Hang Seng
   if(SymbolContains("HK50") || SymbolContains("HSI") || SymbolContains("HANGSENG") ||
      SymbolContains("HONGKONG50"))
      return true;

   return false; // Gold, forex, and anything else at a different point-scale
}

//+------------------------------------------------------------------+
double CalculateLots(bool buySide, double entryPrice)
{
   double lots;

   if(InpSizingMode == SIZING_FIXED_LOT_AUTO)
      lots = IsIndexInstrument() ? InpFixedLotsIndex : InpFixedLotsOther;
   else
      lots = InpFixedLots;

   if(InpSizingMode != SIZING_FIXED_LOT && InpSizingMode != SIZING_FIXED_LOT_AUTO)
   {
      double riskPercent = (InpSizingMode == SIZING_KELLY)
         ? CalculateKellyRiskPercent()
         : InpRiskPercent;

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskCash = equity * riskPercent / 100.0;

      // Size against a REALISTIC typical-move reference (a multiple of
      // current ATR), not the emergency backstop - the backstop is
      // intentionally far too wide to represent a meaningful "typical risk"
      // distance, and using it there produced a sizing calculation that
      // didn't actually track the configured risk % in practice.
      double atrNow = 0.0;
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);

      if(CopyBuffer(atrHandle, 0, 1, 1, atrBuf) == 1)
         atrNow = atrBuf[0];

      if(atrNow > 0.0)
      {
         double sizingDistance = InpSizingATRMult * atrNow;
         double referenceStop = buySide ? entryPrice - sizingDistance : entryPrice + sizingDistance;

         double testVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double profitPerMinLot = 0.0;

         ENUM_ORDER_TYPE orderType = buySide ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

         if(OrderCalcProfit(orderType, _Symbol, testVolume, entryPrice, referenceStop, profitPerMinLot))
         {
            double riskPerMinLot = MathAbs(profitPerMinLot);
            if(riskPerMinLot > 0.0)
               lots = testVolume * (riskCash / riskPerMinLot);
         }
      }
   }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   return lots;
}

//+------------------------------------------------------------------+
// Builds the trade comment sent with every order: the user's base
// comment (InpTradeComment), the bot version, and a short code showing
// which entry confluences were active for this trade. The version
// comes from the BOT_VERSION macro defined at the top of the file -
// there is no separate hardcoded version string here, so bumping
// BOT_VERSION once automatically keeps the comment in sync with the
// actual file version, exactly as requested. Truncates the base
// comment if needed to stay within a safe, conservative 31-character
// limit (many brokers cap order comments around there).
string BuildTradeComment(bool isScalp = false)
{
   // isScalp defaults to false, so every existing call site (the normal
   // strategy) behaves exactly as before. Chaos Scalping passes true
   // explicitly, since the M/B confluence codes wouldn't mean anything
   // for a trade that doesn't use MACD/breakout logic at all.
   string confluenceCode = isScalp ? "SCALP" : "";
   if(!isScalp)
   {
      if(InpRequireMainLineSignal)
         confluenceCode += "M";
      if(InpRequireConsolidationBreakout)
         confluenceCode += "B";
   }

   string suffix = " v" + BOT_VERSION + " " + confluenceCode;
   int maxTotalLen = 31;
   int maxBaseLen = maxTotalLen - StringLen(suffix);

   string base = InpTradeComment;
   if(maxBaseLen < 0)
      maxBaseLen = 0;
   if(StringLen(base) > maxBaseLen)
      base = StringSubstr(base, 0, maxBaseLen);

   return base + suffix;
}

//+------------------------------------------------------------------+
void OpenPosition(bool buySide, double consolidationLevel = 0.0)
{
   double price = buySide ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double stopPrice = 0.0;

   // Real protective stop: the FAR side of the consolidation range that
   // was broken - support for a buy breakout, resistance for a sell
   // breakout ("on top of the range" for a sell, per direct correction).
   // This gives the trade room to breathe through a brief retest of the
   // broken level, rather than stopping out right at the exact boundary
   // most prone to a fakeout pullback.
   if(InpUseConsolidationSL && consolidationLevel > 0.0)
      stopPrice = consolidationLevel;

   // Emergency backstop still applies as an additional, wider safety net
   // - only relevant if it happens to be TIGHTER than the consolidation
   // stop (e.g. if InpUseConsolidationSL is off, or the level is
   // unusually close to entry).
   if(InpEmergencyStopUnits > 0.0)
   {
      double emergencyStop = buySide ? price - InpEmergencyStopUnits : price + InpEmergencyStopUnits;
      if(stopPrice <= 0.0)
         stopPrice = emergencyStop;
      else
         stopPrice = buySide ? MathMax(stopPrice, emergencyStop) : MathMin(stopPrice, emergencyStop);
   }

   double lots = CalculateLots(buySide, price);

   if(lots <= 0.0)
   {
      Print("ImprovedMACD: calculated lot size is zero, skipping entry.");
      return;
   }

   string tradeComment = BuildTradeComment();

   bool sent = buySide
      ? trade.Buy(lots, _Symbol, 0.0, stopPrice, 0.0, tradeComment)
      : trade.Sell(lots, _Symbol, 0.0, stopPrice, 0.0, tradeComment);

   if(!sent)
      Print("ImprovedMACD: order failed. Retcode: ", trade.ResultRetcodeDescription());
   else
      DrawTradeOpenMarker(TimeCurrent(), buySide, price);
}

//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
   if(!trade.PositionClose(ticket))
      Print("ImprovedMACD: close failed. Retcode: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
// Partial close + breakeven - TWO selectable modes (InpExitMode):
//
// MODE 1 - EXIT_MODE_DECELERATION (default): fires the moment the
// histogram DECELERATES on the SAME side as the trade - i.e. momentum
// stops building and starts fading (a "dark to light" color change,
// matching the diagnostic indicator's 4-color scheme), WITHOUT waiting
// for a full zero-line cross. This is an earlier signal than Mode 2.
// Only fires while the position is currently in profit. SL moves to
// TRUE economic breakeven (entry + spread for a buy, entry - spread
// for a sell) - moving to the exact entry price alone would still
// guarantee a loss equal to the spread if the stop is ever hit, since
// a buy closes at bid (below the ask it entered at).
//
// MODE 2 - EXIT_MODE_FULL_REVERSAL: Miki's original spec - fires when
// the histogram fully crosses zero against the trade (main crosses
// signal), no profit requirement. SL moves to the exact entry price,
// per that original wording.
//
// Both modes share the same lot-size validation: the closed portion is
// rounded to a valid lot step, and both the closed portion and the
// remainder must be at or above the broker's minimum lot, or the
// partial close is skipped (moving to breakeven still happens
// regardless - protecting the trade matters more than the partial).
//
// Checked continuously (every completed bar, as long as it hasn't
// already fired for this trade) rather than only at the exact
// triggering moment - self-healing, matching the main exit fix.
void TryPartialCloseAndBreakeven(ulong ticket, ENUM_POSITION_TYPE type,
                                  double mainNow, double mainPrev, double mainPrevPrev,
                                  double signalNow, double signalPrev, double signalPrevPrev)
{
   if(!InpEnablePartialClose || partialCloseDone)
      return;

   bool triggered = false;
   double slPrice = 0.0;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentTP = PositionGetDouble(POSITION_TP);
   double floatingPL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

   if(InpExitMode == EXIT_MODE_DECELERATION)
   {
      double histNow      = mainNow      - signalNow;
      double histPrev      = mainPrev     - signalPrev;
      double histPrevPrev  = mainPrevPrev - signalPrevPrev;

      bool risingNow  = histNow  > histPrev;
      bool risingPrev = histPrev > histPrevPrev;

      // "Dark to light" - was building (rising), now fading (falling),
      // while STILL on the same side of zero as the trade direction.
      bool decelBuy  = (type == POSITION_TYPE_BUY)  && histNow >= 0.0 && risingPrev && !risingNow;
      bool decelSell = (type == POSITION_TYPE_SELL) && histNow <= 0.0 && !risingPrev && risingNow;

      if((decelBuy || decelSell) && floatingPL > 0.0)
      {
         triggered = true;
         double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
         slPrice = (type == POSITION_TYPE_BUY) ? entry + spread : entry - spread;
      }
   }
   else // EXIT_MODE_FULL_REVERSAL
   {
      bool histogramAgainstBuy  = (type == POSITION_TYPE_BUY)  && (mainNow < signalNow);
      bool histogramAgainstSell = (type == POSITION_TYPE_SELL) && (mainNow > signalNow);

      if(histogramAgainstBuy || histogramAgainstSell)
      {
         triggered = true;
         slPrice = entry; // exact entry price, per Miki's original wording
      }
   }

   if(!triggered)
      return;

   double totalVolume = PositionGetDouble(POSITION_VOLUME);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // When the target percentage doesn't divide evenly into whole lot
   // steps (e.g. 50% of 0.03 lots at a 0.01 step = 1.5 steps), this
   // ALWAYS rounds the CLOSED portion down and the REMAINDER up - per
   // direct request, favoring letting MORE of the position keep
   // running, not less, whenever an exact split isn't possible. The
   // small epsilon ADDED before flooring guards against the opposite
   // failure: when the split SHOULD be exact (e.g. 50% of 0.04 lots =
   // exactly 2 steps), floating-point representation error can leave
   // the raw value as 1.9999999999 instead of a clean 2.0 - flooring
   // that directly would incorrectly close one step too FEW. The
   // epsilon nudges it back to the intended whole number without
   // affecting genuine fractional cases like the 1.5 boundary above,
   // which floors to 1 correctly either way.
   double rawSteps = (totalVolume * InpPartialClosePercent / 100.0) / lotStep;
   double closeVolume = MathFloor(rawSteps + 0.0000001) * lotStep;
   double remainder = totalVolume - closeVolume;

   bool partialValid = closeVolume >= minLot && remainder >= minLot;

   if(partialValid)
   {
      if(!trade.PositionClosePartial(ticket, closeVolume))
         Print("ImprovedMACD: partial close failed. Retcode: ", trade.ResultRetcodeDescription());
   }
   else
   {
      Print("ImprovedMACD: position too small for a valid partial close (broker min lot constraint) - "
            "moving to breakeven only, skipping the partial close itself.");
   }

   double slFinal = NormalizeDouble(slPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   if(trade.PositionModify(ticket, slFinal, currentTP))
   {
      partialCloseDone = true;
      SavePersistedState();
      Print("ImprovedMACD: partial close + SL move applied. Mode=", EnumToString(InpExitMode),
            " SL=", slFinal, " Closed=", (partialValid ? closeVolume : 0.0));
   }
   else
   {
      Print("ImprovedMACD: SL move failed. Retcode: ", trade.ResultRetcodeDescription(),
            " - will retry next bar.");
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| DASHBOARD                                                          |
//+------------------------------------------------------------------+
// Modern dark-theme dashboard, built once in OnInit and updated in
// place every tick (no object recreation = no flicker). Shows exactly
// what the bot currently sees: each of the four entry conditions,
// whether they add up to a valid signal, live indicator/level values,
// and full position detail whenever a trade is open.

color dashBg       = C'14,16,21';
color dashPanelBg  = C'21,24,32';
color dashBorder   = C'42,46,58';
color dashAccent   = C'52,58,74';
color dashTextMain = C'232,235,242';
color dashTextDim  = C'128,136,152';
color dashGreen    = C'56,189,113';
color dashRed      = C'235,87,87';
color dashAmber    = C'245,166,35';
color dashBlue     = C'59,150,240';

//+------------------------------------------------------------------+
void DashRect(string name, int x, int y, int w, int h, color bg, color border)
{
   string full = dashPrefix + name;
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, full, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, full, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, full, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, full, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, full, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, full, OBJPROP_COLOR, border);
   ObjectSetInteger(0, full, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, full, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, full, OBJPROP_BACK, false);
   ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void DashLabel(string name, int x, int y, string text, color clr, int fontSize = 9, string font = "Segoe UI")
{
   string full = dashPrefix + name;
   if(ObjectFind(0, full) < 0)
      ObjectCreate(0, full, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, full, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, full, OBJPROP_TEXT, text);
   ObjectSetString(0, full, OBJPROP_FONT, font);
   ObjectSetInteger(0, full, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, full, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, full, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
// Splits text into two lines at the last word boundary at or before
// maxCharsPerLine, rather than letting it run off the edge of the
// panel. Falls back to a hard split only if no space is found at all
// (e.g. one very long unbroken word).
void WrapTextTwoLines(string text, int maxCharsPerLine, string &line1, string &line2)
{
   if(StringLen(text) <= maxCharsPerLine)
   {
      line1 = text;
      line2 = "";
      return;
   }

   int searchLimit = MathMin(maxCharsPerLine, StringLen(text) - 1);
   int splitPos = -1;
   for(int i = searchLimit; i >= 0; i--)
   {
      if(StringGetCharacter(text, i) == ' ')
      {
         splitPos = i;
         break;
      }
   }

   if(splitPos < 0)
   {
      line1 = StringSubstr(text, 0, maxCharsPerLine);
      line2 = StringSubstr(text, maxCharsPerLine);
   }
   else
   {
      line1 = StringSubstr(text, 0, splitPos);
      line2 = StringSubstr(text, splitPos + 1);
   }
}

//+------------------------------------------------------------------+
// Shared row-height constants - both CreateDashboard and UpdateDashboard
// use these same values so the two can never drift out of sync.
#define DASH_ROW_H      18   // standard label/value row
#define DASH_HDR_H      20   // section header row
#define DASH_GAP        8    // gap after a section, before the next divider

//+------------------------------------------------------------------+
void CreateDashboard()
{
   if(!InpShowDashboard)
      return;

   int x = InpDashX;
   int y = InpDashY;
   int w = InpDashWidth;

   // Background panel created FIRST (placeholder height) so everything
   // else drawn after it naturally stacks on top, by creation order.
   // Resized to the real, exact height at the end of this function.
   DashRect("bg", x, y, w, 10, dashPanelBg, dashBorder);

   int cy = y; // running cursor - every row advances this, nothing is hand-calculated

   // Title bar
   DashRect("title", x, cy, w, 32, C'27,31,41', dashAccent);
   DashLabel("titleTxt", x+14, cy+9, "GS - v" + BOT_VERSION, dashTextMain, 10, "Segoe UI Semibold");
   cy += 32;

   // Status row - large, colored, full-width band
   DashRect("statusBg", x, cy, w, 40, dashBg, dashBorder);
   DashLabel("statusVal", x+14, cy+11, "FLAT", dashTextMain, 13, "Segoe UI Semibold");
   cy += 40 + 6;

   // Waiting-for banner - THREE lines now (title + 2-line wrapped detail)
   // so longer messages never run off the edge of the panel
   DashRect("waitBg", x+8, cy, w-16, 59, dashBg, dashBorder);
   DashRect("waitAccent", x+8, cy, 4, 59, dashAmber, dashAmber);
   DashLabel("waitVal", x+22, cy+8, "Loading...", dashAmber, 9, "Segoe UI Semibold");
   DashLabel("waitVal2", x+22, cy+25, "", dashTextDim, 8);
   DashLabel("waitVal3", x+22, cy+38, "", dashTextDim, 8);
   cy += 59 + DASH_GAP;

   // Entry conditions
   DashRect("condAccent", x+8, cy, 4, DASH_HDR_H + 4*DASH_ROW_H, dashBorder, dashBorder);
   DashLabel("condHeader", x+22, cy+3, "ENTRY CONDITIONS", dashTextDim, 8, "Segoe UI Semibold");
   cy += DASH_HDR_H;
   string condRows[4] = {"brkUp","brkDown","macdPos","macdNeg"};
   string condLbls[4] = {"Breakout above resistance","Breakout below support","Main line positive","Main line negative"};
   for(int i=0;i<4;i++)
   {
      DashLabel(condRows[i]+"Lbl", x+22, cy+3, condLbls[i], dashTextDim, 8);
      DashLabel(condRows[i]+"Val", x+w-70, cy+3, "--", dashTextDim, 8, "Segoe UI Semibold");
      cy += DASH_ROW_H;
   }
   cy += DASH_GAP;

   // Levels - resistance/support split onto two lines so long numbers
   // never overflow the panel width, regardless of symbol digit count.
   // "Live MACD" shows the CURRENTLY FORMING bar's value (updates every
   // tick) right next to the OFFICIAL value (last CLOSED bar only, which
   // is what the trading decision actually uses) - without this, the
   // two can visibly disagree (e.g. official still positive while live
   // is already dipping toward zero) with no way to tell why.
   DashRect("divider1", x+8, cy, w-16, 1, dashBorder, dashBorder);
   cy += 6;
   DashRect("valAccent", x+8, cy, 4, DASH_HDR_H + 5*DASH_ROW_H, dashBorder, dashBorder);
   DashLabel("valHeader", x+22, cy+3, "LEVELS", dashTextDim, 8, "Segoe UI Semibold");
   cy += DASH_HDR_H;
   DashLabel("priceLbl", x+22, cy+3, "Price", dashTextDim, 8);
   DashLabel("priceVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("macdLbl", x+22, cy+3, "MACD Main (closed)", dashTextDim, 8);
   DashLabel("macdVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("macdLiveLbl", x+22, cy+3, "MACD Main (live)", dashTextDim, 8);
   DashLabel("macdLiveVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("resLbl", x+22, cy+3, "Resistance", dashTextDim, 8);
   DashLabel("resVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("supLbl", x+22, cy+3, "Support", dashTextDim, 8);
   DashLabel("supVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H + DASH_GAP;

   // Risk Management - sizing, plus exit mode and SL basis so the full
   // risk picture is visible in one place, not just position sizing
   DashRect("divider2", x+8, cy, w-16, 1, dashBorder, dashBorder);
   cy += 6;
   DashRect("sizeAccent", x+8, cy, 4, DASH_HDR_H + 4*DASH_ROW_H + 14, dashBorder, dashBorder);
   DashLabel("sizeHeader", x+22, cy+3, "RISK MANAGEMENT", dashTextDim, 8, "Segoe UI Semibold");
   cy += DASH_HDR_H;
   DashLabel("sizeModeLbl", x+22, cy+3, "Sizing Mode", dashTextDim, 8);
   DashLabel("sizeModeVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("sizeLotLbl", x+22, cy+3, "Next Lot (est.)", dashTextDim, 8);
   DashLabel("sizeLotVal", x+w-130, cy+3, "--", dashTextMain, 8, "Segoe UI Semibold");
   cy += DASH_ROW_H;
   DashLabel("sizeSubVal", x+22, cy+2, "", dashTextDim, 7);
   cy += 14;
   DashLabel("exitModeLbl", x+22, cy+3, "Exit Mode", dashTextDim, 8);
   DashLabel("exitModeVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("slBasisLbl", x+22, cy+3, "SL Basis", dashTextDim, 8);
   DashLabel("slBasisVal", x+w-190, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H + DASH_GAP;

   // Market Conditions - timeframe, which consolidation method is
   // active, and whether the range is trusted/fresh or currently frozen
   // (only meaningful under Smart Consolidation). Session removed along
   // with the session-multiplier mechanism it supported.
   DashRect("divider3b", x+8, cy, w-16, 1, dashBorder, dashBorder);
   cy += 6;
   DashRect("marketAccent", x+8, cy, 4, DASH_HDR_H + 4*DASH_ROW_H, dashBorder, dashBorder);
   DashLabel("marketHeader", x+22, cy+3, "MARKET CONDITIONS", dashTextDim, 8, "Segoe UI Semibold");
   cy += DASH_HDR_H;
   DashLabel("tfLbl", x+22, cy+3, "Timeframe", dashTextDim, 8);
   DashLabel("tfVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("consolModeLbl", x+22, cy+3, "Consolidation Mode", dashTextDim, 8);
   DashLabel("consolModeVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("rangeStatusLbl", x+22, cy+3, "Range Status", dashTextDim, 8);
   DashLabel("rangeStatusVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("chaosFilterLbl", x+22, cy+3, "Chaos Filter", dashTextDim, 8);
   DashLabel("chaosFilterVal", x+w-130, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H + DASH_GAP;

   // Chaos Scalp status - only meaningful if InpEnableChaosScalping is
   // on. Shows whether it's idle or actively running a pyramid cycle,
   // which direction, and how many positions are currently stacked.
   DashRect("divider3c", x+8, cy, w-16, 1, dashBorder, dashBorder);
   cy += 6;
   DashRect("scalpAccent", x+8, cy, 4, DASH_HDR_H + 2*DASH_ROW_H, dashBorder, dashBorder);
   DashLabel("scalpHeader", x+22, cy+3, "CHAOS SCALP", dashTextDim, 8, "Segoe UI Semibold");
   cy += DASH_HDR_H;
   DashLabel("scalpStatusLbl", x+22, cy+3, "Status", dashTextDim, 8);
   DashLabel("scalpStatusVal", x+w-150, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H;
   DashLabel("scalpPositionsLbl", x+22, cy+3, "Pyramid Positions", dashTextDim, 8);
   DashLabel("scalpPositionsVal", x+w-150, cy+3, "--", dashTextMain, 8);
   cy += DASH_ROW_H + DASH_GAP;

   // Resize the background panel now that the real height is known -
   // DashRect updates the existing object in place since it was already
   // created above, so this does not change its stacking position.
   DashRect("bg", x, y, w, (cy - y) + 8, dashPanelBg, dashBorder);
}

//+------------------------------------------------------------------+
void RemoveDashboard()
{
   ObjectsDeleteAll(0, dashPrefix);
   ObjectDelete(0, dashPrefix+"resLine");
   ObjectDelete(0, dashPrefix+"supLine");
}

//+------------------------------------------------------------------+
// Draws the current resistance/support levels directly on the price
// chart, matching the original Pine Script's visual plots:
//   plot(resistance, color=color.green, style=plot.style_linebr, ...)
//   plot(support,    color=color.red,   style=plot.style_linebr, ...)
// Pine's "linebr" style draws a fresh line segment for each value that
// breaks/resets when the level changes. This draws the CURRENT active
// level as a short horizontal segment spanning the lookback window plus
// a bit forward, updated every bar as the range recalculates - the
// live, forward-looking equivalent for an EA (not an indicator that can
// redraw its entire history the way Pine can).
// Chart event markers - main-line cross, trade open, trade close. Style
// choices, per direct request for "professional, doesn't bother your
// eyes": thin lines (not thick/bold), placed BEHIND the candles
// (OBJPROP_BACK=true) so price action is never obscured, and a
// consistent color convention throughout - green = buy-related, red =
// sell-related - so direction is visible at a glance without needing
// to hover. Line STYLE distinguishes the event type: dotted = cross,
// solid = open, dashed = close. A small one-letter label sits just
// above/below the bar so "B"/"S" is visible without full sentences
// cluttering the chart; full detail is still in the tooltip on hover.
//
// Each marker type uses a fixed-size rotating set of object names
// (slot = counter % InpMaxChartMarkers) - once the count exceeds the
// limit, the oldest marker's name is simply reused (deleted, then
// recreated at the new position), so the chart never accumulates an
// unbounded number of old markers over a long-running session.
int crossMarkerCounter = 0;
int openMarkerCounter  = 0;
int closeMarkerCounter = 0;

//+------------------------------------------------------------------+
void DrawEventMarker(string namePrefix, int &counter, datetime barTime, double labelPrice,
                     string labelText, color clr, ENUM_LINE_STYLE lineStyle, string tooltip)
{
   int slot = counter % InpMaxChartMarkers;
   counter++;

   string lineName = dashPrefix + namePrefix + "Line_" + (string)slot;
   string textName = dashPrefix + namePrefix + "Text_" + (string)slot;

   ObjectDelete(0, lineName);
   ObjectDelete(0, textName);

   ObjectCreate(0, lineName, OBJ_VLINE, 0, barTime, 0);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
   ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, lineName, OBJPROP_TOOLTIP, tooltip);

   ObjectCreate(0, textName, OBJ_TEXT, 0, barTime, labelPrice);
   ObjectSetString(0, textName, OBJPROP_TEXT, labelText);
   ObjectSetString(0, textName, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, textName, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
void DrawCrossMarker(datetime barTime, bool isBuy, double barHigh, double barLow)
{
   if(!InpShowCrossMarkers)
      return;

   color clr = isBuy ? dashGreen : dashRed;
   string label = isBuy ? "B" : "S";
   double labelPrice = isBuy ? barHigh : barLow;
   string tooltip = "Main line crossed " + (isBuy ? "UP" : "DOWN") + " through zero here";

   DrawEventMarker("cross", crossMarkerCounter, barTime, labelPrice, label, clr, STYLE_DOT, tooltip);
}

//+------------------------------------------------------------------+
void DrawTradeOpenMarker(datetime barTime, bool isBuy, double entryPrice)
{
   if(!InpShowTradeMarkers)
      return;

   color clr = isBuy ? dashGreen : dashRed;
   string label = isBuy ? "OPEN B" : "OPEN S";
   string tooltip = "Trade OPENED - " + (isBuy ? "BUY" : "SELL") + " @ " + DoubleToString(entryPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   DrawEventMarker("open", openMarkerCounter, barTime, entryPrice, label, clr, STYLE_SOLID, tooltip);
}

//+------------------------------------------------------------------+
void DrawTradeCloseMarker(datetime barTime, double closePrice, double profit)
{
   if(!InpShowTradeMarkers)
      return;

   color clr = (profit >= 0.0) ? dashGreen : dashRed;
   string label = "CLOSE";
   string tooltip = "Trade CLOSED @ " + DoubleToString(closePrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                     " (" + (profit >= 0.0 ? "+" : "") + DoubleToString(profit, 2) + ")";

   DrawEventMarker("close", closeMarkerCounter, barTime, closePrice, label, clr, STYLE_DASH, tooltip);
}

//+------------------------------------------------------------------+
void DrawSRLines(double resistance, double support, bool dataReady, bool hasOpenPosition, ENUM_POSITION_TYPE posType)
{
   if(!dataReady)
   {
      ObjectDelete(0, dashPrefix+"resLine");
      ObjectDelete(0, dashPrefix+"supLine");
      ObjectDelete(0, dashPrefix+"resTriggerLine");
      ObjectDelete(0, dashPrefix+"supTriggerLine");
      ObjectDelete(0, dashPrefix+"brokenLevelLine");
      ObjectDelete(0, dashPrefix+"brokenLevelText");
      // BUG FIX: these 4 were only ever cleaned up in the flat branch
      // further below - if a trade closes and this "not ready" early
      // return then fires (e.g. Smart Consolidation has no trusted
      // range right after), execution never reaches that cleanup code,
      // leaving stale lines from the PREVIOUS open trade's display
      // visible on the chart indefinitely. Confirmed directly from a
      // real screenshot showing exactly this.
      ObjectDelete(0, dashPrefix+"histOtherLine");
      ObjectDelete(0, dashPrefix+"histOtherText");
      ObjectDelete(0, dashPrefix+"freshResLine");
      ObjectDelete(0, dashPrefix+"freshSupLine");
      return;
   }

   datetime barStart = iTime(_Symbol, InpSignalTimeframe, InpConsolidationLookback + 1);
   datetime barEnd   = iTime(_Symbol, InpSignalTimeframe, 0) +
                        PeriodSeconds(InpSignalTimeframe) * 5; // extend a few bars forward

   // Originally the earlier ATR-adaptive trigger lines kept visibly
   // shifting during an open trade (recalculating from LIVE ATR every
   // tick, even though the underlying locked S/R itself was correctly
   // static) - which is why trigger lines are still hidden below while
   // a position is open, since a new entry can't happen anyway. But per
   // further direct request, hiding everything else down to a single
   // broken-level marker was too little context - the full picture
   // wanted is below: the broken level highlighted, the FULL historical
   // range that was active at entry (both sides, for context), AND a
   // live, continuously-updating fresh range showing what's forming
   // continuously-updating fresh range showing what's forming now -
   // all three at once, not just the single broken level alone.
   if(hasOpenPosition)
   {
      // 1. The broken level - unchanged, amber/gold, clearly labeled
      double brokenLevel = (posType == POSITION_TYPE_BUY) ? resistance : support;
      string brokenLabel = (posType == POSITION_TYPE_BUY) ? "BROKEN RESISTANCE" : "BROKEN SUPPORT";
      color brokenColor = C'255,190,60';

      string lineName = dashPrefix + "brokenLevelLine";
      string textName = dashPrefix + "brokenLevelText";

      if(ObjectFind(0, lineName) < 0)
         ObjectCreate(0, lineName, OBJ_TREND, 0, barStart, brokenLevel, barEnd, brokenLevel);
      else
      {
         ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, barStart);
         ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, brokenLevel);
         ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, barEnd);
         ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, brokenLevel);
      }
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, brokenColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, lineName, OBJPROP_TOOLTIP, brokenLabel + " - the exact level broken to enter this trade, locked until it closes");

      if(ObjectFind(0, textName) < 0)
         ObjectCreate(0, textName, OBJ_TEXT, 0, barStart, brokenLevel);
      ObjectSetInteger(0, textName, OBJPROP_TIME, 0, barStart);
      ObjectSetDouble(0, textName, OBJPROP_PRICE, 0, brokenLevel);
      ObjectSetString(0, textName, OBJPROP_TEXT, brokenLabel);
      ObjectSetString(0, textName, OBJPROP_FONT, "Segoe UI Semibold");
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, textName, OBJPROP_COLOR, brokenColor);
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);

      // 2. The OTHER side of the same historical/locked range - muted
      // gray, dashed, so the full box that was active at entry is
      // visible for context, clearly distinct from the highlighted
      // broken side.
      double otherHistLevel = (posType == POSITION_TYPE_BUY) ? support : resistance;
      string otherHistLabel = (posType == POSITION_TYPE_BUY) ? "Support (at entry)" : "Resistance (at entry)";
      color histColor = C'130,136,148';

      string histLineName = dashPrefix + "histOtherLine";
      string histTextName = dashPrefix + "histOtherText";

      if(ObjectFind(0, histLineName) < 0)
         ObjectCreate(0, histLineName, OBJ_TREND, 0, barStart, otherHistLevel, barEnd, otherHistLevel);
      else
      {
         ObjectSetInteger(0, histLineName, OBJPROP_TIME, 0, barStart);
         ObjectSetDouble(0, histLineName, OBJPROP_PRICE, 0, otherHistLevel);
         ObjectSetInteger(0, histLineName, OBJPROP_TIME, 1, barEnd);
         ObjectSetDouble(0, histLineName, OBJPROP_PRICE, 1, otherHistLevel);
      }
      ObjectSetInteger(0, histLineName, OBJPROP_COLOR, histColor);
      ObjectSetInteger(0, histLineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, histLineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, histLineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, histLineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, histLineName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, histLineName, OBJPROP_TOOLTIP, otherHistLabel + " - the far side of the consolidation range that was active when this trade entered");

      if(ObjectFind(0, histTextName) < 0)
         ObjectCreate(0, histTextName, OBJ_TEXT, 0, barStart, otherHistLevel);
      ObjectSetInteger(0, histTextName, OBJPROP_TIME, 0, barStart);
      ObjectSetDouble(0, histTextName, OBJPROP_PRICE, 0, otherHistLevel);
      ObjectSetString(0, histTextName, OBJPROP_TEXT, otherHistLabel);
      ObjectSetString(0, histTextName, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, histTextName, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, histTextName, OBJPROP_COLOR, histColor);
      ObjectSetInteger(0, histTextName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, histTextName, OBJPROP_HIDDEN, true);

      // 3. A LIVE, continuously-updating fresh range - calculated
      // independently of the lock, purely for visual context, so you
      // can see what's forming now while still watching the trade that
      // came from the OLD range. This does NOT feed into any trading
      // decision - entries stay correctly locked out while a position
      // is open, this is display-only.
      double freshHigh = 0.0, freshLow = 0.0;
      bool gotFreshRange = InpUseSmartConsolidation
         ? GetSmartConsolidationRange(freshHigh, freshLow)
         : GetConsolidationRange(freshHigh, freshLow);

      if(gotFreshRange)
      {
         string freshResName = dashPrefix + "freshResLine";
         string freshSupName = dashPrefix + "freshSupLine";

         if(ObjectFind(0, freshResName) < 0)
            ObjectCreate(0, freshResName, OBJ_TREND, 0, barStart, freshHigh, barEnd, freshHigh);
         else
         {
            ObjectSetInteger(0, freshResName, OBJPROP_TIME, 0, barStart);
            ObjectSetDouble(0, freshResName, OBJPROP_PRICE, 0, freshHigh);
            ObjectSetInteger(0, freshResName, OBJPROP_TIME, 1, barEnd);
            ObjectSetDouble(0, freshResName, OBJPROP_PRICE, 1, freshHigh);
         }
         ObjectSetInteger(0, freshResName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, freshResName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, freshResName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, freshResName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, freshResName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, freshResName, OBJPROP_HIDDEN, true);
         ObjectSetString(0, freshResName, OBJPROP_TOOLTIP, "Resistance forming NOW (live, " + (string)InpConsolidationLookback + "-bar) - not locked, updates every bar while this trade is open");

         if(ObjectFind(0, freshSupName) < 0)
            ObjectCreate(0, freshSupName, OBJ_TREND, 0, barStart, freshLow, barEnd, freshLow);
         else
         {
            ObjectSetInteger(0, freshSupName, OBJPROP_TIME, 0, barStart);
            ObjectSetDouble(0, freshSupName, OBJPROP_PRICE, 0, freshLow);
            ObjectSetInteger(0, freshSupName, OBJPROP_TIME, 1, barEnd);
            ObjectSetDouble(0, freshSupName, OBJPROP_PRICE, 1, freshLow);
         }
         ObjectSetInteger(0, freshSupName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, freshSupName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, freshSupName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, freshSupName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, freshSupName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, freshSupName, OBJPROP_HIDDEN, true);
         ObjectSetString(0, freshSupName, OBJPROP_TOOLTIP, "Support forming NOW (live, " + (string)InpConsolidationLookback + "-bar) - not locked, updates every bar while this trade is open");
      }

      // No trigger lines while in a trade - a new entry can't happen
      // anyway, so the breakout distance isn't relevant right now.
      ObjectDelete(0, dashPrefix+"resTriggerLine");
      ObjectDelete(0, dashPrefix+"supTriggerLine");

      return;
   }

   // Flat - no trade open, so clean up all the open-trade markers and
   // resume showing the normal searching lines for the next setup.
   ObjectDelete(0, dashPrefix+"brokenLevelLine");
   ObjectDelete(0, dashPrefix+"brokenLevelText");
   ObjectDelete(0, dashPrefix+"histOtherLine");
   ObjectDelete(0, dashPrefix+"histOtherText");
   ObjectDelete(0, dashPrefix+"freshResLine");
   ObjectDelete(0, dashPrefix+"freshSupLine");

   string resName = dashPrefix + "resLine";
   string supName = dashPrefix + "supLine";

   if(ObjectFind(0, resName) < 0)
      ObjectCreate(0, resName, OBJ_TREND, 0, barStart, resistance, barEnd, resistance);
   else
   {
      ObjectSetInteger(0, resName, OBJPROP_TIME, 0, barStart);
      ObjectSetDouble(0, resName, OBJPROP_PRICE, 0, resistance);
      ObjectSetInteger(0, resName, OBJPROP_TIME, 1, barEnd);
      ObjectSetDouble(0, resName, OBJPROP_PRICE, 1, resistance);
   }
   ObjectSetInteger(0, resName, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, resName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, resName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, resName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, resName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, resName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, resName, OBJPROP_TOOLTIP, "Resistance (dynamic S/R, " + (string)InpConsolidationLookback + "-bar)");

   if(ObjectFind(0, supName) < 0)
      ObjectCreate(0, supName, OBJ_TREND, 0, barStart, support, barEnd, support);
   else
   {
      ObjectSetInteger(0, supName, OBJPROP_TIME, 0, barStart);
      ObjectSetDouble(0, supName, OBJPROP_PRICE, 0, support);
      ObjectSetInteger(0, supName, OBJPROP_TIME, 1, barEnd);
      ObjectSetDouble(0, supName, OBJPROP_PRICE, 1, support);
   }
   ObjectSetInteger(0, supName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, supName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, supName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, supName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, supName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, supName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, supName, OBJPROP_TOOLTIP, "Support (dynamic S/R, " + (string)InpConsolidationLookback + "-bar)");

   // The ACTUAL breakout trigger levels - matches whichever mode (fixed
   // % or ATR-adaptive) is actually driving entry decisions. Only drawn
   // while flat, since they're not relevant during an open trade.
   double triggerDistHigh, triggerDistLow;
   if(InpBreakoutMode == BREAKOUT_ATR_ADAPTIVE)
   {
      double atrNow = 0.0;
      GetBreakoutATR(atrNow); // if this fails, distance falls back to 0 (lines sit on the raw S/R level)
      double atrDist = atrNow * InpBreakoutATRMult;
      if(InpBreakoutMaxPoints > 0.0)
         atrDist = MathMin(atrDist, InpBreakoutMaxPoints);
      triggerDistHigh = atrDist;
      triggerDistLow  = atrDist;
   }
   else
   {
      triggerDistHigh = resistance * (InpBreakoutPercent / 100.0);
      triggerDistLow  = support    * (InpBreakoutPercent / 100.0);
   }

   double resTrigger = resistance + triggerDistHigh;
   double supTrigger = support    - triggerDistLow;

   string resTrigName = dashPrefix + "resTriggerLine";
   string supTrigName = dashPrefix + "supTriggerLine";

   if(ObjectFind(0, resTrigName) < 0)
      ObjectCreate(0, resTrigName, OBJ_TREND, 0, barStart, resTrigger, barEnd, resTrigger);
   else
   {
      ObjectSetInteger(0, resTrigName, OBJPROP_TIME, 0, barStart);
      ObjectSetDouble(0, resTrigName, OBJPROP_PRICE, 0, resTrigger);
      ObjectSetInteger(0, resTrigName, OBJPROP_TIME, 1, barEnd);
      ObjectSetDouble(0, resTrigName, OBJPROP_PRICE, 1, resTrigger);
   }
   ObjectSetInteger(0, resTrigName, OBJPROP_COLOR, C'150,220,150');
   ObjectSetInteger(0, resTrigName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, resTrigName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, resTrigName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, resTrigName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, resTrigName, OBJPROP_HIDDEN, true);
   string modeDesc = (InpBreakoutMode == BREAKOUT_ATR_ADAPTIVE)
      ? ("ATR(" + (string)InpBreakoutATRPeriod + ") x " + DoubleToString(InpBreakoutATRMult,2) +
         ", capped at " + DoubleToString(InpBreakoutMaxPoints,1) + "pts")
      : (DoubleToString(InpBreakoutPercent,2) + "%");

   ObjectSetString(0, resTrigName, OBJPROP_TOOLTIP,
      "BUY breakout trigger - price must close above this (resistance + " +
      modeDesc + ") for Breakout to show MET");

   if(ObjectFind(0, supTrigName) < 0)
      ObjectCreate(0, supTrigName, OBJ_TREND, 0, barStart, supTrigger, barEnd, supTrigger);
   else
   {
      ObjectSetInteger(0, supTrigName, OBJPROP_TIME, 0, barStart);
      ObjectSetDouble(0, supTrigName, OBJPROP_PRICE, 0, supTrigger);
      ObjectSetInteger(0, supTrigName, OBJPROP_TIME, 1, barEnd);
      ObjectSetDouble(0, supTrigName, OBJPROP_PRICE, 1, supTrigger);
   }
   ObjectSetInteger(0, supTrigName, OBJPROP_COLOR, C'230,150,150');
   ObjectSetInteger(0, supTrigName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, supTrigName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, supTrigName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, supTrigName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, supTrigName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, supTrigName, OBJPROP_TOOLTIP,
      "SELL breakout trigger - price must close below this (support - " +
      modeDesc + ") for Breakout to show MET");
}

//+------------------------------------------------------------------+
color CondColor(bool state)
{
   return state ? dashGreen : dashTextDim;
}

//+------------------------------------------------------------------+
void UpdateDashboard(bool dataReady, bool brkUp, bool brkDown, bool macdPos, bool macdNeg,
                     bool validBuy, bool validSell,
                     double price, double macdVal, double resVal, double supVal,
                     bool freshCrossUp, bool freshCrossDown, double liveMacd,
                     double breakoutDistHigh, double breakoutDistLow, string notReadyReason,
                     bool chaosActive)
{
   if(!InpShowDashboard)
      return;

   int x = InpDashX;
   int y = InpDashY;
   int w = InpDashWidth;

   ulong ticket = 0;
   ENUM_POSITION_TYPE type;
   bool hasPosition = FindOurPosition(ticket, type);

   // Recompute the SAME cursor sequence CreateDashboard used, so the
   // position-block's coordinates can never drift out of sync with it.
   int cy = y;
   cy += 32;               // title
   cy += 40 + 6;           // status
   cy += 59 + DASH_GAP;    // waiting banner (now 3 lines)
   cy += DASH_HDR_H + 4*DASH_ROW_H + DASH_GAP; // entry conditions
   cy += 6 + DASH_HDR_H + 5*DASH_ROW_H + DASH_GAP; // divider1 + levels (now 5 rows, added live MACD)
   cy += 6 + DASH_HDR_H + 4*DASH_ROW_H + 14 + DASH_GAP; // divider2 + risk management
   cy += 6 + DASH_HDR_H + 4*DASH_ROW_H + DASH_GAP; // divider3b + market conditions (added Chaos Filter row)
   cy += 6 + DASH_HDR_H + 2*DASH_ROW_H + DASH_GAP; // divider3c + chaos scalp status
   int baseBottom = cy; // where the base (no-position) content ends

   int panelH = baseBottom - y + 8;
   if(hasPosition)
      panelH += 6 + DASH_HDR_H + 6*DASH_ROW_H + DASH_GAP; // divider3 + position block (now 6 rows, added SMA-switch status)

   // Per direct request: the whole dashboard border changes color when
   // chaos is detected, so it's obvious at a glance rather than needing
   // to read a specific status row. Orange rather than red - red is
   // already used for the specific "entries paused" text, so this
   // keeps a visual distinction between "something serious is
   // happening" (border) and "here's exactly what" (the red text).
   color liveBorderColor = chaosActive ? C'255,140,0' : dashBorder;
   DashRect("bg", x, y, w, panelH, dashPanelBg, liveBorderColor);
   ObjectSetInteger(0, dashPrefix+"bg", OBJPROP_WIDTH, chaosActive ? 3 : 1);

   // Status
   string statusText = "FLAT";
   color statusColor = dashTextDim;
   if(!dataReady)
   {
      statusText = "LOADING HISTORY...";
      statusColor = dashAmber;
   }
   else if(hasPosition)
   {
      statusText = (type == POSITION_TYPE_BUY) ? "IN TRADE - BUY" : "IN TRADE - SELL";
      statusColor = (type == POSITION_TYPE_BUY) ? dashGreen : dashRed;
   }
   ObjectSetString(0, dashPrefix+"statusVal", OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, dashPrefix+"statusVal", OBJPROP_COLOR, statusColor);

   // "Waiting for" banner - dynamically explains exactly what is
   // missing for the next trade, using only the same booleans already
   // computed for the conditions list. No trading logic touched here -
   // this just describes it in plain language.
   // Live-price breakout preview - compares the CURRENT, still-forming
   // price against the same threshold the official decision uses (which
   // only evaluates on the last COMPLETED bar's close). This is exactly
   // what was missing when a live breakout was visible on the chart but
   // the dashboard gave no way to tell "live price already clears this"
   // apart from "the deciding bar hasn't closed yet."
   double breakoutThresholdPreview = InpBreakoutPercent / 100.0;
   bool liveBreakoutUp   = (resVal > 0.0) && (price >= resVal) && ((price - resVal) / resVal) >= breakoutThresholdPreview;
   bool liveBreakoutDown = (supVal > 0.0) && (price <= supVal) && ((supVal - price) / supVal) >= breakoutThresholdPreview;

   string waitTitle, waitDetail;
   color waitColor;

   if(!dataReady)
   {
      // Uses the SPECIFIC reason from EvaluateConditions rather than a
      // generic "loading" message for every case - found directly from
      // a real case where Smart Consolidation genuinely had no tight-
      // enough range for an extended period, which looked identical to
      // "still loading" on the dashboard but was a completely different
      // situation with a completely different resolution.
      waitTitle = (InpUseSmartConsolidation && smartHasTrustedRange == false)
         ? "Smart Consolidation - no trusted range yet"
         : "Loading price history...";
      waitDetail = notReadyReason;
      waitColor = dashAmber;
   }
   else if(hasPosition)
   {
      waitTitle = "Monitoring open position";
      if(InpEnableSmaSwitchExit && smaSwitchActive)
      {
         waitDetail = "Profit crossed the switch threshold - now watching for a candle to close beyond the " +
                      (string)InpSmaSwitchPeriod + " SMA instead of the MACD signal.";
      }
      else if(partialCloseDone)
      {
         waitDetail = "Breakeven locked - watching for the full exit signal.";
      }
      else
      {
         waitDetail = (InpExitMode == EXIT_MODE_DECELERATION)
            ? "Watching for momentum to decelerate while in profit (partial close)."
            : "Watching for the histogram to turn against the trade (partial close).";
      }
      waitColor = dashBlue;
   }
   else if(chaosActive)
   {
      waitTitle = "Chaos filter active - entries paused";
      waitDetail = "Choppy conditions and a genuine volatility spike detected together - "
                   "waiting for calmer conditions before considering any new entry.";
      waitColor = dashRed;
   }
   else if(validBuy)
   {
      waitTitle = "BUY conditions met";
      waitDetail = "Breakout + main line cross confirmed - entering now.";
      waitColor = dashGreen;
   }
   else if(validSell)
   {
      waitTitle = "SELL conditions met";
      waitDetail = "Breakout + main line cross confirmed - entering now.";
      waitColor = dashRed;
   }
   else if(brkUp && !macdPos)
   {
      waitTitle = "Broke resistance - waiting on MACD";
      waitDetail = "Needs the main line to cross up through zero to confirm.";
      waitColor = dashAmber;
   }
   else if(brkDown && !macdNeg)
   {
      waitTitle = "Broke support - waiting on MACD";
      waitDetail = "Needs the main line to cross down through zero to confirm.";
      waitColor = dashAmber;
   }
   else if(macdPos && !brkUp)
   {
      // NOTE: entry no longer requires a fresh same-bar cross (changed
      // per direct instruction + repeated real-chart evidence) - the
      // main line simply needs to currently be positive when a breakout
      // confirms, however many bars ago it actually crossed. So this
      // branch now only needs the breakout itself, nothing about
      // freshness.
      waitTitle = "Main line positive - waiting on breakout";
      waitDetail = liveBreakoutUp
         ? "Live price already clears the breakout level - waiting for THIS candle to close to confirm."
         : "Needs price to break above resistance by the threshold.";
      waitColor = dashAmber;
   }
   else if(macdNeg && !brkDown)
   {
      waitTitle = "Main line negative - waiting on breakout";
      waitDetail = liveBreakoutDown
         ? "Live price already clears the breakout level - waiting for THIS candle to close to confirm."
         : "Needs price to break below support by the threshold.";
      waitColor = dashAmber;
   }
   else
   {
      waitTitle = "Waiting for setup";
      waitDetail = "Needs a consolidation breakout + matching main line cross.";
      waitColor = dashTextDim;
   }

   ObjectSetInteger(0, dashPrefix+"waitAccent", OBJPROP_BGCOLOR, waitColor);
   ObjectSetString(0, dashPrefix+"waitVal", OBJPROP_TEXT, waitTitle);
   ObjectSetInteger(0, dashPrefix+"waitVal", OBJPROP_COLOR, waitColor);

   string waitDetailLine1, waitDetailLine2;
   WrapTextTwoLines(waitDetail, 42, waitDetailLine1, waitDetailLine2);
   ObjectSetString(0, dashPrefix+"waitVal2", OBJPROP_TEXT, waitDetailLine1);
   ObjectSetString(0, dashPrefix+"waitVal3", OBJPROP_TEXT, waitDetailLine2);

   // Conditions - show a neutral placeholder (not stale data) until ready
   string condTxt = dataReady ? "" : "--";
   ObjectSetString(0, dashPrefix+"brkUpVal", OBJPROP_TEXT, dataReady ? (brkUp ? "MET" : "--") : condTxt);
   ObjectSetInteger(0, dashPrefix+"brkUpVal", OBJPROP_COLOR, dataReady ? CondColor(brkUp) : dashTextDim);
   ObjectSetString(0, dashPrefix+"brkDownVal", OBJPROP_TEXT, dataReady ? (brkDown ? "MET" : "--") : condTxt);
   ObjectSetInteger(0, dashPrefix+"brkDownVal", OBJPROP_COLOR, dataReady ? CondColor(brkDown) : dashTextDim);
   ObjectSetString(0, dashPrefix+"macdPosVal", OBJPROP_TEXT, dataReady ? (macdPos ? "MET" : "--") : condTxt);
   ObjectSetInteger(0, dashPrefix+"macdPosVal", OBJPROP_COLOR, dataReady ? CondColor(macdPos) : dashTextDim);
   ObjectSetString(0, dashPrefix+"macdNegVal", OBJPROP_TEXT, dataReady ? (macdNeg ? "MET" : "--") : condTxt);
   ObjectSetInteger(0, dashPrefix+"macdNegVal", OBJPROP_COLOR, dataReady ? CondColor(macdNeg) : dashTextDim);

   // Levels - price is always live; MACD/S&R need dataReady to be
   // meaningful. Resistance/support each get their own line (rather than
   // one combined "X / Y" string) so long numbers never overflow.
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   ObjectSetString(0, dashPrefix+"priceVal", OBJPROP_TEXT, DoubleToString(price, digits));

   if(dataReady)
   {
      ObjectSetString(0, dashPrefix+"macdVal", OBJPROP_TEXT, DoubleToString(macdVal, 4));
      ObjectSetInteger(0, dashPrefix+"macdVal", OBJPROP_COLOR, macdVal > 0 ? dashGreen : (macdVal < 0 ? dashRed : dashTextMain));
      ObjectSetString(0, dashPrefix+"macdLiveVal", OBJPROP_TEXT, DoubleToString(liveMacd, 4));
      ObjectSetInteger(0, dashPrefix+"macdLiveVal", OBJPROP_COLOR, liveMacd > 0 ? dashGreen : (liveMacd < 0 ? dashRed : dashTextMain));
      ObjectSetString(0, dashPrefix+"resVal", OBJPROP_TEXT, DoubleToString(resVal,digits));
      ObjectSetString(0, dashPrefix+"supVal", OBJPROP_TEXT, DoubleToString(supVal,digits));
   }
   else
   {
      ObjectSetString(0, dashPrefix+"macdVal", OBJPROP_TEXT, "--");
      ObjectSetInteger(0, dashPrefix+"macdVal", OBJPROP_COLOR, dashTextDim);
      ObjectSetString(0, dashPrefix+"macdLiveVal", OBJPROP_TEXT, "--");
      ObjectSetInteger(0, dashPrefix+"macdLiveVal", OBJPROP_COLOR, dashTextDim);
      ObjectSetString(0, dashPrefix+"resVal", OBJPROP_TEXT, "--");
      ObjectSetString(0, dashPrefix+"supVal", OBJPROP_TEXT, "--");
   }

   string modeText = (InpSizingMode == SIZING_FIXED_LOT) ? "Fixed Lot" :
                      (InpSizingMode == SIZING_KELLY) ? "Kelly" :
                      (InpSizingMode == SIZING_FIXED_LOT_AUTO) ? "Auto Lot" : "Risk %";
   ObjectSetString(0, dashPrefix+"sizeModeVal", OBJPROP_TEXT, modeText);

   // Next-lot preview - the qualifier (Kelly risk %, Index/Other tag)
   // goes on its own smaller sub-line beneath the main value, rather
   // than one long concatenated string that could run past the panel.
   bool sideForPreview = validBuy || macdVal > 0.0;
   double previewLots = CalculateLots(sideForPreview, price);
   ObjectSetString(0, dashPrefix+"sizeLotVal", OBJPROP_TEXT, DoubleToString(previewLots, 2));

   string subText = "";
   if(InpSizingMode == SIZING_KELLY)
      subText = "Kelly risk " + DoubleToString(CalculateKellyRiskPercent(), 2) + "%";
   else if(InpSizingMode == SIZING_FIXED_LOT_AUTO)
      subText = IsIndexInstrument() ? "Detected: Index" : "Detected: Other";
   ObjectSetString(0, dashPrefix+"sizeSubVal", OBJPROP_TEXT, subText);

   // Exit mode + SL basis - completes the risk picture (what triggers
   // partial close/breakeven, and where the protective stop actually
   // sits) alongside position sizing, in one place.
   string exitModeText = (InpExitMode == EXIT_MODE_DECELERATION) ? "Deceleration" : "Full Reversal";
   ObjectSetString(0, dashPrefix+"exitModeVal", OBJPROP_TEXT, exitModeText);

   if(InpUseConsolidationSL && dataReady)
   {
      double buySLShown  = supVal - breakoutDistLow;
      double sellSLShown = resVal + breakoutDistHigh;
      string slText = "Buy:" + DoubleToString(buySLShown,digits) + " Sell:" + DoubleToString(sellSLShown,digits);
      ObjectSetString(0, dashPrefix+"slBasisVal", OBJPROP_TEXT, slText);
   }
   else
   {
      ObjectSetString(0, dashPrefix+"slBasisVal", OBJPROP_TEXT, InpUseConsolidationSL ? "--" : "Emergency backstop only");
   }

   // Market Conditions - timeframe, which consolidation method is
   // active, and whether the range is trusted/fresh or frozen (only
   // meaningful under Smart Consolidation - reads straight from the
   // global tracking flags, since those aren't threaded through the
   // EvaluateConditions/UpdateDashboard signatures)
   string tfName = EnumToString(InpSignalTimeframe);
   StringReplace(tfName, "PERIOD_", "");
   ObjectSetString(0, dashPrefix+"tfVal", OBJPROP_TEXT, tfName);

   ObjectSetString(0, dashPrefix+"consolModeVal", OBJPROP_TEXT, InpUseSmartConsolidation ? "Smart" : "Legacy");

   if(InpUseSmartConsolidation)
   {
      string rangeStatusText;
      color rangeStatusColor;
      if(!smartHasTrustedRange && smartHasRetiredRange)
      {
         rangeStatusText = "Waiting (prior range retired)";
         rangeStatusColor = dashAmber;
      }
      else if(!smartHasTrustedRange)
      {
         rangeStatusText = "Not ready yet";
         rangeStatusColor = dashAmber;
      }
      else if(smartRangeIsFrozenNow)
      {
         rangeStatusText = "Frozen (held over)";
         rangeStatusColor = dashAmber;
      }
      else
      {
         rangeStatusText = "Trusted (fresh)";
         rangeStatusColor = dashGreen;
      }
      ObjectSetString(0, dashPrefix+"rangeStatusVal", OBJPROP_TEXT, rangeStatusText);
      ObjectSetInteger(0, dashPrefix+"rangeStatusVal", OBJPROP_COLOR, rangeStatusColor);
   }
   else
   {
      ObjectSetString(0, dashPrefix+"rangeStatusVal", OBJPROP_TEXT, "--");
      ObjectSetInteger(0, dashPrefix+"rangeStatusVal", OBJPROP_COLOR, dashTextMain);
   }

   if(!InpUseChaosFilter)
   {
      ObjectSetString(0, dashPrefix+"chaosFilterVal", OBJPROP_TEXT, "Off");
      ObjectSetInteger(0, dashPrefix+"chaosFilterVal", OBJPROP_COLOR, dashTextDim);
   }
   else if(chaosActive)
   {
      ObjectSetString(0, dashPrefix+"chaosFilterVal", OBJPROP_TEXT, "ACTIVE - entries paused");
      ObjectSetInteger(0, dashPrefix+"chaosFilterVal", OBJPROP_COLOR, dashRed);
   }
   else
   {
      ObjectSetString(0, dashPrefix+"chaosFilterVal", OBJPROP_TEXT, "Clear");
      ObjectSetInteger(0, dashPrefix+"chaosFilterVal", OBJPROP_COLOR, dashGreen);
   }

   if(!chaosScalpingActive)
   {
      ObjectSetString(0, dashPrefix+"scalpStatusVal", OBJPROP_TEXT, "Off");
      ObjectSetInteger(0, dashPrefix+"scalpStatusVal", OBJPROP_COLOR, dashTextDim);
      ObjectSetString(0, dashPrefix+"scalpPositionsVal", OBJPROP_TEXT, "--");
   }
   else
   {
      int dashScalpDir = 0;
      datetime dashScalpTime = 0;
      double dashScalpPrice = 0.0;
      int dashScalpCount = CountScalpPositions(dashScalpDir, dashScalpTime, dashScalpPrice);

      if(dashScalpCount > 0)
      {
         string dirText = (dashScalpDir == 1) ? "BUY" : "SELL";
         ObjectSetString(0, dashPrefix+"scalpStatusVal", OBJPROP_TEXT, "ACTIVE - " + dirText);
         ObjectSetInteger(0, dashPrefix+"scalpStatusVal", OBJPROP_COLOR, (dashScalpDir == 1) ? dashGreen : dashRed);
         ObjectSetString(0, dashPrefix+"scalpPositionsVal", OBJPROP_TEXT, (string)dashScalpCount);
      }
      else
      {
         ObjectSetString(0, dashPrefix+"scalpStatusVal", OBJPROP_TEXT, "Idle");
         ObjectSetInteger(0, dashPrefix+"scalpStatusVal", OBJPROP_COLOR, dashTextDim);
         ObjectSetString(0, dashPrefix+"scalpPositionsVal", OBJPROP_TEXT, "0");
      }
   }

   // Position block - created/updated only while a position is open.
   // Coordinates continue the SAME cursor from baseBottom above, so
   // this can never overlap or drift out of sync with the base layout.
   if(hasPosition)
   {
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double lots  = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      long durationSec = TimeCurrent() - openTime;
      long durH = durationSec/3600;
      long durM = (durationSec%3600)/60;

      double curPrice = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double ptsMove = (type==POSITION_TYPE_BUY) ? (curPrice-entry) : (entry-curPrice);

      int pcy = baseBottom;
      DashRect("divider3", x+8, pcy, w-16, 1, dashBorder, dashBorder);
      pcy += 6;
      DashRect("posAccent", x+8, pcy, 4, DASH_HDR_H + 6*DASH_ROW_H, dashBorder, dashBorder);
      DashLabel("posHeader", x+22, pcy+3, "OPEN POSITION", dashTextDim, 8, "Segoe UI Semibold");
      pcy += DASH_HDR_H;
      DashLabel("posEntryLbl", x+22, pcy+3, "Entry", dashTextDim, 8);
      DashLabel("posEntryVal", x+w-130, pcy+3, DoubleToString(entry,digits), dashTextMain, 8);
      pcy += DASH_ROW_H;
      DashLabel("posLotsLbl", x+22, pcy+3, "Lots", dashTextDim, 8);
      DashLabel("posLotsVal", x+w-130, pcy+3, DoubleToString(lots,2), dashTextMain, 8);
      pcy += DASH_ROW_H;
      DashLabel("posPnlLbl", x+22, pcy+3, "P&L", dashTextDim, 8);
      DashLabel("posPnlVal", x+w-130, pcy+3,
                DoubleToString(profit,2) + " (" + DoubleToString(ptsMove,digits) + "pt)",
                profit >= 0 ? dashGreen : dashRed, 8, "Segoe UI Semibold");
      pcy += DASH_ROW_H;
      DashLabel("posDurLbl", x+22, pcy+3, "Duration", dashTextDim, 8);
      DashLabel("posDurVal", x+w-130, pcy+3, (string)durH+"h "+(string)durM+"m", dashTextMain, 8);
      pcy += DASH_ROW_H;
      DashLabel("posPartialLbl", x+22, pcy+3, "Partial/Breakeven", dashTextDim, 8);
      DashLabel("posPartialVal", x+w-130, pcy+3, partialCloseDone ? "DONE" : "pending",
                partialCloseDone ? dashGreen : dashTextDim, 8, "Segoe UI Semibold");
      pcy += DASH_ROW_H;

      // SMA-switch status - explains, per direct request, exactly why
      // the final exit basis has (or hasn't) switched away from MACD
      string smaSwitchText;
      color smaSwitchColor;
      if(!InpEnableSmaSwitchExit)
      {
         smaSwitchText = "Disabled";
         smaSwitchColor = dashTextDim;
      }
      else if(smaSwitchActive)
      {
         smaSwitchText = "ACTIVE (20 SMA)";
         smaSwitchColor = dashGreen;
      }
      else
      {
         double thresholdShown = GetSmaSwitchThreshold();
         smaSwitchText = "Pending (" + DoubleToString(ptsMove,1) + "/" + DoubleToString(thresholdShown,1) + "pt)";
         smaSwitchColor = dashTextDim;
      }
      DashLabel("posSmaLbl", x+22, pcy+3, "Exit Basis (SMA-switch)", dashTextDim, 8);
      DashLabel("posSmaVal", x+w-150, pcy+3, smaSwitchText, smaSwitchColor, 8, "Segoe UI Semibold");
   }
   else
   {
      // remove position-block objects when flat, so the panel shrinks cleanly
      string posNames[15] = {"divider3","posAccent","posHeader","posEntryLbl","posEntryVal","posLotsLbl","posLotsVal",
                              "posPnlLbl","posPnlVal","posDurLbl","posDurVal",
                              "posPartialLbl","posPartialVal","posSmaLbl","posSmaVal"};
      for(int i=0;i<15;i++)
         ObjectDelete(0, dashPrefix+posNames[i]);
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Evaluates all entry conditions plus the resulting verdict, using the
// LAST COMPLETED bar's data. Shared by the dashboard (every tick, for
// live display) and the actual trading logic (only acted upon once per
// new completed bar) so there is exactly one place this logic lives.
//
// FIXED per review: the original Pine Script's "OR breakoutPrevHigh/Low"
// condition (close > just the previous single bar's high/low) was far
// too weak - it fires constantly during ordinary in-range price action,
// not just on real breakouts, which is what was causing entries INSIDE
// the consolidation. Removed entirely - only a genuine break of the
// full N-bar consolidation range (with the % threshold) counts now.
//
// MACD confirmation now requires a FRESH zero-line cross on this same
// bar, not just "currently positive/negative" - tightly couples the
// MACD confirmation to the actual breakout moment, rather than allowing
// a stale sign from many bars earlier to combine with any new high/low.
//
// While a trade is open, the consolidation range is LOCKED to the exact
// range that produced the breakout (rangeLocked=true, set by the caller
// at entry) - it does not keep recalculating a moving 10-bar window
// while a position is open. A fresh range is only computed again once
// flat.
bool EvaluateConditions(double &mainNowOut, double &rangeHighOut, double &rangeLowOut,
                         bool &breakoutUpOut, bool &breakoutDownOut,
                         bool &macdPosOut, bool &macdNegOut,
                         bool &validBuyOut, bool &validSellOut,
                         bool &freshCrossUpOut, bool &freshCrossDownOut,
                         double &breakoutDistHighOut, double &breakoutDistLowOut,
                         string &notReadyReasonOut, bool &chaosActiveOut)
{
   // CONFIRMED via direct visual diagnostic (GalaxyMACD_SignalDiagnostic.mq5):
   // entries use the MAIN LINE crossing zero - the cyan arrows, confirmed
   // directly against a real chart screenshot. NOT the histogram (that
   // was an incorrect interpretation on my part, now reverted). The
   // histogram (main - signal) crossing against the trade remains the
   // correct signal for partial close + breakeven, per Miki Gala's
   // description: "the formation of the reverse histogram into which the
   // MACD line [main line] entered" - a separate, later-stage signal
   // within an already-open trade, not the entry signal itself.
   double mainNow = 0.0;
   double mainPrev = 0.0;
   if(!GetMACDMain(1, mainNow) || !GetMACDMain(2, mainPrev))
   {
      notReadyReasonOut = "Waiting for enough price history to calculate MACD.";
      return false;
   }

   double closeNow  = iClose(_Symbol, InpSignalTimeframe, 1);

   double rangeHigh = 0.0;
   double rangeLow  = 0.0;

   if(rangeLocked)
   {
      rangeHigh = lockedResistance;
      rangeLow  = lockedSupport;
   }
   else
   {
      bool gotRange = InpUseSmartConsolidation
         ? GetSmartConsolidationRange(rangeHigh, rangeLow)
         : GetConsolidationRange(rangeHigh, rangeLow);

      if(!gotRange)
      {
         // Found directly from a real case: under Smart Consolidation,
         // this can genuinely persist for a while - not because history
         // is loading, but because no candidate range has been tight
         // enough (vs the ATR x sqrt(lookback) tolerance) to trust yet,
         // or the width-freeze correctly retired the last range and
         // hasn't found a genuinely different one since. This is NOT
         // the same situation as "not enough bars exist yet", and
         // showing the same generic loading message for both was
         // actively misleading - it implies a brief, resolving-soon
         // startup condition when it might not be one at all.
         if(InpUseSmartConsolidation)
         {
            notReadyReasonOut = smartHasRetiredRange
               ? "Smart Consolidation: waiting for a genuinely different range (last one was retired after a trade)."
               : "Smart Consolidation: no candidate range has been tight enough to trust yet.";
         }
         else
         {
            notReadyReasonOut = "Waiting for enough price history to calculate the consolidation range.";
         }
         return false;
      }
   }

   // Breakout distance - EITHER a fixed % of the range level (unchanged,
   // original behavior), OR ATR x multiplier (NEW - scales with actual
   // current volatility instead of a flat distance regardless of market
   // conditions). ATR mode uses the SAME absolute distance for both the
   // high and low side, since ATR already represents "typical current
   // movement" independent of price level.
   double breakoutDistHigh, breakoutDistLow;

   if(InpBreakoutMode == BREAKOUT_ATR_ADAPTIVE)
   {
      double breakoutAtr = 0.0;
      if(!GetBreakoutATR(breakoutAtr))
      {
         notReadyReasonOut = "Waiting for enough price history to calculate ATR.";
         return false;
      }

      double atrDistance = breakoutAtr * InpBreakoutATRMult;
      if(InpBreakoutMaxPoints > 0.0)
         atrDistance = MathMin(atrDistance, InpBreakoutMaxPoints);
      breakoutDistHigh = atrDistance;
      breakoutDistLow  = atrDistance;
   }
   else
   {
      breakoutDistHigh = rangeHigh * (InpBreakoutPercent / 100.0);
      breakoutDistLow  = rangeLow  * (InpBreakoutPercent / 100.0);
   }

   bool breakoutFromConsHigh =
      closeNow >= rangeHigh &&
      (rangeHigh > 0.0) &&
      (closeNow - rangeHigh) >= breakoutDistHigh;

   bool breakoutFromConsLow =
      closeNow <= rangeLow &&
      (rangeLow > 0.0) &&
      (rangeLow - closeNow) >= breakoutDistLow;

   bool freshCrossUp   = mainPrev <= 0.0 && mainNow > 0.0;
   bool freshCrossDown = mainPrev >= 0.0 && mainNow < 0.0;

   // CHANGED per direct instruction, backed by repeated real-chart
   // evidence: entry no longer requires the main-line cross and the
   // breakout to happen on the exact same bar. Real price action often
   // has the cross happen first, then the breakout confirms several
   // bars later - requiring both simultaneously was causing genuine,
   // valid setups to be permanently missed (confirmed directly from
   // multiple live screenshots showing both conditions individually
   // true but no trade taken). Entry now fires whenever a breakout is
   // confirmed AND the main line's CURRENT sign agrees with that
   // direction - the cross itself can have happened on any earlier bar.
   //
   // NEW: each confluence is independently configurable
   // (InpRequireMainLineSignal, InpRequireConsolidationBreakout) - a
   // disabled confluence is simply skipped (treated as automatically
   // satisfied) rather than removed from the AND entirely, so disabling
   // ONE still respects whichever ONE remains enabled. If BOTH are
   // disabled, there would be no requirement left at all and the bot
   // would try to enter on literally every bar - a clear misconfig, so
   // entry is refused entirely in that case rather than doing that.
   bool mainLineCheckBuy  = !InpRequireMainLineSignal || (mainNow > 0.0);
   bool mainLineCheckSell = !InpRequireMainLineSignal || (mainNow < 0.0);
   bool breakoutCheckBuy  = !InpRequireConsolidationBreakout || breakoutFromConsHigh;
   bool breakoutCheckSell = !InpRequireConsolidationBreakout || breakoutFromConsLow;

   bool atLeastOneConfluenceEnabled = InpRequireMainLineSignal || InpRequireConsolidationBreakout;

   mainNowOut      = mainNow;
   rangeHighOut    = rangeHigh;
   rangeLowOut     = rangeLow;
   breakoutUpOut   = breakoutFromConsHigh;
   breakoutDownOut = breakoutFromConsLow;
   macdPosOut      = mainNow > 0.0;   // informational/dashboard display only
   macdNegOut      = mainNow < 0.0;   // informational/dashboard display only
   validBuyOut     = atLeastOneConfluenceEnabled && breakoutCheckBuy  && mainLineCheckBuy;
   validSellOut    = atLeastOneConfluenceEnabled && breakoutCheckSell && mainLineCheckSell;
   freshCrossUpOut   = freshCrossUp;   // kept for reference/logging - no
   freshCrossDownOut = freshCrossDown; // longer required for entry itself
   breakoutDistHighOut = breakoutDistHigh; // same distance used to confirm the breakout -
   breakoutDistLowOut  = breakoutDistLow;  // reused for SL placement, so they can never drift apart

   // Chaos filter: per direct request, pause NEW entries entirely when
   // both a genuine volatility spike and choppy conditions are
   // detected together - the "insane volatility, candles moving all
   // over the place" scenario. This does NOT make the function return
   // false - all the underlying MACD/range data is still valid and
   // worth displaying - it specifically overrides validBuy/validSell
   // to false, blocking only new entries while everything else keeps
   // working normally (including managing an already-open trade).
   chaosActiveOut = false;
   if(InpUseChaosFilter)
   {
      string chaosReason = "";
      if(IsChaosDetected(chaosReason))
      {
         chaosActiveOut = true;
         validBuyOut = false;
         validSellOut = false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
void OnTick()
{
   // --- Live dashboard update, every tick, regardless of bar state ---
   double dMain=0, dResH=0, dResL=0;
   bool dBrkUp=false, dBrkDown=false, dMacdPos=false, dMacdNeg=false, dValidBuy=false, dValidSell=false;
   bool dFreshCrossUp=false, dFreshCrossDown=false;
   double dBreakoutDistHigh=0, dBreakoutDistLow=0;
   string dNotReadyReason = "Waiting for enough bars to calculate the consolidation range.";
   bool dChaosActive = false;
   bool haveConditions = EvaluateConditions(dMain, dResH, dResL, dBrkUp, dBrkDown, dMacdPos, dMacdNeg, dValidBuy, dValidSell, dFreshCrossUp, dFreshCrossDown, dBreakoutDistHigh, dBreakoutDistLow, dNotReadyReason, dChaosActive);

   double livePrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Live MACD preview - shift=0 is the CURRENTLY FORMING bar, updating
   // every tick, unlike the official value above (shift=1, last CLOSED
   // bar only). Shown side by side on the dashboard so "official still
   // positive, live already dipping toward zero" is visible at a glance
   // instead of looking like a discrepancy or a bug.
   double dLiveMain = 0.0;
   GetMACDMain(0, dLiveMain);

   // Always update - even before enough history exists for the full
   // condition set, so the dashboard shows live price/status immediately
   // rather than freezing on the initial "--" placeholders indefinitely.
   UpdateDashboard(haveConditions, dBrkUp, dBrkDown, dMacdPos, dMacdNeg, dValidBuy, dValidSell, livePrice, dMain, dResH, dResL, dFreshCrossUp, dFreshCrossDown, dLiveMain, dBreakoutDistHigh, dBreakoutDistLow, dNotReadyReason, dChaosActive);

   ulong dTicket = 0;
   ENUM_POSITION_TYPE dType = POSITION_TYPE_BUY;
   bool dHasPosition = FindOurPosition(dTicket, dType);
   DrawSRLines(dResH, dResL, haveConditions, dHasPosition, dType);

   // Chaos Scalp trailing + pyramid-add check - deliberately placed
   // HERE, in the every-tick section, not the once-per-bar trading
   // logic below. Per direct request ("quick trailing stop"), this
   // needs genuine tick-level responsiveness - waiting for a full bar
   // close (every 5 minutes on M5) between trail updates would defeat
   // the entire point of a FAST scalping mode. Starting a brand NEW
   // cycle still happens in the bar-gated section below, since the
   // short-term MA direction check is based on closed-bar data anyway
   // and doesn't need tick-level checking.
   if(chaosScalpingActive)
   {
      int dScalpDir = 0;
      datetime dScalpMostRecentTime = 0;
      double dScalpMostRecentPrice = 0.0;
      int dScalpCount = CountScalpPositions(dScalpDir, dScalpMostRecentTime, dScalpMostRecentPrice);

      if(dScalpCount > 0)
      {
         TrailAllScalpPositions();

         double curPriceForPyramid = (dScalpDir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double favorableMove = (dScalpDir == 1) ? (curPriceForPyramid - dScalpMostRecentPrice) : (dScalpMostRecentPrice - curPriceForPyramid);
         double triggerDist = GetPyramidTriggerPoints();

         if(triggerDist > 0.0 && favorableMove >= triggerDist)
            OpenScalpPosition(dScalpDir == 1);
      }
   }

   // --- Trading logic: only acted upon once per new completed bar ---
   datetime completedBarTime = iTime(_Symbol, InpSignalTimeframe, 1);

   if(completedBarTime <= 0 || completedBarTime == lastProcessedBarTime)
      return;

   lastProcessedBarTime = completedBarTime;

   double mainNow = 0.0;
   double mainPrev = 0.0;
   double mainPrevPrev = 0.0;
   double signalNow = 0.0;
   double signalPrev = 0.0;
   double signalPrevPrev = 0.0;

   // BUG FIX, found directly from a real case: the cross marker only
   // ever needs the MAIN line, but was previously gated behind a check
   // that ALSO required the signal line (needed elsewhere, for partial-
   // close) to be available. The signal line needs a longer warm-up
   // period, so if it was ever unavailable on the specific bar where a
   // cross happened - plausible right after attaching to a brand-new
   // symbol - that cross marker was silently skipped forever, since
   // this check only runs once per bar with no way to revisit a missed
   // one. Main-line data is fetched and the marker drawn FIRST, fully
   // decoupled from whatever the signal line's availability turns out
   // to be.
   if(!GetMACDMain(1, mainNow) || !GetMACDMain(2, mainPrev))
      return;

   bool crossUp   = mainPrev <= 0.0 && mainNow > 0.0; // still used for entries below
   bool crossDown = mainPrev >= 0.0 && mainNow < 0.0;

   if(crossUp || crossDown)
   {
      double crossBarHigh = iHigh(_Symbol, InpSignalTimeframe, 1);
      double crossBarLow  = iLow(_Symbol, InpSignalTimeframe, 1);
      DrawCrossMarker(completedBarTime, crossUp, crossBarHigh, crossBarLow);
   }

   // The rest of this bar's trading logic (partial-close, full exit)
   // additionally needs mainPrevPrev and the signal line - checked
   // separately, after the cross marker has already been drawn, so a
   // signal-line data gap can no longer suppress it.
   if(!GetMACDMain(3, mainPrevPrev) ||
      !GetMACDSignal(1, signalNow) || !GetMACDSignal(2, signalPrev) || !GetMACDSignal(3, signalPrevPrev))
      return;

   // Exit signal: is the position CURRENTLY on the wrong side of the
   // MACD's sign - checked fresh every completed bar, not just at the
   // exact moment of transition. A one-shot "did a cross just happen"
   // check has a real gap: if the close attempt ever fails for any
   // reason (broker rejection, requote, connection hiccup), the next
   // bar's "previous vs now" comparison no longer shows a fresh
   // transition (the value already flipped sides one bar earlier), so
   // the exit silently stops triggering and the position is stuck open
   // indefinitely. Checking current alignment every bar is self-healing
   // - a failed close attempt simply retries on the next bar close.

   ulong ticket = 0;
   ENUM_POSITION_TYPE type;
   bool hasPosition = FindOurPosition(ticket, type);

   // CRITICAL FIX: detect a position that was closed EXTERNALLY - by the
   // real, broker-side stop-loss actually being hit, or by the user
   // manually closing it - neither of which goes through this EA's own
   // ClosePosition() call below. Without this check, rangeLocked and
   // partialCloseDone only ever got reset inside the EA's own close
   // path, meaning the very first time a stop-loss was ever hit (a
   // completely normal, expected event), the bot would get permanently
   // stuck comparing price against a stale, outdated consolidation
   // range forever afterward - explaining a real "stops taking trades"
   // pattern reported after live testing.
   if(wasInPositionLastCheck && !hasPosition)
   {
      rangeLocked = false;
      partialCloseDone = false;
      smaSwitchActive = false;
      RetireSmartRangeIfActive();
      SavePersistedState();
      Print("ImprovedMACD: position closed externally (SL hit or manual close) - "
            "resetting range lock so a fresh consolidation range is calculated.");

      double lastClosePrice = 0.0, lastProfit = 0.0;
      if(GetLastClosedDealInfo(lastClosePrice, lastProfit))
         DrawTradeCloseMarker(TimeCurrent(), lastClosePrice, lastProfit);
   }
   wasInPositionLastCheck = hasPosition;

   if(hasPosition)
   {
      // Partial close + breakeven fires FIRST, on the earlier warning
      // (histogram/main-vs-signal turning against the trade) - before
      // the later, full exit signal closes the rest.
      TryPartialCloseAndBreakeven(ticket, type, mainNow, mainPrev, mainPrevPrev, signalNow, signalPrev, signalPrevPrev);

      // SMA-switch exit, per direct request: once floating profit crosses
      // the instrument-appropriate threshold, the FINAL exit basis
      // switches from "MACD main line sign" to "candle closes on the
      // wrong side of the 20 SMA" - a completely separate mechanism from
      // partial-close/breakeven above, which stays untouched either way.
      // Once switched, it stays switched for the rest of this trade,
      // even if profit later dips back below the threshold again.
      double posEntry = PositionGetDouble(POSITION_PRICE_OPEN);
      double curPriceForProfit = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double ptsProfitNow = (type == POSITION_TYPE_BUY) ? (curPriceForProfit - posEntry) : (posEntry - curPriceForProfit);

      if(InpEnableSmaSwitchExit && !smaSwitchActive && ptsProfitNow >= GetSmaSwitchThreshold())
      {
         smaSwitchActive = true;
         SavePersistedState();
      }

      // Full exit: is the position CURRENTLY on the wrong side of the
      // MAIN LINE's sign - checked fresh every completed bar, not just
      // at the exact moment of transition (self-healing: a failed close
      // attempt simply retries on the next bar). This is safe to check
      // unconditionally right after entry, because entry ALSO uses the
      // main line crossing zero - the two share the same signal, so the
      // main line is, by definition, on the correct side at the moment
      // of entry. (An earlier version had entries on a DIFFERENT signal
      // - the histogram - which could contradict this check immediately
      // at entry; that's now resolved by reverting entries to the main
      // line, so no artificial gating is needed here anymore.)
      //
      // UNLESS the SMA-switch above has activated, in which case this
      // check uses the 20 SMA instead - completely replacing the MACD
      // basis for the remainder of this specific trade.
      bool wrongSideBuy, wrongSideSell;

      if(InpEnableSmaSwitchExit && smaSwitchActive)
      {
         double smaNow = 0.0;
         if(GetSmaSwitchValue(1, smaNow))
         {
            double closeNowForSma = iClose(_Symbol, InpSignalTimeframe, 1);
            wrongSideBuy  = (type == POSITION_TYPE_BUY)  && closeNowForSma < smaNow;
            wrongSideSell = (type == POSITION_TYPE_SELL) && closeNowForSma > smaNow;
         }
         else
         {
            // SMA fetch failed this bar - fall back to the main-line
            // check rather than skip the exit check entirely.
            wrongSideBuy  = (type == POSITION_TYPE_BUY)  && mainNow < 0.0;
            wrongSideSell = (type == POSITION_TYPE_SELL) && mainNow > 0.0;
         }
      }
      else
      {
         wrongSideBuy  = (type == POSITION_TYPE_BUY)  && mainNow < 0.0;
         wrongSideSell = (type == POSITION_TYPE_SELL) && mainNow > 0.0;
      }

      if(wrongSideBuy || wrongSideSell)
      {
         ClosePosition(ticket);
         rangeLocked = false;      // trade closed - free to compute a fresh consolidation range again
         partialCloseDone = false; // reset for the next trade
         smaSwitchActive = false;  // reset for the next trade
         RetireSmartRangeIfActive();
         SavePersistedState();
      }
      else
         return; // still correctly aligned, nothing else to evaluate this bar
   }

   // Entry signal: reuse the same evaluation used for the dashboard.
   // Since we're flat at this point (or just closed above), rangeLocked
   // is false, so this computes a FRESH consolidation range - not a
   // stale locked one.
   double eMain=0, eResH=0, eResL=0;
   bool eBrkUp=false, eBrkDown=false, eMacdPos=false, eMacdNeg=false, eValidBuy=false, eValidSell=false;
   bool eFreshCrossUp=false, eFreshCrossDown=false;
   double eBreakoutDistHigh=0, eBreakoutDistLow=0;
   string eNotReadyReason = "";
   bool eChaosActive = false;

   if(!EvaluateConditions(eMain, eResH, eResL, eBrkUp, eBrkDown, eMacdPos, eMacdNeg, eValidBuy, eValidSell, eFreshCrossUp, eFreshCrossDown, eBreakoutDistHigh, eBreakoutDistLow, eNotReadyReason, eChaosActive))
      return; // not enough history yet

   int scalpDirNow = 0;
   datetime scalpMostRecentTime = 0;
   double scalpMostRecentPrice = 0.0;
   int scalpCount = chaosScalpingActive ? CountScalpPositions(scalpDirNow, scalpMostRecentTime, scalpMostRecentPrice) : 0;

   // Per direct design consideration: if chaos clears while scalp
   // positions are still open and winding down, the normal strategy
   // should NOT jump back in immediately - wait until those positions
   // have fully closed out first, avoiding both systems ever holding
   // exposure on the same symbol at the same time.
   if(!FindOurPosition(ticket, type) && scalpCount == 0) // re-check after any close above
   {
      if(eValidBuy)
      {
         // Lock this exact range for the life of the trade - per direct
         // request, the consolidation that broke stays fixed until the
         // trade closes, rather than continuing to recalculate a moving
         // window while a position is open.
         lockedResistance = eResH;
         lockedSupport    = eResL;
         rangeLocked      = true;
         partialCloseDone = false;
         smaSwitchActive  = false;
         SavePersistedState();
         // SL at the THRESHOLD-ADJUSTED level beyond support, per direct
         // request - the same distance used to confirm a breakout on
         // this side (whichever mode, fixed % or ATR-adaptive, is
         // active), applied to the opposite side instead. Gives more
         // room than the raw S/R level alone.
         double buySL = eResL - eBreakoutDistLow;
         OpenPosition(true, buySL);
      }
      else if(eValidSell)
      {
         lockedResistance = eResH;
         lockedSupport    = eResL;
         rangeLocked      = true;
         partialCloseDone = false;
         smaSwitchActive  = false;
         SavePersistedState();
         double sellSL = eResH + eBreakoutDistHigh;
         OpenPosition(false, sellSL);
      }
      else if(chaosScalpingActive && eChaosActive && scalpCount == 0)
      {
         // Starting a NEW Chaos Scalp cycle - per direct request, this
         // branch only reaches here when both the normal strategy has
         // nothing to do (eValidBuy/eValidSell already false, which
         // happens automatically during real chaos) AND no scalp
         // positions are currently open.
         int startDir = 0;
         if(EvaluateScalpDirection(startDir))
            OpenScalpPosition(startDir == 1);
      }
   }
}
//+------------------------------------------------------------------+
