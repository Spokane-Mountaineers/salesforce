public with sharing class TicketQueryHelper {
  /**
   * Get all Cases for the current Experience Cloud user's Contact.
   * Includes cases where the user is the opener (ContactId) or a participant.
   * @return List of Case records with related data
   */
  @AuraEnabled(cacheable=true)
  public static List<Case> getMyTickets() {
    try {
      Id contactId = TicketSubmissionHelper.getContactForUser();

      if (contactId == null) {
        return new List<Case>();
      }

      Set<Id> participantCaseIds = new Set<Id>();
      for (Case_Participant__c cp : [
        SELECT Case__c
        FROM Case_Participant__c
        WHERE Contact__c = :contactId
      ]) {
        participantCaseIds.add(cp.Case__c);
      }

      return [
        SELECT
          Id,
          CaseNumber,
          Subject,
          Description,
          Status,
          Priority,
          RecordType.Name,
          RecordType.DeveloperName,
          CreatedDate,
          LastModifiedDate,
          ClosedDate,
          Owner.Name,
          Owner.Type
        FROM Case
        WHERE ContactId = :contactId OR Id IN :participantCaseIds
        ORDER BY CreatedDate DESC
        LIMIT 100
      ];
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error retrieving tickets: ' + e.getMessage()
      );
    }
  }

  /**
   * Get a single Case with full details.
   * Accessible to the case opener or any participant.
   * @param caseId Case ID
   * @return Case record
   */
  @AuraEnabled(cacheable=true)
  public static Case getTicketDetails(String caseId) {
    try {
      Id contactId = TicketSubmissionHelper.getContactForUser();

      Set<Id> participantCaseIds = new Set<Id>();
      for (Case_Participant__c cp : [
        SELECT Case__c
        FROM Case_Participant__c
        WHERE Contact__c = :contactId
      ]) {
        participantCaseIds.add(cp.Case__c);
      }

      Case targetCase = [
        SELECT
          Id,
          CaseNumber,
          Subject,
          Description,
          Status,
          Priority,
          RecordType.Name,
          RecordType.DeveloperName,
          CreatedDate,
          LastModifiedDate,
          ClosedDate,
          Owner.Name,
          Owner.Type,
          Contact.Name,
          Contact.Email,
          Contact.User_Lookup__c,
          Contact.User_Lookup__r.Name,
          Related_User__c
        FROM Case
        WHERE
          Id = :caseId
          AND (ContactId = :contactId
          OR Id IN :participantCaseIds)
        LIMIT 1
      ];

      return targetCase;
    } catch (QueryException e) {
      throw new AuraHandledException(
        'Ticket not found or you do not have permission to view it.'
      );
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error retrieving ticket details: ' + e.getMessage()
      );
    }
  }

  /**
   * Get all public comments for a Case.
   * Accessible to the case opener or any participant.
   * @param caseId Case ID
   * @return List of CaseComment records
   */
  @AuraEnabled(cacheable=true)
  public static List<CaseComment> getTicketComments(String caseId) {
    try {
      Id contactId = TicketSubmissionHelper.getContactForUser();

      // Verify access
      Set<Id> participantCaseIds = new Set<Id>();
      for (Case_Participant__c cp : [
        SELECT Case__c
        FROM Case_Participant__c
        WHERE Contact__c = :contactId
      ]) {
        participantCaseIds.add(cp.Case__c);
      }

      List<Case> cases = [
        SELECT Id
        FROM Case
        WHERE
          Id = :caseId
          AND (ContactId = :contactId
          OR Id IN :participantCaseIds)
        LIMIT 1
      ];

      if (cases.isEmpty()) {
        throw new QueryException('Not found');
      }

      return [
        SELECT Id, CommentBody, CreatedDate, CreatedBy.Name, IsPublished
        FROM CaseComment
        WHERE ParentId = :caseId AND IsPublished = TRUE
        ORDER BY CreatedDate ASC
      ];
    } catch (QueryException e) {
      throw new AuraHandledException(
        'Ticket not found or you do not have permission to view it.'
      );
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error retrieving comments: ' + e.getMessage()
      );
    }
  }

  /**
   * Get filtered tickets by status.
   * Includes cases where the user is opener or participant.
   * @param statusFilter Status filter (All, Open, Closed)
   * @return List of Case records
   */
  @AuraEnabled(cacheable=true)
  public static List<Case> getMyTicketsByStatus(String statusFilter) {
    try {
      Id contactId = TicketSubmissionHelper.getContactForUser();

      if (contactId == null) {
        return new List<Case>();
      }

      Set<Id> participantCaseIds = new Set<Id>();
      for (Case_Participant__c cp : [
        SELECT Case__c
        FROM Case_Participant__c
        WHERE Contact__c = :contactId
      ]) {
        participantCaseIds.add(cp.Case__c);
      }

      String baseWhere = 'WHERE (ContactId = :contactId OR Id IN :participantCaseIds) ';

      String query =
        'SELECT Id, CaseNumber, Subject, Description, Status, Priority, ' +
        'RecordType.Name, RecordType.DeveloperName, ' +
        'CreatedDate, LastModifiedDate, ClosedDate, ' +
        'Owner.Name, Owner.Type ' +
        'FROM Case ' +
        baseWhere;

      if (statusFilter == 'Open') {
        query += 'AND Status NOT IN (\'Closed\', \'Resolved\') ';
      } else if (statusFilter == 'Closed') {
        query += 'AND Status IN (\'Closed\', \'Resolved\') ';
      }

      query += 'ORDER BY CreatedDate DESC LIMIT 100';

      return Database.query(query);
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error retrieving tickets: ' + e.getMessage()
      );
    }
  }
}
