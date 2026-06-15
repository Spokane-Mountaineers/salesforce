@isTest
private class ActivityGroupControllerTest {
  @testSetup
  static void setup() {
    insert new List<CollaborationGroup>{
      new CollaborationGroup(Name = 'Climbing', CollaborationType = 'Public'),
      new CollaborationGroup(
        Name = 'Hiking Leaders',
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
    Boolean foundClimbing = false;
    for (ActivityGroupController.GroupDTO g : groups) {
      if (g.name == 'Climbing') {
        foundClimbing = true;
        System.assertEquals(true, g.isPublic, 'Climbing is a public group');
        // "Climbing" is an Activity_Group__c picklist value -> a core group.
        System.assertEquals(true, g.isCore, 'Climbing should be a core group');
      }
      if (g.name == 'Hiking Leaders') {
        System.assertEquals(
          false,
          g.isCore,
          'a bespoke group is not a core group'
        );
      }
    }
    System.assert(foundClimbing, 'public Climbing group should be listed');
  }

  @isTest
  static void getGroup_returnsOne() {
    CollaborationGroup g = [
      SELECT Id
      FROM CollaborationGroup
      WHERE Name = 'Climbing'
      LIMIT 1
    ];
    Test.startTest();
    ActivityGroupController.GroupDTO dto = ActivityGroupController.getGroup(
      g.Id
    );
    Test.stopTest();
    System.assertEquals('Climbing', dto.name);
    System.assertEquals(g.Id, dto.id);
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
}
