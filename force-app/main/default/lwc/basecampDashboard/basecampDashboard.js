import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import isGuest from "@salesforce/user/isGuest";
import USER_ID from "@salesforce/user/Id";
import NAME_FIELD from "@salesforce/schema/User.FirstName";
import getMyRegistrations from "@salesforce/apex/EventController.getMyRegistrations";
import getPublishedPosts from "@salesforce/apex/ContentPostController.getPublishedPosts";
import basePath from "@salesforce/community/basePath";

// "Basecamp" member dashboard (plan §9.4, Option A): the staging point a member
// organizes from — upcoming events, quick actions, and the latest from their
// activities. Utility-first, no dominant feed. Composes the events + blog
// controllers already built in Phases 1–2.
const MAX_POSTS = 4;

export default class BasecampDashboard extends LightningElement {
  // Quick-action targets — Builder-configurable so links track real routes.
  @api tripReportHref = "/trip-report/new";
  @api eventsHref = "/events";
  @api slackHref;
  @api memberCardHref = "/my-membership";

  firstName;
  registrations = [];
  posts = [];

  get isGuest() {
    return isGuest;
  }

  withBase(href) {
    if (!href || !href.startsWith("/")) {
      return href;
    }
    return `${basePath}${href === "/" ? "" : href}` || "/";
  }

  get resolvedTripReportHref() {
    let href = this.tripReportHref;
    if (href && href.includes("trip-report/new")) {
      href = "/newtrip";
    }
    return this.withBase(href);
  }

  get resolvedEventsHref() {
    return this.withBase(this.eventsHref);
  }

  get resolvedMemberCardHref() {
    return this.withBase(this.memberCardHref);
  }

  get resolvedSlackHref() {
    return this.withBase(this.slackHref);
  }

  @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD] })
  wiredUser({ data }) {
    if (data) this.firstName = getFieldValue(data, NAME_FIELD);
  }

  @wire(getMyRegistrations)
  wiredRegs({ data }) {
    if (data) this.registrations = data;
  }

  @wire(getPublishedPosts, { activity: "", tag: "", search: "" })
  wiredPosts({ data }) {
    if (data) this.posts = data.slice(0, MAX_POSTS);
  }

  get greeting() {
    return this.firstName ? `Welcome back, ${this.firstName}` : "Basecamp";
  }

  get hasRegistrations() {
    return this.registrations.length > 0;
  }

  get upcoming() {
    return this.registrations.slice(0, 6).map((e) => ({
      id: e.id,
      name: e.name,
      activityGroup: e.activityGroup,
      startTime: e.startTime,
      location: e.location,
      detailUrl: `${basePath}/event?recordId=${e.id}`
    }));
  }

  get hasPosts() {
    return this.posts.length > 0;
  }

  get latestPosts() {
    return this.posts.map((p) => ({
      id: p.id,
      title: p.title,
      meta: [p.activity, p.location].filter((x) => x).join(" · "),
      detailUrl: `${basePath}/post?recordId=${p.id}`
    }));
  }

  get showSlack() {
    return Boolean(this.slackHref);
  }
}
