import { LightningElement, api } from "lwc";
import basePath from "@salesforce/community/basePath";
import CONTENT_ASSETS from "@salesforce/resourceUrl/content_assets";
import CONTENT_IMG_CHALET from "@salesforce/resourceUrl/content_img_chalet";
import CONTENT_IMG_SCHOOLS from "@salesforce/resourceUrl/content_img_schools";

// Images ship as static resources (CDN-cached, versioned). A single resource
// caps at 5 MB, so heavy galleries/sections get their own resource; a "group/"
// prefix on the data-asset token selects it. Add a resource + map entry per group.
const IMAGE_RESOURCES = {
  chalet: CONTENT_IMG_CHALET,
  schools: CONTENT_IMG_SCHOOLS
};

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
  _bodyBound = false;
  _images = [];
  lightboxIndex = -1;

  connectedCallback() {
    this._onKeydown = (e) => {
      if (this.lightboxIndex < 0) {
        return;
      }
      if (e.key === "Escape") {
        this.closeLightbox();
      } else if (e.key === "ArrowLeft") {
        this.prevImage();
      } else if (e.key === "ArrowRight") {
        this.nextImage();
      }
    };
    window.addEventListener("keydown", this._onKeydown);
  }

  disconnectedCallback() {
    window.removeEventListener("keydown", this._onKeydown);
  }

  get isLightboxOpen() {
    return this.lightboxIndex >= 0;
  }
  get lightboxSrc() {
    const img = this._images[this.lightboxIndex];
    return img && img.src;
  }
  get lightboxAlt() {
    const img = this._images[this.lightboxIndex];
    return (img && img.alt) || "";
  }
  // Only show prev/next affordances when there's more than one image.
  get hasGallery() {
    return this._images.length > 1;
  }

  // Click any image in the prose/gallery to open the lightbox at that image.
  handleBodyClick(event) {
    const img = event.target.closest("img");
    if (!img) {
      return;
    }
    const host = this.refs && this.refs.body;
    const imgs = host ? Array.from(host.querySelectorAll("img")) : [img];
    this._images = imgs.map((el) => ({
      src: el.currentSrc || el.src,
      alt: el.alt || ""
    }));
    this.lightboxIndex = Math.max(0, imgs.indexOf(img));
  }

  prevImage(event) {
    if (event) {
      event.stopPropagation();
    }
    const n = this._images.length;
    if (n) {
      this.lightboxIndex = (this.lightboxIndex - 1 + n) % n;
    }
  }

  nextImage(event) {
    if (event) {
      event.stopPropagation();
    }
    const n = this._images.length;
    if (n) {
      this.lightboxIndex = (this.lightboxIndex + 1) % n;
    }
  }

  closeLightbox() {
    this.lightboxIndex = -1;
  }

  // Tapping the image itself closes (a clear dismiss on mobile and desktop).
  closeFromImage(event) {
    event.stopPropagation();
    this.closeLightbox();
  }

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
    // Delegate image clicks once (the body is rebuilt in place, the host stays).
    if (!this._bodyBound) {
      host.addEventListener("click", (e) => this.handleBodyClick(e));
      this._bodyBound = true;
    }
    // Resolve migrated images. Authors write a host-neutral token carrying the
    // filename (<img data-asset="history.jpg">), optionally with a group prefix
    // for galleries in their own resource (<img data-asset="chalet/IMG_1.jpeg">).
    // Binaries are exported from prod (sandbox file data isn't copied). Keeps
    // committed markup free of host/site prefixes.
    host.querySelectorAll("img[data-asset]").forEach((img) => {
      img.setAttribute("src", this.assetUrl(img.dataset.asset));
      if (!img.getAttribute("loading")) {
        img.setAttribute("loading", "lazy");
      }
    });
    // Site-relative links in the body need the community basePath too (so they
    // resolve under /lwrsite etc.). Absolute URLs, anchors and mailto: are left
    // alone, and links already under basePath aren't double-prefixed.
    if (basePath) {
      host.querySelectorAll('a[href^="/"]').forEach((anchor) => {
        const href = anchor.getAttribute("href");
        if (!href.startsWith(`${basePath}/`) && href !== basePath) {
          anchor.setAttribute("href", `${basePath}${href}`);
        }
      });
    }
  }

  assetUrl(token) {
    const slash = token.indexOf("/");
    if (slash > -1) {
      const base = IMAGE_RESOURCES[token.slice(0, slash)];
      if (base) {
        return `${base}/${token.slice(slash + 1)}`;
      }
    }
    return `${CONTENT_ASSETS}/${token}`;
  }
}
