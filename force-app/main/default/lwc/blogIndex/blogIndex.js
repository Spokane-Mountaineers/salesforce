import { LightningElement, wire, track } from "lwc";
import getPublishedPosts from "@salesforce/apex/ContentPostController.getPublishedPosts";
import getActiveTags from "@salesforce/apex/ContentPostController.getActiveTags";

// Blog index / archive (plan §3.4): published posts with activity + tag chips,
// free-text search, and a browsable grid. Filters are reactive @wire params so
// the list re-queries as the member narrows down.
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

export default class BlogIndex extends LightningElement {
  @track activity = "";
  @track tag = "";
  @track search = "";

  posts;
  postsError;
  tags = [];

  @wire(getPublishedPosts, {
    activity: "$activity",
    tag: "$tag",
    search: "$search"
  })
  wiredPosts({ data, error }) {
    if (data) {
      this.posts = data;
      this.postsError = undefined;
    } else if (error) {
      this.postsError = this.reduceError(error);
      this.posts = [];
    }
  }

  @wire(getActiveTags)
  wiredTags({ data }) {
    if (data) this.tags = data;
  }

  get activityChips() {
    return ACTIVITIES.map((a) => ({
      label: a,
      value: a,
      cls: a === this.activity ? "chip chip--on" : "chip"
    }));
  }

  get tagChips() {
    return this.tags.map((t) => ({
      label: t.name,
      value: t.name,
      cls: t.name === this.tag ? "chip chip--on" : "chip"
    }));
  }

  get hasPosts() {
    return this.posts && this.posts.length > 0;
  }

  get isEmpty() {
    return this.posts && this.posts.length === 0 && !this.postsError;
  }

  get cards() {
    return (this.posts || []).map((p) => ({
      ...p,
      meta: [p.activity, p.location].filter((x) => x).join(" · ")
    }));
  }

  handleSearch(event) {
    this.search = event.target.value;
  }

  handleActivity(event) {
    const v = event.currentTarget.dataset.value;
    this.activity = this.activity === v ? "" : v;
  }

  handleTag(event) {
    const v = event.currentTarget.dataset.value;
    this.tag = this.tag === v ? "" : v;
  }

  clearFilters() {
    this.activity = "";
    this.tag = "";
    this.search = "";
    const box = this.template.querySelector(".search-box");
    if (box) box.value = "";
  }

  reduceError(error) {
    return error?.body?.message || "Something went wrong loading posts.";
  }
}
