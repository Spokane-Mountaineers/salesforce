import { LightningElement, api } from "lwc";
import basePath from "@salesforce/community/basePath";
import CONTENT_ASSETS from "@salesforce/resourceUrl/content_assets";

/**
 * Reusable Alpine Field Guide content page for ported legacy marketing/info
 * pages (plan: 2026-06-12 content port). A page is a hero (gradient, or a
 * full-bleed photo when heroImageUrl is set) over a readable prose column with
 * an optional "related links" rail.
 *
 * bodyHtml is trusted, pre-cleaned markup migrated from the legacy Aura site
 * (inline font-size/color stripped at migration time). It's injected into this
 * component's own shadow root via lwc:dom="manual" so the field-guide prose CSS
 * styles it — lightning-formatted-rich-text renders in its own shadow root and
 * can't be themed to match.
 */
export default class ContentPage extends LightningElement {
  @api eyebrow;
  @api heading;
  @api subtitle;
  @api heroImageUrl;
  @api heroAlt = "";
  @api bodyHtml;
  @api relatedHeading;
  // JSON array string: [{"label":"Our Mission","path":"/our-mission"}]
  @api relatedLinks;

  _rendered;

  get hasPhotoHero() {
    return Boolean(this.heroImageUrl);
  }
  get hasEyebrow() {
    return Boolean(this.eyebrow);
  }
  get hasSubtitle() {
    return Boolean(this.subtitle);
  }
  get hasBody() {
    return Boolean(this.bodyHtml);
  }

  get hasRelated() {
    return Boolean(this.relatedHeading) || this.links.length > 0;
  }

  get links() {
    if (!this.relatedLinks) {
      return [];
    }
    let parsed;
    try {
      parsed = JSON.parse(this.relatedLinks);
    } catch (e) {
      return [];
    }
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed
      .filter((link) => link && link.label)
      .map((link, index) => ({
        key: `${index}-${link.label}`,
        label: link.label,
        href: this.resolve(link.path)
      }));
  }

  // Site-relative paths get the community basePath (= /lwrsite on staging) so
  // bookmarks survive cutover; absolute URLs (the Foundation, etc.) pass through.
  resolve(path) {
    if (!path) {
      return undefined;
    }
    if (/^https?:\/\//i.test(path)) {
      return path;
    }
    return `${basePath}${path.startsWith("/") ? "" : "/"}${path}`;
  }

  renderedCallback() {
    const host = this.refs && this.refs.body;
    if (!host) {
      return;
    }
    const next = this.bodyHtml || "";
    if (this._rendered === next) {
      return;
    }
    this._rendered = next;
    // Replace the prose without innerHTML (blocked by @lwc/lwc/no-inner-html):
    // parse the trusted, pre-cleaned markup and adopt its nodes into our own
    // lwc:dom="manual" container so the field-guide prose CSS styles it.
    while (host.firstChild) {
      host.removeChild(host.firstChild);
    }
    if (!next) {
      return;
    }
    const parsed = new DOMParser().parseFromString(next, "text/html");
    Array.from(parsed.body.childNodes).forEach((node) => {
      host.appendChild(document.importNode(node, true));
    });
    // Resolve migrated images. Authors write a host-neutral token carrying the
    // filename (<img data-asset="history.jpg">); we point it at the
    // content_assets static resource (binaries exported from prod, since sandbox
    // file data isn't copied). Keeps committed markup free of host/site prefixes.
    host.querySelectorAll("img[data-asset]").forEach((img) => {
      img.setAttribute("src", `${CONTENT_ASSETS}/${img.dataset.asset}`);
      if (!img.getAttribute("loading")) {
        img.setAttribute("loading", "lazy");
      }
    });
  }
}
