import { LightningElement, api, wire } from "lwc";
import basePath from "@salesforce/community/basePath";
import login from "@salesforce/apex/CommunityLoginController.login";
import getLoginConfig from "@salesforce/apex/CommunityLoginController.getLoginConfig";

// Alpine Field Guide login for the LWR site (plan §8). Username/password via
// CommunityLoginController.login (which does the .smi normalization + Site.login
// and returns a redirect URL), plus Google/Microsoft SSO links. Self-reg stays
// off — membership is driven by DonorBox.
export default class CommunityLogin extends LightningElement {
  @api heading = "Member sign in";
  @api backgroundUrl; // optional landscape photo behind the card

  username = "";
  password = "";
  errorMessage;
  busy = false;
  config;

  @wire(getLoginConfig)
  wiredConfig({ data }) {
    if (data) this.config = data;
  }

  get startUrl() {
    try {
      return new URLSearchParams(window.location.search).get("startURL") || "";
    } catch (e) {
      return "";
    }
  }

  get rootStyle() {
    return this.backgroundUrl
      ? `background-image: var(--smi-scrim), url(${this.backgroundUrl});`
      : "";
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  get googleUrl() {
    return this.config && this.config.googleUrl;
  }

  get microsoftUrl() {
    return this.config && this.config.microsoftUrl;
  }

  // Stay inside the LWR experience site (basePath = /lwrsite) → the branded
  // /ForgotPassword route, not the control site's force.com VF page that
  // Site.getBaseUrl() resolves to.
  get forgotUrl() {
    return `${basePath}/ForgotPassword`;
  }

  handleChange(event) {
    this[event.target.dataset.field] = event.target.value;
  }

  async handleSubmit(event) {
    if (event) event.preventDefault();
    this.errorMessage = undefined;
    this.busy = true;
    try {
      const result = await login({
        username: this.username,
        password: this.password,
        startUrl: this.startUrl
      });
      if (result && result.success && result.redirectUrl) {
        window.location.href = result.redirectUrl;
      } else {
        this.errorMessage =
          (result && result.message) || "Sign-in failed. Please try again.";
      }
    } catch (err) {
      this.errorMessage =
        err && err.body && err.body.message
          ? err.body.message
          : "Sign-in failed. Please try again.";
    } finally {
      this.busy = false;
    }
  }
}
