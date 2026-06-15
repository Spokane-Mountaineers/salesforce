import { createElement } from "lwc";
import LoginGate from "c/loginGate";

function mount(props = {}) {
  const el = createElement("c-login-gate", { is: LoginGate });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

describe("c-login-gate", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders the heading, message, and a sign-in link", () => {
    const el = mount({ heading: "Members only", message: "Please sign in." });
    expect(el.shadowRoot.querySelector(".title").textContent).toBe(
      "Members only"
    );
    expect(el.shadowRoot.querySelector(".message").textContent).toBe(
      "Please sign in."
    );
    const signIn = el.shadowRoot.querySelector(".btn--primary");
    expect(signIn.textContent.trim()).toBe("Sign in");
    expect(signIn.getAttribute("href")).toContain("/login");
  });

  it("carries the current page as the startURL return", () => {
    const el = mount();
    const href = el.shadowRoot
      .querySelector(".btn--primary")
      .getAttribute("href");
    expect(href).toContain("startURL=");
  });
});
