import { LightningElement, wire, track } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
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

export default class BlogIndex extends NavigationMixin(LightningElement) {
  @track activity = "";
  @track selectedActivities = [];
  @track selectedTags = [];
  @track search = "";

  get tag() {
    return this.selectedTags.join(",");
  }

  @wire(CurrentPageReference)
  setCurrentPageReference(pageRef) {
    if (pageRef && pageRef.state) {
      if (pageRef.state.tag) {
        const rawTag = pageRef.state.tag;
        this.selectedTags = Array.isArray(rawTag)
          ? rawTag
          : rawTag
              .split(",")
              .map((t) => t.trim())
              .filter(Boolean);
      } else {
        this.selectedTags = [];
      }
      if (pageRef.state.activity) {
        const rawAct = pageRef.state.activity;
        this.selectedActivities = Array.isArray(rawAct)
          ? rawAct
          : rawAct
              .split(",")
              .map((a) => a.trim())
              .filter(Boolean);
        this.activity = this.selectedActivities.join(",");
      } else {
        this.selectedActivities = [];
        this.activity = "";
      }
      if (pageRef.state.search) {
        this.search = pageRef.state.search;
      } else {
        this.search = "";
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
      cls: this.selectedActivities.includes(a) ? "chip chip--on" : "chip"
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
    this.updateUrl();
  }

  handleActivity(event) {
    const v = event.currentTarget.dataset.value;
    if (this.selectedActivities.includes(v)) {
      this.selectedActivities = this.selectedActivities.filter((a) => a !== v);
    } else {
      this.selectedActivities = [...this.selectedActivities, v];
    }
    this.activity = this.selectedActivities.join(",");
    this.updateUrl();
  }

  handleTag(event) {
    const v = event.currentTarget.dataset.value;
    if (this.selectedTags.includes(v)) {
      this.selectedTags = this.selectedTags.filter((t) => t !== v);
    } else {
      this.selectedTags = [...this.selectedTags, v];
    }
    this.updateUrl();
  }

  clearFilters() {
    this.selectedActivities = [];
    this.activity = "";
    this.selectedTags = [];
    this.search = "";
    this.updateUrl();
  }

  updateUrl() {
    this[NavigationMixin.Navigate]({
      type: "standard__webPage",
      attributes: {
        url: this.buildUrl()
      }
    });
  }

  buildUrl() {
    let url = `${basePath}/blog`;
    const params = [];
    if (this.selectedActivities.length > 0) {
      params.push(
        `activity=${encodeURIComponent(this.selectedActivities.join(","))}`
      );
    }
    if (this.selectedTags.length > 0) {
      params.push(`tag=${encodeURIComponent(this.selectedTags.join(","))}`);
    }
    if (this.search) {
      params.push(`search=${encodeURIComponent(this.search)}`);
    }
    if (params.length > 0) {
      url += `?${params.join("&")}`;
    }
    return url;
  }

  reduceError(error) {
    return error?.body?.message || "Something went wrong loading posts.";
  }
}
