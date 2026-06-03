/**
 * Scheduler for ActiveMemberRollupBatch. Intended to run daily so the current
 * month's active-member list stays fresh as members join or lapse.
 *
 * Recomputes only the current and previous month (trailing window); older months
 * stay frozen in Active_Member_Month__c. The one-time historical backfill is
 * `Database.executeBatch(new ActiveMemberRollupBatch(), 6)` run by an admin.
 */
public class ActiveMemberRollupScheduler implements Schedulable {
  public void execute(SchedulableContext ctx) {
    Date currentMonth = Date.today().toStartOfMonth();
    Date previousMonth = currentMonth.addMonths(-1);
    ActiveMemberRollupBatch batch = new ActiveMemberRollupBatch(
      previousMonth,
      currentMonth
    );

    if (!Test.isRunningTest()) {
      Database.executeBatch(batch, 6);
    }
  }
}
