import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import basePath from "@salesforce/community/basePath";
import getPost from "@salesforce/apex/ContentPostController.getPost";
import getPostPhotos from "@salesforce/apex/ContentPostController.getPostPhotos";

// Post detail (plan §3.4): rich body + metadata + tags + author + date. Placed
// on the custom /post page, the id arrives as the ?recordId= URL param; it can
// also be set directly via the postId property, or come from page context
// (recordId) if ever placed on a record page.
export default class BlogPost extends LightningElement {
  @api recordId;
  @api postId;

  urlRecordId;
  post;
  errorMessage;

  get canEdit() {
    return this.post && this.post.canEdit;
  }

  get editUrl() {
    return `${basePath}/newtrip?recordId=${this.effectiveId}`;
  }

  photos = [];
  lightboxOpen = false;
  currentPhotoIndex = 0;
  _boundKeyHandler;

  @wire(CurrentPageReference)
  setPageRef(pageRef) {
    this.urlRecordId = pageRef?.state?.recordId;
  }

  get effectiveId() {
    return this.postId || this.urlRecordId || this.recordId;
  }

  @wire(getPost, { postId: "$effectiveId" })
  wiredPost({ data, error }) {
    if (data) {
      this.post = data;
      this.errorMessage = undefined;
      this.updateSeoTags();
    } else if (error) {
      this.errorMessage =
        error?.body?.message || "This post could not be loaded.";
      this.post = undefined;
    }
  }

  @wire(getPostPhotos, { postId: "$effectiveId" })
  wiredPhotos({ data, error }) {
    if (data) {
      this.photos = data;
      this.updateSeoTags();
    } else if (error) {
      console.error("Failed to load post photos", error);
    }
  }

  connectedCallback() {
    this._boundKeyHandler = this.handleKeyDown.bind(this);
  }

  disconnectedCallback() {
    window.removeEventListener("keydown", this._boundKeyHandler);
  }

  get hasPost() {
    return Boolean(this.post);
  }

  get meta() {
    if (!this.post) return "";
    const date = this.post.tripDate || this.post.publishDate;
    return [this.post.activity, this.post.location, date]
      .filter((x) => x)
      .join(" · ");
  }

  get tags() {
    return this.post?.displayTags || [];
  }

  get hasTags() {
    return this.tags.length > 0;
  }

  get hasPhotos() {
    return this.photos && this.photos.length > 0;
  }

  get processedPhotos() {
    if (!this.photos) return [];
    return this.photos.map((p) => {
      const isPortrait =
        p.aspectRatio === "4:5" ||
        p.aspectRatio === "3:4" ||
        p.aspectRatio === "Portrait" ||
        p.aspectRatio === "9:16";
      return {
        ...p,
        isPortrait
      };
    });
  }

  get formattedTripDate() {
    if (!this.post?.tripDate) return "";
    try {
      const date = new Date(this.post.tripDate);
      const options = { month: "short", year: "numeric", timeZone: "UTC" };
      return date.toLocaleDateString("en-US", options);
    } catch (e) {
      return "";
    }
  }

  get showNavigation() {
    return this.photos.length > 1;
  }

  get currentPhoto() {
    return this.photos[this.currentPhotoIndex];
  }

  get currentPhotoIndexDisplay() {
    return `${this.currentPhotoIndex + 1} of ${this.photos.length}`;
  }

  openLightbox(event) {
    this.currentPhotoIndex = parseInt(event.currentTarget.dataset.index, 10);
    this.lightboxOpen = true;
    window.addEventListener("keydown", this._boundKeyHandler);
  }

  closeLightbox() {
    this.lightboxOpen = false;
    window.removeEventListener("keydown", this._boundKeyHandler);
  }

  prevPhoto(event) {
    if (event) event.stopPropagation();
    if (this.photos.length <= 1) return;
    this.currentPhotoIndex =
      (this.currentPhotoIndex - 1 + this.photos.length) % this.photos.length;
  }

  nextPhoto(event) {
    if (event) event.stopPropagation();
    if (this.photos.length <= 1) return;
    this.currentPhotoIndex = (this.currentPhotoIndex + 1) % this.photos.length;
  }

  stopBubble(event) {
    event.stopPropagation();
  }

  handleKeyDown(event) {
    if (!this.lightboxOpen) return;
    if (event.key === "ArrowLeft") {
      this.prevPhoto();
    } else if (event.key === "ArrowRight") {
      this.nextPhoto();
    } else if (event.key === "Escape") {
      this.closeLightbox();
    }
  }

  updateSeoTags() {
    if (!this.post) return;

    document.title = `${this.post.title} | Spokane Mountaineers`;

    const description = this.stripHtml(this.post.body || "").substring(0, 160);
    this.setMetaTag("name", "description", description);
    this.setMetaTag("property", "og:title", this.post.title);
    this.setMetaTag("property", "og:description", description);
    this.setMetaTag("property", "og:type", "article");

    if (this.photos && this.photos.length > 0) {
      this.setMetaTag(
        "property",
        "og:image",
        this.photos[0].publicUrl || this.photos[0].memberUrl
      );
    }
  }

  setMetaTag(attrName, attrValue, content) {
    let element = document.head.querySelector(
      `meta[${attrName}="${attrValue}"]`
    );
    if (!element) {
      element = document.createElement("meta");
      element.setAttribute(attrName, attrValue);
      document.head.appendChild(element);
    }
    element.setAttribute("content", content);
  }

  stripHtml(html) {
    if (!html) return "";
    return html.replace(/<[^>]*>/g, "");
  }
}
