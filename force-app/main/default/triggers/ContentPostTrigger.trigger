trigger ContentPostTrigger on Content_Post__c(after update) {
  if (Trigger.isAfter && Trigger.isUpdate) {
    ContentPostService.handleAfterUpdate(Trigger.new, Trigger.oldMap);
  }
}
