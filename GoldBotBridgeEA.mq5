#property strict
#property version   "1.00"
#property description "GoldBot demo-only MT5 bridge EA starter"
#include <Trade/Trade.mqh>
CTrade trade;

input string InpBridgeBaseUrl = "https://YOUR-HOST.example";
input string InpToken = "REPLACE_WITH_LONG_RANDOM_TOKEN";
input string InpSymbol = "XAUUSD";
input bool   InpDemoOnly = true;
input double InpLots = 0.01;
input int    InpStopLossPoints = 500;
input int    InpTakeProfitPoints = 800;
input int    InpFastEMA = 9;
input int    InpSlowEMA = 21;
input ulong  InpMagic = 26102701;
input int    InpPollSeconds = 3;

bool bot_enabled=false;
int fastHandle=INVALID_HANDLE, slowHandle=INVALID_HANDLE;
string last_message="Starting";

bool IsDemo() { return (AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO); }
string Url(string path) { return InpBridgeBaseUrl + path; }
string Request(string method,string path,string body="") {
   char data[], result[]; string headers="X-Bot-Token: "+InpToken+"\r\nContent-Type: application/json\r\n";
   if(body!="") StringToCharArray(body,data,0,WHOLE_ARRAY,CP_UTF8); else ArrayResize(data,0);
   string response_headers;
   ResetLastError();
   int timeout=2500;
   int code=WebRequest(method,Url(path),headers,timeout,data,result,response_headers);
   if(code==-1) { last_message="WebRequest failed: "+IntegerToString(GetLastError()); return ""; }
   return CharArrayToString(result,0,-1,CP_UTF8);
}

void PublishStatus() {
   MqlTick tick; double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   SymbolInfoTick(InpSymbol,tick);
   string msg=StringFormat("{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,\"equity\":%.2f,\"bot_enabled\":%s,\"last_message\":\"%s\"}",InpSymbol,tick.bid,tick.ask,equity,bot_enabled?"true":"false",last_message);
   Request("POST","/api/status",msg);
}

void CloseOurPosition() {
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0 && PositionGetString(POSITION_SYMBOL)==InpSymbol && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic)
         trade.PositionClose(ticket);
   }
}

bool HasOurPosition() {
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0 && PositionGetString(POSITION_SYMBOL)==InpSymbol && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic) return true;
   }
   return false;
}

void ProcessCommand() {
   string cmd=Request("GET","/api/command");
   StringTrimLeft(cmd); StringTrimRight(cmd);
   if(cmd=="START") { if(InpDemoOnly && !IsDemo()) { bot_enabled=false; last_message="BLOCKED: demo account required"; } else { bot_enabled=true; last_message="Bot enabled on demo"; } }
   else if(cmd=="STOP") { bot_enabled=false; last_message="Bot stopped; existing position left open"; }
   else if(cmd=="CLOSE") { CloseOurPosition(); last_message="Close requested"; }
}

void CheckStrategy() {
   if(!bot_enabled || (InpDemoOnly && !IsDemo())) return;
   if(HasOurPosition()) return;
   double f[3],s[3]; ArraySetAsSeries(f,true); ArraySetAsSeries(s,true);
   if(CopyBuffer(fastHandle,0,0,3,f)<3 || CopyBuffer(slowHandle,0,0,3,s)<3) { last_message="Waiting for EMA data"; return; }
   bool buy=(f[2]<=s[2] && f[1]>s[1]);
   bool sell=(f[2]>=s[2] && f[1]<s[1]);
   MqlTick tick; if(!SymbolInfoTick(InpSymbol,tick)) return;
   double point=SymbolInfoDouble(InpSymbol,SYMBOL_POINT);
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(20);
   if(buy) {
      double sl=tick.ask-InpStopLossPoints*point, tp=tick.ask+InpTakeProfitPoints*point;
      if(trade.Buy(InpLots,InpSymbol,0,sl,tp,"GoldBot demo EMA buy")) last_message="Demo BUY opened"; else last_message="BUY failed: "+trade.ResultRetcodeDescription();
   } else if(sell) {
      double sl=tick.bid+InpStopLossPoints*point, tp=tick.bid-InpTakeProfitPoints*point;
      if(trade.Sell(InpLots,InpSymbol,0,sl,tp,"GoldBot demo EMA sell")) last_message="Demo SELL opened"; else last_message="SELL failed: "+trade.ResultRetcodeDescription();
   }
}

int OnInit() {
   if(InpDemoOnly && !IsDemo()) { last_message="BLOCKED: attach only to a demo account"; }
   fastHandle=iMA(InpSymbol,PERIOD_M5,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   slowHandle=iMA(InpSymbol,PERIOD_M5,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   if(fastHandle==INVALID_HANDLE || slowHandle==INVALID_HANDLE) return INIT_FAILED;
   trade.SetExpertMagicNumber(InpMagic);
   EventSetTimer(InpPollSeconds);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) { EventKillTimer(); if(fastHandle!=INVALID_HANDLE) IndicatorRelease(fastHandle); if(slowHandle!=INVALID_HANDLE) IndicatorRelease(slowHandle); }
void OnTimer() { ProcessCommand(); CheckStrategy(); PublishStatus(); }
void OnTick() { }
