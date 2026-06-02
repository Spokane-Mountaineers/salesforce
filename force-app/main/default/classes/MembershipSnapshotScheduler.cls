/**
 * Scheduler for MembershipSnapshotBatch. Intended to run monthly (shortly after a
 * month closes).
 *
 * Recomputes the current and previous month only: the current month keeps the
 * in-progress count fresh, and the just-closed month is re-frozen once more so any
 * backdated memberships entered late are reflected. The full historical backfill is
 * a one-time `Database.executeBatch(new MembershipSnapshotBatch(), 30)` run by an admin.
 */
public class MembershipSnapshotScheduler implements Schedulable {
  public void execute(SchedulableContext ctx) {
    Date currentMonth = Date.today().toStartOfMonth();
    Date previousMonth = currentMonth.addMonths(-1);
    MembershipSnapshotBatch batch = new MembershipSnapshotBatch(
      previousMonth,
      currentMonth
    );

    // Test.isRunningTest guard mirrors LoginHistorySyncScheduler: avoid a second
    // executeBatch inside a test's start/stop window.
    if (!Test.isRunningTest()) {
      Database.executeBatch(batch, 12);
    }
  }
}
