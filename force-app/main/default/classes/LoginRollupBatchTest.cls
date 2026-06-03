/**
 * Tests for LoginRollupBatch and LoginRollupScheduler.
 *
 * Reuses an existing member (with a Contact, non-excluded) and an @smi.org staff
 * user (excluded). Seeds Active_Member_Month__c so the member is active in some
 * months but not others, then asserts logins are counted only for active months,
 * staff is excluded, and a non-active month is gated out.
 */
@isTest
private class LoginRollupBatchTest {
  private static Date monthStart(Integer monthsAgo) {
    return Date.today().toStartOfMonth().addMonths(-monthsAgo);
  }

  private static String monthKey(Date m) {
    return m.year() + '-' + String.valueOf(m.month()).leftPad(2, '0');
  }

  private static Fiscal_Year_Login_History__c makeLogin(Id userId, Date d) {
    return new Fiscal_Year_Login_History__c(
      User__c = userId,
      Login_Time__c = DateTime.newInstance(d, Time.newInstance(12, 0, 0, 0))
    );
  }

  private static Active_Member_Month__c activeRow(Id contactId, Date m) {
    return new Active_Member_Month__c(
      Key__c = contactId + '-' + monthKey(m),
      Contact__c = contactId,
      Member_Name__c = 'Test Member',
      Month__c = m
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
  static void testRollupGatesOnActiveMembership() {
    // A member with a Contact whose username can't trip the exclusion formula,
    // and a staff @smi.org user that the formula excludes.
    List<User> members = [
      SELECT Id, ContactId
      FROM User
      WHERE
        IsActive = TRUE
        AND ContactId != NULL
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
    Id memberContact = members[0].ContactId;
    Id staff = staffs[0].Id;

    // The member is active months 4 and 3 ago, but NOT month 2.
    insert new List<Active_Member_Month__c>{
      activeRow(memberContact, monthStart(4)),
      activeRow(memberContact, monthStart(3))
    };

    List<Fiscal_Year_Login_History__c> logins = new List<Fiscal_Year_Login_History__c>();
    for (Integer i = 0; i < 3; i++) {
      logins.add(makeLogin(member, monthStart(4).addDays(i + 1)));
    }
    for (Integer i = 0; i < 2; i++) {
      logins.add(makeLogin(member, monthStart(3).addDays(i + 1)));
    }
    // Logins in a month the member was NOT active -> should be gated out.
    for (Integer i = 0; i < 4; i++) {
      logins.add(makeLogin(member, monthStart(2).addDays(i + 1)));
    }
    for (Integer i = 0; i < 5; i++) {
      logins.add(makeLogin(staff, monthStart(4).addDays(i + 1)));
    }
    insert logins;

    Test.startTest();
    Database.executeBatch(
      new LoginRollupBatch(monthStart(4), monthStart(2)),
      12
    );
    Test.stopTest();

    System.assertEquals(
      3,
      countFor(member, monthStart(4)),
      'Active member month: 3 logins counted'
    );
    System.assertEquals(
      2,
      countFor(member, monthStart(3)),
      'Active member month: 2 logins counted'
    );
    System.assertEquals(
      null,
      countFor(member, monthStart(2)),
      'Not an active member that month: logins gated out'
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Member_Login_Month__c WHERE User__c = :staff],
      'Staff @smi.org logins are excluded'
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
