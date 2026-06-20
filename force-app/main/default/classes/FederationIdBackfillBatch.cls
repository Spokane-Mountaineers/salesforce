/**
 * Backfills User.FederationIdentifier from the login username so members have a
 * stable federated identity for SSO.
 *
 * SMI usernames are "<email>.smi" (e.g. jane@gmail.com.smi). A sandbox refresh
 * appends ".<sandboxName>" to every username, so in staging the same user reads
 * "jane@gmail.com.smi.staging". The username — not the Email field — is how
 * members log in, so it is the source of truth for the federated id; the Email
 * field can drift (provider change, typo) and is masked to ".invalid" in sandboxes.
 *
 * Derivation: strip the sandbox suffix (none in production), then strip a trailing
 * ".smi". The result is the federated id.
 *
 * Skipped (deriveFederationId returns null):
 *   - deactivated/duplicate orphans: leading "_" or a ".smiN" collision suffix
 *   - admin "marked for deletion" accounts: a "del_"/"delete_" local part (any
 *     status), or a bare "del…" local part on an inactive account
 *   - staff / integration / site / system accounts (see INTERNAL_HINTS)
 *   - anything that doesn't resolve to a syntactically valid email
 *
 * Idempotent and re-runnable: a user is updated only when the derived id differs
 * from what's stored, so already-correct rows are no-ops and a second run is cheap.
 * FederationIdentifier is not DB-unique, so updates use partial success — one bad
 * row never rolls back the rest of the chunk.
 *
 * Run once to backfill:
 *   Database.executeBatch(new FederationIdBackfillBatch(), 200);
 */
public class FederationIdBackfillBatch implements Database.Batchable<sObject>, Database.Stateful {
  // Domains that are never a member's real login email.
  private static final List<String> INTERNAL_HINTS = new List<String>{
    '@spokanemountaineers.org',
    '@spokanemountaineers.com',
    '@smi.org',
    '@prolocity.com',
    '@smi.trial',
    '@smi.poc.org',
    '.ext',
    '.force.com',
    '@chatter.salesforce.com',
    '@example.com'
  };

  // ".smiN" collision-renamed orphan (e.g. jane@gmail.com.smi1).
  private static final Pattern SMI_NUMERIC = Pattern.compile(
    '(?i).*\\.smi[0-9]+$'
  );
  // Numeric collision prefix (e.g. 1jwalters09@gmail.com) on inactive users.
  private static final Pattern COLLISION_PREFIX = Pattern.compile(
    '(?i)^[0-9]+[a-zA-Z].*'
  );
  // "del_" / "delete_" local part marks an account an admin queued for deletion.
  private static final Pattern DEL_PREFIX = Pattern.compile(
    '(?i)^(del|delete)_.*'
  );
  // Good-enough email shape: something@something.something, no whitespace.
  private static final Pattern EMAILISH = Pattern.compile(
    '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$'
  );

  // Stateful counters for the finish() summary.
  @TestVisible
  private Integer updated = 0;
  @TestVisible
  private Integer skipped = 0;

  // ".staging" in the staging sandbox, "" in production. Computed once.
  private final String envSuffix;

  public FederationIdBackfillBatch() {
    this.envSuffix = sandboxSuffix();
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    System.debug(
      'FederationIdBackfillBatch: starting (envSuffix="' + envSuffix + '")'
    );
    // Pull everyone; the include/skip decision lives in deriveFederationId so it
    // stays in one testable place rather than being split across a SOQL filter.
    return Database.getQueryLocator(
      [SELECT Id, Username, Email, FederationIdentifier, IsActive FROM User]
    );
  }

  public void execute(Database.BatchableContext bc, List<sObject> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    List<User> toUpdate = new List<User>();
    for (sObject obj : scope) {
      User u = (User) obj;
      String fed = deriveFederationId(
        u.Username,
        u.Email,
        envSuffix,
        u.IsActive
      );
      if (fed == null) {
        skipped++;
        continue;
      }
      if (fed.equals(u.FederationIdentifier)) {
        // Already correct — idempotent no-op.
        continue;
      }
      u.FederationIdentifier = fed;
      toUpdate.add(u);
    }

    if (!toUpdate.isEmpty()) {
      // Partial success: a single bad row (validation, a locked user) must not
      // roll back everyone else's stamp.
      for (Database.SaveResult sr : Database.update(toUpdate, false)) {
        if (sr.isSuccess()) {
          updated++;
        } else {
          skipped++;
          System.debug(
            LoggingLevel.WARN,
            'FederationIdBackfillBatch: update failed — ' + sr.getErrors()
          );
        }
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
    System.debug(
      LoggingLevel.INFO,
      'FederationIdBackfillBatch: done. updated=' +
        updated +
        ' skipped=' +
        skipped
    );
  }

  /**
   * Pure derivation + skip logic. Returns the federation id to stamp, or null to
   * skip the user. Takes the environment suffix explicitly so it is fully testable
   * for both production ("") and sandbox (".staging") without depending on the org
   * the test happens to run in.
   */
  @TestVisible
  private static String deriveFederationId(
    String username,
    String email,
    String envSuffix,
    Boolean isActive
  ) {
    if (String.isBlank(username)) {
      return null;
    }

    String base = username;
    if (String.isNotBlank(envSuffix) && base.endsWithIgnoreCase(envSuffix)) {
      base = base.removeEndIgnoreCase(envSuffix);
    }

    // Deactivated / duplicate orphans are never a real login identity.
    if (base.startsWith('_') || SMI_NUMERIC.matcher(base).matches()) {
      return null;
    }
    if (isActive == false && COLLISION_PREFIX.matcher(base).matches()) {
      // If the derived Federation ID (base without .smi) matches the clean email,
      // it is a legitimate email that happens to start with a number (e.g. 2for1.sheehan).
      // Otherwise, it is an admin-renamed duplicate placeholder (e.g. 1jwalters09).
      String fedId = base;
      while (fedId.endsWithIgnoreCase('.smi')) {
        fedId = fedId.removeEndIgnoreCase('.smi');
      }
      String cleanEmail = String.isBlank(email)
        ? ''
        : email.toLowerCase().trim();
      if (cleanEmail.endsWithIgnoreCase('.invalid')) {
        cleanEmail = cleanEmail.removeEndIgnoreCase('.invalid');
      }
      if (!fedId.equalsIgnoreCase(cleanEmail)) {
        return null;
      }
    }

    String fed = base;
    while (fed.endsWithIgnoreCase('.smi')) {
      fed = fed.removeEndIgnoreCase('.smi');
    }

    // "del_"/"delete_" is an explicit "marked for deletion" tag (skip any status).
    // A bare "del…" local part is ambiguous — a real Delia/Delgado looks the same —
    // so only treat it as a deletion marker when the account is inactive (every
    // such marker in the org is). A future *active* member named Del keeps their id.
    String localPart = fed.contains('@') ? fed.substringBefore('@') : fed;
    if (DEL_PREFIX.matcher(localPart).matches()) {
      return null;
    }
    if (isActive == false && localPart.startsWithIgnoreCase('del')) {
      return null;
    }

    String lower = username.toLowerCase();
    for (String domainHint : INTERNAL_HINTS) {
      if (lower.contains(domainHint)) {
        return null;
      }
    }

    if (!EMAILISH.matcher(fed).matches() || fed.length() > 512) {
      return null;
    }
    return fed;
  }

  /**
   * The username suffix Salesforce appends on sandbox refresh ("" in production).
   * Derived from the My Domain host (foo--staging.sandbox.my.salesforce.com), whose
   * sandbox name matches the username suffix.
   */
  @TestVisible
  private static String sandboxSuffix() {
    if (![SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox) {
      return '';
    }
    String host = URL.getOrgDomainUrl().getHost();
    if (host.contains('--') && host.contains('.sandbox')) {
      return '.' + host.substringAfter('--').substringBefore('.sandbox');
    }
    return '';
  }
}
