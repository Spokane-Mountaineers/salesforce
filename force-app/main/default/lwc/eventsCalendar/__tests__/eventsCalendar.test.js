import { createElement } from "lwc";
import EventsCalendar from "c/eventsCalendar";
import getEvents from "@salesforce/apex/EventController.getEvents";

jest.mock(
  "@salesforce/apex/EventController.getEvents",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

function mount() {
  const el = createElement("c-events-calendar", { is: EventsCalendar });
  document.body.appendChild(el);
  return el;
}
const flush = () => Promise.resolve();

describe("c-events-calendar", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders a 6-week grid with weekday headers", async () => {
    const el = mount();
    getEvents.emit([]);
    await flush();
    expect(el.shadowRoot.querySelectorAll(".weekday").length).toBe(7);
    expect(el.shadowRoot.querySelectorAll(".cell").length).toBe(42);
  });

  it("places an event chip on its start day that links to the detail page", async () => {
    const el = mount();
    const today = new Date();
    getEvents.emit([
      {
        id: "a12X",
        name: "Wed Night Hike",
        startTime: today.toISOString(),
        isPublic: true
      }
    ]);
    await flush();

    const chips = el.shadowRoot.querySelectorAll(".ev");
    expect(chips.length).toBe(1);
    expect(chips[0].textContent.trim()).toBe("Wed Night Hike");
    expect(chips[0].className).toContain("ev--public");
    // basePath is auto-mocked to "" by sfdx-lwc-jest.
    expect(chips[0].getAttribute("href")).toBe("/event?recordId=a12X");
  });

  it("changes the month label when navigating", async () => {
    const el = mount();
    getEvents.emit([]);
    await flush();
    const before = el.shadowRoot.querySelector(".cal__title").textContent;
    el.shadowRoot.querySelector(".navbtn[aria-label='Next month']").click();
    await flush();
    const after = el.shadowRoot.querySelector(".cal__title").textContent;
    expect(after).not.toBe(before);
  });

  it("surfaces a wire error", async () => {
    const el = mount();
    getEvents.error({ message: "nope" });
    await flush();
    expect(el.shadowRoot.querySelector(".cal__error").textContent).toContain(
      "nope"
    );
  });
});
