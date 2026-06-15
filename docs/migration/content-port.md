# Content Page Port

Bringing the legacy Aura information pages (About, Membership, Schools, and so
on) onto the LWR site as Alpine Field Guide pages.

## Where the content comes from

The page content lives only in the **production** Aura site — staging is a thin
sandbox whose `ExperienceBundle` export errors. Pull it read-only:

```
sf project retrieve start --metadata "ExperienceBundle:Spokane_Mountaineers1" \
  --target-org production
```

This bundle is reference material only. It is git- and force-ignored so it never
deploys or gets committed (the repo is public).

Per page (`experiences/Spokane_Mountaineers1/views/<name>.json`):

- The body is HTML inside `richTextValue` strings on
  `forceCommunity:richTextInline` components.
- Images are `src="{!contentAsset.NAME}"` references, or sometimes inline base64
  (the Logo & Gear banner and the discount partner logos were base64). See the
  [image pipeline](design-system.md#the-image-pipeline).
- The old URL is the route `urlPrefix`.

## How a page is ported

1. Extract and clean the `richTextValue` HTML: strip inline styles, unwrap
   `<span>`/`<font>`, fix obvious typos, rewrite legacy `/s/...` Aura links to
   their LWR routes.
2. Resolve images: export the binaries from production, optimize, add to a
   `content_assets` static resource, and reference them with `data-asset` tokens.
3. Author the route and view placing `c:contentPage` with the cleaned content.
4. Keep the same `urlPrefix` as the old page so member bookmarks survive without a
   redirect.

## Done

### About group (5 pages)

| Page            | URL                | Notes                                                                                                                                                                        |
| --------------- | ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| About Us        | `/about-us`        | Club overview; "More About Us" related rail                                                                                                                                  |
| Our Mission     | `/our-mission`     | By-Laws mission list; tulips photo                                                                                                                                           |
| Our History     | `/100-years`       | 1915→2015 timeline; history photo                                                                                                                                            |
| Our Chalet      | `/our-chalet`      | Booking/rules prose; 13-photo gallery                                                                                                                                        |
| Club Leadership | `/club-leadership` | Governance prose; progression diagram. The board roster is intentionally omitted — it changes yearly and shouldn't be hardcoded in a public repo; source it from data later. |

### Membership group (4 pages)

| Page                | URL                 | Notes                                                                                                                                                                                                                         |
| ------------------- | ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Membership Benefits | `/member-benefits`  | Prose                                                                                                                                                                                                                         |
| Member Discounts    | `/member-discounts` | Vendor cards (Outdoorly, Wild Walls, Bloc Yard, Coeur Climbing, Solnix, Evergreen Gear Exchange). Partner logos pulled from each vendor's public site; the old "all discounts" table image was retired in favor of the cards. |
| Member Resources    | `/member-resources` | The member/leader documents, maps, and online resources list (the legacy `memberDocuments` page)                                                                                                                              |
| Logo & Gear         | `/club-logo-gear`   | BSI Apparel ordering; logo banner extracted from inline base64                                                                                                                                                                |

## Not started

### Schools & Clinics (~20 pages)

The schools and seminars: rock climbing school, mountain school, backpack school,
trad lead school, backcountry ski school, multipitch sport school, scrambling,
the wilderness medicine courses, the various seminars, and so on. These are prose
pages and port the same way as the About/Membership pages.

When they land, the **Schools & Clinics** nav item should become a dropdown for
consistency with the other section menus, instead of the single link it is today.

## Redirects

Most ported pages keep their old `urlPrefix`, so existing bookmarks keep working
with no redirect. Redirects are only needed for the pages whose URL genuinely
changed — the already-rebuilt app pages — and the old auth paths. The full
old→new map is in the
[Content Port & Redirects plan](../plans/2026-06-12-content-port-and-redirects.md).
The redirect mechanism itself (Experience Cloud URL redirects) is still to be
set up; see [Remaining Work](remaining-work.md).
