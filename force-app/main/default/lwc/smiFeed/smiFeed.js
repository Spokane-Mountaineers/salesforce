import { LightningElement, api, wire, track } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getFeed from "@salesforce/apex/ChatterPublisherController.getFeed";
import postToChatter from "@salesforce/apex/ChatterPublisherController.postToChatter";

// In-site feed (plan §4.4) — a clean pure-LWR rewrite of the SLDS
// chatterPublisherWithAutosave: compose + recent posts for a group, with
// localStorage draft autosave. Durable authored content lives in the blog
// (Content_Post__c); this is the lightweight announcements/discussion feed.
export default class SmiFeed extends LightningElement {
  @api groupId;
  @api heading = "Club Feed";

  @track draft = "";
  @track posting = false;
  @track errorMessage;
  posts = [];
  _wired;

  get storageKey() {
    return `smiFeedDraft:${this.groupId || "default"}`;
  }

  connectedCallback() {
    try {
      const saved = window.localStorage.getItem(this.storageKey);
      if (saved) this.draft = saved;
    } catch (e) {
      // localStorage unavailable — drafts just won't persist.
    }
  }

  @wire(getFeed, { groupId: "$groupId" })
  wiredFeed(result) {
    this._wired = result;
    if (result.data) {
      this.posts = result.data.map((p) => ({
        ...p,
        excerpt: this.toText(p.body)
      }));
    }
  }

  get hasPosts() {
    return this.posts.length > 0;
  }

  get canPost() {
    return !this.posting && this.draft && this.draft.trim().length > 0;
  }

  get postDisabled() {
    return !this.canPost;
  }

  toText(html) {
    if (!html) return "";
    return html
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<\/p>/gi, "\n")
      .replace(/<[^>]+>/g, "")
      .trim();
  }

  handleInput(event) {
    this.draft = event.target.value;
    try {
      window.localStorage.setItem(this.storageKey, this.draft);
    } catch (e) {
      // ignore persistence failures
    }
  }

  async handlePost() {
    if (!this.canPost) return;
    this.posting = true;
    this.errorMessage = undefined;
    try {
      await postToChatter({ groupId: this.groupId, content: this.draft });
      this.draft = "";
      try {
        window.localStorage.removeItem(this.storageKey);
      } catch (e) {
        // ignore
      }
      if (this._wired) await refreshApex(this._wired);
    } catch (e) {
      this.errorMessage =
        e && e.body && e.body.message
          ? e.body.message
          : "Your post couldn't be shared. Please try again.";
    } finally {
      this.posting = false;
    }
  }
}
