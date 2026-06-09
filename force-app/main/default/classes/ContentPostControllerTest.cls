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

  @isTest
  static void createTripReport_setsRecordTypeOwnerAndPublishes() {
    Test.startTest();
    Id newId = ContentPostController.createTripReport(
      'Enchantments thru-hike',
      '<p>Twenty miles, one long day.</p>',
      'Hiking',
      Date.today().addDays(-7),
      'Enchantments',
      'Strenuous',
      'larches, golden'
    );
    Test.stopTest();

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
    System.assertEquals(UserInfo.getUserId(), rec.OwnerId, 'Author owns it');
    System.assertEquals(
      'Published',
      rec.Status__c,
      'Internal publishes on submit'
    );
    System.assertEquals('Internal', rec.Visibility__c);
    System.assertEquals('Enchantments', rec.Location__c);
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
        null
      );
      System.assert(false, 'Expected an exception for a blank title');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }
}
