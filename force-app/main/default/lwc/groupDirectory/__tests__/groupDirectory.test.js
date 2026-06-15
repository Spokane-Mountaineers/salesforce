import { createElement } from "lwc";
import GroupDirectory from "c/groupDirectory";
import getGroups from "@salesforce/apex/ActivityGroupController.getGroups";

jest.mock(
  "@salesforce/apex/ActivityGroupController.getGroups",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const GROUPS = [
  {
    id: "0F9a",
    name: "Climbing",
    description: "Rock and alpine.",
    memberCount: 224,
    isPublic: true,
    isCore: true
  },
  {
    id: "0F9b",
    name: "Hiking Leaders",
    description: "",
    memberCount: 1,
    isPublic: false,
    isCore: false
  }
];

function mount() {
  const el = createElement("c-group-directory", { is: GroupDirectory });
  document.body.appendChild(el);
  return el;
}

describe("c-group-directory", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders a card per group with link, type tag and member count", async () => {
    const el = mount();
    getGroups.emit(GROUPS);
    await Promise.resolve();
    const cards = el.shadowRoot.querySelectorAll(".card");
    expect(cards).toHaveLength(2);
    const first = cards[0];
    expect(first.querySelector(".card__name").textContent).toBe("Climbing");
    expect(first.querySelector(".card__link").getAttribute("href")).toContain(
      "/group?recordId=0F9a"
    );
    expect(first.querySelector(".tag").textContent).toBe("Public");
    expect(first.querySelector(".card__meta").textContent).toBe("224 members");
  });

  it("singularizes a one-member group and marks it private", async () => {
    const el = mount();
    getGroups.emit(GROUPS);
    await Promise.resolve();
    const second = el.shadowRoot.querySelectorAll(".card")[1];
    expect(second.querySelector(".card__meta").textContent).toBe("1 member");
    expect(second.querySelector(".tag").textContent).toBe("Private");
  });

  it("features core groups in their own section", async () => {
    const el = mount();
    getGroups.emit(GROUPS);
    await Promise.resolve();
    const sections = [...el.shadowRoot.querySelectorAll(".section-title")].map(
      (h) => h.textContent
    );
    expect(sections).toEqual(["Core activity groups", "More groups"]);
    // Climbing (core) carries the featured modifier; Hiking Leaders does not.
    expect(el.shadowRoot.querySelectorAll(".card--core")).toHaveLength(1);
    expect(
      el.shadowRoot.querySelector(".card--core .card__name").textContent
    ).toBe("Climbing");
  });

  it("shows an error state when the wire fails", async () => {
    const el = mount();
    getGroups.error();
    await Promise.resolve();
    expect(el.shadowRoot.querySelector(".state--error")).not.toBeNull();
  });
});
