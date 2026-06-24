/**
 * Service class for Content Post operations.
 * Handles background operations such as generating public file distributions
 * when a post is approved by staff.
 */
public with sharing class ContentPostService {
  private static Map<Id, Boolean> isAuthorizedMap = new Map<Id, Boolean>();
  private static Id cachedQueueId;

  public static Id getQueueId() {
    if (cachedQueueId == null) {
      List<Group> queues = [
        SELECT Id
        FROM Group
        WHERE DeveloperName = 'Content_Approval' AND Type = 'Queue'
        LIMIT 1
      ];
      if (!queues.isEmpty()) {
        cachedQueueId = queues[0].Id;
      }
    }
    return cachedQueueId;
  }

  public static Boolean isAuthorizedApprover() {
    Id userId = UserInfo.getUserId();
    if (isAuthorizedMap.containsKey(userId)) {
      return isAuthorizedMap.get(userId);
    }

    Id profileId = UserInfo.getProfileId();
    List<Profile> profiles = [
      SELECT Name
      FROM Profile
      WHERE Id = :profileId
      LIMIT 1
    ];
    if (!profiles.isEmpty() && profiles[0].Name == 'System Administrator') {
      isAuthorizedMap.put(userId, true);
      return true;
    }

    Set<Id> userGroupIds = new Set<Id>{ userId };
    for (GroupMember gm : [
      SELECT GroupId
      FROM GroupMember
      WHERE UserOrGroupId = :userId
    ]) {
      userGroupIds.add(gm.GroupId);
    }

    if (UserInfo.getUserType() == 'Standard') {
      for (Group g : [
        SELECT Id
        FROM Group
        WHERE DeveloperName = 'AllInternalUsers' AND Type = 'Organization'
      ]) {
        userGroupIds.add(g.Id);
      }
    }

    Integer count = [
      SELECT COUNT()
      FROM GroupMember
      WHERE
        Group.DeveloperName = 'Content_Approval'
        AND Group.Type = 'Queue'
        AND UserOrGroupId IN :userGroupIds
    ];

    Boolean result = (count > 0);
    isAuthorizedMap.put(userId, result);
    return result;
  }

  public static void handleBeforeInsert(List<Content_Post__c> newPosts) {
    Id tripRtId = Schema.SObjectType.Content_Post__c.getRecordTypeInfosByDeveloperName()
      .get('Trip_Report')
      .getRecordTypeId();
    Id qId = getQueueId();
    Boolean isApprover = isAuthorizedApprover();

    for (Content_Post__c post : newPosts) {
      if (post.RecordTypeId == tripRtId) {
        if (!isApprover) {
          if (
            post.Visibility__c == 'Public' ||
            post.Public_Review_Status__c == 'Approved'
          ) {
            post.addError(
              'You do not have permission to publish this post publicly or approve it.'
            );
            continue;
          }
        }

        if (post.Submit_For_Public__c == true) {
          post.Visibility__c = 'Internal';
          post.Public_Review_Status__c = 'Pending';
          if (qId != null) {
            post.OwnerId = qId;
          }
        }
      }
    }
  }

  public static void handleBeforeUpdate(
    List<Content_Post__c> newPosts,
    Map<Id, Content_Post__c> oldMap
  ) {
    Id tripRtId = Schema.SObjectType.Content_Post__c.getRecordTypeInfosByDeveloperName()
      .get('Trip_Report')
      .getRecordTypeId();
    Id qId = getQueueId();
    Boolean isApprover = isAuthorizedApprover();

    for (Content_Post__c post : newPosts) {
      if (post.RecordTypeId == tripRtId) {
        Content_Post__c oldPost = oldMap.get(post.Id);

        boolean visChangedToPublic = (post.Visibility__c == 'Public' &&
        oldPost.Visibility__c != 'Public');
        boolean statusChangedToApproved = (post.Public_Review_Status__c ==
        'Approved' &&
        oldPost.Public_Review_Status__c != 'Approved');

        if (!isApprover) {
          if (visChangedToPublic || statusChangedToApproved) {
            post.addError(
              'You do not have permission to publish this post publicly or approve it.'
            );
            continue;
          }
        }

        // Handle requesting public visibility
        boolean submitChangedToTrue = (post.Submit_For_Public__c == true &&
        oldPost.Submit_For_Public__c != true);
        if (submitChangedToTrue && !isApprover) {
          post.Visibility__c = 'Internal';
          post.Public_Review_Status__c = 'Pending';
          if (qId != null) {
            post.OwnerId = qId;
          }
        }

        // Handle transitioning review status (done by approver)
        if (oldPost.Public_Review_Status__c == 'Pending') {
          if (post.Public_Review_Status__c == 'Approved') {
            post.Visibility__c = 'Public';
            post.OwnerId = post.CreatedById != null
              ? post.CreatedById
              : UserInfo.getUserId();
          } else if (post.Public_Review_Status__c == 'Rejected') {
            post.Visibility__c = 'Internal';
            post.Submit_For_Public__c = false;
            post.OwnerId = post.CreatedById != null
              ? post.CreatedById
              : UserInfo.getUserId();
          }
        }
      }
    }
  }
  /**
   * Handles after-update trigger events on Content_Post__c.
   * Detects transition to 'Approved' public review status to generate public urls.
   *
   * @param newPosts Trigger.new
   * @param oldMap Trigger.oldMap
   */
  public static void handleAfterUpdate(
    List<Content_Post__c> newPosts,
    Map<Id, Content_Post__c> oldMap
  ) {
    Set<Id> approvedPostIds = new Set<Id>();
    for (Content_Post__c newPost : newPosts) {
      Content_Post__c oldPost = oldMap.get(newPost.Id);
      if (
        newPost.Public_Review_Status__c == 'Approved' &&
        oldPost.Public_Review_Status__c != 'Approved'
      ) {
        approvedPostIds.add(newPost.Id);
      }
    }

    if (!approvedPostIds.isEmpty()) {
      generatePublicUrls(approvedPostIds);
    }
  }

  /**
   * Generates ContentDistribution records for photos linked to approved posts,
   * populating their Public_Url__c fields.
   *
   * @param postIds Approved Content_Post__c IDs
   */
  public static void generatePublicUrls(Set<Id> postIds) {
    List<Content_Post_Photo__c> photos = [
      SELECT Id, Content_Document_Id__c, Public_Url__c
      FROM Content_Post_Photo__c
      WHERE Content_Post__c IN :postIds AND Public_Url__c = NULL
    ];

    if (photos.isEmpty()) {
      return;
    }

    Set<String> docIds = new Set<String>();
    for (Content_Post_Photo__c photo : photos) {
      docIds.add(photo.Content_Document_Id__c);
    }

    Map<Id, ContentVersion> docIdToVersion = new Map<Id, ContentVersion>();
    for (ContentVersion cv : [
      SELECT Id, ContentDocumentId, Title
      FROM ContentVersion
      WHERE ContentDocumentId IN :docIds AND IsLatest = TRUE
    ]) {
      docIdToVersion.put(cv.ContentDocumentId, cv);
    }

    List<ContentDistribution> dists = new List<ContentDistribution>();
    for (Content_Post_Photo__c photo : photos) {
      ContentVersion cv = docIdToVersion.get(photo.Content_Document_Id__c);
      if (cv != null) {
        dists.add(
          new ContentDistribution(
            Name = cv.Title,
            ContentVersionId = cv.Id,
            PreferencesAllowViewInBrowser = true,
            PreferencesLinkLatestVersion = true,
            PreferencesNotifyOnVisit = false,
            PreferencesPasswordRequired = false
          )
        );
      }
    }

    if (!dists.isEmpty()) {
      insert dists;

      Map<Id, ContentDistribution> versionToDist = new Map<Id, ContentDistribution>();
      for (ContentDistribution cd : [
        SELECT ContentVersionId, ContentDownloadUrl
        FROM ContentDistribution
        WHERE Id IN :dists
      ]) {
        versionToDist.put(cd.ContentVersionId, cd);
      }

      List<Content_Post_Photo__c> photosToUpdate = new List<Content_Post_Photo__c>();
      for (Content_Post_Photo__c photo : photos) {
        ContentVersion cv = docIdToVersion.get(photo.Content_Document_Id__c);
        if (cv != null && versionToDist.containsKey(cv.Id)) {
          ContentDistribution cd = versionToDist.get(cv.Id);
          photo.Public_Url__c = cd.ContentDownloadUrl;
          photosToUpdate.add(photo);
        }
      }

      if (!photosToUpdate.isEmpty()) {
        update photosToUpdate;
      }
    }
  }
}
