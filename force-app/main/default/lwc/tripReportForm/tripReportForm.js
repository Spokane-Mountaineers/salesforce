import { LightningElement, track } from "lwc";
import createTripReport from "@salesforce/apex/ContentPostController.createTripReport";

// Member-facing trip-report authoring (plan §3.3). A purpose-built form, not the
// raw record edit page: title, body, activity + difficulty pickers, trip date,
// location, and free tags. On submit it calls createTripReport (Trip Report
// record type, member-owned, Internal-publishes-on-submit) and emits a
// `created` event with the new id so the host page can navigate to it.
//
// Body is plain text for now; rich text + inline image upload (Files) is the
// planned enhancement (§3.1/§3.4) — the Body__c field already stores HTML.
const ACTIVITIES = [
  "Climbing",
  "Hiking",
  "Skiing",
  "Paddling",
  "Backpacking",
  "Conservation",
  "Social",
  "Other"
];
const DIFFICULTIES = ["Easy", "Moderate", "Strenuous", "Technical"];

export default class TripReportForm extends LightningElement {
  @track form = {
    title: "",
    body: "",
    activity: "",
    tripDate: null,
    location: "",
    difficulty: "",
    freeTags: ""
  };
  @track submitting = false;
  @track errorMessage = "";

  activityOptions = ACTIVITIES;
  difficultyOptions = DIFFICULTIES;

  handleChange(event) {
    const field = event.target.dataset.field;
    this.form = { ...this.form, [field]: event.target.value };
  }

  get titleMissing() {
    return !this.form.title || !this.form.title.trim();
  }

  async handleSubmit(event) {
    if (event) event.preventDefault();
    this.errorMessage = "";
    if (this.titleMissing) {
      this.errorMessage = "Please give your trip report a title.";
      return;
    }
    this.submitting = true;
    try {
      const id = await createTripReport({
        title: this.form.title,
        body: this.form.body,
        activity: this.form.activity,
        tripDate: this.form.tripDate || null,
        location: this.form.location,
        difficulty: this.form.difficulty,
        freeTags: this.form.freeTags
      });
      this.dispatchEvent(new CustomEvent("created", { detail: { id } }));
    } catch (e) {
      this.errorMessage =
        e?.body?.message || "Sorry — your trip report could not be saved.";
    } finally {
      this.submitting = false;
    }
  }
}
