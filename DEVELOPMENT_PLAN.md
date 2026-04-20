# Local Tool Locker — Comprehensive Development & Production Plan

> A beginner-friendly, production-shaped plan for building a fully offline, barcode-driven tool locker on a Raspberry Pi, designed to scale from a single cabinet to a fleet across multiple sites.

---

## Table of contents

1. [Executive summary](#1-executive-summary)
2. [Guiding principles](#2-guiding-principles)
3. [Architecture overview](#3-architecture-overview)
4. [Phased roadmap](#4-phased-roadmap)
   - [Phase 0 — Setup & learning](#phase-0--setup--learning-week-1)
   - [Phase 1 — Virtual prototype](#phase-1--virtual-prototype-week-12)
   - [Phase 2 — Proper backend, no hardware](#phase-2--proper-backend-no-hardware-week-24)
   - [Phase 3 — Scanner integration](#phase-3--scanner-integration-week-45)
   - [Phase 4 — Feedback hardware](#phase-4--feedback-hardware-week-56)
   - [Phase 5 — Lock mechanism](#phase-5--lock-mechanism-week-67)
   - [Phase 6 — Admin dashboard & reporting](#phase-6--admin-dashboard--reporting-week-79)
   - [Phase 7 — Hardening, replication, docs](#phase-7--hardening-replication-docs-week-912)
5. [Software stack (final)](#5-software-stack-final)
6. [Data model](#6-data-model)
7. [Hardware BOM & wiring](#7-hardware-bom--wiring)
8. [Project & program management](#8-project--program-management)
9. [Testing strategy](#9-testing-strategy)
10. [Security & safety](#10-security--safety)
11. [Scale path](#11-scale-path-multi-locker)
12. [Risk register](#12-risk-register)
13. [Glossary](#13-glossary)
14. [Appendices](#14-appendices)

---

## 1. Executive summary

**Goal:** a fully offline smart tool locker that tracks its contents via a barcode scanner, with a physical lock, headless operation, and a clean upgrade path to deploy additional lockers across multiple sites.

**Shape of v1:**
- Single cabinet, one door, 12 V electric strike lock.
- Raspberry Pi brain (headless — no monitor, keyboard, or mouse).
- **USB barcode scanner is the sole user input.** Users identify themselves by scanning a badge barcode; tools are checked in/out by scanning tool barcodes.
- Feedback to the user: RGB LED + piezo buzzer + small I²C OLED screen.
- Admin manages everything via a local Wi-Fi web dashboard (reachable from phone/laptop, fully offline).
- Full history log of every check-in/out.
- Designed from day one for replication: Docker + config file + image recipe = deploy a new locker anywhere.

**Timeline:** 6–12 weeks of evenings.

**Budget:** ~$200 of hardware beyond the Pi and scanner you already own.

---

## 2. Guiding principles

1. **Offline-first, always.** No cloud dependency. Everything works on a disconnected Pi.
2. **Scan-driven interaction.** Every borrower action is expressed as a barcode scan. There are no buttons, no keyboards at the locker.
3. **Modular layers.** Data → services → hardware adapters → UI. Each layer is independently testable and replaceable.
4. **Replicable.** Flash an SD card, inject a config file, deploy a new locker. No manual tinkering per site.
5. **Beginner-friendly but production-shaped.** No throwaway hacks. Every line of code written in v1 could ship.
6. **Test without hardware.** The whole system must be runnable on a laptop with mocked scanner and mocked GPIO so development doesn't require the Pi to be plugged in.

---

## 3. Architecture overview

Three Python processes running on the Pi, each a `systemd` unit, talking to each other over `localhost` HTTP/WebSocket. Clean separation means each can be tested, replaced, or upgraded independently.

```
┌──────────────────────────────────────────────────────────┐
│ Raspberry Pi (headless)                                  │
│                                                          │
│  [scanner_daemon]  ──HTTP POST /scan──▶ [FastAPI app]    │
│   (reads evdev)                          │               │
│                                          ├─ SQLite DB    │
│                                          │               │
│  [hardware_daemon] ◀──WebSocket /events─┘                │
│   - relay (lock)                                         │
│   - RGB LED                                              │
│   - piezo buzzer                                         │
│   - OLED display (I²C)                                   │
│                                                          │
│  [admin web UI] (Jinja + HTMX, served by FastAPI)        │
│   └─ reachable on LAN from phone/laptop                  │
│                                                          │
└──────────────────────────────────────────────────────────┘

   ▲ USB                                     ▲ Wi-Fi (LAN only)
   │                                         │
 USB HID                                   Admin
 barcode scanner                           laptop/phone
```

**Why three processes and not one?**
- **Scanner daemon** needs exclusive access to the `/dev/input/event*` device and runs as a user in the `input` group.
- **Hardware daemon** needs GPIO privileges and should crash/restart independently of the API.
- **FastAPI app** is the single source of truth for state; both daemons are thin I/O adapters.

A single-process design would conflate privileges and make testing on a non-Pi machine painful.

---

## 4. Phased roadmap

Each phase ends with a concrete, demoable deliverable. Mark a phase done only when its tests pass on a fresh checkout.

### Phase 0 — Setup & learning (Week 1)

**Goal:** environment ready, fundamentals understood, empty repo wired for CI.

**Tasks:**
- Install VS Code, Python 3.11+, Git, Docker Desktop (on your laptop, not the Pi yet).
- Create a GitHub repo named `tool-locker`.
- Read the [FastAPI tutorial](https://fastapi.tiangolo.com/tutorial/) (first-steps through path parameters at minimum).
- Skim the [SQLAlchemy 2.0 ORM quickstart](https://docs.sqlalchemy.org/en/20/orm/quickstart.html).
- Set up pre-commit hooks (`ruff`, `black`, `mypy`).
- Add a GitHub Actions workflow that runs lint + pytest on every push.

**Deliverable:** empty repo, `make test` runs (even if no tests yet), CI green on `main`.

---

### Phase 1 — Virtual prototype (Week 1–2)

**Goal:** prove the concept in a single HTML file, zero dependencies, matching your original example. Anyone can double-click it and use it.

**Features:**
- List of tools (name, status, current borrower, last action timestamp).
- Add a tool.
- Toggle a tool's status between Available / Loaned, with a borrower name field.
- Filter: "Show only available tools".
- History log of toggles.
- Clear all data button.
- All data in `localStorage`.

**Code skeleton — `prototype/index.html`:**

```html
<!doctype html>
<meta charset="utf-8">
<title>Tool Locker — Virtual Prototype</title>
<style>
  body { font-family: system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; }
  .loaned { color: #a00; }
  .available { color: #060; }
  table { width: 100%; border-collapse: collapse; }
  th, td { border-bottom: 1px solid #ddd; padding: .4rem; text-align: left; }
  input, button { font: inherit; padding: .3rem .6rem; }
</style>

<h1>Tool Locker — Virtual Prototype</h1>

<form id="addForm">
  <input id="toolName" placeholder="Tool name" required>
  <button>Add tool</button>
</form>

<label><input type="checkbox" id="onlyAvailable"> Show only available</label>
<button id="clearAll">Clear all data</button>

<h2>Tools</h2>
<table id="toolsTable">
  <thead><tr><th>Name</th><th>Status</th><th>Borrower</th><th>Action</th></tr></thead>
  <tbody></tbody>
</table>

<h2>History</h2>
<ul id="history"></ul>

<script>
const KEY_TOOLS = "tl.tools", KEY_HIST = "tl.history";
const load = k => JSON.parse(localStorage.getItem(k) || "[]");
const save = (k, v) => localStorage.setItem(k, JSON.stringify(v));

function render() {
  const tools = load(KEY_TOOLS);
  const onlyAvail = document.getElementById("onlyAvailable").checked;
  const tbody = document.querySelector("#toolsTable tbody");
  tbody.innerHTML = "";
  tools
    .filter(t => !onlyAvail || t.status === "Available")
    .forEach((t, i) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>${t.name}</td>
        <td class="${t.status.toLowerCase()}">${t.status}</td>
        <td>${t.borrower || ""}</td>
        <td><button data-i="${i}">Toggle</button></td>`;
      tbody.appendChild(tr);
    });
  const hist = load(KEY_HIST).slice(-20).reverse();
  document.getElementById("history").innerHTML =
    hist.map(h => `<li>${h.ts} — ${h.action}: ${h.tool}${h.borrower ? ` (${h.borrower})` : ""}</li>`).join("");
}

document.getElementById("addForm").onsubmit = e => {
  e.preventDefault();
  const name = document.getElementById("toolName").value.trim();
  if (!name) return;
  const tools = load(KEY_TOOLS);
  tools.push({ name, status: "Available", borrower: "" });
  save(KEY_TOOLS, tools);
  e.target.reset();
  render();
};

document.querySelector("#toolsTable").onclick = e => {
  const i = e.target.dataset.i;
  if (i === undefined) return;
  const tools = load(KEY_TOOLS);
  const t = tools[i];
  if (t.status === "Available") {
    const who = prompt("Borrower name?");
    if (!who) return;
    t.status = "Loaned"; t.borrower = who;
  } else {
    t.status = "Available"; t.borrower = "";
  }
  const hist = load(KEY_HIST);
  hist.push({ ts: new Date().toISOString(), action: t.status === "Loaned" ? "checkout" : "checkin", tool: t.name, borrower: t.borrower });
  save(KEY_TOOLS, tools); save(KEY_HIST, hist);
  render();
};

document.getElementById("onlyAvailable").onchange = render;
document.getElementById("clearAll").onclick = () => {
  if (confirm("Wipe all tools and history?")) { localStorage.clear(); render(); }
};

render();
</script>
```

**Deliverable:** `prototype/index.html` works in any browser. You can email it to anyone to demo the idea.

---

### Phase 2 — Proper backend, no hardware (Week 2–4)

**Goal:** migrate the data model to a real backend. Still no hardware — a debug form simulates scans.

**Tasks:**
- Set up the repo layout (see [§8](#8-project--program-management)).
- Create the FastAPI app.
- Define the database schema with SQLAlchemy + Alembic migrations.
- Implement the `/scan` endpoint and the state machine.
- Build a minimal Jinja + HTMX admin dashboard served by the same FastAPI app.
- Write unit tests for every service function.

**Code skeleton — SQLAlchemy models (`apps/api/models.py`):**

```python
from datetime import datetime
from enum import Enum
from sqlalchemy import ForeignKey, String, DateTime, Enum as SAEnum
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class ToolStatus(str, Enum):
    AVAILABLE = "available"
    LOANED = "loaned"
    RETIRED = "retired"


class User(Base):
    __tablename__ = "users"
    id:            Mapped[int]  = mapped_column(primary_key=True)
    badge_barcode: Mapped[str]  = mapped_column(String, unique=True, index=True)
    name:          Mapped[str]
    active:        Mapped[bool] = mapped_column(default=True)
    created_at:    Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Tool(Base):
    __tablename__ = "tools"
    id:      Mapped[int] = mapped_column(primary_key=True)
    barcode: Mapped[str] = mapped_column(String, unique=True, index=True)
    name:    Mapped[str]
    category: Mapped[str | None] = mapped_column(nullable=True)
    status:  Mapped[ToolStatus] = mapped_column(SAEnum(ToolStatus), default=ToolStatus.AVAILABLE)
    current_borrower_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    borrower: Mapped["User | None"] = relationship()
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class LoanEvent(Base):
    __tablename__ = "loan_events"
    id:        Mapped[int] = mapped_column(primary_key=True)
    tool_id:   Mapped[int] = mapped_column(ForeignKey("tools.id"))
    user_id:   Mapped[int] = mapped_column(ForeignKey("users.id"))
    action:    Mapped[str]  # "checkout" | "checkin"
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    site_id:   Mapped[str] = mapped_column(String, default="site-01")  # future-proof for fleet
    notes:     Mapped[str | None] = mapped_column(nullable=True)


class ConfigKV(Base):
    __tablename__ = "config"
    key:   Mapped[str] = mapped_column(primary_key=True)
    value: Mapped[str]
```

**Code skeleton — FastAPI entry point (`apps/api/main.py`):**

```python
from fastapi import FastAPI, Depends, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from .state import SessionState
from .services import handle_scan

app = FastAPI(title="Tool Locker API")
app.mount("/static", StaticFiles(directory="web/static"), name="static")


class ScanIn(BaseModel):
    barcode: str


@app.post("/scan")
def scan(payload: ScanIn, state: SessionState = Depends(SessionState.get)):
    try:
        result = handle_scan(payload.barcode, state)
    except ValueError as e:
        raise HTTPException(400, str(e))
    return result   # {"status": "...", "message": "...", "feedback": "..."}


@app.get("/healthz")
def healthz():
    return {"ok": True}
```

**Code skeleton — state machine (`apps/api/state.py`):**

```python
from dataclasses import dataclass
from datetime import datetime, timedelta

SESSION_TTL = timedelta(seconds=30)


@dataclass
class SessionState:
    user_id: int | None = None
    expires_at: datetime | None = None

    def is_authenticated(self) -> bool:
        return (
            self.user_id is not None
            and self.expires_at is not None
            and datetime.utcnow() < self.expires_at
        )

    def login(self, user_id: int) -> None:
        self.user_id = user_id
        self.expires_at = datetime.utcnow() + SESSION_TTL

    def refresh(self) -> None:
        if self.is_authenticated():
            self.expires_at = datetime.utcnow() + SESSION_TTL

    def logout(self) -> None:
        self.user_id = None
        self.expires_at = None

    # Simple singleton for the v1 single-process app.
    # Replace with proper DI container if you ever need multi-tenancy.
    _instance: "SessionState | None" = None

    @classmethod
    def get(cls) -> "SessionState":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
```

**Code skeleton — scan handler (`apps/api/services.py`):**

```python
from .state import SessionState
from . import repo  # thin DB access module; find_user_by_badge, find_tool_by_barcode, toggle_tool

RESERVED = {"LOGOUT", "ADMIN_MODE", "ENROLL_TOOL", "ENROLL_USER"}


def ok(msg: str, feedback: str = "ok") -> dict:
    return {"status": "ok", "message": msg, "feedback": feedback}


def err(msg: str, feedback: str = "error") -> dict:
    return {"status": "error", "message": msg, "feedback": feedback}


def handle_scan(code: str, state: SessionState) -> dict:
    code = code.strip().upper()

    if code in RESERVED:
        return handle_command(code, state)

    # Is it a user badge?
    user = repo.find_user_by_badge(code)
    if user:
        state.login(user.id)
        return ok(f"Welcome {user.name}", feedback="login")

    # Tool scans require authentication.
    if not state.is_authenticated():
        return err("Scan your badge first", feedback="denied")

    tool = repo.find_tool_by_barcode(code)
    if not tool:
        return err("Unknown barcode", feedback="error")

    event = repo.toggle_tool(tool, state.user_id)  # returns LoanEvent
    state.refresh()
    return ok(f"{event.action}: {tool.name}", feedback=event.action)


def handle_command(code: str, state: SessionState) -> dict:
    if code == "LOGOUT":
        state.logout()
        return ok("Logged out", feedback="logout")
    # ENROLL_TOOL / ENROLL_USER / ADMIN_MODE implemented in later phases
    return err(f"Command not implemented: {code}")
```

**Deliverable:** `uvicorn apps.api.main:app --reload` runs locally. You can hit `POST /scan` from `curl` or the debug form in the admin page and see real data stored in `data/toollocker.db`.

---

### Phase 3 — Scanner integration (Week 4–5)

**Goal:** real USB scanner drives the state machine on the Pi. Still no lock.

**Key concept — headless scanning with `evdev`:**
A USB HID barcode scanner identifies itself to the OS as a keyboard. Normally its "keystrokes" would go to whatever text field has focus. On a headless Pi there's no focused field. The solution: use the Linux input subsystem directly via the `evdev` Python library, and **grab the device exclusively** so its events never reach any TTY or X session.

**Tasks:**
- Identify the scanner device path with `ls /dev/input/by-id/`.
- Write a udev rule to give it a stable symlink (`/dev/input/toollocker-scanner`).
- Write the scanner daemon.
- Define the reserved "command barcodes": `LOGOUT`, `ADMIN_MODE`, `ENROLL_TOOL`, `ENROLL_USER`.
- Print a sheet of command barcodes (see [Appendix B](#appendix-b--command-barcode-reference-sheet)).

**Code skeleton — scanner daemon (`apps/scanner_daemon/main.py`):**

```python
"""
Reads a USB HID barcode scanner directly from /dev/input and POSTs each
scanned code to the local FastAPI app. Completely headless — no display
server, no TTY focus required.
"""
import time
import evdev
import httpx

API_URL = "http://127.0.0.1:8000/scan"
DEVICE_PATH = "/dev/input/toollocker-scanner"  # created by udev rule

# Minimal US keyboard scancode → character map.
# Full table in Appendix F; extend as needed for your scanner/locale.
KEYMAP = {
    2: "1", 3: "2", 4: "3", 5: "4", 6: "5",
    7: "6", 8: "7", 9: "8", 10: "9", 11: "0",
    16: "q", 17: "w", 18: "e", 19: "r", 20: "t",
    21: "y", 22: "u", 23: "i", 24: "o", 25: "p",
    30: "a", 31: "s", 32: "d", 33: "f", 34: "g",
    35: "h", 36: "j", 37: "k", 38: "l",
    44: "z", 45: "x", 46: "c", 47: "v", 48: "b",
    49: "n", 50: "m",
    28: "\n",  # Enter — terminates a barcode
}


def read_barcodes(path: str):
    dev = evdev.InputDevice(path)
    dev.grab()  # exclusive access — keystrokes don't leak to TTY
    buf = ""
    try:
        for event in dev.read_loop():
            if event.type != evdev.ecodes.EV_KEY:
                continue
            ke = evdev.categorize(event)
            if ke.keystate != ke.key_down:
                continue
            ch = KEYMAP.get(ke.scancode, "")
            if ch == "\n":
                if buf:
                    yield buf.strip().upper()
                    buf = ""
            else:
                buf += ch
    finally:
        dev.ungrab()


def main() -> None:
    with httpx.Client(timeout=2.0) as client:
        for code in read_barcodes(DEVICE_PATH):
            try:
                r = client.post(API_URL, json={"barcode": code})
                print(f"[{r.status_code}] {code} → {r.json()}")
            except Exception as e:  # noqa: BLE001
                print(f"API error for {code}: {e}")
                time.sleep(0.5)


if __name__ == "__main__":
    main()
```

**Deliverable:** Pi + scanner only. Scan a user badge → terminal prints `{"status": "ok", "message": "Welcome Kaj", "feedback": "login"}`. Scan a tool → toggle recorded in DB.

---

### Phase 4 — Feedback hardware (Week 5–6)

**Goal:** a borrower gets real feedback at the locker — OLED message, LED color, beep pattern. Still no lock.

**Tasks:**
- Wire an RGB LED (common-cathode, via current-limiting resistors) to three GPIO pins.
- Wire an active 5 V piezo buzzer to one GPIO pin.
- Wire a 1.3" SSD1306/SH1106 I²C OLED to 3.3 V, GND, SDA (GPIO 2), SCL (GPIO 3).
- Enable I²C in `raspi-config`.
- Write the hardware daemon.
- Add a WebSocket `/events` endpoint to the API that broadcasts a feedback event whenever a scan is processed.

**Code skeleton — hardware daemon (`apps/hardware_daemon/main.py`):**

```python
"""
Listens for scan-result events from the FastAPI app and drives the
physical feedback hardware: RGB LED, piezo buzzer, OLED, and (Phase 5)
the lock relay.
"""
import time
import httpx
from gpiozero import RGBLED, Buzzer, OutputDevice
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306
from PIL import ImageFont

# --- Hardware init --------------------------------------------------------
led    = RGBLED(red=17, green=27, blue=22, active_high=True)
buzzer = Buzzer(23)
lock   = OutputDevice(24, active_high=True, initial_value=False)  # relay
oled   = ssd1306(i2c(port=1, address=0x3C))
font   = ImageFont.load_default()

MAX_UNLOCK_SECONDS = 5  # hardware watchdog: never hold the lock open longer


# --- Primitives -----------------------------------------------------------
def show(line1: str, line2: str = "") -> None:
    with canvas(oled) as draw:
        draw.text((0, 0),  line1, font=font, fill="white")
        draw.text((0, 20), line2, font=font, fill="white")


def unlock_briefly(seconds: float = 3.0) -> None:
    seconds = min(seconds, MAX_UNLOCK_SECONDS)
    lock.on()
    try:
        time.sleep(seconds)
    finally:
        lock.off()


def feedback(kind: str) -> None:
    match kind:
        case "login":
            led.color = (0, 1, 0); buzzer.beep(0.1, 0.1, n=1, background=False)
        case "checkout":
            led.color = (0, 0, 1); buzzer.beep(0.05, 0.05, n=2, background=False)
            unlock_briefly()
        case "checkin":
            led.color = (0, 1, 0); buzzer.beep(0.05, 0.05, n=1, background=False)
            unlock_briefly()
        case "logout":
            led.color = (0, 0, 0); buzzer.beep(0.05, 0.05, n=1, background=False)
        case "denied" | "error":
            led.color = (1, 0, 0); buzzer.beep(0.2, 0.1, n=3, background=False)
        case _:
            led.color = (0, 0, 0)


# --- Main loop ------------------------------------------------------------
def main() -> None:
    show("Tool Locker", "Scan your badge")
    led.color = (0, 0, 0)
    with httpx.Client() as client:
        while True:
            try:
                # Long-poll the API for scan events. WebSocket is nicer;
                # polling is simpler to start with.
                r = client.get("http://127.0.0.1:8000/events/poll", timeout=30)
                for evt in r.json():
                    show(evt.get("line1", ""), evt.get("line2", ""))
                    feedback(evt.get("feedback", ""))
            except httpx.ReadTimeout:
                continue
            except Exception as e:  # noqa: BLE001
                show("Locker error", str(e)[:20])
                time.sleep(1)


if __name__ == "__main__":
    main()
```

**Deliverable:** scan a badge → OLED says "Welcome Kaj", LED flashes green, buzzer beeps. Scan a tool → OLED says "Checked out: Drill", LED pulses blue.

---

### Phase 5 — Lock mechanism (Week 6–7)

**Goal:** real physical security. The cabinet door actually locks and unlocks.

**Tasks:**
- Procure a 12 V fail-locked electric strike or solenoid lock.
- Wire it through an opto-isolated 5 V relay module driven from GPIO 24.
- Use a **separate 12 V 2 A PSU** for the lock. **Never** power the lock from the Pi's 5 V rail.
- Tie all grounds together (Pi GND ↔ relay GND ↔ 12 V PSU GND).
- Add a mechanical override (physical key cylinder) so you're never locked out of your own cabinet.
- Implement the software watchdog: the relay cannot stay energized for more than `MAX_UNLOCK_SECONDS` (already scaffolded in Phase 4).
- Mount Pi, OLED, LED, buzzer, scanner cradle, and lock in/on the cabinet.

**Wiring outline:**

```
12 V PSU (+) ───┬─── Electric strike (+)
                │
                │       [Relay COM]───────────┐
                │            │                │
                │       [Relay NO] ──── Electric strike (−)
                │            │
12 V PSU (−) ───┴────────────┼──── Pi GND ──── Relay GND
                             │
Pi GPIO 24 ──────────────── Relay IN
Pi 5 V ──────────────────── Relay VCC
```

**Safety checklist:**
- Fail-locked lock stays locked on power loss — good for security.
- Mechanical key override always present.
- Relay is opto-isolated — a fault in the 12 V side cannot fry the Pi.
- Watchdog limits unlock time even if software hangs.
- Fuse on the 12 V rail (1 A fast-blow is plenty for a strike).

**Deliverable:** a working physical v1 locker. Scan in, door unlocks briefly, take your tool, door relocks.

---

### Phase 6 — Admin dashboard & reporting (Week 7–9)

**Goal:** you can administer the locker entirely from your phone or laptop over local Wi-Fi.

**Pages:**
- **Dashboard** — live status: who's logged in, which tools are out.
- **Tools** — CRUD, filter, search.
- **Users** — CRUD, enable/disable badges.
- **History** — full audit log, filterable by user/tool/date.
- **Enrollment wizard** — guided "scan the tool, enter its name, print its label".
- **Config** — site ID, session TTL, unlock duration.
- **Backup/restore** — dump SQLite to a USB drive via a special admin scan.

**Reporting:**
- **Full history log** of who, what, when checked out/in (this was your chosen scope).
- **CSV export** of history for spreadsheets.
- **Print-ready barcode sheet generator** using `python-barcode` + a simple ReportLab PDF layout, so you can print tool labels and user badges at home.

**Security:**
- Admin dashboard bound to the LAN interface only (not `0.0.0.0` blindly).
- Password-protected (single admin password in v1; proper user accounts later).
- HTTPS optional for v1; if added, use a self-signed cert stored on the Pi.

**Deliverable:** you never need SSH to administer the locker during normal use.

---

### Phase 7 — Hardening, replication, docs (Week 9–12)

**Goal:** v1 is production-ready and replicable. You can deploy a second locker at a second site in an afternoon.

**Tasks:**
- Dockerize each of the three services.
- Write `docker-compose.yml` to run the whole stack with one command.
- Write `systemd` unit files as a non-Docker alternative.
- Build a Pi OS image recipe (`pi-gen` or an Ansible playbook) so a new locker = flash + boot + first-boot config.
- Write `DEPLOY.md`: hardware checklist, network setup, first-boot wizard.
- Add a **sync module stub**: an interface for pushing `LoanEvent`s to a future central server. Disabled by default. Defining this now means Phase 8 is a config flip, not a rewrite.
- **Soak test:** run the locker in real daily use for 2 weeks. Fix what breaks.

**Code skeleton — systemd unit (`deploy/systemd/toollocker-api.service`):**

```ini
[Unit]
Description=Tool Locker API
After=network.target

[Service]
Type=simple
User=toollocker
WorkingDirectory=/opt/tool-locker
ExecStart=/opt/tool-locker/.venv/bin/uvicorn apps.api.main:app --host 127.0.0.1 --port 8000
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Similar units go in `deploy/systemd/toollocker-scanner.service` and `toollocker-hardware.service`.

**Code skeleton — `deploy/docker-compose.yml`:**

```yaml
services:
  api:
    build: ./apps/api
    restart: unless-stopped
    volumes:
      - ./data:/data
    ports:
      - "8000:8000"    # dashboard on LAN
    environment:
      - SITE_ID=site-01
      - DATABASE_URL=sqlite:////data/toollocker.db

  scanner:
    build: ./apps/scanner_daemon
    restart: unless-stopped
    devices:
      - "/dev/input/toollocker-scanner:/dev/input/toollocker-scanner"
    depends_on: [api]

  hardware:
    build: ./apps/hardware_daemon
    restart: unless-stopped
    privileged: true    # required for /dev/gpiomem and I²C
    depends_on: [api]
```

**Code skeleton — udev rule (`deploy/udev/99-toollocker-scanner.rules`):**

```
# Replace XXXX/YYYY with your scanner's idVendor/idProduct (find via `lsusb`).
SUBSYSTEM=="input", ATTRS{idVendor}=="XXXX", ATTRS{idProduct}=="YYYY", \
  SYMLINK+="input/toollocker-scanner", MODE="0660", GROUP="input"
```

**Deliverable:** v1 complete. Fully documented. Replicable.

---

## 5. Software stack (final)

| Layer              | Choice                               | Why                                                                 |
|--------------------|--------------------------------------|---------------------------------------------------------------------|
| Language           | Python 3.11+                         | Beginner-friendly, excellent Pi + hardware libraries                |
| API framework      | FastAPI                              | Auto docs, type hints, modern, fast                                 |
| ORM                | SQLAlchemy 2.x                       | Industry standard, Postgres-ready for a future central server       |
| Migrations         | Alembic                              | Standard companion to SQLAlchemy                                    |
| Database           | SQLite (WAL mode)                    | Zero-ops, single file, plenty for <20 users                         |
| Admin UI           | Jinja2 + HTMX + Pico.css             | No build step, clean HTML, tiny footprint                           |
| Scanner I/O        | `evdev`                              | Reads input events directly from kernel; no display server needed   |
| GPIO / LED / buzzer| `gpiozero` with `lgpio` backend      | Simplest Python API for beginners                                   |
| OLED               | `luma.oled`                          | Mature, well-documented, supports SSD1306/SH1106                    |
| HTTP client        | `httpx`                              | Modern, sync + async, great error semantics                         |
| Process management | `systemd` units (Docker optional)    | Standard on Raspberry Pi OS                                         |
| Tests              | `pytest`, `httpx`, `pytest-asyncio`  | Standard Python testing stack                                       |
| Lint / format      | `ruff`, `black`, `mypy --strict`     | Enforces clean code with zero effort                                |
| CI                 | GitHub Actions                       | Free, easy, integrates with the repo                                |
| Barcode generation | `python-barcode` + ReportLab         | For printing tool labels and user badges                            |

---

## 6. Data model

Entities (see [Phase 2 code skeleton](#phase-2--proper-backend-no-hardware-week-24) for the full SQLAlchemy definitions):

- **User:** `id`, `badge_barcode` (unique), `name`, `email?`, `active`, `created_at`
- **Tool:** `id`, `barcode` (unique), `name`, `category?`, `status` (`available`/`loaned`/`retired`), `current_borrower_id?`, `created_at`
- **LoanEvent:** `id`, `tool_id`, `user_id`, `action` (`checkout`/`checkin`), `timestamp`, `site_id`, `notes?`
- **ConfigKV:** key/value store for runtime configuration.
- **Reserved command barcodes:** constants in code, not stored in the DB. Documented in [Appendix B](#appendix-b--command-barcode-reference-sheet).

**Migrations:** Alembic from day one. Never mutate the schema by hand.

**Why `site_id` on `LoanEvent` from v1?** When you add a second locker and want a central reporting server, every event already has the right metadata. Retrofitting this later would mean a painful migration.

---

## 7. Hardware BOM & wiring

### Bill of materials (v1, ~$200 beyond what you own)

| Item                                                | Qty | Approx $ | Notes                                           |
|-----------------------------------------------------|----:|---------:|-------------------------------------------------|
| Raspberry Pi 4 (2 GB)                               |   1 |     —    | You already own one                             |
| 32 GB A1 microSD                                    |   1 |    10    |                                                 |
| USB HID barcode scanner                             |   1 |     —    | You already own one                             |
| 12 V electric strike or solenoid lock               |   1 |    30    | Fail-locked preferred                           |
| 12 V 2 A PSU (barrel jack)                          |   1 |    12    | Powers the lock only                            |
| Opto-isolated 5 V relay module (1 channel)          |   1 |     6    |                                                 |
| 1.3" I²C OLED (SSD1306 or SH1106)                   |   1 |    10    |                                                 |
| Common-cathode RGB LED + 3× 330 Ω resistors         |   1 |     2    |                                                 |
| Active 5 V piezo buzzer                             |   1 |     3    |                                                 |
| Jumper wires + small protoboard                     |   1 |     8    |                                                 |
| Cabinet (wood or metal) + hinges + strike plate     |   1 |    80    | Or retrofit something you own                   |
| 1 A fast-blow inline fuse for 12 V rail             |   1 |     2    | Safety                                          |
| Screws, standoffs, cable glands                     |   — |    15    |                                                 |
| Contingency (10 %)                                  |   — |    20    |                                                 |
| **Total**                                           |     | **~$198** |                                                 |

### GPIO pin map (BCM numbering)

| Function          | GPIO | Physical pin |
|-------------------|-----:|-------------:|
| OLED SDA          |    2 |            3 |
| OLED SCL          |    3 |            5 |
| Buzzer            |   23 |           16 |
| Lock relay IN     |   24 |           18 |
| RGB LED — red     |   17 |           11 |
| RGB LED — green   |   27 |           13 |
| RGB LED — blue    |   22 |           15 |
| 3.3 V             |    — |            1 |
| 5 V (relay VCC)   |    — |            2 |
| GND (common)      |    — |            6 |

### Power budget

- Pi 4 on 5 V 3 A USB-C (its own PSU).
- Lock on 12 V 2 A PSU.
- Relay coil drawn from Pi 5 V (~70 mA, fine).
- Grounds tied together at the relay module.

### Wiring diagram

See ASCII diagram in [Phase 5](#phase-5--lock-mechanism-week-67). A clean KiCad/Fritzing schematic lives in `docs/hardware/wiring.fzz` once drawn.

---

## 8. Project & program management

### Repo layout (monorepo)

```
tool-locker/
├── apps/
│   ├── api/                  # FastAPI backend + admin UI
│   │   ├── main.py
│   │   ├── models.py
│   │   ├── state.py
│   │   ├── services.py
│   │   ├── repo.py
│   │   └── Dockerfile
│   ├── scanner_daemon/
│   │   ├── main.py
│   │   └── Dockerfile
│   └── hardware_daemon/
│       ├── main.py
│       └── Dockerfile
├── web/
│   ├── templates/            # Jinja templates
│   └── static/               # CSS + HTMX + Pico.css
├── prototype/
│   └── index.html            # Phase 1 single-file demo
├── deploy/
│   ├── docker-compose.yml
│   ├── systemd/
│   ├── udev/
│   └── pi-image/             # pi-gen or Ansible recipe
├── docs/
│   ├── hardware/
│   ├── architecture.md
│   └── runbooks/
├── tests/
│   ├── conftest.py
│   ├── test_state.py
│   ├── test_services.py
│   └── test_scan_endpoint.py
├── alembic/
├── pyproject.toml
├── Makefile
├── README.md
└── DEPLOY.md
```

### Ways of working

- **Issue tracking:** GitHub Projects board with a column per phase.
- **Branching:** trunk-based. `main` is always deployable. Feature branches merged via PR with CI green.
- **Commits:** conventional commits (`feat:`, `fix:`, `docs:`, `chore:`).
- **Definition of Done** for any ticket:
  1. Tests pass locally and in CI.
  2. Docs updated (`docs/` or inline docstrings).
  3. Runnable on a fresh Pi after `git pull` + service restart.
- **Cadence:** one phase goal per week, Friday demo-to-self. Video the demo — great for debugging regressions later.
- **Backlog hygiene:** anything out of v1 scope goes into `docs/backlog.md`, not into PRs.

---

## 9. Testing strategy

Four layers:

1. **Unit tests** — pure functions in `services.py`, `state.py`. No DB, no hardware. Run in milliseconds.
2. **Contract tests** — the `/scan` endpoint state machine. SQLite in-memory, no hardware. Cover the full state diagram.
3. **Integration tests** — scanner daemon with a **mock input device**, hardware daemon with **mock GPIO** (gpiozero has a `MockFactory`). Runs in CI without a Pi.
4. **Hardware smoke tests** — a `make hw-check` script run on the Pi that blinks the LED, beeps, cycles the relay safely, and renders the OLED. Not run in CI.

### Example test — state machine (`tests/test_state.py`)

```python
from apps.api.state import SessionState
from apps.api.services import handle_scan


class _Event:
    def __init__(self, action: str): self.action = action


def test_login_then_checkout(monkeypatch):
    class U: id, name, badge_barcode = 1, "Kaj", "USER-KAJ"
    class T: id, barcode, name = 42, "TOOL-DRILL", "Drill"

    monkeypatch.setattr(
        "apps.api.services.repo.find_user_by_badge",
        lambda c: U if c == U.badge_barcode else None,
    )
    monkeypatch.setattr(
        "apps.api.services.repo.find_tool_by_barcode",
        lambda c: T if c == T.barcode else None,
    )
    monkeypatch.setattr(
        "apps.api.services.repo.toggle_tool",
        lambda tool, uid: _Event("checkout"),
    )

    state = SessionState()

    assert handle_scan("USER-KAJ", state)["status"] == "ok"
    assert state.is_authenticated()

    result = handle_scan("TOOL-DRILL", state)
    assert result["status"] == "ok"
    assert "checkout" in result["message"].lower()


def test_tool_scan_without_login_is_denied(monkeypatch):
    monkeypatch.setattr("apps.api.services.repo.find_user_by_badge", lambda c: None)
    monkeypatch.setattr(
        "apps.api.services.repo.find_tool_by_barcode",
        lambda c: type("T", (), {"barcode": c, "name": "x"})(),
    )
    result = handle_scan("TOOL-DRILL", SessionState())
    assert result["status"] == "error"
    assert result["feedback"] == "denied"
```

### Soak test

Two weeks of real daily use before declaring v1 done. Keep a log of every glitch; fix or file each one.

---

## 10. Security & safety

- **Fail-locked lock.** Door stays locked on power loss.
- **Hardware watchdog.** Software cannot hold the relay energized for more than `MAX_UNLOCK_SECONDS`.
- **Mechanical key override.** Always present. You're never locked out of your own cabinet.
- **Fuse on the 12 V rail.** 1 A fast-blow.
- **Opto-isolated relay.** A fault on the 12 V side cannot fry the Pi.
- **Admin dashboard** bound to the LAN interface only; password-protected.
- **Audit trail.** Every relay actuation and every admin login is logged.
- **Backups.** Nightly SQLite dump to a mounted USB drive; on-demand via an admin command barcode.
- **SQLite in WAL mode.** Survives unclean shutdowns much better than the default journal mode.
- **Secrets.** Admin password lives in `config/secrets.env`, git-ignored, mode `600`.
- **Optional DB encryption.** SQLCipher if site policy requires encryption at rest.

---

## 11. Scale path (multi-locker)

The code written in v1 is already almost ready for a fleet:

- Every `LoanEvent` carries a `site_id` — the partitioning key for multi-site reporting.
- All three services are containerized — a new site = clone the repo, edit one env file, `docker compose up -d`.
- The sync module interface is defined in v1 (disabled). When ready:
  - Add a central FastAPI server that accepts batched event pushes.
  - Flip the `SYNC_ENABLED` flag on each locker.
  - No schema changes. No rewrites.
- Pi OS image recipe (Phase 7) means provisioning is: flash SD, boot, enter site ID, done.

Future cross-site features that this foundation supports cleanly:
- Global tool catalog with per-site inventory.
- User badges valid across lockers.
- Central dashboard showing fleet status.
- Alerting (overdue tools, offline lockers) once a central server exists.

---

## 12. Risk register

| # | Risk                                                       | Likelihood | Impact | Mitigation                                                                 |
|--:|------------------------------------------------------------|:----------:|:------:|----------------------------------------------------------------------------|
| 1 | Scanner enumerates as the wrong `/dev/input/event*` device |   Medium   |  High  | udev rule pins it to a stable symlink; daemon refuses to run without it    |
| 2 | Power glitch corrupts SQLite                               |    Low     |  High  | WAL mode, nightly USB backup, UPS optional                                 |
| 3 | User forgets to log out                                    |    High    |  Low   | 30 s inactivity timeout; OLED countdown; `LOGOUT` barcode                  |
| 4 | Lost or damaged barcodes                                   |   Medium   |  Low   | Admin dashboard prints replacements on demand                              |
| 5 | Scope creep (RFID, cameras, phone app, etc.)               |    High    | Medium | Strict v1 scope; everything else in `docs/backlog.md`                      |
| 6 | Relay stuck closed (lock held open)                        |    Low     |  High  | Hardware watchdog caps unlock duration; fail-locked lock on power loss     |
| 7 | Admin password leaks on shared Wi-Fi                       |    Low     | Medium | LAN-only binding; optional self-signed HTTPS; rotate password per site     |
| 8 | You brick the Pi during an update                          |   Medium   | Medium | Keep `deploy/pi-image/` recipe current; practice reflashing from scratch   |

---

## 13. Glossary

- **BCM (pin numbering):** Broadcom numbering scheme for Pi GPIO pins, used by `gpiozero`.
- **evdev:** Linux subsystem and Python library for reading input events (keyboards, scanners, etc.) directly from the kernel.
- **Fail-locked:** a lock that stays locked when it loses power. Opposite of fail-unlocked.
- **GPIO:** General-Purpose Input/Output. The physical header pins on the Pi you wire electronics to.
- **HID:** Human Interface Device. The USB class that includes keyboards, mice, and most barcode scanners.
- **HTMX:** a small JavaScript library that lets you build interactive web UIs with HTML attributes and server-rendered partials. No build step.
- **I²C:** a two-wire bus (SDA + SCL) used to talk to small peripherals like OLEDs.
- **Kiosk mode:** configuring a device to run a single application full-screen. We avoid this by going truly headless.
- **ORM:** Object-Relational Mapper. SQLAlchemy lets you write Python classes that map to DB tables.
- **systemd:** Linux service manager. Defines how long-running programs are started, stopped, and restarted.
- **udev:** Linux subsystem that manages `/dev` entries and can assign stable names to devices.
- **WAL (SQLite):** Write-Ahead Logging mode. More crash-safe and allows concurrent reads during writes.
- **Watchdog:** a safety mechanism that forces an action (e.g., relock) if software fails to confirm "all is well" within a time limit.

---

## 14. Appendices

### Appendix A — Wiring diagram & GPIO pin map

See the ASCII diagram in [Phase 5](#phase-5--lock-mechanism-week-67) and the pin table in [§7](#7-hardware-bom--wiring). A Fritzing file (`docs/hardware/wiring.fzz`) and PNG export will be added during Phase 5.

### Appendix B — Command barcode reference sheet

Reserved strings to be printed as Code-128 barcodes on the admin sheet:

| Barcode string   | Action                                               |
|------------------|------------------------------------------------------|
| `LOGOUT`         | End the current authenticated session               |
| `ADMIN_MODE`     | Enter admin mode (requires admin user badge first)  |
| `ENROLL_TOOL`    | Next tool scan registers a new tool                 |
| `ENROLL_USER`    | Next badge scan registers a new user                |
| `BACKUP_NOW`     | Dump SQLite to the mounted USB drive                |
| `CANCEL`         | Abort the current admin wizard step                 |

Generated with `python-barcode` and laid out in a printable PDF by the admin dashboard.

### Appendix C — systemd unit examples

See [Phase 7](#phase-7--hardening-replication-docs-week-912) for `toollocker-api.service`. Sibling files:

- `toollocker-scanner.service` — runs the scanner daemon, depends on `toollocker-api.service`.
- `toollocker-hardware.service` — runs the hardware daemon, depends on `toollocker-api.service`.

Each uses `Restart=on-failure` and `RestartSec=3`.

### Appendix D — `docker-compose.yml` skeleton

See [Phase 7](#phase-7--hardening-replication-docs-week-912).

### Appendix E — First-time Pi provisioning checklist

1. Flash Raspberry Pi OS Lite (64-bit) to a 32 GB A1 microSD.
2. Pre-configure Wi-Fi + SSH via Raspberry Pi Imager's advanced options.
3. First boot: `ssh pi@toollocker.local`, then `sudo raspi-config` → enable I²C, set hostname, set locale, set timezone.
4. `sudo apt update && sudo apt full-upgrade -y`.
5. Install Docker: `curl -sSL https://get.docker.com | sh` and add your user to the `docker` group.
6. Clone the repo to `/opt/tool-locker`, create a `toollocker` system user.
7. Install the udev rule from `deploy/udev/`, reload udev.
8. Copy your `config/secrets.env` onto the Pi (never commit this).
9. `docker compose up -d` (or `systemctl enable --now` the three units).
10. Verify `/healthz` returns `{"ok": true}` on port 8000 from your laptop.
11. Enroll your first admin user via the admin dashboard.
12. Print user badges and tool labels.
13. Physically install the lock and test the watchdog cutoff.

### Appendix F — Reading list

- FastAPI tutorial — https://fastapi.tiangolo.com/tutorial/
- SQLAlchemy 2.0 ORM quickstart — https://docs.sqlalchemy.org/en/20/orm/quickstart.html
- HTMX essentials — https://htmx.org/docs/
- `gpiozero` recipes — https://gpiozero.readthedocs.io/en/stable/recipes.html
- `luma.oled` docs — https://luma-oled.readthedocs.io/
- `evdev` Python bindings — https://python-evdev.readthedocs.io/
- Raspberry Pi OS Lite setup — https://www.raspberrypi.com/documentation/computers/os.html
- pi-gen (custom Pi OS images) — https://github.com/RPi-Distro/pi-gen

---

*End of plan. Start with Phase 0, keep scope tight, demo to yourself every Friday, and you'll have a production-ready v1 in 6–12 weeks — with a clean path to a fleet whenever you're ready.*
