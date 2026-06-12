import { createElement } from "lwc";
import SmiFieldPlate from "c/smiFieldPlate";

function mount(props = {}) {
  const el = createElement("c-smi-field-plate", { is: SmiFieldPlate });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

describe("c-smi-field-plate", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders the image with alt text", () => {
    const el = mount({ imageUrl: "/img/x.jpg", alt: "Summit ridge" });
    const img = el.shadowRoot.querySelector("img");
    expect(img.getAttribute("src")).toBe("/img/x.jpg");
    expect(img.getAttribute("alt")).toBe("Summit ridge");
    expect(img.getAttribute("loading")).toBe("lazy");
  });

  it("composes the meta line from present parts only", async () => {
    const el = mount({
      imageUrl: "/i.jpg",
      activity: "Rock",
      location: "Minnehaha",
      plateDate: "Sep 2025"
    });
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".meta").textContent).toBe(
      "Rock · Minnehaha · Sep 2025"
    );
  });

  it("omits the meta block entirely when no metadata is given", async () => {
    const el = mount({ imageUrl: "/i.jpg" });
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".meta")).toBeNull();
  });

  it("adds the portrait modifier class when portrait", async () => {
    const el = mount({ imageUrl: "/i.jpg", portrait: true });
    await Promise.resolve();
    expect(
      el.shadowRoot.querySelector(".smi-field-plate--portrait")
    ).not.toBeNull();
  });
});
