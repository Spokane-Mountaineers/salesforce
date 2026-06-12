import { LightningElement, api } from "lwc";

// Hero image (plan §9.5): a full-bleed photograph with a scrim so overlaid
// display type stays legible — never raw text on a busy photo. The structured
// eyebrow/title/subtitle cover the common case; the default slot lets a page
// drop in extra overlay content (e.g. CTA buttons).
export default class SmiHeroImage extends LightningElement {
  @api imageUrl;
  @api alt = "";
  @api eyebrow;
  @api heading;
  @api subtitle;

  get hasEyebrow() {
    return Boolean(this.eyebrow);
  }
  get hasHeading() {
    return Boolean(this.heading);
  }
  get hasSubtitle() {
    return Boolean(this.subtitle);
  }
}
