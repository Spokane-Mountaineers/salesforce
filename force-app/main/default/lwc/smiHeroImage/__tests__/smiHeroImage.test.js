import { createElement } from "lwc";
import SmiHeroImage from "c/smiHeroImage";

function mount(props = {}) {
  const el = createElement("c-smi-hero-image", { is: SmiHeroImage });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

describe("c-smi-hero-image", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("always renders the image and a scrim layer", () => {
    const el = mount({ imageUrl: "/hero.jpg", alt: "Alpine lake" });
    expect(el.shadowRoot.querySelector(".img").getAttribute("src")).toBe(
      "/hero.jpg"
    );
    expect(el.shadowRoot.querySelector(".img").getAttribute("alt")).toBe(
      "Alpine lake"
    );
    // Scrim is non-negotiable — overlaid type must never sit on a raw photo.
    expect(el.shadowRoot.querySelector(".scrim")).not.toBeNull();
  });

  it("renders structured overlay type when provided", async () => {
    const el = mount({
      imageUrl: "/h.jpg",
      eyebrow: "Climbing",
      heading: "Beacon Rock",
      subtitle: "A weekend on the south face"
    });
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".eyebrow").textContent).toBe(
      "Climbing"
    );
    expect(el.shadowRoot.querySelector(".title").textContent).toBe(
      "Beacon Rock"
    );
    expect(el.shadowRoot.querySelector(".sub").textContent).toBe(
      "A weekend on the south face"
    );
  });

  it("omits overlay text blocks that are not provided", async () => {
    const el = mount({ imageUrl: "/h.jpg", heading: "Just a title" });
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".eyebrow")).toBeNull();
    expect(el.shadowRoot.querySelector(".sub")).toBeNull();
    expect(el.shadowRoot.querySelector(".title")).not.toBeNull();
  });
});
