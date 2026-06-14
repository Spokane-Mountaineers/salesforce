import { LightningElement, api } from "lwc";
import isGuest from "@salesforce/user/isGuest";
import basePath from "@salesforce/community/basePath";

// Alpine Field Guide theme layout for the LWR site (plan §9.1): header with
// logo, primary nav, and member/login state; footer; topographic background
// wash. The page content renders into the default <slot>. Nav defaults to the
// live route map (plan §2.2) but is overridable in Builder via the
// navItemsJson property so staff can re-order without a code change.
//
// Two levels: a top item is either a plain link (href) or a dropdown group
// (children) — desktop reveals the submenu on hover/focus, mobile toggles it as
// an accordion. hrefs are root-relative ("/events"); the component prefixes the
// community basePath so they resolve under the site prefix (/lwrsite in staging,
// whatever prod serves) rather than the bare domain root. Grouped content pages
// are added here as each batch of the legacy content port lands.
const DEFAULT_NAV = [
  { label: "Home", href: "/" },
  {
    label: "About",
    children: [
      { label: "About Us", href: "/about-us" },
      { label: "Our Mission", href: "/our-mission" },
      { label: "Our History", href: "/100-years" },
      { label: "Our Chalet", href: "/our-chalet" },
      { label: "Club Leadership", href: "/club-leadership" }
    ]
  },
  {
    label: "Membership",
    children: [
      { label: "Membership Benefits", href: "/member-benefits" },
      { label: "Member Discounts", href: "/member-discounts" },
      { label: "Member Resources", href: "/member-resources" },
      { label: "Logo & Gear", href: "/club-logo-gear" }
    ]
  },
  {
    label: "Activities",
    children: [
      { label: "Climbing", href: "/group-climbing" },
      { label: "Hiking", href: "/group-hiking" },
      { label: "Skiing", href: "/group-skiing" },
      { label: "Paddling", href: "/group-paddling" },
      { label: "Mountain Biking", href: "/group-mountain-biking" },
      { label: "Road Biking", href: "/group-road-biking" },
      { label: "Conservation", href: "/group-conservation" },
      { label: "The Chalet", href: "/group-chalet" },
      { label: "Club-wide", href: "/group-clubwide" }
    ]
  },
  { label: "Schools & Clinics", href: "/schools-and-clinics" },
  { label: "Calendar", href: "/events" },
  {
    label: "News",
    children: [
      { label: "Trip Reports", href: "/blog" },
      { label: "The Kinni Online", href: "/kinni-online" }
    ]
  },
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
  _openKey = null;

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
  // Top items are either plain links or dropdown groups (children); member-only
  // items are filtered at both levels for guests.
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
      .map((item, i) => {
        const key = `${i}-${item.label}`;
        const children = (item.children || [])
          .filter((child) => !(child.member && isGuest))
          .map((child, j) => ({
            key: `${key}-${j}`,
            label: child.label,
            href: this.withBase(child.href)
          }));
        const hasChildren = children.length > 0;
        const open = hasChildren && key === this._openKey;
        return {
          key,
          label: item.label,
          href: hasChildren ? undefined : this.withBase(item.href),
          hasChildren,
          children,
          ariaExpanded: hasChildren ? String(open) : null,
          itemClass: open ? "nav__item nav__item--open" : "nav__item",
          submenuClass: open
            ? "nav__submenu nav__submenu--open"
            : "nav__submenu"
        };
      });
  }

  // Footer is a grouped sitemap: a row of the top-level standalone links, then
  // a column per dropdown group mirroring the header IA.
  get footerPrimary() {
    return this.navItems
      .filter((item) => !item.hasChildren && item.href)
      .map((item) => ({
        key: `fp-${item.key}`,
        label: item.label,
        href: item.href
      }));
  }

  get footerGroups() {
    return this.navItems
      .filter((item) => item.hasChildren)
      .map((item) => ({
        key: `fg-${item.key}`,
        label: item.label,
        links: item.children.map((child) => ({
          key: `fg-${child.key}`,
          label: child.label,
          href: child.href
        }))
      }));
  }

  // Mobile / keyboard: toggle a group's submenu open. Desktop reveals it on
  // hover/focus via CSS, so this is the accordion + a11y path.
  toggleSubmenu(event) {
    const { key } = event.currentTarget.dataset;
    this._openKey = this._openKey === key ? null : key;
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
    this._openKey = null;
  }

  get year() {
    return new Date().getFullYear();
  }
}
