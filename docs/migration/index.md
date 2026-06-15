# Website Migration

This section documents the migration of the Spokane Mountaineers member website
from the legacy Aura Experience Cloud site to a new Lightning Web Runtime (LWR)
site built on the Alpine Field Guide design system. It records what has been
built, how it works, and what remains before cutover.

It is written for the people who will finish and operate the migration:
developers, admins, and club staff who need to understand the moving parts.

## Why we're doing this

The old member site runs on the Aura "Customer Service" template. It is hard to
restyle, slow to change, and increasingly out of step with how the club wants to
present itself. The new site is a pure-LWR build with a consistent design system
("Alpine Field Guide"), authored as code so changes are reviewable, testable, and
repeatable across environments.

## Approach

A few principles have guided the work:

- **Staging first.** Everything is built and verified against the staging
  sandbox before it goes near production. Deploys are environment-scoped through
  the `justfile` so `env=staging` and `env=production` target the right org.
- **Pure LWR, not a port of Aura.** Rather than dragging Aura/SLDS components
  across, the site uses fresh Lightning Web Components on the shared Alpine Field
  Guide theme.
- **Authored as code.** Pages (routes and views), components, Apex, and config
  live in the repo. The site is deployed with `just deploy-site` and made live
  with `just publish`.
- **Don't break the live site.** The legacy Aura site stays running on its own
  network until cutover. The LWR site is a separate Experience Cloud site.

## Status at a glance

| Area                                                                        | Status              |
| --------------------------------------------------------------------------- | ------------------- |
| Theme / design system (Alpine Field Guide)                                  | Done                |
| Deploy model (env-scoped `just` recipes)                                    | Done                |
| Authentication (login, forgot password, T&C, SSO)                           | Done                |
| Navigation (grouped dropdowns + mobile)                                     | Done                |
| Home, Events calendar, RSVP                                                 | Done                |
| Blog / Trip Reports                                                         | Done                |
| Case management / ticketing                                                 | Done                |
| Basecamp member dashboard                                                   | Done                |
| Content pages — About group (5)                                             | Done                |
| Content pages — Membership group (4)                                        | Done                |
| Activity Groups feature (directory, group page, admin, join, notifications) | Done                |
| Logged-out story (friendly login gate, return to bookmark)                  | Done                |
| Content pages — Schools & Clinics (~20)                                     | Not started         |
| Old Aura URL → LWR redirects                                                | Not started         |
| **Chatter / Activity Group data migration into the LWR network**            | Planned (see below) |
| Cutover (site Live, URL prefix, OAuth redirect URIs)                        | Not started         |

## How this section is organized

- [Architecture & Deploy Model](architecture.md) — networks, the site bundle,
  routes and views, the theme layout, and how deploys work.
- [Design System & Page Patterns](design-system.md) — Alpine Field Guide, the
  `contentPage` component, and the image pipeline.
- [Authentication & Access](auth-and-access.md) — login, password reset, the
  Terms & Conditions flow, SSO, and the logged-out experience.
- [Content Page Port](content-port.md) — porting the legacy info pages, what's
  done, and what's left.
- [Activity Groups](activity-groups.md) — the dynamic groups feature that
  replaced the legacy Chatter group pages.
- [Chatter Data Migration](chatter-migration.md) — the remaining data migration
  to bring groups, members, and feed history into the LWR network.
- [Remaining Work & Cutover](remaining-work.md) — everything left, plus the
  cutover checklist.

## Related plans

- [LWR Site Overhaul](../plans/2026-06-08-lwr-site-overhaul.md)
- [Content Port & Redirects](../plans/2026-06-12-content-port-and-redirects.md)
