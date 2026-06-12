import { LightningElement, api } from "lwc";
import isGuest from "@salesforce/user/isGuest";
import basePath from "@salesforce/community/basePath";

// Alpine Field Guide theme layout for the LWR site (plan §9.1): header with
// logo, primary nav, and member/login state; footer; topographic background
// wash. The page content renders into the default <slot>. Nav defaults to the
// live route map (plan §2.2) but is overridable in Builder via the
// navItemsJson property so staff can re-order without a code change.
//
// hrefs are root-relative ("/events"); the component prefixes the community
// basePath so they resolve under the site prefix (/lwrsite in staging, whatever
// prod serves) rather than the bare domain root.
const DEFAULT_NAV = [
  { label: "Home", href: "/" },
  { label: "Calendar", href: "/events" },
  { label: "Trip Reports", href: "/blog" },
  { label: "My Mountaineers", href: "/basecamp", member: true }
];

export default class SmiThemeLayout extends LightningElement {
  @api siteName = "Spokane Mountaineers";
  @api logoUrl;
  @api homeHref = "/";
  @api loginHref = "/login";
  @api logoutHref = "/secur/logout.jsp";
  @api navItemsJson;

  _mobileOpen = false;

  get isGuest() {
    return isGuest;
  }

  // Prefix the community basePath onto a root-relative href so links resolve
  // under the site prefix. Leaves absolute URLs (http..., mailto:) untouched.
  withBase(href) {
    if (!href || !href.startsWith("/")) {
      return href;
    }
    return `${basePath}${href === "/" ? "" : href}` || "/";
  }

  get homeLink() {
    return this.withBase(this.homeHref);
  }

  get loginLink() {
    return this.withBase(this.loginHref);
  }

  get logoutLink() {
    return this.withBase(this.logoutHref);
  }

  // A signed-in member sees member-only links + Log out; a guest sees Log in.
  get navItems() {
    let items = DEFAULT_NAV;
    if (this.navItemsJson) {
      try {
        const parsed = JSON.parse(this.navItemsJson);
        if (Array.isArray(parsed) && parsed.length) items = parsed;
      } catch (e) {
        // Malformed override — fall back to the default IA rather than break
        // the whole site chrome.
        // eslint-disable-next-line no-console
        console.warn("smiThemeLayout: navItemsJson is not valid JSON", e);
      }
    }
    return items
      .filter((item) => !(item.member && isGuest))
      .map((item, i) => ({
        ...item,
        href: this.withBase(item.href),
        key: `${i}-${item.href}`
      }));
  }

  get mobileOpen() {
    return this._mobileOpen;
  }

  get navClass() {
    return this._mobileOpen ? "nav nav--open" : "nav";
  }

  get hamburgerLabel() {
    return this._mobileOpen ? "Close menu" : "Open menu";
  }

  toggleMobile() {
    this._mobileOpen = !this._mobileOpen;
  }

  closeMobile() {
    this._mobileOpen = false;
  }

  get year() {
    return new Date().getFullYear();
  }
}
