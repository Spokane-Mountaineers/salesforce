import { createElement } from "lwc";
import CommunityLogin from "c/communityLogin";
import login from "@salesforce/apex/CommunityLoginController.login";
import getLoginConfig from "@salesforce/apex/CommunityLoginController.getLoginConfig";

jest.mock(
  "@salesforce/apex/CommunityLoginController.login",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/CommunityLoginController.getLoginConfig",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const CONFIG = {
  googleUrl: "https://site/services/auth/sso/Google",
  microsoftUrl: "https://site/services/auth/sso/Microsoft",
  forgotPasswordUrl: "https://site/CommunitiesForgotPassword"
};

function mount(props = {}) {
  const el = createElement("c-community-login", { is: CommunityLogin });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}
const flush = () => Promise.resolve();

function setField(el, field, value) {
  const input = el.shadowRoot.querySelector(`[data-field="${field}"]`);
  input.value = value;
  input.dispatchEvent(new CustomEvent("change"));
}

describe("c-community-login", () => {
  let originalLocation;
  beforeEach(() => {
    originalLocation = window.location;
    delete window.location;
    window.location = { search: "", href: "" };
  });
  afterEach(() => {
    window.location = originalLocation;
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders SSO links + forgot link from the wired config", async () => {
    const el = mount();
    getLoginConfig.emit(CONFIG);
    await flush();
    const ssoLinks = [...el.shadowRoot.querySelectorAll(".btn--sso")].map((a) =>
      a.getAttribute("href")
    );
    expect(ssoLinks).toContain(CONFIG.googleUrl);
    expect(ssoLinks).toContain(CONFIG.microsoftUrl);
    expect(el.shadowRoot.querySelector(".forgot").getAttribute("href")).toBe(
      CONFIG.forgotPasswordUrl
    );
  });

  it("redirects on a successful sign-in", async () => {
    login.mockResolvedValue({ success: true, redirectUrl: "/s/home" });
    const el = mount();
    setField(el, "username", "jane@example.com");
    setField(el, "password", "secret");
    el.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await flush();
    await flush();
    expect(login).toHaveBeenCalledWith({
      username: "jane@example.com",
      password: "secret",
      startUrl: ""
    });
    expect(window.location.href).toBe("/s/home");
  });

  it("shows the server message and does not redirect on failure", async () => {
    login.mockResolvedValue({
      success: false,
      message: "Invalid username or password. Please try again."
    });
    const el = mount();
    setField(el, "username", "jane@example.com");
    setField(el, "password", "wrong");
    el.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await flush();
    await flush();
    expect(el.shadowRoot.querySelector(".error").textContent).toContain(
      "Invalid"
    );
    expect(window.location.href).toBe("");
  });

  it("surfaces a thrown apex error", async () => {
    login.mockRejectedValue({ body: { message: "boom" } });
    const el = mount();
    setField(el, "username", "x");
    setField(el, "password", "y");
    el.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await flush();
    await flush();
    expect(el.shadowRoot.querySelector(".error").textContent).toContain("boom");
  });
});
