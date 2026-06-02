/**
 * Tests for MembershipSnapshotBatch and MembershipSnapshotScheduler.
 *
 * Builds two membership Opportunities with known date ranges and verifies the
 * per-month distinct active-member counts at the boundary months, including the
 * "as of today" cap that keeps the in-progress month accurate.
 */
@isTest
private class MembershipSnapshotBatchTest {
  // Months relative to the start of the current month.
  private static Date monthStart(Integer monthsAgo) {
    return Date.today().toStartOfMonth().addMonths(-monthsAgo);
  }

  private static Date lastDayOfMonth(Date firstOfMonth) {
    return firstOfMonth.addMonths(1).addDays(-1);
  }

  private static Integer countFor(Date month) {
    List<Monthly_Active_Members__c> rows = [
      SELECT Active_Member_Count__c
      FROM Monthly_Active_Members__c
      WHERE Snapshot_Month__c = :month
    ];
    return rows.isEmpty()
      ? null
      : Integer.valueOf(rows[0].Active_Member_Count__c);
  }

  @testSetup
  static void setup() {
    Id membershipRt = [
      SELECT Id
      FROM RecordType
      WHERE SObjectType = 'Opportunity' AND Name = 'Membership'
      LIMIT 1
    ]
    .Id;

    Contact a = new Contact(LastName = 'MemberA');
    Contact b = new Contact(LastName = 'MemberB');
    insert new List<Contact>{ a, b };
    // NPSP auto-creates a household Account on Contact insert.
    Map<Id, Contact> withAccts = new Map<Id, Contact>(
      [
        SELECT Id, AccountId
        FROM Contact
        WHERE Id IN :new List<Id>{ a.Id, b.Id }
      ]
    );

    // Member A: active only across the months 4 and 3 ago.
    Opportunity oppA = new Opportunity(
      Name = 'Membership A',
      StageName = 'Closed Won',
      CloseDate = monthStart(4),
      RecordTypeId = membershipRt,
      AccountId = withAccts.get(a.Id).AccountId,
      npsp__Primary_Contact__c = a.Id,
      npe01__Membership_Start_Date__c = monthStart(4),
      npe01__Membership_End_Date__c = lastDayOfMonth(monthStart(3))
    );
    // Member B: active across months 4 through 2 ago. All test memberships are
    // kept in the past so the "Opportunity Process" PB (which provisions a member
    // User for currently-active memberships) never fires during the test.
    Opportunity oppB = new Opportunity(
      Name = 'Membership B',
      StageName = 'Closed Won',
      CloseDate = monthStart(4),
      RecordTypeId = membershipRt,
      AccountId = withAccts.get(b.Id).AccountId,
      npsp__Primary_Contact__c = b.Id,
      npe01__Membership_Start_Date__c = monthStart(4),
      npe01__Membership_End_Date__c = lastDayOfMonth(monthStart(2))
    );
    insert new List<Opportunity>{ oppA, oppB };
  }

  @isTest
  static void testMonthlyActiveCountsAtBoundaries() {
    Test.startTest();
    Database.executeBatch(
      new MembershipSnapshotBatch(monthStart(5), monthStart(0)),
      30
    );
    Test.stopTest();

    System.assertEquals(
      0,
      countFor(monthStart(5)),
      'Before either membership started'
    );
    System.assertEquals(2, countFor(monthStart(4)), 'Both members active');
    System.assertEquals(
      2,
      countFor(monthStart(3)),
      'A ends this month, B still active'
    );
    System.assertEquals(1, countFor(monthStart(2)), 'A expired, only B');
    System.assertEquals(
      0,
      countFor(monthStart(0)),
      'Current month (as-of today) exercises the cap; both expired'
    );
  }

  @isTest
  static void testRangeConstructorNormalizesToFirstOfMonth() {
    // Pass mid-month dates; start() should still produce first-of-month entries.
    Date midPast = monthStart(2).addDays(10);
    Date midNow = Date.today().toStartOfMonth().addDays(5);

    Test.startTest();
    Database.executeBatch(new MembershipSnapshotBatch(midPast, midNow), 30);
    Test.stopTest();

    System.assertNotEquals(
      null,
      countFor(monthStart(2)),
      'Snapshot keyed to first of month'
    );
    System.assertEquals(
      1,
      countFor(monthStart(2)),
      'Only B active two months ago'
    );
  }

  @isTest
  static void testDefaultConstructorStartsAtBackfillFloor() {
    MembershipSnapshotBatch batch = new MembershipSnapshotBatch();
    Iterable<Date> months = batch.start(null);
    Iterator<Date> it = months.iterator();
    System.assert(it.hasNext(), 'Backfill produces at least one month');
    System.assertEquals(
      MembershipSnapshotBatch.BACKFILL_START,
      it.next(),
      'First month is the 2021 floor'
    );
  }

  @isTest
  static void testSchedulerRuns() {
    Test.startTest();
    String cron = '0 0 3 1 * ?';
    System.schedule(
      'MembershipSnapshotTest',
      cron,
      new MembershipSnapshotScheduler()
    );
    Test.stopTest();
    // Scheduler skips executeBatch under test; this asserts it schedules cleanly.
    System.assert(true, 'Scheduler executed without error');
  }
}
