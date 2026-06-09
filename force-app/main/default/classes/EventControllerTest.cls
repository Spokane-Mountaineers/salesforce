/**
 * Contract tests for EventController (plan §6.3): the rebuilt RSVP rules
 * (Approved gate, RSVP-type gate, capacity, idempotency, cancel) plus the
 * calendar/list/detail reads. RSVP is driven through the @TestVisible
 * applyRsvp(eventId, contactId, …) seam with seeded Contacts, so the full
 * contract is covered without standing up a community user.
 */
@isTest
private class EventControllerTest {
  private static Event_Registration__c makeEvent(
    String name,
    String activityGroup,
    String regType,
    Decimal limitAttendees,
    Datetime startAt
  ) {
    return new Event_Registration__c(
      Name = name,
      Activity_Group__c = activityGroup,
      Registration_Type__c = regType,
      Limit_of_Attendees__c = limitAttendees,
      Status__c = 'Approved',
      Public__c = false,
      Start__c = startAt,
      End__c = startAt.addHours(3)
    );
  }

  // On insert the Submit_for_Approval_on_Create flow moves Status to Submitted;
  // a follow-up update to Approved sticks. Yields a deterministically Approved
  // event for the RSVP/calendar tests.
  private static Event_Registration__c createApproved(
    String name,
    String activityGroup,
    String regType,
    Decimal limitAttendees,
    Datetime startAt
  ) {
    Event_Registration__c e = makeEvent(
      name,
      activityGroup,
      regType,
      limitAttendees,
      startAt
    );
    insert e;
    e.Status__c = 'Approved';
    update e;
    return e;
  }

  private static Contact makeContact(String last) {
    return new Contact(FirstName = 'Test', LastName = last);
  }

  @isTest
  static void rsvp_happyPath_createsAttendingParticipant() {
    Event_Registration__c e = createApproved(
      'Deep Creek',
      'Hiking',
      'RSVP Required',
      5,
      Datetime.now().addDays(3)
    );
    Contact c = makeContact('Alpha');
    insert c;

    Test.startTest();
    EventController.RsvpResult r = EventController.applyRsvp(e.Id, c.Id, true);
    Test.stopTest();

    System.assertEquals('Attending', r.response);
    System.assertEquals(1, r.attendingCount);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Event_Participant__c
        WHERE Event_Registration__c = :e.Id AND Contact__c = :c.Id
      ]
    );
  }

  @isTest
  static void rsvp_isIdempotent_noDuplicateParticipant() {
    Event_Registration__c e = createApproved(
      'Repeat',
      'Hiking',
      'RSVP Required',
      5,
      Datetime.now().addDays(3)
    );
    Contact c = makeContact('Beta');
    insert c;

    EventController.applyRsvp(e.Id, c.Id, true);
    EventController.applyRsvp(e.Id, c.Id, true);

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Event_Participant__c
        WHERE Event_Registration__c = :e.Id AND Contact__c = :c.Id
      ],
      'Re-RSVP must update, not duplicate'
    );
  }

  @isTest
  static void rsvp_atCapacity_throws() {
    Event_Registration__c e = createApproved(
      'Tiny',
      'Hiking',
      'RSVP Required',
      1,
      Datetime.now().addDays(3)
    );
    Contact first = makeContact('First');
    Contact second = makeContact('Second');
    insert new List<Contact>{ first, second };

    EventController.applyRsvp(e.Id, first.Id, true);
    try {
      EventController.applyRsvp(e.Id, second.Id, true);
      System.assert(false, 'Expected a capacity exception');
    } catch (AuraHandledException ex) {
      System.assert(true);
    }
  }

  @isTest
  static void rsvp_zeroLimitMeansUnlimited() {
    Event_Registration__c e = createApproved(
      'Big',
      'Hiking',
      'RSVP Optional',
      0,
      Datetime.now().addDays(3)
    );
    Contact a = makeContact('A');
    Contact b = makeContact('B');
    insert new List<Contact>{ a, b };

    EventController.applyRsvp(e.Id, a.Id, true);
    EventController.RsvpResult r = EventController.applyRsvp(e.Id, b.Id, true);
    System.assertEquals(2, r.attendingCount, 'Limit 0 = unlimited');
  }

  @isTest
  static void rsvp_notApproved_throws() {
    // Inserted (not updated to Approved) → the create flow leaves it Submitted.
    Event_Registration__c e = makeEvent(
      'Pending',
      'Hiking',
      'RSVP Required',
      5,
      Datetime.now().addDays(3)
    );
    insert e;
    Contact c = makeContact('Gamma');
    insert c;
    try {
      EventController.applyRsvp(e.Id, c.Id, true);
      System.assert(false, 'Expected a not-open exception');
    } catch (AuraHandledException ex) {
      System.assert(true);
    }
  }

  @isTest
  static void rsvp_noRsvpType_throws() {
    Event_Registration__c e = createApproved(
      'Show up',
      'Hiking',
      'No RSVP',
      0,
      Datetime.now().addDays(3)
    );
    Contact c = makeContact('Delta');
    insert c;
    try {
      EventController.applyRsvp(e.Id, c.Id, true);
      System.assert(false, 'Expected a no-RSVP exception');
    } catch (AuraHandledException ex) {
      System.assert(true);
    }
  }

  @isTest
  static void rsvp_cancelFreesCapacity() {
    Event_Registration__c e = createApproved(
      'One spot',
      'Hiking',
      'RSVP Required',
      1,
      Datetime.now().addDays(3)
    );
    Contact a = makeContact('A');
    Contact b = makeContact('B');
    insert new List<Contact>{ a, b };

    EventController.applyRsvp(e.Id, a.Id, true);
    EventController.applyRsvp(e.Id, a.Id, false); // cancel
    EventController.RsvpResult r = EventController.applyRsvp(e.Id, b.Id, true);
    System.assertEquals('Attending', r.response, 'Freed spot can be taken');
    System.assertEquals(1, r.attendingCount);
  }

  @isTest
  static void getEvents_returnsApprovedInRange() {
    createApproved(
      'In range',
      'Hiking',
      'RSVP Optional',
      0,
      Datetime.now().addDays(2)
    );
    createApproved(
      'Far future',
      'Hiking',
      'RSVP Optional',
      0,
      Datetime.now().addDays(60)
    );

    Test.startTest();
    List<EventController.EventDTO> events = EventController.getEvents(
      Datetime.now(),
      Datetime.now().addDays(7),
      null
    );
    Test.stopTest();

    Set<String> names = new Set<String>();
    for (EventController.EventDTO d : events) {
      names.add(d.name);
    }
    System.assert(names.contains('In range'), 'In-range event missing');
    System.assert(!names.contains('Far future'), 'Out-of-range leaked');
  }

  @isTest
  static void getEvents_filtersByActivityGroup() {
    createApproved(
      'Climb day',
      'Climbing',
      'RSVP Optional',
      0,
      Datetime.now().addDays(2)
    );
    createApproved(
      'Hike day',
      'Hiking',
      'RSVP Optional',
      0,
      Datetime.now().addDays(2)
    );

    List<EventController.EventDTO> events = EventController.getEvents(
      Datetime.now(),
      Datetime.now().addDays(7),
      'Climbing'
    );
    System.assertEquals(1, events.size());
    System.assertEquals('Climb day', events[0].name);
  }

  @isTest
  static void getEvent_returnsDtoWithDetail() {
    Event_Registration__c e = createApproved(
      'Detail day',
      'Climbing',
      'RSVP Required',
      5,
      Datetime.now().addDays(2)
    );
    Test.startTest();
    EventController.EventDTO dto = EventController.getEvent(e.Id);
    Test.stopTest();
    System.assertEquals('Detail day', dto.name);
    System.assertEquals('Climbing', dto.activityGroup);
    System.assertEquals('RSVP Required', dto.registrationType);
    System.assertEquals('Approved', dto.status);
  }

  @isTest
  static void getEvent_missingIdThrows() {
    try {
      EventController.getEvent('a12000000000000AAA');
      System.assert(false, 'Expected a not-found exception');
    } catch (Exception ex) {
      System.assert(true);
    }
  }

  @isTest
  static void getEvent_nullThrows() {
    try {
      EventController.getEvent(null);
      System.assert(false, 'Expected an exception');
    } catch (AuraHandledException ex) {
      System.assert(true);
    }
  }

  @isTest
  static void getMyRegistrations_emptyWithoutContact() {
    // The running admin user has no linked Contact → no registrations, no error.
    System.assertEquals(0, EventController.getMyRegistrations().size());
  }
}
