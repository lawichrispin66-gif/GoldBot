import os
import time
import secrets
from threading import Lock
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import PlainTextResponse

TOKEN = os.environ.get("GOLDBOT_TOKEN", "")
if len(TOKEN) < 24:
    raise RuntimeError("Set GOLDBOT_TOKEN to a random secret of at least 24 characters")

app = FastAPI(title="GoldBot Demo Bridge", docs_url=None, redoc_url=None)
lock = Lock()
state = {"connected": False, "symbol": "", "bid": 0.0, "ask": 0.0, "equity": 0.0, "bot_enabled": False, "last_seen": 0, "last_message": "Waiting for MT5 EA"}
commands = []

def auth(x_bot_token: str | None):
    if not x_bot_token or not secrets.compare_digest(x_bot_token, TOKEN):
        raise HTTPException(status_code=401, detail="Unauthorized")

@app.get("/health")
def health():
    return {"service": "GoldBot demo bridge", "ok": True}

@app.get("/api/status")
def get_status(x_bot_token: str | None = Header(default=None)):
    auth(x_bot_token)
    with lock:
        result = dict(state)
        result["connected"] = bool(state["last_seen"] and time.time() - state["last_seen"] < 20)
        return result

@app.post("/api/control/{action}")
def control(action: str, x_bot_token: str | None = Header(default=None)):
    auth(x_bot_token)
    if action not in {"START", "STOP", "CLOSE"}:
        raise HTTPException(status_code=400, detail="Allowed actions: START, STOP, CLOSE")
    with lock:
        commands.append(action)
        if action == "START": state["bot_enabled"] = True
        if action == "STOP": state["bot_enabled"] = False
    return {"queued": action}

@app.get("/api/command", response_class=PlainTextResponse)
def next_command(x_bot_token: str | None = Header(default=None)):
    auth(x_bot_token)
    with lock:
        if commands:
            return commands.pop(0)
    return "NONE"

@app.post("/api/status")
async def update_status(request: Request, x_bot_token: str | None = Header(default=None)):
    auth(x_bot_token)
    data = await request.json()
    with lock:
        for key in ("symbol", "bid", "ask", "equity", "bot_enabled", "last_message"):
            if key in data: state[key] = data[key]
        state["last_seen"] = time.time()
    return {"ok": True}
