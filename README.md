# GoldBot Android + MT5 bridge (starter project)

This is source code, not an installable APK and not a tested live-trading product. It is a demo-only starter kit. The Android app is a controller/dashboard; actual order execution happens in the MT5 desktop terminal running the included Expert Advisor (EA).

## Architecture
Android app -> HTTPS bridge API -> MT5 desktop EA -> broker demo account

**Requirements:**
- Android Studio to build the APK.
- A Windows computer or Windows VPS running MT5 desktop and the EA continuously.
- A reachable HTTPS host for the Python bridge (or adapt the app and EA to a private LAN setup). A VPS/host may cost money; there is no guaranteed free always-on host.
- A broker demo account with XAUUSD (symbol may have a suffix, e.g. XAUUSD.a).

## Safety defaults
- EA refuses to trade on a real account.
- Starts OFF; must be started from the app.
- One position maximum for the configured symbol and magic number.
- Fixed 0.01 lot, configurable stop-loss/take-profit in points.
- EMA crossover is only a sample strategy, not a profitable or validated strategy.
- No martingale/grid. Test in demo only.

## Bridge setup
1. Use Python 3.11+ on a host you control. Install dependencies: `pip install -r requirements.txt`.
2. Set environment variable `GOLDBOT_TOKEN` to a long random secret. Run `uvicorn server:app --host 0.0.0.0 --port 8000` from `bridge/`.
3. Put the API behind HTTPS before exposing it to the public internet. Do not expose plain HTTP to the internet.
4. In the Android app, set the base URL to your HTTPS bridge URL and enter the same token.
5. In MT5 desktop, open Tools -> Options -> Expert Advisors, enable WebRequest for the bridge URL's domain. Copy `GoldBotBridgeEA.mq5` into `MQL5/Experts/`, compile it in MetaEditor, attach it to an XAUUSD chart, and enable Algo Trading.
6. Set `InpBridgeBaseUrl` and `InpToken` in the EA to the same bridge URL and token. Keep `InpDemoOnly=true`.
7. Confirm the account is demo, the bridge status appears in the app, and run a demo test. Never enable on a live account.

## Current limitations
- This source kit has not been compiled into an APK or tested against a live MT5 terminal in this environment.
- The app cannot run MT5 EAs directly on Android. A desktop terminal/VPS and bridge host are required.
- Secure your bridge with HTTPS, a strong token, and preferably network restrictions. Never place broker passwords in the app or bridge.
