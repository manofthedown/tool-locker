# Tool Locker

A fully offline, barcode-driven smart tool locker running on a Raspberry Pi. Headless operation — a USB barcode scanner is the sole user input. Full history log, LAN admin dashboard, designed to be replicated across multiple sites.

## Status

Pre-alpha. **Phase 0 complete** — repo scaffolded, tooling wired, CI green. See [`DEVELOPMENT_PLAN.md`](./DEVELOPMENT_PLAN.md) for the full plan.

![CI](https://github.com/manofthedown/tool-locker/actions/workflows/ci.yml/badge.svg)

## Features (target v1)

- Offline-first: no cloud dependency, everything runs on a single Raspberry Pi.
- Barcode-only interaction: scan a user badge to authenticate, scan a tool to check in/out.
- Physical 12 V electric strike lock with hardware watchdog and mechanical override.
- OLED + RGB LED + piezo buzzer feedback to the user.
- Admin dashboard over local Wi-Fi (phone or laptop).
- Full audit log of every check-in/out with CSV export.
- Print-ready barcode sheet generator for tool labels and user badges.
- Replicable deployment via Docker or `systemd` + a Pi OS image recipe.

## Tech Stack

- **Brain:** Raspberry Pi 4 (headless, Raspberry Pi OS Lite 64-bit)
- **Backend:** Python 3.11+ · FastAPI · SQLAlchemy 2.x · SQLite (WAL) · Alembic
- **Admin UI:** Jinja2 · HTMX · Pico.css (no build step)
- **Hardware I/O:** `evdev` (scanner) · `gpiozero` + `lgpio` (GPIO) · `luma.oled` (display)
- **Tests:** `pytest`, `httpx`, `pytest-asyncio`
- **Lint/format:** `ruff`, `black`, `mypy --strict`
- **CI:** GitHub Actions
- **Deploy:** Docker Compose or `systemd` units; Pi OS image recipe for fleet

## Repo Layout

```
tool-locker/
├── apps/
│   ├── api/               # FastAPI backend + admin UI
│   ├── scanner_daemon/    # Reads USB scanner via evdev, posts to API
│   └── hardware_daemon/   # Drives OLED, LED, buzzer, lock relay
├── web/
│   ├── templates/         # Jinja templates for admin dashboard
│   └── static/            # CSS + HTMX + Pico.css
├── prototype/             # Phase 1: single-file HTML demo
├── deploy/
│   ├── systemd/           # systemd unit files
│   ├── udev/              # udev rules (scanner stable device path)
│   └── pi-image/          # pi-gen or Ansible recipe for a fresh SD
├── docs/
│   ├── hardware/          # Wiring diagrams, BOM, pin maps
│   └── runbooks/          # Operational procedures
├── tests/                 # pytest
├── alembic/               # DB migrations
├── data/                  # SQLite DB (git-ignored)
├── config/                # Site config + secrets (git-ignored)
├── DEVELOPMENT_PLAN.md    # Full project plan
└── README.md
```

## Quick Start

### Phase 0 — local dev bootstrap

```bash
make install        # create .venv, install project + dev deps
make install-hooks  # (optional) wire up pre-commit git hooks
make check          # lint + typecheck + tests (same as CI)
```

See `make help` for all targets.

### Phase 1 — virtual prototype (no hardware, no backend)

Open `prototype/index.html` in any browser. Single-file demo using `localStorage` to prove the concept.

### Phase 2+ — backend (local dev on laptop)

```bash
make install
./.venv/bin/alembic upgrade head
./.venv/bin/uvicorn apps.api.main:app --reload --port 8000
```

Admin dashboard: `http://localhost:8000/`

### Phase 3+ — on the Pi

See [`DEPLOY.md`](./DEPLOY.md) (to be written in Phase 7) and Appendix E of `DEVELOPMENT_PLAN.md`.

## Roadmap

| Phase | Goal                                         | Status  |
|------:|----------------------------------------------|---------|
|     0 | Setup, learning, empty repo + CI             | **done** |
|     1 | Single-file HTML virtual prototype           | pending |
|     2 | FastAPI + SQLite backend (no hardware)       | pending |
|     3 | USB barcode scanner integration (evdev)      | pending |
|     4 | OLED + RGB LED + buzzer feedback hardware    | pending |
|     5 | 12 V electric strike lock + watchdog         | pending |
|     6 | Admin dashboard, history export, barcode PDF | pending |
|     7 | Hardening, Docker/systemd, Pi image recipe   | pending |

See `DEVELOPMENT_PLAN.md` for full detail, code skeletons, BOM, risk register, and glossary.

## License

[MIT](./LICENSE).
