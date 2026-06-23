/**
 * Controller for the LWR blog/content system (plan §3).
 *
 * `with sharing` is load-bearing: the blog index and post detail rely on the
 * platform sharing model (OWD Private + a Published sharing rule) to decide what
 * a given member may read. The contract is the DTO shape returned to the LWCs +
 * the permission/sharing behaviour asserted in ContentPostControllerTest.
 */
public with sharing class ContentPostController {
  /**
   * Published posts for the blog index, newest first, with optional filters.
   * Sharing decides visibility; this only adds the Published gate + filters.
   *
   * @param activity controlled Activity__c value, or blank for all
   * @param tag controlled Content_Tag__c name OR a free tag, or blank for all
   * @param search free-text matched against title / location / free tags
   */
  @AuraEnabled(cacheable=true)
  public static List<PostDTO> getPublishedPosts(
    String activity,
    String tag,
    String search
  ) {
    String soql =
      'SELECT Id, Name, Title__c, Status__c, Visibility__c, Activity__c, ' +
      'Publish_Date__c, Trip_Date__c, Location__c, Difficulty__c, Free_Tags__c, ' +
      'RecordType.DeveloperName, Owner.Name ' +
      'FROM Content_Post__c WHERE Status__c = :statusPublished';
    String statusPublished = 'Published';
    List<String> clauses = new List<String>();

    if (String.isNotBlank(activity)) {
      clauses.add('Activity__c = :activity');
    }
    // Pre-query tagged post ids: a semi-join sub-select can't live inside an OR
    // / nested WHERE, but a bound `Id IN :set` can go anywhere.
    Set<Id> taggedPostIds = new Set<Id>();
    if (String.isNotBlank(tag)) {
      for (Content_Post_Tag__c link : [
        SELECT Content_Post__c
        FROM Content_Post_Tag__c
        WHERE Content_Tag__r.Name = :tag
      ]) {
        taggedPostIds.add(link.Content_Post__c);
      }
      clauses.add('(Free_Tags__c LIKE :tagLike OR Id IN :taggedPostIds)');
    }
    if (String.isNotBlank(search)) {
      clauses.add(
        '(Title__c LIKE :searchLike OR Location__c LIKE :searchLike ' +
        'OR Free_Tags__c LIKE :searchLike)'
      );
    }
    String tagLike = '%' + escape(tag) + '%';
    String searchLike = '%' + escape(search) + '%';

    if (!clauses.isEmpty()) {
      soql += ' AND ' + String.join(clauses, ' AND ');
    }
    soql += ' ORDER BY Publish_Date__c DESC NULLS LAST, CreatedDate DESC LIMIT 200';

    List<Content_Post__c> posts = Database.query(soql);
    Map<Id, List<String>> postToTagNames = new Map<Id, List<String>>();
    for (Content_Post_Tag__c cpt : [
      SELECT Content_Post__c, Content_Tag__r.Name
      FROM Content_Post_Tag__c
      WHERE Content_Post__c IN :posts
    ]) {
      if (!postToTagNames.containsKey(cpt.Content_Post__c)) {
        postToTagNames.put(cpt.Content_Post__c, new List<String>());
      }
      postToTagNames.get(cpt.Content_Post__c).add(cpt.Content_Tag__r.Name);
    }

    List<PostDTO> results = new List<PostDTO>();
    for (Content_Post__c p : posts) {
      PostDTO dto = new PostDTO(p);
      if (postToTagNames.containsKey(p.Id)) {
        dto.displayTags.addAll(postToTagNames.get(p.Id));
      }
      results.add(dto);
    }
    return results;
  }

  /** A single post for the detail page (sharing-checked). */
  @AuraEnabled(cacheable=true)
  public static PostDTO getPost(Id postId) {
    if (postId == null) {
      throw new AuraHandledException('A post id is required');
    }
    List<Content_Post__c> posts = [
      SELECT
        Id,
        Name,
        Title__c,
        Body__c,
        Status__c,
        Visibility__c,
        Activity__c,
        Publish_Date__c,
        Trip_Date__c,
        Location__c,
        Difficulty__c,
        Free_Tags__c,
        RecordType.DeveloperName,
        Owner.Name
      FROM Content_Post__c
      WHERE Id = :postId
      LIMIT 1
    ];
    if (posts.isEmpty()) {
      throw new AuraHandledException(
        'That post does not exist or you do not have access to it'
      );
    }
    PostDTO dto = new PostDTO(posts[0], true);
    for (Content_Post_Tag__c cpt : [
      SELECT Content_Tag__c, Content_Tag__r.Name
      FROM Content_Post_Tag__c
      WHERE Content_Post__c = :posts[0].Id
    ]) {
      dto.tagIds.add(cpt.Content_Tag__c);
      dto.displayTags.add(cpt.Content_Tag__r.Name);
    }
    return dto;
  }

  /** Active controlled tags for the filter UI. */
  @AuraEnabled(cacheable=true)
  public static List<TagDTO> getActiveTags() {
    List<TagDTO> tags = new List<TagDTO>();
    for (Content_Tag__c t : [
      SELECT Id, Name, Category__c
      FROM Content_Tag__c
      WHERE Active__c = TRUE
      ORDER BY Category__c, Name
    ]) {
      tags.add(new TagDTO(t));
    }
    return tags;
  }

  /**
   * Member-facing create for a Trip Report (plan §3.3). Forces the Trip Report
   * record type so members can't post Announcements; the member owns the record
   * (so they can edit their own). Internal trip reports publish on submit;
   * making one Public is a separate, approval-gated step (§5.5).
   */
  @AuraEnabled
  public static Id createTripReport(
    String title,
    String body,
    String activity,
    Date tripDate,
    String location,
    String difficulty,
    String freeTags,
    List<Id> tagIds
  ) {
    if (String.isBlank(title)) {
      throw new AuraHandledException('A title is required');
    }
    Id tripRtId = recordTypeId('Trip_Report');
    Content_Post__c post = new Content_Post__c(
      RecordTypeId = tripRtId,
      Title__c = title.trim(),
      Body__c = sanitizeHtml(body),
      Activity__c = activity,
      Trip_Date__c = tripDate,
      Location__c = location,
      Difficulty__c = difficulty,
      Free_Tags__c = freeTags,
      Visibility__c = 'Internal',
      Status__c = 'Draft'
    );
    if (!Schema.sObjectType.Content_Post__c.isCreateable()) {
      throw new AuraHandledException(
        'You do not have permission to create trip reports.'
      );
    }
    try {
      insert post;

      if (tagIds != null && !tagIds.isEmpty()) {
        List<Content_Post_Tag__c> postTags = new List<Content_Post_Tag__c>();
        for (Id tagId : tagIds) {
          postTags.add(
            new Content_Post_Tag__c(
              Content_Post__c = post.Id,
              Content_Tag__c = tagId
            )
          );
        }
        insert postTags;
      }
    } catch (DmlException e) {
      throw new AuraHandledException(e.getDmlMessage(0));
    }
    return post.Id;
  }

  @AuraEnabled
  public static void updateTripReport(
    Id postId,
    String title,
    String body,
    String activity,
    Date tripDate,
    String location,
    String difficulty,
    String freeTags,
    String status,
    List<Id> tagIds
  ) {
    if (postId == null) {
      throw new AuraHandledException('Post ID is required');
    }
    if (!Schema.sObjectType.Content_Post__c.isUpdateable()) {
      throw new AuraHandledException(
        'You do not have permission to edit trip reports.'
      );
    }
    List<Content_Post__c> posts = [
      SELECT OwnerId, Status__c, Visibility__c, Publish_Date__c
      FROM Content_Post__c
      WHERE Id = :postId
      LIMIT 1
    ];
    if (posts.isEmpty()) {
      throw new AuraHandledException(
        'You do not have permission to edit this trip report.'
      );
    }
    Content_Post__c post = posts[0];

    if (
      post.OwnerId != UserInfo.getUserId() &&
      !UserInfo.getProfileId().equals(getAdminProfileId())
    ) {
      throw new AuraHandledException(
        'You do not have permission to edit this trip report.'
      );
    }

    post.Title__c = title == null ? null : title.trim();
    post.Body__c = sanitizeHtml(body);
    post.Activity__c = activity;
    post.Trip_Date__c = tripDate;
    post.Location__c = location;
    post.Difficulty__c = difficulty;
    post.Free_Tags__c = freeTags;

    if (String.isNotBlank(status)) {
      post.Status__c = status;
      if (status == 'Published' && post.Publish_Date__c == null) {
        post.Publish_Date__c = Date.today();
      }
    }

    try {
      update post;

      if (tagIds != null) {
        delete [
          SELECT Id
          FROM Content_Post_Tag__c
          WHERE Content_Post__c = :postId
        ];
        if (!tagIds.isEmpty()) {
          List<Content_Post_Tag__c> postTags = new List<Content_Post_Tag__c>();
          for (Id tagId : tagIds) {
            postTags.add(
              new Content_Post_Tag__c(
                Content_Post__c = postId,
                Content_Tag__c = tagId
              )
            );
          }
          insert postTags;
        }
      }
    } catch (DmlException e) {
      throw new AuraHandledException(e.getDmlMessage(0));
    }
  }

  @AuraEnabled
  public static void deleteOwnDraft(Id postId) {
    if (postId == null) {
      throw new AuraHandledException('Post ID is required');
    }
    if (!Schema.sObjectType.Content_Post__c.isDeletable()) {
      throw new AuraHandledException(
        'You do not have permission to delete trip reports.'
      );
    }
    List<Content_Post__c> posts = [
      SELECT OwnerId, Status__c
      FROM Content_Post__c
      WHERE Id = :postId
      LIMIT 1
    ];
    if (posts.isEmpty()) {
      throw new AuraHandledException(
        'You do not have permission to delete this trip report.'
      );
    }
    Content_Post__c post = posts[0];
    if (post.OwnerId != UserInfo.getUserId()) {
      throw new AuraHandledException(
        'You do not have permission to delete this trip report.'
      );
    }
    if (post.Status__c != 'Draft') {
      throw new AuraHandledException('You can only delete drafts.');
    }
    try {
      delete post;
    } catch (DmlException e) {
      throw new AuraHandledException(e.getDmlMessage(0));
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<PostDTO> getMyPosts() {
    Id currentUserId = UserInfo.getUserId();
    List<Content_Post__c> posts = [
      SELECT
        Id,
        Name,
        Title__c,
        Status__c,
        Visibility__c,
        Activity__c,
        Publish_Date__c,
        Trip_Date__c,
        Location__c,
        Difficulty__c,
        Free_Tags__c,
        RecordType.DeveloperName,
        Owner.Name
      FROM Content_Post__c
      WHERE
        OwnerId = :currentUserId
        AND RecordType.DeveloperName = 'Trip_Report'
      ORDER BY CreatedDate DESC
    ];
    Map<Id, List<String>> postToTagNames = new Map<Id, List<String>>();
    for (Content_Post_Tag__c cpt : [
      SELECT Content_Post__c, Content_Tag__r.Name
      FROM Content_Post_Tag__c
      WHERE Content_Post__c IN :posts
    ]) {
      if (!postToTagNames.containsKey(cpt.Content_Post__c)) {
        postToTagNames.put(cpt.Content_Post__c, new List<String>());
      }
      postToTagNames.get(cpt.Content_Post__c).add(cpt.Content_Tag__r.Name);
    }

    List<PostDTO> results = new List<PostDTO>();
    for (Content_Post__c p : posts) {
      PostDTO dto = new PostDTO(p);
      if (postToTagNames.containsKey(p.Id)) {
        dto.displayTags.addAll(postToTagNames.get(p.Id));
      }
      results.add(dto);
    }
    return results;
  }

  public static String sanitizeHtml(String html) {
    if (String.isBlank(html)) {
      return '';
    }
    String cleaned = html.replaceAll(
      '(?i)<script[^>]*?>[\\s\\S]*?</script>',
      ''
    );
    cleaned = cleaned.replaceAll(
      '(?i)\\son\\w+\\s*=\\s*("[^"]*"|\'[^\']*\'|[^>\\s]+)',
      ''
    );
    cleaned = cleaned.replaceAll(
      '(?i)(href|src)\\s*=\\s*("[^"]*javascript:[^"]*"|\'[^\']*javascript:[^\']*\'|[^>\\s]*javascript:[^>\\s]*)',
      '$1="#"'
    );
    cleaned = cleaned.replaceAll(
      '(?i)<(iframe|embed|object|frame|frameset|meta|link)[^>]*?>',
      ''
    );
    cleaned = cleaned.replaceAll(
      '(?i)</(iframe|embed|object|frame|frameset|meta|link)>',
      ''
    );
    return cleaned;
  }

  private static Id getAdminProfileId() {
    return [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1]
    .Id;
  }

  private static Id recordTypeId(String developerName) {
    return Schema.SObjectType.Content_Post__c.getRecordTypeInfosByDeveloperName()
      .get(developerName)
      .getRecordTypeId();
  }

  /** Escape SOQL LIKE wildcards/quotes in user input. */
  private static String escape(String input) {
    if (String.isBlank(input)) {
      return '';
    }
    return String.escapeSingleQuotes(input)
      .replace('%', '\\%')
      .replace('_', '\\_');
  }

  /** Stable shape the LWCs bind to (the Apex↔LWC contract, plan §7.4). */
  public class PostDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String body;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String visibility;
    @AuraEnabled
    public String activity;
    @AuraEnabled
    public Date publishDate;
    @AuraEnabled
    public Date tripDate;
    @AuraEnabled
    public String location;
    @AuraEnabled
    public String difficulty;
    @AuraEnabled
    public List<String> freeTags;
    @AuraEnabled
    public List<String> displayTags;
    @AuraEnabled
    public List<Id> tagIds;
    @AuraEnabled
    public String recordType;
    @AuraEnabled
    public String authorName;

    public PostDTO(Content_Post__c p) {
      this(p, false);
    }

    public PostDTO(Content_Post__c p, Boolean includeBody) {
      this.id = p.Id;
      this.name = p.Name;
      this.title = p.Title__c;
      this.status = p.Status__c;
      this.visibility = p.Visibility__c;
      this.activity = p.Activity__c;
      this.publishDate = p.Publish_Date__c;
      this.tripDate = p.Trip_Date__c;
      this.location = p.Location__c;
      this.difficulty = p.Difficulty__c;
      this.recordType = p.RecordType.DeveloperName;
      this.authorName = p.Owner.Name;
      this.freeTags = splitTags(p.Free_Tags__c);
      this.displayTags = new List<String>(this.freeTags);
      this.tagIds = new List<Id>();
      if (includeBody) {
        this.body = p.Body__c;
      }
    }
  }

  public class TagDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String category;

    public TagDTO(Content_Tag__c t) {
      this.id = t.Id;
      this.name = t.Name;
      this.category = t.Category__c;
    }
  }

  @AuraEnabled
  public static Id uploadPhoto(
    Id postId,
    String fileName,
    String base64Data,
    String altText,
    String caption,
    String credit,
    Boolean consentConfirmed,
    Integer sortOrder,
    String aspectRatio
  ) {
    if (postId == null) {
      throw new AuraHandledException('Post ID is required');
    }

    ContentVersion cv = new ContentVersion(
      Title = fileName,
      PathOnClient = fileName,
      VersionData = EncodingUtil.base64Decode(base64Data),
      IsMajorVersion = true
    );
    try {
      insert cv;
    } catch (DmlException e) {
      throw new AuraHandledException(
        'Failed to upload file: ' + e.getDmlMessage(0)
      );
    }

    Id conDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
      LIMIT 1
    ]
    .ContentDocumentId;

    ContentDocumentLink cdl = new ContentDocumentLink(
      ContentDocumentId = conDocId,
      LinkedEntityId = postId,
      ShareType = 'V',
      Visibility = 'AllUsers'
    );
    try {
      insert cdl;
    } catch (DmlException e) {
      throw new AuraHandledException(
        'Failed to link file to post: ' + e.getDmlMessage(0)
      );
    }

    Content_Post_Photo__c cpp = new Content_Post_Photo__c(
      Content_Post__c = postId,
      Content_Document_Id__c = conDocId,
      Alt_Text__c = altText,
      Caption__c = caption,
      Credit__c = credit,
      Consent_Confirmed__c = consentConfirmed,
      Sort_Order__c = sortOrder,
      Aspect_Ratio__c = aspectRatio
    );
    try {
      insert cpp;
    } catch (DmlException e) {
      throw new AuraHandledException(
        'Failed to save photo metadata: ' + e.getDmlMessage(0)
      );
    }

    return cpp.Id;
  }

  @AuraEnabled(cacheable=true)
  public static List<PhotoDTO> getPostPhotos(Id postId) {
    if (postId == null) {
      throw new AuraHandledException('Post ID is required');
    }
    List<Content_Post_Photo__c> photos = [
      SELECT
        Id,
        Content_Document_Id__c,
        Alt_Text__c,
        Caption__c,
        Credit__c,
        Consent_Confirmed__c,
        Sort_Order__c,
        Aspect_Ratio__c,
        Public_Url__c
      FROM Content_Post_Photo__c
      WHERE Content_Post__c = :postId
      ORDER BY Sort_Order__c ASC, CreatedDate ASC
    ];
    List<PhotoDTO> dtos = new List<PhotoDTO>();
    for (Content_Post_Photo__c p : photos) {
      dtos.add(new PhotoDTO(p));
    }
    return dtos;
  }

  @AuraEnabled
  public static void deletePhoto(Id photoId) {
    if (photoId == null) {
      throw new AuraHandledException('Photo ID is required');
    }
    List<Content_Post_Photo__c> photos = [
      SELECT Id, Content_Document_Id__c, Content_Post__r.OwnerId
      FROM Content_Post_Photo__c
      WHERE Id = :photoId
      LIMIT 1
    ];
    if (photos.isEmpty()) {
      throw new AuraHandledException('Photo not found');
    }
    Content_Post_Photo__c photo = photos[0];
    if (photo.Content_Post__r.OwnerId != UserInfo.getUserId()) {
      throw new AuraHandledException(
        'You do not have permission to delete this photo.'
      );
    }

    try {
      delete new ContentDocument(Id = photo.Content_Document_Id__c);
      delete photo;
    } catch (DmlException e) {
      throw new AuraHandledException(
        'Failed to delete photo: ' + e.getDmlMessage(0)
      );
    }
  }

  public class PhotoDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String contentDocumentId;
    @AuraEnabled
    public String altText;
    @AuraEnabled
    public String caption;
    @AuraEnabled
    public String credit;
    @AuraEnabled
    public Boolean consentConfirmed;
    @AuraEnabled
    public Integer sortOrder;
    @AuraEnabled
    public String aspectRatio;
    @AuraEnabled
    public String publicUrl;
    @AuraEnabled
    public String memberUrl;

    public PhotoDTO(Content_Post_Photo__c p) {
      this.id = p.Id;
      this.contentDocumentId = p.Content_Document_Id__c;
      this.altText = p.Alt_Text__c;
      this.caption = p.Caption__c;
      this.credit = p.Credit__c;
      this.consentConfirmed = p.Consent_Confirmed__c;
      this.sortOrder = p.Sort_Order__c != null
        ? p.Sort_Order__c.intValue()
        : null;
      this.aspectRatio = p.Aspect_Ratio__c;
      this.publicUrl = p.Public_Url__c;
      this.memberUrl =
        '/sfc/servlet.shepherd/document/download/' + p.Content_Document_Id__c;
    }
  }

  private static List<String> splitTags(String csv) {
    List<String> out = new List<String>();
    if (String.isBlank(csv)) {
      return out;
    }
    for (String part : csv.split(',')) {
      if (String.isNotBlank(part)) {
        out.add(part.trim());
      }
    }
    return out;
  }
}
