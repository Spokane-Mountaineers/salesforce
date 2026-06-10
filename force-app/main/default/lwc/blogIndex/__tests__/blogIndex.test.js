import { createElement } from "lwc";
import BlogIndex from "c/blogIndex";
import getPublishedPosts from "@salesforce/apex/ContentPostController.getPublishedPosts";
import getActiveTags from "@salesforce/apex/ContentPostController.getActiveTags";

// sfdx-lwc-jest auto-mocks @salesforce/apex imports used in @wire as test wire
// adapters with .emit()/.error().
jest.mock(
  "@salesforce/apex/ContentPostController.getPublishedPosts",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ContentPostController.getActiveTags",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const POSTS = [
  {
    id: "a001",
    title: "Beacon Rock",
    activity: "Climbing",
    location: "Beacon",
    authorName: "Jane Member",
    freeTags: []
  },
  {
    id: "a002",
    title: "Mount Spokane",
    activity: "Hiking",
    location: "",
    authorName: "Bob Member",
    freeTags: []
  }
];

function mount() {
  const el = createElement("c-blog-index", { is: BlogIndex });
  document.body.appendChild(el);
  return el;
}

async function flush() {
  return Promise.resolve();
}

describe("c-blog-index", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("leads with the newest post and lists the rest as ledger rows", async () => {
    const el = mount();
    getActiveTags.emit([{ id: "t1", name: "Cascades", category: "Region" }]);
    getPublishedPosts.emit(POSTS);
    await flush();
    expect(el.shadowRoot.querySelector(".lead__title").textContent).toBe(
      "Beacon Rock"
    );
    const rows = el.shadowRoot.querySelectorAll(".row");
    expect(rows.length).toBe(1);
    expect(el.shadowRoot.querySelector(".row__title").textContent).toBe(
      "Mount Spokane"
    );
  });

  it("composes meta from activity and location for lead and rows", async () => {
    const el = mount();
    getPublishedPosts.emit(POSTS);
    await flush();
    expect(el.shadowRoot.querySelector(".lead__meta").textContent).toBe(
      "Climbing · Beacon"
    );
    expect(el.shadowRoot.querySelector(".row__meta").textContent).toBe(
      "Hiking"
    );
  });

  it("renders a tag chip per active tag", async () => {
    const el = mount();
    getActiveTags.emit([
      { id: "t1", name: "Cascades", category: "Region" },
      { id: "t2", name: "Larches", category: "General" }
    ]);
    getPublishedPosts.emit(POSTS);
    await flush();
    const tagChips = [...el.shadowRoot.querySelectorAll(".chips")][1];
    expect(tagChips.querySelectorAll(".chip").length).toBe(2);
  });

  it("shows an empty state when no posts match", async () => {
    const el = mount();
    getPublishedPosts.emit([]);
    await flush();
    expect(el.shadowRoot.querySelector(".state")).not.toBeNull();
    expect(el.shadowRoot.querySelector(".lead")).toBeNull();
    expect(el.shadowRoot.querySelectorAll(".row").length).toBe(0);
  });

  it("surfaces an error from the wire", async () => {
    const el = mount();
    // The test wire adapter sets error.body to this first argument.
    getPublishedPosts.error({ message: "boom" });
    await flush();
    expect(el.shadowRoot.querySelector(".state--error").textContent).toContain(
      "boom"
    );
  });
});
