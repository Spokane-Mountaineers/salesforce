import { createElement } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import BlogPost from "c/blogPost";
import getPost from "@salesforce/apex/ContentPostController.getPost";

jest.mock(
  "@salesforce/apex/ContentPostController.getPost",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const POST = {
  id: "a001",
  title: "Beacon Rock south face",
  body: "<p>Great day on the rock.</p>",
  activity: "Climbing",
  location: "Beacon Rock",
  tripDate: "2025-09-20",
  authorName: "Jane Member",
  freeTags: ["trad", "granite"]
};

function mount(props = {}) {
  const el = createElement("c-blog-post", { is: BlogPost });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

describe("c-blog-post", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders title, composed meta, byline and tags", async () => {
    const el = mount({ postId: "a001" });
    getPost.emit(POST);
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".title").textContent).toBe(
      "Beacon Rock south face"
    );
    expect(el.shadowRoot.querySelector(".meta").textContent).toBe(
      "Climbing · Beacon Rock · 2025-09-20"
    );
    expect(el.shadowRoot.querySelector(".byline").textContent).toContain(
      "Jane Member"
    );
    expect(el.shadowRoot.querySelectorAll(".tag").length).toBe(2);
  });

  it("passes the rich body to the formatted-rich-text component", async () => {
    const el = mount({ postId: "a001" });
    getPost.emit(POST);
    await Promise.resolve();
    const body = el.shadowRoot.querySelector("lightning-formatted-rich-text");
    expect(body.value).toBe("<p>Great day on the rock.</p>");
  });

  it("loads the post from the ?recordId= URL param when no postId prop is set", async () => {
    const el = mount();
    CurrentPageReference.emit({ state: { recordId: "a001" } });
    await Promise.resolve();
    getPost.emit(POST);
    await Promise.resolve();
    // The wire was called with the URL-derived id.
    expect(getPost.getLastConfig()).toEqual({ postId: "a001" });
    expect(el.shadowRoot.querySelector(".title").textContent).toBe(
      "Beacon Rock south face"
    );
  });

  it("shows an error message when the wire errors", async () => {
    const el = mount({ postId: "bad" });
    getPost.error({ message: "no access" });
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".error").textContent).toContain(
      "no access"
    );
    expect(el.shadowRoot.querySelector(".title")).toBeNull();
  });
});
