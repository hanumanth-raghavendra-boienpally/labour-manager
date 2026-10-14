# WINFO Labour Manager · AI forecast approval and allocation

Full-stack app: **React (JavaScript/JSX) + Java 21 / Spring Boot 4 + PostgreSQL**, with the look and feel of the
*WINFO Labour Manager wireframes v2*.

```
 AI agent ──writes by itself──▶ DB1  labor_allocation.agent_playbook (+ agent_playbook_line)   read-only for the app
                                 │   the app checks DB1 every ~1.5 s for a new forecast (status PUBLISHED)
                                 ▼
                 Page 1 · Forecast   (store manager)  popup "New forecast request: FC-…" → approve or reject, with a comment
                                 │
                                 ▼
                               DB2  workflow schema: decision, snapshot of the forecast, allocation, notifications, audit log
                                 │
                                 ▼
                 Page 2 · Allocation (user)           popup "Forecast approved: allocation ready" or "Forecast rejected" → sees the outcome
                 Admin page          (admin)          forecast and allocation together, the agent's writes in DB1, the audit log
```

The app never starts or calls the agent: the agent writes into DB1 on its own, and the app reacts to what appears there.

| Sign-in | Person | Sees |
|---|---|---|
| `store_manager` / `Store@123` | Sam Carter, store manager | **Forecast** page. Popup when the agent writes a forecast into DB1; approves or rejects it with a comment; can reopen a rejected one |
| `user` / `User@123` | Ravi Kumar, user | **Allocation** page. Popup when the forecast is approved or rejected; sees the allocation (ready at once) or the rejection with its comment. Read-only |
| `admin` / `Admin@123` | System Admin | **Admin** page. Every request; the selected one's forecast and allocation together; the agent's writes in DB1; the audit log. Bell only, read-only |

The accounts are created in DB2 the first time the backend starts. Change the passwords before using this anywhere real.

**Forecast page (all live):** the *AI labour forecast* card, the four KPI cards (*Forecast required*, *Scheduled*, *Critical shortage
hours*, *Overstaffed hours*), the zone chips and the *Required vs scheduled staff by hour* chart (DB1 while pending, the DB2 snapshot
once decided), the popup, *Review and decision* (approve / reject with a comment) and *Review history*.
**Allocation page (all live, DB2):** the *Forecast allocation* card, four allocation KPI cards (Approved need, Scheduled, Staff-hours short, Coverage), *Zone coverage*, *Unfilled shortages*, *Remaining surplus* and the audit trail (no chart: that stays on the Forecast page); or the rejection
with its comment. There is no commit step: the allocation is ready as soon as the store manager approves.
**Bell and popups:** clicking a bell item or a popup button opens that exact request and highlights it on the page.

---

## 1. What you need

- **Java 21** and **Maven 3.9+**
- **Node.js 20+**
- **PostgreSQL** (local, or hosted such as Render/Neon) holding DB1. DB2 can be a second database on the same server.

## 2. Databases

### DB1 · the agent database (`labor_allocation`)
Already have it (Render/Neon/local)? Skip to the simulator. Otherwise, in pgAdmin create a database (e.g. `labor_db`) and run, in order:

1. `database/db1/01-labor_allocation_schema.sql`
2. `database/db1/02-seed_labor_allocation.sql` (sample data, ~30 s)

**Agent simulator (until your team's agent is live):** run `database/agent-simulator.sql` once on DB1. It adds a small, separate
`agent_sim` schema whose functions write `agent_playbook` + lines exactly like the agent does. The seed data contains no `PUBLISHED`
playbooks, so without the simulator (or the real agent) there is nothing to approve.

### DB2 · the workflow database (`workflow` schema)
Nothing to run. On start-up the backend creates the `workflow` schema and its tables (`database/db2-workflow-schema.sql`, safe to re-run).
On a **local** PostgreSQL it even creates the DB2 database if it does not exist. On a hosted provider, create an empty database first
(e.g. `CREATE DATABASE labour_db2;`), or point DB2 at the same database as DB1: DB2 keeps to its own `workflow` schema.
Two tables are kept but not used by this version: `requirement_override` and `agent_run`.

## 3. Start the backend (PowerShell)

One-time setup:

```powershell
cd backend
copy .env.example .env
notepad .env        # fill in DB1_URL and DB2_URL, save
```

`.env` example for a local PostgreSQL:

```
DB1_URL=postgresql://postgres:yourpassword@localhost:5432/labor_db
DB2_URL=postgresql://postgres:yourpassword@localhost:5432/labour_db2
```

Hosted URLs are pasted exactly as the provider shows them (`postgresql://USER:PASSWORD@HOST/DATABASE`); SSL is added automatically.

Then, every time:

```powershell
cd backend
mvn spring-boot:run
```

You should see `DB1 OK (agent data, read-only)`, `DB2 OK (workflow data)` and `Started LabourManagerApplication`.
If a database setting is wrong you get a short message saying what to change, not a stack trace.
The API listens on **http://localhost:8080**.

## 4. Start the frontend

```powershell
cd frontend
npm install
npm run dev
```

Open **http://localhost:5173**. Vite forwards `/api` to port 8080.

## 5. Demo: the whole workflow

Use one browser window per person (each keeps its own sign-in), e.g. a normal and a private window, or two browsers.

1. Sign in as **store_manager**. The Forecast page says *Waiting for the agent*.
2. Sign in as **user**. The Allocation page says *Nothing allocated yet*.
3. pgAdmin, query tool on **DB1** (this is "the agent writes into DB1"):
   ```sql
   SELECT agent_sim.publish('DAL01', DATE '2026-10-10');
   ```
4. Within a few seconds the **store manager** gets the centered popup *New forecast request: FC-DAL01-20261010-v1* (Request, Received,
   **Later** / **Review forecast**). **Review forecast** opens the forecast. Add a comment, then **Approve and allocate**.
   The decision, the comment and a snapshot of the forecast go to DB2, and the allocation is created, ready at once.
5. The **user** gets the popup *Forecast approved: allocation ready*. **View allocation** shows the Forecast allocation card,
   the allocation KPI cards, zone coverage, shortages, surplus and the audit trail.
6. Again on DB1: `SELECT agent_sim.publish('ATL01', DATE '2026-10-10');`. The store manager **rejects** it with a comment;
   the user gets *Forecast rejected* and the Allocation page shows who rejected it and the comment. Nothing is allocated.
7. Sign in as **admin**: every request with its decision and allocation. Click a row (or a bell item) to see that request's forecast
   and allocation together, plus the agent's writes in DB1 and the audit log.

More things to try on DB1:

| SQL | What happens |
|---|---|
| `SELECT agent_sim.publish('ATL01', DATE '2026-10-10');` again while it is pending | the agent rewrote it: version 2 replaces version 1 |
| ... after it was approved | ignored (approved forecasts are final), noted in the audit log |
| `SELECT agent_sim.publish('DAL01', DATE '2026-10-09');` | re-sends a playbook from the sample data |
| `SELECT * FROM agent_sim.status();` | what the agent has written |

**Start over:** `SELECT agent_sim.cleanup();` on DB1, then run `database/reset-db2.sql` on DB2.
**When the real agent goes live:** run both of those once, so the simulator's rows do not mix with the real ones.

## 6. Contract for the agent team (what the agent writes into DB1)

The app never writes to DB1. A **forecast request** is one `labor_allocation.agent_playbook` row whose `status` is `PUBLISHED`,
with its `agent_playbook_line` rows. Tables the Forecast page reads: `agent_playbook`, `agent_playbook_line`, `dc`, `dc_zone`,
`agent_model_version`, `shift_definition`, `carrier_cutoff`.

| Column | Used as |
|---|---|
| `agent_playbook.playbook_id` | no default: `max(playbook_id) + 1` for a new row |
| `dc_id`, `business_date` | which DC and day; **one playbook per DC and date** (`UNIQUE (dc_id, business_date)`) |
| `status` | `DRAFT` while writing, `PUBLISHED` as the very last write = "please approve or reject" |
| `generated_at` | set to `clock_timestamp()` in the same statement that sets `PUBLISHED`; **identifies the version** |
| `model_version_id` (must exist, e.g. 2), `agent_mode`, `fcst_volume*`, `static_plan_hours`, `recommended_*`, `risk_windows`, `narrative` | the forecast card and its chips |
| `agent_playbook_line.zone_id` (a zone of that DC), `local_hour` (DC clock hour 0–23) | zone × hour of the business day (06:00 to 05:59) |
| `recommended_hc` | **required staff**: *Forecast required*, the chart's dashed bars |
| `static_plan_hc` | **scheduled staff**: *Scheduled*, the chart's blue bars |
| `fcst_workload`, `required_hours`, `flex_in`, `flex_out` | NOT NULL, must be written; not shown on the page |

Rules:
- Write the header as `DRAFT`, then all its lines, then set `PUBLISHED` (+ new `generated_at`) last. A playbook without lines is not picked up.
- A revised forecast for the same DC and date **updates** that row (lines with `INSERT … ON CONFLICT (playbook_id, zone_id, local_hour) DO UPDATE`)
  and sets a new `generated_at`: it becomes the next version. If the previous version is still pending it is superseded;
  if it was already approved, the new one is ignored.
- Write a line for every zone of the DC and every hour 0–23; a missing line counts as 0.

## 7. API

| Method | Path | Who |
|---|---|---|
| POST | `/api/auth/login` · GET `/api/auth/me`, `/api/auth/demo-identities` | everyone |
| GET | `/api/meta/dcs`, `/api/meta/dates?dcId=` | signed in |
| GET | `/api/forecast?dcId=&date=`, `/api/forecast/{requestId}` | store manager, admin |
| POST | `/api/forecast/{requestId}/approve` `{rowVersion, comment?}` | store manager |
| POST | `/api/forecast/{requestId}/reject`, `/reopen` `{rowVersion, comment?}` | store manager |
| GET | `/api/allocation?dcId=&date=`, `/api/allocation/request/{requestId}` | user, admin |
| GET/POST | `/api/notifications`, `/{id}/read`, `/read-all` | signed in |
| GET | `/api/admin/overview` | admin |

The wrong role gets **403**; a repeated or stale action (approving twice, an old `rowVersion`, a version the agent has since replaced) gets **409**.

## 8. Settings (`backend/.env`)

| Variable | Default | Meaning |
|---|---|---|
| `DB1_URL` (or `DATABASE_URL`) | required | DB1, the agent database. Alternative: jdbc URL + `DB1_USER` + `DB1_PASSWORD` |
| `DB2_URL` | DB1's database | DB2, the workflow database. Alternative: jdbc URL + `DB2_USER` + `DB2_PASSWORD` |
| `AGENT_REQUEST_STATUSES` | `PUBLISHED` | `agent_playbook.status` values that count as a request, comma-separated |
| `AGENT_POLL_MS` | `1500` | how often DB1 is checked for a new forecast |
| `TOKEN_SECRET` | dev value | signs sign-in tokens |
| `PORT` | `8080` | API port |
| `DEMO_USERS` | `true` | create the three demo sign-ins |

## 9. Project layout

```
backend/    Spring Boot 4 (Java 21)
  agent/       AgentPlaybookReader (reads DB1), AgentWatcher (polls DB1), RequestIntake (registers a request in DB2, notifies)
  forecast/    page 1: view, approve / reject / reopen; Grid = the four KPI numbers
  allocation/  page 2: outcome, allocation, audit trail (read-only)
  admin/  meta/  notify/  audit/  auth/  db/ (two connection pools: Db1 read-only, Db2)
frontend/   React 19 + Vite, plain JavaScript (JSX)
  pages/       ForecastPage, AllocationPage, AdminPage
  components/  ForecastCard, ForecastStats (KPI cards + zone chips + chart), StaffingChart, AllocationCard (+ AllocationDetails), DecisionRecord, ...
  layout/      Shell: header, navigation, bell, popups
database/
  db1/                       your schema and seed for DB1
  agent-simulator.sql        stand-in for the agent (DB1)
  db2-workflow-schema.sql    DB2 tables (run automatically)
  reset-db2.sql              clear DB2 for a fresh demo
```

## 10. Troubleshooting

- **"DATABASE SETUP" box on start-up:** the message says which of DB1/DB2 is wrong and what to change in `backend/.env`.
- **No popup after `agent_sim.publish(...)`:** check the playbook is `PUBLISHED` and has lines (`SELECT * FROM agent_sim.status();`);
  the backend log prints `registered as forecast request` when it picks one up. A popup put off with **Later** stays away for that browser
  tab (it comes back in a new tab or window); the request is always in the bell.
- **`function agent_sim.publish does not exist`:** run `database/agent-simulator.sql` on DB1 first.
- **Sign-in page says it can't load demo identities:** the backend isn't running on port 8080.
