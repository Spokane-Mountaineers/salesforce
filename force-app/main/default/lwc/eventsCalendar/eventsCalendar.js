import { LightningElement, track, wire } from "lwc";
import getEvents from "@salesforce/apex/EventController.getEvents";

// Custom LWR month calendar bound directly to Event_Registration__c (plan §5.3):
// LWR has no stock calendar, so this is a forced rebuild — and binding straight
// to the event object is what lets the legacy standard-Event mirror be retired
// (§5.2). Renders a 6-week grid; events sit on their start day. Selecting one
// emits `eventselect` with the event id.
const DAY_MS = 24 * 60 * 60 * 1000;
const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTHS = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December"
];

export default class EventsCalendar extends LightningElement {
  @track viewYear;
  @track viewMonth; // 0-based
  @track activityGroup = "";

  events = [];
  error;

  connectedCallback() {
    const now = new Date();
    this.viewYear = now.getFullYear();
    this.viewMonth = now.getMonth();
  }

  // First cell = the Sunday on/before the 1st of the month.
  get gridStart() {
    const first = new Date(this.viewYear, this.viewMonth, 1);
    return new Date(first.getTime() - first.getDay() * DAY_MS);
  }

  // 42 days (6 weeks) covers any month layout.
  get rangeStart() {
    return this.gridStart.toISOString();
  }

  get rangeEnd() {
    return new Date(this.gridStart.getTime() + 42 * DAY_MS).toISOString();
  }

  @wire(getEvents, {
    rangeStart: "$rangeStart",
    rangeEnd: "$rangeEnd",
    activityGroup: "$activityGroup"
  })
  wiredEvents({ data, error }) {
    if (data) {
      this.events = data;
      this.error = undefined;
    } else if (error) {
      this.error = error?.body?.message || "Could not load events.";
      this.events = [];
    }
  }

  get monthLabel() {
    return `${MONTHS[this.viewMonth]} ${this.viewYear}`;
  }

  get weekdays() {
    return WEEKDAYS;
  }

  // Group events by their start day (local) as YYYY-M-D keys.
  get eventsByDay() {
    const map = {};
    for (const e of this.events) {
      if (!e.startTime) continue;
      const d = new Date(e.startTime);
      const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
      (map[key] = map[key] || []).push(e);
    }
    return map;
  }

  get weeks() {
    const byDay = this.eventsByDay;
    const today = new Date();
    const todayKey = `${today.getFullYear()}-${today.getMonth()}-${today.getDate()}`;
    const start = this.gridStart;
    const weeks = [];
    for (let w = 0; w < 6; w++) {
      const days = [];
      for (let d = 0; d < 7; d++) {
        const date = new Date(start.getTime() + (w * 7 + d) * DAY_MS);
        const key = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
        const inMonth = date.getMonth() === this.viewMonth;
        let cls = "cell";
        if (!inMonth) cls += " cell--muted";
        if (key === todayKey) cls += " cell--today";
        days.push({
          key,
          day: date.getDate(),
          cls,
          events: (byDay[key] || []).map((e) => ({
            id: e.id,
            name: e.name,
            cls: e.isPublic ? "ev ev--public" : "ev"
          }))
        });
      }
      weeks.push({ key: `w${w}`, days });
    }
    return weeks;
  }

  get hasError() {
    return Boolean(this.error);
  }

  previousMonth() {
    if (this.viewMonth === 0) {
      this.viewMonth = 11;
      this.viewYear -= 1;
    } else {
      this.viewMonth -= 1;
    }
  }

  nextMonth() {
    if (this.viewMonth === 11) {
      this.viewMonth = 0;
      this.viewYear += 1;
    } else {
      this.viewMonth += 1;
    }
  }

  today() {
    const now = new Date();
    this.viewYear = now.getFullYear();
    this.viewMonth = now.getMonth();
  }

  handleSelect(event) {
    const id = event.currentTarget.dataset.id;
    this.dispatchEvent(new CustomEvent("eventselect", { detail: { id } }));
  }
}
