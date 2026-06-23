/**
 * Contract tests for ContentPostController (plan §7.4): the @AuraEnabled
 * methods' inputs, returned DTO shape, error behaviour, and the Published gate.
 */
@isTest
private class ContentPostControllerTest {
  private static Content_Post__c makePost(
    String title,
    String status,
    String activity
  ) {
    return new Content_Post__c(
      Title__c = title,
      Status__c = status,
      Visibility__c = 'Internal',
      Activity__c = activity,
      Publish_Date__c = Date.today()
    );
  }

  @testSetup
  static void seed() {
    insert new List<Content_Post__c>{
      makePost('Beacon Rock south face', 'Published', 'Climbing'),
      makePost('Mount Spokane snowshoe', 'Published', 'Hiking'),
      makePost('Draft in progress', 'Draft', 'Climbing')
    };
    Content_Tag__c tag = new Content_Tag__c(
      Name = 'Cascades',
      Category__c = 'Region',
      Active__c = true
    );
    Content_Tag__c inactive = new Content_Tag__c(
      Name = 'Retired',
      Category__c = 'General',
      Active__c = false
    );
    insert new List<Content_Tag__c>{ tag, inactive };

    Content_Post__c climbing = [
      SELECT Id
      FROM Content_Post__c
      WHERE Title__c = 'Beacon Rock south face'
    ];
    insert new Content_Post_Tag__c(
      Content_Post__c = climbing.Id,
      Content_Tag__c = tag.Id
    );
  }

  @isTest
  static void getPublishedPosts_returnsOnlyPublished() {
    Test.startTest();
    List<ContentPostController.PostDTO> posts = ContentPostController.getPublishedPosts(
      null,
      null,
      null
    );
    Test.stopTest();
    System.assertEquals(2, posts.size(), 'Only Published posts should return');
    for (ContentPostController.PostDTO p : posts) {
      System.assertEquals('Published', p.status, 'Draft leaked into index');
    }
  }

  @isTest
  static void getPublishedPosts_filtersByActivity() {
    List<ContentPostController.PostDTO> posts = ContentPostController.getPublishedPosts(
      'Hiking',
      null,
      null
    );
    System.assertEquals(1, posts.size());
    System.assertEquals('Mount Spokane snowshoe', posts[0].title);
  }

  @isTest
  static void getPublishedPosts_filtersByControlledTag() {
    List<ContentPostController.PostDTO> posts = ContentPostController.getPublishedPosts(
      null,
      'Cascades',
      null
    );
    System.assertEquals(1, posts.size(), 'Tag filter should match one post');
    System.assertEquals('Beacon Rock south face', posts[0].title);
  }

  @isTest
  static void getPublishedPosts_searchMatchesTitle() {
    List<ContentPostController.PostDTO> posts = ContentPostController.getPublishedPosts(
      null,
      null,
      'snowshoe'
    );
    System.assertEquals(1, posts.size());
    System.assertEquals('Mount Spokane snowshoe', posts[0].title);
  }

  @isTest
  static void getPost_returnsBodyAndShape() {
    Content_Post__c rec = [
      SELECT Id
      FROM Content_Post__c
      WHERE Title__c = 'Beacon Rock south face'
    ];
    ContentPostController.PostDTO dto = ContentPostController.getPost(rec.Id);
    System.assertEquals('Beacon Rock south face', dto.title);
    System.assertEquals('Climbing', dto.activity);
  }

  @isTest
  static void getPost_nullIdThrows() {
    try {
      ContentPostController.getPost(null);
      System.assert(false, 'Expected an exception for a null id');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @isTest
  static void getActiveTags_excludesInactive() {
    List<ContentPostController.TagDTO> tags = ContentPostController.getActiveTags();
    System.assertEquals(1, tags.size(), 'Inactive tags must be excluded');
    System.assertEquals('Cascades', tags[0].name);
  }

  // Sys-admin profile (so the new record type is accessible) + the perm set
  // (so the new fields are FLS-writeable). Created in the test method, then the
  // non-setup insert runs inside runAs — which both refreshes the permission
  // context and isolates it from the setup-object DML (no MIXED_DML).
  private static User authorUser() {
    Profile admin = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    String uniq = 'triprpt' + DateTime.now().getTime();
    User u = new User(
      ProfileId = admin.Id,
      LastName = 'Author',
      Email = uniq + '@example.com',
      Username = uniq + '@smi-test.example.com',
      Alias = 'trauth',
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert u;
    PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Trip_Report_Author'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = u.Id,
      PermissionSetId = ps.Id
    );
    return u;
  }

  @isTest
  static void createTripReport_setsRecordTypeOwnerAndDraftState() {
    User author = authorUser();
    Id newId;
    System.runAs(author) {
      Test.startTest();
      newId = ContentPostController.createTripReport(
        'Enchantments thru-hike',
        '<p>Twenty miles, one long day.</p>',
        'Hiking',
        Date.today().addDays(-7),
        'Enchantments',
        'Strenuous',
        'larches, golden',
        new List<Id>()
      );
      Test.stopTest();
    }

    Content_Post__c rec = [
      SELECT
        OwnerId,
        Status__c,
        Visibility__c,
        Location__c,
        Free_Tags__c,
        RecordType.DeveloperName
      FROM Content_Post__c
      WHERE Id = :newId
    ];
    System.assertEquals('Trip_Report', rec.RecordType.DeveloperName);
    System.assertEquals(author.Id, rec.OwnerId, 'Author owns it');
    System.assertEquals(
      'Draft',
      rec.Status__c,
      'Trip report defaults to Draft'
    );
    System.assertEquals('Internal', rec.Visibility__c);
    System.assertEquals('Enchantments', rec.Location__c);
  }

  @isTest
  static void updateTripReport_successAndPublish() {
    User author = authorUser();
    Id postId;
    System.runAs(author) {
      postId = ContentPostController.createTripReport(
        'Draft Post',
        '<p>Draft body</p>',
        'Hiking',
        Date.today(),
        'Location',
        'Easy',
        'tag',
        new List<Id>()
      );

      Test.startTest();
      ContentPostController.updateTripReport(
        postId,
        'Updated Published Post',
        '<p>Clean body <script>alert(1)</script></p>',
        'Hiking',
        Date.today(),
        'New Location',
        'Moderate',
        'tag1, tag2',
        'Published',
        new List<Id>()
      );
      Test.stopTest();
    }

    Content_Post__c rec = [
      SELECT Title__c, Body__c, Status__c, Location__c, Publish_Date__c
      FROM Content_Post__c
      WHERE Id = :postId
    ];
    System.assertEquals('Updated Published Post', rec.Title__c);
    System.assertEquals(
      '<p>Clean body </p>',
      rec.Body__c,
      'Sanitizer should strip script tags'
    );
    System.assertEquals('Published', rec.Status__c);
    System.assertEquals(Date.today(), rec.Publish_Date__c);
  }

  @isTest
  static void updateTripReport_blockNonOwner() {
    User userA = createCommunityUser('UserA', true);
    User userB = createCommunityUser('UserB', true);
    Id postId;

    System.runAs(userA) {
      postId = ContentPostController.createTripReport(
        'UserA Draft',
        'Body',
        'Hiking',
        Date.today(),
        'Location',
        'Easy',
        '',
        new List<Id>()
      );
    }

    System.runAs(userB) {
      Test.startTest();
      try {
        ContentPostController.updateTripReport(
          postId,
          'Hacked',
          'Hacked body',
          'Hiking',
          Date.today(),
          'Hacked Location',
          'Easy',
          '',
          'Published',
          new List<Id>()
        );
        System.assert(false, 'Expected validation error');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
      Test.stopTest();
    }
  }

  @isTest
  static void deleteOwnDraft_success() {
    User author = authorUser();
    Id postId;
    System.runAs(author) {
      postId = ContentPostController.createTripReport(
        'Draft to delete',
        'body',
        'Hiking',
        Date.today(),
        'Location',
        'Easy',
        '',
        new List<Id>()
      );

      Test.startTest();
      ContentPostController.deleteOwnDraft(postId);
      Test.stopTest();
    }

    List<Content_Post__c> results = [
      SELECT Id
      FROM Content_Post__c
      WHERE Id = :postId
    ];
    System.assert(results.isEmpty(), 'Draft record should be deleted');
  }

  @isTest
  static void deleteOwnDraft_blockIfPublished() {
    User author = authorUser();
    Id postId;
    System.runAs(author) {
      postId = ContentPostController.createTripReport(
        'Draft',
        'body',
        'Hiking',
        Date.today(),
        'Location',
        'Easy',
        '',
        new List<Id>()
      );
      ContentPostController.updateTripReport(
        postId,
        'Published Post',
        'body',
        'Hiking',
        Date.today(),
        'Location',
        'Easy',
        '',
        'Published',
        new List<Id>()
      );

      Test.startTest();
      try {
        ContentPostController.deleteOwnDraft(postId);
        System.assert(false, 'Expected error deleting published post');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
      Test.stopTest();
    }
  }

  @isTest
  static void getMyPosts_returnsOnlyOwn() {
    User userA = createCommunityUser('UserA', true);
    User userB = createCommunityUser('UserB', true);

    System.runAs(userA) {
      ContentPostController.createTripReport(
        'UserA post',
        'body',
        'Hiking',
        Date.today(),
        'Loc',
        'Easy',
        '',
        new List<Id>()
      );
    }
    System.runAs(userB) {
      ContentPostController.createTripReport(
        'UserB post',
        'body',
        'Hiking',
        Date.today(),
        'Loc',
        'Easy',
        '',
        new List<Id>()
      );
    }

    System.runAs(userA) {
      Test.startTest();
      List<ContentPostController.PostDTO> posts = ContentPostController.getMyPosts();
      Test.stopTest();
      System.assertEquals(1, posts.size());
      System.assertEquals('UserA post', posts[0].title);
    }
  }

  @isTest
  static void createTripReport_blankTitleThrows() {
    try {
      ContentPostController.createTripReport(
        '  ',
        'body',
        null,
        null,
        null,
        null,
        null,
        new List<Id>()
      );
      System.assert(false, 'Expected an exception for a blank title');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  private static User createCommunityUser(
    String lastName,
    Boolean assignPermSet
  ) {
    User adminUser = [
      SELECT Id
      FROM User
      WHERE
        Profile.Name = 'System Administrator'
        AND UserRoleId != NULL
        AND IsActive = TRUE
      LIMIT 1
    ];

    Account a;
    Contact c;
    System.runAs(adminUser) {
      a = new Account(Name = lastName + ' Account');
      insert a;
      c = new Contact(
        AccountId = a.Id,
        FirstName = 'Portal',
        LastName = lastName,
        Email = lastName + '@example.com'
      );
      insert c;
    }

    Profile portalProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'SM Community Plus Member'
      LIMIT 1
    ];
    String uniqueVal = lastName + DateTime.now().getTime();
    User u = new User(
      ContactId = c.Id,
      ProfileId = portalProfile.Id,
      LastName = lastName,
      Email = lastName + '@example.com',
      Username = uniqueVal + '@smi-test.example.com',
      Alias = lastName.substring(0, Math.min(lastName.length(), 8)),
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    System.runAs(adminUser) {
      insert u;

      if (assignPermSet) {
        PermissionSet ps = [
          SELECT Id
          FROM PermissionSet
          WHERE Name = 'Trip_Report_Author'
          LIMIT 1
        ];
        insert new PermissionSetAssignment(
          AssigneeId = u.Id,
          PermissionSetId = ps.Id
        );
      }
    }
    return u;
  }

  @isTest
  static void createTripReport_portalUserWithPermSet_success() {
    User communityUser = createCommunityUser('PortalAuth', true);
    Id newId;
    System.runAs(communityUser) {
      Test.startTest();
      newId = ContentPostController.createTripReport(
        'Community user trip report',
        '<p>Success climb.</p>',
        'Climbing',
        Date.today(),
        'Beacon Rock',
        'Moderate',
        'fun',
        new List<Id>()
      );
      Test.stopTest();
    }
    System.assertNotEquals(null, newId, 'Post ID should be returned');
    Content_Post__c post = [
      SELECT OwnerId, Title__c
      FROM Content_Post__c
      WHERE Id = :newId
    ];
    System.assertEquals(communityUser.Id, post.OwnerId);
  }

  @isTest
  static void createTripReport_portalUserWithoutPermSet_throws() {
    User communityUser = createCommunityUser('PortalNoAuth', false);
    System.runAs(communityUser) {
      Test.startTest();
      try {
        ContentPostController.createTripReport(
          'Should fail',
          'body',
          'Climbing',
          Date.today(),
          'Beacon Rock',
          'Moderate',
          'fun',
          new List<Id>()
        );
        System.assert(false, 'Expected permission error');
      } catch (AuraHandledException e) {
        System.assert(true);
      }
      Test.stopTest();
    }
  }

  @isTest
  static void getPost_sharingRulesApplied() {
    User userA = createCommunityUser('UserA', true);
    User userB = createCommunityUser('UserB', true);

    Content_Post__c pubPost = makePost(
      'Published by UserA',
      'Published',
      'Climbing'
    );
    pubPost.OwnerId = userA.Id;

    Content_Post__c draftPost = makePost('Draft by UserA', 'Draft', 'Climbing');
    draftPost.OwnerId = userA.Id;

    Profile adminProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
    User adminUser = [
      SELECT Id
      FROM User
      WHERE ProfileId = :adminProfile.Id AND IsActive = TRUE
      LIMIT 1
    ];
    System.runAs(adminUser) {
      insert new List<Content_Post__c>{ pubPost, draftPost };

      // Manually insert a share record because criteria-based sharing rules are not recalculated during Apex test runs
      insert new Content_Post__Share(
        ParentId = pubPost.Id,
        UserOrGroupId = userB.Id,
        AccessLevel = 'Read',
        RowCause = 'Manual'
      );
    }

    System.runAs(userB) {
      Test.startTest();
      ContentPostController.PostDTO pubDto = ContentPostController.getPost(
        pubPost.Id
      );
      System.assertEquals('Published by UserA', pubDto.title);

      try {
        ContentPostController.getPost(draftPost.Id);
        System.assert(
          false,
          'UserB should not be able to access UserA\'s draft'
        );
      } catch (AuraHandledException e) {
        System.assert(true);
      }
      Test.stopTest();
    }
  }

  @isTest
  static void createAndUpdateTripReport_syncsControlledTags() {
    User author = authorUser();
    Content_Tag__c tag = [
      SELECT Id, Name
      FROM Content_Tag__c
      WHERE Name = 'Cascades'
      LIMIT 1
    ];

    Id postId;
    System.runAs(author) {
      Test.startTest();
      postId = ContentPostController.createTripReport(
        'With controlled tags',
        'Body',
        'Climbing',
        Date.today(),
        'Beacon Rock',
        'Moderate',
        'fun',
        new List<Id>{ tag.Id }
      );

      ContentPostController.PostDTO dto = ContentPostController.getPost(postId);
      System.assertEquals(
        1,
        dto.tagIds.size(),
        'Should have 1 controlled tag ID'
      );
      System.assertEquals(tag.Id, dto.tagIds[0]);
      System.assert(
        dto.displayTags.contains('Cascades'),
        'displayTags should include Cascades'
      );

      // Now update and remove tag
      ContentPostController.updateTripReport(
        postId,
        'Updated With tag removed',
        'Body',
        'Climbing',
        Date.today(),
        'Beacon Rock',
        'Moderate',
        'fun',
        'Published',
        new List<Id>()
      );
      Test.stopTest();
    }

    ContentPostController.PostDTO dto2 = ContentPostController.getPost(postId);
    System.assertEquals(
      0,
      dto2.tagIds.size(),
      'Should have 0 controlled tag IDs'
    );
    System.assert(
      !dto2.displayTags.contains('Cascades'),
      'displayTags should not include Cascades anymore'
    );
  }

  @isTest
  static void photoUploadAndManagement_success() {
    User author = authorUser();
    Id postId;
    System.runAs(author) {
      postId = ContentPostController.createTripReport(
        'Photo Post',
        'Body',
        'Climbing',
        Date.today(),
        'Beacon Rock',
        'Moderate',
        'fun',
        new List<Id>()
      );

      Test.startTest();
      Id photoId = ContentPostController.uploadPhoto(
        postId,
        'mountains.jpg',
        EncodingUtil.base64Encode(Blob.valueOf('fake-image-content')),
        'Beautiful mountains',
        'Summit sunset',
        'Jane Member',
        true,
        1,
        '16:9'
      );
      System.assertNotEquals(null, photoId);

      List<ContentPostController.PhotoDTO> photos = ContentPostController.getPostPhotos(
        postId
      );
      System.assertEquals(1, photos.size());
      System.assertEquals('Beautiful mountains', photos[0].altText);
      System.assertEquals('Summit sunset', photos[0].caption);

      // Delete photo
      ContentPostController.deletePhoto(photoId);
      Test.stopTest();

      photos = ContentPostController.getPostPhotos(postId);
      System.assertEquals(0, photos.size(), 'Photo should be deleted');
    }
  }
}
