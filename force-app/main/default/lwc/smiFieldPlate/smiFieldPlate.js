import { LightningElement, api } from "lwc";

// Field plate (plan §9.5): a photograph catalogued like a naturalist's
// specimen — keyline frame + a caption in the field-guide voice (small-caps
// activity · location · date eyebrow over a Fraunces-italic title). Ties member
// photos to trip-report/event metadata so disparate images feel like one body
// of work.
export default class SmiFieldPlate extends LightningElement {
  @api imageUrl;
  @api alt = "";
  @api activity; // e.g. "Rock"
  @api location; // e.g. "Minnehaha"
  @api plateDate; // pre-formatted, e.g. "Sep 2025"
  @api title; // optional Fraunces-italic line
  @api portrait = false;

  get rootClass() {
    return this.portrait
      ? "smi-field-plate smi-field-plate--portrait"
      : "smi-field-plate";
  }

  // "ROCK · Minnehaha · Sep 2025" — only the parts that are present.
  get meta() {
    return [this.activity, this.location, this.plateDate]
      .filter((part) => part)
      .join(" · ");
  }

  get hasMeta() {
    return Boolean(this.meta);
  }
}
