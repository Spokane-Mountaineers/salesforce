# License Sorting Scripts

This folder contains all scripts related to the automated license sorting system.

## Setup Scripts

- **`grant_fls_fiscal_year_login_history.apex`**: Grants Field-Level Security (FLS) access to System Administrator profile for all `Fiscal_Year_Login_History__c` fields. Run this after deploying the custom object.

- **`migrate_login_history_initial.apex`**: Executes `LoginHistoryMigrationBatch` to backfill the last 6 months of LoginHistory data into `Fiscal_Year_Login_History__c`. **Run this FIRST before running LicenseShuffleBatch** - otherwise login counts will be 0.

- **`run_initial_migration_and_sync.apex`**: Runs the initial migration and provides instructions for next steps. Use this to ensure data is populated before license shuffling.

## Viewing Login Counts

The primary way to view per-user fiscal-year login counts is the native
**Reports → License Management → "Community User Login Counts FY"** report. It
lists active Community users (including those with zero logins) ranked by their
`Fiscal_Year_Login_Count__c`, a field on User stamped during each nightly
`LicenseShuffleBatch` run. The `Fiscal_Year_Login_Count_Updated__c` column shows
when the count was last refreshed — it reflects the last nightly run, not real
time. Viewers need the `Fiscal Year Login Reporting` permission set.

## Utility Scripts

- **`check_user_login_counts.apex`**: Checks a specific user's current state and login count for debugging purposes. Edit the `userId` variable at the top to check different users.

- **`user_login_count_fiscal_year.apex`**: Manual/debug fallback that prints the same login counts to the debug log. Prefer the native report above for day-to-day use; use this script only for ad-hoc checks. Note its fiscal-year window uses a strict Feb 1 start, whereas `LicenseShuffleBatch` (and therefore the report and license decisions) uses a rolling 365-day window during Feb-Apr.

- **`license_count_by_type.apex`**: Lists all active Community users and their license types (Premium vs Login). Helps verify current license distribution.

- **`check_license_change_logs.apex`**: Queries and displays `License_Change_Log__c` records to verify logging functionality. Shows all custom field values.

- **`verify_login_history.apex`**: Verifies LoginHistory records exist for test users. Useful during testing with artificial login data.

## Manual Execution

- **`run_license_monitor_manually.apex`**: Manually triggers `LicenseShuffleBatch` for immediate license optimization. **IMPORTANT**: Ensure `Fiscal_Year_Login_History__c` has data first (run initial migration), otherwise login counts will be 0.

## Scheduling Scripts

- **`schedule_daily_sync.apex`**: Schedules `LoginHistorySyncScheduler` to run daily at 2:00 AM. Run this after deploying to production.

- **`schedule_annual_cleanup.apex`**: Schedules `LoginHistoryCleanupScheduler` to run annually on May 1st at 3:00 AM. Run this after deploying to production.

## Usage

All scripts are designed to be run in Anonymous Apex (Salesforce Developer Console or VS Code with Salesforce CLI).

Example:

```bash
sf apex run --target-org staging --file scripts/apex/license-sorting/grant_fls_fiscal_year_login_history.apex
```
