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
    return new GroupDTO(groups[0], coreGroupNames().contains(groups[0].Name));
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

    public GroupDTO(CollaborationGroup g, Boolean isCore) {
      this.id = g.Id;
      this.name = g.Name;
      this.description = g.Description;
      this.memberCount = g.MemberCount == null ? 0 : g.MemberCount;
      this.isPublic = g.CollaborationType == 'Public';
      this.isCore = isCore;
    }
  }
}
