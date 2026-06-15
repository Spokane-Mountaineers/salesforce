import { createElement } from "lwc";
import ContentPage from "c/contentPage";

function mount(props = {}) {
  const el = createElement("c-content-page", { is: ContentPage });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

async function flush() {
  return Promise.resolve();
}

describe("c-content-page", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders a gradient hero with the heading and eyebrow when no image", () => {
    const el = mount({ eyebrow: "About", heading: "About the Mountaineers" });
    const hero = el.shadowRoot.querySelector(".hero");
    expect(hero.classList.contains("hero--gradient")).toBe(true);
    expect(el.shadowRoot.querySelector(".hero__title").textContent).toBe(
      "About the Mountaineers"
    );
    expect(el.shadowRoot.querySelector(".eyebrow").textContent).toBe("About");
  });

  it("renders a photographic hero when heroImageUrl is set", () => {
    const el = mount({
      heading: "Our Chalet",
      heroImageUrl: "https://example.com/chalet.jpg",
      heroAlt: "The chalet"
    });
    const hero = el.shadowRoot.querySelector(".hero");
    expect(hero.classList.contains("hero--photo")).toBe(true);
    const img = el.shadowRoot.querySelector(".hero__img");
    expect(img.src).toBe("https://example.com/chalet.jpg");
    expect(img.alt).toBe("The chalet");
  });

  it("injects pre-cleaned body HTML into the prose container", async () => {
    const el = mount({
      heading: "About",
      bodyHtml: "<h2>Heading</h2><p>Founded in <strong>1915</strong>.</p>"
    });
    await flush();
    const body = el.shadowRoot.querySelector(".body");
    expect(body.querySelector("h2").textContent).toBe("Heading");
    expect(body.querySelector("strong").textContent).toBe("1915");
  });

  it("resolves data-asset images to the content_assets static resource", async () => {
    const el = mount({
      heading: "History",
      bodyHtml: '<p><img data-asset="history.jpg" alt="History" /></p>'
    });
    await flush();
    const img = el.shadowRoot.querySelector(".body img");
    expect(img.getAttribute("src")).toMatch(/\/history\.jpg$/);
    expect(img.getAttribute("loading")).toBe("lazy");
  });

  it("resolves site-relative related links through basePath and renders them", () => {
    const el = mount({
      relatedHeading: "More About Us",
      relatedLinks: JSON.stringify([
        { label: "Our Mission", path: "/our-mission" },
        { label: "Foundation", path: "https://foundation.example.org" }
      ])
    });
    const links = el.shadowRoot.querySelectorAll(".related__item a");
    expect(links).toHaveLength(2);
    // basePath mock resolves to "" in tests, so internal paths pass through.
    expect(links[0].getAttribute("href")).toBe("/our-mission");
    expect(links[0].textContent).toBe("Our Mission");
    expect(links[1].getAttribute("href")).toBe(
      "https://foundation.example.org"
    );
  });

  it("ignores malformed related-links JSON without throwing", () => {
    const el = mount({ relatedHeading: "More", relatedLinks: "{not json" });
    expect(el.shadowRoot.querySelectorAll(".related__item a")).toHaveLength(0);
  });
});
