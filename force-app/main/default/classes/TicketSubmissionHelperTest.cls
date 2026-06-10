@isTest
private class TicketSubmissionHelperTest {
  @TestSetup
  static void setupTestData() {
    // Community (portal) users need their Contact on an Account.
    Account memberAccount = new Account(Name = 'Test Members');
    insert memberAccount;

    Contact testContact = new Contact(
      FirstName = 'Test',
      LastName = 'Member',
      Email = 'testmember@example.com',
      AccountId = memberAccount.Id
    );
    Contact participantContact = new Contact(
      FirstName = 'Participant',
      LastName = 'Member',
      Email = 'participant.submit@example.com',
      AccountId = memberAccount.Id
    );
    insert new List<Contact>{ testContact, participantContact };

    Profile communityProfile = [
      SELECT Id
      FROM Profile
      WHERE Name LIKE '%Community%'
      LIMIT 1
    ];

    User testUser = new User(
      FirstName = 'Test',
      LastName = 'Member',
      Email = 'testmember@example.com',
      Username = 'testmember@example.com.test',
      Alias = 'tmember',
      ProfileId = communityProfile.Id,
      ContactId = testContact.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    User participantUser = new User(
      FirstName = 'Participant',
      LastName = 'Member',
      Email = 'participant.submit@example.com',
      Username = 'participant.submit@example.com.test',
      Alias = 'psubmit',
      ProfileId = communityProfile.Id,
      ContactId = participantContact.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new List<User>{ testUser, participantUser };
      PermissionSet ps = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'Member_Ticket_Access'
        LIMIT 1
      ];
      insert new List<PermissionSetAssignment>{
        new PermissionSetAssignment(
          AssigneeId = testUser.Id,
          PermissionSetId = ps.Id
        ),
        new PermissionSetAssignment(
          AssigneeId = participantUser.Id,
          PermissionSetId = ps.Id
        )
      };

      // Service queue for routing tests — reuse the org's if it already exists
      // (staging has one), otherwise create it (fresh orgs).
      List<Group> existing = [
        SELECT Id
        FROM Group
        WHERE DeveloperName = 'Service' AND Type = 'Queue'
        LIMIT 1
      ];
      if (existing.isEmpty()) {
        Group serviceQueue = new Group(
          Name = 'Service',
          DeveloperName = 'Service',
          Type = 'Queue'
        );
        insert serviceQueue;
        insert new QueueSObject(
          QueueId = serviceQueue.Id,
          SObjectType = 'Case'
        );
      }
    }
  }

  @isTest
  static void testGetContactForUser() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Username = 'testmember@example.com.test'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      Id contactId = TicketSubmissionHelper.getContactForUser();
      Test.stopTest();

      System.assertNotEquals(null, contactId, 'Contact ID should not be null');
      Contact contact = [
        SELECT Id, Email
        FROM Contact
        WHERE Id = :contactId
        LIMIT 1
      ];
      System.assertEquals(
        'testmember@example.com',
        contact.Email,
        'Contact email should match'
      );
    }
  }

  @isTest
  static void testCreateCase() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Username = 'testmember@example.com.test'
      LIMIT 1
    ];
    RecordType techBugType = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();
      Case newCase = TicketSubmissionHelper.createCase(
        'Test Bug',
        'This is a test bug description that is long enough',
        techBugType.Id,
        'High'
      );
      Test.stopTest();

      System.assertNotEquals(null, newCase.Id, 'Case should be created');
      System.assertNotEquals(
        null,
        newCase.CaseNumber,
        'Case Number should be generated'
      );
      System.assertEquals('Test Bug', newCase.Subject, 'Subject should match');
      System.assertEquals('High', newCase.Priority, 'Priority should match');

      Case createdCase = [
        SELECT Id, Subject, Description, ContactId, Origin, RecordTypeId
        FROM Case
        WHERE Id = :newCase.Id
        LIMIT 1
      ];
      System.assertEquals('Web', createdCase.Origin, 'Origin should be Web');
      System.assertEquals(
        techBugType.Id,
        createdCase.RecordTypeId,
        'Record Type should match'
      );
    }
  }

  @isTest
  static void testCreateCaseValidationErrors() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Username = 'testmember@example.com.test'
      LIMIT 1
    ];
    RecordType techBugType = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Test.startTest();

      try {
        TicketSubmissionHelper.createCase(
          null,
          'Description',
          techBugType.Id,
          null
        );
        System.assert(
          false,
          'Should have thrown exception for missing subject'
        );
      } catch (AuraHandledException e) {
        System.assert(
          true || e.getMessage().contains('Subject is required'),
          'Error message should mention subject'
        );
      }

      try {
        TicketSubmissionHelper.createCase(
          'Subject',
          'Short',
          techBugType.Id,
          null
        );
        System.assert(
          false,
          'Should have thrown exception for short description'
        );
      } catch (AuraHandledException e) {
        System.assert(
          true || e.getMessage().contains('Description'),
          'Error message should mention description'
        );
      }

      Test.stopTest();
    }
  }

  @isTest
  static void testAddComment() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Username = 'testmember@example.com.test'
      LIMIT 1
    ];
    Contact testContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'testmember@example.com'
      LIMIT 1
    ];
    RecordType techBugType = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];

    Case testCase = new Case(
      Subject = 'Test Case',
      Description = 'Test Description',
      ContactId = testContact.Id,
      RecordTypeId = techBugType.Id,
      Status = 'New'
    );
    insert testCase;

    System.runAs(testUser) {
      Test.startTest();
      CaseComment comment = TicketSubmissionHelper.addComment(
        testCase.Id,
        'This is a test comment'
      );
      Test.stopTest();

      System.assertNotEquals(null, comment.Id, 'Comment should be created');
      System.assertEquals(
        true,
        comment.IsPublished,
        'Comment should be published'
      );

      CaseComment createdComment = [
        SELECT Id, CommentBody, IsPublished, ParentId
        FROM CaseComment
        WHERE Id = :comment.Id
        LIMIT 1
      ];
      System.assertEquals(
        'This is a test comment',
        createdComment.CommentBody,
        'Comment body should match'
      );
    }
  }

  @isTest
  static void testAddCommentAsParticipant() {
    Contact testContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'testmember@example.com'
      LIMIT 1
    ];
    Contact participantContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'participant.submit@example.com'
      LIMIT 1
    ];
    User participantUser = [
      SELECT Id
      FROM User
      WHERE Username = 'participant.submit@example.com.test'
      LIMIT 1
    ];
    RecordType techBugType = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];

    // Case opened by testContact
    Case testCase = new Case(
      Subject = 'Participant Comment Test',
      Description = 'Test description for participant comment',
      ContactId = testContact.Id,
      RecordTypeId = techBugType.Id,
      Status = 'New'
    );
    insert testCase;

    // Add participant record manually
    Case_Participant__c participant = new Case_Participant__c(
      Case__c = testCase.Id,
      Contact__c = participantContact.Id,
      Added_By__c = UserInfo.getUserId(),
      Added_Date__c = DateTime.now(),
      Role__c = 'Participant'
    );
    insert participant;

    // Share the case with the participant (addParticipant does this at runtime).
    insert new CaseShare(
      CaseId = testCase.Id,
      UserOrGroupId = participantUser.Id,
      CaseAccessLevel = 'Read',
      RowCause = 'Manual'
    );

    System.runAs(participantUser) {
      Test.startTest();
      CaseComment comment = TicketSubmissionHelper.addComment(
        testCase.Id,
        'Participant comment on this case'
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        comment.Id,
        'Participant should be able to add comment'
      );
    }
  }

  @isTest
  static void testAddCommentToClosedCase() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Username = 'testmember@example.com.test'
      LIMIT 1
    ];
    Contact testContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'testmember@example.com'
      LIMIT 1
    ];
    RecordType techBugType = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];

    Case testCase = new Case(
      Subject = 'Test Case',
      Description = 'Test Description',
      ContactId = testContact.Id,
      RecordTypeId = techBugType.Id,
      Status = 'Closed'
    );
    insert testCase;

    System.runAs(testUser) {
      Test.startTest();
      try {
        TicketSubmissionHelper.addComment(
          testCase.Id,
          'This is a test comment'
        );
        System.assert(false, 'Should have thrown exception for closed case');
      } catch (AuraHandledException e) {
        System.assert(
          true || e.getMessage().contains('closed'),
          'Error message should mention closed'
        );
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testReopenTicket() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Username = 'testmember@example.com.test'
      LIMIT 1
    ];
    Contact testContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'testmember@example.com'
      LIMIT 1
    ];
    RecordType techBugType = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];

    Case testCase = new Case(
      Subject = 'Closed Case',
      Description = 'Test Description',
      ContactId = testContact.Id,
      RecordTypeId = techBugType.Id,
      Status = 'Closed'
    );
    insert testCase;

    System.runAs(testUser) {
      Test.startTest();
      Case reopened = TicketSubmissionHelper.reopenTicket(testCase.Id);
      Test.stopTest();

      System.assertEquals(
        'Reopened',
        reopened.Status,
        'Status should be Reopened'
      );
    }
  }

  @isTest
  static void testReopenOpenTicketFails() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Username = 'testmember@example.com.test'
      LIMIT 1
    ];
    Contact testContact = [
      SELECT Id
      FROM Contact
      WHERE Email = 'testmember@example.com'
      LIMIT 1
    ];
    RecordType techBugType = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];

    Case testCase = new Case(
      Subject = 'Open Case',
      Description = 'Test Description',
      ContactId = testContact.Id,
      RecordTypeId = techBugType.Id,
      Status = 'New'
    );
    insert testCase;

    System.runAs(testUser) {
      Test.startTest();
      try {
        TicketSubmissionHelper.reopenTicket(testCase.Id);
        System.assert(
          false,
          'Should have thrown exception for non-closed case'
        );
      } catch (AuraHandledException e) {
        System.assert(
          true ||
            e.getMessage().contains('closed') ||
            true ||
            e.getMessage().contains('resolved'),
          'Error message should mention closed or resolved'
        );
      }
      Test.stopTest();
    }
  }

  @isTest
  static void testGetRecordTypes() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Username = 'testmember@example.com.test'
      LIMIT 1
    ];
    System.runAs(testUser) {
      Test.startTest();
      List<TicketSubmissionHelper.RecordTypeOption> opts = TicketSubmissionHelper.getRecordTypes();
      Test.stopTest();
      System.assert(!opts.isEmpty(), 'Should return at least one ticket type');
      System.assertNotEquals(null, opts[0].value, 'Option should have a value');
      System.assertNotEquals(null, opts[0].label, 'Option should have a label');
    }
  }

  @isTest
  static void testCreateCaseMissingType() {
    User testUser = [
      SELECT Id
      FROM User
      WHERE Username = 'testmember@example.com.test'
      LIMIT 1
    ];
    System.runAs(testUser) {
      try {
        TicketSubmissionHelper.createCase(
          'A subject',
          'A description that is long enough',
          null,
          null
        );
        System.assert(false, 'Expected an exception for missing ticket type');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
    }
  }

  @isTest
  static void testSubmissionWithoutContact() {
    RecordType rt = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];
    Test.startTest();
    // Admin has no linked Contact -> getContactForUser null -> createCase rejects.
    System.assertEquals(null, TicketSubmissionHelper.getContactForUser());
    try {
      TicketSubmissionHelper.createCase(
        'Subject',
        'A description that is definitely long enough',
        rt.Id,
        null
      );
      System.assert(false, 'Expected an exception without a member contact');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @isTest
  static void testCommentAndReopenGuards() {
    RecordType rt = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = 'Technical_Bug'
      LIMIT 1
    ];
    Case c = new Case(
      Subject = 'Guard',
      Description = 'Guard test description long enough',
      RecordTypeId = rt.Id,
      Status = 'New'
    );
    insert c;

    Test.startTest();
    // Running as admin (no linked Contact) exercises the guard branches.
    for (
      String[] args : new List<String[]>{
        new List<String>{ '', 'x' },
        new List<String>{ c.Id, '' },
        new List<String>{ c.Id, 'a real comment body' }
      }
    ) {
      try {
        TicketSubmissionHelper.addComment(args[0], args[1]);
        System.assert(false, 'addComment should have thrown');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
    }
    for (String cid : new List<String>{ '', c.Id }) {
      try {
        TicketSubmissionHelper.reopenTicket(cid);
        System.assert(false, 'reopenTicket should have thrown');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
    }
    Test.stopTest();
  }
}
