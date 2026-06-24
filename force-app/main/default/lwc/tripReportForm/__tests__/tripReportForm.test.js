import { createElement } from "lwc";
import TripReportForm from "c/tripReportForm";
import createTripReport from "@salesforce/apex/ContentPostController.createTripReport";
import updateTripReport from "@salesforce/apex/ContentPostController.updateTripReport";
import getPost from "@salesforce/apex/ContentPostController.getPost";
import getPostPhotos from "@salesforce/apex/ContentPostController.getPostPhotos";
import updatePhotoMetadata from "@salesforce/apex/ContentPostController.updatePhotoMetadata";
import deletePhoto from "@salesforce/apex/ContentPostController.deletePhoto";
import { refreshApex } from "@salesforce/apex";
import { CurrentPageReference } from "lightning/navigation";

jest.mock(
  "@salesforce/apex/ContentPostController.createTripReport",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ContentPostController.updateTripReport",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ContentPostController.deleteOwnDraft",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ContentPostController.uploadPhoto",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ContentPostController.updatePhotoMetadata",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ContentPostController.deletePhoto",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/ContentPostController.getPost",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ContentPostController.getActiveTags",
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

jest.mock(
  "@salesforce/apex",
  () => ({
    refreshApex: jest.fn().mockResolvedValue()
  }),
  { virtual: true }
);

function mount(props = {}) {
  const el = createElement("c-trip-report-form", { is: TripReportForm });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

function setField(el, field, value) {
  const input = el.shadowRoot.querySelector(`[data-field="${field}"]`);
  input.value = value;
  input.dispatchEvent(new CustomEvent("change"));
}

const POST_RECORD = {
  id: "a00ABC",
  title: "Beacon Rock draft",
  body: "<p>Nice day</p>",
  activity: "Climbing",
  location: "Beacon Rock",
  tripDate: "2025-09-20",
  difficulty: "Easy",
  freeTags: ["trad"],
  tagIds: [],
  status: "Draft"
};

const PHOTOS = [
  {
    id: "p001",
    altText: "A beautiful peak",
    caption: "Sunset peak",
    credit: "Jane Member",
    consentConfirmed: true,
    sortOrder: 1,
    aspectRatio: "3:2",
    memberUrl: "/sfc/servlet/doc001"
  }
];

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

  it("displays photo notice but no uploader when recordId is null", async () => {
    const el = mount();
    await Promise.resolve();

    expect(el.shadowRoot.querySelector(".photo-notice")).not.toBeNull();
    expect(el.shadowRoot.querySelector(".photo-upload-zone")).toBeNull();
  });

  it("renders photo section with uploaded photos when recordId is set", async () => {
    const el = mount({ recordId: "a00ABC" });
    getPost.emit(POST_RECORD);
    getPostPhotos.emit(PHOTOS);
    await Promise.resolve();

    expect(el.shadowRoot.querySelector(".photo-notice")).toBeNull();
    expect(el.shadowRoot.querySelector(".photo-upload-zone")).not.toBeNull();
    expect(el.shadowRoot.querySelectorAll(".photo-card").length).toBe(1);

    const img = el.shadowRoot.querySelector(".photo-preview");
    expect(img.src).toContain("/sfc/servlet/doc001");
    expect(img.alt).toBe("A beautiful peak");
  });

  it("validates photo Alt Text and consent before publishing", async () => {
    updateTripReport.mockResolvedValue();
    const el = mount({ recordId: "a00ABC" });
    getPost.emit(POST_RECORD);

    // photo with missing alt text and no consent
    const invalidPhotos = [
      {
        id: "p001",
        altText: "",
        caption: "Sunset peak",
        credit: "Jane Member",
        consentConfirmed: false,
        sortOrder: 1,
        aspectRatio: "3:2",
        memberUrl: "/sfc/servlet/doc001"
      }
    ];
    getPostPhotos.emit(invalidPhotos);
    await Promise.resolve();

    // Click publish button (first button in .actions)
    el.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await Promise.resolve();

    // Verify it doesn't call updateTripReport and sets error message
    expect(updateTripReport).not.toHaveBeenCalled();
    expect(el.shadowRoot.querySelector(".error").textContent).toContain(
      "Alt Text"
    );

    // Provide Alt Text but still missing consent
    invalidPhotos[0].altText = "Alt Text Provided";
    getPostPhotos.emit(invalidPhotos);
    await Promise.resolve();

    el.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await Promise.resolve();

    expect(updateTripReport).not.toHaveBeenCalled();
    expect(el.shadowRoot.querySelector(".error").textContent).toContain(
      "consent"
    );

    // Complete all requirements
    invalidPhotos[0].consentConfirmed = true;
    getPostPhotos.emit(invalidPhotos);
    await Promise.resolve();

    el.shadowRoot
      .querySelector("form")
      .dispatchEvent(new CustomEvent("submit"));
    await Promise.resolve();

    expect(updateTripReport).toHaveBeenCalled();
  });

  it("calls deletePhoto and refreshApex when photo is deleted", async () => {
    deletePhoto.mockResolvedValue();
    const el = mount({ recordId: "a00ABC" });
    getPost.emit(POST_RECORD);
    getPostPhotos.emit(PHOTOS);
    await Promise.resolve();

    const deleteBtn = el.shadowRoot.querySelector(".delete-photo-btn");
    deleteBtn.click();
    await Promise.resolve();

    expect(deletePhoto).toHaveBeenCalledWith({ photoId: "p001" });
    expect(refreshApex).toHaveBeenCalled();
  });

  it("calls updatePhotoMetadata when photo details are changed on blur", async () => {
    updatePhotoMetadata.mockResolvedValue();
    const el = mount({ recordId: "a00ABC" });
    getPost.emit(POST_RECORD);
    getPostPhotos.emit(PHOTOS);
    await Promise.resolve();

    const altInput = el.shadowRoot.querySelector(
      ".photo-metadata-fields input[data-field='altText']"
    );
    altInput.value = "New Alt Text Description";
    altInput.dispatchEvent(new CustomEvent("blur"));
    await Promise.resolve();

    expect(updatePhotoMetadata).toHaveBeenCalledWith({
      photoId: "p001",
      altText: "New Alt Text Description",
      caption: "Sunset peak",
      credit: "Jane Member",
      consentConfirmed: true
    });
  });

  it("calls updatePhotoMetadata when photo consent is toggled", async () => {
    updatePhotoMetadata.mockResolvedValue();
    const el = mount({ recordId: "a00ABC" });
    getPost.emit(POST_RECORD);
    getPostPhotos.emit(PHOTOS);
    await Promise.resolve();

    const consentCheckbox = el.shadowRoot.querySelector(
      ".photo-metadata-fields input[data-field='consentConfirmed']"
    );
    consentCheckbox.checked = false;
    consentCheckbox.dispatchEvent(new CustomEvent("change"));
    await Promise.resolve();

    expect(updatePhotoMetadata).toHaveBeenCalledWith({
      photoId: "p001",
      altText: "A beautiful peak",
      caption: "Sunset peak",
      credit: "Jane Member",
      consentConfirmed: false
    });
  });

  it("initializes recordId from CurrentPageReference when standalone", async () => {
    const originalLocation = window.location;
    delete window.location;
    window.location = new URL("https://example.com/lwrsite/newtrip");

    const el = mount();
    CurrentPageReference.emit({ state: { recordId: "a00XYZ" } });
    await Promise.resolve();

    expect(el.recordId).toBe("a00XYZ");

    window.location = originalLocation;
  });
});
