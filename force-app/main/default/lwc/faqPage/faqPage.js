import { LightningElement } from "lwc";
import { loadStyle } from "lightning/platformResourceLoader";
import FAQ_FONTS from "@salesforce/resourceUrl/faq_fonts";
import FAQ_IMAGES from "@salesforce/resourceUrl/member_faq_images";

/**
 * Member-facing FAQ page for the Experience Cloud site (Support > FAQ).
 * Content mirrors docs/members/*.md. Fonts and screenshots are bundled as
 * static resources, so the component has no runtime CDN dependency.
 */
export default class FaqPage extends LightningElement {
  _fontsLoaded = false;

  // Lightbox (click a screenshot to enlarge).
  lightboxSrc = null;
  lightboxAlt = "";

  connectedCallback() {
    this._onKeydown = (event) => {
      if (event.key === "Escape") {
        this.closeLightbox();
      }
    };
    window.addEventListener("keydown", this._onKeydown);
  }

  disconnectedCallback() {
    window.removeEventListener("keydown", this._onKeydown);
  }

  get isLightboxOpen() {
    return this.lightboxSrc !== null;
  }

  openLightbox(event) {
    const img = event.currentTarget;
    this.lightboxSrc = img.src;
    this.lightboxAlt = img.alt;
  }

  closeLightbox() {
    this.lightboxSrc = null;
    this.lightboxAlt = "";
  }

  renderedCallback() {
    if (this._fontsLoaded) {
      return;
    }
    this._fontsLoaded = true;
    // Bundled @font-face stylesheet; design degrades to serif/sans fallbacks if it fails.
    loadStyle(this, `${FAQ_FONTS}/fonts.css`).catch(() => {});
  }

  get imgPasswordReset() {
    return `${FAQ_IMAGES}/password-reset.png`;
  }
  get imgMyProfile() {
    return `${FAQ_IMAGES}/my-profile.png`;
  }
  get imgProfileVisibility() {
    return `${FAQ_IMAGES}/profile-visibility-settings.png`;
  }
  get imgNewMessage() {
    return `${FAQ_IMAGES}/new-message-alert.png`;
  }
  get imgCalendarMenu() {
    return `${FAQ_IMAGES}/calendar-of-events-menu.png`;
  }
  get imgCalendarMonth() {
    return `${FAQ_IMAGES}/calendar-month-view.png`;
  }
  get imgEventsList() {
    return `${FAQ_IMAGES}/events-list-view.png`;
  }
  get imgMemberDocuments() {
    return `${FAQ_IMAGES}/member-documents.png`;
  }

  handleTocClick(event) {
    event.preventDefault();
    const { target } = event.currentTarget.dataset;
    const section = this.template.querySelector(`[data-section="${target}"]`);
    if (!section) {
      return;
    }
    const reduce = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    section.scrollIntoView({
      behavior: reduce ? "auto" : "smooth",
      block: "start"
    });
  }
}
