import { createElement } from "lwc";
import TripReportForm from "c/tripReportForm";
import createTripReport from "@salesforce/apex/ContentPostController.createTripReport";

jest.mock(
  "@salesforce/apex/ContentPostController.createTripReport",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

function mount() {
  const el = createElement("c-trip-report-form", { is: TripReportForm });
  document.body.appendChild(el);
  return el;
}

function setField(el, field, value) {
  const input = el.shadowRoot.querySelector(`[data-field="${field}"]`);
  input.value = value;
  input.dispatchEvent(new CustomEvent("change"));
}

describe("c-trip-report-form", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("blocks submit and shows an error when the title is blank", async () => {
    const el = mount();
    el.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await Promise.resolve();
    expect(createTripReport).not.toHaveBeenCalled();
    expect(el.shadowRoot.querySelector(".error").textContent).toContain(
      "title"
    );
  });

  it("submits the form values and emits a created event with the new id", async () => {
    createTripReport.mockResolvedValue("a00ABC");
    const el = mount();
    const handler = jest.fn();
    el.addEventListener("created", handler);

    setField(el, "title", "Beacon Rock south face");
    setField(el, "activity", "Climbing");
    setField(el, "location", "Beacon");
    setField(el, "freeTags", "trad, granite");
    el.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await Promise.resolve();
    await Promise.resolve();

    expect(createTripReport).toHaveBeenCalledTimes(1);
    const args = createTripReport.mock.calls[0][0];
    expect(args.title).toBe("Beacon Rock south face");
    expect(args.activity).toBe("Climbing");
    expect(args.freeTags).toBe("trad, granite");
    expect(handler).toHaveBeenCalledTimes(1);
    expect(handler.mock.calls[0][0].detail.id).toBe("a00ABC");
  });

  it("surfaces a server error and does not emit created", async () => {
    createTripReport.mockRejectedValue({ body: { message: "no access" } });
    const el = mount();
    const handler = jest.fn();
    el.addEventListener("created", handler);

    setField(el, "title", "A trip");
    el.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await Promise.resolve();
    await Promise.resolve();

    expect(el.shadowRoot.querySelector(".error").textContent).toContain(
      "no access"
    );
    expect(handler).not.toHaveBeenCalled();
  });
});
