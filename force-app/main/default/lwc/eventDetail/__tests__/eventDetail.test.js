import { createElement } from "lwc";
import EventDetail from "c/eventDetail";
import getEvent from "@salesforce/apex/EventController.getEvent";
import rsvp from "@salesforce/apex/EventController.rsvp";

jest.mock(
  "@salesforce/apex/EventController.getEvent",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/EventController.rsvp",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);

const EVENT = {
  id: "a12X",
  name: "Beacon Practice",
  activityGroup: "Climbing",
  startTime: "2026-07-01T17:00:00.000Z",
  location: "Beacon Rock",
  leaderName: "Jane Leader",
  registrationType: "RSVP Required",
  limitOfAttendees: 3,
  attendingCount: 1,
  myResponse: null
};

function mount(props = {}) {
  const el = createElement("c-event-detail", { is: EventDetail });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}
const flush = () => Promise.resolve();

describe("c-event-detail", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders details and a primary RSVP button when not attending", async () => {
    const el = mount({ eventId: "a12X" });
    getEvent.emit(EVENT);
    await flush();
    expect(el.shadowRoot.querySelector(".title").textContent).toBe(
      "Beacon Practice"
    );
    const btn = el.shadowRoot.querySelector(".rsvp button");
    expect(btn.textContent.trim()).toContain("RSVP");
    expect(btn.className).toContain("smi-btn--primary");
  });

  it("RSVPs, flips to attending, and shows a confirmation", async () => {
    rsvp.mockResolvedValue({ response: "Attending", attendingCount: 2 });
    const el = mount({ eventId: "a12X" });
    getEvent.emit(EVENT);
    await flush();

    el.shadowRoot.querySelector(".rsvp button").click();
    await flush();
    await flush();

    expect(rsvp).toHaveBeenCalledWith({ eventId: "a12X", attending: true });
    const btn = el.shadowRoot.querySelector(".rsvp button");
    expect(btn.textContent.trim()).toBe("Cancel RSVP");
    expect(el.shadowRoot.querySelector(".message").textContent).toContain(
      "list"
    );
  });

  it("shows a full message instead of the button when at capacity", async () => {
    const el = mount({ eventId: "a12X" });
    getEvent.emit({ ...EVENT, attendingCount: 3 });
    await flush();
    expect(el.shadowRoot.querySelector(".full")).not.toBeNull();
    expect(el.shadowRoot.querySelector(".rsvp button")).toBeNull();
  });

  it("hides the RSVP section for No RSVP events", async () => {
    const el = mount({ eventId: "a12X" });
    getEvent.emit({ ...EVENT, registrationType: "No RSVP" });
    await flush();
    expect(el.shadowRoot.querySelector(".rsvp")).toBeNull();
  });

  it("surfaces a server error from the wire", async () => {
    const el = mount({ eventId: "bad" });
    getEvent.error({ message: "gone" });
    await flush();
    expect(el.shadowRoot.querySelector(".error").textContent).toContain("gone");
  });
});
