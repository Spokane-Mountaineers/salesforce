@isTest
private class ActivityGroupControllerTest {
  // CollaborationGroup names are unique org-wide and that uniqueness is enforced
  // even in tests, so use names that won't collide with real club groups.
  @testSetup
  static void setup() {
    insert new List<CollaborationGroup>{
      new CollaborationGroup(
        Name = 'SMTestAlpha Group',
        CollaborationType = 'Public'
      ),
      new CollaborationGroup(
        Name = 'SMTestBravo Group',
        CollaborationType = 'Private'
      )
    };
  }

  @isTest
  static void getGroups_returnsVisibleGroups() {
    Test.startTest();
    List<ActivityGroupController.GroupDTO> groups = ActivityGroupController.getGroups();
    Test.stopTest();
    System.assert(!groups.isEmpty(), 'expected at least one group');
    Boolean foundAlpha = false;
    for (ActivityGroupController.GroupDTO g : groups) {
      if (g.name == 'SMTestAlpha Group') {
        foundAlpha = true;
        System.assertEquals(true, g.isPublic, 'Alpha is public');
        // A bespoke name isn't an Activity_Group__c picklist value -> not core.
        System.assertEquals(false, g.isCore, 'bespoke group is not core');
      }
    }
    System.assert(foundAlpha, 'the public test group should be listed');
  }

  @isTest
  static void getGroup_returnsOneAndMarksOwnerAdmin() {
    CollaborationGroup g = [
      SELECT Id
      FROM CollaborationGroup
      WHERE Name = 'SMTestAlpha Group'
      LIMIT 1
    ];
    Test.startTest();
    ActivityGroupController.GroupDTO dto = ActivityGroupController.getGroup(
      g.Id
    );
    Test.stopTest();
    System.assertEquals('SMTestAlpha Group', dto.name);
    System.assertEquals(g.Id, dto.id);
    System.assertEquals(true, dto.isAdmin, 'owner should be a group admin');
  }

  @isTest
  static void getGroup_nullThrows() {
    Test.startTest();
    try {
      ActivityGroupController.getGroup(null);
      System.assert(false, 'expected an exception');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @isTest
  static void updateGroupDescription_setsIt() {
    CollaborationGroup g = [
      SELECT Id
      FROM CollaborationGroup
      WHERE Name = 'SMTestAlpha Group'
      LIMIT 1
    ];
    Test.startTest();
    ActivityGroupController.updateGroupDescription(g.Id, 'Rock and alpine.');
    Test.stopTest();
    System.assertEquals(
      'Rock and alpine.',
      [SELECT Description FROM CollaborationGroup WHERE Id = :g.Id].Description
    );
  }

  @isTest
  static void getMembers_returnsOwnerAdmin() {
    CollaborationGroup g = [
      SELECT Id
      FROM CollaborationGroup
      WHERE Name = 'SMTestAlpha Group'
      LIMIT 1
    ];
    Test.startTest();
    ActivityGroupController.MemberList ml = ActivityGroupController.getMembers(
      g.Id
    );
    Test.stopTest();
    System.assert(!ml.members.isEmpty(), 'owner should be a member');
    Boolean ownerIsAdmin = false;
    for (ActivityGroupController.MemberDTO m : ml.members) {
      if (m.userId == UserInfo.getUserId() && m.isAdmin) {
        ownerIsAdmin = true;
      }
    }
    System.assert(ownerIsAdmin, 'owner should be listed as an admin member');
  }

  @isTest
  static void setJoinRequestStatus_rejectsBadStatus() {
    Test.startTest();
    try {
      ActivityGroupController.setJoinRequestStatus(null, 'Maybe');
      System.assert(false, 'expected an exception for an invalid status');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @isTest
  static void updateDescription_nonAdminBlocked() {
    CollaborationGroup g = [
      SELECT Id
      FROM CollaborationGroup
      WHERE Name = 'SMTestAlpha Group'
      LIMIT 1
    ];
    User stranger = buildStandardUser();
    System.runAs(stranger) {
      Test.startTest();
      try {
        ActivityGroupController.updateGroupDescription(g.Id, 'nope');
        System.assert(false, 'a non-admin should be blocked');
      } catch (Exception e) {
        System.assert(true);
      }
      Test.stopTest();
    }
  }

  static User buildStandardUser() {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User u = new User(
      FirstName = 'Strato',
      LastName = 'Volcano',
      Email = 'strato.volcano@example.com',
      Username = 'strato.volcano.' +
        System.currentTimeMillis() +
        '@example.com.smitest',
      Alias = 'svol',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert u;
    return u;
  }
}
