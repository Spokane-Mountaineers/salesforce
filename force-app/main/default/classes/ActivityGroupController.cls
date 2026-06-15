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
  /** Visible activity groups for the directory, busiest first. */
  @AuraEnabled(cacheable=true)
  public static List<GroupDTO> getGroups() {
    Set<String> core = coreGroupNames();
    List<GroupDTO> groups = new List<GroupDTO>();
    for (CollaborationGroup g : [
      SELECT Id, Name, Description, MemberCount, CollaborationType
      FROM CollaborationGroup
      ORDER BY MemberCount DESC NULLS LAST, Name ASC
      LIMIT 200
    ]) {
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

  /** One activity group for its page. */
  @AuraEnabled(cacheable=true)
  public static GroupDTO getGroup(Id groupId) {
    if (groupId == null) {
      throw new AuraHandledException('A group id is required');
    }
    List<CollaborationGroup> groups = [
      SELECT Id, Name, Description, MemberCount, CollaborationType
      FROM CollaborationGroup
      WHERE Id = :groupId
      LIMIT 1
    ];
    if (groups.isEmpty()) {
      throw new AuraHandledException(
        'That group does not exist or you do not have access to it'
      );
    }
    GroupDTO dto = new GroupDTO(
      groups[0],
      coreGroupNames().contains(groups[0].Name)
    );
    dto.isAdmin = isCurrentUserAdmin(groupId);
    return dto;
  }

  /** The group's members + any pending join requests. Admin-only (management). */
  @AuraEnabled(cacheable=true)
  public static MemberList getMembers(Id groupId) {
    assertAdmin(groupId);
    MemberList result = new MemberList();
    for (CollaborationGroupMember m : [
      SELECT Id, MemberId, Member.Name, CollaborationRole
      FROM CollaborationGroupMember
      WHERE CollaborationGroupId = :groupId
      ORDER BY CollaborationRole, Member.Name
      LIMIT 1000
    ]) {
      result.members.add(
        new MemberDTO(
          m.Id,
          m.MemberId,
          m.Member.Name,
          m.CollaborationRole == 'Admin'
        )
      );
    }
    for (CollaborationGroupMemberRequest r : [
      SELECT Id, RequesterId, Requester.Name
      FROM CollaborationGroupMemberRequest
      WHERE CollaborationGroupId = :groupId AND Status = 'Pending'
      ORDER BY Requester.Name
      LIMIT 1000
    ]) {
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

  // ---- admin checks -------------------------------------------------------

  /** True when the running user owns or is an Admin member of the group. */
  private static Boolean isCurrentUserAdmin(Id groupId) {
    Id uid = UserInfo.getUserId();
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

  private static void assertAdmin(Id groupId) {
    if (!isCurrentUserAdmin(groupId)) {
      throw new AuraHandledException('Only a group administrator can do that.');
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
