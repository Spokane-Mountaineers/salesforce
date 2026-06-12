// isGuest is a static import in the component, so toggle it per-test via
// jest.resetModules + a fresh mock + dynamic import. createElement must come
// from the SAME post-reset module graph as the component, otherwise the
// component extends a different LightningElement than the engine expects.
let tagSeq = 0;
async function render({ guest = false, props = {}, base = "" } = {}) {
  jest.resetModules();
  jest.doMock("@salesforce/user/isGuest", () => ({ default: guest }), {
    virtual: true
  });
  jest.doMock(
    "@salesforce/community/basePath",
    () => ({ __esModule: true, default: base }),
    { virtual: true }
  );
  const { createElement } = await import("lwc");
  const { default: SmiThemeLayout } = await import("c/smiThemeLayout");
  // Unique tag per render — the custom-element registry persists across
  // jest.resetModules, so reusing a tag throws "already registered".
  const el = createElement(`c-smi-theme-layout-${tagSeq++}`, {
    is: SmiThemeLayout
  });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

describe("c-smi-theme-layout", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.resetModules();
  });

  it("renders the wordmark, header nav, and footer", async () => {
    const el = await render();
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".brand__name").textContent).toBe(
      "Spokane Mountaineers"
    );
    expect(el.shadowRoot.querySelector(".site-header")).not.toBeNull();
    expect(el.shadowRoot.querySelector(".site-footer")).not.toBeNull();
    expect(el.shadowRoot.querySelector("main.site-main")).not.toBeNull();
  });

  it("shows Log in for guests and hides member-only nav", async () => {
    const el = await render({ guest: true });
    await Promise.resolve();
    const auth = el.shadowRoot.querySelector(".nav__auth a");
    expect(auth.textContent.trim()).toBe("Log in");
    const labels = [...el.shadowRoot.querySelectorAll(".nav__link")].map((a) =>
      a.textContent.trim()
    );
    expect(labels).not.toContain("My Mountaineers");
    expect(labels).toContain("Calendar");
  });

  it("shows Log out and member-only nav for signed-in members", async () => {
    const el = await render({ guest: false });
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".nav__auth a").textContent.trim()).toBe(
      "Log out"
    );
    const labels = [...el.shadowRoot.querySelectorAll(".nav__link")].map((a) =>
      a.textContent.trim()
    );
    expect(labels).toContain("My Mountaineers");
  });

  it("toggles the mobile menu and reflects aria-expanded", async () => {
    const el = await render();
    await Promise.resolve();
    const burger = el.shadowRoot.querySelector(".hamburger");
    expect(el.shadowRoot.querySelector(".nav").className).toBe("nav");
    expect(burger.getAttribute("aria-expanded")).toBe("false");

    burger.click();
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".nav").className).toContain(
      "nav--open"
    );
    expect(burger.getAttribute("aria-expanded")).toBe("true");
  });

  it("honors a navItemsJson override and ignores malformed JSON", async () => {
    const el = await render({
      props: {
        navItemsJson: JSON.stringify([{ label: "Trips", href: "/trips" }])
      }
    });
    await Promise.resolve();
    const labels = [...el.shadowRoot.querySelectorAll(".nav__link")].map((a) =>
      a.textContent.trim()
    );
    expect(labels).toEqual(["Trips"]);

    const bad = await render({ props: { navItemsJson: "{not json" } });
    await Promise.resolve();
    // Falls back to the default IA rather than rendering nothing.
    const fallback = [...bad.shadowRoot.querySelectorAll(".nav__link")].map(
      (a) => a.textContent.trim()
    );
    expect(fallback).toContain("Calendar");
  });

  it("prefixes the community basePath onto root-relative links", async () => {
    const el = await render({ base: "/lwrsite" });
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".brand").getAttribute("href")).toBe(
      "/lwrsite"
    );
    const calendar = [...el.shadowRoot.querySelectorAll(".nav__link")].find(
      (a) => a.textContent.trim() === "Calendar"
    );
    expect(calendar.getAttribute("href")).toBe("/lwrsite/events");
  });
});
