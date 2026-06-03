/**
 * Lists the distinct active member Contacts for each month into the durable
 * Active_Member_Month__c rollup — one row per active member per month — so the
 * Active Members Per Month chart can drill into a month and show WHO was active.
 *
 * A member counts for a month if a Membership Opportunity covers that month's
 * "as of" date (last day of the month, capped at today for the in-progress
 * month) — the same definition MembershipSnapshotBatch uses for the count, so
 * the per-month record count here equals that snapshot count. Test accounts
 * (primary contact name containing "test") are excluded.
 *
 * The batch writes only the months in its range: the backfill writes every month
 * from 2021; the scheduler passes the trailing two months, so closed months are
 * written once and the current month stays live.
 */
public class ActiveMemberRollupBatch implements Database.Batchable<Date>, Database.Stateful {
  // Continuous membership tracking in this org begins in 2021 (matches MembershipSnapshotBatch).
  public static final Date BACKFILL_START = Date.newInstance(2021, 1, 1);
  private static final String MEMBERSHIP_RECORD_TYPE = 'Membership';

  private final Date startMonth;
  private final Date endMonth;
  private Integer rowsUpserted = 0;

  /** Full range: 2021 through the current month (backfill). */
  public ActiveMemberRollupBatch() {
    this(BACKFILL_START, firstOfMonth(Date.today()));
  }

  /** Explicit inclusive month range; both args normalized to the first of their month. */
  public ActiveMemberRollupBatch(Date startMonthArg, Date endMonthArg) {
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
      'ActiveMemberRollupBatch: ' +
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
    List<Active_Member_Month__c> rows = new List<Active_Member_Month__c>();

    for (Date monthStart : scope) {
      Date monthEnd = monthStart.addMonths(1).addDays(-1);
      // In-progress month: count as of today (don't drop memberships expiring later this month).
      Date asOf = monthEnd > today ? today : monthEnd;

      Set<Id> seen = new Set<Id>();
      for (Opportunity o : [
        SELECT npsp__Primary_Contact__c, npsp__Primary_Contact__r.Name
        FROM Opportunity
        WHERE
          RecordType.Name = :MEMBERSHIP_RECORD_TYPE
          AND npe01__Membership_Start_Date__c <= :asOf
          AND npe01__Membership_End_Date__c >= :asOf
          AND npsp__Primary_Contact__c != NULL
          AND (NOT npsp__Primary_Contact__r.Name LIKE '%test%')
      ]) {
        Id cid = o.npsp__Primary_Contact__c;
        if (seen.add(cid)) {
          rows.add(
            new Active_Member_Month__c(
              Key__c = cid + '-' + monthKey(monthStart),
              Contact__c = cid,
              Member_Name__c = o.npsp__Primary_Contact__r.Name,
              Month__c = monthStart,
              Calculated_On__c = calculatedOn
            )
          );
        }
      }
    }

    if (!rows.isEmpty()) {
      // Partial success so one bad row can't roll back the rest.
      Database.UpsertResult[] results = Database.upsert(
        rows,
        Active_Member_Month__c.Key__c,
        false
      );
      for (Database.UpsertResult r : results) {
        if (r.isSuccess()) {
          rowsUpserted++;
        } else {
          System.debug(
            'ActiveMemberRollupBatch: upsert error: ' + r.getErrors()
          );
        }
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
    System.debug(
      'ActiveMemberRollupBatch: finished, ' +
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
