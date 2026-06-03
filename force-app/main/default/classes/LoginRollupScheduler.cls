/**
 * Scheduler for LoginRollupBatch. Intended to run daily (after the 2 AM login sync)
 * so the current month's per-member login counts stay fresh.
 *
 * Recomputes only the current and previous month: the current month stays live and
 * the just-closed month gets a final value after late syncs, while older months
 * remain frozen in Member_Login_Month__c. The one-time historical backfill is
 * `Database.executeBatch(new LoginRollupBatch(), 12)` run by an admin.
 */
public class LoginRollupScheduler implements Schedulable {
  public void execute(SchedulableContext ctx) {
    Date currentMonth = Date.today().toStartOfMonth();
    Date previousMonth = currentMonth.addMonths(-1);
    LoginRollupBatch batch = new LoginRollupBatch(previousMonth, currentMonth);

    if (!Test.isRunningTest()) {
      Database.executeBatch(batch, 12);
    }
  }
}
