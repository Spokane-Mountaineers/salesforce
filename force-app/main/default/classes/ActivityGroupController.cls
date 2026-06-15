/**
 * Controller for the LWR Activities surfaces: the activity-group directory and
 * the per-group page. Activity groups are CollaborationGroups (Chatter groups) —
 * a dynamic, club-managed set (~50, public and private, including bespoke ones),
 * NOT a hardcoded list. `with sharing` so private groups only surface to their
 * members, while public groups are discoverable by any member.
 *
 * Chairs continue to manage membership and approve events in Salesforce (the
 * per-group Event_Registration__c approval processes); these read-only methods
 * never touch that, so no web-dev involvement is needed for group operations.
 */
public with sharing class ActivityGroupController {
  /**
   * Visible activity groups for the directory, busiest first: every public group
   * plus any private group the user belongs to. Public club groups are meant to
   * be discoverable, but Chatter scopes group visibility to the user's network,
   * which hides them from community members — so the read runs `without sharing`
   * and we apply the public/own-private rule ourselves.
   */
  @AuraEnabled(cacheable=true)
  public static List<GroupDTO> getGroups() {
    Set<String> core = coreGroupNames();
    List<GroupDTO> groups = new List<GroupDTO>();
    for (CollaborationGroup g : new GroupSelector().visibleGroups()) {
      groups.add(new GroupDTO(g, core.contains(g.Name)));
    }
    return groups;
  }

  /**
   * The core activity groups = the active Event_Registration__c.Activity_Group__c
   * picklist values (the groups with the formal per-group event-approval
   * workflow). Data-driven on purpose: a new core group is a picklist value +
   * approval process, not a code change here.
   */
  private static Set<String> coreGroupNames() {
    Set<String> names = new Set<String>();
    for (
      Schema.PicklistEntry e : Event_Registration__c.Activity_Group__c.getDescribe()
        .getPicklistValues()
    ) {
      if (e.isActive()) {
        names.add(e.getValue());
      }
    }
    return names;
  }

  /** One activity group for its page (public, or private if the user belongs). */
  @AuraEnabled(cacheable=true)
  public static GroupDTO getGroup(Id groupId) {
    if (groupId == null) {
      throw new AuraHandledException('A group id is required');
    }
    CollaborationGroup g = new GroupSelector().oneGroup(groupId);
    Boolean admin = isCurrentUserAdmin(groupId);
    if (
      g == null ||
      (g.CollaborationType != 'Public' &&
      !admin &&
      !isMember(groupId))
    ) {
      throw new AuraHandledException(
        'That group does not exist or you do not have access to it'
      );
    }
    GroupSelector sel = new GroupSelector();
    Id uid = UserInfo.getUserId();
    CollaborationGroupMember mine = sel.myMembership(groupId, uid);
    GroupDTO dto = new GroupDTO(g, coreGroupNames().contains(g.Name));
    dto.isAdmin = admin;
    dto.isMember = mine != null;
    dto.notificationFrequency = mine == null
      ? null
      : mine.NotificationFrequency;
    dto.hasPendingRequest =
      !dto.isMember && sel.hasPendingRequest(groupId, uid);
    return dto;
  }

  /**
   * Join a group: public groups join immediately; private groups create a
   * pending request for the admin to approve. Returns 'member' or 'requested'.
   */
  @AuraEnabled
  public static String joinGroup(Id groupId) {
    GroupSelector sel = new GroupSelector();
    CollaborationGroup g = sel.oneGroup(groupId);
    if (g == null) {
      throw new AuraHandledException('That group does not exist.');
    }
    Id uid = UserInfo.getUserId();
    if (sel.isMember(groupId, uid)) {
      return 'member';
    }
    if (g.CollaborationType == 'Public') {
      sel.addMember(groupId, uid);
      return 'member';
    }
    if (!sel.hasPendingRequest(groupId, uid)) {
      sel.addRequest(groupId, uid);
    }
    return 'requested';
  }

  /** Leave a group (removes the running user's membership). */
  @AuraEnabled
  public static void leaveGroup(Id groupId) {
    new GroupSelector().removeMembership(groupId, UserInfo.getUserId());
  }

  /**
   * Set the running member's email notification frequency for the group.
   * Values: 'P' each post, 'D' daily digest, 'W' weekly digest, 'N' never.
   * New members default to daily ('D') on join.
   */
  @AuraEnabled
  public static void setNotificationFrequency(Id groupId, String frequency) {
    if (!new Set<String>{ 'P', 'D', 'W', 'N' }.contains(frequency)) {
      throw new AuraHandledException('Invalid notification frequency.');
    }
    new GroupSelector().setFrequency(groupId, UserInfo.getUserId(), frequency);
  }

  /** The group's members + any pending join requests. Admin-only (management). */
  @AuraEnabled(cacheable=true)
  public static MemberList getMembers(Id groupId) {
    assertAdmin(groupId);
    GroupSelector sel = new GroupSelector();
    MemberList result = new MemberList();
    for (CollaborationGroupMember m : sel.membersOf(groupId)) {
      result.members.add(
        new MemberDTO(
          m.Id,
          m.MemberId,
          m.Member.Name,
          m.CollaborationRole == 'Admin'
        )
      );
    }
    for (CollaborationGroupMemberRequest r : sel.requestsOf(groupId)) {
      result.requests.add(
        new MemberDTO(r.Id, r.RequesterId, r.Requester.Name, false)
      );
    }
    return result;
  }

  /** Admin: update the group's description. */
  @AuraEnabled
  public static void updateGroupDescription(Id groupId, String description) {
    assertAdmin(groupId);
    CollaborationGroup g = [
      SELECT Id, Description
      FROM CollaborationGroup
      WHERE Id = :groupId
      LIMIT 1
    ];
    g.Description = description;
    update g;
  }

  /** Admin: remove a member (by their CollaborationGroupMember id). */
  @AuraEnabled
  public static void removeMember(Id memberRecordId) {
    CollaborationGroupMember m = [
      SELECT Id, CollaborationGroupId
      FROM CollaborationGroupMember
      WHERE Id = :memberRecordId
      LIMIT 1
    ];
    assertAdmin(m.CollaborationGroupId);
    delete m;
  }

  /** Admin: approve or decline a pending join request. */
  @AuraEnabled
  public static void setJoinRequestStatus(Id requestId, String status) {
    if (status != 'Accepted' && status != 'Declined') {
      throw new AuraHandledException('Status must be Accepted or Declined.');
    }
    CollaborationGroupMemberRequest r = [
      SELECT Id, CollaborationGroupId, Status
      FROM CollaborationGroupMemberRequest
      WHERE Id = :requestId
      LIMIT 1
    ];
    assertAdmin(r.CollaborationGroupId);
    r.Status = status;
    update r;
  }

  // ---- access checks ------------------------------------------------------

  /** True when the running user owns or is an Admin member of the group. */
  private static Boolean isCurrentUserAdmin(Id groupId) {
    return new GroupSelector().isAdmin(groupId, UserInfo.getUserId());
  }

  /** True when the running user belongs to the group. */
  private static Boolean isMember(Id groupId) {
    return new GroupSelector().isMember(groupId, UserInfo.getUserId());
  }

  private static void assertAdmin(Id groupId) {
    if (!isCurrentUserAdmin(groupId)) {
      throw new AuraHandledException('Only a group administrator can do that.');
    }
  }

  /**
   * Chatter scopes CollaborationGroup visibility to the running user's network,
   * which hides club groups from community members. These reads run `without
   * sharing` so the controller can apply its own public/member/admin rules.
   */
  private without sharing class GroupSelector {
    List<CollaborationGroup> visibleGroups() {
      Id uid = UserInfo.getUserId();
      Set<Id> mine = new Set<Id>();
      for (CollaborationGroupMember m : [
        SELECT CollaborationGroupId
        FROM CollaborationGroupMember
        WHERE MemberId = :uid
      ]) {
        mine.add(m.CollaborationGroupId);
      }
      return [
        SELECT Id, Name, Description, MemberCount, CollaborationType
        FROM CollaborationGroup
        WHERE CollaborationType = 'Public' OR Id IN :mine
        ORDER BY MemberCount DESC NULLS LAST, Name ASC
        LIMIT 200
      ];
    }

    CollaborationGroup oneGroup(Id groupId) {
      List<CollaborationGroup> g = [
        SELECT Id, Name, Description, MemberCount, CollaborationType
        FROM CollaborationGroup
        WHERE Id = :groupId
        LIMIT 1
      ];
      return g.isEmpty() ? null : g[0];
    }

    Boolean isAdmin(Id groupId, Id uid) {
      for (CollaborationGroup g : [
        SELECT OwnerId
        FROM CollaborationGroup
        WHERE Id = :groupId
        LIMIT 1
      ]) {
        if (g.OwnerId == uid) {
          return true;
        }
      }
      return ![
          SELECT Id
          FROM CollaborationGroupMember
          WHERE
            CollaborationGroupId = :groupId
            AND MemberId = :uid
            AND CollaborationRole = 'Admin'
          LIMIT 1
        ]
        .isEmpty();
    }

    Boolean isMember(Id groupId, Id uid) {
      return myMembership(groupId, uid) != null;
    }

    CollaborationGroupMember myMembership(Id groupId, Id uid) {
      List<CollaborationGroupMember> m = [
        SELECT Id, NotificationFrequency
        FROM CollaborationGroupMember
        WHERE CollaborationGroupId = :groupId AND MemberId = :uid
        LIMIT 1
      ];
      return m.isEmpty() ? null : m[0];
    }

    Boolean hasPendingRequest(Id groupId, Id uid) {
      return ![
          SELECT Id
          FROM CollaborationGroupMemberRequest
          WHERE
            CollaborationGroupId = :groupId
            AND RequesterId = :uid
            AND Status = 'Pending'
          LIMIT 1
        ]
        .isEmpty();
    }

    void addMember(Id groupId, Id uid) {
      // New members default to a daily digest (was weekly by default).
      insert new CollaborationGroupMember(
        CollaborationGroupId = groupId,
        MemberId = uid,
        NotificationFrequency = 'D'
      );
    }

    void addRequest(Id groupId, Id uid) {
      // Status isn't writable on insert; it defaults to 'Pending'.
      insert new CollaborationGroupMemberRequest(
        CollaborationGroupId = groupId,
        RequesterId = uid
      );
    }

    void removeMembership(Id groupId, Id uid) {
      List<CollaborationGroupMember> m = [
        SELECT Id
        FROM CollaborationGroupMember
        WHERE CollaborationGroupId = :groupId AND MemberId = :uid
      ];
      if (!m.isEmpty()) {
        delete m;
      }
    }

    void setFrequency(Id groupId, Id uid, String frequency) {
      CollaborationGroupMember m = myMembership(groupId, uid);
      if (m == null) {
        throw new AuraHandledException('You are not a member of this group.');
      }
      m.NotificationFrequency = frequency;
      update m;
    }

    List<CollaborationGroupMember> membersOf(Id groupId) {
      return [
        SELECT Id, MemberId, Member.Name, CollaborationRole
        FROM CollaborationGroupMember
        WHERE CollaborationGroupId = :groupId
        ORDER BY CollaborationRole, Member.Name
        LIMIT 1000
      ];
    }

    List<CollaborationGroupMemberRequest> requestsOf(Id groupId) {
      return [
        SELECT Id, RequesterId, Requester.Name
        FROM CollaborationGroupMemberRequest
        WHERE CollaborationGroupId = :groupId AND Status = 'Pending'
        ORDER BY Requester.Name
        LIMIT 1000
      ];
    }
  }

  public class GroupDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Integer memberCount;
    @AuraEnabled
    public Boolean isPublic;
    @AuraEnabled
    public Boolean isCore;
    @AuraEnabled
    public Boolean isAdmin = false;
    @AuraEnabled
    public Boolean isMember = false;
    @AuraEnabled
    public Boolean hasPendingRequest = false;
    @AuraEnabled
    public String notificationFrequency; // P/D/W/N, null when not a member

    public GroupDTO(CollaborationGroup g, Boolean isCore) {
      this.id = g.Id;
      this.name = g.Name;
      this.description = g.Description;
      this.memberCount = g.MemberCount == null ? 0 : g.MemberCount;
      this.isPublic = g.CollaborationType == 'Public';
      this.isCore = isCore;
    }
  }

  public class MemberList {
    @AuraEnabled
    public List<MemberDTO> members = new List<MemberDTO>();
    @AuraEnabled
    public List<MemberDTO> requests = new List<MemberDTO>();
  }

  public class MemberDTO {
    @AuraEnabled
    public Id recordId; // CollaborationGroupMember or ...MemberRequest id
    @AuraEnabled
    public Id userId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Boolean isAdmin;

    public MemberDTO(Id recordId, Id userId, String name, Boolean isAdmin) {
      this.recordId = recordId;
      this.userId = userId;
      this.name = name;
      this.isAdmin = isAdmin;
    }
  }
}
