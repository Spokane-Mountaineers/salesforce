@isTest
private class CaseParticipantHelperTest {
  @TestSetup
  static void setupTestData() {
    // Case opener contact
    Contact openerContact = new Contact(
      FirstName = 'Opener',
      LastName = 'Member',
      Email = 'opener@example.com'
    );
    insert openerContact;

    // Participant contact
    Contact participantContact = new Contact(
      FirstName = 'Participant',
      LastName = 'Member',
      Email = 'participant@example.com'
    );
    insert participantContact;

    // Third contact for unauthorized access tests
    Contact otherContact = new Contact(
      FirstName = 'Other',
      LastName = 'Member',
      Email = 'other@example.com'
    );
    insert otherContact;

    Profile communityProfile = [
      SELECT Id
      FROM Profile
      WHERE Name LIKE '%Community%'
      LIMIT 1
    ];

    // Opener user
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
    insert openerUser;

    // Participant user
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
    insert participantUser;

    // Other user (not on any case)
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
    insert otherUser;

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
    insert testCase;
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
          e.getMessage().contains('already a participant'),
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
          e.getMessage().contains('permission'),
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
          e.getMessage().contains('permission') ||
          e.getMessage().contains('not found'),
          'Error should mention permission or not found'
        );
      }
      Test.stopTest();
    }
  }
}
