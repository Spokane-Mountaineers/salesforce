import { LightningElement, wire, track } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import basePath from "@salesforce/community/basePath";
import isGuest from "@salesforce/user/isGuest";
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
  @track selectedTags = [];
  @track search = "";

  get tag() {
    return this.selectedTags.join(",");
  }

  @wire(CurrentPageReference)
  setCurrentPageReference(pageRef) {
    if (pageRef && pageRef.state) {
      if (pageRef.state.tag) {
        const urlTag = pageRef.state.tag;
        if (!this.selectedTags.includes(urlTag)) {
          this.selectedTags = [urlTag];
        }
      }
      if (pageRef.state.activity) {
        this.activity = pageRef.state.activity;
      }
    }
  }

  get showNewReportLink() {
    return true;
  }

  get newReportUrl() {
    if (isGuest) {
      return `${basePath}/login?startURL=${encodeURIComponent(basePath + "/newtrip")}`;
    }
    return `${basePath}/newtrip`;
  }

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
      cls: this.selectedTags.includes(t.name) ? "chip chip--on" : "chip"
    }));
  }

  get hasPosts() {
    return this.posts && this.posts.length > 0;
  }

  get isEmpty() {
    return this.posts && this.posts.length === 0 && !this.postsError;
  }

  withMeta(p) {
    return {
      ...p,
      meta: [p.activity, p.location].filter((x) => x).join(" · "),
      detailUrl: `${basePath}/post?recordId=${p.id}`
    };
  }

  // Editorial layout: the newest post leads, the rest form a hairline ledger.
  get leadPost() {
    return this.hasPosts ? this.withMeta(this.posts[0]) : null;
  }

  get restPosts() {
    return (this.posts || []).slice(1).map((p) => this.withMeta(p));
  }

  get hasRest() {
    return this.restPosts.length > 0;
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
    if (this.selectedTags.includes(v)) {
      this.selectedTags = this.selectedTags.filter((t) => t !== v);
    } else {
      this.selectedTags = [...this.selectedTags, v];
    }
  }

  clearFilters() {
    this.activity = "";
    this.selectedTags = [];
    this.search = "";
    const box = this.template.querySelector(".search-box");
    if (box) box.value = "";
  }

  reduceError(error) {
    return error?.body?.message || "Something went wrong loading posts.";
  }
}
