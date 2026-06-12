import { createElement } from "lwc";
import CommunityForgotPassword from "c/communityForgotPassword";
import requestPasswordReset from "@salesforce/apex/CommunityLoginController.requestPasswordReset";

jest.mock(
  "@salesforce/apex/CommunityLoginController.requestPasswordReset",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function mount(props = {}) {
  const el = createElement("c-community-forgot-password", {
    is: CommunityForgotPassword
  });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}
const flush = () => Promise.resolve();

describe("c-community-forgot-password", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders the request form and a basePath back-to-sign-in link", async () => {
    const el = mount();
    await flush();
    expect(el.shadowRoot.querySelector(".heading").textContent).toBe(
      "Reset your password"
    );
    expect(el.shadowRoot.querySelector('input[type="text"]')).not.toBeNull();
    // basePath is auto-mocked to "" by sfdx-lwc-jest.
    expect(el.shadowRoot.querySelector(".forgot").getAttribute("href")).toBe(
      "/login"
    );
  });

  it("submits the username and shows the check-email confirmation on success", async () => {
    requestPasswordReset.mockResolvedValue({ success: true });
    const el = mount();
    await flush();

    const input = el.shadowRoot.querySelector('input[type="text"]');
    input.value = "jason@example.com";
    input.dispatchEvent(new CustomEvent("change"));
    el.shadowRoot
      .querySelector(".form")
      .dispatchEvent(new CustomEvent("submit"));
    await flush();
    await flush();

    expect(requestPasswordReset).toHaveBeenCalledWith({
      username: "jason@example.com"
    });
    expect(el.shadowRoot.querySelector(".heading").textContent).toBe(
      "Check your email"
    );
    // The form is gone in the done state; the back-to-sign-in button remains.
    expect(el.shadowRoot.querySelector(".form")).toBeNull();
    expect(
      el.shadowRoot.querySelector(".btn--primary").getAttribute("href")
    ).toBe("/login");
  });

  it("surfaces an error when the reset call rejects", async () => {
    requestPasswordReset.mockRejectedValue({ body: { message: "boom" } });
    const el = mount();
    await flush();
    el.shadowRoot
      .querySelector(".form")
      .dispatchEvent(new CustomEvent("submit"));
    await flush();
    await flush();
    expect(el.shadowRoot.querySelector(".error").textContent).toContain("boom");
    expect(el.shadowRoot.querySelector(".heading").textContent).toBe(
      "Reset your password"
    );
  });
});
