import { LightningElement, api, wire } from "lwc";
import getPost from "@salesforce/apex/ContentPostController.getPost";

// Post detail (plan §3.4): rich body + metadata + tags + author + date. Placed
// on the post record page, so recordId comes from the page; it can also be set
// directly via the postId property.
export default class BlogPost extends LightningElement {
  @api recordId;
  @api postId;

  post;
  errorMessage;

  get effectiveId() {
    return this.postId || this.recordId;
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
