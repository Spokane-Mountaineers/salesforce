# Remaining Work & Cutover

Everything left between today and a production cutover, roughly in priority order.

## Remaining work

### Chatter data migration

The largest item, documented on its own page:
[Chatter Data Migration](chatter-migration.md). Groups, memberships, and feed
history have to move into the LWR network before join and post work on the new
site. Gated on enabling "Set Audit Fields upon Record Creation."

### Schools & Clinics content (~20 pages)

The last batch of content pages. They port the same way as the About and
Membership groups (see [Content Page Port](content-port.md)). When they land,
turn the **Schools & Clinics** nav item into a dropdown for consistency with the
other section menus.

### URL redirects

Most ported pages kept their old paths, so few redirects are needed. The ones
that are (the already-renamed app pages, and the old auth paths) need the
Experience Cloud URL redirect mechanism set up and the map from the
[Content Port & Redirects plan](../plans/2026-06-12-content-port-and-redirects.md)
applied.

### Events: workflow rules → Flow, retire the standard-Event mirror

The remaining tail of the events rehaul: migrate the last workflow rules to Flow
and retire the standard-Event mirror now that the calendar binds directly to
`Event_Registration__c`.

### Password reset email delivery

The branded reset page works, but the reset email did not reliably arrive in
testing. Confirm production email deliverability (sender verification, rate
limits) before cutover.

## Cutover checklist

These are the production steps to flip the new site live. Most are deliberately
left until cutover because they affect the live member experience.

- [ ] **Member provisioning** — ensure member profiles are in the LWR network's
      `networkMemberGroups`, and members exist in the new network (also a
      prerequisite for the membership migration).
- [ ] **Run the Chatter migration** — final, idempotent re-run close to cutover
      to capture last-minute posts.
- [ ] **Register OAuth redirect URIs** — add the production LWR callback URLs to
      the Google and Microsoft app configurations.
- [ ] **Schools & Clinics** content ported and the nav dropdown in place.
- [ ] **URL redirects** configured for the changed paths and old auth paths.
- [ ] **Filter archived groups** from the directory (we currently show them so
      staging is testable; production should hide long-dead archived groups).
- [ ] **Page-level access** — decide whether member-only pages should hard-block
      guests at the route ("Requires Login") in addition to the in-page login
      gate.
- [ ] **Activate the site** — set the LWR site status to Live.
- [ ] **URL prefix swap** — point the member-facing URL at the LWR site.
- [ ] **Verify** login (username/password and both SSO providers), the Terms &
      Conditions flow, events/RSVP, the blog, ticketing, Basecamp, and the
      activity groups end to end in production.
- [ ] **Retire the legacy Aura site** once the LWR site is confirmed.

## Known gotchas worth remembering

A short list of things that have already cost time, collected so they don't cost
it again:

- `routeType` and `viewType` must both equal `"custom-" + urlName`, or the
  asynchronous publish fails.
- A route/view `title` can't contain `&` (component-name rule).
- `@lwc/lwc/no-inner-html` is enforced; inject trusted HTML via `DOMParser` +
  `lwc:dom="manual"`, not `innerHTML`.
- `CollaborationGroupMemberRequest.Status` is not writable on insert (it defaults
  to Pending; only updatable).
- `CollaborationGroup` names are unique org-wide, even in tests — use
  non-colliding names in Apex tests.
- Sandboxes don't copy Content Asset file bytes or Chatter feed data — export
  binaries from production; expect empty feeds in staging.
- The Terms & Conditions login flow must use the classic VF runtime
  (`useLightningRuntime=false`) on LWR.
