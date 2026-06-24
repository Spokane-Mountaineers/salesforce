import { LightningElement, track, api, wire } from "lwc";
import createTripReport from "@salesforce/apex/ContentPostController.createTripReport";
import updateTripReport from "@salesforce/apex/ContentPostController.updateTripReport";
import deleteOwnDraft from "@salesforce/apex/ContentPostController.deleteOwnDraft";
import getPost from "@salesforce/apex/ContentPostController.getPost";
import getActiveTags from "@salesforce/apex/ContentPostController.getActiveTags";
import uploadPhoto from "@salesforce/apex/ContentPostController.uploadPhoto";
import getPostPhotos from "@salesforce/apex/ContentPostController.getPostPhotos";
import updatePhotoMetadata from "@salesforce/apex/ContentPostController.updatePhotoMetadata";
import deletePhoto from "@salesforce/apex/ContentPostController.deletePhoto";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin, CurrentPageReference } from "lightning/navigation";
import basePath from "@salesforce/community/basePath";

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

export default class TripReportForm extends NavigationMixin(LightningElement) {
  @track _recordId;

  @wire(CurrentPageReference)
  setCurrentPageReference(pageRef) {
    if (pageRef && pageRef.state) {
      const rid = pageRef.state.recordId;
      if (rid && this.isStandalone()) {
        this._recordId = rid;
      }
    }
  }

  @api
  get recordId() {
    return this._recordId;
  }
  set recordId(value) {
    this._recordId = value;
  }

  isStandalone() {
    try {
      return window.location.pathname.includes("/newtrip");
    } catch (e) {
      return false;
    }
  }

  navigateToPost(postId) {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url: `${basePath}/post?recordId=${postId}`
      }
    });
  }

  navigateToBlog() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url: `${basePath}/blog`
      }
    });
  }

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
  @track photos = [];
  @track isUploading = false;

  wiredPhotosResult;

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

  @wire(getPostPhotos, { postId: "$_recordId" })
  wiredGetPostPhotos(result) {
    this.wiredPhotosResult = result;
    if (result.data) {
      this.photos = result.data;
      this.errorMessage = "";
    } else if (result.error) {
      if (this.recordId) {
        this.errorMessage =
          result.error?.body?.message || "Failed to load photos.";
      }
    }
  }

  get hasPhotos() {
    return this.photos && this.photos.length > 0;
  }

  @wire(getPost, { postId: "$_recordId" })
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

    if (status === "Published" && this.hasPhotos) {
      for (const photo of this.photos) {
        if (!photo.altText || !photo.altText.trim()) {
          this.errorMessage =
            "Please provide Alt Text for all uploaded photos before publishing.";
          return;
        }
        if (!photo.consentConfirmed) {
          this.errorMessage =
            "Please confirm consent for all uploaded photos before publishing.";
          return;
        }
      }
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
        if (status === "Published" && this.isStandalone()) {
          this.navigateToPost(this.recordId);
        }
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
        this._recordId = id;
        this.dispatchEvent(new CustomEvent("created", { detail: { id } }));
        if (status === "Published" && this.isStandalone()) {
          this.navigateToPost(id);
        }
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
      if (this.isStandalone()) {
        this.navigateToBlog();
      }
    } catch (e) {
      this.errorMessage =
        e?.body?.message || "Sorry — the draft could not be deleted.";
    } finally {
      this.submitting = false;
    }
  }

  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
    if (this.isStandalone()) {
      this.navigateToBlog();
    }
  }

  async handleFileChange(event) {
    const files = Array.from(event.target.files);
    if (!files.length) return;

    if (this.photos.length + files.length > 15) {
      this.errorMessage = "You can upload up to 15 photos in a trip report.";
      return;
    }

    this.isUploading = true;
    this.errorMessage = "";

    try {
      for (const file of files) {
        // eslint-disable-next-line no-await-in-loop
        const processed = await this.processAndUploadFile(file);
        // eslint-disable-next-line no-await-in-loop
        await uploadPhoto({
          postId: this.recordId,
          fileName: processed.fileName,
          base64Data: processed.base64Data,
          altText: "Photo from " + (this.form.title || "trip report"),
          caption: "",
          credit: "",
          consentConfirmed: false,
          sortOrder: this.photos.length + 1,
          aspectRatio: processed.aspectRatio
        });
      }
      await refreshApex(this.wiredPhotosResult);
    } catch (e) {
      this.errorMessage =
        e?.body?.message ||
        e?.message ||
        "Failed to upload one or more photos.";
    } finally {
      this.isUploading = false;
      const inputEl = this.template.querySelector(".photo-file-input");
      if (inputEl) {
        inputEl.value = "";
      }
    }
  }

  processAndUploadFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          try {
            const canvas = document.createElement("canvas");
            let width = img.width;
            let height = img.height;

            const MAX_WIDTH = 1920;
            const MAX_HEIGHT = 1080;

            if (width > MAX_WIDTH || height > MAX_HEIGHT) {
              const widthRatio = MAX_WIDTH / width;
              const heightRatio = MAX_HEIGHT / height;
              const bestRatio = Math.min(widthRatio, heightRatio);
              width = Math.round(width * bestRatio);
              height = Math.round(height * bestRatio);
            }

            canvas.width = width;
            canvas.height = height;

            const ctx = canvas.getContext("2d");
            ctx.drawImage(img, 0, 0, width, height);

            const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
            const base64Data = dataUrl.split(",")[1];
            const aspectRatio = this.calculateAspectRatio(width, height);

            resolve({
              fileName: file.name,
              base64Data,
              aspectRatio
            });
          } catch (err) {
            reject(err);
          }
        };
        img.onerror = () => {
          reject(new Error("Failed to load image into element"));
        };
        img.src = e.target.result;
      };
      reader.onerror = () => {
        reject(new Error("Failed to read file"));
      };
      reader.readAsDataURL(file);
    });
  }

  calculateAspectRatio(width, height) {
    const ratio = width / height;
    if (Math.abs(ratio - 1) < 0.15) {
      return "1:1";
    } else if (Math.abs(ratio - 1.5) < 0.15 || Math.abs(ratio - 0.67) < 0.15) {
      return ratio > 1 ? "3:2" : "2:3";
    } else if (Math.abs(ratio - 1.33) < 0.15 || Math.abs(ratio - 0.75) < 0.15) {
      return ratio > 1 ? "4:3" : "3:4";
    } else if (Math.abs(ratio - 1.78) < 0.15 || Math.abs(ratio - 0.56) < 0.15) {
      return ratio > 1 ? "16:9" : "9:16";
    } else if (Math.abs(ratio - 1.25) < 0.15 || Math.abs(ratio - 0.8) < 0.15) {
      return ratio > 1 ? "5:4" : "4:5";
    }
    return ratio > 1 ? "Landscape" : "Portrait";
  }

  async handleDeletePhoto(event) {
    const photoId = event.target.dataset.id;
    this.errorMessage = "";
    try {
      await deletePhoto({ photoId });
      await refreshApex(this.wiredPhotosResult);
    } catch (e) {
      this.errorMessage = e?.body?.message || "Failed to delete photo.";
    }
  }

  handlePhotoMetadataBlur(event) {
    const photoId = event.target.dataset.id;
    const field = event.target.dataset.field;
    const value = event.target.value;

    const photo = this.photos.find((p) => p.id === photoId);
    if (!photo) return;
    if (photo[field] === value) return;

    this.updatePhoto(photoId, field, value);
  }

  handlePhotoConsentChange(event) {
    const photoId = event.target.dataset.id;
    const value = event.target.checked;
    this.updatePhoto(photoId, "consentConfirmed", value);
  }

  async updatePhoto(photoId, field, value) {
    this.photos = this.photos.map((p) => {
      if (p.id === photoId) {
        return { ...p, [field]: value };
      }
      return p;
    });

    const photo = this.photos.find((p) => p.id === photoId);
    try {
      await updatePhotoMetadata({
        photoId: photoId,
        altText: photo.altText,
        caption: photo.caption,
        credit: photo.credit,
        consentConfirmed: photo.consentConfirmed
      });
    } catch (e) {
      this.errorMessage = e?.body?.message || "Failed to update photo details.";
      await refreshApex(this.wiredPhotosResult);
    }
  }
}
