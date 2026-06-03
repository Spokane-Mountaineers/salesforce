/**
 * Tests for ActiveMemberRollupBatch and ActiveMemberRollupScheduler.
 *
 * Builds past-dated Membership Opportunities (so the "Opportunity Process" PB that
 * provisions a member User for currently-active memberships never fires) for a
 * real member and a "test"-named contact, then asserts one rollup row per active
 * member per month and that the test account is excluded.
 */
@isTest
private class ActiveMemberRollupBatchTest {
  private static Date monthStart(Integer monthsAgo) {
    return Date.today().toStartOfMonth().addMonths(-monthsAgo);
  }

  private static Date lastDayOfMonth(Date firstOfMonth) {
    return firstOfMonth.addMonths(1).addDays(-1);
  }

  private static Integer activeCount(Date m) {
    return [SELECT COUNT() FROM Active_Member_Month__c WHERE Month__c = :m];
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

    Contact hiker = new Contact(LastName = 'Hiker');
    Contact tester = new Contact(LastName = 'Testerson'); // name contains "test" -> excluded
    Contact lost = new Contact(LastName = 'Lapsed'); // membership Closed Lost -> excluded
    insert new List<Contact>{ hiker, tester, lost };
    Map<Id, Contact> withAccts = new Map<Id, Contact>(
      [
        SELECT Id, AccountId
        FROM Contact
        WHERE Id IN :new List<Id>{ hiker.Id, tester.Id, lost.Id }
      ]
    );

    // Real member: active across months 4 and 3 ago (past, so not currently active).
    Opportunity oppHiker = new Opportunity(
      Name = 'Membership Hiker',
      StageName = 'Closed Won',
      CloseDate = monthStart(4),
      RecordTypeId = membershipRt,
      AccountId = withAccts.get(hiker.Id).AccountId,
      npsp__Primary_Contact__c = hiker.Id,
      npe01__Membership_Start_Date__c = monthStart(4),
      npe01__Membership_End_Date__c = lastDayOfMonth(monthStart(3))
    );
    // Test account: active month 4 ago, but excluded by name.
    Opportunity oppTester = new Opportunity(
      Name = 'Membership Tester',
      StageName = 'Closed Won',
      CloseDate = monthStart(4),
      RecordTypeId = membershipRt,
      AccountId = withAccts.get(tester.Id).AccountId,
      npsp__Primary_Contact__c = tester.Id,
      npe01__Membership_Start_Date__c = monthStart(4),
      npe01__Membership_End_Date__c = lastDayOfMonth(monthStart(4))
    );
    // Closed Lost (failed/abandoned) renewal covering month 4 -> must NOT count.
    Opportunity oppLost = new Opportunity(
      Name = 'Membership Lapsed',
      StageName = 'Closed Lost',
      CloseDate = monthStart(4),
      RecordTypeId = membershipRt,
      AccountId = withAccts.get(lost.Id).AccountId,
      npsp__Primary_Contact__c = lost.Id,
      npe01__Membership_Start_Date__c = monthStart(4),
      npe01__Membership_End_Date__c = lastDayOfMonth(monthStart(3))
    );
    insert new List<Opportunity>{ oppHiker, oppTester, oppLost };
  }

  @isTest
  static void testActiveMembersPerMonthAndExclusion() {
    Contact hiker = [SELECT Id FROM Contact WHERE LastName = 'Hiker' LIMIT 1];
    Contact tester = [
      SELECT Id
      FROM Contact
      WHERE LastName = 'Testerson'
      LIMIT 1
    ];
    Contact lost = [SELECT Id FROM Contact WHERE LastName = 'Lapsed' LIMIT 1];

    Test.startTest();
    Database.executeBatch(
      new ActiveMemberRollupBatch(monthStart(5), monthStart(0)),
      6
    );
    Test.stopTest();

    System.assertEquals(
      0,
      activeCount(monthStart(5)),
      'No memberships 5 months ago'
    );
    System.assertEquals(
      1,
      activeCount(monthStart(4)),
      'Only the real member (tester excluded by name, lapsed excluded by stage)'
    );
    System.assertEquals(
      1,
      activeCount(monthStart(3)),
      'Real member still active'
    );
    System.assertEquals(0, activeCount(monthStart(2)), 'Membership expired');
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Active_Member_Month__c
        WHERE Contact__c = :hiker.Id AND Month__c = :monthStart(4)
      ],
      'Member row exists for month 4'
    );
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Active_Member_Month__c
        WHERE Contact__c = :tester.Id
      ],
      'Test account produces no rollup rows'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Active_Member_Month__c WHERE Contact__c = :lost.Id],
      'Closed Lost (failed renewal) produces no rollup rows'
    );
  }

  @isTest
  static void testDefaultConstructorAndScheduler() {
    Test.startTest();
    System.schedule(
      'ActiveMemberRollupTest',
      '0 0 3 * * ?',
      new ActiveMemberRollupScheduler()
    );
    ActiveMemberRollupBatch b = new ActiveMemberRollupBatch();
    Iterator<Date> it = b.start(null).iterator();
    System.assert(it.hasNext(), 'Backfill yields at least one month');
    System.assertEquals(
      ActiveMemberRollupBatch.BACKFILL_START,
      it.next(),
      'Starts at the 2021 floor'
    );
    Test.stopTest();
  }
}
