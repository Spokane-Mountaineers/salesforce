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
    if (String.isNotBlank(tag)) {
      clauses.add(
        '(Free_Tags__c LIKE :tagLike OR Id IN (SELECT Content_Post__c ' +
        'FROM Content_Post_Tag__c WHERE Content_Tag__r.Name = :tag))'
      );
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

    List<PostDTO> results = new List<PostDTO>();
    for (Content_Post__c p : Database.query(soql)) {
      results.add(new PostDTO(p));
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
      WITH USER_MODE
      LIMIT 1
    ];
    if (posts.isEmpty()) {
      throw new AuraHandledException(
        'That post does not exist or you do not have access to it'
      );
    }
    return new PostDTO(posts[0], true);
  }

  /** Active controlled tags for the filter UI. */
  @AuraEnabled(cacheable=true)
  public static List<TagDTO> getActiveTags() {
    List<TagDTO> tags = new List<TagDTO>();
    for (Content_Tag__c t : [
      SELECT Id, Name, Category__c
      FROM Content_Tag__c
      WHERE Active__c = TRUE
      WITH USER_MODE
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
    String freeTags
  ) {
    if (String.isBlank(title)) {
      throw new AuraHandledException('A title is required');
    }
    Id tripRtId = recordTypeId('Trip_Report');
    Content_Post__c post = new Content_Post__c(
      RecordTypeId = tripRtId,
      Title__c = title.trim(),
      Body__c = body,
      Activity__c = activity,
      Trip_Date__c = tripDate,
      Location__c = location,
      Difficulty__c = difficulty,
      Free_Tags__c = freeTags,
      Visibility__c = 'Internal',
      Status__c = 'Published',
      Publish_Date__c = Date.today()
    );
    try {
      // USER_MODE so the permission set + record-type access are the real gate:
      // a member without create rights fails here, as the contract test asserts.
      insert as user post;
    } catch (DmlException e) {
      throw new AuraHandledException(e.getDmlMessage(0));
    }
    return post.Id;
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
