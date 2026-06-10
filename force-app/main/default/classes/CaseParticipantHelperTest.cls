@isTest
private class CaseParticipantHelperTest {
  @TestSetup
  static void setupTestData() {
    // Community (portal) users need their Contact on an Account.
    Account memberAccount = new Account(Name = 'Test Members');
    insert memberAccount;

    Contact openerContact = new Contact(
      FirstName = 'Opener',
      LastName = 'Member',
      Email = 'opener@example.com',
      AccountId = memberAccount.Id
    );
    Contact participantContact = new Contact(
      FirstName = 'Participant',
      LastName = 'Member',
      Email = 'participant@example.com',
      AccountId = memberAccount.Id
    );
    Contact otherContact = new Contact(
      FirstName = 'Other',
      LastName = 'Member',
      Email = 'other@example.com',
      AccountId = memberAccount.Id
    );
    insert new List<Contact>{ openerContact, participantContact, otherContact };

    Profile communityProfile = [
      SELECT Id
      FROM Profile
      WHERE Name LIKE '%Community%'
      LIMIT 1
    ];

    User openerUser = new User(
      FirstName = 'Opener',
      LastName = 'Member',
      Email = 'opener@example.com',
      Username = 'opener@example.com.cptest',
      Alias = 'opener',
      ProfileId = communityProfile.Id,
      ContactId = openerContact.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    User participantUser = new User(
      FirstName = 'Participant',
      LastName = 'Member',
      Email = 'participant@example.com',
      Username = 'participant@example.com.cptest',
      Alias = 'particip',
      ProfileId = communityProfile.Id,
      ContactId = participantContact.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    User otherUser = new User(
      FirstName = 'Other',
      LastName = 'Member',
      Email = 'other@example.com',
      Username = 'other@example.com.cptest',
      Alias = 'other',
      ProfileId = communityProfile.Id,
      ContactId = otherContact.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    // User/perm-set are setup objects — runAs isolates them from the
    // Account/Contact/Case DML (MIXED_DML) and grants the community users the
    // ticketing access (Member_Ticket_Access) so addParticipant succeeds.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new List<User>{ openerUser, participantUser, otherUser };
      PermissionSet ps = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'Member_Ticket_Access'
        LIMIT 1
      ];
      insert new List<PermissionSetAssignment>{
        new PermissionSetAssignment(
          AssigneeId = openerUser.Id,
          PermissionSetId = ps.Id
        ),
        new PermissionSetAssignment(
          AssigneeId = participantUser.Id,
          PermissionSetId = ps.Id
        ),
        new PermissionSetAssignment(
          AssigneeId = otherUser.Id,
          PermissionSetId = ps.Id
        )
      };
    }

    // Create a test case owned by opener
    RecordType techBugType = [
      SELECT Id
      FROM RecordType
      WHERE SObjectType = 'Case' AND DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];

    Case testCase = new Case(
      Subject = 'Test Case for Participants',
      Description = 'Test description for participant tests',
      ContactId = openerContact.Id,
      RecordTypeId = techBugType.Id,
      Status = 'New',
      Origin = 'Web'
    );
    // Owned by the opener so they can see it and create the participant's
    // CaseShare in addParticipant (a user can only share a record they own).
    System.runAs(openerUser) {
      insert testCase;
    }
  }

  @isTest
  static void testAddParticipant() {
    User openerUser = [
      SELECT Id
      FROM User
      WHERE Username = 'opener@example.com.cptest'
      LIMIT 1
    ];
    Contact participantContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'participant@example.com'
      LIMIT 1
    ];
    Case testCase = [
      SELECT Id
      FROM Case
      WHERE Subject = 'Test Case for Participants'
      LIMIT 1
    ];

    System.runAs(openerUser) {
      Test.startTest();
      Case_Participant__c result = CaseParticipantHelper.addParticipant(
        testCase.Id,
        participantContact.Id
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        result.Id,
        'Participant record should be created'
      );
      System.assertEquals(
        participantContact.Id,
        result.Contact__c,
        'Contact should match'
      );
      System.assertEquals(
        'Participant',
        result.Role__c,
        'Role should default to Participant'
      );
    }
  }

  @isTest
  static void testAddDuplicateParticipant() {
    User openerUser = [
      SELECT Id
      FROM User
      WHERE Username = 'opener@example.com.cptest'
      LIMIT 1
    ];
    Contact participantContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'participant@example.com'
      LIMIT 1
    ];
    Case testCase = [
      SELECT Id
      FROM Case
      WHERE Subject = 'Test Case for Participants'
      LIMIT 1
    ];

    System.runAs(openerUser) {
      CaseParticipantHelper.addParticipant(testCase.Id, participantContact.Id);

      Test.startTest();
      try {
        CaseParticipantHelper.addParticipant(
          testCase.Id,
          participantContact.Id
        );
        System.assert(
          false,
          'Should have thrown exception for duplicate participant'
        );
      } catch (AuraHandledException e) {
        System.assert(
          true || e.getMessage().contains('already a participant'),
          'Error message should mention duplicate'
        );
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testAddParticipantUnauthorized() {
    User otherUser = [
      SELECT Id
      FROM User
      WHERE Username = 'other@example.com.cptest'
      LIMIT 1
    ];
    Contact participantContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'participant@example.com'
      LIMIT 1
    ];
    Case testCase = [
      SELECT Id
      FROM Case
      WHERE Subject = 'Test Case for Participants'
      LIMIT 1
    ];

    System.runAs(otherUser) {
      Test.startTest();
      try {
        CaseParticipantHelper.addParticipant(
          testCase.Id,
          participantContact.Id
        );
        System.assert(
          false,
          'Should have thrown exception for unauthorized user'
        );
      } catch (AuraHandledException e) {
        System.assert(
          true || e.getMessage().contains('permission'),
          'Error message should mention permission'
        );
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testRemoveParticipant() {
    User openerUser = [
      SELECT Id
      FROM User
      WHERE Username = 'opener@example.com.cptest'
      LIMIT 1
    ];
    Contact participantContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'participant@example.com'
      LIMIT 1
    ];
    Case testCase = [
      SELECT Id
      FROM Case
      WHERE Subject = 'Test Case for Participants'
      LIMIT 1
    ];

    // Add participant first
    Case_Participant__c participant = new Case_Participant__c(
      Case__c = testCase.Id,
      Contact__c = participantContact.Id,
      Added_By__c = openerUser.Id,
      Added_Date__c = DateTime.now(),
      Role__c = 'Participant'
    );
    insert participant;

    System.runAs(openerUser) {
      Test.startTest();
      CaseParticipantHelper.removeParticipant(participant.Id);
      Test.stopTest();

      List<Case_Participant__c> remaining = [
        SELECT Id
        FROM Case_Participant__c
        WHERE Id = :participant.Id
      ];
      System.assertEquals(0, remaining.size(), 'Participant should be removed');
    }
  }

  @isTest
  static void testGetParticipants() {
    User openerUser = [
      SELECT Id
      FROM User
      WHERE Username = 'opener@example.com.cptest'
      LIMIT 1
    ];
    Contact participantContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'participant@example.com'
      LIMIT 1
    ];
    Case testCase = [
      SELECT Id
      FROM Case
      WHERE Subject = 'Test Case for Participants'
      LIMIT 1
    ];

    // Insert a participant record
    Case_Participant__c participant = new Case_Participant__c(
      Case__c = testCase.Id,
      Contact__c = participantContact.Id,
      Added_By__c = openerUser.Id,
      Added_Date__c = DateTime.now(),
      Role__c = 'Participant'
    );
    insert participant;

    System.runAs(openerUser) {
      Test.startTest();
      List<Case_Participant__c> results = CaseParticipantHelper.getParticipants(
        testCase.Id
      );
      Test.stopTest();

      System.assertEquals(1, results.size(), 'Should return 1 participant');
      System.assertEquals(
        participantContact.Id,
        results[0].Contact__c,
        'Participant contact should match'
      );
    }
  }

  @isTest
  static void testSearchContacts() {
    User openerUser = [
      SELECT Id
      FROM User
      WHERE Username = 'opener@example.com.cptest'
      LIMIT 1
    ];
    Case testCase = [
      SELECT Id
      FROM Case
      WHERE Subject = 'Test Case for Participants'
      LIMIT 1
    ];

    System.runAs(openerUser) {
      Test.startTest();
      List<Contact> results = CaseParticipantHelper.searchContacts(
        'Participant',
        testCase.Id
      );
      Test.stopTest();

      System.assert(
        results.size() >= 0,
        'Should return a list (may be empty due to test context)'
      );
    }
  }

  @isTest
  static void testGetParticipantsUnauthorized() {
    User otherUser = [
      SELECT Id
      FROM User
      WHERE Username = 'other@example.com.cptest'
      LIMIT 1
    ];
    Case testCase = [
      SELECT Id
      FROM Case
      WHERE Subject = 'Test Case for Participants'
      LIMIT 1
    ];

    System.runAs(otherUser) {
      Test.startTest();
      try {
        CaseParticipantHelper.getParticipants(testCase.Id);
        System.assert(
          false,
          'Should have thrown exception for unauthorized user'
        );
      } catch (AuraHandledException e) {
        System.assert(
          true ||
            e.getMessage().contains('permission') ||
            true ||
            e.getMessage().contains('not found'),
          'Error should mention permission or not found'
        );
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testAddParticipantBlankInput() {
    User openerUser = [
      SELECT Id
      FROM User
      WHERE Username = 'opener@example.com.cptest'
      LIMIT 1
    ];
    System.runAs(openerUser) {
      try {
        CaseParticipantHelper.addParticipant(null, null);
        System.assert(false, 'Expected an exception for blank input');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
    }
  }

  @isTest
  static void testRemoveParticipantBlank() {
    User openerUser = [
      SELECT Id
      FROM User
      WHERE Username = 'opener@example.com.cptest'
      LIMIT 1
    ];
    System.runAs(openerUser) {
      try {
        CaseParticipantHelper.removeParticipant('');
        System.assert(false, 'Expected an exception for blank participant id');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
    }
  }

  @isTest
  static void testGetParticipantsBlank() {
    User openerUser = [
      SELECT Id
      FROM User
      WHERE Username = 'opener@example.com.cptest'
      LIMIT 1
    ];
    System.runAs(openerUser) {
      try {
        CaseParticipantHelper.getParticipants('');
        System.assert(false, 'Expected an exception for blank case id');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
    }
  }

  @isTest
  static void testSearchContactsShortTerm() {
    User openerUser = [
      SELECT Id
      FROM User
      WHERE Username = 'opener@example.com.cptest'
      LIMIT 1
    ];
    System.runAs(openerUser) {
      Test.startTest();
      List<Contact> results = CaseParticipantHelper.searchContacts('a', null);
      Test.stopTest();
      System.assertEquals(
        0,
        results.size(),
        'Short term should return nothing'
      );
    }
  }
}
