import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getPost from "@salesforce/apex/ContentPostController.getPost";

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
    } else if (error) {
      this.errorMessage =
        error?.body?.message || "This post could not be loaded.";
      this.post = undefined;
    }
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
    return this.post?.freeTags || [];
  }

  get hasTags() {
    return this.tags.length > 0;
  }
}
