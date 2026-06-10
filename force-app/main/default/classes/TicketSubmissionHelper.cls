public with sharing class TicketSubmissionHelper {
  /**
   * Get the Contact record associated with the current Experience Cloud user
   * @return Contact ID or null if not found
   */
  @AuraEnabled(cacheable=true)
  public static Id getContactForUser() {
    try {
      Id currentUserId = UserInfo.getUserId();

      User currentUser = [
        SELECT Id, ContactId
        FROM User
        WHERE Id = :currentUserId
        LIMIT 1
      ];

      if (currentUser.ContactId != null) {
        return currentUser.ContactId;
      }

      String userEmail = [
        SELECT Email
        FROM User
        WHERE Id = :currentUserId
        LIMIT 1
      ]
      .Email;

      if (String.isNotBlank(userEmail)) {
        List<Contact> contacts = [
          SELECT Id
          FROM Contact
          WHERE Email = :userEmail
          LIMIT 1
        ];
        if (!contacts.isEmpty()) {
          return contacts[0].Id;
        }
      }

      return null;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error retrieving Contact: ' + e.getMessage()
      );
    }
  }

  /**
   * Get available Case Record Types for ticket submission
   * @return List of RecordTypeOption wrappers
   */
  @AuraEnabled(cacheable=true)
  public static List<RecordTypeOption> getRecordTypes() {
    try {
      List<RecordType> recordTypes = [
        SELECT Id, Name, DeveloperName, Description
        FROM RecordType
        WHERE
          SObjectType = 'Case'
          AND IsActive = TRUE
          AND DeveloperName IN (
            'Technical_Bug',
            'Feature_Request',
            'Account_Access',
            'General_Feedback'
          )
        ORDER BY Name
      ];

      List<RecordTypeOption> options = new List<RecordTypeOption>();
      for (RecordType rt : recordTypes) {
        RecordTypeOption option = new RecordTypeOption();
        option.value = rt.Id;
        option.label = rt.Name;
        option.description = rt.Description;
        options.add(option);
      }

      return options;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error retrieving record types: ' + e.getMessage()
      );
    }
  }

  public class RecordTypeOption {
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String description;
  }

  /**
   * Create a new Case record from Experience Cloud
   * @param subject Case subject
   * @param description Case description
   * @param recordTypeId Case record type ID
   * @param priority Case priority (optional)
   * @return Case record with Case Number
   */
  @AuraEnabled
  public static Case createCase(
    String subject,
    String description,
    String recordTypeId,
    String priority
  ) {
    try {
      if (String.isBlank(subject)) {
        throw new AuraHandledException('Subject is required.');
      }
      if (String.isBlank(description) || description.length() < 10) {
        throw new AuraHandledException(
          'Description is required and must be at least 10 characters.'
        );
      }
      if (String.isBlank(recordTypeId)) {
        throw new AuraHandledException('Ticket type is required.');
      }

      Id contactId = getContactForUser();
      if (contactId == null) {
        throw new AuraHandledException(
          'Unable to find Contact record. Please ensure you are logged in with a valid member account.'
        );
      }

      Id ownerId = getDefaultQueueForRecordType(recordTypeId);

      Case newCase = new Case(
        Subject = subject,
        Description = description,
        RecordTypeId = recordTypeId,
        ContactId = contactId,
        Origin = 'Web',
        OwnerId = ownerId != null ? ownerId : UserInfo.getUserId()
      );

      if (String.isNotBlank(priority)) {
        newCase.Priority = priority;
      }

      insert newCase;

      return [
        SELECT
          Id,
          CaseNumber,
          Subject,
          Status,
          Priority,
          RecordType.Name,
          CreatedDate
        FROM Case
        WHERE Id = :newCase.Id
        LIMIT 1
      ];
    } catch (AuraHandledException e) {
      throw e;
    } catch (DmlException e) {
      throw new AuraHandledException(
        'Error creating ticket: ' + e.getDmlMessage(0)
      );
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error creating ticket: ' + e.getMessage()
      );
    }
  }

  /**
   * Add a public comment to an existing Case.
   * Caller must be the case opener or an existing participant.
   * @param caseId Case ID
   * @param commentBody Comment text
   * @return CaseComment record
   */
  @AuraEnabled
  public static CaseComment addComment(String caseId, String commentBody) {
    try {
      if (String.isBlank(caseId)) {
        throw new AuraHandledException('Case ID is required.');
      }
      if (String.isBlank(commentBody)) {
        throw new AuraHandledException('Comment is required.');
      }

      Id contactId = getContactForUser();
      if (contactId == null) {
        throw new AuraHandledException(
          'Unable to find Contact record. Please ensure you are logged in with a valid member account.'
        );
      }

      Case targetCase = [
        SELECT Id, ContactId, Status
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];

      Boolean isOwner = targetCase.ContactId == contactId;
      Boolean isParticipant = ![
          SELECT Id
          FROM Case_Participant__c
          WHERE Case__c = :caseId AND Contact__c = :contactId
          LIMIT 1
        ]
        .isEmpty();

      if (!isOwner && !isParticipant) {
        throw new AuraHandledException(
          'You do not have permission to add comments to this ticket.'
        );
      }

      if (targetCase.Status == 'Closed' || targetCase.Status == 'Resolved') {
        throw new AuraHandledException(
          'Cannot add comments to closed or resolved tickets.'
        );
      }

      CaseComment comment = new CaseComment(
        ParentId = caseId,
        CommentBody = commentBody,
        IsPublished = true
      );
      insert comment;

      return comment;
    } catch (AuraHandledException e) {
      throw e;
    } catch (DmlException e) {
      throw new AuraHandledException(
        'Error adding comment: ' + e.getDmlMessage(0)
      );
    } catch (Exception e) {
      throw new AuraHandledException('Error adding comment: ' + e.getMessage());
    }
  }

  /**
   * Reopen a closed or resolved ticket.
   * Caller must be the case opener or an existing participant.
   * @param caseId Case ID
   * @return Updated Case record
   */
  @AuraEnabled
  public static Case reopenTicket(String caseId) {
    try {
      if (String.isBlank(caseId)) {
        throw new AuraHandledException('Case ID is required.');
      }

      Id contactId = getContactForUser();
      if (contactId == null) {
        throw new AuraHandledException(
          'Unable to find Contact record. Please ensure you are logged in with a valid member account.'
        );
      }

      Case targetCase = [
        SELECT Id, ContactId, Status
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];

      Boolean isOwner = targetCase.ContactId == contactId;
      Boolean isParticipant = ![
          SELECT Id
          FROM Case_Participant__c
          WHERE Case__c = :caseId AND Contact__c = :contactId
          LIMIT 1
        ]
        .isEmpty();

      if (!isOwner && !isParticipant) {
        throw new AuraHandledException(
          'You do not have permission to reopen this ticket.'
        );
      }

      if (targetCase.Status != 'Closed' && targetCase.Status != 'Resolved') {
        throw new AuraHandledException(
          'Only closed or resolved tickets can be reopened.'
        );
      }

      targetCase.Status = 'Reopened';
      update targetCase;

      return [
        SELECT
          Id,
          CaseNumber,
          Subject,
          Status,
          Priority,
          RecordType.Name,
          CreatedDate,
          LastModifiedDate
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];
    } catch (AuraHandledException e) {
      throw e;
    } catch (DmlException e) {
      throw new AuraHandledException(
        'Error reopening ticket: ' + e.getDmlMessage(0)
      );
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error reopening ticket: ' + e.getMessage()
      );
    }
  }

  /**
   * Get the default queue ID for a given record type using Queue_Routing__mdt.
   * Falls back to null (Case falls to current user as owner) if no routing record found.
   * @param recordTypeId Record type ID
   * @return Queue ID or null
   */
  private static Id getDefaultQueueForRecordType(String recordTypeId) {
    try {
      RecordType rt = [
        SELECT Id, DeveloperName
        FROM RecordType
        WHERE Id = :recordTypeId
        LIMIT 1
      ];

      List<Queue_Routing__mdt> routings = [
        SELECT Queue_Developer_Name__c, Queue_Name__c
        FROM Queue_Routing__mdt
        WHERE Record_Type_Developer_Name__c = :rt.DeveloperName
        LIMIT 1
      ];

      if (routings.isEmpty()) {
        return null;
      }

      String queueDevName = routings[0].Queue_Developer_Name__c;
      String queueName = routings[0].Queue_Name__c;

      // Prefer lookup by DeveloperName; fall back to Name
      if (String.isNotBlank(queueDevName)) {
        List<Group> queues = [
          SELECT Id
          FROM Group
          WHERE Type = 'Queue' AND DeveloperName = :queueDevName
          LIMIT 1
        ];
        if (!queues.isEmpty()) {
          return queues[0].Id;
        }
      }

      if (String.isNotBlank(queueName)) {
        List<Group> queues = [
          SELECT Id
          FROM Group
          WHERE Type = 'Queue' AND Name = :queueName
          LIMIT 1
        ];
        if (!queues.isEmpty()) {
          return queues[0].Id;
        }
      }

      return null;
    } catch (Exception e) {
      return null;
    }
  }
}
