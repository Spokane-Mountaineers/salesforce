import { createElement } from "lwc";
import BasecampDashboard from "c/basecampDashboard";
import getMyRegistrations from "@salesforce/apex/EventController.getMyRegistrations";
import getPublishedPosts from "@salesforce/apex/ContentPostController.getPublishedPosts";
import { getRecord } from "lightning/uiRecordApi";

jest.mock(
  "@salesforce/apex/EventController.getMyRegistrations",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ContentPostController.getPublishedPosts",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "lightning/uiRecordApi",
  () => {
    const { createLdsTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      getRecord: createLdsTestWireAdapter(jest.fn()),
      // The component only reads User.FirstName; return it directly rather than
      // depend on the @salesforce/schema mock shape.
      getFieldValue: (record) => {
        const f = record && record.fields && record.fields.FirstName;
        return f ? f.value : undefined;
      }
    };
  },
  { virtual: true }
);

function mount(props = {}) {
  const el = createElement("c-basecamp-dashboard", { is: BasecampDashboard });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}
const flush = () => Promise.resolve();

const REGS = [
  {
    id: "a12A",
    name: "Beacon Practice",
    activityGroup: "Climbing",
    startTime: "2026-07-01T17:00:00.000Z",
    location: "Beacon"
  }
];
const POSTS = [
  { id: "p1", title: "Trip one", activity: "Hiking", location: "Spokane" },
  { id: "p2", title: "Trip two", activity: "Climbing", location: "" },
  { id: "p3", title: "Trip three", activity: "Skiing", location: "" },
  { id: "p4", title: "Trip four", activity: "Paddling", location: "" },
  { id: "p5", title: "Trip five (overflow)", activity: "Social", location: "" }
];

describe("c-basecamp-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("greets the member by first name", async () => {
    const el = mount();
    getRecord.emit({ fields: { FirstName: { value: "Jane" } } });
    await flush();
    expect(el.shadowRoot.querySelector(".status-strip__hi").textContent).toBe(
      "Welcome back, Jane"
    );
  });

  it("renders upcoming event cards from getMyRegistrations", async () => {
    const el = mount();
    getMyRegistrations.emit(REGS);
    await flush();
    const cards = el.shadowRoot.querySelectorAll(".evcard");
    expect(cards.length).toBe(1);
    expect(el.shadowRoot.querySelector(".evcard__name").textContent).toBe(
      "Beacon Practice"
    );
    expect(
      el.shadowRoot.querySelector(".evcard__link").getAttribute("href")
    ).toBe("/event?recordId=a12A");
  });

  it("shows the empty state when there are no registrations", async () => {
    const el = mount();
    getMyRegistrations.emit([]);
    await flush();
    expect(el.shadowRoot.querySelector(".panel--events .empty")).not.toBeNull();
  });

  it("caps the latest posts at four", async () => {
    const el = mount();
    getPublishedPosts.emit(POSTS);
    await flush();
    expect(el.shadowRoot.querySelectorAll(".postrow").length).toBe(4);
    expect(
      el.shadowRoot.querySelector(".postrow__link").getAttribute("href")
    ).toBe("/post?recordId=p1");
  });

  it("shows the Slack link only when configured", async () => {
    const noSlack = mount();
    getMyRegistrations.emit([]);
    await flush();
    let actions = [...noSlack.shadowRoot.querySelectorAll(".action")].map((a) =>
      a.textContent.trim()
    );
    expect(actions.some((t) => t.includes("Slack"))).toBe(false);

    const withSlack = mount({ slackHref: "https://smi.slack.com" });
    getMyRegistrations.emit([]);
    await flush();
    actions = [...withSlack.shadowRoot.querySelectorAll(".action")].map((a) =>
      a.textContent.trim()
    );
    expect(actions.some((t) => t.includes("Slack"))).toBe(true);
  });

  it("resolves the trip report link correctly, rewriting trip-report/new variations", async () => {
    // Default /trip-report/new
    let el = mount();
    await flush();
    expect(
      el.shadowRoot.querySelector(".action").getAttribute("href")
    ).toContain("/newtrip");

    document.body.removeChild(el);

    // Variation: domain + path with trailing slash
    el = mount({
      tripReportHref: "https://spokanemountaineers.org/trip-report/new/"
    });
    await flush();
    expect(el.shadowRoot.querySelector(".action").getAttribute("href")).toBe(
      "/newtrip"
    );
  });
});
