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

const GROUP = {
  id: "0F9a",
  name: "Climbing",
  description: "Rock and alpine climbing.",
  memberCount: 224,
  isPublic: true
};

function mount(props = {}) {
  const el = createElement("c-group-detail", { is: GroupDetail });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

describe("c-group-detail", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders the group header and presets the calendar to the group", async () => {
    const el = mount({ groupId: "0F9a" });
    getGroup.emit(GROUP);
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".title").textContent).toBe("Climbing");
    expect(el.shadowRoot.querySelector(".eyebrow").textContent).toBe(
      "Public group"
    );
    expect(el.shadowRoot.querySelector(".meta").textContent).toBe(
      "224 members"
    );
    const cal = el.shadowRoot.querySelector("c-events-calendar");
    expect(cal).not.toBeNull();
    expect(cal.activity).toBe("Climbing");
    const feed = el.shadowRoot.querySelector("c-smi-feed");
    expect(feed).not.toBeNull();
    expect(feed.groupId).toBe("0F9a");
  });

  it("shows the admin panel only to group admins", async () => {
    const member = mount({ groupId: "0F9a" });
    getGroup.emit({ ...GROUP, isAdmin: false });
    await Promise.resolve();
    expect(member.shadowRoot.querySelector("c-group-admin-panel")).toBeNull();

    const admin = mount({ groupId: "0F9a" });
    getGroup.emit({ ...GROUP, isAdmin: true });
    await Promise.resolve();
    const panel = admin.shadowRoot.querySelector("c-group-admin-panel");
    expect(panel).not.toBeNull();
    expect(panel.groupId).toBe("0F9a");
  });

  it("shows an error when the group can't be loaded", async () => {
    const el = mount({ groupId: "bad" });
    getGroup.error();
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".state--error")).not.toBeNull();
  });
});
