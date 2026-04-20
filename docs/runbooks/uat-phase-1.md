# UAT — Phase 1 Virtual Prototype

> User Acceptance Test plan for `prototype/index.html`. Run through this once
> end-to-end on a fresh browser profile (or after clicking **Clear all data**)
> to sign off Phase 1 before starting Phase 2.

---

## 0. Scope and intent

**Under test:** the single-file browser prototype at `prototype/index.html`.

**Purpose:** confirm the prototype demonstrates the intended check-in / check-out
flow, persists data as expected, and behaves predictably in edge cases. This is
*not* a test of the Raspberry Pi, scanner, hardware, or FastAPI backend — those
arrive in Phases 2–5.

**Out of scope:**

- Visual/CSS polish beyond "it's readable"
- Cross-browser pixel parity
- Accessibility audit (deferred; see `docs/backlog.md` once created)
- Performance at scale (prototype is for single-digit tools)

**Exit criteria:** every test case below passes. Any failure is either fixed
before closing Phase 1 or logged as a known limitation in the report at the
bottom of this file.

---

## 1. Prerequisites

1. A modern desktop browser. Tested configurations:
   - Firefox ≥ 128
   - Chromium / Chrome / Edge ≥ 120
   - Safari ≥ 17
2. A recent clone of the repo with `prototype/index.html` present.
3. No prior Tool Locker data in the browser (either use a private/incognito
   window, a fresh profile, or click **Clear all data** before starting).

### Starting the prototype

Pick one:

**A. Double-click** `prototype/index.html` in your file manager.
The browser opens it on a `file://` URL. This is the zero-setup path.

**B. Local HTTP** (use this if your browser limits features on `file://`):

```bash
python3 -m http.server --directory prototype 8000
# then open http://127.0.0.1:8000/ in the browser
```

Both modes must behave identically for this UAT to pass.

---

## 2. Test environment log (fill in at run time)

| Field             | Value                                |
|-------------------|--------------------------------------|
| Date              |                                      |
| Tester            |                                      |
| Git commit        | `git rev-parse --short HEAD` →       |
| Browser + version |                                      |
| OS                |                                      |
| Serving mode      | `file://` / `http://127.0.0.1:8000/` |

---

## 3. Test cases

Each case lists **steps**, **expected result**, and a **pass/fail** box. "Data"
means the contents of `localStorage` keys `tl.tools` and `tl.history` (inspect
via DevTools → Application → Local Storage).

### TC-01  First load renders cleanly

1. Open the page on a fresh profile (no prior data).
2. Observe the page.

**Expected:**

- Page title shows "Tool Locker — Virtual Prototype".
- **Tools** table header is visible; body shows placeholder text like
  "No tools yet. Add one above."
- **History** list shows "No history yet." or similar empty state.
- No browser console errors (open DevTools → Console).

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-02  Add a tool

1. Type `Cordless drill` into the "Tool name" input.
2. Press **Add tool**.

**Expected:**

- Input clears.
- Tools table now shows one row: `Cordless drill` / `Available` / (empty
  borrower) / button labelled something like **Check out**.
- History section still says empty (adding a tool is not a loan event).
- `localStorage.tl.tools` contains one object:
  `{"name":"Cordless drill","status":"Available","borrower":""}`.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-03  Add a second tool

1. Add `Impact driver`.
2. Add `Tape measure`.

**Expected:** three rows visible in the order they were added. `tl.tools`
array length is 3.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-04  Reject duplicate tool name (case-insensitive)

1. Try to add `cordless drill` (lower case).
2. Try to add `  Impact driver  ` (surrounding whitespace).

**Expected:**

- Browser shows an alert / warning that a tool with that name already exists.
- No new row is added; `tl.tools` still has length 3.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-05  Reject empty / whitespace-only tool name

1. Click **Add tool** with the input empty.
2. Type three spaces, click **Add tool**.

**Expected:** nothing is added. No console errors.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-06  Check out a tool

1. Click the check-out button on the `Cordless drill` row.
2. When prompted, enter `Kaj`.
3. Click OK.

**Expected:**

- Row updates: status becomes `Loaned` (red-ish), borrower becomes `Kaj`,
  action button label flips to something like **Check in**.
- History list gains a new most-recent entry like
  `<timestamp> — checkout: Cordless drill (Kaj)`.
- `tl.tools[0].status === "Loaned"` and `tl.tools[0].borrower === "Kaj"`.
- A new entry is appended to `tl.history` with fields `ts`, `action:"checkout"`,
  `tool:"Cordless drill"`, `borrower:"Kaj"`.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-07  Cancel the borrower prompt

1. Click the check-out button on `Impact driver`.
2. When prompted for the borrower, press **Cancel** (or OK with empty value).

**Expected:** no state change. `Impact driver` stays `Available`. No history
entry added.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-08  Check a tool back in

1. Click the check-in button on the `Cordless drill` row.

**Expected:**

- Row returns to `Available`, borrower clears.
- History gains a new most-recent entry like
  `<timestamp> — checkin: Cordless drill` (no borrower in parens).
- `tl.tools[0].status === "Available"`, `tl.tools[0].borrower === ""`.
- Previous `checkout` entry is still present in history.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-09  "Show only available" filter

1. Check out `Impact driver` to borrower `Sam`.
2. Check the **Show only available** box.

**Expected:**

- Tools table shows only rows whose status is `Available`.
- `Impact driver` is hidden while the filter is on.
- Unchecking the box restores the full list.
- Filter state does **not** need to persist across reloads in v1 (noted as
  acceptable; re-filter after reload is fine).

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-10  History capped at most-recent 20 entries

1. Perform enough checkouts/checkins to generate > 20 events total
   (e.g. toggle `Tape measure` eleven times, with borrower `Alex`, which
   yields 22 events if you started from zero on this tool).
2. Observe the **History** list.

**Expected:**

- The list shows **at most 20** entries, most-recent first.
- The underlying `tl.history` array may be longer than 20 (display-cap only);
  older entries are not purged silently. *If the implementation does purge,
  note that as an accepted behavior below.*

Result: ☐ pass ☐ fail — notes: ____________________________________________

Implementation note observed (cap vs purge): __________________________________

---

### TC-11  Persistence across reload

1. Ensure at least one loaned tool, one available tool, and a few history
   events exist.
2. Full-reload the page (Ctrl+R / Cmd+R).

**Expected:**

- Tool list, statuses, borrowers, and history all render identically to
  before the reload.
- No console errors on reload.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-12  Cross-tab sync

1. Open the prototype in tab A.
2. Open the same URL in tab B.
3. In tab A, add a tool named `Oscilloscope`.
4. Without reloading, switch to tab B.

**Expected:** tab B's tool list updates to include `Oscilloscope` within a
second or two (driven by the `storage` event).

Result: ☐ pass ☐ fail — notes: ____________________________________________

If this fails but everything else passes, record as a known limitation — it's
a nice-to-have, not a gating requirement for Phase 1.

---

### TC-13  Injection-safe rendering of user input

1. Add a tool with the literal name `<img src=x onerror=alert(1)>`.
2. Check it out to a borrower named `"><script>alert('xss')</script>`.

**Expected:**

- No alert dialog appears.
- No browser console error about blocked script execution.
- The tool row shows the literal text of the name (angle brackets visible as
  text, not rendered as HTML).
- Same for the borrower in the tools row and history entry.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-14  Clear all data

1. With several tools and history entries present, click **Clear all data**.
2. Confirm the dialog.

**Expected:**

- Tools table returns to empty state.
- History list returns to empty state.
- `tl.tools` and `tl.history` are removed (or empty arrays) in localStorage.
- Refreshing the page still shows the empty state.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-15  Clear all data — cancel path

1. Add a tool.
2. Click **Clear all data**.
3. Cancel the confirmation dialog.

**Expected:** no data change. Tool list untouched.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-16  Mobile / small viewport usability

1. Open the prototype on a phone **or** resize the browser window to ~375 px
   wide (iPhone portrait).
2. Add a tool and toggle it.

**Expected:**

- Page is readable without horizontal scrolling the whole body.
- Buttons are tappable (no overlapping controls).
- Prompts work.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

### TC-17  Offline behavior

1. While the page is open, put the browser into offline mode
   (DevTools → Network → throttling → Offline, or disable Wi-Fi for the
   `http://` serving mode).
2. Add a tool, check it out, check it in.
3. Reload the page.

**Expected:** all operations and the reload succeed. The prototype has **no**
network dependencies.

Result: ☐ pass ☐ fail — notes: ____________________________________________

---

## 4. Sign-off report (fill in at end of run)

| Summary                                | Value  |
|----------------------------------------|--------|
| Total test cases                       | 17     |
| Passed                                 |        |
| Failed                                 |        |
| Known limitations accepted             |        |

**Overall verdict:** ☐ Phase 1 accepted · ☐ Fixes required before sign-off

**Failures / follow-ups:**

1.
2.
3.

**Tester signature / name + date:** __________________________________

---

## 5. What this proves (and what it doesn't)

**Proves:**

- The data model (tool → status + borrower; history as an append-only log)
  is coherent and usable.
- The core interaction loop (add → check out → check in → review history)
  works without a backend.
- User-visible behavior is defined well enough to regression-test against
  once the real FastAPI backend lands in Phase 2.

**Does not prove:**

- Anything about the Raspberry Pi, the scanner, the lock, or real-world
  concurrency.
- That the data model scales past a few dozen tools (it won't — SQLite in
  Phase 2 will).
- Security of a multi-user system (there is no auth here).

Those concerns are intentionally deferred to their respective phases.
