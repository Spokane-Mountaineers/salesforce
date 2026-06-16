import { LightningElement, api } from "lwc";
import isGuest from "@salesforce/user/isGuest";
import basePath from "@salesforce/community/basePath";
import SMI_LOGO from "@salesforce/resourceUrl/smi_logo";
import FAVICON from "@salesforce/resourceUrl/favicon_ico";

// Set once per page load (the theme layout renders once); a module flag avoids
// a forbidden document-level query to dedupe.
let faviconSet = false;

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
// Ordered so direct links and dropdowns don't intersperse: quick-access direct
// links first (Home, Calendar, Schools & Clinics), then the browse-by-section
// dropdowns, then the member dashboard in its conventional far-right slot.
const DEFAULT_NAV = [
  { label: "Home", href: "/" },
  { label: "Calendar", href: "/events" },
  { label: "Activities", href: "/activities" },
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
    // Every school/seminar/course is reachable directly here (the dropdown
    // scrolls if it's tall); the overview page presents the same set as a
    // grouped, designed directory.
    label: "Schools & Clinics",
    children: [
      { label: "All Schools & Clinics", href: "/schools-and-clinics" },
      { label: "Rock Climbing School", href: "/rock-climbing-school" },
      { label: "Mountain School", href: "/mountain-school" },
      { label: "Backpack School", href: "/backpack-school" },
      { label: "Trad Lead School", href: "/trad-lead-school" },
      { label: "Backcountry Ski School", href: "/backcountry-ski-school" },
      { label: "Multipitch Sport School", href: "/multipitch-sport-school" },
      { label: "Scrambling", href: "/scrambling" },
      { label: "Aid Climbing Seminar", href: "/aid-climbing-seminar" },
      { label: "Crack Climbing Seminar", href: "/crack-climbing-seminar" },
      { label: "Ice Climbing Seminar", href: "/ice-climbing-seminar" },
      { label: "Alpine Climbing Seminar", href: "/alpine-climbing-seminar" },
      { label: "Sport Lead Rock Seminar", href: "/sport-lead-rock-seminar" },
      {
        label: "Leadership Development Seminar",
        href: "/leadership-development-seminar"
      },
      { label: "Wilderness First Aid", href: "/wilderness-first-aid-course" },
      {
        label: "Wilderness First Responder",
        href: "/wilderness-first-responder-course"
      },
      { label: "High Angle Rescue", href: "/high-angle-rescue" },
      { label: "Introduction to Beacons", href: "/introduction-to-beacons" },
      { label: "Backcountry Skiing 101", href: "/backcountry-skiing-101" },
      {
        label: "Mountain Bike Fundamentals",
        href: "/mountain-bike-fundamentals"
      },
      {
        label: "Mountain Bike Intermediate",
        href: "/mountain-bike-intermediate"
      },
      {
        label: "For School Directors & Chairs",
        href: "/for-school-directors-and-chairs"
      }
    ]
  },
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
  showTop = false;

  // The theme layout wraps every page, so set the favicon here and watch scroll
  // for the back-to-top button.
  connectedCallback() {
    this.setFavicon();
    this._onScroll = () => {
      this.showTop = (window.pageYOffset || window.scrollY || 0) > 400;
    };
    try {
      window.addEventListener("scroll", this._onScroll, { passive: true });
    } catch (e) {
      // scroll not observable in this runtime — button just won't auto-show
    }
  }

  disconnectedCallback() {
    try {
      window.removeEventListener("scroll", this._onScroll);
    } catch (e) {
      // nothing to clean up
    }
  }

  // Best-effort favicon: if the runtime blocks document.head, set it via the
  // site's head markup in Builder (the favicon_ico static resource deploys
  // either way).
  setFavicon() {
    if (faviconSet) {
      return;
    }
    try {
      const link = document.createElement("link");
      link.rel = "icon";
      link.type = "image/x-icon";
      link.href = FAVICON;
      document.head.appendChild(link);
      faviconSet = true;
    } catch (e) {
      // favicon will be set via Builder head markup instead
    }
  }

  scrollToTop() {
    try {
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (e) {
      window.scrollTo(0, 0);
    }
  }

  get isGuest() {
    return isGuest;
  }

  // The Spokane Mountaineers logo (Builder can override via logoUrl).
  get logoSrc() {
    return this.logoUrl || SMI_LOGO;
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

  // Carry the current page as startURL so logging in returns the member here
  // (not the default landing), unless they're already on the login page.
  get loginLink() {
    const base = this.withBase(this.loginHref);
    try {
      const here = window.location.pathname + window.location.search;
      if (here && here.indexOf(this.loginHref) === -1) {
        return `${base}?startURL=${encodeURIComponent(here)}`;
      }
    } catch (e) {
      // window unavailable (SSR) — fall back to the plain login link.
    }
    return base;
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
