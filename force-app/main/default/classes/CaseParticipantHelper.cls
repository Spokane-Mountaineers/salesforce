public with sharing class CaseParticipantHelper {
  /**
   * Add a Contact as a participant on a Case.
   * Caller must already be on the case (opener or existing participant).
   * Also inserts a CaseShare record so the new participant can see the Case.
   *
   * @param caseId  The Case to share
   * @param contactId  The Contact to add as a participant
   * @return The new Case_Participant__c record
   */
  @AuraEnabled
  public static Case_Participant__c addParticipant(
    String caseId,
    String contactId
  ) {
    try {
      if (String.isBlank(caseId) || String.isBlank(contactId)) {
        throw new AuraHandledException('Case ID and Contact ID are required.');
      }

      Id callerContactId = TicketSubmissionHelper.getContactForUser();
      if (callerContactId == null) {
        throw new AuraHandledException(
          'Unable to find your Contact record. Please ensure you are logged in with a valid member account.'
        );
      }

      // Verify caller is already on the case
      Case targetCase = [
        SELECT Id, ContactId
        FROM Case
        WHERE Id = :caseId
        LIMIT 1
      ];

      Boolean callerIsOwner = targetCase.ContactId == callerContactId;
      Boolean callerIsParticipant = ![
          SELECT Id
          FROM Case_Participant__c
          WHERE Case__c = :caseId AND Contact__c = :callerContactId
          LIMIT 1
        ]
        .isEmpty();

      if (!callerIsOwner && !callerIsParticipant) {
        throw new AuraHandledException(
          'You do not have permission to add participants to this ticket.'
        );
      }

      // Check for duplicate participant
      List<Case_Participant__c> existing = [
        SELECT Id
        FROM Case_Participant__c
        WHERE Case__c = :caseId AND Contact__c = :contactId
        LIMIT 1
      ];
      if (!existing.isEmpty()) {
        throw new AuraHandledException(
          'This member is already a participant on this ticket.'
        );
      }

      // Create participant record
      Case_Participant__c participant = new Case_Participant__c(
        Case__c = caseId,
        Contact__c = contactId,
        Added_By__c = UserInfo.getUserId(),
        Added_Date__c = DateTime.now(),
        Role__c = 'Participant'
      );
      insert participant;

      // Find the User associated with this Contact and share the Case
      List<User> participantUsers = [
        SELECT Id
        FROM User
        WHERE ContactId = :contactId AND IsActive = TRUE
        LIMIT 1
      ];

      if (!participantUsers.isEmpty()) {
        CaseShare share = new CaseShare(
          CaseId = caseId,
          UserOrGroupId = participantUsers[0].Id,
          CaseAccessLevel = 'Read',
          RowCause = 'Manual'
        );
        insert share;
      }

      return [
        SELECT
          Id,
          Case__c,
          Contact__c,
          Contact__r.Name,
          Contact__r.Email,
          Added_By__c,
          Added_By__r.Name,
          Added_Date__c,
          Role__c
        FROM Case_Participant__c
        WHERE Id = :participant.Id
        LIMIT 1
      ];
    } catch (AuraHandledException e) {
      throw e;
    } catch (DmlException e) {
      throw new AuraHandledException(
        'Error adding participant: ' + e.getDmlMessage(0)
      );
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error adding participant: ' + e.getMessage()
      );
    }
  }

  /**
   * Remove a participant from a case.
   * Also deletes the corresponding CaseShare record.
   * Caller must be on the case to remove a participant.
   *
   * @param participantId  The Case_Participant__c record ID to remove
   */
  @AuraEnabled
  public static void removeParticipant(String participantId) {
    try {
      if (String.isBlank(participantId)) {
        throw new AuraHandledException('Participant ID is required.');
      }

      Id callerContactId = TicketSubmissionHelper.getContactForUser();
      if (callerContactId == null) {
        throw new AuraHandledException(
          'Unable to find your Contact record. Please ensure you are logged in with a valid member account.'
        );
      }

      Case_Participant__c participant = [
        SELECT Id, Case__c, Contact__c
        FROM Case_Participant__c
        WHERE Id = :participantId
        LIMIT 1
      ];

      // Verify caller is on the case
      Case targetCase = [
        SELECT Id, ContactId
        FROM Case
        WHERE Id = :participant.Case__c
        LIMIT 1
      ];

      Boolean callerIsOwner = targetCase.ContactId == callerContactId;
      Boolean callerIsParticipant = ![
          SELECT Id
          FROM Case_Participant__c
          WHERE Case__c = :participant.Case__c AND Contact__c = :callerContactId
          LIMIT 1
        ]
        .isEmpty();

      if (!callerIsOwner && !callerIsParticipant) {
        throw new AuraHandledException(
          'You do not have permission to remove participants from this ticket.'
        );
      }

      // Find and delete associated CaseShare record
      List<User> participantUsers = [
        SELECT Id
        FROM User
        WHERE ContactId = :participant.Contact__c AND IsActive = TRUE
        LIMIT 1
      ];

      if (!participantUsers.isEmpty()) {
        List<CaseShare> shares = [
          SELECT Id
          FROM CaseShare
          WHERE
            CaseId = :participant.Case__c
            AND UserOrGroupId = :participantUsers[0].Id
            AND RowCause = 'Manual'
          LIMIT 1
        ];
        if (!shares.isEmpty()) {
          delete shares;
        }
      }

      delete participant;
    } catch (AuraHandledException e) {
      throw e;
    } catch (DmlException e) {
      throw new AuraHandledException(
        'Error removing participant: ' + e.getDmlMessage(0)
      );
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error removing participant: ' + e.getMessage()
      );
    }
  }

  /**
   * Get all participants for a case.
   * Caller must be on the case to view participants.
   *
   * @param caseId  The Case ID
   * @return List of Case_Participant__c records with Contact and User info
   */
  @AuraEnabled(cacheable=true)
  public static List<Case_Participant__c> getParticipants(String caseId) {
    try {
      if (String.isBlank(caseId)) {
        throw new AuraHandledException('Case ID is required.');
      }

      Id callerContactId = TicketSubmissionHelper.getContactForUser();
      if (callerContactId == null) {
        return new List<Case_Participant__c>();
      }

      // Verify access to this case
      Set<Id> participantCaseIds = new Set<Id>();
      for (Case_Participant__c cp : [
        SELECT Case__c
        FROM Case_Participant__c
        WHERE Contact__c = :callerContactId
      ]) {
        participantCaseIds.add(cp.Case__c);
      }

      List<Case> cases = [
        SELECT Id, ContactId
        FROM Case
        WHERE
          Id = :caseId
          AND (ContactId = :callerContactId
          OR Id IN :participantCaseIds)
        LIMIT 1
      ];

      if (cases.isEmpty()) {
        throw new AuraHandledException(
          'Ticket not found or you do not have permission to view it.'
        );
      }

      return [
        SELECT
          Id,
          Case__c,
          Contact__c,
          Contact__r.Name,
          Contact__r.Email,
          Added_By__c,
          Added_By__r.Name,
          Added_Date__c,
          Role__c
        FROM Case_Participant__c
        WHERE Case__c = :caseId
        ORDER BY Added_Date__c ASC
      ];
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error retrieving participants: ' + e.getMessage()
      );
    }
  }

  /**
   * Search for Contacts by name or email to add as participants.
   * Returns up to 10 matches, excluding the case opener and existing participants.
   *
   * @param searchTerm  Partial name or email to search
   * @param caseId  The Case ID (to exclude existing participants)
   * @return List of matching Contact records
   */
  @AuraEnabled(cacheable=true)
  public static List<Contact> searchContacts(String searchTerm, String caseId) {
    try {
      if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
        return new List<Contact>();
      }

      // Get existing participants to exclude
      Set<Id> existingParticipantContactIds = new Set<Id>();
      if (String.isNotBlank(caseId)) {
        List<Case> cases = [
          SELECT ContactId
          FROM Case
          WHERE Id = :caseId
          LIMIT 1
        ];
        if (!cases.isEmpty() && cases[0].ContactId != null) {
          existingParticipantContactIds.add(cases[0].ContactId);
        }
        for (Case_Participant__c p : [
          SELECT Contact__c
          FROM Case_Participant__c
          WHERE Case__c = :caseId
        ]) {
          existingParticipantContactIds.add(p.Contact__c);
        }
      }

      String likePattern = '%' + searchTerm + '%';
      List<Contact> results = [
        SELECT Id, Name, Email, Account.Name
        FROM Contact
        WHERE
          (Name LIKE :likePattern
          OR Email LIKE :likePattern)
          AND Id NOT IN :existingParticipantContactIds
          AND Id IN (SELECT ContactId FROM User WHERE IsActive = TRUE)
        ORDER BY Name
        LIMIT 10
      ];

      return results;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error searching contacts: ' + e.getMessage()
      );
    }
  }
}
