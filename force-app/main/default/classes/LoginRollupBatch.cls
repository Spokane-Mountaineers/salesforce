/**
 * Sums member logins from Fiscal_Year_Login_History__c into the durable
 * Member_Login_Month__c rollup — one row per member per month.
 *
 * The login mirror is purged yearly (LoginHistoryCleanupBatch), so this freezes
 * each month's per-member login counts before they age out. The batch writes only
 * the months in its range: the one-time backfill writes every available month;
 * the scheduler passes just the trailing two months, so closed months are written
 * once and then left untouched (they survive the purge). The current month is
 * recomputed each run so it stays live.
 *
 * Excludes staff/integration/test logins via Exclude_From_Member_Login_Stats__c,
 * matching the Member Logins Per Month report. Months are bucketed by the running
 * user's time zone (Date-range binds), matching the report's month grouping.
 */
public class LoginRollupBatch implements Database.Batchable<Date>, Database.Stateful {
  private final Date startMonth;
  private final Date endMonth;
  private Integer rowsUpserted = 0;

  /** Full range: earliest month in the mirror through the current month (backfill). */
  public LoginRollupBatch() {
    Date currentMonth = firstOfMonth(Date.today());
    AggregateResult ar = [
      SELECT MIN(Login_Time__c) earliest
      FROM Fiscal_Year_Login_History__c
      WHERE Exclude_From_Member_Login_Stats__c = FALSE
    ];
    DateTime earliest = (DateTime) ar.get('earliest');
    this.startMonth = earliest == null
      ? currentMonth
      : firstOfMonth(earliest.date());
    this.endMonth = currentMonth;
  }

  /** Explicit inclusive month range; both args normalized to the first of their month. */
  public LoginRollupBatch(Date startMonthArg, Date endMonthArg) {
    this.startMonth = firstOfMonth(startMonthArg);
    this.endMonth = firstOfMonth(endMonthArg);
  }

  public Iterable<Date> start(Database.BatchableContext bc) {
    List<Date> months = new List<Date>();
    Date m = startMonth;
    while (m <= endMonth) {
      months.add(m);
      m = m.addMonths(1);
    }
    System.debug(
      'LoginRollupBatch: ' +
        months.size() +
        ' months (' +
        startMonth +
        ' .. ' +
        endMonth +
        ')'
    );
    return months;
  }

  public void execute(Database.BatchableContext bc, List<Date> scope) {
    DateTime calculatedOn = DateTime.now();
    List<Member_Login_Month__c> rows = new List<Member_Login_Month__c>();

    for (Date monthStart : scope) {
      Date nextMonth = monthStart.addMonths(1);
      for (AggregateResult ar : [
        SELECT User__c uid, User__r.Name nm, COUNT(Id) cnt
        FROM Fiscal_Year_Login_History__c
        WHERE
          Exclude_From_Member_Login_Stats__c = FALSE
          AND User__c != NULL
          AND Login_Time__c >= :monthStart
          AND Login_Time__c < :nextMonth
        GROUP BY User__c, User__r.Name
      ]) {
        Id uid = (Id) ar.get('uid');
        rows.add(
          new Member_Login_Month__c(
            Key__c = uid + '-' + monthKey(monthStart),
            User__c = uid,
            Member_Name__c = (String) ar.get('nm'),
            Month__c = monthStart,
            Login_Count__c = (Integer) ar.get('cnt'),
            Calculated_On__c = calculatedOn
          )
        );
      }
    }

    if (!rows.isEmpty()) {
      // Partial success so one bad row can't roll back the rest.
      Database.UpsertResult[] results = Database.upsert(
        rows,
        Member_Login_Month__c.Key__c,
        false
      );
      for (Database.UpsertResult r : results) {
        if (r.isSuccess()) {
          rowsUpserted++;
        } else {
          System.debug('LoginRollupBatch: upsert error: ' + r.getErrors());
        }
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
    System.debug(
      'LoginRollupBatch: finished, ' +
        rowsUpserted +
        ' member-month rows upserted'
    );
  }

  private static Date firstOfMonth(Date d) {
    return Date.newInstance(d.year(), d.month(), 1);
  }

  /** YYYY-MM key fragment, e.g. 2026-04. */
  private static String monthKey(Date monthStart) {
    return monthStart.year() +
      '-' +
      String.valueOf(monthStart.month()).leftPad(2, '0');
  }
}
