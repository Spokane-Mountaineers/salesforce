import { LightningElement, track, api, wire } from "lwc";
import createTripReport from "@salesforce/apex/ContentPostController.createTripReport";
import updateTripReport from "@salesforce/apex/ContentPostController.updateTripReport";
import deleteOwnDraft from "@salesforce/apex/ContentPostController.deleteOwnDraft";
import getPost from "@salesforce/apex/ContentPostController.getPost";
import getActiveTags from "@salesforce/apex/ContentPostController.getActiveTags";

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
  @api recordId;

  @track form = {
    title: "",
    body: "",
    activity: "",
    tripDate: null,
    location: "",
    difficulty: "",
    freeTags: ""
  };
  @track selectedTagIds = [];
  @track controlledTags = [];
  @track submitting = false;
  @track errorMessage = "";

  postRecord;
  allTags = [];
  activityOptions = ACTIVITIES;
  difficultyOptions = DIFFICULTIES;

  @wire(getActiveTags)
  wiredTags({ data }) {
    if (data) {
      this.allTags = data;
      this.formatTags();
    }
  }

  @wire(getPost, { postId: "$recordId" })
  wiredPost({ data, error }) {
    if (data) {
      this.postRecord = data;
      this.form = {
        title: data.title || "",
        body: data.body || "",
        activity: data.activity || "",
        tripDate: data.tripDate || null,
        location: data.location || "",
        difficulty: data.difficulty || "",
        freeTags: (data.freeTags || []).join(", ")
      };
      this.selectedTagIds = data.tagIds || [];
      this.formatTags();
    } else if (error) {
      if (this.recordId) {
        this.errorMessage =
          error?.body?.message || "Failed to load trip report details.";
      }
    }
  }

  formatTags() {
    if (!this.allTags || this.allTags.length === 0) return;
    this.controlledTags = this.allTags.map((t) => ({
      id: t.id,
      name: t.name,
      className: this.selectedTagIds.includes(t.id) ? "chip chip--on" : "chip"
    }));
  }

  get hasControlledTags() {
    return this.controlledTags && this.controlledTags.length > 0;
  }

  get eyebrowText() {
    return this.recordId ? "Edit Trip Report" : "New Trip Report";
  }

  get titleText() {
    return this.recordId ? "Update your report" : "Share where you went";
  }

  get isDraftEdit() {
    return this.recordId && this.postRecord?.status === "Draft";
  }

  handleChange(event) {
    const field = event.target.dataset.field;
    this.form = { ...this.form, [field]: event.target.value };
  }

  handleToggleTag(event) {
    const tagId = event.target.dataset.id;
    if (this.selectedTagIds.includes(tagId)) {
      this.selectedTagIds = this.selectedTagIds.filter((id) => id !== tagId);
    } else {
      this.selectedTagIds = [...this.selectedTagIds, tagId];
    }
    this.formatTags();
  }

  get titleMissing() {
    return !this.form.title || !this.form.title.trim();
  }

  handleSubmit(event) {
    if (event) event.preventDefault();
    this.handleSavePublish();
  }

  async handleSaveDraft() {
    await this.savePost("Draft");
  }

  async handleSavePublish() {
    await this.savePost("Published");
  }

  async savePost(status) {
    this.errorMessage = "";
    if (this.titleMissing) {
      this.errorMessage = "Please give your trip report a title.";
      return;
    }
    this.submitting = true;
    try {
      if (this.recordId) {
        await updateTripReport({
          postId: this.recordId,
          title: this.form.title,
          body: this.form.body,
          activity: this.form.activity,
          tripDate: this.form.tripDate || null,
          location: this.form.location,
          difficulty: this.form.difficulty,
          freeTags: this.form.freeTags,
          status: status,
          tagIds: this.selectedTagIds
        });
        this.dispatchEvent(
          new CustomEvent("updated", { detail: { id: this.recordId } })
        );
      } else {
        const id = await createTripReport({
          title: this.form.title,
          body: this.form.body,
          activity: this.form.activity,
          tripDate: this.form.tripDate || null,
          location: this.form.location,
          difficulty: this.form.difficulty,
          freeTags: this.form.freeTags,
          tagIds: this.selectedTagIds
        });

        if (status === "Published") {
          await updateTripReport({
            postId: id,
            title: this.form.title,
            body: this.form.body,
            activity: this.form.activity,
            tripDate: this.form.tripDate || null,
            location: this.form.location,
            difficulty: this.form.difficulty,
            freeTags: this.form.freeTags,
            status: "Published",
            tagIds: this.selectedTagIds
          });
        }
        this.dispatchEvent(new CustomEvent("created", { detail: { id } }));
      }
    } catch (e) {
      this.errorMessage =
        e?.body?.message || "Sorry — your trip report could not be saved.";
    } finally {
      this.submitting = false;
    }
  }

  async handleDeleteDraft() {
    if (!this.recordId) return;
    this.errorMessage = "";
    this.submitting = true;
    try {
      await deleteOwnDraft({ postId: this.recordId });
      this.dispatchEvent(new CustomEvent("deleted"));
    } catch (e) {
      this.errorMessage =
        e?.body?.message || "Sorry — the draft could not be deleted.";
    } finally {
      this.submitting = false;
    }
  }

  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }
}
