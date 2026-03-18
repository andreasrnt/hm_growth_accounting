# HeyMax Growth & Engagement Analytics

End-to-end analytics stack built as part of the HeyMax Senior Analytics Engineer take-home assessment. Covers data ingestion, transformation, growth accounting, cohort retention, and engagement analysis.

---

## Stack

| Layer | Tool |
|---|---|
| Warehouse | BigQuery |
| Transformation | dbt Cloud |
| Dashboard | Tableau Public |
| CI/CD | GitHub Actions |

---

## Quick Start

### 1. BigQuery Setup

- Create a GCP project
- Create a dataset called `growth_accounting`
- Upload the raw CSV to a table called `heymax.event_stream`

### 2. dbt Setup

Clone the repo:
```bash
git clonehttps://github.com/andreasrnt/hm_growth_accounting.git
cd hm_growth_accounting
```

### Alternative — Run Locally with Seed Data

You can load the bundled CSV directly into your warehouse using dbt seed:

1. Skip BigQuery on step 1 above
2. Load the seed data:
```bash
dbt seed
```
3. Then run the full pipeline:
```bash
dbt build
```

This loads `seeds/event_stream.csv` into `heymax.event_stream` and runs
all models and tests against it. No access to the production source table required.


Create a `profiles.yml` in `~/.dbt/`:
```yaml
growth_accounting:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: your-gcp-project-id
      dataset: growth_accounting
      threads: 4
      timeout_seconds: 300
```

Install dependencies and run:
```bash
dbt deps
dbt build
```

### 3. Run Tests
```bash
dbt test
```

All tests pass on the current dataset. See [Known Limitations](#known-limitations) for documented exceptions.

### 4. dbt Docs
```bash
dbt docs generate
dbt docs serve
```

Open `http://localhost:8080` to browse model documentation.


---

## Project Structure

```
├── .github/
│   └── workflows/
│       └── ci.yml
├── models/
│   ├── staging/
│   │   └── stg_event_stream.sql
│   ├── marts/
│   │   ├── dim_user.sql
│   │   ├── fct_events.sql
│   │   ├── fct_growth_daily.sql
│   │   ├── fct_growth_weekly.sql
│   │   ├── fct_growth_monthly.sql
│   │   └── fct_growth_agg.sql
│   └── metrics/
│       └── fct_cohort.sql
│   └── schema.yml
├── tests/
│   ├── no_duplicate_users.sql
│   ├── no_negative_miles.sql
├── seeds/
│   ├── event_stream.csv
├── AGENTDESIGN.md
├── dbt_project.yml
├── README.md
└── REFLECTION.md
```

---

## Data Model

```
heymax.event_stream
        │
        ▼
stg_event_stream
        │
        ├──────────────────► dim_user
        │                        │
        └────────────────────────┼──► fct_events
                                 │         │
                                 │         ├──► fct_growth_daily
                                 │         ├──► fct_growth_weekly
                                 │         ├──► fct_growth_monthly
                                 │         ├──► fct_growth_agg
                                 │         └──► fct_cohort
```

---

## Design Decisions & Assumptions

### Data Ingestion
- Events are deduplicated on `(user_id, event_time)` using `QUALIFY ROW_NUMBER() = 1` in `stg_event_stream`
- `event_id` is a surrogate key derived from `CONCAT(user_id, formatted_event_time)` — assumes no two events from the same user occur within the same second
- Null `user_id` and `event_time` are filtered at source — these cannot be meaningfully attributed
- `gender` and `utm_source` default to `'unknown'` when null to preserve row counts

### dim_user
- SCD-1 — user attributes reflect the latest known values, not historical snapshots
- `gender` and `country` reflect latest touch, not acquisition-time values — documented assumption
- User tier thresholds: Gold = 10+ events over 2+ months, Silver = 5+ events over 2+ months, Bronze = 3+ events, New = all others
- `cohort_date` = `MIN(event_date)` — immutable, used as the fixed cohort anchor for traditional retention

### fct_events
- Incremental model with `insert_overwrite` strategy — daily runs process the last 3 days to account for late-arriving events
- `INNER JOIN` with `dim_user` — events with no matching user are excluded. A dbt `relationships` test catches any unmatched users
- Boolean flags (`is_earning`, `is_redemption`, `is_social`, `is_discovery`) pre-computed here for downstream efficiency

### Growth Accounting
- Three separate models (`fct_growth_daily`, `fct_growth_weekly`, `fct_growth_monthly`) — one per grain for query efficiency
- Classification logic uses `LEAD`/`LAG` window functions instead of correlated subqueries for performance
- Churned users are synthetic rows — `activity_date` is set to the period after last activity so Tableau can filter on `user_classification` directly
- Metric definitions:
  - **New** = first ever active period
  - **Retained** = active in consecutive periods
  - **Resurrected** = active now after a gap of 2+ periods
  - **Churned** = active last period, not this period (synthetic row)
  - **Quick Ratio** = (New + Resurrected) / Churned

### Cohort Retention
- Consecutive cohort model — cohort resets every time a user churns and returns (Resurrected)
- Uses `LEAD` to identify `next_cohort_period` — avoids correlated subqueries
- Supports Weekly and Monthly grains in a single model
- A gap > 1 period triggers a new cohort start

### fct_growth_agg
- Miles metrics (`total_miles_earned`, `total_miles_redeemed`) reflect period-specific activity, not lifetime user totals
- Aggregated at `(activity_period, period, transaction_category, acquisition_channel, country, platform, gender)` grain
- Primary data source for Tableau engagement, segmentation, and miles charts

---

## Dashboard

The Tableau dashboard covers five sections:

| Section | Charts |
|---|---|
| KPI Overview | New, Retained, Resurrected, Churned users · Miles Earned vs Redeemed · Quick Ratio |
| Active Entity Growth | Stacked bar (churned below x-axis) · Quick Ratio trend line |
| Cohort Retention | Consecutive retention triangle (Weekly / Monthly) |
| Engagement Analysis | Miles earned vs redeemed over time · Transaction category breakdown · Event type distribution |
| User Segmentation | Acquisition channel · Country · Platform |

KPI cards show the latest full period snapshot. The period switcher (Daily / Weekly / Monthly) controls all trend charts simultaneously.

View the live Tableau dashboard here: https://public.tableau.com/app/profile/andreas.rinanto2835/viz/AndreasRinanto-GrowthEngagementDashboard/GrowthEngagementDashboard

---

## CI/CD

GitHub Actions runs `dbt parse` on every push to validate SQL syntax and model references. See `.github/workflows/ci.yml`.

To extend CI to run full `dbt test` on push, add BigQuery service account credentials as a GitHub Actions secret and replace `dbt parse` with `dbt build`.

---

## Known Limitations

- **Dataset ends December 2025** — the final period (Dec 2025) is a partial month with only 1 day of data. KPI cards use the latest full period (Nov 2025) to avoid misleading numbers
- **New user acquisition stops after June 2025** — the dataset shows no new users after this point, which is reflected in the growth accounting chart as a real data pattern, not a bug
- **event_id collision risk** — the current surrogate key truncates to second precision. If two events from the same user fire within the same second, one is deduplicated.
- **User tier thresholds are heuristic** — Bronze/Silver/Gold thresholds are based on reasonable assumptions about engagement levels, not business-defined criteria
- **fct_growth_agg triples storage** — unioning three grains into one model triples the row count. At scale this would be replaced with grain-specific aggregation models or a semantic layer

---

## What I Would Do With More Time and Have The Access

- Add a streaming ingestion layer (Pub/Sub → BigQuery) to replace daily batch
- Implement dbt snapshots for true SCD-2 user history
- Add a logging framework to track model run times and row counts
- Extend CI to run full `dbt test` on every PR with BigQuery service account auth

---