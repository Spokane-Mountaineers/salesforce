trigger ContentPostTrigger on Content_Post__c(
  before insert,
  before update,
  after update
) {
  if (Trigger.isBefore && Trigger.isInsert) {
    ContentPostService.handleBeforeInsert(Trigger.new);
  } else if (Trigger.isBefore && Trigger.isUpdate) {
    ContentPostService.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
  } else if (Trigger.isAfter && Trigger.isUpdate) {
    ContentPostService.handleAfterUpdate(Trigger.new, Trigger.oldMap);
  }
}
