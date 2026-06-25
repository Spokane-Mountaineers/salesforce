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

  /**
   * Links document link records using ServiceDb without sharing.
   */
  public static void insertLinks(List<ContentDocumentLink> cdls) {
    ServiceDb db = new ServiceDb();
    db.insertLinks(cdls);
  }

  /**
   * Scans and parses inline base64 images in HTML, uploads them to ContentVersion,
   * generates ContentDistribution, and replaces image src attributes with the public CDN URL.
   * Collects created ContentDocumentIds to link them to the post.
   *
   * @param html The HTML string containing raw base64 data.
   * @param outDocIds Output list to collect the created ContentDocumentIds.
   * @return The rewritten HTML string.
   */
  public static String processInlineImagesInHtml(
    String html,
    List<Id> outDocIds
  ) {
    if (String.isBlank(html)) {
      return html;
    }

    List<ContentVersion> cvsToInsert = new List<ContentVersion>();
    List<InlineImageInfo> imageInfos = new List<InlineImageInfo>();

    Pattern imgPattern = Pattern.compile(
      'src=(["\'])data:image/([a-zA-Z]+);base64,([^"\']+)\\1'
    );
    Matcher imgMatcher = imgPattern.matcher(html);

    while (imgMatcher.find()) {
      String quoteChar = imgMatcher.group(1);
      String ext = imgMatcher.group(2);
      String base64Data = imgMatcher.group(3);

      ContentVersion cv = new ContentVersion(
        Title = 'Inline Image ' + DateTime.now().getTime(),
        PathOnClient = 'inline_' + DateTime.now().getTime() + '.' + ext,
        VersionData = EncodingUtil.base64Decode(base64Data),
        IsMajorVersion = true
      );
      cvsToInsert.add(cv);

      InlineImageInfo info = new InlineImageInfo();
      info.cv = cv;
      info.originalMatch = imgMatcher.group(0);
      info.quoteChar = quoteChar;
      imageInfos.add(info);
    }

    if (cvsToInsert.isEmpty()) {
      return html;
    }

    ServiceDb db = new ServiceDb();
    db.insertContentVersions(cvsToInsert);

    List<ContentDistribution> distsToInsert = new List<ContentDistribution>();
    for (InlineImageInfo info : imageInfos) {
      distsToInsert.add(
        new ContentDistribution(
          Name = info.cv.Title,
          ContentVersionId = info.cv.Id,
          PreferencesAllowViewInBrowser = true,
          PreferencesLinkLatestVersion = true,
          PreferencesNotifyOnVisit = false,
          PreferencesPasswordRequired = false
        )
      );
    }
    db.insertDistributions(distsToInsert);

    Set<Id> cvIds = new Set<Id>();
    for (ContentVersion cv : cvsToInsert) {
      cvIds.add(cv.Id);
    }

    Map<Id, ContentVersion> cvMap = db.queryVersions(cvIds);

    Map<Id, ContentDistribution> distMap = new Map<Id, ContentDistribution>();
    for (ContentDistribution cd : db.queryDistributions(distsToInsert)) {
      distMap.put(cd.ContentVersionId, cd);
    }

    String rewrittenHtml = html;
    for (InlineImageInfo info : imageInfos) {
      ContentVersion cv = cvMap.get(info.cv.Id);
      ContentDistribution cd = distMap.get(info.cv.Id);

      if (cv != null && cd != null) {
        String replacement =
          'src=' +
          info.quoteChar +
          cd.ContentDownloadUrl +
          info.quoteChar;
        rewrittenHtml = rewrittenHtml.replace(info.originalMatch, replacement);

        if (cv.ContentDocumentId != null && outDocIds != null) {
          outDocIds.add(cv.ContentDocumentId);
        }
      }
    }

    return rewrittenHtml;
  }

  public class InlineImageInfo {
    public ContentVersion cv;
    public String originalMatch;
    public String quoteChar;
  }

  private without sharing class ServiceDb {
    public void insertContentVersions(List<ContentVersion> cvs) {
      insert cvs;
    }
    public void insertDistributions(List<ContentDistribution> cds) {
      insert cds;
    }
    public void insertLinks(List<ContentDocumentLink> cdls) {
      Database.insert(cdls, false);
    }
    public Map<Id, ContentVersion> queryVersions(Set<Id> cvIds) {
      return new Map<Id, ContentVersion>(
        [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :cvIds]
      );
    }
    public List<ContentDistribution> queryDistributions(
      List<ContentDistribution> dists
    ) {
      return [
        SELECT ContentVersionId, ContentDownloadUrl
        FROM ContentDistribution
        WHERE Id IN :dists
      ];
    }
  }
}
