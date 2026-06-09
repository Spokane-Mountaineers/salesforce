/**
 * Controller for the LWR events surfaces (plan §5): a custom calendar/list bound
 * directly to Event_Registration__c (the event), event detail, and the RSVP
 * rebuild that writes Event_Participant__c (replacing the Aura
 * Community_Event_Registration_Screen_Flow — the migration's highest-coupling
 * piece, plan §6.3).
 *
 * The RSVP rules (event must be Approved, must accept RSVPs, capacity, no
 * duplicate) live in applyRsvp, exposed @TestVisible so the full contract can be
 * tested with a seeded Contact without standing up a community user.
 */
public with sharing class EventController {
  /**
   * Approved events overlapping [rangeStart, rangeEnd], for the calendar/list.
   * @param activityGroup optional Activity_Group__c filter
   */
  @AuraEnabled(cacheable=true)
  public static List<EventDTO> getEvents(
    Datetime rangeStart,
    Datetime rangeEnd,
    String activityGroup
  ) {
    if (rangeStart == null || rangeEnd == null) {
      throw new AuraHandledException('A start and end date range is required');
    }
    String soql =
      'SELECT Id, Name, Activity_Group__c, Start__c, End__c, Location__c, ' +
      'Leader__c, Leader__r.Name, Registration_Type__c, Limit_of_Attendees__c, ' +
      'Number_Attending__c, Public__c, Status__c ' +
      'FROM Event_Registration__c ' +
      'WHERE Status__c = \'Approved\' AND Start__c < :rangeEnd ' +
      'AND End__c >= :rangeStart';
    if (String.isNotBlank(activityGroup)) {
      soql += ' AND Activity_Group__c = :activityGroup';
    }
    soql += ' ORDER BY Start__c ASC LIMIT 1000';

    List<EventDTO> events = new List<EventDTO>();
    for (Event_Registration__c e : Database.query(soql)) {
      events.add(new EventDTO(e));
    }
    return events;
  }

  /** One event for the detail page, including the running member's RSVP. */
  @AuraEnabled(cacheable=true)
  public static EventDTO getEvent(Id eventId) {
    if (eventId == null) {
      throw new AuraHandledException('An event id is required');
    }
    List<Event_Registration__c> events = [
      SELECT
        Id,
        Name,
        Activity_Group__c,
        Description__c,
        Event_Pre_Requisites__c,
        Start__c,
        End__c,
        Location__c,
        Leader__c,
        Leader__r.Name,
        Registration_Type__c,
        Limit_of_Attendees__c,
        Number_Attending__c,
        Public__c,
        Status__c
      FROM Event_Registration__c
      WHERE Id = :eventId
      LIMIT 1
    ];
    if (events.isEmpty()) {
      throw new AuraHandledException(
        'That event does not exist or you do not have access to it'
      );
    }
    EventDTO dto = new EventDTO(events[0]);
    Id contactId = currentContactId();
    if (contactId != null) {
      dto.attendingCount = attendingCount(eventId);
      for (Event_Participant__c p : [
        SELECT Response__c
        FROM Event_Participant__c
        WHERE Event_Registration__c = :eventId AND Contact__c = :contactId
        LIMIT 1
      ]) {
        dto.myResponse = p.Response__c;
      }
    }
    return dto;
  }

  /** Events the running member is attending, upcoming first. */
  @AuraEnabled(cacheable=true)
  public static List<EventDTO> getMyRegistrations() {
    Id contactId = currentContactId();
    if (contactId == null) {
      return new List<EventDTO>();
    }
    List<EventDTO> events = new List<EventDTO>();
    for (Event_Participant__c p : [
      SELECT
        Event_Registration__r.Id,
        Event_Registration__r.Name,
        Event_Registration__r.Activity_Group__c,
        Event_Registration__r.Start__c,
        Event_Registration__r.End__c,
        Event_Registration__r.Location__c,
        Event_Registration__r.Leader__r.Name,
        Event_Registration__r.Registration_Type__c,
        Event_Registration__r.Limit_of_Attendees__c,
        Event_Registration__r.Number_Attending__c,
        Event_Registration__r.Public__c,
        Event_Registration__r.Status__c
      FROM Event_Participant__c
      WHERE
        Contact__c = :contactId
        AND Response__c = 'Attending'
        AND Event_Registration__r.End__c >= :Datetime.now()
      ORDER BY Event_Registration__r.Start__c ASC
    ]) {
      events.add(new EventDTO(p.Event_Registration__r));
    }
    return events;
  }

  /** RSVP for the running member. attending=false cancels. */
  @AuraEnabled
  public static RsvpResult rsvp(Id eventId, Boolean attending) {
    Id contactId = currentContactId();
    if (contactId == null) {
      throw new AuraHandledException(
        'Your account is not linked to a member contact, so you cannot RSVP.'
      );
    }
    return applyRsvp(eventId, contactId, attending);
  }

  /**
   * The RSVP contract (plan §6.3). Validates the event accepts RSVPs and is
   * Approved, enforces capacity on a new Attending RSVP, and is idempotent
   * (updates the member's existing participant rather than duplicating).
   */
  @TestVisible
  private static RsvpResult applyRsvp(
    Id eventId,
    Id contactId,
    Boolean attending
  ) {
    Event_Registration__c event = [
      SELECT
        Id,
        Name,
        Start__c,
        End__c,
        Location__c,
        Registration_Type__c,
        Limit_of_Attendees__c,
        Status__c
      FROM Event_Registration__c
      WHERE Id = :eventId
      LIMIT 1
    ];
    if (event.Status__c != 'Approved') {
      throw new AuraHandledException(
        'This event is not open for registration yet.'
      );
    }
    if (event.Registration_Type__c == 'No RSVP') {
      throw new AuraHandledException('This event does not take RSVPs.');
    }

    List<Event_Participant__c> existing = [
      SELECT Id, Response__c
      FROM Event_Participant__c
      WHERE Event_Registration__c = :eventId AND Contact__c = :contactId
      LIMIT 1
    ];
    Boolean alreadyAttending =
      !existing.isEmpty() && existing[0].Response__c == 'Attending';

    if (attending && !alreadyAttending) {
      Decimal cap = event.Limit_of_Attendees__c;
      if (cap != null && cap > 0 && attendingCount(eventId) >= cap) {
        throw new AuraHandledException(
          'This event is full (' + cap.intValue() + ' spots).'
        );
      }
    }

    Event_Participant__c participant = existing.isEmpty()
      ? new Event_Participant__c(
          Event_Registration__c = eventId,
          Contact__c = contactId
        )
      : existing[0];
    participant.Response__c = attending ? 'Attending' : 'Not Attending';
    // Event_Name__c / Start__c / End__c / Location__c are denormalized by the
    // existing EventParticipantTrigger from the parent — read-only here.
    upsert participant;

    RsvpResult result = new RsvpResult();
    result.participantId = participant.Id;
    result.response = participant.Response__c;
    result.attendingCount = attendingCount(eventId);
    return result;
  }

  private static Integer attendingCount(Id eventId) {
    return [
      SELECT COUNT()
      FROM Event_Participant__c
      WHERE Event_Registration__c = :eventId AND Response__c = 'Attending'
    ];
  }

  private static Id currentContactId() {
    User u = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()];
    return u.ContactId;
  }

  /** Calendar/list/detail shape bound by the LWCs. */
  public class EventDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String activityGroup;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public String prerequisites;
    @AuraEnabled
    public Datetime startTime;
    @AuraEnabled
    public Datetime endTime;
    @AuraEnabled
    public String location;
    @AuraEnabled
    public String leaderName;
    @AuraEnabled
    public String registrationType;
    @AuraEnabled
    public Decimal limitOfAttendees;
    @AuraEnabled
    public Decimal numberAttending;
    @AuraEnabled
    public Integer attendingCount;
    @AuraEnabled
    public Boolean isPublic;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String myResponse;

    public EventDTO(Event_Registration__c e) {
      this.id = e.Id;
      this.name = e.Name;
      this.activityGroup = e.Activity_Group__c;
      this.startTime = e.Start__c;
      this.endTime = e.End__c;
      this.location = e.Location__c;
      this.leaderName = e.Leader__r != null ? e.Leader__r.Name : null;
      this.registrationType = e.Registration_Type__c;
      this.limitOfAttendees = e.Limit_of_Attendees__c;
      this.numberAttending = e.Number_Attending__c;
      this.isPublic = e.Public__c;
      this.status = e.Status__c;
      // Detail-only fields; guarded so list queries that omit them don't break.
      if (e.isSet(Event_Registration__c.Description__c)) {
        this.description = e.Description__c;
      }
      if (e.isSet(Event_Registration__c.Event_Pre_Requisites__c)) {
        this.prerequisites = e.Event_Pre_Requisites__c;
      }
    }
  }

  public class RsvpResult {
    @AuraEnabled
    public Id participantId;
    @AuraEnabled
    public String response;
    @AuraEnabled
    public Integer attendingCount;
  }
}
