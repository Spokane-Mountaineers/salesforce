/**
 * Tests for FederationIdBackfillBatch.
 *
 * The derivation/skip contract is covered exhaustively against the pure static
 * deriveFederationId (no DML, both prod and sandbox suffixes). The batch plumbing
 * (start/execute/finish) is covered against existing org users so the test never
 * creates a User — this org manages its license seats tightly.
 */
@isTest
private class FederationIdBackfillBatchTest {
  // ---------------------------------------------------------------------------
  // deriveFederationId — the contract
  // ---------------------------------------------------------------------------

  @isTest
  static void deriveProductionUsernames() {
    System.assertEquals(
      'jane.doe@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        'jane.doe@gmail.com.smi',
        'jane.doe@gmail.com',
        '',
        true
      ),
      'trailing .smi is stripped'
    );
    System.assertEquals(
      'francis.scarlet@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        'francis.scarlet@gmail.com',
        'francis.scarlet@gmail.com',
        '',
        true
      ),
      'plain-email member (no .smi) passes through unchanged'
    );
    System.assertEquals(
      'john.smiley@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        'john.smiley@gmail.com.smi',
        'john.smiley@gmail.com',
        '',
        true
      ),
      'only the trailing .smi is removed; an internal "smi" is preserved'
    );
    System.assertEquals(
      'a_b.c@hotmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        'a_b.c@hotmail.com.smi',
        'a_b.c@hotmail.com',
        '',
        true
      ),
      'a non-leading underscore is a valid email character'
    );
    System.assertEquals(
      'jane.doe@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        'jane.doe@gmail.com.smi.smi',
        'jane.doe@gmail.com',
        '',
        true
      ),
      'double .smi suffix is recursively stripped'
    );
  }

  @isTest
  static void deriveSandboxUsernames() {
    System.assertEquals(
      'jane.doe@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        'jane.doe@gmail.com.smi.staging',
        'jane.doe@gmail.com.invalid',
        '.staging',
        true
      ),
      'sandbox suffix then .smi are both stripped'
    );
    System.assertEquals(
      'francis.scarlet@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        'francis.scarlet@gmail.com.staging',
        'francis.scarlet@gmail.com.invalid',
        '.staging',
        true
      ),
      'plain-email member with only the sandbox suffix'
    );
    System.assertEquals(
      'x@y.com',
      FederationIdBackfillBatch.deriveFederationId(
        'x@y.com.smi.STAGING',
        'x@y.com.invalid',
        '.staging',
        true
      ),
      'sandbox suffix match is case-insensitive'
    );
  }

  @isTest
  static void deriveSkipsNonMembers() {
    // Status-independent skips (asserted with isActive = true to prove they hold
    // even for active accounts).
    Map<String, String> skip = new Map<String, String>{
      '_delete_lifelong@hotmail.com.smi' => 'lifelong@hotmail.com',
      'foo@gmail.com.smi1' => 'foo@gmail.com',
      'del_pintermr@msn.com' => 'pintermr@msn.com',
      'delete_mravi7@gmail.com.smi' => 'mravi7@gmail.com',
      'webdev5@smi.org' => 'webdev5@smi.org',
      'sm-client@prolocity.com' => 'sm-client@prolocity.com',
      'checkout@spokanemountaineers-pub.force.com' => 'checkout@spokanemountaineers-pub.force.com',
      'chatty.x@chatter.salesforce.com' => 'chatty.x@chatter.salesforce.com',
      'autoproc@00dcw000004ihinuae' => 'autoproc@00dcw000004ihinuae'
    };
    for (String uname : skip.keySet()) {
      System.assertEquals(
        null,
        FederationIdBackfillBatch.deriveFederationId(
          uname,
          skip.get(uname),
          '',
          true
        ),
        'should skip: ' + uname
      );
    }
    // Orphan / staff skips also hold once the sandbox suffix is present.
    System.assertEquals(
      null,
      FederationIdBackfillBatch.deriveFederationId(
        '_orphan@x.com.smi.staging',
        'orphan@x.com.invalid',
        '.staging',
        true
      ),
      'leading underscore orphan in sandbox'
    );
    System.assertEquals(
      null,
      FederationIdBackfillBatch.deriveFederationId(
        'webdev5@spokanemountaineers.org.staging',
        'webdev5@spokanemountaineers.org.invalid',
        '.staging',
        true
      ),
      'staff domain in sandbox'
    );
  }

  @isTest
  static void deriveBareDelSkippedOnlyWhenInactive() {
    // Bare "del…" (no underscore) deletion markers — skipped only when inactive.
    System.assertEquals(
      null,
      FederationIdBackfillBatch.deriveFederationId(
        'deljeffreymergler@gmail.com',
        'jeffreymergler@gmail.com',
        '',
        false
      ),
      'inactive bare del* is a deletion marker'
    );
    System.assertEquals(
      null,
      FederationIdBackfillBatch.deriveFederationId(
        'delwfs@hotmail.com.smi',
        'delwfs@hotmail.com',
        '',
        false
      ),
      'inactive bare del* is a deletion marker'
    );
    // A real, active member whose name starts with "Del" keeps a real id.
    System.assertEquals(
      'delgado.maria@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        'delgado.maria@gmail.com.smi',
        'delgado.maria@gmail.com',
        '',
        true
      ),
      'active Del-named member is NOT a deletion marker'
    );
    System.assertEquals(
      'deljeffreymergler@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        'deljeffreymergler@gmail.com',
        'jeffreymergler@gmail.com',
        '',
        true
      ),
      'bare del* is not skipped while the account is active'
    );
    // The underscore form is a marker regardless of status.
    System.assertEquals(
      null,
      FederationIdBackfillBatch.deriveFederationId(
        'del_pintermr@msn.com',
        'pintermr@msn.com',
        '',
        true
      ),
      'del_ marker skips even when active'
    );
  }

  @isTest
  static void deriveNumberedPrefixSkippedOnlyWhenInactive() {
    System.assertEquals(
      null,
      FederationIdBackfillBatch.deriveFederationId(
        '1jwalters09@gmail.com.smi',
        'jwalters09@gmail.com',
        '',
        false
      ),
      'inactive numbered prefix duplicate user is skipped when email mismatches'
    );
    System.assertEquals(
      '1jwalters09@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        '1jwalters09@gmail.com.smi',
        '1jwalters09@gmail.com',
        '',
        false
      ),
      'inactive numbered prefix user is not skipped when email matches'
    );
    System.assertEquals(
      '2for1.sheehan@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        '2for1.sheehan@gmail.com.smi',
        '2for1.sheehan@gmail.com',
        '',
        false
      ),
      'inactive user with legitimate numeric prefix email is not skipped'
    );
    System.assertEquals(
      '2for1.sheehan@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        '2for1.sheehan@gmail.com.smi.staging',
        '2for1.sheehan@gmail.com.invalid',
        '.staging',
        false
      ),
      'inactive user with legitimate numeric prefix email is not skipped in sandbox'
    );
    System.assertEquals(
      '1jwalters09@gmail.com',
      FederationIdBackfillBatch.deriveFederationId(
        '1jwalters09@gmail.com.smi',
        'jwalters09@gmail.com',
        '',
        true
      ),
      'active numbered prefix user is not skipped regardless of email mismatch'
    );
  }

  @isTest
  static void deriveHandlesBlankInput() {
    System.assertEquals(
      null,
      FederationIdBackfillBatch.deriveFederationId(null, null, '', true)
    );
    System.assertEquals(
      null,
      FederationIdBackfillBatch.deriveFederationId('', '', '', true)
    );
    System.assertEquals(
      null,
      FederationIdBackfillBatch.deriveFederationId('   ', '   ', '', true)
    );
  }

  @isTest
  static void sandboxSuffixIsWellFormed() {
    String s = FederationIdBackfillBatch.sandboxSuffix();
    System.assert(
      s == '' || s.startsWith('.'),
      'suffix is empty (prod) or a dotted segment (sandbox), got: ' + s
    );
  }

  // ---------------------------------------------------------------------------
  // Batch plumbing
  // ---------------------------------------------------------------------------

  @isTest
  static void startQuerySelectsFederationId() {
    FederationIdBackfillBatch batch = new FederationIdBackfillBatch();
    Database.QueryLocator ql = batch.start(new TestBatchableContext());
    String q = ql.getQuery().toLowerCase();
    System.assert(
      q.contains('federationidentifier'),
      'selects FederationIdentifier'
    );
    System.assert(q.contains('email'), 'selects Email');
    System.assert(q.contains('from user'), 'queries User');
  }

  @isTest
  static void executeHandlesEmptyAndNullScope() {
    FederationIdBackfillBatch batch = new FederationIdBackfillBatch();
    Database.BatchableContext bc = new TestBatchableContext();
    batch.execute(bc, new List<sObject>());
    batch.execute(bc, null);
    batch.finish(bc);
    System.assertEquals(0, batch.updated, 'no updates on empty/null scope');
    System.assertEquals(0, batch.skipped, 'no skips on empty/null scope');
  }

  @isTest
  static void executeSkipsIneligibleRows() {
    // In-memory rows (no Id): skipped before any DML, so no persistence and no
    // license cost. Covers orphan, underscore-marker, and inactive bare-del paths.
    FederationIdBackfillBatch batch = new FederationIdBackfillBatch();
    batch.execute(
      new TestBatchableContext(),
      new List<sObject>{
        new User(Username = '_orphan@x.com.smi', Email = 'orphan@x.com'),
        new User(Username = 'del_x@y.com.smi', Email = 'x@y.com'),
        new User(
          Username = 'delwfs@hotmail.com.smi',
          Email = 'delwfs@hotmail.com',
          IsActive = false
        )
      }
    );
    System.assertEquals(3, batch.skipped, 'all three ineligible rows skipped');
    System.assertEquals(0, batch.updated, 'nothing stamped');
  }

  @isTest
  static void executeStampsExistingEligibleUser() {
    // Use a real user the batch would stamp, so the update path runs without
    // creating a User. All changes roll back at end of test.
    String env = FederationIdBackfillBatch.sandboxSuffix();
    String usernameFilter = '%.smi' + env;
    User target;
    for (User u : [
      SELECT Id, Username, Email, FederationIdentifier, IsActive
      FROM User
      WHERE IsActive = TRUE AND Username LIKE :usernameFilter
      ORDER BY CreatedDate DESC
      LIMIT 50
    ]) {
      if (
        FederationIdBackfillBatch.deriveFederationId(
          u.Username,
          u.Email,
          env,
          u.IsActive
        ) != null
      ) {
        target = u;
        break;
      }
    }
    if (target == null) {
      return; // org has no eligible member user to exercise the update path
    }
    String expected = FederationIdBackfillBatch.deriveFederationId(
      target.Username,
      target.Email,
      env,
      target.IsActive
    );

    Test.startTest();
    FederationIdBackfillBatch batch = new FederationIdBackfillBatch();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      batch.execute(new TestBatchableContext(), new List<sObject>{ target });
    }
    Test.stopTest();

    User after = [
      SELECT FederationIdentifier
      FROM User
      WHERE Id = :target.Id
    ];
    System.assertEquals(
      expected,
      after.FederationIdentifier,
      'FederationIdentifier should be the username-derived value'
    );
  }

  /** Minimal BatchableContext for driving execute/start/finish directly. */
  private class TestBatchableContext implements Database.BatchableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }
    public Id getChildJobId() {
      return null;
    }
  }
}
