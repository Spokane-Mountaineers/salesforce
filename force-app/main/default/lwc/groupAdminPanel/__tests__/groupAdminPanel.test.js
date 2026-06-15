import { createElement } from "lwc";
import GroupAdminPanel from "c/groupAdminPanel";
import getMembers from "@salesforce/apex/ActivityGroupController.getMembers";
import updateGroupDescription from "@salesforce/apex/ActivityGroupController.updateGroupDescription";
import setJoinRequestStatus from "@salesforce/apex/ActivityGroupController.setJoinRequestStatus";

jest.mock(
  "@salesforce/apex/ActivityGroupController.getMembers",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ActivityGroupController.updateGroupDescription",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ActivityGroupController.removeMember",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ActivityGroupController.setJoinRequestStatus",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);

const MEMBERS = {
  members: [
    { recordId: "0FBa", userId: "005a", name: "Chair Person", isAdmin: true },
    { recordId: "0FBb", userId: "005b", name: "Reg Member", isAdmin: false }
  ],
  requests: [
    { recordId: "0KCa", userId: "005c", name: "Hopeful Joiner", isAdmin: false }
  ]
};

function mount(props = {}) {
  const el = createElement("c-group-admin-panel", { is: GroupAdminPanel });
  Object.assign(el, { groupId: "0F9a", description: "Old desc", ...props });
  document.body.appendChild(el);
  return el;
}
const flush = () => Promise.resolve();

describe("c-group-admin-panel", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders members and pending requests for an admin", async () => {
    const el = mount();
    getMembers.emit(MEMBERS);
    await flush();
    expect(el.shadowRoot.querySelector(".badge").textContent).toBe(
      "Group admin"
    );
    const rows = el.shadowRoot.querySelectorAll(".row");
    // 1 request + 2 members
    expect(rows).toHaveLength(3);
    expect(el.shadowRoot.querySelector(".role").textContent).toBe("Admin");
  });

  it("saves the description", async () => {
    const el = mount();
    getMembers.emit(MEMBERS);
    await flush();
    el.shadowRoot.querySelector(".btn--primary").click();
    await flush();
    expect(updateGroupDescription).toHaveBeenCalledWith({
      groupId: "0F9a",
      description: "Old desc"
    });
  });

  it("approves a join request with the Accepted status", async () => {
    const el = mount();
    getMembers.emit(MEMBERS);
    await flush();
    const approve = el.shadowRoot.querySelector(
      '.row__actions [data-status="Accepted"]'
    );
    approve.click();
    await flush();
    expect(setJoinRequestStatus).toHaveBeenCalledWith({
      requestId: "0KCa",
      status: "Accepted"
    });
  });
});
