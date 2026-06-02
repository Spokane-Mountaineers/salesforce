/**
 * Computes the number of distinct active member Contacts for each calendar month
 * and stores one row per month on Monthly_Active_Members__c.
 *
 * A member counts toward a month if a Membership Opportunity covers that month's
 * "as of" date: Membership Start <= asOf AND Membership End >= asOf, where asOf is
 * the last day of the month, capped at today for the in-progress month (so the
 * current month matches the live active-member count instead of under-counting
 * memberships that expire later this month).
 *
 * Standard Salesforce reports cannot count span-memberships per period, so this
 * pre-aggregates into Monthly_Active_Members__c which a simple summary report and
 * the Membership dashboard line graph read from.
 *
 * Scope is a list of month-start Dates; each execute() runs one COUNT_DISTINCT
 * query per month and upserts the snapshot by the Snapshot_Month__c external id.
 */
public class MembershipSnapshotBatch implements Database.Batchable<Date>, Database.Stateful {
  // Continuous membership tracking in this org begins in 2021; earlier records are
  // a handful of lifetime members and are not meaningful as a monthly trend.
  public static final Date BACKFILL_START = Date.newInstance(2021, 1, 1);

  // Membership Opportunity record type (label confirmed in prod/staging).
  private static final String MEMBERSHIP_RECORD_TYPE = 'Membership';

  private final Date startMonth;
  private final Date endMonth;
  private Integer monthsProcessed = 0;

  /** Full range: 2021 through the current month. Used for the one-time backfill. */
  public MembershipSnapshotBatch() {
    this(BACKFILL_START, firstOfMonth(Date.today()));
  }

  /** Explicit inclusive range; both args are normalized to the first of their month. */
  public MembershipSnapshotBatch(Date startMonthArg, Date endMonthArg) {
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
      'MembershipSnapshotBatch: computing ' +
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
    Date today = Date.today();
    List<Monthly_Active_Members__c> snapshots = new List<Monthly_Active_Members__c>();

    for (Date monthStart : scope) {
      Date monthEnd = monthStart.addMonths(1).addDays(-1);
      // In-progress month: count as of today so we don't drop memberships that
      // are active now but expire later this month.
      Date asOf = monthEnd > today ? today : monthEnd;

      AggregateResult ar = [
        SELECT COUNT_DISTINCT(npsp__Primary_Contact__c) cnt
        FROM Opportunity
        WHERE
          RecordType.Name = :MEMBERSHIP_RECORD_TYPE
          AND npe01__Membership_Start_Date__c <= :asOf
          AND npe01__Membership_End_Date__c >= :asOf
      ];
      Integer activeCount = (Integer) ar.get('cnt');

      snapshots.add(
        new Monthly_Active_Members__c(
          Snapshot_Key__c = monthKey(monthStart),
          Snapshot_Month__c = monthStart,
          Active_Member_Count__c = activeCount,
          Calculated_On__c = calculatedOn
        )
      );
      monthsProcessed++;
    }

    if (!snapshots.isEmpty()) {
      // Partial success so one bad row can't roll back every month's snapshot.
      Database.UpsertResult[] results = Database.upsert(
        snapshots,
        Monthly_Active_Members__c.Snapshot_Key__c,
        false
      );
      for (Database.UpsertResult r : results) {
        if (!r.isSuccess()) {
          System.debug(
            'MembershipSnapshotBatch: upsert error: ' + r.getErrors()
          );
        }
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
    System.debug(
      'MembershipSnapshotBatch: finished, ' +
        monthsProcessed +
        ' months upserted'
    );
  }

  /** First day of the month containing d. */
  private static Date firstOfMonth(Date d) {
    return Date.newInstance(d.year(), d.month(), 1);
  }

  /** YYYY-MM key for a month-start date, e.g. 2021-04. */
  private static String monthKey(Date monthStart) {
    return monthStart.year() +
      '-' +
      String.valueOf(monthStart.month()).leftPad(2, '0');
  }
}
