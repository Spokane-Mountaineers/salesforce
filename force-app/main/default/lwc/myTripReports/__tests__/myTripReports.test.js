import { createElement } from "lwc";
import MyTripReports from "c/myTripReports";
import getMyPosts from "@salesforce/apex/ContentPostController.getMyPosts";

jest.mock(
  "@salesforce/apex/ContentPostController.getMyPosts",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/ContentPostController.deleteOwnDraft",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function mount() {
  const el = createElement("c-my-trip-reports", { is: MyTripReports });
  document.body.appendChild(el);
  return el;
}

async function flush() {
  return Promise.resolve();
}

describe("c-my-trip-reports", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders drafts and published posts correctly", async () => {
    const mockPosts = [
      {
        id: "a001",
        title: "Draft Peak Climb",
        status: "Draft",
        activity: "Climbing",
        location: "Mount Stuart",
        tripDate: "2026-06-20"
      },
      {
        id: "a002",
        title: "Published River Float",
        status: "Published",
        activity: "Paddling",
        location: "Spokane River",
        publishDate: "2026-06-22"
      }
    ];

    const el = mount();
    getMyPosts.emit(mockPosts);
    await flush();

    const titles = Array.from(
      el.shadowRoot.querySelectorAll(".item-title")
    ).map((node) => node.textContent);
    expect(titles).toContain("Draft Peak Climb");
    expect(titles).toContain("Published River Float");
  });

  it("switches to create mode when new trip report is clicked", async () => {
    const el = mount();
    getMyPosts.emit([]);
    await flush();

    const newBtn = el.shadowRoot.querySelector(".smi-btn--primary");
    newBtn.click();
    await flush();

    const form = el.shadowRoot.querySelector("c-trip-report-form");
    expect(form).not.toBeNull();
  });

  it("switches to edit mode when edit is clicked", async () => {
    const mockPosts = [
      {
        id: "a001",
        title: "Draft Peak Climb",
        status: "Draft",
        activity: "Climbing",
        location: "Mount Stuart"
      }
    ];
    const el = mount();
    getMyPosts.emit(mockPosts);
    await flush();

    const editBtn = el.shadowRoot.querySelector(".smi-btn--ghost");
    editBtn.click();
    await flush();

    const form = el.shadowRoot.querySelector("c-trip-report-form");
    expect(form).not.toBeNull();
    expect(form.recordId).toBe("a001");
  });
});
