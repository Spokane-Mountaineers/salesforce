/**
 * Service class for Content Post operations.
 * Handles background operations such as generating public file distributions
 * when a post is approved by staff.
 */
public with sharing class ContentPostService {
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
