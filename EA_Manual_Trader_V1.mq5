//+------------------------------------------------------------------+
//|                           EA_Manual_Trader_V1.mq5               |
//|  ระบบเทรดมือ + TP/SL + แก้ไม้ + แจ้งเตือนจังหวะ               |
//+------------------------------------------------------------------+
#property copyright "Manual Trader V1"
#property version   "1.0"
#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// INPUT PARAMETERS
//====================================================================

input group "🔑 Magic & Lot"
input int    Inp_Magic         = 111111;    // Magic Number หลัก
input int    Inp_Rescue_Magic  = 222222;    // Magic Number ไม้แก้
input double Inp_BaseLot       = 0.50;      // Lot พื้นฐาน
input bool   Inp_Use_MaxLot    = false;     // เปิด Lot สูงสุด (false= ไม่มีเพดานจำกัด)
input double Inp_MaxLot        = 0.50;      // Lot สูงสุด (ใช้เมื่อ เปิด Use_MaxLot เท่านั้น)

input group "🎯 TP / SL"
input int    Inp_TP_Points     = 0;         // TP fixed (จุด) — 0 = ใช้ Auto แทน
input double Inp_TP_ATR_Mult   = 1.5;      // TP = Auto x ตัวเลขนี้ (ใช้เมือTP ไม่ได้ตั้ง)
input int    Inp_BE_Trigger    = 50;        // เริ่มล็อคทุนเมื่อกำไรถึงกี่จุด (แนะนำ 50)
input int    Inp_Trail_Step    = 20;        // ขยับ SL: เลื่อน SL ตามทุกกี่จุด (0 = ปิด ระยะกันหน้าทุน)

input group "💰 ปิดรวบกำไรสุทธิ"
input bool   Inp_Close_Net     = true;      // ปิดรวบเมื่อกำไรรวมเป็นบวก
input double Inp_Close_Net_THB = 50.0;      // กำไรรวมขั้นต่ำ (บาท) ก่อนปิดรวบ
input double Inp_Rescue_Close_THB = 80.0;   // ปิดรวบเมื่อกำไรรวม+แก้ถึง (บาท)
input double Inp_Rescue_Lot_Mult  = 1.3;    // Martingale คูณ Lot ต่อไม้ (1.0=คงที่, 2.0=x2)
input bool   Inp_Stop_At_Target = true;     // ถึงเป้าปิดกระดานแล้วหยุด Auto+Rescue

input group "🔄 ระยะแก้ไม จำกัดฝั่ง"
input bool   Inp_Use_Rescue       = true;   // เปิดระบบแก้ไม้
input int    Inp_Rescue_MaxCount  = 3;      // จำนวนไม้แก้สูงสุดต่อฝั่ง

input group "🔄 ระยะแก้ไม้แบบเลือกเอง (ระยะแก้ไม้ 1-10)"
input int    Inp_RD1  = 200;   // ระยะแก้ไม้  1 
input int    Inp_RD2  = 400;   // ระยะแก้ไม้  2 
input int    Inp_RD3  = 600;   // ระยะแก้ไม้  3 
input int    Inp_RD4  = 400;   // ระยะแก้ไม้  4 
input int    Inp_RD5  = 500;   // ระยะแก้ไม้  5 
input int    Inp_RD6  = 600;   // ระยะแก้ไม้  6 
input int    Inp_RD7  = 700;   // ระยะแก้ไม้  7 
input int    Inp_RD8  = 800;   // ระยะแก้ไม้  8 
input int    Inp_RD9  = 900;   // ระยะแก้ไม้  9 
input int    Inp_RD10 = 1000;  // ระยะแก้ไม้  10 
input double Inp_RD_ATR_Mult = 1.5; // ระยะแก้ไม้ที่ 11+ ใช้ Autoวิเคราะห์
input group "🔄 ระยะแก้ไม้ (ระยะเดียวตลอด)"
input bool   Inp_Rescue_Single    = false;  // ใช้ระยะเดียวทุกการแก้ไม้
input int    Inp_Rescue_Single_Pts= 300;   // ระยะ แก้ไม้

input group "🔔 แจ้งเตือนจังหวะ"
input bool   Inp_Use_Alert     = true;      // เปิดแจ้งเตือน
input int    Inp_Alert_Cooldown= 300;       // ระหว่างแจ้งเตือน (วินาที)
input int    Inp_EMA_Fast      = 8;         // EMA เร็ว
input int    Inp_EMA_Slow      = 21;        // EMA ช้า
input int    Inp_RSI_Period    = 14;        // RSI Period
input int    Inp_RSI_OB        = 65;        // RSI Overbought
input int    Inp_RSI_OS        = 35;        // RSI Oversold

input group "⚙️ การทำงานระบบ"
input bool   Inp_Hedge_Mode    = false;   // ออก BUY+SELL พร้อมกันได้
input bool   Inp_Net_Close     = true;    // ปิดรวบเมื่อกำไรรวมบวก
input bool   Inp_Max_Order_On  = true;    // จำกัดจำนวนไม้ต่อฝั่ง
input int    Inp_MaxOrderPerSide = 5;     // สูงสุดไม้ต่อฝั่ง (0=ไม่จำกัด)
input bool   Inp_Rescue_Hedge  = true;    // true=แก้สวนฝั่ง (Sell แก้ Buy), false=ฝั่งเดียวกัน

input group "🤖 Auto Trade"
input bool   Inp_Auto_Trade    = true;    // เปิด Auto Trade 
input bool   Inp_AT_One_Side   = true;    // true=ออกทีละฝั่ง (ห้ามมีไม้ค้างถ้าทิศตรงข้าม)
input int    Inp_AT_Cooldown   = 60;      // Auto Trade (วินาที) — ไม่สัญญาณซ้ำในช่วงนี้

input group "📡 ตรวจสอบ การเชื่อมต่อ"
input bool   Inp_Use_ConnCheck  = true;   // เปิดตรวจสอบการเชื่อมต่อ
input int    Inp_ConnCheck_Sec  = 60;     // ตรวจทุกกี่วินาที (แนะนำ 60)
input int    Inp_ConnTimeout_Sec= 120;    // แจ้งเตือนถ้าไม่มี Tick เกินกี่วินาที (แนะนำ 120)

input group "🛡️ เอาตัวรอด (Safety)"
input bool   Inp_Use_Safety    = false;    // เปิดระบบเอาตัวรอด
input double Inp_Max_DD_Side_Pct = 5.0;   // ขาดทุนฝั่งละเกินกี่% ปิดฝั่งนั้น (แนะนำ 3-8)
input double Inp_Max_DD_Total_Pct= 10.0;  // ขาดทุนรวมเกินกี่% ปิดทุกไม้+หยุด EA (แนะนำ 5-15)
input int    Inp_Max_Grid_Hours  = 24;    // Rescue ติด Grid เกินกี่ชม. ปิดฝั่งนั้น (0=ปิด)

input group "📰 News Filter (เช็ดข่าว)"
// ต้องเปิด Allow WebRequest ใน MT5: Tools → Options → Expert Advisors → Add URL
input bool   Inp_Use_News      = false;     // ระบบ ข่าว
input int    Inp_News_Before   = 15;        // หยุดก่อนข่าวกี่นาที
input int    Inp_News_After    = 15;        // รอหลังข่าวกี่นาที
input int    Inp_News_Impact   = 3;         // 1=Low 2=Medium 3=High กรองตั้งแต่ระดับนี้
input int    Inp_News_OffsetH  = 0;         // ปรับเวลาข่าว (ชม.)
input string Inp_News_Currency = "USD";     // สกุลเงินข่าวที่ตรวจ (XAUUSD=USD)

input group "🕐 กรองเวลาเทรด (Session Filter)"
input bool   Inp_Use_Session    = false;    // เปิดกรองเวลาเทรด
input int    Inp_Session_Start  = 8;        // เริ่มเทรด (ชั่วโมง, 0-23)
input int    Inp_Session_End    = 22;       // หยุดเทรด (ชั่วโมง, 0-23)

input group "📊 เช็คสเปรด (Spread Filter)"
input bool   Inp_Use_Spread     = true;     // เปิดเช็คสเปรดก่อนเทรด
input int    Inp_Max_Spread     = 35;       // สเปรดสูงสุดที่ยอมเทรด (จุด) 0=ปิด
input int    Inp_Spread_Cooldown= 300;      // ถ้าสเปรดกว้าง รอกี่วินาทีก่อนเช็คใหม่

//====================================================================
// GLOBAL VARIABLES
//====================================================================
int    h_ema_fast, h_ema_slow, h_rsi, h_atr;
datetime g_last_alert_time     = 0;
datetime g_last_auto_trade_time= 0;   // cooldown แยกสำหรับ Auto Trade
datetime g_last_tick_time      = 0;   // เวลา Tick ล่าสุด
datetime g_last_conn_alert  = 0;   // เวลาแจ้งเตือนหลุดล่าสุด
bool   g_conn_was_lost      = false;
datetime g_last_spread_block= 0;   // เวลาสเปรดกว้างล่าสุด
bool   g_one_click_hedge    = false;   // One-Click Hedge: กดปุ่มเดียว ออก BUY+SELL พร้อมกัน
bool   g_stop_trading       = false;   // true = ถึงเป้าแล้ว หยุด Auto+Rescue
bool   g_safety_triggered    = false;   // true = Safety ทำงานแล้ว หยุด EA
// News Filter globals
struct NewsEvent { datetime time; string title; int impact; };
NewsEvent g_news_events[];
datetime g_last_news_fetch = 0;
string PFX = "MT_";   // prefix ชื่อ object
string GV_CMD  = "MT_CMD_";  // GlobalVariable prefix สำหรับ Remote Command

//====================================================================
// INIT / DEINIT
//====================================================================
int OnInit()
{
   h_ema_fast = iMA(_Symbol, PERIOD_M5, Inp_EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_slow = iMA(_Symbol, PERIOD_M5, Inp_EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   h_rsi      = iRSI(_Symbol, PERIOD_M5, Inp_RSI_Period, PRICE_CLOSE);
   h_atr      = iATR(_Symbol, PERIOD_M5, 14);

   if(h_ema_fast == INVALID_HANDLE || h_ema_slow == INVALID_HANDLE ||
      h_rsi == INVALID_HANDLE || h_atr == INVALID_HANDLE)
   {
      Alert("ไม่สามารถสร้าง Indicator Handles ได้");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(Inp_Magic);
   g_last_tick_time = TimeCurrent();
   if(Inp_Use_ConnCheck)
      EventSetTimer(Inp_ConnCheck_Sec);
   if(Inp_Use_News)
   {
      if(!FetchNewsFromFF())
      {
         string newsErr = "[NEWS] โหลดข่าวไม่ได้! เปิด MT5 -> Tools -> Options -> Expert Advisors -> Allow WebRequest -> Add: https://nfs.faireconomy.media";
         Alert(newsErr);
         Print(newsErr);
      }
   }
   Print("EA:Beast Tamer V1 เริ่มทำงาน");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   // แจ้งเตือนเมื่อ EA หยุด/ถูกถอด (ไม่แจ้งเวลา REASON_PARAMETERS/F7 หรือ REASON_RECOMPILE)
   if(reason != REASON_CHARTCLOSE && reason != REASON_REMOVE &&
      reason != REASON_PARAMETERS && reason != REASON_RECOMPILE)
   {
      string msg = "[EA:Beast Tamer] EAยุดทำงาน! กรุณาตรวจสอบการเชื่อมต่อและการทำงานของEA (Reason:"+(string)reason+")";
      Alert(msg);
      SendNotification(msg);
      Print(msg);
   }
   DeleteAllObjects();
   IndicatorRelease(h_ema_fast);
   IndicatorRelease(h_ema_slow);
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_atr);
}

//====================================================================
// ON TIMER - ตรวจ Connection
//====================================================================
void OnTimer()
{
   if(!Inp_Use_ConnCheck) return;

   datetime now = TimeCurrent();
   int elapsed = (int)(now - g_last_tick_time);

   // ตรวจว่าสัญญาณขาดหายนานเกินไปไหม
   if(elapsed >= Inp_ConnTimeout_Sec)
   {
      // Cooldown กันแจ้งซ้ำ (cooldown = timeout * 2)
      if(now - g_last_conn_alert >= Inp_ConnTimeout_Sec * 2)
      {
         string msg = StringFormat(
            "[EA:Beast Tamer] หลุดการเชื่อมต่อ! "
            "ไม่มี Tick นาน %d วินาที\n"
            "กรุณาตรวจสอบการเชื่อมต่อและการทำงานของEA\n"
            "Symbol: %s | เวลา: %s",
            elapsed, _Symbol, TimeToString(now, TIME_DATE|TIME_MINUTES));
         Alert(msg);
         SendNotification(msg);
         Print(msg);
         g_last_conn_alert = now;
         g_conn_was_lost = true;
         // อัปเดต Panel เตือน
         ObjectSetString(0, PFX+"LBL_STATUS", OBJPROP_TEXT, "!! หลุด CONNECTION !!");
         ObjectSetInteger(0, PFX+"LBL_STATUS", OBJPROP_COLOR, clrRed);
         ChartRedraw();
      }
   }
   else if(g_conn_was_lost)
   {
      // กลับมาแล้ว
      string msg = "[EA:Beast Tamer] เชื่อมต่อกลับมาแล้ว | Symbol: " + _Symbol;
      SendNotification(msg);
      Print(msg);
      g_conn_was_lost = false;
      ObjectSetInteger(0, PFX+"LBL_STATUS", OBJPROP_COLOR, clrSilver);
      ChartRedraw();
   }
}

//====================================================================
// ON TICK
//====================================================================
void OnTick()
{
   g_last_tick_time = TimeCurrent();   // อัปเดต Tick ล่าสุด
   double divider = AccountInfoString(ACCOUNT_CURRENCY) == "USC" ? 100.0 : 1.0;

   // 0. ใส่ TP ให้ order ที่เปิดจาก Mobile หรือมือ (ไม่มี TP)
   ApplyTPSLToNewOrders();

   // 1. Break Even Real-time
   ManageTrailingSL();

   // 2. ปิดรวบเมื่อกำไรรวมบวก
   if(Inp_Net_Close) CheckNetProfitClose(divider);

   // 3. แก้ไม้ Rescue
   if(Inp_Use_Rescue) CheckRescue(divider);

   // 4. แจ้งเตือนจังหวะ + Auto Trade
   if(Inp_Use_Alert)   CheckSignalAlert();
   if(Inp_Auto_Trade)  AutoTradeOnSignal();

   // 5. รับคำสั่งจากระยะไกล (GlobalVariable)
   CheckRemoteCommand();

   // 6. โหลดข่าวใหม่ทุก 6 ชั่วโมง
   if(Inp_Use_News && TimeCurrent() - g_last_news_fetch > 21600)
      FetchNewsFromFF();

   // 7. ระบบเอาตัวรอด — ป้องกันบัญชีระเบิด
   if(Inp_Use_Safety) CheckSurvivalSystem(divider);

}

//====================================================================
// ON CHART EVENT (ปุ่มกด)
//====================================================================

//====================================================================
// AUTO TRADE ตามสัญญาณ EMA Cross — ออก order อัตโนมัติ + TP + BreakEven
//====================================================================
void AutoTradeOnSignal()
{
   // ถึงเป้าแล้วหยุด
   if(Inp_Stop_At_Target && g_stop_trading)
   { Print("[AutoTrade] STOP: ถึงเป้ากำไรแล้ว หยุด Auto Trade"); return; }

   if(Inp_Use_News && IsNewsBlocking())
   { Print("[AutoTrade] STOP: ช่วงข่าว High Impact หยุด Auto Trade"); return; }

   if(Inp_Use_Session && !IsInSession())
   { Print("[AutoTrade] STOP: นอกช่วงเวลาเทรด หยุด Auto Trade"); return; }

   if(Inp_Use_Spread && !IsSpreadOK())
   { Print("[AutoTrade] STOP: สเปรดกว้างเกินไป หยุด Auto Trade"); return; }

   // ใช้ timer แยกต่างหาก ไม่ปนกับ Signal Alert cooldown
   if(TimeCurrent() - g_last_auto_trade_time < Inp_AT_Cooldown) return;

   double ema_fast[], ema_slow[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   if(CopyBuffer(h_ema_fast, 0, 0, 3, ema_fast) < 3) { Print("[AutoTrade] ดึง EMA ไม่ได้"); return; }
   if(CopyBuffer(h_ema_slow, 0, 0, 3, ema_slow) < 3) { Print("[AutoTrade] ดึง EMA ไม่ได้"); return; }

   bool cross_up   = (ema_fast[1] <= ema_slow[1] && ema_fast[0] > ema_slow[0]);
   bool cross_down = (ema_fast[1] >= ema_slow[1] && ema_fast[0] < ema_slow[0]);

   if(!cross_up && !cross_down) return;

   Print(StringFormat("[AutoTrade] เห็น Cross: UP=%s DOWN=%s | EMAfast[0]=%.5f [1]=%.5f | EMAslow[0]=%.5f [1]=%.5f",
         cross_up?"Y":"N", cross_down?"Y":"N",
         ema_fast[0], ema_fast[1], ema_slow[0], ema_slow[1]));

   // One-Side guard
   if(Inp_AT_One_Side)
   {
      if(cross_up  && CountBySideMagic(POSITION_TYPE_SELL, Inp_Magic) > 0)
      { Print("[AutoTrade] บล็อค BUY: มีไม้ SELL ค้าง"); return; }
      if(cross_down && CountBySideMagic(POSITION_TYPE_BUY,  Inp_Magic) > 0)
      { Print("[AutoTrade] บล็อค SELL: มีไม้ BUY ค้าง"); return; }
   }

   g_last_auto_trade_time = TimeCurrent();

   if(cross_up)
   {
      Print("[AutoTrade] → เปิด BUY");
      OpenBuy();
   }
   else if(cross_down)
   {
      Print("[AutoTrade] → เปิด SELL");
      OpenSell();
   }
}

//====================================================================
// HELPER: คำนวณ TP จาก open price — fixed หรือ ATR
// is_buy=true → price + TP_pts, false → price - TP_pts
//====================================================================
double CalcTP(double open_price, bool is_buy)
{
   double tp_pts = 0;
   if(Inp_TP_Points > 0)
   {
      tp_pts = (double)Inp_TP_Points;
   }
   else
   {
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(h_atr, 0, 0, 1, atr_buf) > 0)
         tp_pts = (atr_buf[0] / _Point) * Inp_TP_ATR_Mult;
   }
   if(tp_pts <= 0) return 0;
   if(is_buy)
      return NormalizeDouble(open_price + tp_pts * _Point, _Digits);
   else
      return NormalizeDouble(open_price - tp_pts * _Point, _Digits);
}

//====================================================================
// OPEN ORDERS
//====================================================================
void OpenBuy()
{
   if(Inp_Max_Order_On && Inp_MaxOrderPerSide > 0)
   {
      int cur_b = CountBySideMagic(POSITION_TYPE_BUY, Inp_Magic);
      if(cur_b >= Inp_MaxOrderPerSide) { Print("ไม้ซื้อเต็มแล้ว (",cur_b,"/",Inp_MaxOrderPerSide,")"); return; }
   }
   if(!Inp_Hedge_Mode && CountBySideMagic(POSITION_TYPE_SELL, Inp_Magic) > 0)
   {
      Print("ห้ามสวน: มีไม้ขายค้างอยู่ เปิดโหมดสวนก่อน");
      return;
   }
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tp  = CalcTP(ask, true);
   double lot = SafeLot(Inp_BaseLot);

   trade.SetExpertMagicNumber(Inp_Magic);
   if(trade.Buy(lot, _Symbol, ask, 0, tp, "Manual Buy"))
   {
      DrawArrow(ask, true);
      Print("Manual BUY | Lot=", DoubleToString(lot,2), " TP=", DoubleToString(tp,_Digits));
   }
}

void OpenSell()
{
   if(Inp_Max_Order_On && Inp_MaxOrderPerSide > 0)
   {
      int cur_s = CountBySideMagic(POSITION_TYPE_SELL, Inp_Magic);
      if(cur_s >= Inp_MaxOrderPerSide) { Print("ไม้ขายเต็มแล้ว (",cur_s,"/",Inp_MaxOrderPerSide,")"); return; }
   }
   if(!Inp_Hedge_Mode && CountBySideMagic(POSITION_TYPE_BUY, Inp_Magic) > 0)
   {
      Print("ห้ามสวน: มีไม้ซื้อค้างอยู่ เปิดโหมดสวนก่อน");
      return;
   }
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp  = CalcTP(bid, false);
   double lot = SafeLot(Inp_BaseLot);

   trade.SetExpertMagicNumber(Inp_Magic);
   if(trade.Sell(lot, _Symbol, bid, 0, tp, "Manual Sell"))
   {
      DrawArrow(bid, false);
      Print("Manual SELL | Lot=", DoubleToString(lot,2), " TP=", DoubleToString(tp,_Digits));
   }
}

void OpenBothSides()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = SafeLot(Inp_BaseLot);
   double tp_buy  = CalcTP(ask, true);
   double tp_sell = CalcTP(bid, false);

   trade.SetExpertMagicNumber(Inp_Magic);
   if(trade.Buy(lot, _Symbol, ask, 0, tp_buy, "OCH Buy"))
   {
      DrawArrow(ask, true);
      Print("OCH BUY  | Lot=", DoubleToString(lot,2), " TP=", DoubleToString(tp_buy,_Digits));
   }
   if(trade.Sell(lot, _Symbol, bid, 0, tp_sell, "OCH Sell"))
   {
      DrawArrow(bid, false);
      Print("OCH SELL | Lot=", DoubleToString(lot,2), " TP=", DoubleToString(tp_sell,_Digits));
   }
}

//====================================================================
// CLOSE ORDERS
//====================================================================
void CloseAllOrders()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (PositionGetInteger(POSITION_MAGIC) == Inp_Magic ||
          PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic))
         trade.PositionClose(ticket);
   }
   Print("ปิดทุกไม้แล้ว");
}

void CloseSide(ENUM_POSITION_TYPE side)
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (PositionGetInteger(POSITION_MAGIC) == Inp_Magic ||
          PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic) &&
         PositionGetInteger(POSITION_TYPE) == side)
         trade.PositionClose(ticket);
   }
}

//====================================================================
// ใส่ TP อัตโนมัติให้ order ทุกตัวบน Symbol นี้ที่ยังไม่มี TP
// รองรับ order จาก Mobile / Manual / Script ทุกแหล่ง
//====================================================================
void ApplyTPSLToNewOrders()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double tp = PositionGetDouble(POSITION_TP);
      if(tp != 0) continue;   // มี TP แล้ว ข้ามได้

      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // คำนวณ TP: ถ้า Inp_TP_Points > 0 ใช้ fixed, ถ้า = 0 ใช้ ATR * Mult
      double tp_pts = 0;
      if(Inp_TP_Points > 0)
      {
         tp_pts = (double)Inp_TP_Points;
      }
      else
      {
         double atr_buf[];
         ArraySetAsSeries(atr_buf, true);
         if(CopyBuffer(h_atr, 0, 0, 1, atr_buf) > 0)
            tp_pts = (atr_buf[0] / _Point) * Inp_TP_ATR_Mult;
      }
      if(tp_pts <= 0) continue;

      double new_tp = 0;
      if(type == POSITION_TYPE_BUY)
         new_tp = NormalizeDouble(op + tp_pts * _Point, _Digits);
      else
         new_tp = NormalizeDouble(op - tp_pts * _Point, _Digits);

      if(new_tp == 0) continue;

      if(trade.PositionModify(ticket, sl, new_tp))
         Print("Auto TP set | Ticket=", ticket, " TP=", DoubleToString(new_tp, _Digits));
   }
}

void ManageTrailingSL()
{
   if(Inp_BE_Trigger <= 0) return;   // ปิดฟีเจอร์นี้ทั้งหมด

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool   use_trail = (Inp_Trail_Step > 0);

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double op  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl  = PositionGetDouble(POSITION_SL);
      double tp  = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY)
      {
         double profit_pts = (bid - op) / _Point;
         if(profit_pts < Inp_BE_Trigger) continue;   // ยังไม่ถึง BE trigger

         double new_sl;
         if(use_trail)
         {
            // Trailing: SL = bid - Trail_Step จุด (ตามราคาปัจจุบัน) แต่ไม่ต่ำกว่า op
            double trail_sl = NormalizeDouble(bid - Inp_Trail_Step * _Point, _Digits);
            new_sl = MathMax(trail_sl, NormalizeDouble(op, _Digits));
         }
         else
         {
            new_sl = NormalizeDouble(op, _Digits);   // BE เอย
         }

         // ขยับ SL ขึ้นเท่านั้น ไม่เล่ยลง
         if(sl < new_sl - _Point * 0.5)
            trade.PositionModify(ticket, new_sl, tp);
      }
      else // SELL
      {
         double profit_pts = (op - ask) / _Point;
         if(profit_pts < Inp_BE_Trigger) continue;

         double new_sl;
         if(use_trail)
         {
            // Trailing: SL = ask + Trail_Step จุด แต่ไม่สูงกว่า op
            double trail_sl = NormalizeDouble(ask + Inp_Trail_Step * _Point, _Digits);
            new_sl = MathMin(trail_sl, NormalizeDouble(op, _Digits));
         }
         else
         {
            new_sl = NormalizeDouble(op, _Digits);
         }

         // ขยับ SL ลงเท่านั้น ไม่เลยขึ้น
         if(sl == 0 || sl > new_sl + _Point * 0.5)
            trade.PositionModify(ticket, new_sl, tp);
      }
   }
}

//====================================================================
// ปิดรวบเมื่อกำไรรวมเป็นบวก
//====================================================================
void CheckNetProfitClose(double divider)
{
   double total_usd = 0;
   int total_pos = 0;
   string pos_log = "";

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(mg != Inp_Magic && mg != Inp_Rescue_Magic) continue;

      double pf = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      total_usd += pf;
      total_pos++;
      pos_log += StringFormat("  Ticket=%I64u | Type=%s | Lot=%.2f | Open=%s | Profit=$%.2f\n",
                     ticket,
                     PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?"BUY":"SELL",
                     PositionGetDouble(POSITION_VOLUME),
                     DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),_Digits),
                     pf);
   }

   if(total_pos == 0) return;

   double total_thb = (total_usd / divider) * 32.0;

   if(total_thb >= Inp_Close_Net_THB)
   {
      // --- SAFETY GUARD ---
      if(total_usd <= 0)
      {
         Print(StringFormat("[SAFETY] บล็อกปิดรวบ: total_usd=%.2f (ติดลบหรือศูนย์) แม้ THB=%.2f >= %.2f", total_usd, total_thb, Inp_Close_Net_THB));
         Print(pos_log);
         return;
      }

      // Double-check: รอ 1 วินาทีแล้วเช็คซ้ำว่ากำไรยังเป็นบวกอยู่
      Sleep(1000);
      double recheck_usd = 0;
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         long mg = PositionGetInteger(POSITION_MAGIC);
         if(mg != Inp_Magic && mg != Inp_Rescue_Magic) continue;
         recheck_usd += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
      if(recheck_usd <= 0)
      {
         Print(StringFormat("[SAFETY] บล็อกปิดรวบหลัง Recheck: กำไรเปลี่ยน %.2f -> %.2f", total_usd, recheck_usd));
         return;
      }

      string close_time = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
      string msg = StringFormat("🟢 ปิดรวบทั้งกระดาน %s\nกำไร: $%.2f USD (Recheck: $%.2f)\nเวลา: %s", _Symbol, total_usd, recheck_usd, close_time);
      Alert(msg);
      SendNotification(msg);
      Print(msg);
      Print("[CloseAll] Positions before close:\n" + pos_log);
      CloseAllOrders();

      // ถึงเป้าแล้วหยุดรัน
      if(Inp_Stop_At_Target)
      {
         g_stop_trading = true;
         string stop_msg = "[STOP] ถึงเป้ากำไรแล้ว — Auto Trade + Rescue หยุดทำงาน | ปิดกระดาน " + _Symbol;
         Alert(stop_msg); SendNotification(stop_msg); Print(stop_msg);
      }
   }
}

//====================================================================
// ระบบแก้ไม้ Rescue
//====================================================================
void CheckRescue(double divider)
{
   if(Inp_Use_Session && !IsInSession()) return;
   if(Inp_Use_Spread && !IsSpreadOK()) return;

   // Cooldown ภายในฟังก์ชัน (ไม่ต้อง Global/Input)
   static datetime last_open_sell = 0;
   static datetime last_open_buy  = 0;
   const int RESCUE_COOLDOWN_SEC = 60;   // ห้ามเปิดซ้ำเร็วกว่า 60 วิ

   // เช็คปิดรวบ Rescue
   if(CountByMagic(Inp_Rescue_Magic) > 0)
   {
      // คำนวณกำไรรวม (ไม้หลัก + Rescue)
      double total_usd = 0;
      double rescue_only_usd = 0;
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         long mg = PositionGetInteger(POSITION_MAGIC);
         double pf = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(mg == Inp_Magic || mg == Inp_Rescue_Magic)
            total_usd += pf;
         if(mg == Inp_Rescue_Magic)
            rescue_only_usd += pf;
      }
      double total_thb       = (total_usd / divider) * 32.0;
      double rescue_only_thb = (rescue_only_usd / divider) * 32.0;

      // ปิดรวบเมื่อกำไรรวม (หลัก+Rescue) ถึง threshold
      if(total_thb >= Inp_Rescue_Close_THB)
      {
         // Safety Guard: ห้ามปิดถ้า USD ติดลบ
         if(total_usd <= 0)
         {
            Print(StringFormat("[SAFETY-Rescue] บล็อกปิดรวบ: total_usd=%.2f (ติดลบหรือศูนย์) แม้ THB=%.2f >= %.2f", total_usd, total_thb, Inp_Rescue_Close_THB));
            return;
         }
         // Double-check หลัง Sleep 1 วิ
         Sleep(1000);
         double recheck_usd = 0;
         for(int i=PositionsTotal()-1; i>=0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            long mg = PositionGetInteger(POSITION_MAGIC);
            double pf = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            if(mg == Inp_Magic || mg == Inp_Rescue_Magic)
               recheck_usd += pf;
         }
         if(recheck_usd <= 0)
         {
            Print(StringFormat("[SAFETY-Rescue] บล็อกปิดรวบหลัง Recheck: %.2f -> %.2f", total_usd, recheck_usd));
            return;
         }

         string ct = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
         string msg2 = StringFormat("🟢 ไม้แก้ชนปิดรวบ %s\nกำไรรวม: $%.2f USD (Recheck: $%.2f)\nเวลา: %s", _Symbol, total_usd, recheck_usd, ct);
         Alert(msg2); SendNotification(msg2); Print(msg2);
         CloseAllOrders();

         // ถึงเป้าแล้วหยุดรัน
         if(Inp_Stop_At_Target)
         {
            g_stop_trading = true;
            string stop_msg2 = "[STOP] ถึงเป้ากำไร Rescue แล้ว — Auto Trade + Rescue หยุดทำงาน | ปิดกระดาน " + _Symbol;
            Alert(stop_msg2); SendNotification(stop_msg2); Print(stop_msg2);
         }
         return;
      }

      // ถ้าไม้หลักฝั่งที่ Rescue กำลังแก้หมดแล้ว → ปิด Rescue ทันทีที่กำไร Rescue บวก
      bool main_buy_gone  = (CountBySideMagic(POSITION_TYPE_BUY,  Inp_Magic) == 0);
      bool main_sell_gone = (CountBySideMagic(POSITION_TYPE_SELL, Inp_Magic) == 0);
      bool has_rescue_sell = (CountBySideMagic(POSITION_TYPE_SELL, Inp_Rescue_Magic) > 0);
      bool has_rescue_buy  = (CountBySideMagic(POSITION_TYPE_BUY,  Inp_Rescue_Magic) > 0);

      if((main_buy_gone && has_rescue_sell) || (main_sell_gone && has_rescue_buy))
      {
         if(rescue_only_usd > 0)
         {
            string ct2 = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
            string msg3 = StringFormat("🟡 ไม้หลักปิดไปแล้ว — Rescue บวก ปิดรวบ %s\nกำไร Rescue: $%.2f USD\nเวลา: %s",
                          _Symbol, rescue_only_usd, ct2);
            Alert(msg3); SendNotification(msg3); Print(msg3);
            // ปิดเฉพาะ Rescue
            for(int i=PositionsTotal()-1; i>=0; i--)
            {
               ulong tk = PositionGetTicket(i);
               if(!PositionSelectByTicket(tk)) continue;
               if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
               if(PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic)
                  trade.PositionClose(tk);
            }
            return;
         }
      }
   }

   // นับ + วิเคราะห์ไม้หลัก
   int b_count = 0, s_count = 0;
   double b_vol = 0, s_vol = 0;
   double b_cost = 0, s_cost = 0;
   double b_profit = 0, s_profit = 0;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Inp_Magic) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double op  = PositionGetDouble(POSITION_PRICE_OPEN);
      double pf  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(type == POSITION_TYPE_BUY)
      { b_count++; b_vol += vol; b_cost += op * vol; b_profit += pf; }
      else
      { s_count++; s_vol += vol; s_cost += op * vol; s_profit += pf; }
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Buy ดอย → Rescue Sell (รวมกรณี BUY หลักปิดไปแล้วแต่ Rescue Sell ยังค้าง)
   int rescue_sell_count = CountBySideMagic(POSITION_TYPE_SELL, Inp_Rescue_Magic);
   bool buy_orphan = (b_count == 0 && rescue_sell_count > 0); // ไม้หลัก BUY หมดแต่ Rescue ยังค้าง
   // เพิ่ม: ถ้า BUY หลักหายกำไรแล้ว แต่ Rescue Sell ยังดอยอยู่ → ยังต้องเช็ค rescue ต่อ
   bool buy_recovered_but_rescue_losing = (b_count > 0 && b_profit >= 0 && rescue_sell_count > 0
                                           && GetSideProfit(POSITION_TYPE_SELL, Inp_Rescue_Magic) < 0);
   if((b_count > 0 && b_vol > 0 && b_profit < 0) || buy_orphan || buy_recovered_but_rescue_losing)
   {
      double avg_buy, drag;
      bool use_rescue_drag = buy_orphan || buy_recovered_but_rescue_losing;
      if(b_count > 0 && b_vol > 0 && !use_rescue_drag)
      {
         avg_buy = b_cost / b_vol;
         drag = (avg_buy - bid) / _Point;
      }
      else
      {
         // Orphan / Main recovered: คำนวณ drag จาก Rescue Sell entry
         // ใช้ ask - avg เพราะ Sell ดอยเมื่อราคาขึ้น
         double r_vol = 0, r_cost = 0;
         for(int i=PositionsTotal()-1; i>=0; i--)
         {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Inp_Rescue_Magic) continue;
            if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
            double v = PositionGetDouble(POSITION_VOLUME);
            r_vol += v; r_cost += PositionGetDouble(POSITION_PRICE_OPEN) * v;
         }
         avg_buy = (r_vol > 0) ? r_cost / r_vol : ask;
         // Sell ดอยเมื่อราคาขึ้น → drag = (ask - avg_entry) เป็นบวกเมื่อดอย
         drag = (ask - avg_buy) / _Point;
         if(drag < 0) drag = 0;  // ถ้า Rescue Sell กำไรอยู่ drag = 0
      }
      int rescue_count = rescue_sell_count;
      double need_drag = GetRescueDistance(rescue_count);

      Print(StringFormat("[Rescue SELL] drag=%.0f need=%.0f cnt=%d/%d profit=%.2f orphan=%s",
            drag, need_drag, rescue_count, Inp_Rescue_MaxCount,
            GetSideProfit(POSITION_TYPE_SELL, Inp_Rescue_Magic),
            buy_orphan?"Y":"N"));
      if(rescue_count >= Inp_Rescue_MaxCount)
         Print(StringFormat("[Rescue SELL] BLOCKED: MaxCount ถึงแล้ว (%d/%d)", rescue_count, Inp_Rescue_MaxCount));
      if(drag >= need_drag && rescue_count < Inp_Rescue_MaxCount)
      {
         bool do_open_sell = true;

         if(rescue_count > 0 && GetSideProfit(POSITION_TYPE_SELL, Inp_Rescue_Magic) >= 0)
         { Print("[Rescue SELL] บล็อค: Rescue SELL ยังกำไรอยู่"); do_open_sell = false; }

         if(do_open_sell && Inp_Stop_At_Target && g_stop_trading)
         { Print("[Rescue SELL] STOP: ถึงเป้ากำไรแล้ว หยุด Rescue"); do_open_sell = false; }

         if(do_open_sell && Inp_Use_News && IsNewsBlocking())
         { Print("[Rescue SELL] STOP: ช่วงข่าว High Impact หยุด Rescue"); do_open_sell = false; }

         // --- COOLDOWN ---
         if(do_open_sell)
         {
            int elapsed_s = (int)(TimeCurrent() - last_open_sell);
            if(elapsed_s < RESCUE_COOLDOWN_SEC)
            {
               Print(StringFormat("[Rescue SELL] Cooldown: รออีก %d วิ", RESCUE_COOLDOWN_SEC - elapsed_s));
               do_open_sell = false;
            }
         }

         if(do_open_sell)
         {
            double lot_raw = Inp_BaseLot * MathPow(Inp_Rescue_Lot_Mult, rescue_count);
            double lot = SafeLot(lot_raw);
            Print(StringFormat("[Rescue SELL] เปิดไม้#%d | BaseLot=%.4f Mult=%.1f^%d=%.4f -> lot=%.4f orphan=%s",
                  rescue_count+1, Inp_BaseLot, Inp_Rescue_Lot_Mult, rescue_count, lot_raw, lot,
                  buy_orphan?"Y":"N"));
            trade.SetExpertMagicNumber(Inp_Rescue_Magic);

            if(use_rescue_drag)
            {
               // Orphan / Main recovered: Rescue Sell ดอย → แก้ด้วยฝั่งตรงข้าม (Buy)
               if(Inp_Rescue_Hedge)
               {
                  double r_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double r_tp = CalcTP(r_ask, true);
                  if(trade.Buy(lot, _Symbol, r_ask, 0, r_tp, "Rescue Buy(Orphan) #"+(string)(rescue_count+1)))
                  {
                     DrawArrow(r_ask, true);
                     last_open_buy = TimeCurrent();
                     last_open_sell = TimeCurrent();  // อัปเดต cooldown ทั้งสองฝั่งกัน rapid-fire
                     Print("Rescue Buy(Orphan) #", rescue_count+1, " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag,0));
                  }
               }
               else
               {
                  // Average Up: Rescue Sell ดอย → Sell เพิ่มที่ราคาสูงขึ้น
                  double r_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double r_tp = CalcTP(r_bid, false);
                  if(trade.Sell(lot, _Symbol, r_bid, 0, r_tp, "AvgUp Sell(Orphan) #"+(string)(rescue_count+1)))
                  {
                     DrawArrow(r_bid, false);
                     last_open_sell = TimeCurrent();
                     Print("AvgUp Sell(Orphan) #", rescue_count+1, " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag,0));
                  }
               }
            }
            else
            {
               // Normal: Main BUY ดอย → Rescue
               if(Inp_Rescue_Hedge)
               {
                  // โหมดสวนฝั่ง: Buy ดอย → Sell
                  double r_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double r_tp_sell = CalcTP(r_bid, false);
                  if(trade.Sell(lot, _Symbol, r_bid, 0, r_tp_sell, "Rescue Sell #"+(string)(rescue_count+1)))
                  {
                     DrawArrow(r_bid, false);
                     last_open_sell = TimeCurrent();
                     Print("Rescue Sell #", rescue_count+1, " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag,0));
                  }
               }
               else
               {
                  // โหมด Average Down: Buy ดอย → Buy เพิ่ม
                  double r_ask2 = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double r_tp_buy2 = CalcTP(r_ask2, true);
                  if(trade.Buy(lot, _Symbol, r_ask2, 0, r_tp_buy2, "AvgDown Buy #"+(string)(rescue_count+1)))
                  {
                     DrawArrow(r_ask2, true);
                     last_open_buy = TimeCurrent();
                     Print("AvgDown Buy #", rescue_count+1, " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag,0));
                  }
               }
            }
         }
      }
   }

   // Sell ดอย → Rescue Buy (รวมกรณี SELL หลักปิดไปแล้วแต่ Rescue Buy ยังค้าง)
   int rescue_buy_count = CountBySideMagic(POSITION_TYPE_BUY, Inp_Rescue_Magic);
   bool sell_orphan = (s_count == 0 && rescue_buy_count > 0); // ไม้หลัก SELL หมดแต่ Rescue ยังค้าง
   // เพิ่ม: ถ้า SELL หลักหายกำไรแล้ว แต่ Rescue Buy ยังดอยอยู่ → ยังต้องเช็ค rescue ต่อ
   bool sell_recovered_but_rescue_losing = (s_count > 0 && s_profit >= 0 && rescue_buy_count > 0
                                            && GetSideProfit(POSITION_TYPE_BUY, Inp_Rescue_Magic) < 0);
   if((s_count > 0 && s_vol > 0 && s_profit < 0) || sell_orphan || sell_recovered_but_rescue_losing)
   {
      double avg_sell, drag;
      bool use_rescue_drag_s = sell_orphan || sell_recovered_but_rescue_losing;
      if(s_count > 0 && s_vol > 0 && !use_rescue_drag_s)
      {
         avg_sell = s_cost / s_vol;
         drag = (ask - avg_sell) / _Point;
      }
      else
      {
         // Orphan / Main recovered: คำนวณ drag จาก Rescue Buy entry
         // ใช้ avg - bid เพราะ Buy ดอยเมื่อราคาลง
         double r_vol = 0, r_cost = 0;
         for(int i=PositionsTotal()-1; i>=0; i--)
         {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Inp_Rescue_Magic) continue;
            if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
            double v = PositionGetDouble(POSITION_VOLUME);
            r_vol += v; r_cost += PositionGetDouble(POSITION_PRICE_OPEN) * v;
         }
         avg_sell = (r_vol > 0) ? r_cost / r_vol : bid;
         // Buy ดอยเมื่อราคาลง → drag = (avg_entry - bid) เป็นบวกเมื่อดอย
         drag = (avg_sell - bid) / _Point;
         if(drag < 0) drag = 0;  // ถ้า Rescue Buy กำไรอยู่ drag = 0
      }
      int rescue_count = rescue_buy_count;
      double need_drag = GetRescueDistance(rescue_count);

      Print(StringFormat("[Rescue BUY] drag=%.0f need=%.0f cnt=%d/%d profit=%.2f orphan=%s",
            drag, need_drag, rescue_count, Inp_Rescue_MaxCount,
            GetSideProfit(POSITION_TYPE_BUY, Inp_Rescue_Magic),
            sell_orphan?"Y":"N"));
      if(rescue_count >= Inp_Rescue_MaxCount)
         Print(StringFormat("[Rescue BUY] BLOCKED: MaxCount ถึงแล้ว (%d/%d)", rescue_count, Inp_Rescue_MaxCount));
      if(drag >= need_drag && rescue_count < Inp_Rescue_MaxCount)
      {
         bool do_open_buy = true;

         if(rescue_count > 0 && GetSideProfit(POSITION_TYPE_BUY, Inp_Rescue_Magic) >= 0)
         { Print("[Rescue BUY] บล็อค: Rescue BUY ยังกำไรอยู่"); do_open_buy = false; }

         if(do_open_buy && Inp_Stop_At_Target && g_stop_trading)
         { Print("[Rescue BUY] STOP: ถึงเป้ากำไรแล้ว หยุด Rescue"); do_open_buy = false; }

         if(do_open_buy && Inp_Use_News && IsNewsBlocking())
         { Print("[Rescue BUY] STOP: ช่วงข่าว High Impact หยุด Rescue"); do_open_buy = false; }

         // --- COOLDOWN ---
         if(do_open_buy)
         {
            int elapsed_b = (int)(TimeCurrent() - last_open_buy);
            if(elapsed_b < RESCUE_COOLDOWN_SEC)
            {
               Print(StringFormat("[Rescue BUY] Cooldown: รออีก %d วิ", RESCUE_COOLDOWN_SEC - elapsed_b));
               do_open_buy = false;
            }
         }

         if(do_open_buy)
         {
            double lot_raw = Inp_BaseLot * MathPow(Inp_Rescue_Lot_Mult, rescue_count);
            double lot = SafeLot(lot_raw);
            Print(StringFormat("[Rescue BUY] เปิดไม้#%d | BaseLot=%.4f Mult=%.1f^%d=%.4f -> lot=%.4f orphan=%s",
                  rescue_count+1, Inp_BaseLot, Inp_Rescue_Lot_Mult, rescue_count, lot_raw, lot,
                  sell_orphan?"Y":"N"));

            trade.SetExpertMagicNumber(Inp_Rescue_Magic);

            if(use_rescue_drag_s)
            {
               // Orphan / Main recovered: Rescue Buy ดอย → แก้ด้วยฝั่งตรงข้าม (Sell)
               if(Inp_Rescue_Hedge)
               {
                  double r_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double r_tp = CalcTP(r_bid, false);
                  if(trade.Sell(lot, _Symbol, r_bid, 0, r_tp, "Rescue Sell(Orphan) #"+(string)(rescue_count+1)))
                  {
                     DrawArrow(r_bid, false);
                     last_open_sell = TimeCurrent();
                     last_open_buy = TimeCurrent();   // อัปเดต cooldown ทั้งสองฝั่งกัน rapid-fire
                     Print("Rescue Sell(Orphan) #", rescue_count+1, " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag,0));
                  }
               }
               else
               {
                  // Average Down: Rescue Buy ดอย → Buy เพิ่มที่ราคาต่ำลง
                  double r_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double r_tp = CalcTP(r_ask, true);
                  if(trade.Buy(lot, _Symbol, r_ask, 0, r_tp, "AvgDown Buy(Orphan) #"+(string)(rescue_count+1)))
                  {
                     DrawArrow(r_ask, true);
                     last_open_buy = TimeCurrent();
                     Print("AvgDown Buy(Orphan) #", rescue_count+1, " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag,0));
                  }
               }
            }
            else
            {
               // Normal: Main SELL ดอย → Rescue
               if(Inp_Rescue_Hedge)
               {
                  // โหมดสวนฝั่ง: Sell ดอย → Buy
                  double r_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double r_tp_buy = CalcTP(r_ask, true);
                  if(trade.Buy(lot, _Symbol, r_ask, 0, r_tp_buy, "Rescue Buy #"+(string)(rescue_count+1)))
                  {
                     DrawArrow(r_ask, true);
                     last_open_buy = TimeCurrent();
                     Print("Rescue Buy #", rescue_count+1, " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag,0));
                  }
               }
               else
               {
                  // โหมด Average Down: Sell ดอย → Sell เพิ่ม
                  double r_bid2 = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double r_tp_sell2 = CalcTP(r_bid2, false);
                  if(trade.Sell(lot, _Symbol, r_bid2, 0, r_tp_sell2, "AvgDown Sell #"+(string)(rescue_count+1)))
                  {
                     DrawArrow(r_bid2, false);
                     last_open_sell = TimeCurrent();
                     Print("AvgDown Sell #", rescue_count+1, " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag,0));
                  }
               }
            }
         }
      }
   }
}

//====================================================================
// คำนวณระยะแก้ไม้ตาม Level
//====================================================================
double GetRescueDistance(int rescue_count)
{
   // Single Mode: ใช้ระยะเดียวตลอด
   if(Inp_Rescue_Single)
      return (double)Inp_Rescue_Single_Pts;

   // Grid Mode: Level 1-10 กำหนดเอง
   int grid_pts[10];
   grid_pts[0] = Inp_RD1;
   grid_pts[1] = Inp_RD2;
   grid_pts[2] = Inp_RD3;
   grid_pts[3] = Inp_RD4;
   grid_pts[4] = Inp_RD5;
   grid_pts[5] = Inp_RD6;
   grid_pts[6] = Inp_RD7;
   grid_pts[7] = Inp_RD8;
   grid_pts[8] = Inp_RD9;
   grid_pts[9] = Inp_RD10;

   // Level 1-10: ใช้ค่าที่กำหนด
   // rescue_count = จำนวนไม้ที่เปิดไปแล้ว (0 = ยังไม่มี → Level 1)
   if(rescue_count < 10)
      return (double)grid_pts[rescue_count];

   // Level 11+: คำนวณจาก ATR
   double atr_val[];
   ArraySetAsSeries(atr_val, true);
   if(CopyBuffer(h_atr, 0, 0, 1, atr_val) > 0)
      return (atr_val[0] / _Point) * Inp_RD_ATR_Mult;

   // fallback ถ้าดึง ATR ไม่ได้
   return (double)Inp_RD10;
}

//====================================================================
// แจ้งเตือนจังหวะ Buy / Sell + TP แนะนำ
//====================================================================
void CheckSignalAlert()
{
   if(TimeCurrent() - g_last_alert_time < Inp_Alert_Cooldown) return;

   double ema_fast[], ema_slow[], rsi_val[], atr_val[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   ArraySetAsSeries(rsi_val, true);
   ArraySetAsSeries(atr_val, true);

   if(CopyBuffer(h_ema_fast, 0, 0, 3, ema_fast) < 3) return;
   if(CopyBuffer(h_ema_slow, 0, 0, 3, ema_slow) < 3) return;
   if(CopyBuffer(h_rsi,      0, 0, 2, rsi_val)  < 2) return;
   if(CopyBuffer(h_atr,      0, 0, 2, atr_val)  < 2) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = atr_val[0];
   double tp_suggest = atr * 1.5 / _Point;   // TP แนะนำ = 1.5 ATR
   double sl_suggest = atr * 1.0 / _Point;   // SL แนะนำ = 1.0 ATR
   double rsi = rsi_val[0];

   // EMA Cross ขึ้น (EMA fast ผ่าน EMA slow ขึ้น)
   bool ema_cross_up   = (ema_fast[1] <= ema_slow[1] && ema_fast[0] > ema_slow[0]);
   // EMA Cross ลง
   bool ema_cross_down = (ema_fast[1] >= ema_slow[1] && ema_fast[0] < ema_slow[0]);

   // เทรนด์ขึ้น = EMA fast > EMA slow
   bool trend_up   = (ema_fast[0] > ema_slow[0]);
   bool trend_down = (ema_fast[0] < ema_slow[0]);

   // สัญญาณ BUY: EMA cross ขึ้น หรือ RSI Oversold + เทรนด์ขึ้น
   bool signal_buy  = (ema_cross_up)  || (rsi <= Inp_RSI_OS && trend_up);
   // สัญญาณ SELL: EMA cross ลง หรือ RSI Overbought + เทรนด์ลง
   bool signal_sell = (ema_cross_down) || (rsi >= Inp_RSI_OB && trend_down);

   string reason = "";
   if(signal_buy)
   {
      reason = ema_cross_up ? "ออกออเดอร์ BUY" : "สัญญาณ RSI Oversold "+(string)(int)rsi;
      string msg = StringFormat("📊 BUY %s\nเหตุ: %s\nราคา: %s\nTP: +%d จุด | SL: -%d จุด",
                     _Symbol, reason, DoubleToString(ask, _Digits), (int)tp_suggest, (int)sl_suggest);
      Alert(msg);
      SendNotification(msg);
      DrawSignalArrow(ask, true, "ซื้อ:"+reason);
      g_last_alert_time = TimeCurrent();
      Print(msg);
   }
   else if(signal_sell)
   {
      reason = ema_cross_down ? "ออกออเดอร์ SELL" : "สัญญาณ RSI Overbought "+(string)(int)rsi;
      string msg = StringFormat("📊 SELL %s\nเหตุ: %s\nราคา: %s\nTP: +%d จุด | SL: -%d จุด",
                     _Symbol, reason, DoubleToString(bid, _Digits), (int)tp_suggest, (int)sl_suggest);
      Alert(msg);
      SendNotification(msg);
      DrawSignalArrow(bid, false, "ขาย:"+reason);
      g_last_alert_time = TimeCurrent();
      Print(msg);
   }
}


string GetSignalText()
{
   double ema_fast[], ema_slow[], rsi_val[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   ArraySetAsSeries(rsi_val, true);

   if(CopyBuffer(h_ema_fast, 0, 0, 2, ema_fast) < 2) return "--";
   if(CopyBuffer(h_ema_slow, 0, 0, 2, ema_slow) < 2) return "--";
   if(CopyBuffer(h_rsi,      0, 0, 2, rsi_val)  < 2) return "--";

   double rsi = rsi_val[0];
   bool trend_up   = (ema_fast[0] > ema_slow[0]);
   bool trend_down = (ema_fast[0] < ema_slow[0]);
   bool cross_up   = (ema_fast[1] <= ema_slow[1] && ema_fast[0] > ema_slow[0]);
   bool cross_down = (ema_fast[1] >= ema_slow[1] && ema_fast[0] < ema_slow[0]);

   if(cross_up  || (rsi <= Inp_RSI_OS && trend_up))   return "▲ BUY (RSI:"+DoubleToString(rsi,0)+")";
   if(cross_down|| (rsi >= Inp_RSI_OB && trend_down)) return "▼ SELL (RSI:"+DoubleToString(rsi,0)+")";
   if(trend_up)   return "~ Uptrend (RSI:"+DoubleToString(rsi,0)+")";
   if(trend_down) return "~ Downtrend (RSI:"+DoubleToString(rsi,0)+")";
   return "-- Neutral";
}

//====================================================================
// ลูกศร Buy / Sell บนกราฟ
//====================================================================
void DrawArrow(double price, bool is_buy)
{
   static int arrow_count = 0;
   arrow_count++;
   string name = PFX + (is_buy ? "ARR_BUY_" : "ARR_SELL_") + IntegerToString(arrow_count);
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, is_buy ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, is_buy ? clrDodgerBlue : clrTomato);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, is_buy ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ChartRedraw();
}

void DrawSignalArrow(double price, bool is_buy, string label)
{
   static int sig_count = 0;
   sig_count++;
   string name = PFX + (is_buy ? "SIG_BUY_" : "SIG_SELL_") + IntegerToString(sig_count);
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, is_buy ? 241 : 242);
   ObjectSetInteger(0, name, OBJPROP_COLOR, is_buy ? clrLime : clrMagenta);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, is_buy ? ANCHOR_TOP : ANCHOR_BOTTOM);

   // ป้ายกำกับ
   string lname = name + "_LBL";
   ObjectCreate(0, lname, OBJ_TEXT, 0, TimeCurrent(), price);
   ObjectSetString( 0, lname, OBJPROP_TEXT, label);
   ObjectSetInteger(0, lname, OBJPROP_COLOR, is_buy ? clrLime : clrMagenta);
   ObjectSetInteger(0, lname, OBJPROP_FONTSIZE, 8);
   ChartRedraw();
}

//====================================================================
// REMOTE COMMAND via GlobalVariable
// Script บน Mobile/VPS ตั้งค่า GlobalVariable แล้ว EA อ่านทุก Tick
// GV Name: MT_CMD_<Symbol>  |  ค่า: 1=BUY, 2=SELL, 3=BUY+SELL, 4=CLOSE ALL
//====================================================================
void CheckRemoteCommand()
{
   string gv = GV_CMD + _Symbol;
   if(!GlobalVariableCheck(gv)) return;

   int cmd = (int)GlobalVariableGet(gv);
   if(cmd == 0) return;

   GlobalVariableSet(gv, 0);   // reset ทันทีเพื่อไม่ให้ fire ซ้ำ

   if(cmd == 1)
   {
      Print("[Remote] BUY");
      OpenBuy();
   }
   else if(cmd == 2)
   {
      Print("[Remote] SELL");
      OpenSell();
   }
   else if(cmd == 3)
   {
      Print("[Remote] BUY+SELL");
      OpenBothSides();
   }
   else if(cmd == 4)
   {
      Print("[Remote] CLOSE ALL");
      CloseAllOrders();
   }
}

//====================================================================
// UTILITY FUNCTIONS
//====================================================================
double SafeLot(double lot)
{
   double step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double min_v = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_v = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lot = MathMax(lot, min_v);
   if(Inp_Use_MaxLot)
      lot = MathMin(lot, MathMin(max_v, Inp_MaxLot));
   else
      lot = MathMin(lot, max_v);
   int d = 2;
   if(step <= 0.0001) d = 4;
   else if(step <= 0.001) d = 3;
   return NormalizeDouble(MathCeil(lot / step) * step, d);
}

int CountByMagic(int magic)
{
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == magic)
         count++;
   }
   return count;
}

int CountBySideMagic(ENUM_POSITION_TYPE side, int magic)
{
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetInteger(POSITION_TYPE) == side)
         count++;
   }
   return count;
}

double GetSideProfit(ENUM_POSITION_TYPE side, int magic)
{
   double profit = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetInteger(POSITION_TYPE) == side)
         profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return profit;
}

void DeleteAllObjects()
{
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, PFX) == 0)
         ObjectDelete(0, name);
   }
   ChartRedraw();
}

//====================================================================
// NEWS FILTER (ForexFactory API)
//====================================================================
bool FetchNewsFromFF()
{
   string url = "https://nfs.faireconomy.media/ff_calendar_thisweek.xml";
   char data[], result[];
   string headers;
   int res = WebRequest("GET", url, headers, 5000, data, result, headers);
   if(res != 200)
   {
      Print("[News] Fetch failed, HTTP=", res);
      return false;
   }
   string xml = CharArrayToString(result);
   if(StringLen(xml) < 100)
   {
      Print("[News] Empty response");
      return false;
   }
   ParseNewsXML(xml);
   g_last_news_fetch = TimeCurrent();
   Print("[News] Loaded ", ArraySize(g_news_events), " events");
   return true;
}

void ParseNewsXML(string xml)
{
   ArrayResize(g_news_events, 0);
   int pos = 0;
   while((pos = StringFind(xml, "<event>", pos)) != -1)
   {
      int endPos = StringFind(xml, "</event>", pos);
      if(endPos == -1) break;
      string block = StringSubstr(xml, pos, endPos - pos + 8);

      string country = GetXMLTagValue(block, "country");
      string impactStr = GetXMLTagValue(block, "impact");
      string dateStr = GetXMLTagValue(block, "date");
      string timeStr = GetXMLTagValue(block, "time");
      string title = GetXMLTagValue(block, "title");

      if(Inp_News_Currency != "" && StringFind(country, Inp_News_Currency) == -1)
      { pos = endPos + 8; continue; }

      int impact = 0;
      if(impactStr == "High") impact = 3;
      else if(impactStr == "Medium") impact = 2;
      else if(impactStr == "Low") impact = 1;

      if(impact < Inp_News_Impact)
      { pos = endPos + 8; continue; }

      datetime evtTime = ParseFFDateTime(dateStr, timeStr);
      if(evtTime == 0)
      { pos = endPos + 8; continue; }

      int idx = ArraySize(g_news_events);
      ArrayResize(g_news_events, idx + 1);
      g_news_events[idx].time = evtTime;
      g_news_events[idx].title = title;
      g_news_events[idx].impact = impact;

      pos = endPos + 8;
   }
}

string GetXMLTagValue(string block, string tag)
{
   string openTag = "<" + tag + ">";
   string closeTag = "</" + tag + ">";
   int start = StringFind(block, openTag);
   if(start == -1) return "";
   start += StringLen(openTag);

   if(StringSubstr(block, start, 9) == "<![CDATA[")
   {
      start += 9;
      int cdataEnd = StringFind(block, "]]>", start);
      if(cdataEnd == -1) return "";
      return StringSubstr(block, start, cdataEnd - start);
   }

   int end = StringFind(block, closeTag, start);
   if(end == -1) return "";
   return StringSubstr(block, start, end - start);
}

datetime ParseFFDateTime(string dateStr, string timeStr)
{
   if(StringLen(dateStr) < 8 || StringLen(timeStr) < 3) return 0;
   if(StringFind(timeStr, "All") != -1) return 0;

   int slash1 = StringFind(dateStr, "/");
   int slash2 = StringFind(dateStr, "/", slash1 + 1);
   if(slash1 == -1 || slash2 == -1) return 0;

   int mon = (int)StringToInteger(StringSubstr(dateStr, 0, slash1));
   int day = (int)StringToInteger(StringSubstr(dateStr, slash1 + 1, slash2 - slash1 - 1));
   int year = (int)StringToInteger(StringSubstr(dateStr, slash2 + 1));

   StringToLower(timeStr);
   int colon = StringFind(timeStr, ":");
   if(colon == -1) return 0;

   int hour = (int)StringToInteger(StringSubstr(timeStr, 0, colon));

   string minPart = StringSubstr(timeStr, colon + 1);
   int amPos = StringFind(minPart, "am");
   int pmPos = StringFind(minPart, "pm");
   if(amPos == -1 && pmPos == -1) return 0;

   bool isPM = (pmPos != -1);
   if(amPos != -1) minPart = StringSubstr(minPart, 0, amPos);
   else if(pmPos != -1) minPart = StringSubstr(minPart, 0, pmPos);

   int min = (int)StringToInteger(minPart);

   if(isPM && hour != 12) hour += 12;
   if(!isPM && hour == 12) hour = 0;

   hour += Inp_News_OffsetH;

   MqlDateTime dt;
   dt.year = year;
   dt.mon = mon;
   dt.day = day;
   dt.hour = hour;
   dt.min = min;
   dt.sec = 0;

   while(dt.hour >= 24) { dt.hour -= 24; dt.day++; }
   while(dt.hour < 0) { dt.hour += 24; dt.day--; }

   return StructToTime(dt);
}

double GetTotalSideProfit(ENUM_POSITION_TYPE side)
{
   double profit = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (PositionGetInteger(POSITION_MAGIC) == Inp_Magic ||
          PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic) &&
         PositionGetInteger(POSITION_TYPE) == side)
         profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return profit;
}

void CheckSurvivalSystem(double divider)
{
   if(g_safety_triggered) return;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity <= 0 || balance <= 0) return;

   // --- 1. ตรวจสอบ Drawdown รวม ---
   double total_dd_pct = (balance - equity) / balance * 100.0;
   if(total_dd_pct >= Inp_Max_DD_Total_Pct)
   {
      string msg = StringFormat("[SAFETY] DD รวม %.1f%% เกิน %.1f%% — ปิดทุกไม้ + หยุด EA", total_dd_pct, Inp_Max_DD_Total_Pct);
      Alert(msg); Print(msg);
      CloseAllOrders();
      g_safety_triggered = true;
      g_stop_trading = true;
      return;
   }

   // --- 2. ตรวจสอบ Drawdown แต่ละฝั่ง ---
   double buy_profit  = GetTotalSideProfit(POSITION_TYPE_BUY);
   double sell_profit = GetTotalSideProfit(POSITION_TYPE_SELL);
   double buy_dd_pct  = buy_profit  < 0 ? MathAbs(buy_profit)  / equity * 100.0 : 0;
   double sell_dd_pct = sell_profit < 0 ? MathAbs(sell_profit) / equity * 100.0 : 0;

   if(buy_dd_pct >= Inp_Max_DD_Side_Pct)
   {
      string msg = StringFormat("[SAFETY] BUY DD %.1f%% เกิน %.1f%% — ปิดฝั่ง BUY", buy_dd_pct, Inp_Max_DD_Side_Pct);
      Alert(msg); Print(msg);
      CloseSide(POSITION_TYPE_BUY);
      return;
   }
   if(sell_dd_pct >= Inp_Max_DD_Side_Pct)
   {
      string msg = StringFormat("[SAFETY] SELL DD %.1f%% เกิน %.1f%% — ปิดฝั่ง SELL", sell_dd_pct, Inp_Max_DD_Side_Pct);
      Alert(msg); Print(msg);
      CloseSide(POSITION_TYPE_SELL);
      return;
   }

   // --- 3. ตรวจสอบเวลาติด Grid (Rescue) ---
   if(Inp_Max_Grid_Hours > 0)
   {
      datetime now = TimeCurrent();
      int max_sec = Inp_Max_Grid_Hours * 3600;
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) &&
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic)
         {
            datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
            if(now - open_time > max_sec)
            {
               ENUM_POSITION_TYPE side = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               string msg = StringFormat("[SAFETY] Rescue %s ติด Grid เกิน %d ชม. — ปิดฝั่ง", (side==POSITION_TYPE_BUY?"BUY":"SELL"), Inp_Max_Grid_Hours);
               Alert(msg); Print(msg);
               CloseSide(side);
               return;
            }
         }
      }
   }
}

bool IsNewsBlocking()
{
   if(!Inp_Use_News || ArraySize(g_news_events) == 0) return false;

   datetime now = TimeCurrent();
   int beforeSec = Inp_News_Before * 60;
   int afterSec = Inp_News_After * 60;

   for(int i = 0; i < ArraySize(g_news_events); i++)
   {
      datetime evt = g_news_events[i].time;
      if(now >= evt - beforeSec && now <= evt + afterSec)
      {
         Print(StringFormat("[News] BLOCK: %s | Impact=%d | EventTime=%s",
            g_news_events[i].title, g_news_events[i].impact, TimeToString(evt)));
         return true;
      }
   }
   return false;
}

bool IsInSession()
{
   if(!Inp_Use_Session) return true;

   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int hour = dt.hour;

   if(Inp_Session_Start < Inp_Session_End)
      return (hour >= Inp_Session_Start && hour < Inp_Session_End);
   else  // ข้ามคืน (เช่น Start=22, End=6)
      return (hour >= Inp_Session_Start || hour < Inp_Session_End);
}

bool IsSpreadOK()
{
   if(!Inp_Use_Spread || Inp_Max_Spread <= 0) return true;

   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
   {
      spread = (long)((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point);
   }

   if(spread > Inp_Max_Spread)
   {
      datetime now = TimeCurrent();
      if(now - g_last_spread_block > 60)
      {
         Print(StringFormat("[SPREAD] กว้างเกินไป: %d จุด (max=%d) — หยุดเปิดไม้ชั่วคราว", (int)spread, Inp_Max_Spread));
         g_last_spread_block = now;
      }
      return false;
   }
   return true;
}
