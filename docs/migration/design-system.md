# Design System & Page Patterns

The visual language of the new site and the reusable patterns that most pages are
built from.

## Alpine Field Guide

The site uses the "Alpine Field Guide" design system: an evergreen-and-rust
palette, Fraunces for display headings, Public Sans for body, a topographic
contour motif, and photography treated like catalogued field specimens. The
canonical source is `docs/stylesheets/smi-theme.css` (design tokens plus `smi-`
component classes). It is mirrored to the `smi_theme` static resource for use in
Experience Cloud components, kept in sync with `just sync-theme`.

The full visual reference lives in the
[Style Guide](../brand/style-guide.md). The Member FAQ page (`faqPage`) is the
reference implementation of the theme in a Lightning Web Component.

Components carry their own copy of the tokens in a `:host` block because shadow
DOM can't read the global stylesheet. When you add a component, copy the token
block from an existing one rather than reaching for the global file.

## The `contentPage` component

Most ported information pages (About Us, Our Mission, and so on) are built from
one reusable component: `c:contentPage`. It renders a hero (a gradient by
default, or a full-bleed photo when given an image), a readable prose column, and
an optional "related links" rail.

A page's content is supplied through the view's component attributes:

- `eyebrow`, `heading`, `subtitle` — the hero text.
- `heroImageUrl`, `heroAlt` — optional photographic hero.
- `bodyHtml` — the page body as pre-cleaned HTML.
- `relatedHeading`, `relatedLinks` — an optional rail; `relatedLinks` is a JSON
  array of `{ "label", "path" }`. Site-relative paths get the community base
  path; absolute URLs pass through.

### Why the body is injected, and the lint rule behind it

`contentPage` styles the body with the field-guide prose CSS. To do that the
markup has to render inside the component's own shadow root, so a base
`lightning-formatted-rich-text` (which renders in its own shadow root and can't
be themed) wasn't an option.

The repo enforces the `@lwc/lwc/no-inner-html` security lint rule, so setting
`innerHTML` is not allowed. Instead `contentPage` parses the trusted, pre-cleaned
`bodyHtml` with `DOMParser` and adopts the nodes into a `lwc:dom="manual"`
container. In the same pass it:

- resolves images written as `<img data-asset="name.ext">` to their static
  resource URL (see below), and
- prefixes site-relative links (`<a href="/events">`) with the community base
  path so they resolve under the site prefix.

The body HTML committed to the repo is cleaned at migration time: inline
font-size and color styles are stripped, `<span>`/`<font>` wrappers are removed,
and whitespace-only inline tags become a single space (an early bug dropped those
and butted words against links).

## The image pipeline

Legacy pages embedded images as Salesforce Content Assets, referenced in Aura as
`{!contentAsset.NAME}`. Those references do not work on LWR — the `/file-asset/`
path only resolves inside Lightning Experience, not on the member site. So images
are shipped a different way.

How it works:

1. **Export from production.** Sandboxes copy Content Asset records but not the
   file bytes, so the binaries come from production. `scripts/export-content-assets.sh`
   pulls each asset's `ContentVersion` `VersionData` from the `production` org.
2. **Optimize.** The originals are 1–5 MB phone photos; they're resized and
   recompressed with `sips` for the web.
3. **Bundle as a static resource.** Optimized images go into the
   `content_assets` static resource (CDN-cached, `cacheControl=Public`, versioned
   URL for automatic cache-busting). This is the same mechanism `faqPage` uses
   for its screenshots — a supported, cacheable host, not a workaround.
4. **Reference by token.** Authors write `<img data-asset="history.jpg">` and
   `contentPage` resolves it at render. The committed markup never hardcodes a
   host or site prefix.

### The 5 MB cap and galleries

A single static resource maxes out at 5 MB. Heavy galleries get their own
resource, selected by a group prefix on the token: `data-asset="chalet/IMG.jpeg"`
resolves against the `content_img_chalet` resource. The Our Chalet page uses this
for its 13-photo gallery, laid out in a responsive grid.

As more image-heavy pages land (Schools & Clinics), expect to add more
group-scoped resources rather than growing one past the cap.
