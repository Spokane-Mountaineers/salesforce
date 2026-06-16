# Authentication & Access

How members sign in to the LWR site, what guests see, and the access plumbing
behind it.

## Login

The login page is a custom Lightning Web Component (`communityLogin`) styled to
the Alpine Field Guide, backed by `CommunityLoginController`. It keeps the
behavior the club already relied on:

- **Email-based login.** Usernames are normalized with a `.smi` suffix so members
  sign in with just their email. The controller appends `.smi` if it isn't
  already there.
- **Username/password** via `Site.login`, which authenticates and returns a
  redirect URL the component sends the browser to. A failed login surfaces a
  friendly "Invalid username or password" rather than a stack trace.
- **Single sign-on** with Google and Microsoft, linked from the login card.

### Return to where you were headed

The login flow honors a `startURL` query parameter. When a member is sent to
login from somewhere, that destination is preserved and they're returned there
after authenticating. Two places set it:

- The header **Log in** button carries the current page as `startURL`.
- The login gate (below) does the same from any member-only page.

## Password reset

`communityForgotPassword` is a branded reset request page that calls
`CommunityLoginController.requestPasswordReset`, which runs `Site.forgotPassword`
on the normalized username and always reports success (so the page never reveals
whether an account exists). The "forgot password" link points at the LWR site's
own `/ForgotPassword` route, not the Aura `/CommunitiesForgotPassword` VF page.

### Why the reset email wasn't arriving

The platform is healthy — an anonymous-Apex send test succeeded, and the Forgot
Password / Welcome / Change Password community templates are active. The mail
fails for two stacked reasons, plus two staging-only caveats.

**1. The sender address isn't a verified Org-Wide Email Address.** The site
sends as `webdev5@spokanemountaineers.org`, which isn't an OWEA (and isn't even a
real mailbox). Experience Cloud drops forgot-password and welcome mail when the
configured sender isn't verified. It must point at a verified OWEA —
`admin@spokanemountaineers.org`. That's the value now in `SITE_SENDER_EMAIL`
(`.env.staging` / `.env.production`).

`Network.EmailSenderAddress` is read-only to both the Metadata API and Apex, so
it **cannot** be deployed — set it once per org in the UI: _Experience
Workspaces → (Spokane Mountaineers LWR) → Administration → Emails → Sender Email
Address_ → pick the verified address → Save. The env var documents the intended
value and feeds `just create-site` on a fresh org.

**2. The `spokanemountaineers.org` domain isn't authenticated (DKIM).** The org
has zero DKIM keys (`SELECT Id FROM EmailDomainKey` returns nothing), so
Salesforce isn't authorized to sign mail as `@spokanemountaineers.org`. A verified
OWEA on an unauthenticated domain still fails SPF/DKIM alignment at the recipient
(Gmail spam-folders or rejects), and Salesforce is rolling out a hard block on
sends from unverified domains. The durable fix is to DKIM-authenticate the domain
(runbook below), after which any `@spokanemountaineers.org` sender is club-branded
_and_ deliverable.

#### Runbook: authenticate the domain and turn on reset mail

Per org (do it in staging first, then prod at cutover — the selectors differ, so
publish both sets of DNS records):

1. **Create a DKIM key.** Setup → _DKIM Keys_ → **Create New Key**. Domain
   `spokanemountaineers.org`, key size 2048, match the exact domain. Salesforce
   generates a key pair and shows **two CNAME records** (a primary and an
   alternate selector, for rotation).
2. **Publish the CNAMEs** in the `spokanemountaineers.org` DNS zone exactly as
   shown. Wait for propagation (minutes to a few hours).
3. **Activate the key.** Back on the DKIM Keys page, activate it — Salesforce
   validates the CNAMEs resolve before it will sign with them.
4. **Set the site sender** to `admin@spokanemountaineers.org` (the manual step
   from cause #1). If a send still fails, open that OWEA and enable _Allow All
   Profiles_ (community mail can send from an automated context).
5. **Test** the forgot-password page with an account whose email is a real inbox
   (see the sandbox caveat below).

**Staging-only caveat A — email masking.** A sandbox refresh appends `.invalid`
to every user's email, so reset mail to most staging members can't be delivered.
Test with a de-masked account. Doesn't affect production.

**Staging-only caveat B — site status.** While the site is `UnderConstruction`,
the public forgot-password page is reachable only via authenticated preview. It
works for everyone once the site is activated.

## Terms & Conditions login flow

Members must accept the Terms & Conditions, enforced by a profile-level login
flow. Login flows are configured per profile (there is no per-site setting).

The gotcha: a login flow with `useLightningRuntime=true` renders through Aura's
`flowLightningOut.app`, which returns a 401 on an LWR site because LWR can't host
Aura. Setting `useLightningRuntime=false` runs the flow through the classic
Visualforce runtime, which works on both site types. The three community profiles
carry the Terms & Conditions flow with this setting.

A related repo gotcha: the `@prettier/plugin-xml` formatter corrupts the profile
`<loginFlows><flow>` element (it injects a stray character), which makes the
profile undeployable. The affected profiles are listed in `.prettierignore`.

## The logged-out story

Guests who reach member-only content should get a friendly nudge to sign in, not
an empty page. The reusable `loginGate` component renders a card — heading,
message, a "Sign in" button, and a "Back to home" link — where the Sign in link
carries the current page as `startURL` so the member returns after login.

It is applied to the pages that need a logged-in member:

- the Activities directory and any group page, and
- the My Mountaineers (Basecamp) dashboard.

`loginGate` is reusable and exposed, so any other member-only page can adopt the
same pattern. This is an in-page gate; it works regardless of the platform's
page-level authentication setting. If a hard, route-level block is wanted later
(no page render at all for guests), that's the per-page "Requires Login" setting,
configured at cutover.

## Access plumbing

A few non-obvious requirements make authenticated access work:

- **Guest profile Apex access.** The guest profile needs access to the
  controllers used on public pages. Without it, pages fail with "Failed to get
  error from response." New controllers (for example `ActivityGroupController`)
  are added to the relevant profiles' `classAccesses`.
- **Member profiles in the network.** The three community profiles
  (`SM Community Plus Login`, `Member`, `Chair`) must be in the LWR network's
  `networkMemberGroups`, or authenticated users get
  "NO_ACCESS: not authorized for the community."
- **SSO redirect URIs.** Google and Microsoft each need the site's callback URL
  registered in their app configuration. The production callback URLs are
  registered at cutover.
