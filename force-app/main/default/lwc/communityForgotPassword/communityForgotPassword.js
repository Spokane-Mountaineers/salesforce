import { LightningElement, api } from "lwc";
import basePath from "@salesforce/community/basePath";
import requestPasswordReset from "@salesforce/apex/CommunityLoginController.requestPasswordReset";

// Alpine Field Guide forgot-password for the LWR site (plan §8), matching the
// communityLogin card. Calls CommunityLoginController.requestPasswordReset
// (Site.forgotPassword + the .smi normalization). Always confirms success so
// it never reveals whether an account exists. Replaces the stock
// community_login:forgotPassword and the legacy force.com VF page.
export default class CommunityForgotPassword extends LightningElement {
  @api heading = "Reset your password";
  @api backgroundUrl; // optional landscape photo behind the card

  username = "";
  errorMessage;
  busy = false;
  done = false;

  get rootStyle() {
    return this.backgroundUrl
      ? `background-image: var(--smi-scrim), url(${this.backgroundUrl});`
      : "";
  }

  get hasError() {
    return Boolean(this.errorMessage);
  }

  // Stay inside the LWR experience site (basePath = /lwrsite) — never link out
  // to the control site's force.com auth pages.
  get loginUrl() {
    return `${basePath}/login`;
  }

  handleChange(event) {
    this.username = event.target.value;
  }

  async handleSubmit(event) {
    if (event) event.preventDefault();
    this.errorMessage = undefined;
    this.busy = true;
    try {
      const result = await requestPasswordReset({ username: this.username });
      if (result && result.success) {
        this.done = true;
      } else {
        this.errorMessage =
          (result && result.message) ||
          "Something went wrong. Please try again.";
      }
    } catch (err) {
      this.errorMessage =
        err && err.body && err.body.message
          ? err.body.message
          : "Something went wrong. Please try again.";
    } finally {
      this.busy = false;
    }
  }
}
