//+------------------------------------------------------------------+
//|                                  EA:Beast Tamer (ผู้คุมอสูร) V.1.5 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "EA:Beast Tamer (ผู้คุมอสูร)"
#property version   "1.5"
#property strict "LINE @465rwlcf ผู้สนับสุนหลัก KVB Thailand"

#include <Trade\Trade.mqh>
CTrade trade;

enum ENUM_EXIT_MODE {
   Money_Target,  // ปิดตามเป้ากำไร (บาท)
   Point_Target,  // ปิดตามระยะจุด (TP Points) รายฝั่ง
   Basket_TP      // รวบปิดทั้งพอร์ต (เมื่อกำไรเฉลี่ยรวมทุกไม้ถึงจุด)
};

input group "🚪 โหมดปิดรวบกำไร"
enum ENUM_FORCE_CLOSE_MODE {
   CLOSE_OFF,        // ปิดระบบ (ทำงานแบบเดิม)
   CLOSE_BY_PROFIT,  // กำไร > X ปิดทันที
   CLOSE_BY_BASKET   // ใช้ (TP/Points)
};

input ENUM_FORCE_CLOSE_MODE Inp_Force_Close_Mode = CLOSE_BY_PROFIT; //ระบบปิดออเดอร์แบบบังคับ
input double Inp_Force_Close_THB = 5.0; //กำไรเป้าหมาย (บาท) ที่จะปิดไม้ (เซฟ=5)
input int    Inp_Force_Close_Velocity = 3; //ความเร็ว/ความแรงของการปิด

//====================================================================
// VISUAL DEFINITIONS (โทนสีเสริมดวง วันพุธกลางคืน)
//====================================================================
#define BRT "BEAST_"
#define PANEL_X 20
#define PANEL_Y 20
#define PANEL_W 270
#define HDR_H   35
#define ROW_H   22
#define PAD     10

#define CLR_PANEL_BG    C'15,10,25'     // ม่วงเข้มเกือบดำ
#define CLR_HEADER_BG    C'60,35,85'     // ม่วงเข้ม
#define CLR_LABEL        C'176,179,184'  // เงินสว่าง
#define CLR_VALUE        C'248,249,250'  // ขาวบริสุทธิ์
#define CLR_PURPLE_L    C'142,68,173'   // ม่วงอเมทิสต์
#define CLR_GOLD         C'212,175,55'   // ทอง
#define CLR_PROFIT       clrLime
#define CLR_LOSS         C'231,76,60'    // แดงมะเขือเทศ

// --- [กลุ่มที่ 1: ระบบควบคุมการปิดกำไร] ---
input group "🔑 ระบบยืนยันสิทธิ์ (License)"
input long   Inp_Account   = 0;          // กรอกเลขบัญชีที่แจ้งแอดมิน
input string Inp_SerialKey = "รหัสKey"; // กรอกรหัส Serial Key

// --- [กลุ่มที่ 2: ระบบควบคุมการปิดกำไร] ---
input group "🕹️ การตั้งค่าหลัก"
input double Inp_BaseLot = 0.01;   // ล็อตเริ่มต้น
input double lastLot = 0.01;             // ล็อตล่าสุด
input double Inp_Lot_Multiplier  = 1.00;   // ตัวคูณแก้ไม้ (เซฟ=1.00 คงที่ 0.01)
input int    Inp_Magic           = 888888; // รหัสอ้างอิงออเดอร์

// --- [กลุ่มที่ 3: ระบบควบคุมการปิดกำไร] ---
input group "⏰ ระบบเวลาไทย (Thai Time Window)"
input bool   Inp_Use_Time_Filter = true;      // เปิดระบบคุมเวลาเปิด-ปิด
input int    Inp_Start_Hour_TH   = 9;        // เวลาเริ่มรัน (ชั่วโมง - ไทย)
input int    Inp_End_Hour_TH     = 19;        // เวลาหยุดรัน (ชั่วโมง - ไทย)


// --- [กลุ่มที่ 3: ระบบควบคุมการปิดกำไร] ---
input group "🎯 ระบบเป้าหมาย (USC)"
input bool   Inp_Use_Daily_Lock  = false;      // เปิดระบบล็อคเป้ากำไรรายวัน
input double Inp_Daily_Target_USC = 500.0;    // เป้ากำไร (เซนต์) ต่อวัน
input bool   Inp_Close_And_Stop  = false;      // ถึงเป้าแล้วปิดทุกไม้และหยุดรัน


// --- [กลุ่มที่ 4: ระบบควบคุมการปิดกำไร] ---
input group "💰 ระบบปิดกำไร (Exit Strategy)"
input ENUM_EXIT_MODE Inp_Exit_Mode = Basket_TP; // โหมดการทำงาน
input double Inp_Target_THB        = 30.0;        // เป้ากำไรรายฝั่ง (บาท) (เซฟ=30)
input int    Inp_Target_Points     = 500;         // TP
input double Inp_Min_Profit_THB    = 10.0;         // กำไรขั้นต่ำที่เป็นบาท
input bool   Inp_Close_All_When_Green = true;      // เมื่อ Buy/Sell เขียว ปิดทั้งกระดาน
input double Inp_Close_All_Min_Profit_THB = 0.0;   // กำไรขั้นต่ำต่อฝั่งสำหรับปิดทั้งกระดาน
input bool   Inp_Close_When_Net_Profit = true;     // ปิดรวบทั้งกระดานเมื่อกำไรรวมเป็นบวก (ไม่สนฝั่ง)

// --- [กลุ่มที่ 5: ระบบปิดกำไรแบบรวดเร็ว ---
input group "💰 ระบบปิดกำไรแบบรวดเร็ว"
input bool   Inp_Quick_Scalp       = true;         // ปิดไวเมื่อถูกทาง (กรณีมีไม้เดียว)
input bool   Inp_Clear_Winner_Side = true;         // ฝั่งไหนกำไร รวบปิดฝั่งนั้นทันที
input bool   Inp_Nuke_Board        = false;        // ล้างกระดานทั้งพอร์ต ถ้าฝั่งใดฝั่งหนึ่งกำไร
input bool   Inp_Use_AI_Exit       = true;        // AI เมือกราฟนิ่งรวบปิด
input bool    Inp_Use_Survivor   = true;   // ระบบเอาตัวรอด
input bool    Inp_Cross_Survivor     = true;   // ตัดดอยข้ามฝั่ง (Buy ตัด Sell / Sell ตัด Buy)
input double  Inp_Survivor_Clear_THB = 5.0;    // กำไรส่วนต่างหักลบไม้ดอย (บาท)

// --- [กลุ่มที่ 6: ระบบควบคุมลอจิก - เพิ่ม ATR/Trend ตามสั่ง] ---
input group "⚙️ ระบบสวนเทรนด์"
input bool    Inp_Use_Trend_H1   = true;   // เปิดระบบ(กันสวนเทรนด์)
input bool    Inp_Trend_Follow   = true;   // เปิด/ปิด ระบบกรองเทรน
input bool    Inp_Use_ATR_Step   = false;   // ใช้ ATR ถ่างระยะไม้ (กันทองทุบ)
input double  Inp_ATR_Multiplier = 1.5;    // ตัวคูณ ATR เพื่อกำหนดระยะ Step

// --- [กลุ่มที่ 7: ระบบกันทุน & Trailing] ---
input group "💰 ระบบควบคุมRSI"
input int     Inp_RSI_High       = 70;     // จุดเริ่มเปิดสนาม (Overbought)
input int     Inp_RSI_Low        = 30;     // จุดเริ่มเปิดสนาม (Oversold)
input int     Inp_CoolDown_Sec   = 300;    // เว้นระยะห่างหลังปิดงาน (5 นาที)
input double  Inp_Min_Margin      = 300.0;  // % Margin ขั้นต่ำ (เซฟ=300%)

// --- [กลุ่มที่ 8: ระบบกันทุน & Trailing] ---
input group "🛡️ ระบบป้องกันกำไรยกตะกร้า"
input bool    Inp_Use_Trailing   = true;   // เปิดระบบ Trailing
input bool    Inp_Auto_SL        = true;   // คำนวณ SL อัตโนมัติ (จาก ATR ไม่ต้องตั้งเอง)
input int     Inp_BE_Trigger     = 450;    // เริ่มวาง SL หน้าทุน
input int     Inp_BE_Lock        = 150;    // ระยะ SL หน้าทุน
input int     Inp_Trail_Stop      = 400;    // ระยะ SL วิ่งไล่ตามราคา
input int     Inp_Trail_Step      = 50;     // ระยะขยับทีละ

// --- [กลุ่มที่ 8.5: ระบบ TP ทุกไม้ & Trailing TP] ---
input group "🎯 TP ทุกไม้ & Trailing TP (ล็อคกำไร)"
input bool   Inp_Use_All_TP          = true;    // ตั้ง TP ทุกไม้อัตโนมัติ
input bool   Inp_Auto_TP             = true;    // คำนวณ TP อัตโนมัติจาก ATR
input int    Inp_All_TP_Points       = 500;     // TP ห่างจากราคาเปิดแต่ละไม้ (จุด)
input bool   Inp_Use_Trailing_TP     = true;    // เปิดระบบ Trailing TP (TP ขยับตามราคา)
input int    Inp_Trail_TP_Trigger    = 300;     // เริ่ม Trail เมื่อกำไรกี่จุด
input int    Inp_Trail_TP_Distance   = 200;     // TP ห่างจากราคาปัจจุบัน (ขณะ Trail)
input int    Inp_Trail_TP_Step       = 50;      // ขยับ TP ทีละกี่จุด
input int    Inp_Trail_TP_Min_Profit = 50;      // กำไรขั้นต่ำที่ต้องล็อค (จุด)


// --- [กลุ่มที่ 9: ระบบ การตั้งค่าระยะแก้ไม้] ---
input group "📐 การตั้งค่าระยะแก้ไม้"
input double Inp_Step_Base       = 1200.0;  // ระยะห่างเริ่มต้น (เซฟ=$12)
input double Inp_Step_Exp        = 1.0;    // ตัวคูณระยะห่าง (เซฟ=คงที่)
double g_last_buy_rescue_lot  = 0;
double g_last_sell_rescue_lot = 0;

// --- [กลุ่มที่ 10: ระบบ กู้พอร์ตเมื่อโดนลากหนัก Panic Rescue] ---
input group "🚨 ระบบแก้ไม้ตามเทรนด์"
input bool   Inp_Use_Panic_Rescue      = true;    // เปิดระบบแก้ใหม่ไม้ (เซฟ=เปิด 1 ไม้ต่อฝั่ง)
input int    Inp_Rescue_Magic          = 666666;  // รหัสอ้างอิงออเดอร์
input int    Inp_Rescue_Min_Orders     = 2;       // มีไม้หลักกี่ไม้ขึ้นไปถึงเริ่มพิจารณา
input int    Inp_Rescue_Trigger_Points = 600;    // ราคาโดนลากกี่จุดถึงเริ่มแก้
input int    Inp_Rescue_TP_Points      = 500;     // tp 
input double Inp_Rescue_Close_THB      = 5.0;     // กำไรรวมถึงเท่านี้ให้ปิดรวบ (บาท)
input double Inp_Rescue_Lot_Buffer     = 1.20;    // เผื่อ lot เพิ่ม เช่น 1.2 = เผื่อ 20%
input double Inp_Rescue_Max_Lot        = 0.02;    // lot แก้ไม้สูงสุด (เซฟ=0.02)
input bool   Inp_Rescue_Trend_Only     = true;    // เปิดเฉพาะเมื่อเทรนด์ยืนยัน
input bool   Inp_Rescue_Reverse_Mode = false; // เปิดโหมดกลับตัวคูณไม้ (เซฟ=ปิด อย่าเปิด)
input double Inp_Rescue_Reverse_Mult = 1.35; // ตัวคูณไม้กลับตัว

// --- [กลุ่มที่ 11: ระบบ ควบคุมความดุของไม้แก้] ---
input group "🚨 ระบบควบคุมความดุของไม้แก้"
input int MagicNumber = 99999; //รหัสอางอิงออเดอร์
input int RecoveryWaitMinutes = 3;
input int RecoveryDistancePoints = 100;
input double LotMultiplier = 1.5;
input int RescueConfirmBars = 1;

// --- [กลุ่มที่ 11: ระบบ ไม้เสริมและจำกัดไม้] ---
input group "🛡️ ระบบไม้เสริม & จำกัดไม้หลัก"
input bool   Inp_Use_Max_Main    = true;   // เปิดระบบจำกัดจำนวนไม้หลัก
input int    Inp_Max_Main_Orders = 3;      // จำนวนไม้หลักสูงสุด (เซฟ=3 ไม้)
input bool   Inp_Use_Support      = false;   // เปิดใช้งานระบบไม้เสริม (Hedge Support) (เซฟ=ปิดคงที่)
input int    Inp_Support_Magic   = 999999; // รหัสอ้างอิงไม้เสริม (แยกจากไม้หลัก)
input double Inp_Support_Lot      = 0.01;   // ล็อตไม้เสริม
input int    Inp_Support_TP_Pts  = 300;    // ระยะรวบปิดไม้เสริม (Points)

// --- [กลุ่มที่ 12: ระบบ เส้นฉลาดเลือกทาง] ---
input group "📍 ระบบเส้น"
input bool   Inp_Use_Order_Line    = false;   // เปิดใช้งานเส้นฉลาด
input bool   Inp_OL_Smart_Path     = false;    // ให้เส้นเลือกทางเอง
input bool   Inp_OL_Auto_Mode      = false;    // Auto / Manual
input bool   Inp_OL_One_Side_Only  = false;   // false = แสดง Buy/Sell พร้อมกัน
input int    Inp_OL_Buy_Offset     = 150;     // ระยะเส้น Buy
input int    Inp_OL_Sell_Offset    = 150;     // ระยะเส้น Sell
input double Inp_OL_Buy_Price      = 0.0;     // ราคา Buy Manual
input double Inp_OL_Sell_Price     = 0.0;     // ราคา Sell Manual
input int    Inp_OL_Replan_Sec     = 60;      // วางแผนเส้นใหม่ทุกกี่วิ
input int    Inp_OL_Trigger_Buffer = 30;      // ราคาใกล้เส้นกี่ จุด ถึงเข้า
input int    Inp_OL_Reset_Buffer   = 250;     // รีเซ็ตหลังยิงแล้ว
input color  Inp_OL_Buy_Color      = clrBlue;  //สีBUY 
input color  Inp_OL_Sell_Color     = clrRed;  //สีSELL
input int    Inp_OL_Width          = 2;

// --- [กลุ่มที่ 13: ระบบหักลบปิดรวบ] ---
input group "🔄 ระบบหักลบปิดรวบ (Offset Close)"
input bool   Inp_Use_Pull_Recovery    = true;    // เปิดระบบหักลบปิดรวบ
input double Inp_Pull_Close_THB      = 2.0;     // กำไรสุทธิขั้นต่ำ หักลบปิดรวบ (บาท)

// --- [กลุ่มที่ 14: ระบบดึงไม้ดอย (Pull Recovery)] ---
input group "🔄 ระบบดึงไม้ดอย (Pull Recovery)"
input bool   Inp_Use_Pull_Lot        = false;    // เปิดระบบดึงไม้ดอย (เซฟ=ปิด)
input double Inp_Pull_Trigger_DD     = 300.0;   // ขาดทุนเฉลี่ยต่อไม้ (จุด) เริ่มดึง
input double Inp_Pull_Lot_Mult       = 1.5;     // ตัวคูณ lot (จาก lot รวมฝั่งที่ค้าง)
input double Inp_Pull_Max_Lot        = 0.02;     // lot สูงสุดที่เปิดดึง (เซฟ=0.02)
input int    Inp_Pull_Magic          = 777777;  // Magic Number ไม้ดึง
input int    Inp_Pull_Cooldown       = 60;      // Cooldown (วินาที) กันยิงรัว


// --- [กลุ่มที่ 16: กรอง RSI + เทรนด์ร่วมกัน] ---
input group "📈 กรอง RSI + เทรนด์ (Multi-Filter)"
input bool   Inp_Use_Multi_Filter   = true;    // เปิดระบบกรอง RSI + เทรนด์
input int    Inp_RSI_OB             = 75;      // RSI Overbought
input int    Inp_RSI_OS             = 25;      // RSI Oversold

// --- [กลุ่มที่ 17: TP แบ่งปิด (Partial Close)] ---
input group "🎯 TP แบ่งปิด (Partial Close)"
input bool   Inp_Use_Partial_Close  = true;    // เปิดระบบปิดครึ่งเมื่อกำไร
input double Inp_Partial_Pct        = 50.0;    // ปิดกี่ % ของ lot (เช่น 50 = ครึ่ง)
input int    Inp_Partial_Trigger    = 250;     // เริ่มปิดบางส่วนเมื่อกำไรกี่จุด

// --- [กลุ่มที่ 18: ลด Lot อัตโนมัติ (Anti-Martingale)] ---
input group "📉 ลด Lot อัตโนมัติ (Anti-Martingale)"
input bool   Inp_Use_Anti_Mart      = true;    // เปิดระบบ Anti-Martingale
input int    Inp_Consec_Loss_Limit  = 3;       // ขาดทุนต่อเนื่องกี่ครั้งก่อนลด lot
input double Inp_Lot_Reduce_Pct     = 50.0;    // ลด lot กี่ % (เช่น 50 = ครึ่ง)


// --- Global Variables ---
int h_ma, h_atr, h_rsi;
datetime expire_date;
bool is_authorized = false, is_processing = false;
bool g_auto_mode = true; 
bool g_infinity_mode = true; 
bool g_mobile_hedge = true;   
bool g_double_force = true;   
bool g_trend_filter = false;    // ตัวแปรเก็บสถานะปุ่ม Trend H1
bool g_ui_visible = true;       // แสดง/ซ่อน UI หลัก
datetime LastRecoveryTime = 0;
datetime g_last_pull_time = 0;

// --- ตัวแปร Anti-Martingale & Partial Close ---
int g_consec_losses = 0;
int g_consec_wins = 0;

double LastEntryPrice = 0;

bool g_rescue_active = false;
datetime g_rescue_last_open = 0;

double g_last_rescue_lot = 0;
int g_last_rescue_side = -1;

datetime lastTradeTime = 0;




// --- ตัวแปรระบบเส้นฉลาด ---
bool g_order_line_enabled = false;
bool g_buy_line_created = false, g_sell_line_created = false;
double g_buy_line_price = 0.0, g_sell_line_price = 0.0;
bool g_buy_line_triggered = false, g_sell_line_triggered = false;
datetime g_ol_last_plan = 0;
int g_ol_path = 0; // 1=Buy, -1=Sell, 0=รอสัญญาณ

datetime g_last_manual_hedge = 0;
ulong g_last_manual_ticket = 0;

bool g_target_reached_today = false; 
datetime last_basket_close = 0;
color g_bg, g_fg, g_grid, g_up, g_down; 



input int TradeCooldownSec = 300;




bool ConfirmBuyTrend()
{
   double ema = iMA(_Symbol,_Period,20,0,MODE_EMA,PRICE_CLOSE);

   double close1 = iClose(_Symbol,_Period,1);
   double close2 = iClose(_Symbol,_Period,2);

   return (close1 > ema && close2 > ema);
}

bool CanRecovery()
{
   if(TimeCurrent() - LastRecoveryTime <
      RecoveryWaitMinutes * 60)
      return false;

   return true;
}

double GetNextLot()
{
   double lastLot = Inp_BaseLot;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL)==_Symbol)
         {
            lastLot = PositionGetDouble(POSITION_VOLUME);
            break;
         }
      }
   }

   return NormalizeDouble(lastLot * LotMultiplier,2);
}

//
bool ConfirmSellTrend()
{
   double ema = iMA(_Symbol,_Period,20,0,MODE_EMA,PRICE_CLOSE);

   double close1 = iClose(_Symbol,_Period,1);
   double close2 = iClose(_Symbol,_Period,2);

   return (close1 < ema && close2 < ema);
}

  bool CanOpenNewTrade()
{
   if(TimeCurrent() - lastTradeTime < TradeCooldownSec)
      return false;

   return true;
}

bool IsNewM5Bar()
{
   static datetime lastBar = 0;

   datetime currentBar =
      iTime(_Symbol, PERIOD_M5, 0);

   if(currentBar != lastBar)
   {
      lastBar = currentBar;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   CheckLicense(); 
   if(!is_authorized || TimeCurrent() > expire_date) {
      Alert("ไม่อนุญาตให้ใช้งานหรือหมดอายุ!");
      return(INIT_FAILED);
   }

   //h_ma  = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   h_ma = iMA(_Symbol, PERIOD_H1, 30, 0, MODE_EMA, PRICE_CLOSE);
   h_atr = iATR(_Symbol, PERIOD_H1, 14);
  // h_atr = iATR(_Symbol, PERIOD_H1, 14); // ดึงค่าความผันผวนจาก H1
   h_rsi = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   trade.SetExpertMagicNumber(Inp_Magic);
   
   g_trend_filter = Inp_Use_Trend_H1;
   g_order_line_enabled = Inp_Use_Order_Line;

   SaveChartColors();
   ApplyDarkTheme();
   DrawUI(); 
   if(g_order_line_enabled) DrawOrderLines();
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) { 
   CleanupVisual(); 
   RestoreChartColors();
}

//+------------------------------------------------------------------+
//| CORE LOGIC                                                       |
//+------------------------------------------------------------------+
void OnTick() {
   if(!is_authorized || is_processing || TimeCurrent() > expire_date) return;

   // กัน EA เริ่มรันแล้วปิดไม้ทันที — รอ 10 วินาทีก่อน
   static datetime ea_start_time = 0;
   if(ea_start_time == 0) ea_start_time = TimeCurrent();
   bool is_warming_up = (TimeCurrent() - ea_start_time < 10);

   double daily_p_usc = GetDailyProfitUSC();
   if(Inp_Use_Daily_Lock && daily_p_usc >= Inp_Daily_Target_USC && !is_warming_up) {
      if(!g_target_reached_today) {
         if(Inp_Close_And_Stop) { CloseAllProfitOnly(); g_auto_mode = false; }
         g_target_reached_today = true;
         Alert("เป้าแตก! กำไรวันนี้ครบ "+(string)Inp_Daily_Target_USC+" USC แล้วนาย");
         ShowBigMessage("🎯 ถึงเป้าหมายแล้ว!", clrLime);
      }
      UpdateUI(AccountInfoDouble(ACCOUNT_BALANCE), 0, AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), daily_p_usc, 0, 0, 0, 0);
      return; 
   }
   
   
   static int last_day = -1;
   MqlDateTime dt; TimeCurrent(dt);
   if(dt.day != last_day) { g_target_reached_today = false; last_day = dt.day; }

   if(Inp_Use_Time_Filter && !IsThaiTimeWindow()) {
      UpdateUI(AccountInfoDouble(ACCOUNT_BALANCE), 0, AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), daily_p_usc, 0, 0, 0, 0);
      ShowBigMessage("⏰ ยังไม่ถึงเวลาเทรด", clrOrangeRed);
      return; 
   }
   // ซ่อนข้อความตัวใหญ่เมื่ออยู่ในเวลาเทรด
   HideBigMessage();

   if(g_mobile_hedge || g_double_force) CheckMobileHedge();

   int b_t = 0, s_t = 0; 
   double b_p_usd = 0, s_p_usd = 0;
   double b_vol_sum = 0, s_vol_sum = 0;
   double b_cost_sum = 0, s_cost_sum = 0;

   int b_supp_t = 0, s_supp_t = 0;
   double b_supp_vol = 0, s_supp_vol = 0, b_supp_cost = 0, s_supp_cost = 0;

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double m_lv = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         long m_num = PositionGetInteger(POSITION_MAGIC);
         double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         double vol = PositionGetDouble(POSITION_VOLUME);
         double op  = PositionGetDouble(POSITION_PRICE_OPEN);

         if(m_num == Inp_Magic) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) { 
               b_t++; b_p_usd += p; b_vol_sum += vol; b_cost_sum += (op * vol);
            }
            else { 
               s_t++; s_p_usd += p; s_vol_sum += vol; s_cost_sum += (op * vol);
            }
         }
         else if(m_num == Inp_Support_Magic) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               b_supp_t++; b_supp_vol += vol; b_supp_cost += (op * vol);
            }
            else {
               s_supp_t++; s_supp_vol += vol; s_supp_cost += (op * vol);
            }
         }
      }
   }

   if(Inp_Use_Support) {
      if(b_supp_t > 0) UpdateSupportTP(POSITION_TYPE_BUY, b_supp_cost/b_supp_vol);
      if(s_supp_t > 0) UpdateSupportTP(POSITION_TYPE_SELL, s_supp_cost/s_supp_vol);
   }

   if(b_t == 0 && s_t == 0) {
      if(CountSupportOrders() > 0) {
         CloseSupportOnly();
         Print("ไม้หลักรวบจบ -> ปิดไม้เสริมตามคำขอ");
      }
   }

   string acc_curr = AccountInfoString(ACCOUNT_CURRENCY);
   bool is_cent = (StringFind(acc_curr, "USC") >= 0 || StringFind(acc_curr, "Cent") >= 0);
   double divider = is_cent ? 100.0 : 1.0;
   double b_p_thb = (b_p_usd / divider) * 32.0; 
   double s_p_thb = (s_p_usd / divider) * 32.0;
   double total_thb = b_p_thb + s_p_thb;

   // --- [เพิ่มระบบแทรก: Quick Scalp & Clear Winner Side] ---
   if(Inp_Quick_Scalp && !is_processing && !is_warming_up) {
      if(b_t == 1 && s_t == 0 && b_p_thb >= Inp_Min_Profit_THB) {
         CloseSideProfitOnly(POSITION_TYPE_BUY); last_basket_close = TimeCurrent(); return; 
      }
      if(s_t == 1 && b_t == 0 && s_p_thb >= Inp_Min_Profit_THB) {
         CloseSideProfitOnly(POSITION_TYPE_SELL); last_basket_close = TimeCurrent(); return; 
      }
   }

   if(Inp_Close_All_When_Green && !is_processing && !is_warming_up) {
      if(b_t > 0 && s_t > 0 && b_p_thb >= Inp_Close_All_Min_Profit_THB && s_p_thb >= Inp_Close_All_Min_Profit_THB) {
         CloseAllProfitOnly(); last_basket_close = TimeCurrent(); return;
      }
   }

   // ปิดรวบทั้งกระดาน เมื่อกำไรรวมทุกฝั่งเป็นบวก (ไม่สนว่าแต่ละฝั่งเป็นยังไง)
   if(Inp_Close_When_Net_Profit && !is_processing && !is_warming_up) {
      if((b_t > 0 || s_t > 0) && total_thb > 0) {
         Print("ปิดรวบทั้งกระดาน | กำไรรวม THB: ", DoubleToString(total_thb,2));
         CloseAll();
         last_basket_close = TimeCurrent();
         g_rescue_active = false;
         g_last_buy_rescue_lot = 0;
         g_last_sell_rescue_lot = 0;
         return;
      }
   }

   if(Inp_Clear_Winner_Side && !is_processing && !is_warming_up) {
      if(b_t > 0 && b_p_thb >= Inp_Min_Profit_THB) {
         if(Inp_Nuke_Board && total_thb >= 0) CloseAllProfitOnly(); else CloseSideProfitOnly(POSITION_TYPE_BUY); 
         last_basket_close = TimeCurrent(); return; 
      }
      if(s_t > 0 && s_p_thb >= Inp_Min_Profit_THB) {
         if(Inp_Nuke_Board && total_thb >= 0) CloseAllProfitOnly(); else CloseSideProfitOnly(POSITION_TYPE_SELL); 
         last_basket_close = TimeCurrent(); return; 
      }
   }
   // ----------------------------------------------------

   if(Inp_Exit_Mode != Basket_TP) {
      if(b_t > 0) UpdateHardTP(POSITION_TYPE_BUY, b_cost_sum/b_vol_sum, b_vol_sum, divider);
      if(s_t > 0) UpdateHardTP(POSITION_TYPE_SELL, s_cost_sum/s_vol_sum, s_vol_sum, divider);
   } else {
      if(CheckGlobalBasketExit(total_thb, b_p_usd + s_p_usd, b_vol_sum + s_vol_sum)) {
         last_basket_close = TimeCurrent();
         return;
      }
   }

   if(Inp_Use_Trailing) {
      if(b_t > 0) ApplyBasketTrailing(POSITION_TYPE_BUY, b_cost_sum/b_vol_sum, b_p_usd, b_vol_sum);
      if(s_t > 0) ApplyBasketTrailing(POSITION_TYPE_SELL, s_cost_sum/s_vol_sum, s_p_usd, s_vol_sum);
   }

   // TP ทุกไม้ & Trailing TP (ล็อคกำไร)
   ManageAllPositionsTP();

   // TP แบ่งปิด (Partial Close)
   ManagePartialClose();

   // ปิดไม้ lot จิ๋วที่ค้างจาก Partial Close
   if(!is_warming_up) CleanupTinyPositions();

   double velocity = MathAbs(iClose(_Symbol, PERIOD_M1, 0) - iOpen(_Symbol, PERIOD_M1, 0)) / _Point;
   if(Inp_Use_AI_Exit && !is_warming_up && total_thb > (Inp_Target_THB * 0.5) && velocity < 5.0 && (b_t > 0 || s_t > 0)) {
      // ปิดเฉพาะเมื่อไม่มีฝั่งไหนขาดทุนหนัก (กัน cut loss)
      if(b_p_thb >= 0 && s_p_thb >= 0) {
         CloseAllProfitOnly(); last_basket_close = TimeCurrent(); return;
      } else if(b_t > 0 && s_t == 0 && b_p_thb > 0) {
         CloseSideProfitOnly(POSITION_TYPE_BUY); last_basket_close = TimeCurrent(); return;
      } else if(s_t > 0 && b_t == 0 && s_p_thb > 0) {
         CloseSideProfitOnly(POSITION_TYPE_SELL); last_basket_close = TimeCurrent(); return;
      }
   }
   

   // ===============================
// 🚪 FORCE CLOSE SYSTEM (NEW)
// ===============================
if(!is_processing)
{
   double velocity = MathAbs(iClose(_Symbol, PERIOD_M1, 0)
                    - iOpen(_Symbol, PERIOD_M1, 0)) / _Point;

   if(Inp_Force_Close_Mode == CLOSE_OFF)
   {
      // ไม่ทำอะไร
   }
   else if(Inp_Force_Close_Mode == CLOSE_BY_PROFIT)
   {
      if(total_thb >= Inp_Force_Close_THB)
      {
         Print("🚪 Force Close (Profit Mode) = ", total_thb);
         CloseAllProfitOnly();
         last_basket_close = TimeCurrent();
         return;
      }
   }
   else if(Inp_Force_Close_Mode == CLOSE_BY_BASKET)
   {
      // ใช้ logic เดิมของคุณ
      if(CheckGlobalBasketExit(total_thb, b_p_usd + s_p_usd, b_vol_sum + s_vol_sum))
      {
         last_basket_close = TimeCurrent();
         return;
      }
   }

   // 🔥 กันลากกลับ (optional safety)
   if(Inp_Force_Close_Mode == CLOSE_BY_PROFIT)
   {
      if(total_thb >= Inp_Force_Close_THB && velocity < Inp_Force_Close_Velocity)
      {
         Print("🚀 Fast Close (Low Volatility)");
         CloseAllProfitOnly();
         last_basket_close = TimeCurrent();
         return;
      }
   }
}

   if(Inp_Use_Survivor && !is_warming_up && (datetime)TimeCurrent() - lastTradeTime > 5) {
      if(b_t >= 2) TrySurvivorClear(POSITION_TYPE_BUY);
      if(s_t >= 2) TrySurvivorClear(POSITION_TYPE_SELL);
   }

   // --- [เพิ่มระบบแทรก: Cross Survivor] ---
   if(Inp_Cross_Survivor && !is_processing && !is_warming_up && (datetime)TimeCurrent() - lastTradeTime > 5) {
      if(b_t > 0 && s_t > 0) TryCrossSurvivorClear(divider);
   }
   // ------------------------------------

   double rsi_v[], ma_v[], atr_v[];
   ArraySetAsSeries(rsi_v, true); ArraySetAsSeries(ma_v, true); ArraySetAsSeries(atr_v, true);
   
   if(CopyBuffer(h_rsi, 0, 0, 1, rsi_v) > 0 && CopyBuffer(h_ma, 0, 0, 1, ma_v) > 0 && CopyBuffer(h_atr, 0, 0, 1, atr_v) > 0) {
      if(g_auto_mode && b_t == 0 && s_t == 0) {
         if((datetime)TimeCurrent() - last_basket_close > Inp_CoolDown_Sec) {
            bool trigger = (g_infinity_mode) || (rsi_v[0] >= Inp_RSI_High || rsi_v[0] <= Inp_RSI_Low);
            bool is_uptrend = (iClose(_Symbol, PERIOD_H1, 0) > ma_v[0]);  
              //bool is_uptrend = (iClose(_Symbol, PERIOD_H1, 0) > ma_v[0]);

               if(Inp_Use_Time_Filter && !IsThaiTimeWindow()) { trigger = false; ShowBigMessage("⏰ ยังไม่ถึงเวลาเทรด", clrOrangeRed); }
            if(trigger) {
               trade.SetExpertMagicNumber(Inp_Magic);
               if(g_trend_filter) {
                  // ถ้าเปิดกรองเทรนด์ จะเปิดเฉพาะฝั่งที่เทรนด์ 
                  if(is_uptrend) trade.Buy(SafeLot(GetAntiMartLot(Inp_BaseLot)));
                  else trade.Sell(SafeLot(GetAntiMartLot(Inp_BaseLot)));
               } else {
                  // ถ้าไม่กรองเทรนด์ เปิดตามลอจิกเดิม (Double Force)
                  trade.Buy(SafeLot(GetAntiMartLot(Inp_BaseLot)));
                  if(g_double_force) trade.Sell(SafeLot(GetAntiMartLot(Inp_BaseLot))); 
               }
               lastTradeTime = TimeCurrent();
               if(Inp_Use_Support) OpenSupportOrder();
            }
         }
      }
      UpdateUI(bal, 0, m_lv, daily_p_usc, b_t, s_t, atr_v[0], ma_v[0]);
      UpdateRightPanel();

      // อัปเดตตารางย้อนหลัง 7 วัน (ทุก 60 วินาที)
      static datetime last_hist_update = 0;
      if(TimeCurrent() - last_hist_update >= 60) {
         UpdateHistoryPanel();
         last_hist_update = TimeCurrent();
      }

      if((m_lv > Inp_Min_Margin || m_lv == 0) && (datetime)TimeCurrent() - lastTradeTime > 3) {
         if(b_t > 0 && b_t < 20) SmartCheckRecovery(POSITION_TYPE_BUY, b_t, atr_v[0]);
         if(s_t > 0 && s_t < 20) SmartCheckRecovery(POSITION_TYPE_SELL, s_t, atr_v[0]);
      }
   }

   if(Inp_Exit_Mode == Money_Target) {
   if(b_p_thb >= Inp_Target_THB && b_t > 0) { CloseSideProfitOnly(POSITION_TYPE_BUY); last_basket_close = TimeCurrent(); UpdateConsecRecord(true); ShowBigMessage("🎯 ถึงเป้าหมาย BUY แล้ว!", clrLime); }
   if(s_p_thb >= Inp_Target_THB && s_t > 0) { CloseSideProfitOnly(POSITION_TYPE_SELL); last_basket_close = TimeCurrent(); UpdateConsecRecord(true); ShowBigMessage("🎯 ถึงเป้าหมาย SELL แล้ว!", clrLime); }
  }
  // --- ตรวจสอบเส้นฉลาด ---
  if(g_order_line_enabled) CheckOrderLineHit();

  // --- ตรวจสอบระบบกู้พอร์ตเมื่อโดนลากหนัก ---
  if(Inp_Use_Panic_Rescue && !is_processing)
   CheckPanicRescue(divider);

  // --- ระบบดึงกลับเมื่อเทรนด์กลับตัว & กันพอร์ตแตก ---
  if(!is_processing)
   SmartPullRecovery(divider);

  // --- ระบบดึงไม้ดอย ---
  if(!is_processing)
   PullStuckPositions();
}
//--- Functions ---
void SmartCheckRecovery(ENUM_POSITION_TYPE t, int tot, double atr) {
   if(Inp_Use_Max_Main && tot >= Inp_Max_Main_Orders) return;

   // กรองเวลาเทรด + กรอง RSI+เทรนด์
   if(Inp_Use_Time_Filter && !IsThaiTimeWindow()) return;
   if(!PassMultiFilter(t)) return;

   // ถ้าเปิดกรองเทรนด์ จะไม่แก้ไม้ฝั่งที่สวนเทรนด์
   if(g_trend_filter) {
      double ma_v[]; ArraySetAsSeries(ma_v, true);
      if(CopyBuffer(h_ma, 0, 0, 1, ma_v) > 0) {
         //bool is_uptrend = (iClose(_Symbol, PERIOD_H1, 0) > ma_v[0]);
         bool is_uptrend = (iClose(_Symbol, PERIOD_H1, 0) > ma_v[0]);
         if(t == POSITION_TYPE_BUY && !is_uptrend) return;
         if(t == POSITION_TYPE_SELL && is_uptrend) return;
      }
   }

   double lp=0, ll=0;
bool found = false;
datetime latest_time = 0;

// หาไม้ล่าสุดทั้ง Main + Rescue (เรียงตาม POSITION_TIME เพื่อจับ lot ที่ถูกต้อง)
for(int i=PositionsTotal()-1; i>=0; i--)
{
   ulong ticket =
      PositionGetTicket(i);

   if(!PositionSelectByTicket(ticket))
      continue;

   if(PositionGetString(POSITION_SYMBOL)
      != _Symbol)
      continue;

   long mg =
      PositionGetInteger(
         POSITION_MAGIC
      );

   ENUM_POSITION_TYPE pt =
      (ENUM_POSITION_TYPE)
      PositionGetInteger(
         POSITION_TYPE
      );

   if(
      (mg == Inp_Magic
      || mg == Inp_Rescue_Magic)
      &&
      pt == t
   )
   {
      datetime open_time =
         (datetime)PositionGetInteger(
            POSITION_TIME
         );

      if(open_time > latest_time)
      {
         latest_time = open_time;

         lp =
            PositionGetDouble(
               POSITION_PRICE_OPEN
            );

         ll =
            PositionGetDouble(
               POSITION_VOLUME
            );

         found = true;
      }
   }
}

if(!found)
   return;

   // ลอจิก ATR Dynamic Step: ถ่ายระยะห่างถ้าตลาดผันผวนสูง
   double final_dist = (Inp_Step_Base * _Point) * MathPow(Inp_Step_Exp, (double)tot - 1.0);
   if(Inp_Use_ATR_Step && atr > 0) {
      final_dist = MathMax(final_dist, atr * Inp_ATR_Multiplier);
   }
   
   double cp = (t == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if((t == POSITION_TYPE_BUY && cp <= lp - final_dist) || (t == POSITION_TYPE_SELL && cp >= lp + final_dist)) {
      double nl = SafeLot(ll * Inp_Lot_Multiplier);
      trade.SetExpertMagicNumber(Inp_Magic);
      bool opened = trade.PositionOpen(_Symbol, (t==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL), nl, 0, 0, 0, "แก้โดยระบบออโต้");
      if(opened) {
         lastTradeTime = TimeCurrent();
         if(Inp_Use_Support) OpenSupportOrder();
      } else {
         PrintFormat("SmartCheckRecovery failed(%s): lp=%.5f cp=%.5f dist=%.5f nl=%.2f ret=%d %s", 
            (t==POSITION_TYPE_BUY?"BUY":"SELL"), lp, cp, final_dist, nl, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      }
   }
}

double GetDailyProfitUSC() {
   double profit = 0;
   HistorySelect(StringToTime(TimeToString(TimeCurrent(), TIME_DATE)), TimeCurrent());
   for(int i=HistoryDealsTotal()-1; i>=0; i--) {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol && HistoryDealGetInteger(ticket, DEAL_MAGIC) == Inp_Magic)
         profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }
   return profit;
}

bool IsThaiTimeWindow() {
   MqlDateTime th_dt; TimeToStruct(TimeLocal(), th_dt); 
   return (th_dt.hour >= Inp_Start_Hour_TH && th_dt.hour < Inp_End_Hour_TH);
}

void CheckMobileHedge()
{
   static ulong last_mobile_ticket = 0;
   static datetime last_hedge_time = 0;

   // กันยิงรัว
   if(TimeCurrent() - last_hedge_time < 3)
      return;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i);

      if(!PositionSelectByTicket(tk))
         continue;

      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==MagicNumber)
         continue;

      // เอาเฉพาะไม้มือถือ
      if(PositionGetInteger(POSITION_MAGIC) != 0)
         continue;

      // ยิง hedge แค่ครั้งเดียวต่อ ticket
      if(tk == last_mobile_ticket)
         continue;

      double lot =
         PositionGetDouble(POSITION_VOLUME);

      ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)
         PositionGetInteger(POSITION_TYPE);

      trade.SetExpertMagicNumber(Inp_Magic);

      bool opened = false;

      // Buy มือถือ -> เปิด Sell hedge
      if(type == POSITION_TYPE_BUY)
      {
         opened = trade.Sell(
            SafeLot(lot),
            _Symbol,
            0,0,0,
            "Mobile Hedge"
         );
      }

      // Sell มือถือ -> เปิด Buy hedge
      else if(type == POSITION_TYPE_SELL)
      {
         opened = trade.Buy(
            SafeLot(lot),
            _Symbol,
            0,0,0,
            "Mobile Hedge"
         );
      }

      if(opened)
      {
         last_mobile_ticket = tk;
         lastTradeTime = TimeCurrent();
         last_hedge_time = TimeCurrent();

         Print("Mobile Hedge Opened | Ticket: ", tk);
      }
   }

   // รีเซ็ตเมื่อไม่มีไม้มือถือ
   bool mobile_exist = false;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i);

      if(PositionSelectByTicket(tk)
         && PositionGetInteger(POSITION_MAGIC) == 0
         && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         mobile_exist = true;
         break;
      }
   }

   if(!mobile_exist)
   {
      last_mobile_ticket = 0;
   }
}

void OpenSupportOrder() {
   int b_main = 0, s_main = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) b_main++; else s_main++;
      }
   }
   trade.SetExpertMagicNumber(Inp_Support_Magic);
   if(b_main > 0) trade.Sell(SafeLot(Inp_Support_Lot), _Symbol, 0, 0, 0, "ไม้เสริมฝั่ง Buy หลัก");
   if(s_main > 0) trade.Buy(SafeLot(Inp_Support_Lot), _Symbol, 0, 0, 0, "ไม้เสริมฝั่ง Sell หลัก");
}

int CountSupportOrders() {
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == Inp_Support_Magic) count++;
   }
   return count;
}

void CloseSupportOnly() {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != Inp_Support_Magic) continue;
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(profit >= 0) trade.PositionClose(tk);
   }
}

void UpdateSupportTP(ENUM_POSITION_TYPE type, double avg_price) {
   double tp_price = (type == POSITION_TYPE_BUY) ? (avg_price + Inp_Support_TP_Pts * _Point) : (avg_price - Inp_Support_TP_Pts * _Point);
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == Inp_Support_Magic && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         if(MathAbs(PositionGetDouble(POSITION_TP) - tp_price) > _Point * 10) 
            trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), NormalizeDouble(tp_price, _Digits));
      }
   }
}

void DrawOpenButton() {
   // ปุ่มเล็กๆ มุมซ้ายบน สำหรับเปิด UI ตอนซ่อน
   MakeRect(BRT+"OPEN_BG", PANEL_X, PANEL_Y, 40, 28, CLR_HEADER_BG);
   ObjectSetInteger(0, BRT+"OPEN_BG", OBJPROP_ZORDER, 99);
   MakeLabel(BRT+"OPEN_LBL", PANEL_X+8, PANEL_Y+5, "☰ เปิด", "Segoe UI", 9, CLR_GOLD);
   ObjectSetInteger(0, BRT+"OPEN_LBL", OBJPROP_ZORDER, 100);
}

void DeleteOpenButton() {
   ObjectDelete(0, BRT+"OPEN_BG");
   ObjectDelete(0, BRT+"OPEN_LBL");
}

void DrawUI() {
   if(!g_ui_visible) {
      // ซ่อน UI หลัก แสดงแค่ปุ่มเปิด
      DrawOpenButton();
      return;
   }
   
   int y = PANEL_Y;
   MakeRect(BRT+"BG", PANEL_X, PANEL_Y, PANEL_W, 680, CLR_PANEL_BG);
   ObjectSetInteger(0, BRT+"BG", OBJPROP_ZORDER, 0); 
   MakeRect(BRT+"HDR", PANEL_X, PANEL_Y, PANEL_W, HDR_H, CLR_HEADER_BG);
   ObjectSetInteger(0, BRT+"HDR", OBJPROP_ZORDER, 1);
   MakeLabel(BRT+"TITLE", PANEL_X+PAD, y+8, "◆ EA:Beast Tamer", "Segoe UI", 11, CLR_GOLD); 
   
   // ปุ่ม X ปิด UI
   MakeRect(BRT+"CLOSE_UI_BG", PANEL_X+PANEL_W-32, PANEL_Y+4, 24, 24, C'192,57,43');
   ObjectSetInteger(0, BRT+"CLOSE_UI_BG", OBJPROP_ZORDER, 2);
   MakeLabel(BRT+"CLOSE_UI_X", PANEL_X+PANEL_W-26, PANEL_Y+5, "✕", "Tahoma", 12, clrWhite);
   ObjectSetInteger(0, BRT+"CLOSE_UI_X", OBJPROP_ZORDER, 3);
   
   y += HDR_H+10; 
   

   // เพิ่มปุ่มควบคุมเทรนด์ใหม่
   CreateButton(BRT+"BTN_TREND", g_trend_filter?"เทรนด์: [เปิดใช้งาน]":"เทรนด์: [ปิดใช้งาน]", PANEL_X+PAD, y, 250, 32, g_trend_filter?C'41,128,185':clrSlateGray); y += 38;
   CreateButton(BRT+"BTN_LOOP", g_infinity_mode?"โหมด: [รันต่อเนื่อง]":"โหมด: [รอสัญญาณ RSI]", PANEL_X+PAD, y, 250, 32, g_infinity_mode?CLR_PURPLE_L:CLR_HEADER_BG); y += 38;
   CreateButton(BRT+"BTN_DBL", g_double_force?"Buy/Sell: [เปิด]":"Buy/Sell: [ปิด]", PANEL_X+PAD, y, 250, 32, g_double_force?C'46,204,113':clrSlateGray); y += 38;
   CreateButton(BRT+"BTN_HEDGE", g_mobile_hedge?"มือถือ: [เปิด]":"มือถือ: [ปิด]", PANEL_X+PAD, y, 250, 32, g_mobile_hedge?clrLimeGreen:clrSlateGray); y += 38;
   CreateButton(BRT+"BTN_AUTO", g_auto_mode?"ระบบ AUTO: [ทำงาน]":"ระบบ AUTO: [หยุด]", PANEL_X+PAD, y, 250, 32, g_auto_mode?clrDodgerBlue:CLR_LOSS); y += 45;

   CreateButton(BRT+"BTN_BUY", "ซื้อ (BUY)", PANEL_X+15, y, 115, 38, C'39,174,96'); 
   CreateButton(BRT+"BTN_SELL", "ขาย (SELL)", PANEL_X+140, y, 115, 38, C'192,57,43'); y += 45;
   CreateButton(BRT+"BTN_CLOSE", "ปิดทั้งหมด (CLOSE ALL)", PANEL_X+15, y, 240, 38, C'120,40,160'); y += 55;
   CreateButton(BRT+"BTN_ORDLINE", g_order_line_enabled?"เส้น: [เปิด]":"เส้น: [ปิด]", PANEL_X+PAD, y, 250, 32, g_order_line_enabled?C'155,89,182':clrSlateGray); 
y += 38;

   MakeRect(BRT+"DIV", PANEL_X+10, y, PANEL_W-20, 1, C'60,40,100'); y+=15;
   MakeLabel(BRT+"BAL_L", PANEL_X+PAD, y, "ยอดเงินคงเหลือ:", "Tahoma", 9, CLR_LABEL);
   MakeLabel(BRT+"BAL_V", PANEL_X+140, y, "0.00", "Tahoma", 9, CLR_VALUE); y+=ROW_H;
   MakeLabel(BRT+"MG_L", PANEL_X+PAD, y, "กำไรวันนี้ (USC):", "Tahoma", 9, CLR_LABEL);
   MakeLabel(BRT+"MG_V", PANEL_X+140, y, "0.00", "Tahoma", 9, CLR_PROFIT); y+=ROW_H;
   MakeLabel(BRT+"TREND_L", PANEL_X+PAD, y, "ทิศทางตลาด:", "Tahoma", 9, CLR_LABEL);
   MakeLabel(BRT+"TREND_V", PANEL_X+140, y, "รอสัญญาณ", "Tahoma", 9, CLR_VALUE); y+=ROW_H;
   MakeLabel(BRT+"POS_L", PANEL_X+PAD, y, "ไม้ที่ถือปัจจุบัน:", "Tahoma", 9, CLR_LABEL);
   MakeLabel(BRT+"POS_V", PANEL_X+140, y, "B: 0 | S: 0", "Tahoma", 9, CLR_GOLD); y+=ROW_H;

   MakeRect(BRT+"DIV2", PANEL_X+10, y+5, PANEL_W-20, 1, C'60,40,100'); y+=15;
   MakeLabel(BRT+"ATR_L", PANEL_X+PAD, y, "สถานะ ATR Step:", "Tahoma", 8, CLR_LABEL);
   MakeLabel(BRT+"ATR_V", PANEL_X+140, y, "Normal", "Tahoma", 8, CLR_GOLD); y+=18;
   
   MakeLabel(BRT+"STATUS_L", PANEL_X+PAD, y+5, "สถานะพอร์ต:", "Tahoma", 9, CLR_LABEL);
   MakeLabel(BRT+"STATUS_V", PANEL_X+140, y+5, "...", "Tahoma", 9, clrWhite); 

   // แสดง UI ฝั่งขวา
   DrawRightPanel();
   DrawHistoryPanel();
}


//+------------------------------------------------------------------+
//| DrawRightPanel - แสดง UI ฝั่งขวา (กำไร/ขาดทุน/DD/%)             |
//+------------------------------------------------------------------+
void DrawRightPanel()
{
   string P = BRT+"RP_";
   int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int pw = 230;
   int px = chart_w - pw - 15;
   int py = 20;
   int row = 20;

   // พื้นหลัง
   MakeRect(P+"BG", px, py, pw, 280, C'20,12,35');
   ObjectSetInteger(0, P+"BG", OBJPROP_BORDER_COLOR, C'80,50,120');
   ObjectSetInteger(0, P+"BG", OBJPROP_ZORDER, 0);

   // Header
   MakeRect(P+"HDR", px, py, pw, 32, C'75,40,110');
   ObjectSetInteger(0, P+"HDR", OBJPROP_ZORDER, 1);
   MakeLabel(P+"TITLE", px+10, py+7, "📊 สรุปพอร์ต", "Segoe UI", 10, CLR_GOLD);

   int y = py + 42;

   // --- Balance ---
   MakeLabel(P+"BAL_L", px+10, y, "Balance:", "Tahoma", 9, C'160,140,190');
   MakeLabel(P+"BAL_V", px+110, y, "0.00", "Tahoma", 9, CLR_VALUE);
   y += row;

   // --- Equity ---
   MakeLabel(P+"EQ_L", px+10, y, "Equity:", "Tahoma", 9, C'160,140,190');
   MakeLabel(P+"EQ_V", px+110, y, "0.00", "Tahoma", 9, CLR_VALUE);
   y += row;

   // --- Divider ---
   MakeRect(P+"DIV1", px+8, y, pw-16, 1, C'80,50,120');
   y += 8;

   // --- กำไร/ขาดทุนปัจจุบัน ---
   MakeLabel(P+"PNL_L", px+10, y, "กำไร/ขาดทุน:", "Tahoma", 9, C'160,140,190');
   MakeLabel(P+"PNL_V", px+110, y, "0.00", "Tahoma Bold", 11, CLR_PROFIT);
   y += row + 2;

   // --- กำไร % ---
   MakeLabel(P+"PCT_L", px+10, y, "กำไร %:", "Tahoma", 9, C'160,140,190');
   MakeLabel(P+"PCT_V", px+110, y, "0.00%", "Tahoma Bold", 11, CLR_PROFIT);
   y += row + 2;

   // --- Divider ---
   MakeRect(P+"DIV2", px+8, y, pw-16, 1, C'80,50,120');
   y += 8;

   // --- Drawdown ---
   MakeLabel(P+"DD_L", px+10, y, "Drawdown:", "Tahoma", 9, C'160,140,190');
   MakeLabel(P+"DD_V", px+110, y, "0.00", "Tahoma Bold", 10, CLR_LOSS);
   y += row;

   // --- DD % ---
   MakeLabel(P+"DDP_L", px+10, y, "DD %:", "Tahoma", 9, C'160,140,190');
   MakeLabel(P+"DDP_V", px+110, y, "0.00%", "Tahoma Bold", 10, CLR_LOSS);
   y += row + 2;

   // --- Divider ---
   MakeRect(P+"DIV3", px+8, y, pw-16, 1, C'80,50,120');
   y += 8;

   // --- กำไรวันนี้ ---
   MakeLabel(P+"DAY_L", px+10, y, "วันนี้:", "Tahoma", 9, C'160,140,190');
   MakeLabel(P+"DAY_V", px+110, y, "0.00", "Tahoma Bold", 10, CLR_GOLD);
   y += row;

   // --- จำนวนไม้ ---
   MakeLabel(P+"POS_L", px+10, y, "ไม้ทั้งหมด:", "Tahoma", 9, C'160,140,190');
   MakeLabel(P+"POS_V", px+110, y, "0", "Tahoma", 9, CLR_VALUE);
   y += row;

   // --- Margin Level ---
   MakeLabel(P+"MG_L", px+10, y, "Margin Lv:", "Tahoma", 9, C'160,140,190');
   MakeLabel(P+"MG_V", px+110, y, "0%", "Tahoma", 9, CLR_VALUE);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| UpdateRightPanel - อัปเดตค่าทุก tick                             |
//+------------------------------------------------------------------+
void UpdateRightPanel()
{
   string P = BRT+"RP_";

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double equ = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin_lv = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double pnl = equ - bal;
   double pnl_pct = (bal > 0) ? (pnl / bal) * 100.0 : 0;

   double dd = (pnl < 0) ? MathAbs(pnl) : 0;
   double dd_pct = (bal > 0 && pnl < 0) ? (MathAbs(pnl) / bal) * 100.0 : 0;

   string acc_curr = AccountInfoString(ACCOUNT_CURRENCY);
   double divider = (StringFind(acc_curr, "USC") >= 0 || StringFind(acc_curr, "Cent") >= 0) ? 100.0 : 1.0;
   double pnl_thb = (pnl / divider) * 32.0;
   double dd_thb  = (dd / divider) * 32.0;

   double daily_usc = GetDailyProfitUSC();
   double daily_thb = (daily_usc / divider) * 32.0;

   // จำนวนไม้
   int total_pos = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(PositionSelectByTicket(tk) && PositionGetString(POSITION_SYMBOL) == _Symbol)
         total_pos++;
   }

   // Balance & Equity
   ObjectSetString(0, P+"BAL_V", OBJPROP_TEXT, DoubleToString(bal, 2));
   ObjectSetString(0, P+"EQ_V", OBJPROP_TEXT, DoubleToString(equ, 2));

   // กำไร/ขาดทุน
   ObjectSetString(0, P+"PNL_V", OBJPROP_TEXT, DoubleToString(pnl_thb, 2) + " ฿");
   ObjectSetInteger(0, P+"PNL_V", OBJPROP_COLOR, pnl >= 0 ? CLR_PROFIT : CLR_LOSS);

   // กำไร %
   ObjectSetString(0, P+"PCT_V", OBJPROP_TEXT, DoubleToString(pnl_pct, 2) + "%");
   ObjectSetInteger(0, P+"PCT_V", OBJPROP_COLOR, pnl >= 0 ? CLR_PROFIT : CLR_LOSS);

   // Drawdown
   ObjectSetString(0, P+"DD_V", OBJPROP_TEXT, DoubleToString(dd_thb, 2) + " ฿");
   ObjectSetInteger(0, P+"DD_V", OBJPROP_COLOR, dd_pct > 20 ? clrRed : (dd_pct > 10 ? clrOrangeRed : CLR_LOSS));

   // DD %
   ObjectSetString(0, P+"DDP_V", OBJPROP_TEXT, DoubleToString(dd_pct, 2) + "%");
   ObjectSetInteger(0, P+"DDP_V", OBJPROP_COLOR, dd_pct > 20 ? clrRed : (dd_pct > 10 ? clrOrangeRed : CLR_LOSS));

   // กำไรวันนี้
   ObjectSetString(0, P+"DAY_V", OBJPROP_TEXT, DoubleToString(daily_thb, 2) + " ฿");
   ObjectSetInteger(0, P+"DAY_V", OBJPROP_COLOR, daily_thb >= 0 ? CLR_GOLD : CLR_LOSS);

   // จำนวนไม้
   ObjectSetString(0, P+"POS_V", OBJPROP_TEXT, IntegerToString(total_pos));

   // Margin Level
   string mg_txt = (margin_lv > 0) ? DoubleToString(margin_lv, 0) + "%" : "ไม่มีไม้";
   ObjectSetString(0, P+"MG_V", OBJPROP_TEXT, mg_txt);
   ObjectSetInteger(0, P+"MG_V", OBJPROP_COLOR, margin_lv > 500 ? CLR_PROFIT : (margin_lv > 200 ? CLR_GOLD : CLR_LOSS));

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| DrawHistoryPanel - ตารางกำไร/ขาดทุนย้อนหลัง 7 วัน (มุมขวาล่าง)  |
//+------------------------------------------------------------------+
void DrawHistoryPanel()
{
   string H = BRT+"HP_";
   int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int pw = 230;
   int ph = 220;
   int px = chart_w - pw - 15;
   int py = chart_h - ph - 15;
   int row = 22;

   // พื้นหลัง
   MakeRect(H+"BG", px, py, pw, ph, C'20,12,35');
   ObjectSetInteger(0, H+"BG", OBJPROP_BORDER_COLOR, C'80,50,120');
   ObjectSetInteger(0, H+"BG", OBJPROP_ZORDER, 0);

   // Header
   MakeRect(H+"HDR", px, py, pw, 28, C'75,40,110');
   ObjectSetInteger(0, H+"HDR", OBJPROP_ZORDER, 1);
   MakeLabel(H+"TITLE", px+10, py+5, "📅 ย้อนหลัง 7 วัน", "Segoe UI", 9, CLR_GOLD);

   int y = py + 34;

   // Column Headers
   MakeLabel(H+"COL_D", px+8,   y, "วัน", "Tahoma", 8, C'140,120,170');
   MakeLabel(H+"COL_P", px+55,  y, "กำไร(฿)", "Tahoma", 8, C'140,120,170');
   MakeLabel(H+"COL_L", px+120, y, "ขาดทุน(฿)", "Tahoma", 8, C'140,120,170');
   MakeLabel(H+"COL_N", px+190, y, "สุทธิ", "Tahoma", 8, C'140,120,170');
   y += 18;
   MakeRect(H+"DIV0", px+5, y, pw-10, 1, C'60,40,90');
   y += 4;

   // 7 rows for each day
   for(int d = 0; d < 7; d++)
   {
      string ds = IntegerToString(d);
      MakeLabel(H+"D"+ds, px+8,   y, "-", "Tahoma", 8, C'160,140,190');
      MakeLabel(H+"P"+ds, px+55,  y, "0", "Tahoma", 8, CLR_PROFIT);
      MakeLabel(H+"L"+ds, px+120, y, "0", "Tahoma", 8, CLR_LOSS);
      MakeLabel(H+"N"+ds, px+190, y, "0", "Tahoma", 8, CLR_VALUE);
      y += row;
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| UpdateHistoryPanel - อัปเดตข้อมูลย้อนหลัง 7 วัน                  |
//+------------------------------------------------------------------+
void UpdateHistoryPanel()
{
   string H = BRT+"HP_";
   string acc_curr = AccountInfoString(ACCOUNT_CURRENCY);
   double divider = (StringFind(acc_curr, "USC") >= 0 || StringFind(acc_curr, "Cent") >= 0) ? 100.0 : 1.0;

   MqlDateTime now_dt;
   TimeCurrent(now_dt);

   for(int d = 0; d < 7; d++)
   {
      // คำนวณวันที่
      datetime day_start = TimeCurrent() - (d * 86400);
      MqlDateTime dt;
      TimeToStruct(day_start, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      datetime from_time = StructToTime(dt);
      datetime to_time   = from_time + 86400;

      // ดึงประวัติ
      HistorySelect(from_time, to_time);
      int deals = HistoryDealsTotal();

      double day_profit = 0;
      double day_loss   = 0;

      for(int i = 0; i < deals; i++)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0) continue;
         if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol) continue;

         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_INOUT) continue;

         double p = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT)
                  + HistoryDealGetDouble(deal_ticket, DEAL_SWAP)
                  + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);

         if(p >= 0) day_profit += p;
         else       day_loss   += p;
      }

      double day_net = day_profit + day_loss;
      double profit_thb = (day_profit / divider) * 32.0;
      double loss_thb   = (day_loss / divider) * 32.0;
      double net_thb    = (day_net / divider) * 32.0;

      // ชื่อวัน
      string day_names[] = {"อา","จ","อ","พ","พฤ","ศ","ส"};
      string day_label = IntegerToString(dt.day) + "/" + IntegerToString(dt.mon)
                        + " " + day_names[dt.day_of_week];

      string ds = IntegerToString(d);
      ObjectSetString(0, H+"D"+ds, OBJPROP_TEXT, day_label);

      ObjectSetString(0, H+"P"+ds, OBJPROP_TEXT, DoubleToString(profit_thb, 0));
      ObjectSetInteger(0, H+"P"+ds, OBJPROP_COLOR, CLR_PROFIT);

      ObjectSetString(0, H+"L"+ds, OBJPROP_TEXT, DoubleToString(loss_thb, 0));
      ObjectSetInteger(0, H+"L"+ds, OBJPROP_COLOR, CLR_LOSS);

      ObjectSetString(0, H+"N"+ds, OBJPROP_TEXT, DoubleToString(net_thb, 0));
      ObjectSetInteger(0, H+"N"+ds, OBJPROP_COLOR, net_thb >= 0 ? CLR_PROFIT : CLR_LOSS);
   }

   ChartRedraw();
}
void UpdateUI(double bal, double equ, double mg, double daily_usc, int b_t, int s_t, double atr, double ma) {
   ObjectSetString(0, BRT+"BAL_V", OBJPROP_TEXT, DoubleToString(bal, 2));
   ObjectSetString(0, BRT+"MG_V", OBJPROP_TEXT, DoubleToString(daily_usc, 2));
   ObjectSetString(0, BRT+"POS_V", OBJPROP_TEXT, "B: "+(string)b_t+" | S: "+(string)s_t);
   string status = g_target_reached_today ? "เป้าแตก! (หยุด)" : (Inp_Use_Time_Filter && !IsThaiTimeWindow() ? "นอกเวลาทำงาน" : (g_auto_mode ? "บอทกำลังรัน" : "เทรดมือเอง"));
   ObjectSetString(0, BRT+"STATUS_V", OBJPROP_TEXT, status);
   ObjectSetInteger(0, BRT+"STATUS_V", OBJPROP_COLOR, g_target_reached_today ? CLR_LOSS : (g_auto_mode ? clrLime : CLR_GOLD));
   
   double cp = iClose(_Symbol, _Period, 0);
   string trend = (cp > ma) ? "ขาขึ้น ▲" : "ขาลง ▼";
   ObjectSetString(0, BRT+"TREND_V", OBJPROP_TEXT, trend);
   ObjectSetInteger(0, BRT+"TREND_V", OBJPROP_COLOR, (cp > ma)?clrLime:CLR_LOSS);
   
   ObjectSetString(0, BRT+"ATR_V", OBJPROP_TEXT, DoubleToString(atr/(_Point*10), 1)+" pips");
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == BRT+"BTN_TREND") { g_trend_filter = !g_trend_filter; ObjectSetString(0, sparam, OBJPROP_TEXT, g_trend_filter?"เทรนด์: [เปิดใช้งาน]":"เทรนด์: [ปิดใช้งาน]"); ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, g_trend_filter?C'41,128,185':clrSlateGray); }
      if(sparam == BRT+"BTN_DBL") { g_double_force = !g_double_force; ObjectSetString(0, sparam, OBJPROP_TEXT, g_double_force?"Buy/Sell: [เปิด]":"Buy/Sell: [ปิด]"); ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, g_double_force?C'46,204,113':clrSlateGray); }
      if(sparam == BRT+"BTN_LOOP") { g_infinity_mode = !g_infinity_mode; ObjectSetString(0, sparam, OBJPROP_TEXT, g_infinity_mode?"โหมด: [รันต่อเนื่อง]":"โหมด: [รอสัญญาณ RSI]"); ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, g_infinity_mode?CLR_PURPLE_L:CLR_HEADER_BG); }
      if(sparam == BRT+"BTN_HEDGE") { g_mobile_hedge = !g_mobile_hedge; ObjectSetString(0, sparam, OBJPROP_TEXT, g_mobile_hedge?"มือถือ: [เปิด]":"มือถือ: [ปิด]"); ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, g_mobile_hedge?clrLimeGreen:clrSlateGray); }
      if(sparam == BRT+"BTN_AUTO") { g_auto_mode = !g_auto_mode; ObjectSetString(0, sparam, OBJPROP_TEXT, g_auto_mode?"ระบบ AUTO: [ทำงาน]":"ระบบ AUTO: [หยุด]"); ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, g_auto_mode?clrDodgerBlue:CLR_LOSS); }
      if(sparam == BRT+"BTN_BUY")  { trade.SetExpertMagicNumber(Inp_Magic); trade.Buy(SafeLot(Inp_BaseLot)); if(!g_trend_filter && g_double_force) trade.Sell(SafeLot(Inp_BaseLot)); lastTradeTime = TimeCurrent(); }
      if(sparam == BRT+"BTN_SELL") { trade.SetExpertMagicNumber(Inp_Magic); trade.Sell(SafeLot(Inp_BaseLot)); if(!g_trend_filter && g_double_force) trade.Buy(SafeLot(Inp_BaseLot)); lastTradeTime = TimeCurrent(); }
      if(sparam == BRT+"BTN_CLOSE") { CloseAll(); last_basket_close = TimeCurrent(); }
      if(sparam == BRT+"BTN_ORDLINE") { g_order_line_enabled = !g_order_line_enabled; ObjectSetString(0, sparam, OBJPROP_TEXT, g_order_line_enabled?"เส้นฉลาด: [เปิด]":"เส้นฉลาด: [ปิด]"); ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, g_order_line_enabled?C'155,89,182':clrSlateGray); if(g_order_line_enabled) DrawOrderLines(); else DeleteOrderLines(); }
      
      // ปุ่ม X ปิด UI
      if(sparam == BRT+"CLOSE_UI_BG" || sparam == BRT+"CLOSE_UI_X") {
         g_ui_visible = false;
         CleanupVisual();
         DrawOpenButton();
         ChartRedraw();
         return;
      }
      
      // ปุ่มเปิด UI (ตอนซ่อน)
      if(sparam == BRT+"OPEN_BG" || sparam == BRT+"OPEN_LBL") {
         g_ui_visible = true;
         DeleteOpenButton();
         DrawUI();
         ChartRedraw();
         return;
      }
      
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false); ChartRedraw();
   }
}

// *** แก้ไข: แยก Magic หลัก ไม่ให้ยุ่งกับไม้ 0 หรือไม้เสริม ***
void ApplyBasketTrailing(ENUM_POSITION_TYPE type, double avg_price, double profit_usd, double total_vol) {
   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE), tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double current_points = (profit_usd) / (total_vol * tick_val / tick_size) / _Point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Auto SL: คำนวณค่าจาก ATR อัตโนมัติ
   int be_trigger = Inp_BE_Trigger;
   int be_lock = Inp_BE_Lock;
   int trail_stop = Inp_Trail_Stop;
   int trail_step = Inp_Trail_Step;

   if(Inp_Auto_SL)
   {
      double atr_v[];
      ArraySetAsSeries(atr_v, true);
      if(CopyBuffer(h_atr, 0, 0, 1, atr_v) > 0 && atr_v[0] > 0)
      {
         int atr_pts = (int)(atr_v[0] / _Point);
         be_trigger = (int)(atr_pts * 1.5);
         be_lock    = (int)(atr_pts * 0.5);
         trail_stop = (int)(atr_pts * 1.2);
         trail_step = (int)(atr_pts * 0.15);
         if(be_trigger < 50) be_trigger = 50;
         if(be_lock < 20) be_lock = 20;
         if(trail_stop < 50) trail_stop = 50;
         if(trail_step < 10) trail_step = 10;
      }
   }

   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong tk = PositionGetTicket(i);
      if(PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC) == Inp_Magic && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         double sl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
         double op = PositionGetDouble(POSITION_PRICE_OPEN);
         if(type == POSITION_TYPE_BUY) {
            double be_price = NormalizeDouble(avg_price + (be_lock * _Point), _Digits);
            // กัน SL ต่ำกว่าราคาเปิดของไม้ (ป้องกันขาดทุน)
            if(be_price < op) be_price = NormalizeDouble(op + _Point, _Digits);
            if(current_points >= be_trigger && (sl < avg_price)) trade.PositionModify(tk, be_price, tp);
            double trail_price = NormalizeDouble(bid - (trail_stop * _Point), _Digits);
            // กัน trail SL ต่ำกว่าราคาเปิด
            if(trail_price < op) trail_price = NormalizeDouble(op + _Point, _Digits);
            if(sl >= avg_price && trail_price > sl + (trail_step * _Point) && trail_price > avg_price) trade.PositionModify(tk, trail_price, tp);
         } else {
            double be_price = NormalizeDouble(avg_price - (be_lock * _Point), _Digits);
            // กัน SL สูงกว่าราคาเปิดของไม้ (ป้องกันขาดทุน)
            if(be_price > op) be_price = NormalizeDouble(op - _Point, _Digits);
            if(current_points >= be_trigger && (sl > avg_price || sl == 0)) trade.PositionModify(tk, be_price, tp);
            double trail_price = NormalizeDouble(ask + (trail_stop * _Point), _Digits);
            // กัน trail SL สูงกว่าราคาเปิด
            if(trail_price > op) trail_price = NormalizeDouble(op - _Point, _Digits);
            if(sl != 0 && sl <= avg_price && trail_price < sl - (trail_step * _Point) && trail_price < avg_price) trade.PositionModify(tk, trail_price, tp);
         }
      }
   }
}

bool CheckGlobalBasketExit(double profit_thb, double profit_usd, double total_vol) {
   if(total_vol <= 0) return false;
   double current_points = (profit_usd) / (total_vol * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)) / _Point;
   if(current_points >= Inp_Target_Points && profit_thb >= Inp_Min_Profit_THB) { CloseAllProfitOnly(); return true; } return false;
}

void UpdateHardTP(ENUM_POSITION_TYPE type, double avg_price, double total_vol, double divider) {
   double points_needed = (Inp_Exit_Mode == Money_Target) ? ((Inp_Target_THB / 35.0) * divider) / (total_vol * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)) : Inp_Target_Points * _Point;
   double tp_price = (type == POSITION_TYPE_BUY) ? (avg_price + points_needed) : (avg_price - points_needed);
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == Inp_Magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         if(MathAbs(PositionGetDouble(POSITION_TP) - tp_price) > _Point * 10) trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), NormalizeDouble(tp_price, _Digits));
   }
}

void SaveChartColors() { g_bg=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND); g_fg=(color)ChartGetInteger(0,CHART_COLOR_FOREGROUND); g_grid=(color)ChartGetInteger(0,CHART_COLOR_GRID); g_up=(color)ChartGetInteger(0,CHART_COLOR_CHART_UP); g_down=(color)ChartGetInteger(0,CHART_COLOR_CHART_DOWN); }
void RestoreChartColors() { ChartSetInteger(0,CHART_COLOR_BACKGROUND,g_bg); ChartSetInteger(0,CHART_COLOR_FOREGROUND,g_fg); ChartSetInteger(0,CHART_COLOR_GRID,g_grid); ChartSetInteger(0,CHART_COLOR_CHART_UP,g_up); ChartSetInteger(0,CHART_COLOR_CHART_DOWN,g_down); ChartRedraw(); }
void ApplyDarkTheme() { ChartSetInteger(0, CHART_COLOR_BACKGROUND, C'10,5,20'); ChartSetInteger(0, CHART_COLOR_FOREGROUND, C'160,160,180'); ChartSetInteger(0, CHART_COLOR_GRID, C'30,20,45'); ChartSetInteger(0, CHART_COLOR_CHART_UP, C'142,68,173'); ChartSetInteger(0, CHART_COLOR_CHART_DOWN, C'75,0,130'); ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, C'142,68,173'); ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, C'75,0,130'); ChartSetInteger(0, CHART_MODE, CHART_CANDLES); ChartRedraw(); }

// --- [แทรกระบบคำนวณ THB ที่คุณขอ โดยไม่แก้โครงเก่า] ---
void TrySurvivorClear(ENUM_POSITION_TYPE t) {
   ulong bt=0, wt=0; double max_p=-999999, min_p=999999;
   for(int i=0; i<PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == t && PositionGetInteger(POSITION_MAGIC) == Inp_Magic) {
         double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(p > max_p) { max_p = p; bt = ticket; } if(p < min_p) { min_p = p; wt = ticket; }
      }
   }
   
   string acc_curr = AccountInfoString(ACCOUNT_CURRENCY);
   double divider = (StringFind(acc_curr, "USC") >= 0 || StringFind(acc_curr, "Cent") >= 0) ? 100.0 : 1.0;
   
   if(bt > 0 && wt > 0 && bt != wt) { 
      double diff_raw = max_p + min_p; 
      double diff_thb = (diff_raw / divider) * 32.0;
      if(diff_thb >= Inp_Survivor_Clear_THB) { 
         is_processing = true; trade.PositionClose(bt); trade.PositionClose(wt); is_processing = false; 
      }
   }
}

// --- [เพิ่มระบบแทรกใหม่: Cross Survivor] ---
void TryCrossSurvivorClear(double divider) {
   ulong best_tk=0, worst_tk=0; 
   double max_p=-9999999, min_p=9999999;
   int best_type = -1;
   
   for(int i=0; i<PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         long m = PositionGetInteger(POSITION_MAGIC);
         if(m == Inp_Magic) { 
            double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            if(p > max_p) { max_p = p; best_tk = ticket; best_type = (int)PositionGetInteger(POSITION_TYPE); }
         }
      }
   }
   
   if(best_tk > 0 && best_type != -1) {
      int target_type = (best_type == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
      for(int i=0; i<PositionsTotal(); i++) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == target_type) {
            long m = PositionGetInteger(POSITION_MAGIC);
            if(m == Inp_Magic) {
               double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
               if(p < min_p) { min_p = p; worst_tk = ticket; }
            }
         }
      }
   }
   
   if(best_tk > 0 && worst_tk > 0) { 
      double diff_raw = max_p + min_p; 
      double diff_thb = (diff_raw / divider) * 32.0;
      if(diff_thb >= Inp_Survivor_Clear_THB) { 
         is_processing = true; 
         trade.PositionClose(best_tk); 
         trade.PositionClose(worst_tk); 
         is_processing = false; 
      }
   }
}
// ----------------------------------------

void CloseSide(ENUM_POSITION_TYPE t) { for(int i=PositionsTotal()-1; i>=0; i--) { ulong ticket = PositionGetTicket(i); if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == t && (PositionGetInteger(POSITION_MAGIC) == Inp_Magic || PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic || PositionGetInteger(POSITION_MAGIC) == Inp_Support_Magic || PositionGetInteger(POSITION_MAGIC) == Inp_Pull_Magic)) trade.PositionClose(ticket); } }

void CloseAll() { 
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && (PositionGetInteger(POSITION_MAGIC) == Inp_Magic || PositionGetInteger(POSITION_MAGIC) == Inp_Support_Magic || PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic || PositionGetInteger(POSITION_MAGIC) == Inp_Pull_Magic)) trade.PositionClose(ticket);
   }
   g_rescue_active = false;
   g_last_buy_rescue_lot = 0;
   g_last_sell_rescue_lot = 0;
}

// --- CloseSideProfitOnly: ปิดเฉพาะไม้ที่กำไร ---
void CloseSideProfitOnly(ENUM_POSITION_TYPE t) {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != t) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != Inp_Magic && magic != Inp_Rescue_Magic &&
         magic != Inp_Support_Magic && magic != Inp_Pull_Magic) continue;
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(profit >= 0) trade.PositionClose(ticket);
   }
}

// --- CloseAllProfitOnly: ปิดเฉพาะไม้ที่กำไร (ไม่ตัดขาดทุน) ---
void CloseAllProfitOnly() {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != Inp_Magic && magic != Inp_Support_Magic &&
         magic != Inp_Rescue_Magic && magic != Inp_Pull_Magic) continue;
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(profit >= 0) trade.PositionClose(ticket);
   }
}

void MakeRect(string n, int x, int y, int xs, int ys, color c) { ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,n,OBJPROP_XSIZE,xs); ObjectSetInteger(0,n,OBJPROP_YSIZE,ys); ObjectSetInteger(0,n,OBJPROP_BGCOLOR,c); ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,n,OBJPROP_ZORDER,0); }
void MakeLabel(string n, int x, int y, string t, string font, int s, color c) { ObjectCreate(0,n,OBJ_LABEL,0,0,0); ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y); ObjectSetString(0,n,OBJPROP_TEXT,t); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,s); ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetString(0,n,OBJPROP_FONT,font); ObjectSetInteger(0,n,OBJPROP_ZORDER,10); }
void CreateButton(string n, string t, int x, int y, int xs, int ys, color c) { ObjectCreate(0,n,OBJ_BUTTON,0,0,0); ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,n,OBJPROP_XSIZE,xs); ObjectSetInteger(0,n,OBJPROP_YSIZE,ys); ObjectSetString(0,n,OBJPROP_TEXT,t); ObjectSetInteger(0,n,OBJPROP_BGCOLOR,c); ObjectSetInteger(0,n,OBJPROP_COLOR,clrWhite); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,9); ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,n,OBJPROP_ZORDER,20); }
void CleanupVisual() { ObjectsDeleteAll(0, BRT); }



void CheckLicense() {
   is_authorized = false;
   long server_acc = AccountInfoInteger(ACCOUNT_LOGIN);
   if(Inp_Account != server_acc) { 
      Print("❌ เลขบัญชีไม่ตรง! บัญชีปัจจุบัน: ", server_acc);
      return; 
   }
   long secret_math = Inp_Account + 5553052547; 
   string encoded_key = GenerateKey(secret_math);
   string master_key = "BT-" + encoded_key; 
   if(Inp_SerialKey == master_key) {
      is_authorized = true;
      expire_date = D'2026.06.01';
      Print("✅ ปลดล็อคสำเร็จ!");
   } else { 
      Print("❌ Serial Key ผิด!"); 
   }
}


string GenerateKey(long code) {
   string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
   string res = "";
   while(code > 0) { res = StringSubstr(chars, (int)(code % 62), 1) + res; code /= 62; }
   return res;
}

// --- [ระบบเส้นฉลาดเลือกทาง Smart Order Line] ---
int GetSmartOrderLinePath() {
   double rsi_v[], ma_v[];
   ArraySetAsSeries(rsi_v, true);
   ArraySetAsSeries(ma_v, true);

   if(CopyBuffer(h_rsi, 0, 0, 1, rsi_v) <= 0) return 0;
   if(CopyBuffer(h_ma, 0, 0, 1, ma_v) <= 0) return 0;

   double close_m15 = iClose(_Symbol, PERIOD_H1, 0);
   double momentum = (iClose(_Symbol, PERIOD_M1, 0) - iOpen(_Symbol, PERIOD_M1, 0)) / _Point;

   bool uptrend = close_m15 > ma_v[0];
   bool downtrend = close_m15 < ma_v[0];

   if(uptrend && rsi_v[0] < Inp_RSI_High && momentum >= -50) return 1;
   if(downtrend && rsi_v[0] > Inp_RSI_Low && momentum <= 50) return -1;

   if(rsi_v[0] <= Inp_RSI_Low && momentum > 0) return 1;
   if(rsi_v[0] >= Inp_RSI_High && momentum < 0) return -1;

   return 0;
}

//ระบบคำนวณตำแหน่งเส้น Order Line แบบ Smart (ใช้ ATR ปรับระยะอัตโนมัติ)
double GetSmartOrderLinePrice(int path) {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double atr_v[];
   ArraySetAsSeries(atr_v, true);

   double atr_points = 0;
   if(CopyBuffer(h_atr, 0, 0, 1, atr_v) > 0)
      atr_points = atr_v[0] / _Point;

   int base_offset = (path == 1) ? Inp_OL_Buy_Offset : Inp_OL_Sell_Offset;
   double smart_offset = MathMax((double)base_offset, atr_points * 0.3);
   if(path == 1)
      return NormalizeDouble(bid - smart_offset * _Point, _Digits);

   if(path == -1)
      return NormalizeDouble(ask + smart_offset * _Point, _Digits);

   return 0.0;
}

//ระบบวางเส้น BUY / SELL (Order Line Generator / Smart Zone Creator)
void DrawOrderLines() {
   double buy_price = 0.0;
   double sell_price = 0.0;

   if(Inp_OL_Smart_Path) {
      g_ol_path = GetSmartOrderLinePath();

      if(Inp_OL_One_Side_Only) {
         if(g_ol_path == 1) buy_price = GetSmartOrderLinePrice(1);
         if(g_ol_path == -1) sell_price = GetSmartOrderLinePrice(-1);
      } else {
         buy_price = GetSmartOrderLinePrice(1);
         sell_price = GetSmartOrderLinePrice(-1);
      }
   } else {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      buy_price = Inp_OL_Auto_Mode ? (bid - Inp_OL_Buy_Offset * _Point) : Inp_OL_Buy_Price;
      sell_price = Inp_OL_Auto_Mode ? (ask + Inp_OL_Sell_Offset * _Point) : Inp_OL_Sell_Price;
      g_ol_path = 0;
   }

   if(Inp_OL_One_Side_Only && Inp_OL_Smart_Path) {
      if(g_ol_path != 1 && ObjectFind(0, BRT+"OL_BUY") >= 0) ObjectDelete(0, BRT+"OL_BUY");
      if(g_ol_path != -1 && ObjectFind(0, BRT+"OL_SELL") >= 0) ObjectDelete(0, BRT+"OL_SELL");

      g_buy_line_created = (g_ol_path == 1);
      g_sell_line_created = (g_ol_path == -1);
   }

   if(buy_price > 0) {
      string n = BRT+"OL_BUY";

      if(ObjectFind(0, n) < 0)
         ObjectCreate(0, n, OBJ_HLINE, 0, 0, buy_price);

      ObjectSetDouble(0, n, OBJPROP_PRICE, buy_price);
      ObjectSetInteger(0, n, OBJPROP_COLOR, Inp_OL_Buy_Color);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, Inp_OL_Width);
      ObjectSetInteger(0, n, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, true);
      ObjectSetString(0, n, OBJPROP_TOOLTIP, "Smart Buy Level: " + DoubleToString(buy_price, _Digits));

      g_buy_line_created = true;
      g_buy_line_price = buy_price;
      g_buy_line_triggered = false;
   }

   if(sell_price > 0) {
      string n = BRT+"OL_SELL";

      if(ObjectFind(0, n) < 0)
         ObjectCreate(0, n, OBJ_HLINE, 0, 0, sell_price);

      ObjectSetDouble(0, n, OBJPROP_PRICE, sell_price);
      ObjectSetInteger(0, n, OBJPROP_COLOR, Inp_OL_Sell_Color);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, Inp_OL_Width);
      ObjectSetInteger(0, n, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, true);
      ObjectSetString(0, n, OBJPROP_TOOLTIP, "Smart Sell Level: " + DoubleToString(sell_price, _Digits));

      g_sell_line_created = true;
      g_sell_line_price = sell_price;
      g_sell_line_triggered = false;
   }

   g_ol_last_plan = TimeCurrent();
   ChartRedraw();
}

//ระบบลบเส้น Order Line + รีเซ็ตสถานะทั้งหมดของโหมดเส้น
void DeleteOrderLines() {
   if(ObjectFind(0, BRT+"OL_BUY") >= 0) ObjectDelete(0, BRT+"OL_BUY");
   if(ObjectFind(0, BRT+"OL_SELL") >= 0) ObjectDelete(0, BRT+"OL_SELL");

   g_buy_line_created = false;
   g_sell_line_created = false;
   g_buy_line_triggered = false;
   g_sell_line_triggered = false;
   g_buy_line_price = 0.0;
   g_sell_line_price = 0.0;
   g_ol_path = 0;
   g_ol_last_plan = 0;

   ChartRedraw();
}

//ระบบเข้าออเดอร์อัตโนมัติจากเส้นที่วาดไว้ (Order Line Trigger System)
void CheckOrderLineHit() {
   if(!g_order_line_enabled) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(Inp_OL_Smart_Path && TimeCurrent() - g_ol_last_plan >= Inp_OL_Replan_Sec) {
      if(!g_buy_line_triggered && !g_sell_line_triggered)
         DrawOrderLines();
   }

   if(g_buy_line_triggered && bid > g_buy_line_price + Inp_OL_Reset_Buffer * _Point)
      g_buy_line_triggered = false;

   if(g_sell_line_triggered && ask < g_sell_line_price - Inp_OL_Reset_Buffer * _Point)
      g_sell_line_triggered = false;

   if(g_buy_line_created && ObjectFind(0, BRT+"OL_BUY") >= 0 && !g_buy_line_triggered) {
      g_buy_line_price = ObjectGetDouble(0, BRT+"OL_BUY", OBJPROP_PRICE);

      if(MathAbs(bid - g_buy_line_price) <= Inp_OL_Trigger_Buffer * _Point) {
         trade.SetExpertMagicNumber(Inp_Magic);

         if(trade.Buy(SafeLot(Inp_BaseLot), _Symbol, 0, 0, 0, "Smart Order Line Buy")) {
            lastTradeTime = TimeCurrent();
            if(Inp_Use_Support) OpenSupportOrder();

            DeleteOrderLines();
            g_order_line_enabled = true;

            Print("Smart Line Buy Triggered @ ", DoubleToString(bid, _Digits));
         }
      }
   }

   if(g_sell_line_created && ObjectFind(0, BRT+"OL_SELL") >= 0 && !g_sell_line_triggered) {
      g_sell_line_price = ObjectGetDouble(0, BRT+"OL_SELL", OBJPROP_PRICE);

      if(MathAbs(ask - g_sell_line_price) <= Inp_OL_Trigger_Buffer * _Point) {
         trade.SetExpertMagicNumber(Inp_Magic);

         if(trade.Sell(SafeLot(Inp_BaseLot), _Symbol, 0, 0, 0, "Smart Order Line Sell")) {
            lastTradeTime = TimeCurrent();
            if(Inp_Use_Support) OpenSupportOrder();

            DeleteOrderLines();
            g_order_line_enabled = true;

            Print("Smart Line Sell Triggered @ ", DoubleToString(ask, _Digits));
         }
      }
   }
}

// --- [ระบบกู้พอร์ตเมื่อโดนลากหนัก Panic Rescue] ---
double GetMoneyPerPointPerLot() {
   double tick_val = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tick_val <= 0 || tick_size <= 0 || _Point <= 0)
      return 0.0;

   return tick_val * (_Point / tick_size);
}

int CountRescueOrders() {
   int count = 0;

   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket)
         && PositionGetString(POSITION_SYMBOL) == _Symbol
         && PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic) {
         count++;
      }
   }

   return count;
}

double GetRescueProfit() {
   double profit = 0.0;

   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket)
         && PositionGetString(POSITION_SYMBOL) == _Symbol
         && PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic) {
         profit += PositionGetDouble(POSITION_PROFIT)
                 + PositionGetDouble(POSITION_SWAP);
      }
   }

   return profit;
}

//ระบบเช็คว่าไม้แก้ (Rescue) ควรเข้าไหม โดยดูเทรนด์ก่อน
bool IsRescueTrendConfirmed(
   ENUM_POSITION_TYPE rescue_type
)
{
   if(!Inp_Rescue_Trend_Only)
      return true;

   // ===== EMA =====
   int fastHandle =
      iMA(
         _Symbol,
         PERIOD_M5,
         5,
         0,
         MODE_EMA,
         PRICE_CLOSE
      );

   int slowHandle =
      iMA(
         _Symbol,
         PERIOD_M5,
         20,
         0,
         MODE_EMA,
         PRICE_CLOSE
      );

   double fastMA[];
   double slowMA[];

   ArraySetAsSeries(
      fastMA,
      true
   );

   ArraySetAsSeries(
      slowMA,
      true
   );

   if(CopyBuffer(
      fastHandle,
      0,
      0,
      1,
      fastMA
   ) <= 0)
      return false;

   if(CopyBuffer(
      slowHandle,
      0,
      0,
      1,
      slowMA
   ) <= 0)
      return false;

   // ราคาแท่งล่าสุด
   double close1 =
      iClose(
         _Symbol,
         PERIOD_M5,
         1
      );

   // เช็กเทรนด์ปัจจุบัน
   bool trendUp =
      (
         close1 > fastMA[0]
      )
      &&
      (
         fastMA[0] > slowMA[0]
      );

   bool trendDown =
      (
         close1 < fastMA[0]
      )
      &&
      (
         fastMA[0] < slowMA[0]
      );

   // ติด Buy -> รอขึ้น
   if(rescue_type ==
      POSITION_TYPE_BUY)
   {
      return trendUp;
   }

   // ติด Sell -> รอลง
   if(rescue_type ==
      POSITION_TYPE_SELL)
   {
      return trendDown;
   }

   return false;
}

//นับจำนวน Rescue ต่อฝั่ง
int CountRescueBySide(ENUM_POSITION_TYPE side) {
   int count = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong t = PositionGetTicket(i);
      if(PositionSelectByTicket(t)
         && PositionGetString(POSITION_SYMBOL) == _Symbol
         && PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic
         && PositionGetInteger(POSITION_TYPE) == side)
         count++;
   }
   return count;
}

//กำไรรวม Rescue ต่อฝั่ง
double GetRescueSideProfit(ENUM_POSITION_TYPE side) {
   double profit = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong t = PositionGetTicket(i);
      if(PositionSelectByTicket(t)
         && PositionGetString(POSITION_SYMBOL) == _Symbol
         && PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic
         && PositionGetInteger(POSITION_TYPE) == side)
         profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return profit;
}

//ราคาเปิดล่าสุดของ Rescue ต่อฝั่ง
bool GetLastRescuePrice(ENUM_POSITION_TYPE side, double &price, double &vol) {
   datetime last_time = 0;
   bool found = false;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong t = PositionGetTicket(i);
      if(PositionSelectByTicket(t)
         && PositionGetString(POSITION_SYMBOL) == _Symbol
         && PositionGetInteger(POSITION_MAGIC) == Inp_Rescue_Magic
         && PositionGetInteger(POSITION_TYPE) == side) {
         datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
         if(ot > last_time) {
            last_time = ot;
            price = PositionGetDouble(POSITION_PRICE_OPEN);
            vol = PositionGetDouble(POSITION_VOLUME);
            found = true;
         }
      }
   }
   return found;
}

//เช็คความแรงของเทรนด์ (จุดห่างระหว่าง EMA5 กับ EMA20)
double GetTrendStrength() {
   int fastHandle = iMA(_Symbol, PERIOD_M5, 5, 0, MODE_EMA, PRICE_CLOSE);
   int slowHandle = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
   double fastMA[], slowMA[];
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   double result = 0;
   if(CopyBuffer(fastHandle, 0, 0, 1, fastMA) > 0 && CopyBuffer(slowHandle, 0, 0, 1, slowMA) > 0)
      result = MathAbs(fastMA[0] - slowMA[0]) / _Point;
   IndicatorRelease(fastHandle);
   IndicatorRelease(slowHandle);
   return result;
}

//ระบบคำนวณขนาดล็อตของไม้แก้ (Rescue Lot Calculator)
// คูณ conservative: ไม้ที่ n = BaseLot * (1 + n * 0.5)
// ไม้ 1 = 0.01, ไม้ 2 = 0.015, ไม้ 3 = 0.02 (สูงสุด)
double CalcRescueLot(double loss_usd, int rescue_count) {
   double mult = 1.0 + (rescue_count * 0.5);  // 0→1.0, 1→1.5, 2→2.0
   double lot = SafeLot(Inp_BaseLot * mult);
   lot = MathMin(lot, Inp_Rescue_Max_Lot);    // ห้ามเกิน 0.02
   return lot;
}

//ระบบปิดออเดอร์ทั้งหมดของ แต่จะเฉพาะ:ไม้หลัก (Main order) ไม้แก้ (Rescue order)
void CloseMainAndRescue() {
   is_processing = true;

   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket)
         && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         long magic = PositionGetInteger(POSITION_MAGIC);

         if(magic == Inp_Magic || magic == Inp_Rescue_Magic || magic == Inp_Pull_Magic) {
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            if(profit >= 0) trade.PositionClose(ticket);
         }
      }
   }

   g_rescue_active = false;
   g_last_buy_rescue_lot = 0;
   g_last_sell_rescue_lot = 0;
   is_processing = false;
   last_basket_close = TimeCurrent();
}

void CheckPanicRescue(double divider)
{
   // รีเซ็ตสถานะ ถ้าไม่มีไม้แก้แล้ว
   if(CountRescueOrders() == 0)
   {
      g_rescue_active = false;
      g_last_buy_rescue_lot = 0;
      g_last_sell_rescue_lot = 0;
   }

   // ถ้ามี rescue อยู่ เช็คกำไรรวม ถ้าถึงเป้าปิดรวบ
   if(g_rescue_active && CountRescueOrders() > 0)
   {
      double total_usd = 0;
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(PositionSelectByTicket(t) && PositionGetString(POSITION_SYMBOL)==_Symbol)
         {
            long mg = PositionGetInteger(POSITION_MAGIC);
            if(mg==Inp_Magic || mg==Inp_Rescue_Magic)
               total_usd += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
         }
      }
      double total_thb = (total_usd/divider)*32.0;
      if(total_thb >= Inp_Rescue_Close_THB)
      {
         Print("Rescue ปิดรวบ | กำไร THB: ", DoubleToString(total_thb,2));
         CloseMainAndRescue();
      }
   }

   int b_t = 0, s_t = 0;
   double b_vol = 0.0, s_vol = 0.0;
   double b_cost = 0.0, s_cost = 0.0;
   double b_profit = 0.0, s_profit = 0.0;

   // อ่านไม้หลัก
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)
         && PositionGetString(POSITION_SYMBOL) == _Symbol
         && PositionGetInteger(POSITION_MAGIC) == Inp_Magic)
      {
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double vol = PositionGetDouble(POSITION_VOLUME);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

         if(type == POSITION_TYPE_BUY)
         { b_t++; b_vol += vol; b_cost += open_price * vol; b_profit += profit; }
         else
         { s_t++; s_vol += vol; s_cost += open_price * vol; s_profit += profit; }
      }
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double trend_strength = GetTrendStrength();

   // === Buy หลักโดนลากลงหนัก → เปิด Sell Rescue ===
   if(b_t >= Inp_Rescue_Min_Orders && b_vol > 0 && b_profit < 0)
   {
      double avg_buy = b_cost / b_vol;
      double drag_points = (avg_buy - bid) / _Point;
      int sell_rescue_count = CountRescueBySide(POSITION_TYPE_SELL);
      double required_drag = Inp_Rescue_Trigger_Points + (sell_rescue_count * 300.0);

      if(drag_points >= required_drag)
      {
         bool sell_trend_ok = IsRescueTrendConfirmed(POSITION_TYPE_SELL);
         bool buy_trend_ok  = IsRescueTrendConfirmed(POSITION_TYPE_BUY);
         bool do_sell_rescue = sell_trend_ok;
         bool do_buy_reverse = (Inp_Rescue_Reverse_Mode && buy_trend_ok && !sell_trend_ok);

         if(do_sell_rescue || do_buy_reverse)
         {
            // Cooldown ระหว่าง rescue
            if(TimeCurrent() - g_rescue_last_open < 300) return; // 5 นาที
            if(!IsNewM5Bar()) return;

            // จำกัดสูงสุด 3 rescue ต่อฝั่ง
            ENUM_POSITION_TYPE rescue_side = do_buy_reverse ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            if(CountRescueBySide(rescue_side) >= 3) return;

            // ถ้ามี rescue ก่อนหน้า ต้องขาดทุนด้วย (เทรนด์ยังไม่กลับ)
            if(CountRescueBySide(rescue_side) > 0 && GetRescueSideProfit(rescue_side) >= 0) return;

            // เทรนด์ต้องแรงพอ (EMA ห่างกัน > 200 จุด)
            if(trend_strength < 200.0) return;

            double lot = CalcRescueLot(b_profit, CountRescueBySide(rescue_side));

            if(do_buy_reverse)
            {
               trade.SetExpertMagicNumber(Inp_Rescue_Magic);
               if(trade.Buy(lot, _Symbol, 0, 0, 0, "Reverse Buy Rescue #"+IntegerToString(CountRescueBySide(POSITION_TYPE_BUY)+1)))
               {
                  lastTradeTime = TimeCurrent();
                  g_rescue_active = true;
                  g_rescue_last_open = TimeCurrent();
                  g_last_rescue_side = POSITION_TYPE_BUY;
                  g_last_buy_rescue_lot = lot;
                  Print("Reverse Buy Rescue | #", CountRescueBySide(POSITION_TYPE_BUY), " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag_points,0), " TrendStr=", DoubleToString(trend_strength,0));
               }
            }
            else
            {
               trade.SetExpertMagicNumber(Inp_Rescue_Magic);
               if(trade.Sell(lot, _Symbol, 0, 0, 0, "Rescue Sell #"+IntegerToString(CountRescueBySide(POSITION_TYPE_SELL)+1)))
               {
                  lastTradeTime = TimeCurrent();
                  g_rescue_active = true;
                  g_rescue_last_open = TimeCurrent();
                  g_last_rescue_side = POSITION_TYPE_SELL;
                  g_last_sell_rescue_lot = lot;
                  Print("Rescue Sell | #", CountRescueBySide(POSITION_TYPE_SELL), " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag_points,0), " TrendStr=", DoubleToString(trend_strength,0));
               }
            }
         }
      }
   }

   // === Sell หลักโดนลากขึ้นหนัก → เปิด Buy Rescue ===
   if(s_t >= Inp_Rescue_Min_Orders && s_vol > 0 && s_profit < 0)
   {
      double avg_sell = s_cost / s_vol;
      double drag_points = (ask - avg_sell) / _Point;
      int buy_rescue_count = CountRescueBySide(POSITION_TYPE_BUY);
      double required_drag = Inp_Rescue_Trigger_Points + (buy_rescue_count * 300.0);

      if(drag_points >= required_drag)
      {
         bool buy_trend_ok  = IsRescueTrendConfirmed(POSITION_TYPE_BUY);
         bool sell_trend_ok = IsRescueTrendConfirmed(POSITION_TYPE_SELL);
         bool do_buy_rescue   = buy_trend_ok;
         bool do_sell_reverse = (Inp_Rescue_Reverse_Mode && sell_trend_ok && !buy_trend_ok);

         if(do_buy_rescue || do_sell_reverse)
         {
            if(TimeCurrent() - g_rescue_last_open < 300) return;
            if(!IsNewM5Bar()) return;

            ENUM_POSITION_TYPE rescue_side = do_sell_reverse ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
            if(CountRescueBySide(rescue_side) >= 3) return;

            // ถ้ามี rescue ก่อนหน้า ต้องขาดทุนด้วย
            if(CountRescueBySide(rescue_side) > 0 && GetRescueSideProfit(rescue_side) >= 0) return;

            // เทรนด์ต้องแรงพอ
            if(trend_strength < 200.0) return;

            double lot = CalcRescueLot(s_profit, CountRescueBySide(rescue_side));

            if(do_sell_reverse)
            {
               trade.SetExpertMagicNumber(Inp_Rescue_Magic);
               if(trade.Sell(lot, _Symbol, 0, 0, 0, "Reverse Sell Rescue #"+IntegerToString(CountRescueBySide(POSITION_TYPE_SELL)+1)))
               {
                  lastTradeTime = TimeCurrent();
                  g_rescue_active = true;
                  g_rescue_last_open = TimeCurrent();
                  g_last_rescue_side = POSITION_TYPE_SELL;
                  g_last_sell_rescue_lot = lot;
                  Print("Reverse Sell Rescue | #", CountRescueBySide(POSITION_TYPE_SELL), " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag_points,0), " TrendStr=", DoubleToString(trend_strength,0));
               }
            }
            else
            {
               trade.SetExpertMagicNumber(Inp_Rescue_Magic);
               if(trade.Buy(lot, _Symbol, 0, 0, 0, "Rescue Buy #"+IntegerToString(CountRescueBySide(POSITION_TYPE_BUY)+1)))
               {
                  lastTradeTime = TimeCurrent();
                  g_rescue_active = true;
                  g_rescue_last_open = TimeCurrent();
                  g_last_rescue_side = POSITION_TYPE_BUY;
                  g_last_buy_rescue_lot = lot;
                  Print("Rescue Buy | #", CountRescueBySide(POSITION_TYPE_BUY), " Lot=", DoubleToString(lot,2), " Drag=", DoubleToString(drag_points,0), " TrendStr=", DoubleToString(trend_strength,0));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ManageAllPositionsTP - ตั้ง TP ทุกไม้ + Trailing TP (ล็อคกำไร)   |
//+------------------------------------------------------------------+
void ManageAllPositionsTP()
{
   if(!Inp_Use_All_TP) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Auto TP: คำนวณค่าจาก ATR อัตโนมัติ
   int tp_points = Inp_All_TP_Points;
   int tp_trigger = Inp_Trail_TP_Trigger;
   int tp_distance = Inp_Trail_TP_Distance;
   int tp_step = Inp_Trail_TP_Step;
   int tp_min_profit = Inp_Trail_TP_Min_Profit;

   if(Inp_Auto_TP)
   {
      double atr_v[];
      ArraySetAsSeries(atr_v, true);
      if(CopyBuffer(h_atr, 0, 0, 1, atr_v) > 0 && atr_v[0] > 0)
      {
         int atr_pts = (int)(atr_v[0] / _Point);
         tp_points     = (int)(atr_pts * 2.0);
         tp_trigger    = (int)(atr_pts * 1.0);
         tp_distance   = (int)(atr_pts * 0.7);
         tp_step       = (int)(atr_pts * 0.15);
         tp_min_profit = (int)(atr_pts * 0.2);
         if(tp_points < 100) tp_points = 100;
         if(tp_trigger < 50) tp_trigger = 50;
         if(tp_distance < 30) tp_distance = 30;
         if(tp_step < 10) tp_step = 10;
         if(tp_min_profit < 10) tp_min_profit = 10;
      }
   }


   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != Inp_Magic && magic != Inp_Rescue_Magic &&
         magic != Inp_Support_Magic && magic != MagicNumber &&
         magic != Inp_Pull_Magic &&
         magic != 0) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY)
      {
         double min_tp = NormalizeDouble(op + tp_min_profit * _Point, _Digits);
         double initial_tp = NormalizeDouble(op + tp_points * _Point, _Digits);
         initial_tp = MathMax(initial_tp, min_tp);

         if(tp == 0 || tp <= op)
         {
            if(initial_tp > bid + _Point)
               trade.PositionModify(ticket, sl, initial_tp);
         }

         if(Inp_Use_Trailing_TP && tp > op)
         {
            double profit_pts = (bid - op) / _Point;
            if(profit_pts >= tp_trigger)
            {
               double new_tp = NormalizeDouble(bid + tp_distance * _Point, _Digits);
               new_tp = MathMax(new_tp, min_tp);

               if(new_tp > tp + tp_step * _Point)
                  trade.PositionModify(ticket, sl, new_tp);
            }
         }
      }
      else // SELL
      {
         double min_tp = NormalizeDouble(op - tp_min_profit * _Point, _Digits);
         double initial_tp = NormalizeDouble(op - tp_points * _Point, _Digits);
         initial_tp = MathMin(initial_tp, min_tp);

         if(tp == 0 || tp >= op)
         {
            if(initial_tp < ask - _Point && initial_tp > 0)
               trade.PositionModify(ticket, sl, initial_tp);
         }

         if(Inp_Use_Trailing_TP && tp > 0 && tp < op)
         {
            double profit_pts = (op - ask) / _Point;
            if(profit_pts >= tp_trigger)
            {
               double new_tp = NormalizeDouble(ask - tp_distance * _Point, _Digits);
               new_tp = MathMin(new_tp, min_tp);

               if(new_tp < tp - tp_step * _Point && new_tp > 0)
                  trade.PositionModify(ticket, sl, new_tp);
            }
         }
      }
   }
}



//+------------------------------------------------------------------+
//| ShowBigMessage - แสดงข้อความตัวใหญ่กลางจอ                        |
//+------------------------------------------------------------------+
void ShowBigMessage(string msg, color clr)
{
   string name = BRT+"BIG_MSG";
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   }
   int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, chart_w / 2);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, chart_h / 2);
   ObjectSetString(0, name, OBJPROP_TEXT, msg);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 28);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| HideBigMessage - ซ่อนข้อความตัวใหญ่                             |
//+------------------------------------------------------------------+
void HideBigMessage()
{
   string name = BRT+"BIG_MSG";
   if(ObjectFind(0, name) >= 0)
   {
      ObjectDelete(0, name);
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| PassMultiFilter - ตรวจ RSI + เทรนด์ก่อนเปิดไม้                  |
//+------------------------------------------------------------------+
bool PassMultiFilter(ENUM_POSITION_TYPE t)
{
   if(!Inp_Use_Multi_Filter) return true;

   double rsi_v[];
   ArraySetAsSeries(rsi_v, true);
   if(CopyBuffer(h_rsi, 0, 0, 1, rsi_v) <= 0) return true;
   double rsi = rsi_v[0];

   double ma_v[];
   ArraySetAsSeries(ma_v, true);
   if(CopyBuffer(h_ma, 0, 0, 1, ma_v) <= 0) return true;
   bool is_uptrend = (iClose(_Symbol, PERIOD_H1, 0) > ma_v[0]);

   // ไม่เปิด BUY ถ้า RSI overbought + เทรนด์ลง
   if(t == POSITION_TYPE_BUY && rsi >= Inp_RSI_OB && !is_uptrend) return false;
   // ไม่เปิด SELL ถ้า RSI oversold + เทรนด์ขึ้น
   if(t == POSITION_TYPE_SELL && rsi <= Inp_RSI_OS && is_uptrend) return false;

   return true;
}

//+------------------------------------------------------------------+
//| ManagePartialClose - ปิดบางส่วนเมื่อกำไรถึง trigger             |
//+------------------------------------------------------------------+
void ManagePartialClose()
{
   if(!Inp_Use_Partial_Close) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != Inp_Magic && magic != Inp_Rescue_Magic &&
         magic != Inp_Support_Magic && magic != MagicNumber &&
         magic != Inp_Pull_Magic && magic != 0) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);
      string comment = PositionGetString(POSITION_COMMENT);

      // ข้ามถ้า lot น้อยเกินไป (CleanupTinyPositions จัดการ)
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(vol <= min_lot) continue;

      double profit_pts = 0;
      if(type == POSITION_TYPE_BUY)
         profit_pts = (bid - op) / _Point;
      else
         profit_pts = (op - ask) / _Point;

      if(profit_pts >= Inp_Partial_Trigger)
      {
         double close_vol = SafeLot(vol * Inp_Partial_Pct / 100.0);
         if(close_vol >= min_lot)
         {
            trade.PositionClosePartial(ticket, close_vol);
            Print("Partial Close | Ticket=", ticket,
                  " Vol=", DoubleToString(close_vol,2),
                  " Profit=", DoubleToString(profit_pts,0), " pts");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CleanupTinyPositions - ปิดไม้ lot จิ๋วที่ค้างจาก Partial Close    |
//+------------------------------------------------------------------+
void CleanupTinyPositions()
{
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != Inp_Magic && magic != Inp_Rescue_Magic &&
         magic != Inp_Support_Magic && magic != MagicNumber &&
         magic != Inp_Pull_Magic && magic != 0) continue;

      double vol = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      // ปิดไม้ที่ lot เท่ากับ min lot (0.01) ทันที — เป็นเศษจาก Partial Close
      if(vol <= min_lot && profit >= 0)
      {
         trade.PositionClose(ticket);
         Print("Cleanup Tiny | Ticket=", ticket, " Vol=", DoubleToString(vol,2));
      }
   }
}

//+------------------------------------------------------------------+
//| GetAntiMartLot - คำนวณ lot ตาม Anti-Martingale                   |
//+------------------------------------------------------------------+
double GetAntiMartLot(double base_lot)
{
   if(!Inp_Use_Anti_Mart) return base_lot;
   if(g_consec_losses >= Inp_Consec_Loss_Limit)
   {
      double reduced = base_lot * (1.0 - Inp_Lot_Reduce_Pct / 100.0);
      if(reduced < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
         reduced = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      return reduced;
   }
   return base_lot;
}

//+------------------------------------------------------------------+
//| UpdateConsecRecord - อัปเดตสถิติชนะ/แพ้ต่อเนื่อง                |
//+------------------------------------------------------------------+
void UpdateConsecRecord(bool is_win)
{
   if(!Inp_Use_Anti_Mart) return;
   if(is_win)
   {
      g_consec_wins++;
      g_consec_losses = 0;
   }
   else
   {
      g_consec_losses++;
      g_consec_wins = 0;
   }
}

//+------------------------------------------------------------------+
//| PullStuckPositions - ดึงไม้ดอยด้วย lot คำนวณจากไม้ที่ค้าง       |
//| SELL ดอย + เทรนด์ขึ้น → เปิด BUY ดึง                            |
//| BUY ดอย + เทรนด์ลง → เปิด SELL ดึง                              |
//+------------------------------------------------------------------+
void PullStuckPositions()
{
   if(!Inp_Use_Pull_Lot) return;
   if(TimeCurrent() - g_last_pull_time < Inp_Pull_Cooldown) return;

   // ตรวจว่ามีไม้ดึงอยู่แล้วหรือยัง
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) == Inp_Pull_Magic) return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // ตรวจเทรนด์ H1
   double ma_v[];
   ArraySetAsSeries(ma_v, true);
   if(CopyBuffer(h_ma, 0, 0, 1, ma_v) <= 0) return;
   bool is_uptrend = (iClose(_Symbol, PERIOD_H1, 0) > ma_v[0]);

   // คำนวณไม้ที่ค้างแต่ละฝั่ง
   double buy_loss_pts = 0, sell_loss_pts = 0;
   double buy_stuck_vol = 0, sell_stuck_vol = 0;
   int buy_stuck = 0, sell_stuck = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != Inp_Magic && magic != Inp_Rescue_Magic &&
         magic != Inp_Support_Magic && magic != MagicNumber &&
         magic != Inp_Pull_Magic && magic != 0) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);

      if(type == POSITION_TYPE_BUY)
      {
         double drag = (op - bid) / _Point;
         if(drag > 0) { buy_loss_pts += drag; buy_stuck_vol += vol; buy_stuck++; }
      }
      else
      {
         double drag = (ask - op) / _Point;
         if(drag > 0) { sell_loss_pts += drag; sell_stuck_vol += vol; sell_stuck++; }
      }
   }

   // SELL ดอย + เทรนด์ขึ้น → เปิด BUY ดึง
   if(sell_stuck > 0 && sell_stuck_vol > 0 && is_uptrend)
   {
      double avg_loss = sell_loss_pts / sell_stuck;
      if(avg_loss >= Inp_Pull_Trigger_DD)
      {
         double lot = SafeLot(sell_stuck_vol * Inp_Pull_Lot_Mult);
         lot = MathMin(lot, Inp_Pull_Max_Lot);
         lot = MathMin(lot, Inp_BaseLot * 2.0); // force cap ไม่ให้เกิน 2 เท่าของ base
         lot = SafeLot(lot);
         if(lot > 0)
         {
            trade.SetExpertMagicNumber(Inp_Pull_Magic);
            if(trade.Buy(lot, _Symbol, 0, 0, 0, "Pull BUY ดึงไม้ SELL ดอย"))
            {
               g_last_pull_time = TimeCurrent();
               lastTradeTime = TimeCurrent();
               Print("Pull BUY | SELL stuck=", sell_stuck, " vol=",
                     DoubleToString(sell_stuck_vol,2),
                     " pull lot=", DoubleToString(lot,2),
                     " avg drag=", DoubleToString(avg_loss,0), " pts");
            }
         }
      }
   }

   // BUY ดอย + เทรนด์ลง → เปิด SELL ดึง
   if(buy_stuck > 0 && buy_stuck_vol > 0 && !is_uptrend)
   {
      double avg_loss = buy_loss_pts / buy_stuck;
      if(avg_loss >= Inp_Pull_Trigger_DD)
      {
         double lot = SafeLot(buy_stuck_vol * Inp_Pull_Lot_Mult);
         lot = MathMin(lot, Inp_Pull_Max_Lot);
         lot = MathMin(lot, Inp_BaseLot * 2.0); // force cap ไม่ให้เกิน 2 เท่าของ base
         lot = SafeLot(lot);
         if(lot > 0)
         {
            trade.SetExpertMagicNumber(Inp_Pull_Magic);
            if(trade.Sell(lot, _Symbol, 0, 0, 0, "Pull SELL ดึงไม้ BUY ดอย"))
            {
               g_last_pull_time = TimeCurrent();
               lastTradeTime = TimeCurrent();
               Print("Pull SELL | BUY stuck=", buy_stuck, " vol=",
                     DoubleToString(buy_stuck_vol,2),
                     " pull lot=", DoubleToString(lot,2),
                     " avg drag=", DoubleToString(avg_loss,0), " pts");
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| SmartPullRecovery - หักลบปิดรวบ & กันพอร์ตแตก                    |
//| เอากำไรจากไม้ข้างบน (กำไร) มาหักลบไม้ข้างล่าง (ขาดทุน)          |
//| ถ้าหักลบแล้วกำไรสุทธิ >= threshold → ปิดรวบ                      |
//+------------------------------------------------------------------+
void SmartPullRecovery(double divider)
{

   // === 1. คำนวณ P&L รวมทุกไม้ ===
   double total_profit_usd = 0;
   int total_positions = 0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != Inp_Magic && magic != Inp_Rescue_Magic &&
         magic != Inp_Support_Magic && magic != MagicNumber &&
         magic != Inp_Pull_Magic &&
         magic != 0) continue;

      total_profit_usd += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      total_positions++;
   }

   if(total_positions == 0) return;

   double total_thb = (total_profit_usd / divider) * 32.0;
   if(!Inp_Use_Pull_Recovery) return;

   // === 3. ปิดรวบทุกไม้เมื่อกำไรสุทธิรวมเป็นบวก ===
   if(total_positions >= 2 && total_thb >= Inp_Pull_Close_THB)
   {
      Print("Offset Close All! Net=", DoubleToString(total_thb, 2), " THB");
      CloseAllProfitOnly();
      last_basket_close = TimeCurrent();
      return;
   }

   // === 4. หักลบจับคู่: กำไรข้างบน หักลบ ขาดทุนข้างล่าง ===
   ulong best_tk = 0, worst_tk = 0;
   double best_p = -999999, worst_p = 999999;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != Inp_Magic && magic != Inp_Rescue_Magic &&
         magic != Inp_Support_Magic && magic != MagicNumber &&
         magic != Inp_Pull_Magic &&
         magic != 0) continue;

      double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(p > best_p) { best_p = p; best_tk = ticket; }
      if(p < worst_p) { worst_p = p; worst_tk = ticket; }
   }

   if(best_tk > 0 && worst_tk > 0 && best_tk != worst_tk
      && best_p > 0 && worst_p < 0)
   {
      double net_thb = ((best_p + worst_p) / divider) * 32.0;
      if(net_thb >= Inp_Pull_Close_THB)
      {
         is_processing = true;
         trade.PositionClose(best_tk);
         trade.PositionClose(worst_tk);
         is_processing = false;
         Print("Offset Pair Close! Best=", DoubleToString((best_p/divider)*32,2),
               " Worst=", DoubleToString((worst_p/divider)*32,2),
               " Net=", DoubleToString(net_thb,2), " THB");
      }
   }
}



// --- [เพิ่มใหม่: ฟังก์ชันปัดเศษ Lot ป้องกัน Invalid Volume สำหรับ BTC] ---
double SafeLot(double lot)
{
   double step =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_STEP
      );

   double min_v =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_MIN
      );

   double max_v =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_MAX
      );

   lot = MathMax(lot, min_v);
   lot = MathMin(lot, max_v);

   int d = 2;

   if(step <= 0.0001)
      d = 4;
   else if(step <= 0.001)
      d = 3;

   return NormalizeDouble(
      MathCeil(lot / step)
      * step,
      d
   );
}
// -------------------------------------------------------------------