# Persistent Monthly Login Rollup Implementation Plan

## Overview

Preserve member login history beyond the LoginHistory purge by summing the login
mirror into a durable, lightweight rollup table — one row per member per month —
that the Member Logins Per Month chart and its per-member drill read from. This
also fixes the drill's "sort by login count" (a real `Login_Count__c` field is
sortable; a report grouping's record-count aggregate is not).

## Current State Analysis

- **Chart + drill read live from the mirror.** `Membership/Member_Logins_Per_Month`
  reports on `Fiscal_Year_Login_History__c` (one row per login), grouped by month
  with a per-member sub-grouping, filtered `Exclude_From_Member_Login_Stats__c = false`.
- **The mirror is purged.** `LoginHistoryCleanupBatch` runs every **May 1** and
  deletes `Fiscal_Year_Login_History__c` rows older than Feb 1 of the previous
  fiscal year (keeps ~one fiscal year). So login history older than ~1 year is
  permanently lost from the chart. The mirror exists for license sorting
  (`LicenseShuffleBatch`), not long-term reporting.
- **Grouping sort limitation.** A report grouping cannot be reliably sorted by the
  record-count aggregate via metadata (`sortByName=false` falls back to sorting by
  the member's name — confirmed in the UI). So the drill currently lists members
  alphabetically, not by login count.
- **Proven pattern to mirror.** `Monthly_Active_Members__c` + `MembershipSnapshotBatch`
    - `MembershipSnapshotScheduler` already implement a month-keyed rollup (one row
      per month) with a backfill batch, a scheduler, and a custom report type. The
      login rollup follows the same shape at member-month grain.

### Key Discoveries

- Source fields: `Fiscal_Year_Login_History__c.User__c`, `.Login_Time__c`,
  `.Exclude_From_Member_Login_Stats__c` (already filters staff/integration/test).
- Per-month aggregate `SELECT User__c, User__r.Name, COUNT(Id) ... WHERE Login_Time__c`
  in a single month `GROUP BY User__c, User__r.Name` returns ~480 rows (members) —
  under the 2000-row aggregate cap, so batching **by month** keeps each query safe.
- One row per (member, month) lets the **chart** sum `Login_Count__c` by month and
  the **drill** show member detail rows sorted by `Login_Count__c` descending —
  fixing the sort because it becomes a column sort, not a grouping-aggregate sort.
- Custom-object standard report types are rejected as a `reportType` token; a
  **custom report type** is required (per repo gotchas / the membership work).
- Date fields can't be external ids — use a Text composite `Key__c`.

## Desired End State

A `Member_Login_Month__c` table holds one frozen row per member per month
(member, month, login count), accumulating indefinitely and surviving the May
purge. The Member Logins Per Month chart reads totals from it (identical line),
and clicking a month shows that month's members sorted by login count descending.
A daily job keeps the current (and just-closed) month fresh; closed months are
never recomputed once the source ages out.

Verify: after deploy + backfill, the chart line matches today's values; the prod
rollup has one row per member per month with summed counts equal to the mirror's
filtered counts; the drill lists members by descending count.

## What We're NOT Doing

- Not removing or changing `Fiscal_Year_Login_History__c` or `LoginHistoryCleanupBatch`
  (the mirror stays for license sorting; the rollup is downstream).
- Not changing the Active Members chart (it already persists via
  `Monthly_Active_Members__c`). A parallel per-member membership drill is out of
  scope here.
- Not storing individual login events long-term — only per-member monthly counts.
- Not splitting into separate "monthly totals" and "member detail" tables; one
  member-month table serves both (totals are a sum). Revisit only if data volume
  ever makes the summed line slow (not expected at this size).

## Implementation Approach

Add a member-month rollup object, populate it from the filtered mirror with a
by-month batch (backfill once; daily recompute of the trailing two months so
closed months freeze and the current month stays live), then repoint the existing
report and dashboard component at the rollup. Deploy staging-first, then
production (default org). Mirrors the membership-snapshot architecture.

## Phase 1: Rollup object, report type, permission set

### Changes Required

#### 1. New object `Member_Login_Month__c`

**Files**: `force-app/main/default/objects/Member_Login_Month__c/...`

Fields (lightweight):

- `Key__c` — Text(40), External Id, Unique, Required. `<userId>-YYYY-MM`.
- `User__c` — Lookup(User), `deleteConstraint = SetNull` (row survives if the
  member's User is later deleted).
- `Member_Name__c` — Text(121), Required. Denormalized member full name so the row
  is self-describing after a purge or user deletion.
- `Month__c` — Date, Required. First of month (report date grouping).
- `Login_Count__c` — Number(18,0). Logins by that member that month.
- `Calculated_On__c` — DateTime. Freshness stamp.
- AutoNumber Name `MLM-{0000}`.

#### 2. Custom report type `Member_Login_Month`

**File**: `force-app/main/default/reportTypes/Member_Login_Month.reportType-meta.xml`
Base object `Member_Login_Month__c`; columns `Month__c`, `Member_Name__c`,
`Login_Count__c`, `User__c`, `Calculated_On__c`.

#### 3. Permission set FLS

**File**: add to `Membership_Reporting` (reuse) — object read + viewAll, FLS on
`Login_Count__c`, `Member_Name__c`, `User__c`, `Calculated_On__c` (not on the
required `Key__c`/`Month__c`, which reject FLS).

### Success Criteria

#### Automated Verification

- [ ] Deploys to staging: `sf project deploy start --target-org staging -d force-app/main/default/objects/Member_Login_Month__c -d force-app/main/default/reportTypes/Member_Login_Month.reportType-meta.xml -d force-app/main/default/permissionsets/Membership_Reporting.permissionset-meta.xml`
- [ ] `Key__c` is unique external id; `Login_Count__c` is Number.

#### Manual Verification

- [ ] Object/fields visible to a Membership_Reporting holder.

---

## Phase 2: Rollup batch + scheduler + tests

### Changes Required

#### 1. `LoginRollupBatch` (Database.Batchable<Date>, Stateful)

**File**: `force-app/main/default/classes/LoginRollupBatch.cls`

- Constructed with a month range; default range = earliest mirror month → current
  month (backfill). `start()` yields first-of-month Dates.
- `execute()` per month: aggregate the filtered mirror for that month and upsert
  one row per member:

```apex
for (AggregateResult ar : [
  SELECT User__c uid, User__r.Name nm, COUNT(Id) cnt
  FROM Fiscal_Year_Login_History__c
  WHERE Exclude_From_Member_Login_Stats__c = false
    AND User__c != null
    AND Login_Time__c >= :monthStart AND Login_Time__c < :nextMonth
  GROUP BY User__c, User__r.Name
]) {
  // build Member_Login_Month__c(Key__c = uid + '-' + yyyymm, User__c = uid,
  //   Member_Name__c = nm, Month__c = monthStart, Login_Count__c = cnt, Calculated_On__c = now)
}
Database.upsert(rows, Member_Login_Month__c.Key__c, false); // partial success
```

- **Freeze semantics**: the batch only writes the months in its range. Backfill
  writes all; the scheduler passes only the trailing two months, so closed months
  are written once and then left untouched — they persist after the May purge.

#### 2. `LoginRollupScheduler` (Schedulable)

**File**: `force-app/main/default/classes/LoginRollupScheduler.cls`

- Runs `new LoginRollupBatch(today.toStartOfMonth().addMonths(-1), today.toStartOfMonth())`
  so the current month stays live and the just-closed month gets a final value
  after late daily syncs. Guarded by `Test.isRunningTest()` like the existing
  schedulers.

#### 3. Tests

**File**: `force-app/main/default/classes/LoginRollupBatchTest.cls`

- Insert `Fiscal_Year_Login_History__c` rows for 2 members across 2 months (the
  object is writable; the sync batch normally creates them). Run the batch; assert
  one `Member_Login_Month__c` row per member-month with the right `Login_Count__c`,
  correct `Key__c`, and that `Exclude_From_Member_Login_Stats__c = true` rows are
  not counted. Cover the scheduler (schedules cleanly).

### Success Criteria

#### Automated Verification

- [ ] Deploys to staging with tests: `... --test-level RunSpecifiedTests --tests LoginRollupBatchTest` (≥75% coverage, all pass).
- [ ] Backfill run populates rows in prod: per-month `SUM(Login_Count__c)` equals
      the mirror's filtered record count for that month (spot-check current month
      = ~ the live filtered count).

#### Manual Verification

- [ ] Excluded accounts (staff/integration/test) produce no rollup rows.

**Implementation Note**: deploy + run backfill in production read-after-write to
confirm totals before Phase 3 repoints the chart.

---

## Phase 3: Repoint report + dashboard, schedule, verify

### Changes Required

#### 1. `Member Logins Per Month` report → source the rollup

**File**: `force-app/main/default/reports/Membership/Member_Logins_Per_Month.report-meta.xml`

- `reportType` → `Member_Login_Month__c` (custom report type token).
- Row grouping: `Month__c` (Month granularity) only (no member sub-grouping).
- Columns (detail rows, one per member): `Member_Name__c`, `Login_Count__c`, with
  `aggregateTypes = Sum` on `Login_Count__c` for the month/grand totals.
- `sortColumn = Member_Login_Month__c$Login_Count__c`, `sortOrder = Desc` — sorts
  each month's member detail rows by login count descending (**fixes #1**).
- `showDetails = true`; keep `INTERVAL_CUSTOM` All-Time on `Month__c`.

#### 2. Dashboard line component → sum the count

**File**: `force-app/main/default/dashboards/Membership/Membership_Overview.dashboard-meta.xml`

- `groupingColumn = Member_Login_Month__c$Month__c`.
- `chartSummary` → `column` = the Sum of `Login_Count__c` (e.g. `s!Member_Login_Month__c$Login_Count__c`) instead of `RowCount`.
- Keep `drillEnabled = true`, single line.

#### 3. Schedule the job

- `System.schedule('Member Login Rollup - Daily', '0 0 3 * * ?', new LoginRollupScheduler())`
  in staging and production (3 AM daily, after the 2 AM login sync).

### Success Criteria

#### Automated Verification

- [ ] Report + dashboard deploy to staging then production.
- [ ] `Reports.ReportManager.runReport` grand total `SUM(Login_Count__c)` equals
      the prior member-login total (~25,862) and month count matches.
- [ ] Scheduled job present: `SELECT ... FROM CronTrigger WHERE CronJobDetail.Name='Member Login Rollup - Daily'`.

#### Manual Verification

- [ ] Chart still shows one line of total member logins per month (unchanged shape).
- [ ] Clicking a month opens the per-member breakdown sorted by login count
      **descending** (Tyler Nyman 55 at top, not alphabetical).
- [ ] After a simulated/real May purge window, previously-frozen months remain on
      the chart (data persists).

## Testing Strategy

- **Unit** (`LoginRollupBatchTest`): correct per-member-month counts; exclusion
  honored; idempotent upsert (re-run doesn't duplicate); scheduler schedules.
- **Integration (prod, read-only verification)**: backfill totals reconcile to the
  mirror; report grand total unchanged; drill order correct.
- **Manual**: dashboard line shape unchanged; drill sort descending; persistence
  across the purge (verify a frozen month is untouched by a scheduler run).

## Performance Considerations

Tiny: one aggregate query per month (~480 rows) during backfill (~13 queries
total now), one to two per daily run. The rollup is ~480 members × months (~6k
rows/year) — a trivially summable line. No change to the mirror or license batch.

## Migration Notes

Backfill is one-time `Database.executeBatch(new LoginRollupBatch(), 12)`. The
mirror is unchanged. Reversible: repoint the report/dashboard back to
`Fiscal_Year_Login_History__c` and the chart works as before. The rollup only adds
data; nothing is deleted.

## References

- Source mirror: `force-app/main/default/objects/Fiscal_Year_Login_History__c/`
- Purge job: `force-app/main/default/classes/LoginHistoryCleanupBatch.cls`
- Pattern to mirror: `force-app/main/default/classes/MembershipSnapshotBatch.cls`,
  `MembershipSnapshotScheduler.cls`, `objects/Monthly_Active_Members__c/`
- Report/dashboard: `force-app/main/default/reports/Membership/Member_Logins_Per_Month.report-meta.xml`,
  `dashboards/Membership/Membership_Overview.dashboard-meta.xml`
- Related future-work note: memory `project-monthly-metrics-rollup-plan`
