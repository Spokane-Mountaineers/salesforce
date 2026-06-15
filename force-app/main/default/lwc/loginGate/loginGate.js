import { LightningElement, api } from "lwc";
import basePath from "@salesforce/community/basePath";

// Friendly "please sign in" card for guests who reach member-only content (e.g.
// a bookmarked page). The Sign in link carries the current page as startURL so
// login returns the member to where they were headed.
export default class LoginGate extends LightningElement {
  @api heading = "Members only";
  @api message =
    "Please sign in with your Spokane Mountaineers account to view this page.";

  get loginUrl() {
    const base = `${basePath}/login`;
    try {
      const here = window.location.pathname + window.location.search;
      return `${base}?startURL=${encodeURIComponent(here)}`;
    } catch (e) {
      return base;
    }
  }

  get homeUrl() {
    return `${basePath}/` || "/";
  }
}
