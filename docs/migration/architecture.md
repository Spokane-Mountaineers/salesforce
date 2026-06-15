# Architecture & Deploy Model

How the LWR site is structured, how it relates to the legacy Aura site, and how
changes get from the repo to a running site.

## Two Experience Cloud sites, two networks

The org has more than one Experience Cloud "site." Each site is backed by its own
`Network` record, and that distinction matters for the data migration.

| Site (label)             | Network  | Template                | Status                            |
| ------------------------ | -------- | ----------------------- | --------------------------------- |
| Spokane Mountaineers     | `0DB1N…` | Aura (Customer Service) | Live (the current member site)    |
| Spokane Mountaineers LWR | `0DBcW…` | LWR (Build Your Own)    | Under Construction (the new site) |

The new site publishes under the name **"Spokane Mountaineers LWR"** — not
"Spokane Mountaineers", which is the legacy Aura site. The LWR bundle in source is
`site/Spokane_Mountaineers_LWR1`.

Because Chatter groups belong to a single network, the activity groups that live
in the legacy network are not directly usable from the LWR network. That is the
core reason a data migration is required; see
[Chatter Data Migration](chatter-migration.md).

## The site bundle

The LWR site is a `DigitalExperienceBundle` stored under
`force-app/main/default/digitalExperiences/site/Spokane_Mountaineers_LWR1/`. The
parts that come up most often:

- `sfdc_cms__route/<Name>` — a URL route. Its `content.json` sets `urlPrefix`
  (the path), `routeType`, and `activeViewId` (the view it renders).
- `sfdc_cms__view/<Name>` — a page. Its `content.json` holds the component tree
  (sections, columns, and the components placed in them) plus SEO settings.
- `sfdc_cms__themeLayout/smiThemeLayout` — the shared header/nav/footer shell
  (see [Design System](design-system.md)).
- `sfdc_cms__theme`, `sfdc_cms__brandingSet`, `sfdc_cms__styles` — theme and
  branding.

### Authoring a custom page

A page is a route plus a view that places one or more components. The rule that
catches people out: **`routeType` and `viewType` must both equal
`"custom-" + urlName`**. For example a page at `/about-us` uses `urlName`
`about-us`, `routeType` `custom-about-us`, and `viewType` `custom-about-us`. A
mismatch deploys without complaint but fails the asynchronous publish.

One more constraint learned the hard way: a route or view **`title` cannot
contain an ampersand** (it becomes the component's name, which only allows
alphanumerics, hyphens, colons, and underscores). "Logo & Gear" uses the title
"Logo and Gear" while the page heading still shows the ampersand.

The view JSON is verbose and easy to get wrong by hand, so new pages are
generated with a small Python helper that writes the route and view with proper
escaping.

## Deploy model

Deploys are environment-scoped. The active environment comes from `SF_ENV`
(selected with `just use <env>`), and org-specific values come from
`.env.<SF_ENV>` (for example `SITE_NAME`, `SITE_BUNDLE`). There is no per-recipe
`<org>` argument; the recipe reads the active environment.

The common loop:

1. `just deploy-site` — deploys only the site bundle
   (`DigitalExperienceBundle:$SITE_BUNDLE`) to the active org. On production it
   runs with `RunLocalTests`; on staging it deploys without tests.
2. `just publish` — runs `sf community publish --name "$SITE_NAME"`. Deploying
   metadata is not enough; the page only becomes live after a publish, and the
   publish is where `routeType`/`viewType` mismatches surface.
3. Pull-normalize — after authoring a brand-new route/view, pulling the bundle
   back lets Salesforce rewrite it into canonical form.

Apex and Lightning Web Components deploy with ordinary
`sf project deploy start --metadata` calls. Apex changes are live immediately and
do not need a publish; component and page changes are picked up on the next
publish.

### Site networks are deployed as templated config

The `Network` records carry environment-specific values (sender email, member
profiles) and are `.forceignore`d. They are rendered from templates and deployed
with `just deploy-site-config`, which substitutes `${SITE_*}` values into a temp
copy and deploys past the forceignore. Direct `sf project deploy` of the network
reports "nothing to deploy" because of the forceignore.

## Access layers

A working member login depends on three things lining up:

1. **Guest profile Apex access** — the guest profile must have access to the
   controllers used on public pages, or the page fails with "Failed to get error
   from response."
2. **Member profiles in `networkMemberGroups`** — member profiles must be added
   to the LWR network, or authenticated users get "NO_ACCESS: not authorized for
   the community."
3. **Site status Live** — verified in Builder preview while the site is Under
   Construction (a guest `curl` returns 404 for everything, including assets).

See [Authentication & Access](auth-and-access.md) for the auth components.
