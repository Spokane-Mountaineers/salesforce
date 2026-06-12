# Legacy content port + URL redirects

Working plan for porting the legacy Aura content pages to the LWR site and
mapping old URLs forward. Companion to
[2026-06-08-lwr-site-overhaul.md](2026-06-08-lwr-site-overhaul.md) (task #15).

## Source of truth

The page content lives **only in the production Aura site** — staging is a thin
sandbox (its `ExperienceBundle` export even errors). Pull read-only:

```
sf project retrieve start --metadata "ExperienceBundle:Spokane_Mountaineers1" \
  --target-metadata-dir /tmp/aura-prod --target-org production
```

Per page (`experiences/Spokane_Mountaineers1/views/<name>.json`):

- **Body** = HTML in `richTextValue` on `forceCommunity:richTextInline` (walk
  the JSON for `richTextValue`).
- **Images** = `src="{!contentAsset.IMG_xxxx.1}"` → org-level Content Assets.
  Reference the existing asset (org-wide) rather than re-hosting where possible.
- Markup carries hardcoded inline styles (font-size/color) — **strip them** and
  let the Alpine Field Guide theme style the content.
- **Old URL** = route `urlPrefix`.

## Porting approach (per page)

1. Extract + clean the `richTextValue` HTML (drop inline styles, fix headings).
2. Resolve image `contentAsset` refs to deliverable URLs.
3. Render via a reusable **`contentPage` LWC** (Alpine Field Guide: hero + prose
   column + field-plate images) — content passed as a Builder rich-text property
   or a small per-page wrapper, depending on volume.
4. Author the LWR route + view (proven custom-page loop, §"Author LWR pages").
5. Keep the **same urlPrefix** as the old page so member bookmarks survive with
   no redirect needed.

## Page inventory + URL map

Strategy: **reuse the old path** for every ported content page, so most need no
redirect. Redirects are only for pages whose URL genuinely changed (the
already-built app pages).

### Content / info pages (port content, keep path → no redirect)

| Aura view         | old & new URL        |
| ----------------- | -------------------- |
| aboutUs           | /about-us            |
| ourMission        | /our-mission         |
| ourChalet         | /our-chalet          |
| clubLeadership    | /club-leadership     |
| clubLogoGear      | /club-logo-gear      |
| memberBenefits    | /member-benefits     |
| memberDiscounts   | /member-discounts    |
| memberDocuments   | /member-documents    |
| kinniOnline       | /kinni-online        |
| 100Years          | /100-years           |
| privacyPolicy     | /privacy-policy      |
| schoolsAndClinics | /schools-and-clinics |
| contactSupport    | /contactsupport      |

### Activity-group pages (9) — keep path

group-climbing, group-hiking, group-skiing, group-paddling, group-conservation,
group-chalet, group-mountain-biking, group-road-biking, group-clubwide.

### School / seminar pages (~20) — keep path

rock-climbing-school, mountain-school, backpack-school, trad-lead-school,
backcountry-ski-school, multipitch-sport-school, scrambling,
wilderness-first-aid-course, wilderness-first-responder-course,
high-angle-rescue, introduction-to-beacons, aid-climbing-seminar,
crack-climbing-seminar, ice-climbing-seminar, alpine-climbing-seminar,
sport-lead-rock-seminar, leadership-development-seminar, backcountry-skiing-101,
mountain-bike-fundamentals, mountain-bike-intermediate,
for-school-directors-and-chairs.

### Redirects needed (URL changed — old Aura → new LWR)

These are the app pages already rebuilt under new paths; the old paths must
redirect forward at cutover:

| old Aura URL          | new LWR URL                | note             |
| --------------------- | -------------------------- | ---------------- |
| /all-events, /events  | /events                    | calendar         |
| /my-mountaineers      | /basecamp                  | member dashboard |
| /event-requests       | /events (or a member view) | confirm          |
| (news / trip reports) | /blog                      | confirm old path |
| /contactsupport       | /contactsupport            | kept (ticketing) |

Old auth paths (`/s/login`, `/CommunitiesForgotPassword`, `/SiteLogin`) → the
LWR `/login` and `/ForgotPassword` routes.

## Open items

- **Redirect mechanism**: Experience Cloud URL Redirects (CSV import in Builder,
  or `SiteRedirect`-style metadata) — confirm the LWR-supported path and whether
  it round-trips as metadata.
- **Content Asset delivery URLs** on LWR — confirm `{!contentAsset}` refs resolve
  or need rewriting to CMS delivery URLs / static resources.
- **memberDocuments / clubLogoGear** may be link lists or storefronts, not prose
  — review individually.
- Build order: one exemplar (aboutUs → /about-us) end-to-end to lock the
  `contentPage` pattern, then batch by template (info → activity → school).
