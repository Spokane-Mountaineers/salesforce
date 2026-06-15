# Chatter Data Migration

This is the main piece of remaining work. The activity-group Chatter data — the
groups, their members, and their feed history — lives in the legacy Aura
community's network. The LWR site is a different network, and Chatter groups are
network-bound, so this data has to be brought into the LWR network before members
can join and post on the new site.

## The problem, precisely

- An activity group is a `CollaborationGroup`, and every group belongs to exactly
  one `Network`.
- In production, the groups belong to the legacy "Spokane Mountaineers" network
  (`0DB1N…`). Their members are mostly Customer Community Plus users.
- The LWR site is the "Spokane Mountaineers LWR" network (`0DBcW…`).
- Reading across networks works from Apex (that's how the LWR group pages already
  show feeds and events). But **membership, joining, and posting are
  network-scoped**: an LWR member can't join or post to a group owned by the
  legacy network. That's the "Insufficient Privileges" error.

So full group functionality on LWR requires the groups (and their members and
feed history) to exist in the LWR network.

## Critical platform constraint (discovered during de-risking)

Two platform rules make a naive "recreate the groups in the LWR network" plan
impossible while the legacy site is still up:

- **`CollaborationGroup.NetworkId` is not writeable.** You cannot move a group
  from one network to another by updating it (confirmed: "Field is not writeable:
  CollaborationGroup.NetworkId"). A group's network is fixed when it's created.
- **Group names are unique org-wide.** You cannot create a second "Climbing" in
  the LWR network while the legacy "Climbing" still exists (confirmed: "An active
  or archived group with this name already exists").

Together these mean: you can't move groups, and you can't copy them under their
real names while the originals exist. Any migration has to deal with the name
collision, which forces one of the approaches below.

## Revised options

### Option A — Rename-and-recreate at cutover (within the one org)

Pre-cutover, create the LWR-network groups under temporary names (via
`ConnectApi.ChatterGroups.createGroup` targeting the LWR community), and migrate
members and feed history into them (idempotent, re-runnable). At cutover, in a
tight sequence: archive/rename the legacy groups to free the names, then rename
the LWR groups to their real names.

- Pros: keeps native Chatter (mentions, group notifications, our daily-digest
  default), reuses the work already done.
- Cons: a delicate cutover window, name juggling, and the legacy groups must be
  retired as part of it. Feed-history copy still needs "Set Audit Fields."

### Option B — Move activity groups off Chatter to a custom data model

Stop using `CollaborationGroup` for activity groups. Model them as custom objects
(group, membership, post) owned by the LWR site, with no network binding. Migrate
the feed content into the custom post object (record copy, with Set Audit Fields
for original author/date).

- Pros: removes the network-binding problem entirely; migration becomes a
  straightforward record copy; full control over the model.
- Cons: the largest build — re-implements grouping, membership, and the feed off
  Chatter, and loses native Chatter features (we'd own notifications, mentions,
  etc.). The Activity Groups feature already built on `CollaborationGroup` would
  be re-pointed at the custom model.

### Option C — Keep Chatter on the legacy community; revisit later

Ship the LWR site with group pages that browse/read (which works cross-network),
and keep join/post pointed at the legacy community for now, or hide them until a
decision is made. Defer the data move.

### Option D — Salesforce Support / supported migration path

Open a case with Salesforce to confirm whether there's any supported way to move
groups between networks or convert the community, before committing to A or B.

## Is migration possible? (mechanics, once an approach is chosen)

Yes, with one important prerequisite and some known caveats. The pieces:

| Data                                     | Migratable?      | How                                                                                                                                |
| ---------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Groups (`CollaborationGroup`)            | Yes              | Recreate in the LWR network (set `NetworkId`), preserving name, description, and access type                                       |
| Memberships (`CollaborationGroupMember`) | Yes              | Re-add members via `ConnectApi.ChatterGroups.addMember`; apply the daily-digest default                                            |
| Feed posts (`FeedItem`)                  | Yes, with caveat | Recreate on the new groups; original author and timestamp preserved **only if** "Set Audit Fields upon Record Creation" is enabled |
| Comments (`FeedComment`)                 | Yes, with caveat | Same as feed posts                                                                                                                 |
| Files / attachments                      | Partial          | Need explicit re-upload and re-link; not automatic                                                                                 |
| Reactions / likes                        | No (practically) | Not reliably portable                                                                                                              |
| @mentions                                | Degrades         | Mention links point at the old context; render as text                                                                             |
| Polls, bookmarks                         | No (practically) | Not portable                                                                                                                       |

### The prerequisite: Set Audit Fields

Preserving the original author and post date requires the org permission **"Set
Audit Fields upon Record Creation"** (Create Audit Fields), which lets an insert
set `CreatedById` and `CreatedDate`. Without it, every migrated post shows the
running (integration) user and the migration date, which would make the feed
history useless. **Enabling this is a hard prerequisite** and must be confirmed
before building the feed portion.

## Design: a re-runnable migration tool

The migration needs to run more than once — a dry run, then again to catch
anything posted between then and cutover. So the tool must be **idempotent**:
re-running adds only what's new, never duplicates.

Approach:

- **Stable external keys.** Tag each migrated record with a deterministic
  reference to its source (for example the source group's `DeveloperName`, and for
  posts a hash of source id + author + timestamp). On each run, skip records whose
  key already exists in the target network.
- **Ordered phases.** Groups first, then memberships, then feed posts, then
  comments. Each phase is independently re-runnable.
- **Batched and resumable.** Feed volume can be large; process in batches and
  record progress so a failure mid-run can resume.
- **Dry-run mode.** Report what would be created without writing, so the scope can
  be reviewed before a real run.

Implementation will likely be Apex (Batchable/Queueable for the feed volume) plus
a small invocation surface, with the same `without sharing` selector pattern used
in `ActivityGroupController` for cross-network reads. Exact class design is the
first build step once scope is confirmed.

## Migration phases

### 1. Groups

For each source group in the legacy network, create or find the matching group in
the LWR network. Preserve `Name`, `Description`, and `CollaborationType`
(public/private). Map source group id → target group id for the later phases.

Decide what to include: all groups, or active (non-archived) only. Long-dead
cohorts (for example old per-year school groups) may not be worth carrying.

### 2. Memberships

For each source membership, add the user to the corresponding target group via
`ConnectApi.ChatterGroups.addMember`. Only users who are members of the LWR
network can be added, so this depends on the member provisioning for the new site
being complete. Apply the daily-digest default on creation.

### 3. Feed posts

For each `FeedItem` of type text post on a source group, create the equivalent on
the target group, setting `CreatedById` and `CreatedDate` from the source (needs
Set Audit Fields). Skip non-text post types in the first pass.

### 4. Comments

For each `FeedComment` on a migrated post, recreate it on the new post, again
preserving author and date.

### 5. Verify

Reconcile counts (groups, members, posts, comments) between source and target and
spot-check a sample of high-traffic groups (Clubwide, Conservation, Hiking).

## Open decisions before building

- **Confirm "Set Audit Fields" can be enabled** in production (and staging for
  testing). This gates the feed phases.
- **Scope of groups** to migrate (all vs. active only; whether very old cohorts
  are included).
- **Member provisioning**: members must exist in the LWR network before
  memberships migrate.
- **Files/reactions**: confirm these can be dropped, or scope the extra work.
- **Cutover timing**: the final re-run happens close to cutover to capture
  last-minute posts.

## Until then

While this is pending, the LWR group pages remain useful read-only: members can
browse the directory, see group descriptions, and view events. Join and post will
not work for groups still in the legacy network. If we want to avoid showing
non-functional buttons before the migration, the join/post controls can be hidden
until a group exists in the LWR network — a small, reversible change.
