# LWR Site Overhaul — Replacing the Aura Customer Service Member Site

Status: **Draft / in research.** Most direction is now settled (2026-06-08 working session). Remaining open items are narrow and listed in [§11](#11-remaining-open-items).

Date started: 2026-06-08
Author: Jason Adams
Target for all initial work: `--target-org staging` only. Nothing ships to `production` without team buy-in.

---

## 1. Goal

Replace the legacy Aura **Customer Service (Napili)** Experience Cloud site (`Spokane_Mountaineers1`, the org's only web presence at www.spokanemountaineers.org) with a Lightning Web Runtime (LWR) site on the **Alpine Field Guide** design system. The overhaul covers:

- Every page members actually use, rebuilt with a clean, consistent UI.
- A **durable content/blog system** — trip reports, ecomm/club news and announcements, general member-lookup content — with predefined and user-defined **tags** that members can search and filter on. This is net-new and is a headline feature, not a port.
- A **rescue of historical trip reports** currently buried in Chatter feeds (effectively lost after they scroll off): identify them, convert them to rich trip reports on the new site, and pull their images along.
- **Real-time community chat moved to Slack** (Salesforce Channels), gated on active membership through Experience Cloud SSO, run on the free tier so it stays at $0. Durable content does not live in Slack.
- A persistent **in-site feed** for announcements and discussion that should not disappear.
- **Events** reworked for clean admin and member workflows (the core of day-to-day club life).
- A single source tree deploying to both `staging` and `production`, with a **pull (refresh) → push** loop so staff edits in Experience Builder survive code deploys.

This document is the system of record. It is paired with a full local snapshot of the production site under `docs/plans/_reference/` (see [Appendix A](#appendix-a--local-reference-snapshot)).

---

## 2. Current-state inventory (production)

Pulled 2026-06-08 from `webdev5@smi.org` via Metadata API. The ExperienceBundle Metadata API was recently enabled in prod, so the bundle now round-trips cleanly.

### 2.1 Identity and settings

| Thing             | Value                                                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------- |
| ExperienceBundle  | `Spokane_Mountaineers1` (created 2018-01-04)                                                                           |
| Network           | `Spokane Mountaineers`                                                                                                 |
| CustomSite        | `Spokane_Mountaineers`                                                                                                 |
| Staging bundle    | `Spokane_Mountaineers_Sandbox1` (names differ by org — see [§7](#7-delivery-deployment-testing--commit-discipline))    |
| Template          | Customer Service (Napili), Aura                                                                                        |
| Domain            | www.spokanemountaineers.org (subdomain `spokanemountaineers`)                                                          |
| Member profiles   | `admin`, `sm community plus chair`, `sm community plus login`, `sm community plus member` (Customer Community Plus)    |
| Self-registration | **off** — membership is driven by DonorBox                                                                             |
| Login             | custom login page + Microsoft auth (both already built and working — see [§8](#8-auth))                                |
| Chatter           | Direct messages on, reputation off, member visibility on — being replaced (see [§4](#4-community-slack--in-site-feed)) |
| Branding          | legacy green `rgb(10,81,13)`, Montserrat/Lato — superseded by Alpine Field Guide                                       |

A second `checkout` CustomSite (a Visualforce ecomm/payments site from 2018) runs alongside the community. Out of scope here, but its dependency must be mapped so cutover doesn't break it.

### 2.2 Navigation (the real information architecture)

From `SFDC_Default_Navigation_Spokane_Mountaineers`. Public/Member shown.

1. **My Mountaineers** → `/my-mountaineers` (Member) — member home
2. **Activity Groups** → `/activities` (Public) — list of activity groups
3. **Calendar of Events** → `/events` (Public)
4. **Schools & Clinics** (menu, Public) — 19 children: About `/schools-and-clinics`, Backpack `/backpack-school`, Mountain `/mountain-school`, Rock `/rock-climbing-school`, Sport Lead `/sport-lead-school`, Multipitch Sport `/multipitch-sport-school`, Trad Lead `/trad-lead-school`, Alpine Climbing `/alpine-climbing-school`, Ice Climbing `/ice-climbing-seminar`, Aid Climbing `/aid-climbing-seminar`, High Angle Rescue `/high-angle-rescue`, Scramble `/scramble`, Wilderness First Aid `/wilderness-first-aid-course`, Leadership Development `/leadership-development-seminar`, Backcountry Skiing 101 `/backcountry-skiing-101`, Backcountry Ski School `/backcountry-ski-school`, Mountain Bike Fundamentals `/mountain-bike-fundamentals`, Mountain Bike Intermediate `/mountain-bike-intermediate`, For School Directors and Chairs `/for-school-directors-and-chairs`
5. **Resources** (menu, Public) — 9 children: Club Leadership `/club-leadership`, Our Mission `/our-mission`, Member Benefits `/member-benefits`, Kinni Online `/kinni-online` (M), Our Chalet `/our-chalet` (M), Member Resources `/member-documents` (M), Member Discounts `/member-discounts` (M), History `/100-years`, Club Logo Gear `/club-logo-gear` (M)
6. **Support** → `/contactsupport` (Public)

A second nav set, `Group_Navigation` (Climbing, Hiking tiles), feeds the activity-group landing tiles.

### 2.3 Page catalogue

113 views / 113 routes (they don't map 1:1 — several routes point at differently-named views; the rebuild collapses these to one clean route-per-page scheme). Full dump in [Appendix A](#appendix-a--local-reference-snapshot).

- **A. Custom content pages (port):** `home`, `aboutUs`, `ourMission`, `ourChalet`, `clubLeadership`, `clubLogoGear`, `memberBenefits`, `memberDiscounts`, `memberDocuments`, `kinniOnline`, `100Years`, `privacyPolicy`, `schoolsAndClinics` + the ~20 school/seminar pages.
- **B. Community pages (replace — see [§4](#4-community-slack--in-site-feed)):** `myMountaineers`, `activities`, `groupDetail` + 9 group pages, `feedDetail`, `questionDetail`, `streamList`/`Detail`, `topicCatalog`/`Detail`, `messages`, `groupList`.
- **C. Events (rework — see [§5](#5-events)):** `events`, `allEvents`, `eventDetail`, `eventRequests`, `eventRegistration*`.
- **D. Support / cases (build out — see [§4.5](#45-records-files-account-user-admin-cases)):** `contactSupport`, `myCases`, `caseDetail`/`List`/`RelatedList`.
- **E. Stock record pages (keep files / account mgmt / user admin; drop reports/dashboards):** `fileDetail`/`List`/`RelatedList`, `documentDetail`, `accountManagement`/`accountDetail`/etc., `userProfile`/`userList`/`userSettings`/`userRelatedList`, plus the unused `report*`/`dashboard*` set.
- **F. Auth / system (port — see [§8](#8-auth)):** `login`, `communitiesLogin`, `forgotPassword`, `checkPassword`, `register`, `loginError`, `error`, `serviceNotAvailable`, `tooManyRequests`, `flow`.
- **G. Cruft to drop:** `eVENTSSCREENSHOT`, `website`, the literal `MISSINGLABEL…` view.

### 2.4 Component usage (what the Aura site is built from)

Most-used: `richTextInline` (90), `seoAssistant` (74), `section`/layouts (62), `objectHome` (38), `lwcRecordDetail` (13), **`forceCommunityFeed` (12)** and **`feedPublisher` (12)** (the Chatter surface), `htmlBlock` (12), `relatedRecords`/`relatedList` (9 each), **`dynamicCollection*` + `managedContent*` (7 each — existing Salesforce CMS news collections)**, `calendar` (events), `salesforceIdentity:*` (auth), `selfService:caseCreate`/`similarQuestions` (support), and one `industries_service_excellence:omniscriptContainer` (trace before cutover). The `forceCommunity:*` Aura components have no drop-in LWR equivalent — that gap is the real migration work.

Worth noting: the site **already uses Salesforce CMS** (`managedContentCollectionDataProvider` + `dynamicCollectionGrid`) for news cards. That's a relevant precedent for the blog system in [§3](#3-content--blog-system-trip-reports-news-tagging).

### 2.5 Existing repo assets we build on

- `lwc/faqPage` — the **reference implementation** for Alpine Field Guide in an LWC (shadow-DOM token block, `faq_fonts` static resource). New pages follow this.
- `lwc/chatterPublisherWithAutosave` — custom publisher with localStorage autosave; seed of the in-site feed publisher. Active on `fix/chatter-publisher-rich-text`.
- `lwc/eventParticipantRelatedList`, `eventParticipantRedirect` — events plumbing.
- `staticresources/smi_theme.css` (mirror of `docs/stylesheets/smi-theme.css` via `just sync-theme`), `member_faq_images`, `faq_fonts`.
- Branches to port: `feature/custom-login-page`, `feat/communitielLogin-lwc`, `feat/microsoft-auth` (auth — done), and a case-management branch ([§4.5](#45-records-files-account-user-admin-cases)).

---

## 3. Content & blog system (trip reports, news, tagging)

This is the durable backbone that lets us run Slack on the free tier without losing anything. It must outlive any feed.

### 3.1 What it has to do

- Hold multiple content types: **trip reports** (member-authored), **ecomm/club news & announcements** (staff-authored), and general blog/reference posts members look up later.
- Rich content with **inline images**.
- **Tagging** with both a predefined/controlled vocabulary (e.g. activity = Climbing, Hiking, Skiing; region; difficulty) and **user-defined free tags**.
- **Search and filter by tag**, plus a browsable archive (by type, tag, date, author).
- Member authoring for trip reports, with a clean create/edit flow and image upload.

### 3.2 Data model (decided: custom object)

**Decided 2026-06-08:** a **custom object**, `Content_Post__c`, with a **record type per content type** (Trip Report, Announcement/News, Reference). One object keeps the index, tag filter, and search uniform across types; record types drive different create UX and permissions.

- **Fields:** `Title__c`, `Body__c` (rich text), `Status__c` (Draft / Published / Archived), `Publish_Date__c`, `Author` (OwnerId, preserved on import), `Activity__c` (controlled picklist: Climbing, Hiking, Skiing, …), plus type-specific fields (trip date, location/region, difficulty for trip reports).
- **Tags:** controlled vocabulary as `Content_Tag__c` + a `Content_Post_Tag__c` junction (filterable, reportable, governed). User-defined free tags via Salesforce **Topics** (or a simple multi-value free-tag field) so members can add their own without an admin minting picklist values. The tag filter UI queries both.
- **Images:** Salesforce Files (`ContentDocument`/`ContentVersion`) linked to the post, surfaced through a custom LWC gallery on the `faqPage` image/lightbox pattern. Same target the trip-report rescue re-hosts into ([§10.3](#103-convert-and-import)).
- **News/announcements:** same object, Announcement record type. The existing Salesforce CMS news collections ([§2.4](#24-component-usage-what-the-aura-site-is-built-from)) get reconciled into this in Phase 1 rather than maintained as a separate system.

### 3.3 Member authoring authorization

Members must be able to **create their own trip reports**. These are external **Customer Community Plus** users (`sm community plus member` profile), which support object CRUD, so this is a permission-and-sharing design, not a license blocker:

- **Permission set** (e.g. `Trip_Report_Author`) granting **Create + Read + Edit** on `Content_Post__c` and the needed fields, plus Create on the Topic/free-tag mechanism. Assigned to active members. Scope create to the **Trip Report record type only** so members can't post Announcements/News.
- **Sharing model:** org-wide default **Private** (or Public Read Only) on `Content_Post__c`; authors own their records (Owner = creating member) so they can edit their own. A **sharing rule / "Published" criterion** exposes `Status__c = Published` posts to all site members for reading. Members edit their own drafts; published posts are read-only to everyone but the author/staff.
- **Moderation (decided):** internal/member-only posts **publish on submit** (low friction, staff can unpublish). Making a post **public** requires staff **approval** — see the unified approval-gating model in [§5.5](#55-public-publishing--staff-gated-approval-events-and-blog). A `Visibility__c` (Internal / Public) field drives it: Internal is immediate; flipping to Public routes through the activity-group approval queues.
- **Authoring UX:** a member-facing create/edit LWC (not the raw Salesforce record form) with rich text, image upload, activity + tag pickers, styled in the field guide. Guest (logged-out) users never see create; the permission set is the gate.

### 3.4 UI surfaces

- Blog index / archive with tag chips and a tag filter (controlled + free), type filter, and search.
- Post detail (rich content + image gallery + tags + author + date).
- Trip-report authoring form (member-facing).
- Tag pages (all posts for a tag).
- Feeds of recent posts embedded on `home` and `my-mountaineers`, filtered to a member's followed tags/activities.

All styled through the Alpine Field Guide; these patterns get added back into the design system as they're built ([§9.3](#93-style-guide-gaps-to-close)).

---

## 4. Community: Slack + in-site feed

Two distinct needs, two mechanisms. Conflating them into Chatter is why content gets lost today.

### 4.1 The split

- **Ephemeral real-time chat → Slack** (Salesforce Channels). "Meet at the trailhead at 7," quick coordination, banter. Acceptable to lose after 90 days because it's not reference material.
- **Durable announcements & discussion → in-site feed** (kept, restyled, eventually SMI-owned). Things members should be able to find again.
- **Durable authored content → the blog/content system** ([§3](#3-content--blog-system-trip-reports-news-tagging)). Trip reports, news.

### 4.2 Salesforce Channels / Slack — findings and economics

Research, 2026-06-08:

- **Salesforce Channels** are Slack channels connected to Salesforce records (record tabs, CRM quick actions, AI summaries), now **included on every Slack plan, including Free**.
- **Slack Free** has no practical member cap but caps **message history at 90 days** (data over a year old is deleted), 10 apps, 5 GB storage. The 90-day cap is fine _only because durable content lives on the site_, not in Slack.
- **Nonprofit pricing:** 85% off paid plans. At ~1,000 members on Pro (~$7.25/user/mo list), 85% off is ~$1.09/user/mo → **~$1,090/mo ≈ $13k/yr**. Prohibitive. The free nonprofit grant covers ~250 seats, not 1,000.
- **SSO/IdP is free** (SAML, Experience Cloud as IdP — the `[[slack-experience-cloud-sso]]` track). **SCIM** auto-deprovisioning requires **Business+**, so removing lapsed members is manual for now.

**Recommendation:** run the membership Slack on **Free**, gate sign-in through Experience Cloud SSO so only members with active membership can authenticate, and keep all durable content on the site. Cost stays $0. This gives the membership Slack access (the stated goal) without the $13k/yr.

### 4.3 Lapsed-member deprovisioning without a paid tier

- Manual baseline: a Salesforce report of lapsed members → admin deactivates / removes them in Slack. Jason is fine doing this initially.
- Automation paths that avoid Business+/SCIM, to evaluate: Slack SCIM is gated, but the **Slack Web API** (`admin.users.*` requires Enterprise Grid; standard `users.*` is read-only for deactivation) is limited on free/pro — so true API deactivation likely needs a paid tier. Realistic free-tier automation is **gating at the IdP**: if SSO is the only way in and the IdP refuses lapsed members, they can't sign back in even if their Slack account lingers. Document this as the practical "soft deprovisioning" approach; hard removal stays manual until budget exists.

### 4.4 In-site feed (kept)

The member-visible, durable feed stays. Near-term it can run on the restyled native feed; the end-state is an SMI-owned feed built on `ConnectApi` (extending `chatterPublisherWithAutosave`) so look and retention are fully ours. The trip-report rescue ([§10](#10-chatter-history--trip-report-rescue)) reads from the same Chatter/`FeedItem` data, so keeping FeedItem as the store near-term also keeps history migration simple.

### 4.5 Records: files, account, user admin, cases

Decisions from the working session:

- **Keep and port:** Files (`fileList`/`fileDetail`/`documentDetail`), Account Management (`accountManagement` + account pages), User admin/profile (`userProfile`/`userList`/`userSettings`). Members use these.
- **Drop:** Reports and Dashboards (`report*`, `dashboard*`) — not used for membership.
- **Build out — Case Management:** members already create cases via `/contactsupport`, but it's unmanaged today. Port the existing **case-management branch** and implement it properly: member case create/list/detail, staff triage, the field-guide styling. This becomes a real supported workflow, not template furniture.

---

## 5. Events

Events are the core of day-to-day club life and are **eligible for a full rehaul** (not just a restyle), with the bar set at clean, easy management for **both admins and members** and visual consistency with the rest of the site. The headline question — change the data model or just the UI — needed a real look at what's there. Findings below.

### 5.1 How events actually work today (as-built)

Three objects, and the naming is the confusing part:

- **`Event_Registration__c`** (keyPrefix `a12`) is the **event itself** — the source of truth — not a per-person registration despite the name. ~2,567 records in prod. Fields: `Activity_Group__c`, `Leader__c`, `Start__c`/`End__c`, `Location__c`, `Registration_Type__c` (No RSVP / RSVP Optional / RSVP Required), `Limit_of_Attendees__c`, `Repeats__c`, `Parent_Event_Id__c`, `Number_Attending__c`, `Public__c`, `Status__c` (Requested → Submitted → Approved/Rejected), record types Approved/Unapproved.
- **`Event_Participant__c`** (keyPrefix `a11`, custom object) is the **per-attendee RSVP record** — lookups to `Event_Registration__c` and `Contact`, plus `Response__c`, `Currently_Logged_in_User__c`, and denormalized `Event_Name__c`/`Start__c`/`End__c`/`Location__c`. **8,576 records.** This is what the `eventParticipant*` LWCs, `EventParticipantTrigger`, and `EventParticipantFollowHandler` operate on, and what the `[[2026-03-18-fix-event-participant-contact-user-mapping]]` fix addressed. Attendance is already a clean custom object — good.
- **Standard Activity `Event`** (keyPrefix `00U`, 649 future-dated records) is **only a calendar-render mirror** — a denormalized copy synced from `Event_Registration__c` (via the `Event_Registration_Update_Parent_Event_when_Changed` flow) so the Aura `forceCommunity:calendar` and the managed **`cccalendar`** package can draw the calendar. It is not the event and not the attendee; it exists to feed the calendar widget.
- **Approval gating already exists and is good:** 9 `Event_Registration__c` approval processes (one per activity group) route a `Status = Requested` record to that activity's **approval queue** (`Climbing_Approval_Queue`, etc.) with field updates and committee email alerts. Membership of those queues is the answer to "who can approve events."
- **Public events are in active use.** In production, `Public__c = true` on 27 of 2,567 event records (e.g. "Wed Night Hike - Deep Creek," Hiking, Approved) — the rest are member-only. The public flag is real and approval-gated. (Counts are from **production**; staging is scrubbed — all `Public__c = false` there — so data-driven analysis must run against prod, not staging.)

### 5.2 Data-model deep-dive — recommendation

Your instinct to lean UI-only is the right call, and looking closely makes the case stronger, not weaker: the core data model is actually clean. The event is a custom object, attendance is a custom object with proper Contact lookups, and the approval model is genuinely good. I'm not going to manufacture a migration.

The one real piece of structural debt is **the standard Activity `Event` mirror (§5.1)** — a redundant denormalized copy whose only job is to feed the Aura calendar component. It brings the usual Activity-object baggage (special sharing model, weak reporting, WhoId/WhatId cruft) for no benefit beyond rendering. And here's the payoff: since the LWR rebuild needs a **custom calendar LWC anyway** (§5.3) that can query `Event_Registration__c` directly, the mirror, its sync flow, and quite possibly the `cccalendar` managed package all become **removable**. That is a simplification the migration hands us for free — fewer moving parts, no Activity baggage, one less managed dependency.

So the recommendation:

- **Keep** `Event_Registration__c` (the event) and `Event_Participant__c` (attendance) as-is. No schema churn on 2,500+ events or 8,500+ participants. Keep the 9 approval processes and queues.
- **Retire** the standard-`Event` calendar mirror once the custom LWR calendar exists: delete the `Event_Registration_Update_Parent_Event_when_Changed` sync, and evaluate dropping the `cccalendar` package (confirm it has no other consumers first).
- **Document, don't migrate**, the naming inversion (`Event_Registration__c` = the event). Optionally consider denormalization cleanup on `Event_Participant__c` later, but it's not load-bearing.

Net: this stays a UI project. The only data-model move is a deletion (the mirror), which reduces complexity rather than adding risk.

### 5.3 Calendar UI is a forced rebuild regardless

The Aura site rendered events with `forceCommunity:calendar` (plus the `cccalendar` package). **Neither has a drop-in LWR equivalent — LWR has no standard calendar component** — so a custom LWR calendar LWC is required no matter what. That custom calendar should bind directly to `Event_Registration__c`, which is what makes retiring the standard-Event mirror (§5.2) possible.

### 5.4 Scope of the events rehaul

- **Member side:** custom LWR calendar + list (bound to `Event_Registration__c`), event detail, register/cancel writing to `Event_Participant__c` (the `Community_Event_Registration_Screen_Flow` reworked or rebuilt as an LWC — see §6 flows), my registrations, waitlist clarity vs. `Limit_of_Attendees__c`, leader/participant info respecting the public-event participant-hiding rule (`[[2026-03-18-hide-event-participant-list-for-public-events]]`).
- **Admin/leader side:** create/manage events, manage participants, the event-request → approval workflow (`eventRequests`), attendance reporting off `Event_Participant__c`.
- **Reuse:** `Event_Registration__c`, `Event_Participant__c`, the approval processes/queues, the `eventParticipant*` LWCs, and the surviving flows (see the flow audit in §6).

A dedicated events design pass (through the `frontend-design` skill) covers calendar, event card, detail, and the registration flow.

### 5.5 Public publishing — staff-gated approval (events and blog)

Public visibility must be **staff-gated by approval** for both events and blog posts; member-only/internal content stays publish-on-submit. Reuse the model that already gates events:

- **Public events:** the per-activity **approval queues** that already gate event creation are the gate. A request flagged `Public__c = true` routes (via the existing per-activity approval processes, with entry criteria extended to the public flag) to that activity's approval queue — the same staff/chairs who approve events. Only after approval does the event become publicly visible to guests. This already works in production (27 public events today); the LWR rebuild must preserve the approval-gated `Public__c` path, not reinvent it.
- **Public blog posts:** mirror the same gating on `Content_Post__c`. Internal/member-only posts publish on submit ([§3.3](#33-member-authoring-authorization)). Flipping a post to **public** triggers an approval process routing to the activity-group approval queues (a post tagged Climbing → `Climbing_Approval_Queue`), or a single content-approval queue if a post isn't activity-specific. Approver membership is the same staff gating model as events, so "who can approve events" and "who can publish public content" stay one consistent list.

This unifies public-publishing governance across the site on one already-trusted mechanism: the per-activity approval queues.

---

## 6. Flow audit & migration coupling

26 flows live in the repo. The reassuring headline: **most of them are backend automation that doesn't care whether the UI is Aura or LWR** — membership lifecycle, user↔contact sync, opportunity processing, approval routing, notifications. Those migrate untouched. The genuine coupling to the site is concentrated in a small set of UI-embedded screen flows and a cluster of Chatter/CollaborationGroup flows that change meaning once chat moves to Slack. This section documents all of it so nothing surprises us at cutover.

### 6.1 How flows are wired into the Aura site

Two embedding paths in the current site:

- **`flow.json`** is a generic flow-runner route using `forceCommunity:flowCommunity` with a dynamic `{!flowName}` — any flow can be launched by name through it (URL/param-driven). Every flow reachable this way needs an LWR equivalent route, and we need to confirm which flows are launched through it before cutover.
- **`eventRegistrationDetail.json`** embeds `Community_Event_Registration_Screen_Flow` directly via `forceCommunity:flowCommunity`. This is the member RSVP flow and the tightest UI coupling in the site.

`forceCommunity:flowCommunity` is an Aura wrapper. In LWR, screen flows still run (via the Flow standard component / `lightning-flow`), so a flow _can_ be re-embedded with low effort — but where the goal is clean UX (RSVP, login terms), rebuilding as a purpose-built LWC is the better call. Both options are noted per flow below.

### 6.2 Disposition table (all 26)

Categories: **UI** = embedded/screen, site-coupled · **EVENT** = event backend automation · **CORE** = UI-agnostic backend (membership/user/opp) · **CHATTER** = CollaborationGroup/Chatter-coupled, revisit with Slack · **DEAD** = obsolete/invalid/draft to clean up.

| Flow                                                     | Type / trigger   | Object                   | Status       | Cat          | Disposition for LWR                                                                                                                                                   |
| -------------------------------------------------------- | ---------------- | ------------------------ | ------------ | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Community_Event_Registration_Screen_Flow`               | Screen           | Event_Participant\_\_c   | Active       | UI           | **Rebuild as RSVP LWC** (or re-embed via LWR Flow component as a fast path). Highest coupling.                                                                        |
| `Terms_Conditions_Login_Flow`                            | Screen           | User                     | Active       | UI           | Rewire into the new custom login ([§8](#8-auth)); keep the T&C gate, restyle.                                                                                         |
| `Redirect_to_User_Profile`                               | Screen / None    | EventRelation            | InvalidDraft | DEAD         | Broken draft on a standard Activity-relation object. Confirm unused, delete.                                                                                          |
| `Event_Registration_Submit_for_Approval_on_Create`       | RecordAfterSave  | Event_Registration\_\_c  | Active       | EVENT        | **Keep** — core approval routing. UI-agnostic.                                                                                                                        |
| `Event_Registration_Update_Record_Type_when_Approved`    | RecordBeforeSave | Event_Registration\_\_c  | Active       | EVENT        | Keep.                                                                                                                                                                 |
| `Event_Registration_Add_Leader_as_Participant_on_Create` | RecordAfterSave  | Event_Participant\_\_c   | Active       | EVENT        | Keep.                                                                                                                                                                 |
| `Notify_Leader_on_RSVP`                                  | RecordAfterSave  | Event_Registration\_\_c  | Active       | EVENT        | Keep (consider Slack/notification delivery later).                                                                                                                    |
| `Event_Registration_Update_Parent_Event_when_Changed`    | RecordAfterSave  | **Event (standard)**     | Active       | EVENT        | **Retire** with the calendar-render mirror ([§5.2](#52-data-model-deep-dive--recommendation)). Its only job is syncing the standard-Event copy for the Aura calendar. |
| `Event_Process`                                          | Workflow rule    | Event_Registration\_\_c  | Active       | EVENT        | Legacy Workflow Rule — migrate logic to Flow ([§6.4](#64-legacy-workflow-rules)).                                                                                     |
| `Event_Process_1`                                        | RecordAfterSave  | Event_Registration\_\_c  | Draft        | EVENT        | Incomplete draft — review intent; finish or drop.                                                                                                                     |
| `Notify_Subscribers_New_Event`                           | RecordAfterSave  | Event_Registration\_\_c  | Obsolete     | DEAD         | Already obsolete. If "notify on new public event" is still wanted, reimplement cleanly.                                                                               |
| `Membership_Daily_Check_for_Deactivation`                | Scheduled        | Opportunity              | Active       | CORE         | **Keep — critical** membership lifecycle. Untouched by UI migration.                                                                                                  |
| `Membership_Expiration_Reminder_Triggers`                | Scheduled        | Task                     | Active       | CORE         | Keep.                                                                                                                                                                 |
| `Opportunities_Update_Memberships_on_Create`             | RecordAfterSave  | Task                     | Active       | CORE         | Keep (DonorBox/membership).                                                                                                                                           |
| `Opportunity_Process`                                    | Workflow rule    | —                        | Active       | CORE         | Legacy Workflow — migrate to Flow ([§6.4](#64-legacy-workflow-rules)).                                                                                                |
| `Opportunity_Process_1`                                  | RecordAfterSave  | Opportunity              | InvalidDraft | DEAD         | Broken draft — fix or delete.                                                                                                                                         |
| `User_to_Contact_Sync_Trigger`                           | RecordAfterSave  | Contact                  | Active       | CORE         | Keep (user↔contact sync).                                                                                                                                             |
| `Sync_User_to_Contact`                                   | None             | Contact                  | Draft        | CORE         | Draft counterpart — reconcile with the active trigger above; likely redundant.                                                                                        |
| `User_Process`                                           | Workflow rule    | —                        | Active       | CORE         | Legacy Workflow — migrate to Flow.                                                                                                                                    |
| `Contact_Process_1`                                      | RecordAfterSave  | CustomNotificationType   | Active       | CORE         | Keep (custom notifications).                                                                                                                                          |
| `Contact_Process`                                        | Workflow rule    | —                        | Obsolete     | DEAD         | Delete.                                                                                                                                                               |
| `Create_New_Member_User`                                 | RecordAfterSave  | CollaborationGroupMember | Active       | CHATTER      | **Revisit with Slack.** Tied to Chatter group membership; if activity groups become Slack channels, this logic moves to Slack provisioning.                           |
| `Add_Chatter_Service_To_New_Groups`                      | RecordAfterSave  | User                     | Draft        | CHATTER      | Chatter-specific; likely **retire** with the Chatter→Slack move.                                                                                                      |
| `Remove_Members_From_Conservation_Group`                 | (autolaunched)   | CollaborationGroupMember | Draft        | CHATTER      | Chatter group mgmt — revisit/retire with Slack.                                                                                                                       |
| `Scheduled_Add_Members_To_Conservation_Group`            | Scheduled        | CollaborationGroupMember | Obsolete     | DEAD/CHATTER | Obsolete — delete; re-express as Slack channel membership if still needed.                                                                                            |
| `CreateCalendarsForNewUser`                              | (autolaunched)   | CalendarView             | Active       | EVENT        | Tied to the `cccalendar`/standard-calendar stack. **Revisit if `cccalendar` is retired** ([§5.3](#53-calendar-ui-is-a-forced-rebuild-regardless)).                    |

### 6.3 Where the migration risk actually is

- **RSVP flow (`Community_Event_Registration_Screen_Flow`).** The one piece of deep UI coupling. It reads Contact/User/Event_Registration and creates/updates `Event_Participant__c`, with capacity checks (limit hit / limit 0), approval checks, and email confirmation. Rebuilding it as an LWC is the clean path and folds into the events rehaul ([§5.4](#54-scope-of-the-events-rehaul)); re-embedding it via the LWR Flow component is the low-effort fallback if we need RSVP working before the LWC is ready.
- **Login terms (`Terms_Conditions_Login_Flow`).** Coupled to the auth path; rewire into the ported custom login.
- **Chatter/CollaborationGroup cluster.** Four flows manage Chatter group membership. The Slack decision ([§4](#4-community-slack--in-site-feed)) changes their purpose: if activity groups become Slack channels, group-membership provisioning shifts to Slack (SCIM/manual), and these flows are retired or re-pointed. This must be designed alongside the Slack rollout, not after.
- **Calendar-mirror sync.** `Event_Registration_Update_Parent_Event_when_Changed` (+ `CreateCalendarsForNewUser`) exist to feed the Aura calendar. They go away when the custom LWR calendar binds straight to `Event_Registration__c` ([§5.2](#52-data-model-deep-dive--recommendation)).

### 6.4 Legacy Workflow Rules

`Event_Process`, `Opportunity_Process`, `User_Process` (and obsolete `Contact_Process`) are old-style **Workflow Rules**, which Salesforce is sunsetting in favor of Flow. This overhaul is the moment to migrate the live ones to Flow and delete the obsolete one — independent of Aura vs. LWR, but worth doing while we're auditing automation.

### 6.5 Cleanup list (DEAD)

Confirm-unused-then-delete: `Redirect_to_User_Profile`, `Opportunity_Process_1`, `Contact_Process`, `Notify_Subscribers_New_Event`, `Scheduled_Add_Members_To_Conservation_Group`. Reconcile the `Sync_User_to_Contact` draft against the active `User_to_Contact_Sync_Trigger`. Removing these shrinks the automation surface before the migration rather than carrying dead weight across.

---

## 7. Delivery: deployment, testing & commit discipline

How we work, not just what we build. Two hard deployment requirements (one codebase to both orgs; a pull→push loop that preserves staff edits), a **contract-level testing** bar that every phase must clear, and a **commit discipline** that keeps the tree clean as we go.

### 7.1 The round-trip problem

Experience Builder rewrites view/route JSON (GUIDs, ordering, attribute blobs) on every publish, so a naive bundle diff after a staff edit is huge and merge-hostile. Strategy:

- Treat the deployed bundle as **partially staff-owned**: page _content/composition_ staff arrange in Builder is pulled and committed as source of truth for those pages; our _code_ (LWCs, Apex, static resources, theme) is owned in the repo and pushed.
- **Normalize on pull.** `just refresh` retrieves and runs a normalizer (stable key ordering, strip volatile-meaningless fields) so diffs are reviewable. Commit the normalized form.
- **Component boundary.** Push logic into versioned LWCs (which live in `force-app/lwc`, not the bundle JSON) so the bundle mostly references components by name, shrinking the collision surface.
- **Pull before push, always:** `just refresh` → review/commit staff changes → rebase code on top → `just deploy`.

### 7.2 One codebase, two orgs

- Org-specific values (site/network/customsite names, domain, guest user, record IDs, Slack/IdP config) stay out of committed metadata. Extend the existing `.env.staging` / `.env.production`.
- `just` recipes template/post-process bundle/site/network files at deploy time from the active env, so `force-app` stays org-neutral (the site is `Spokane_Mountaineers1` in prod, `Spokane_Mountaineers_Sandbox1` in staging — the recipe rewrites it).
- Custom Metadata / Custom Labels for any IDs Apex or LWCs need at runtime, set per org, never committed as literals.

### 7.3 `just` recipes (to design in Phase 0)

The **active org is implicit**, selected once via the existing env mechanism rather than passed to every recipe:

- `just use <env>` — select the active Salesforce env (e.g. `just use staging` → `.env.staging`). The argument is interpreted as `.env.<env>`; the recipe **fails if that env file doesn't exist**. Writes `SF_ENV` to `.envrc.local`; direnv loads `.env.<env>` (org, execution user) on reload. This replaces the old `use-staging` / `use-production` recipes with one parameterized recipe that accepts any env name. (Implemented.)

Every recipe below then acts on the current `SF_ENV` — **no `<org>` argument**:

- `just refresh` — retrieve ExperienceBundle + Network + CustomSite + NavigationMenu from the active org, normalize, leave for review.
- `just deploy` — `sync-theme`, apply org config, deploy source to the active org, report what needs manual publish.
- `just publish` — document/automate the Builder publish step (publish isn't fully API-driven).
- `just diff-site` — normalized drift detection vs. the active org.
- Guardrails: when `SF_ENV=production`, `just deploy` requires explicit confirmation and refuses test-skipping shortcuts (prod requires real test runs — `[[reference_salesforce_deploy_gotchas]]`).

Extends the existing `justfile` (already has `sync-theme` and `use`).

### 7.4 Contract-level testing

Testing is **baked into every phase, not bolted on at the end**. The emphasis is **contract tests**: verify the agreed shape of each boundary between components, so a change on one side that breaks the contract fails loudly and locally. Salesforce's 75% Apex coverage floor for prod deploys is a side effect of doing this well, not the goal.

The contracts we hold, and how each is tested:

- **Apex ↔ LWC.** Every `@AuraEnabled` controller method has an Apex test asserting its inputs, return DTO shape, and error behavior (including `AuraHandledException` messages). On the client, a **Jest** test per LWC mocks that Apex (and `@wire`) and asserts the component renders/handles the agreed shape. The method signature + DTO is the contract; both sides test against it. Jest runs via the existing `sfdx-lwc-jest` setup.
- **Permissions & sharing (critical for member authoring, [§3.3](#33-member-authoring-authorization)).** `runAs` tests with a Customer Community Plus community user assert the real rules: a member **can** create a Trip Report `Content_Post__c`, **cannot** create an Announcement record type, **can** read `Status = Published` posts, **cannot** read another member's draft, **can** edit their own. These tests are the executable spec for the permission set + sharing model — they catch a misconfigured OWD or sharing rule before members do.
- **Approval processes.** Apex tests that submitting an `Event_Registration__c` with `Public__c = true` routes to the correct per-activity queue, that approval flips `Status`/record type, and that a public `Content_Post__c` routes the same way ([§5.5](#55-public-publishing--staff-gated-approval-events-and-blog)). Assert against `ProcessInstance`/`ProcessInstanceStep`.
- **Flows.** Each surviving auto-launched/record-triggered flow gets an Apex test that drives its trigger condition and asserts the side effect (e.g. creating an `Event_Registration__c` adds the leader as an `Event_Participant__c`). The rebuilt **RSVP** logic ([§6.3](#63-where-the-migration-risk-actually-is)) is tested on its full contract: capacity limit hit, limit = 0, not-yet-approved, duplicate registration, happy path.
- **Data migration (trip-report rescue, [§10](#10-chatter-history--trip-report-rescue)).** Importer tests assert **idempotency** (re-running on the same `FeedItem.Id` creates no duplicates), that images re-host with linkage intact, that author and original date are preserved, and that the dry-run row counts match. This runs against staging before any production read.
- **Deployment round-trip.** A test that the bundle normalizer is **deterministic** (`normalize(normalize(x)) == normalize(x)`) and that org-config templating produces valid per-org metadata — so the pull→push loop ([§7.1](#71-the-round-trip-problem)) can't silently corrupt the bundle.
- **Accessibility / rendering.** Jest + DOM assertions on the shared UI primitives (header/nav, cards, blog, calendar) for keyboard and ARIA basics, since this is the org's only web presence.

Definition of done for a phase includes its contract tests written and green, plus coverage comfortably above the prod floor. CI runs Apex tests and Jest on every push (wire into the existing husky hooks).

### 7.5 Commit discipline

We commit **as we go** — no pile of uncommitted or loosely-tracked work accumulating across a phase.

- **Atomic, conventional commits.** Each commit is one cohesive change. "Atomic" means cohesive, **not** artificially tiny — a commit can be large if it's one coherent unit (a whole LWC plus its Jest test and meta is fine). Small is welcome, never required.
- **Conventional Commits**, matching the repo's existing style: `feat(events): …`, `fix(flow): …`, `refactor(brand): …`, `docs: …`, `test(blog): …`, `chore(deploy): …`. Scope names track the area (events, blog, community, auth, deploy, theme).
- **Tests travel with their code.** A feature commit (or its immediate follow-up) carries the contract tests from §7.4 — code and its test land together, not in a far-off "add tests" commit.
- **Working tree stays clean.** Generated/reference artifacts (the `docs/plans/_reference/` dump) stay git-ignored; member PII is never committed (`[[feedback_never_commit_member_pii]]` — this repo is public; stage explicitly, never `git add -A`). No Claude/AI attribution in commit messages.
- **Branch per phase/feature**, PR-reviewed, demoed in `staging` before merge.

---

## 8. Auth

Settled: the **custom login page is built, and Google and Microsoft auth is implemented — this work is complete.** Plan is to **port it into the new site and restyle it** to match the Alpine Field Guide. Self-registration stays off (DonorBox drives membership). Experience Cloud as **SAML IdP for Slack** is a **parallel track this project depends on** (not built here, but sequenced so the Slack rollout can use it).

---

## 9. Design system

### 9.1 Template and shell

New **Build Your Own (LWR)** site in `staging` (Aura→LWR is a rebuild; no in-place conversion). Working name `Spokane_Mountaineers_LWR`, finalized before first deploy. One custom theme-layout LWC supplies header (logo, nav, member/login state), footer, and the topographic background wash. Page templates are LWR sections; everything visual flows from Alpine Field Guide tokens, not the legacy Napili branding set.

### 9.2 Design system mapping

`docs/stylesheets/smi-theme.css` (573 lines, mirrored to `smi_theme` static resource) is the single brand source. Tokens: brand greens (`--smi-pine` #1e4b38, `--smi-pine-2`, `--smi-pine-deep`, `--smi-moss`, `--smi-rust`, `--smi-sky`), surfaces/ink, radius, shadow, 760px measure, contour SVG wash; Fraunces (display) + Public Sans (body) bundled as `faq_fonts`; `.smi-prose` / `.smi-code` / callouts. Shadow-DOM LWCs import the token block (faqPage pattern); light-DOM surfaces use the static resource via `loadStyle`. Run every new surface through the `frontend-design` skill for a distinct, non-generic result.

### 9.3 Style-guide gaps to close

Extracted from one FAQ page, the guide doesn't yet cover a full site. Net-new patterns to design and fold back into `smi-theme.css` (then `just sync-theme`):

- Site header / nav (desktop + mobile hamburger), member vs. logged-out states.
- Footer.
- Hero / banner for content and school pages.
- Card grid / collection tiles (activity groups, schools, events, blog).
- **Blog: index, post detail, tag chips/filters, author byline, image gallery.**
- **Event: calendar, event card, detail, registration flow.**
- Feed / post / comment styling.
- Form controls (case create, login, trip-report authoring).
- Buttons (primary / secondary / ghost) as reusable classes.
- Tables and definition lists for resource pages.
- **Photography & imagery system** — the "field plate" frame, scrim/overlay tokens, treatment policy, and reusable image components ([§9.5](#95-photography--imagery-system)).

### 9.4 My Mountaineers — layout options

The member home is a Chatter feed today. With Slack owning chat and the blog owning durable content, it should become a **useful personal dashboard**. **Selected: Option A, named "Basecamp."** (Avoid "Trailhead" — it collides with Salesforce's own Trailhead brand inside a Salesforce-built site. "Basecamp" is the mountaineering term for the staging point you organize from before heading out, which is exactly this page's job; alternates considered: "The Lookout," "Waypoint.") Options B and C are kept below for record but not chosen.

**Option A (SELECTED) — "Basecamp" (utility-first).** A slim membership-status strip on top (status, renewal date, member card). Then "Your upcoming events" as cards, "Jump to your Slack channels / activity groups" quick links, and "Latest from your activities" (blog feed filtered to followed tags). Quick actions: register, post a trip report. Bias toward at-a-glance utility; no dominant feed. Build as an ASCII-spec'd LWC dashboard in Phase 3.

```
┌───────────────────────────────────────────────┐
│  ✓ Active member · renews Mar 2027   [card ▸]  │
├──────────────────────────┬────────────────────┤
│  YOUR UPCOMING EVENTS     │  QUICK ACTIONS      │
│  ┌─────┐ ┌─────┐ ┌─────┐ │  + Post trip report │
│  │event│ │event│ │event│ │  → Open Slack       │
│  └─────┘ └─────┘ └─────┘ │  ⌕ Browse events    │
├──────────────────────────┴────────────────────┤
│  LATEST FROM YOUR ACTIVITIES (blog, by tag)    │
│  • Trip report …   • Club news …   • …          │
└────────────────────────────────────────────────┘
```

**Option B — "Field Journal" (content-forward).** Hero with member name + a countdown to their next event. Two columns: left = a personalized stream (announcements feed + recent trip reports for followed activities); right sidebar = membership card, my registrations, my activity groups (each linking into its Slack channel).

```
┌───────────────────────────────────────────────┐
│  Welcome back, Jason — next: Beacon Practice 3d│
├──────────────────────────────┬────────────────┤
│  STREAM                       │  ▸ Membership   │
│  ▸ Announcement …             │  ▸ My events    │
│  ▸ Trip report + photo …      │  ▸ My groups →  │
│  ▸ Trip report …              │    Slack        │
│  …                            │  ▸ My files     │
└──────────────────────────────┴────────────────┘
```

**Option C — "Command Center" (dense widgets).** A compact widget grid for power users: membership, next 3 events, my open cases, my files, recent announcements, jump-to-Slack, my trip reports. Everything one glance away; less editorial.

```
┌───────┬───────┬───────┬───────┐
│Member │Next   │My     │My     │
│status │events │cases  │files  │
├───────┴───────┼───────┴───────┤
│ Announcements  │ Jump to Slack │
├───────────────┼───────────────┤
│ My trip reports│ My groups     │
└───────────────┴───────────────┘
```

Decision: **Option A ("Basecamp")**, for being the most broadly useful for a 1,000-member club where most people just want "what's next and what's new." B/C retained above only as alternatives if the team reacts differently to a prototype.

### 9.5 Photography & imagery system

We're a mountaineering and outdoor club, and the photography is a real asset — the site already uses landscape shots as header (`IMG_2602_2`) and login (`IMG_0599`) backgrounds, and trip reports will bring a steady stream of member photos. The design challenge is cohesion: the Alpine Field Guide is a warm, papery, typographic system, and big vivid landscape photos can either elevate it or turn it into a generic photo-grid that throws the field-guide voice away. The resolution is a deliberate frame and a treatment policy, not "drop photos everywhere."

**Organizing idea — the "field plate."** Treat photographs the way a naturalist's field guide treats its plates: a catalogued specimen with a caption, not a raw image dump. A field plate is the photo + a thin keyline border (`--smi-line-strong`), an optional warm paper mat, and a caption set in the field-guide voice — a small-caps eyebrow plus a Fraunces-italic line carrying **location, date, and activity** (e.g. `ROCK · Minnehaha · Sep 2025`). This ties straight into the trip-report metadata ([§3](#3-content--blog-system-trip-reports-news-tagging)) and into the event/activity tags, so a member's snapshot becomes a labeled specimen in the club's collection. It's the distinctive move that keeps disparate photos feeling like one body of work.

**Treatment policy — color where it sings, restraint in the chrome.**

- **Full color** for the photographs that are the point: trip-report galleries, activity/school landing heroes, the Basecamp masthead. These are gorgeous; don't crush them. A light, consistent post-treatment (gentle warm grade, controlled contrast) unifies wildly different cameras and lighting without dimming them.
- **Restrained / duotone** only in UI chrome where legibility and cohesion beat fidelity: small thumbnails, tag-page headers, and the zone behind overlaid text. A pine-toward-paper duotone token keeps those surfaces on-brand and quiet so they don't compete with the real photos nearby.

**Text over photography.** Never raw white text on a busy photo. A standard scrim token — a `--smi-pine-deep` → transparent gradient — anchors the bottom (or a side) of any hero so overlaid display type stays legible, with `OverlayTextColor`/paper for the text. Define `--smi-scrim` once and reuse it everywhere text sits on an image. The topographic contour wash can sit at the seam where a full-bleed photo meets a paper section, stitching the two together.

**Where photos earn their place — and where they don't.** Photos belong on the home hero, activity/school landings, trip reports, event cards, and Basecamp. Reference, resource, and legal pages stay **photo-free** — pure type, paper, and contour — so the system breathes and the photography lands harder where it appears. The contrast between image-rich and image-quiet pages is the point, not an oversight.

**Craft & performance** (this is the org's only web presence, so it doubles as SEO/perf):

- A small set of standard aspect ratios — 3:2 landscape for plates/heros, 4:5 portrait for trip shots, 1:1 for thumbnails — so grids stay tidy.
- Responsive `srcset`/sizes, lazy-loading below the fold, modern formats; Experience Cloud's image-optimization CDN is already enabled (`enableImageOptimizationCDN` in the network) — lean on it.
- **Alt text is mandatory** on every photo (accessibility and SEO); member uploads prompt for it.

**Sourcing & rights.**

- A **curated "hero-eligible" set** — staff-selected, high-resolution, treated — drives marketing surfaces (home/activity heros), kept separate from the firehose of member trip photos. A CMS tag / flag marks an image hero-eligible.
- Member-submitted trip photos flow through the authoring LWC ([§3.3](#33-member-authoring-authorization)): auto-applied treatment, required alt text, an optional **photo credit** line, and a consent note (people appear in these photos — capture usage consent at upload).

**Reusable components** (added to `smi-theme.css` + LWCs, then `just sync-theme`): `FieldPlate` (captioned plate), `HeroImage` (full-bleed + scrim + overlay slot), `Gallery` (justified/masonry trip-report grid with lightbox — extends the `faqPage` lightbox), `Thumb`, and `EventCardImage`. Every photo on the site is framed by this shared vocabulary even though the photos themselves vary wildly — which is exactly what makes it feel cohesive.

This whole section is itself a **style-guide gap to close** ([§9.3](#93-style-guide-gaps-to-close)); design it through the `frontend-design` skill alongside the hero and card patterns in Phase 0/1, and fold the tokens (`--smi-scrim`, plate/caption classes) back into the canonical theme.

---

## 10. Chatter history & trip-report rescue

History is valuable and trip reports must be saved. This is a defined sub-project, detailed because it's the riskiest data work.

### 10.1 What exists

Trip reports and discussion live as Chatter `FeedItem` records (with `FeedComment` replies and `ContentDocument`/`ContentVersion` image attachments via `FeedAttachment`), posted into the nine activity groups (`CollaborationGroup`) and member feeds. After they scroll off, members can't find them — but the records still exist and are queryable.

### 10.2 Identify trip reports (the hard part)

There is no "is a trip report" flag, so identification is heuristic. Approach:

1. **Export** all `FeedItem` (+ `FeedComment`, `FeedAttachment` → `ContentDocument`) via Bulk API / SOQL, scoped to the activity-group `ParentId`s and date ranges. Keep author, group, timestamp, body, attachments.
2. **Classify** with a tiered heuristic: posts in activity groups, above a length threshold, that have image attachments, are strong trip-report candidates. Add keyword/title cues ("trip report," summit/route names, dates). Optionally an LLM pass over candidate bodies to label trip-report vs. chatter and extract a title/date/location.
3. **Human review queue:** present candidates (body + images + score) for a quick yes/no + tag assignment before import. This keeps quality high and avoids importing noise.

### 10.3 Convert and import

- For each confirmed trip report, create a `Content_Post__c` (record type Trip Report — [§3.2](#32-data-model-decided-custom-object)) with the original author as author, original date preserved, body converted from Chatter markup to the site's rich text, and **images re-hosted** as Files linked to the new record (download `ContentVersion` blobs, re-upload, relink).
- Auto-apply controlled tags from the source group (Climbing group → Climbing tag) and any tags the reviewer adds.
- Idempotent import keyed on source `FeedItem.Id` so re-runs don't duplicate.

### 10.4 Non-trip-report history

General discussion history that isn't trip reports: keep the legacy site/feed **readable** through cutover; if the end-state in-site feed stays on `FeedItem` ([§4.4](#44-in-site-feed-kept)), that history simply continues to render and nothing is migrated. Only the trip reports get promoted into durable, tagged blog posts. Decide at cutover whether to archive-export the remainder.

### 10.5 Deliverables

A repeatable script/job (Apex batch or external script via `ConnectApi`/Bulk), a review UI or simple report, and a dry-run mode that runs against `staging` first. No production reads beyond export until the team signs off.

---

## 11. Remaining open items

Most direction is settled. Still to decide, mostly during design phases:

- **Trip-report identification thresholds** ([§10.2](#102-identify-trip-reports-the-hard-part)): tune the heuristic against a real export sample; confirm whether an LLM-assisted pass is wanted.
- **`Event_Attendee__c` migration** ([§5.2](#52-data-model-deep-dive--recommendation)): the one advocated data-model change — move per-attendee RSVPs off the standard Activity Event object. Decision rule: do it only if the LWR build hits the Activity-sharing wall exposing RSVPs to community members; otherwise defer. Isolated sub-project, not a blocker.
- **In-site feed end-state timing** ([§4.4](#44-in-site-feed-kept)): how soon to move from native feed to the SMI-owned `ConnectApi` feed.
- **Slack free-tier deprovisioning automation** ([§4.3](#43-lapsed-member-deprovisioning-without-a-paid-tier)): confirm what's achievable without Business+ beyond IdP gating.

---

## 12. Roadmap (staging-first)

**Phase 0 — Foundations.** LWR site shell, theme layout, header/footer/nav. `just refresh`/`deploy` recipes + org-config abstraction; prove the pull→push loop. Close top style-guide gaps (header, footer, hero, buttons, cards) including the **photography/imagery foundations** — field-plate frame, `--smi-scrim`, `HeroImage` ([§9.5](#95-photography--imagery-system)) — since heros and cards depend on them. Run the **flow audit cleanup** ([§6.5](#65-cleanup-list-dead)) — delete the DEAD flows and reconcile the user-sync drafts — so the migration starts from a smaller automation surface. Confirm which flows launch through the `flow.json` runner ([§6.1](#61-how-flows-are-wired-into-the-aura-site)).

**Phase 1 — Content + blog system.** Port the ~35 custom content pages (low risk, high visibility). Build the blog/content data model, authoring, tag filtering, and archive ([§3](#3-content--blog-system-trip-reports-news-tagging)). This is the durable backbone everything else leans on.

**Phase 2 — Events.** Full rehaul: custom LWR calendar bound to `Event_Registration__c`, detail, the RSVP flow rebuilt as an LWC, admin/leader management ([§5](#5-events)). Retire the standard-Event calendar mirror + its sync flow ([§5.2](#52-data-model-deep-dive--recommendation)); migrate the legacy event Workflow Rule to Flow ([§6.4](#64-legacy-workflow-rules)).

**Phase 3 — Community.** Slack rollout on free tier behind Exp Cloud SSO (depends on the IdP track); restyled in-site feed; the My Mountaineers "Basecamp" dashboard ([§9.4](#94-my-mountaineers--layout-options)). Redesign the Chatter/CollaborationGroup flow cluster ([§6.3](#63-where-the-migration-risk-actually-is)) alongside the Slack model — group-membership provisioning moves to Slack.

**Phase 4 — Records & support.** Port files, account management, user admin; build out case management from the existing branch ([§4.5](#45-records-files-account-user-admin-cases)).

**Phase 5 — Auth & polish.** Port custom login + Microsoft auth, restyle ([§8](#8-auth)). Accessibility, SEO (this is the org's only web presence, so public content pages carry real SEO weight), redirects from old routes.

**Phase 6 — History migration & cutover.** Trip-report rescue ([§10](#10-chatter-history--trip-report-rescue)) dry-run in staging then for real; in-site feed end-state; production deploy behind team buy-in; DNS/domain cutover; legacy site archived but readable.

Every phase ships with its **contract tests** green ([§7.4](#74-contract-level-testing)) and its work landed as **atomic, conventional commits** ([§7.5](#75-commit-discipline)) — no phase closes on an uncommitted or untested pile.

Gate between phases: contract tests passing, demo in `staging`, team sign-off. Nothing touches `production` until Phase 6 and explicit approval.

---

## Appendix A — Local reference snapshot

Pulled from production for offline reference (git-ignored; regenerate with `just use production && just refresh` once recipes exist):

- `docs/plans/_reference/aura-site-prod-mdapi/unpackaged/unpackaged/` — full ExperienceBundle (`experiences/Spokane_Mountaineers1/` with `views/`, `routes/`, `variations/`, `themes/`, `brandingSets/`, `config/`), `networks/`, `sites/`.
- `docs/plans/_reference/nav-menus-mdapi/unpackaged/unpackaged/navigationMenus/` — `SFDC_Default_Navigation_Spokane_Mountaineers`, `Group_Navigation`.

237 view/route JSON files, network + site definitions, both nav menus, branding set, theme — all captured locally.

## Appendix B — Open research tasks

- Trace the one `industries_service_excellence:omniscriptContainer` — what OmniScript, still used?
- Export a real `FeedItem` sample to tune the trip-report identification heuristic ([§10.2](#102-identify-trip-reports-the-hard-part)).
- Confirm the external license type that supports Experience-Cloud-as-IdP for Slack (`[[slack-experience-cloud-sso]]`).
- Inventory existing `managedContent` / CMS news collections and reconcile with the blog data-model decision.
- Map the `checkout` Visualforce ecomm/payments site dependency so it isn't broken at cutover.
- Verify Slack Free member-count behavior and any current nonprofit-grant seat terms before rollout.
- ~~Enumerate every flow launched through the `flow.json` runner~~ **(resolved 2026-06-09).** The reference dump shows `routes/flow.json` binds exactly one flow — `Community_Event_Registration_Screen_Flow` (the RSVP flow, already the known high-coupling case in [§6.1](#61-how-flows-are-wired-into-the-aura-site)) — and `views/flow.json` carries the generic dynamic `{!flowName}`. No additional flows are wired through the runner, so nothing beyond the RSVP rebuild is missed.
- Confirm `cccalendar` managed-package consumers before retiring it ([§5.3](#53-calendar-ui-is-a-forced-rebuild-regardless)).
