import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getMyPosts from "@salesforce/apex/ContentPostController.getMyPosts";
import deleteOwnDraft from "@salesforce/apex/ContentPostController.deleteOwnDraft";
import basePath from "@salesforce/community/basePath";

export default class MyTripReports extends LightningElement {
  @track editingPostId = null;
  @track creatingPost = false;
  @track errorMessage = "";

  wiredPostsResult;
  posts = [];

  @wire(getMyPosts)
  wiredPosts(result) {
    this.wiredPostsResult = result;
    if (result.data) {
      this.posts = result.data.map((p) => ({
        ...p,
        meta: [p.activity, p.location, p.tripDate || p.publishDate]
          .filter((x) => x)
          .join(" · "),
        detailUrl: `${basePath}/post?recordId=${p.id}`
      }));
      this.errorMessage = undefined;
    } else if (result.error) {
      this.errorMessage =
        result.error?.body?.message || "Failed to load your trip reports.";
      this.posts = [];
    }
  }

  get drafts() {
    return this.posts.filter((p) => p.status === "Draft");
  }

  get published() {
    return this.posts.filter((p) => p.status === "Published");
  }

  get hasDrafts() {
    return this.drafts.length > 0;
  }

  get hasPublished() {
    return this.published.length > 0;
  }

  handleNewPost() {
    this.creatingPost = true;
    this.editingPostId = null;
  }

  handleEdit(event) {
    const postId = event.target.dataset.id;
    this.editingPostId = postId;
    this.creatingPost = false;
  }

  async handleDelete(event) {
    const postId = event.target.dataset.id;
    this.errorMessage = "";
    try {
      await deleteOwnDraft({ postId });
      await refreshApex(this.wiredPostsResult);
    } catch (e) {
      this.errorMessage = e?.body?.message || "Could not delete this draft.";
    }
  }

  async handleFormSuccess() {
    this.creatingPost = false;
    this.editingPostId = null;
    await refreshApex(this.wiredPostsResult);
  }

  async handleFormDeleted() {
    this.creatingPost = false;
    this.editingPostId = null;
    await refreshApex(this.wiredPostsResult);
  }

  handleFormCancel() {
    this.creatingPost = false;
    this.editingPostId = null;
  }
}
