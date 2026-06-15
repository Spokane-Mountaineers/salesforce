# Activity Groups

The Activities section is a dynamic, club-managed groups feature that replaces the
legacy site's mix of nine hardcoded activity-group pages plus a separate group
list. This page documents what was built and the constraints discovered along the
way (which lead directly into the [Chatter Data Migration](chatter-migration.md)).

## What the legacy site did

The old site had two things that didn't line up:

- nine hardcoded activity-group pages (Climbing, Hiking, Skiing, and so on), and
- a separate Chatter "groups" list that linked to per-group pages.

The hardcoded pages and the list entries didn't always match, which was a known
pain point. Behind both, an activity group is a Chatter group
(`CollaborationGroup`) — there are around 50, public and private, including
bespoke ones the chairs create ad hoc (Gear Swap, Book Club, Orienteering, the
per-year school cohorts, and more). The group pages were Chatter group record
pages: feed, members, and events.

## What we built

One unified, data-driven model, so the hardcoded/list mismatch goes away and
bespoke groups appear automatically because they're data, not code.

### Directory — `/activities`

`groupDirectory` lists the activity groups, busiest first. The nine **core
groups** are featured in their own section; everything else lists under "More
groups." A group is "core" if its name matches an active
`Event_Registration__c.Activity_Group__c` picklist value — the groups that have
the formal per-group event-approval workflow. That keeps "core" data-driven: a
new core group is a picklist value plus an approval process, not a code change.

The nav entry is a single **Activities** link to this directory, not a hardcoded
dropdown.

### Group page — `/group?recordId=…`

`groupDetail` is one dynamic page that serves every group, core and bespoke
alike, so there is no longer a hardcoded-versus-list mismatch. It shows:

- the group header (name, description, member count, public/private),
- membership controls (join/leave and notification frequency — see below),
- the group's upcoming events (the events calendar preset to the group, via the
  `Activity_Group__c` filter), and
- the group feed.

### Administration

Chairs and group managers used to have bespoke per-group sites. The new model
gives every group one consistent admin front: when the viewer is the group's
Chatter admin or owner, `groupAdminPanel` appears on the group page with controls
to edit the description, approve or decline join requests, and remove members.
Every admin action is gated server-side (`assertAdmin`); non-admins never see the
panel or reach the methods.

Event approvals deliberately stay in Salesforce. The nine per-group approval
processes on `Event_Registration__c` (Climbing, Hiking, Skiing, Paddling,
Mountain Biking, Road Biking, Conservation, Chalet, Clubwide) are untouched —
members create events on the site, which route to the chair's approval as they do
today. This is the "no web-dev needed for chair operations" requirement: adding
or removing an admin is a group-membership change, and bespoke groups just work
because they're data.

### Membership and notifications

Members self-serve on the group page:

- **Join / Leave.** Public groups join instantly; private groups create a pending
  request the admin approves through the admin panel.
- **Members-only feed.** Non-members read a public group's feed but see "Join
  this group to post"; the composer appears once you're a member.
- **Notification frequency.** Each member sets their email digest (every post,
  daily, weekly, or never). **New members default to daily** — the previous
  default was weekly.

## Constraints discovered

These shaped the implementation and surface the migration need:

- **Network scoping on reads.** Chatter scopes group visibility to the running
  user's network, so a plain `with sharing` query returned the club's public
  groups to an admin but nothing to a community member (an empty directory). The
  controller reads through a `without sharing` selector and applies its own
  public/own-private rule, so members see every public group plus the private
  ones they belong to.
- **The "group not found" false reject.** The feed post controller checked the
  group existed with a `with sharing` query, which hid it from community members
  and produced "Chatter group not found or you do not have access." It now looks
  up the group `without sharing`; Chatter still enforces who may actually post.
- **You can't join via direct DML.** Inserting a `CollaborationGroupMember`
  directly throws "insufficient access rights on cross-reference id." Joining goes
  through `ConnectApi.ChatterGroups.addMember` instead (the supported self-join
  path), then sets the new member's digest to daily.
- **The network boundary (the big one).** Even via ConnectApi, joining fails with
  "Insufficient Privileges" because the groups belong to the legacy Aura network,
  not the LWR network, and Chatter groups are network-bound. Reading feeds and
  events works (that's plain Apex over org data), but join and post are
  network-scoped. Resolving this is the data migration — see
  [Chatter Data Migration](chatter-migration.md).

## Component map

| Component                 | Role                                                                                                         |
| ------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `ActivityGroupController` | Reads groups/members through a `without sharing` selector; join/leave; notification frequency; admin actions |
| `groupDirectory`          | The `/activities` directory (featured core + the rest)                                                       |
| `groupDetail`             | The dynamic `/group` page (header, membership, events, feed)                                                 |
| `groupAdminPanel`         | Admin-only management panel (description, members, requests)                                                 |
| `eventsCalendar`          | Reused on the group page, preset to the group via the `activity` API                                         |
| `smiFeed`                 | The group feed; `readOnly` for non-members                                                                   |
| `loginGate`               | Friendly sign-in card for guests                                                                             |

## A note on staging data

Staging is a thin copy: it has only the nine core groups, originally
`IsArchived = true` with one member each. To make the feature testable, three
bespoke public groups were seeded (Book Club, Gear Swap, Orienteering) and the
nine core groups were un-archived. Real member counts and the full set of bespoke
groups exist only in production.
