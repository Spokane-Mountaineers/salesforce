import { createElement } from "lwc";
import SmiFeed from "c/smiFeed";
import getFeed from "@salesforce/apex/ChatterPublisherController.getFeed";
import postToChatter from "@salesforce/apex/ChatterPublisherController.postToChatter";

jest.mock(
  "@salesforce/apex/ChatterPublisherController.getFeed",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ChatterPublisherController.postToChatter",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);

const POSTS = [
  {
    id: "0D5a",
    body: "<p>Trailhead at 7am</p>",
    authorName: "Jane Member",
    createdDate: "2026-06-10T15:00:00.000Z"
  }
];

function mount(props = { groupId: "0F9a" }) {
  const el = createElement("c-smi-feed", { is: SmiFeed });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}
const flush = () => Promise.resolve();

describe("c-smi-feed", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    window.localStorage.clear();
    jest.clearAllMocks();
  });

  it("renders posts with HTML stripped to text", async () => {
    const el = mount();
    getFeed.emit(POSTS);
    await flush();
    expect(el.shadowRoot.querySelector(".post__author").textContent).toBe(
      "Jane Member"
    );
    expect(el.shadowRoot.querySelector(".post__body").textContent).toBe(
      "Trailhead at 7am"
    );
  });

  it("shows the empty state with no posts", async () => {
    const el = mount();
    getFeed.emit([]);
    await flush();
    expect(el.shadowRoot.querySelector(".empty")).not.toBeNull();
  });

  it("disables Post until there is text", async () => {
    const el = mount();
    getFeed.emit([]);
    await flush();
    const btn = el.shadowRoot.querySelector(".btn--primary");
    expect(btn.disabled).toBe(true);

    const ta = el.shadowRoot.querySelector(".composer__input");
    ta.value = "Hello";
    ta.dispatchEvent(new CustomEvent("input"));
    await flush();
    expect(el.shadowRoot.querySelector(".btn--primary").disabled).toBe(false);
  });

  it("posts, clears the draft, and persists drafts to localStorage", async () => {
    postToChatter.mockResolvedValue("0D5xNEW");
    const el = mount();
    getFeed.emit([]);
    await flush();

    const ta = el.shadowRoot.querySelector(".composer__input");
    ta.value = "Meet at the crag";
    ta.dispatchEvent(new CustomEvent("input"));
    await flush();
    expect(window.localStorage.getItem("smiFeedDraft:0F9a")).toBe(
      "Meet at the crag"
    );

    el.shadowRoot.querySelector(".btn--primary").click();
    await flush();
    await flush();
    expect(postToChatter).toHaveBeenCalledWith({
      groupId: "0F9a",
      content: "Meet at the crag"
    });
    expect(window.localStorage.getItem("smiFeedDraft:0F9a")).toBeNull();
  });

  it("surfaces a post error", async () => {
    postToChatter.mockRejectedValue({ body: { message: "no access" } });
    const el = mount();
    getFeed.emit([]);
    await flush();
    const ta = el.shadowRoot.querySelector(".composer__input");
    ta.value = "x";
    ta.dispatchEvent(new CustomEvent("input"));
    await flush();
    el.shadowRoot.querySelector(".btn--primary").click();
    await flush();
    await flush();
    expect(
      el.shadowRoot.querySelector(".composer__error").textContent
    ).toContain("no access");
  });
});
