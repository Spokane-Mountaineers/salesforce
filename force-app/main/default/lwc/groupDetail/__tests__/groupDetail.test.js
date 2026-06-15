import { createElement } from "lwc";
import GroupDetail from "c/groupDetail";
import getGroup from "@salesforce/apex/ActivityGroupController.getGroup";
import joinGroup from "@salesforce/apex/ActivityGroupController.joinGroup";
import setNotificationFrequency from "@salesforce/apex/ActivityGroupController.setNotificationFrequency";

jest.mock(
  "@salesforce/apex/ActivityGroupController.getGroup",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
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
  isMember: false,
  hasPendingRequest: false,
  notificationFrequency: null
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
    getGroup.emit({ ...GROUP, isMember: true });
    await flush();
    expect(el.shadowRoot.querySelector(".title").textContent).toBe("Climbing");
    const cal = el.shadowRoot.querySelector("c-events-calendar");
    expect(cal.activity).toBe("Climbing");
    const feed = el.shadowRoot.querySelector("c-smi-feed");
    expect(feed.groupId).toBe("0F9a");
    expect(feed.readOnly).toBe(false);
  });

  it("shows a join button to non-members and makes the feed read-only", async () => {
    const el = mount({ groupId: "0F9a" });
    getGroup.emit({ ...GROUP, isMember: false });
    await flush();
    const join = el.shadowRoot.querySelector(".btn--primary");
    expect(join.textContent.trim()).toBe("Join group");
    expect(el.shadowRoot.querySelector("c-smi-feed").readOnly).toBe(true);
    join.click();
    await flush();
    expect(joinGroup).toHaveBeenCalledWith({ groupId: "0F9a" });
  });

  it("labels the action as a request for private groups", async () => {
    const el = mount({ groupId: "0F9a" });
    getGroup.emit({ ...GROUP, isPublic: false, isMember: false });
    await flush();
    expect(
      el.shadowRoot.querySelector(".btn--primary").textContent.trim()
    ).toBe("Request to join");
  });

  it("preselects the member's notification frequency and saves changes", async () => {
    const el = mount({ groupId: "0F9a" });
    getGroup.emit({ ...GROUP, isMember: true, notificationFrequency: "W" });
    await flush();
    const select = el.shadowRoot.querySelector(".freq__select");
    const selected = [...select.options].find((o) => o.selected);
    expect(selected.value).toBe("W");
    select.value = "D";
    select.dispatchEvent(new CustomEvent("change"));
    await flush();
    expect(setNotificationFrequency).toHaveBeenCalledWith({
      groupId: "0F9a",
      frequency: "D"
    });
  });

  it("shows the admin panel only to group admins", async () => {
    const member = mount({ groupId: "0F9a" });
    getGroup.emit({ ...GROUP, isMember: true, isAdmin: false });
    await flush();
    expect(member.shadowRoot.querySelector("c-group-admin-panel")).toBeNull();

    const admin = mount({ groupId: "0F9a" });
    getGroup.emit({ ...GROUP, isMember: true, isAdmin: true });
    await flush();
    expect(
      admin.shadowRoot.querySelector("c-group-admin-panel")
    ).not.toBeNull();
  });
});
