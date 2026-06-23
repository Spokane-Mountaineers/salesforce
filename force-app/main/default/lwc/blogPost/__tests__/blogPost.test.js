import { createElement } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import BlogPost from "c/blogPost";
import getPost from "@salesforce/apex/ContentPostController.getPost";
import getPostPhotos from "@salesforce/apex/ContentPostController.getPostPhotos";

jest.mock(
  "@salesforce/apex/ContentPostController.getPost",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/ContentPostController.getPostPhotos",
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
  freeTags: ["trad", "granite"],
  displayTags: ["trad", "granite"]
};

const PHOTOS = [
  {
    id: "p001",
    contentDocumentId: "doc001",
    altText: "Mt. Spokane sunset",
    caption: "Gorgeous views",
    credit: "Jane Member",
    consentConfirmed: true,
    sortOrder: 1,
    aspectRatio: "3:2",
    publicUrl: "http://public/1",
    memberUrl: "/sfc/servlet.shepherd/document/download/doc001"
  },
  {
    id: "p002",
    contentDocumentId: "doc002",
    altText: "Climbing Mt. Spokane",
    caption: "Struggling but happy",
    credit: "John Climber",
    consentConfirmed: true,
    sortOrder: 2,
    aspectRatio: "Portrait",
    publicUrl: "http://public/2",
    memberUrl: "/sfc/servlet.shepherd/document/download/doc002"
  }
];

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
    jest.clearAllMocks();
  });

  it("renders title, composed meta, byline and tags", async () => {
    const el = mount({ postId: "a001" });
    getPost.emit(POST);
    getPostPhotos.emit([]);
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
    getPostPhotos.emit([]);
    await Promise.resolve();
    const body = el.shadowRoot.querySelector("lightning-formatted-rich-text");
    expect(body.value).toBe("<p>Great day on the rock.</p>");
  });

  it("loads the post from the ?recordId= URL param when no postId prop is set", async () => {
    const el = mount();
    CurrentPageReference.emit({ state: { recordId: "a001" } });
    await Promise.resolve();
    getPost.emit(POST);
    getPostPhotos.emit([]);
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

  it("renders photo gallery when post has photos", async () => {
    const el = mount({ postId: "a001" });
    getPost.emit(POST);
    getPostPhotos.emit(PHOTOS);
    await Promise.resolve();

    const gallerySection = el.shadowRoot.querySelector(".gallery-section");
    expect(gallerySection).not.toBeNull();

    const plates = el.shadowRoot.querySelectorAll("c-smi-field-plate");
    expect(plates.length).toBe(2);
    expect(plates[0].imageUrl).toBe(
      "/sfc/servlet.shepherd/document/download/doc001"
    );
    expect(plates[0].alt).toBe("Mt. Spokane sunset");
    expect(plates[1].portrait).toBe(true); // Portrait aspect ratio maps to isPortrait
  });

  it("opens lightbox modal when photo is clicked", async () => {
    const el = mount({ postId: "a001" });
    getPost.emit(POST);
    getPostPhotos.emit(PHOTOS);
    await Promise.resolve();

    expect(el.shadowRoot.querySelector(".lightbox-overlay")).toBeNull();

    // Click the first gallery item
    const firstItem = el.shadowRoot.querySelector(
      ".gallery-item[data-index='0']"
    );
    firstItem.click();
    await Promise.resolve();

    const lightbox = el.shadowRoot.querySelector(".lightbox-overlay");
    expect(lightbox).not.toBeNull();

    const img = el.shadowRoot.querySelector(".lightbox-image");
    expect(img.src).toContain("/sfc/servlet.shepherd/document/download/doc001");

    const captionText =
      el.shadowRoot.querySelector(".lightbox-title").textContent;
    expect(captionText).toBe("Gorgeous views");

    const creditText =
      el.shadowRoot.querySelector(".lightbox-credit").textContent;
    expect(creditText).toContain("Jane Member");
  });

  it("navigates through photos in lightbox and closes", async () => {
    const el = mount({ postId: "a001" });
    getPost.emit(POST);
    getPostPhotos.emit(PHOTOS);
    await Promise.resolve();

    // Open lightbox
    el.shadowRoot.querySelector(".gallery-item[data-index='0']").click();
    await Promise.resolve();

    // Verify initial is 1 of 2
    expect(el.shadowRoot.querySelector(".lightbox-meta").textContent).toContain(
      "1 of 2"
    );

    // Click next
    el.shadowRoot.querySelector(".lightbox-btn--next").click();
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".lightbox-meta").textContent).toContain(
      "2 of 2"
    );

    // Click next again (should wrap to 1)
    el.shadowRoot.querySelector(".lightbox-btn--next").click();
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".lightbox-meta").textContent).toContain(
      "1 of 2"
    );

    // Click prev (should wrap to 2)
    el.shadowRoot.querySelector(".lightbox-btn--prev").click();
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".lightbox-meta").textContent).toContain(
      "2 of 2"
    );

    // Click close
    el.shadowRoot.querySelector(".lightbox-btn--close").click();
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".lightbox-overlay")).toBeNull();
  });

  it("responds to keyboard events (ArrowLeft, ArrowRight, Escape) in lightbox", async () => {
    const el = mount({ postId: "a001" });
    getPost.emit(POST);
    getPostPhotos.emit(PHOTOS);
    await Promise.resolve();

    // Open lightbox
    el.shadowRoot.querySelector(".gallery-item[data-index='0']").click();
    await Promise.resolve();

    expect(el.shadowRoot.querySelector(".lightbox-meta").textContent).toContain(
      "1 of 2"
    );

    // Press ArrowRight
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight" }));
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".lightbox-meta").textContent).toContain(
      "2 of 2"
    );

    // Press ArrowLeft
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowLeft" }));
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".lightbox-meta").textContent).toContain(
      "1 of 2"
    );

    // Press Escape
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".lightbox-overlay")).toBeNull();
  });
});
