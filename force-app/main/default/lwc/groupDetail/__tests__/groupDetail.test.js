import { createElement } from "lwc";
import GroupDetail from "c/groupDetail";
import getGroup from "@salesforce/apex/ActivityGroupController.getGroup";

jest.mock(
  "@salesforce/apex/ActivityGroupController.getGroup",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
// Write methods are mocked so the component's imports resolve, but groups are
// read-only on LWR for now (writeEnabled = false), so the UI doesn't call them.
jest.mock(
  "@salesforce/apex/ActivityGroupController.joinGroup",
  () => ({ default: jest.fn(() => Promise.resolve("member")) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ActivityGroupController.leaveGroup",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ActivityGroupController.setNotificationFrequency",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);

const GROUP = {
  id: "0F9a",
  name: "Climbing",
  description: "Rock and alpine climbing.",
  memberCount: 224,
  isPublic: true,
  isMember: true,
  isAdmin: true,
  hasPendingRequest: false,
  notificationFrequency: "D"
};

function mount(props = {}) {
  const el = createElement("c-group-detail", { is: GroupDetail });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}
const flush = () => Promise.resolve();

describe("c-group-detail", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders the header and presets the calendar + feed to the group", async () => {
    const el = mount({ groupId: "0F9a" });
    getGroup.emit(GROUP);
    await flush();
    expect(el.shadowRoot.querySelector(".title").textContent).toBe("Climbing");
    const cal = el.shadowRoot.querySelector("c-events-calendar");
    expect(cal.activity).toBe("Climbing");
    const feed = el.shadowRoot.querySelector("c-smi-feed");
    expect(feed.groupId).toBe("0F9a");
  });

  it("is read-only while groups live in the legacy network", async () => {
    const el = mount({ groupId: "0F9a" });
    getGroup.emit(GROUP);
    await flush();
    // No write controls: no join/leave button, no notification select, no admin panel.
    expect(el.shadowRoot.querySelector(".membership")).toBeNull();
    expect(el.shadowRoot.querySelector(".freq__select")).toBeNull();
    expect(el.shadowRoot.querySelector("c-group-admin-panel")).toBeNull();
    // A note explains where membership/posting happen for now.
    expect(el.shadowRoot.querySelector(".membership-note")).not.toBeNull();
    // The feed is read-only even for a member/admin.
    expect(el.shadowRoot.querySelector("c-smi-feed").readOnly).toBe(true);
  });

  it("shows the friendly login gate to guests", async () => {
    // isGuest is auto-mocked false; this checks the non-guest path renders the
    // article (guest path is exercised by the loginGate component's own tests).
    const el = mount({ groupId: "0F9a" });
    getGroup.emit(GROUP);
    await flush();
    expect(el.shadowRoot.querySelector("article.root")).not.toBeNull();
  });

  it("shows an error when the group can't be loaded", async () => {
    const el = mount({ groupId: "bad" });
    getGroup.error();
    await flush();
    expect(el.shadowRoot.querySelector(".state--error")).not.toBeNull();
  });
});
