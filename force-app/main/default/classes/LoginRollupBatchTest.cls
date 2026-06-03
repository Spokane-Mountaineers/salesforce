/**
 * Tests for LoginRollupBatch and LoginRollupScheduler.
 *
 * Uses an existing member (non-excluded) and an @smi.org staff user (excluded) —
 * mirroring how LoginHistorySyncBatchTest reuses org users — and inserts
 * Fiscal_Year_Login_History__c rows for known months, then asserts the rollup
 * counts per member-month and that excluded accounts produce no rows.
 */
@isTest
private class LoginRollupBatchTest {
  private static Date monthStart(Integer monthsAgo) {
    return Date.today().toStartOfMonth().addMonths(-monthsAgo);
  }

  private static Fiscal_Year_Login_History__c makeLogin(Id userId, Date d) {
    return new Fiscal_Year_Login_History__c(
      User__c = userId,
      Login_Time__c = DateTime.newInstance(d, Time.newInstance(12, 0, 0, 0))
    );
  }

  private static Integer countFor(Id userId, Date m) {
    List<Member_Login_Month__c> rows = [
      SELECT Login_Count__c
      FROM Member_Login_Month__c
      WHERE User__c = :userId AND Month__c = :m
    ];
    return rows.isEmpty() ? null : Integer.valueOf(rows[0].Login_Count__c);
  }

  @isTest
  static void testRollupCountsAndExclusion() {
    // A member whose username can't trip the exclusion formula, and a staff
    // @smi.org user that the formula excludes.
    List<User> members = [
      SELECT Id
      FROM User
      WHERE
        IsActive = TRUE
        AND (NOT Username LIKE '%@smi.org%')
        AND (NOT Username LIKE '%@spokanemountaineers.org%')
        AND (NOT Username LIKE '%@prolocity.com%')
        AND (NOT FirstName LIKE 'test%')
        AND (NOT LastName LIKE 'test%')
      LIMIT 1
    ];
    List<User> staffs = [
      SELECT Id
      FROM User
      WHERE IsActive = TRUE AND Username LIKE '%@smi.org%'
      LIMIT 1
    ];
    if (members.isEmpty() || staffs.isEmpty()) {
      return; // org without the expected user shapes; nothing to assert
    }
    Id member = members[0].Id;
    Id staff = staffs[0].Id;

    List<Fiscal_Year_Login_History__c> logins = new List<Fiscal_Year_Login_History__c>();
    for (Integer i = 0; i < 3; i++) {
      logins.add(makeLogin(member, monthStart(4).addDays(i + 1)));
    }
    for (Integer i = 0; i < 2; i++) {
      logins.add(makeLogin(member, monthStart(3).addDays(i + 1)));
    }
    for (Integer i = 0; i < 5; i++) {
      logins.add(makeLogin(staff, monthStart(4).addDays(i + 1)));
    }
    insert logins;

    Test.startTest();
    Database.executeBatch(
      new LoginRollupBatch(monthStart(4), monthStart(3)),
      12
    );
    Test.stopTest();

    System.assertEquals(
      3,
      countFor(member, monthStart(4)),
      'Member: 3 logins, month A'
    );
    System.assertEquals(
      2,
      countFor(member, monthStart(3)),
      'Member: 2 logins, month B'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Member_Login_Month__c WHERE User__c = :staff],
      'Staff @smi.org logins are excluded from the rollup'
    );
  }

  @isTest
  static void testDefaultConstructorAndScheduler() {
    Test.startTest();
    System.schedule(
      'LoginRollupTest',
      '0 0 3 * * ?',
      new LoginRollupScheduler()
    );
    LoginRollupBatch b = new LoginRollupBatch();
    Iterator<Date> it = b.start(null).iterator();
    System.assert(it.hasNext(), 'Backfill yields at least one month');
    Test.stopTest();
  }
}
