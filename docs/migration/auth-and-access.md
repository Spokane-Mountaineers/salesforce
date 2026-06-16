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

Three independent causes, found by walking the path on staging:

1. **Unverified sender (the real bug).** The site's sender was
   `webdev5@spokanemountaineers.org`, which is not a verified Org-Wide Email
   Address. Experience Cloud silently drops forgot-password and welcome mail
   when the configured sender isn't verified. The fix is to set the sender to a
   verified address — `admin@spokanemountaineers.org`. This is the value now in
   `SITE_SENDER_EMAIL` (`.env.staging` / `.env.production`).

    `Network.EmailSenderAddress` is read-only to both the Metadata API and Apex,
    so it **cannot** be deployed — it must be set once per org in the UI:
    _Experience Workspaces → (Spokane Mountaineers LWR) → Administration →
    Emails → Sender Email Address_ → pick the verified address → Save. The env
    var documents the intended value and feeds `just create-site` on a fresh org.

2. **Sandbox email masking.** A sandbox refresh appends `.invalid` to every
   user's email, so reset mail to most staging members can't be delivered. Test
   with an account whose email has been de-masked to a real inbox. This does not
   affect production.

3. **Site status.** While the site is `UnderConstruction`, the public
   forgot-password page is reachable only via authenticated preview. It works
   for everyone once the site is activated.

Deliverability itself is fine — an anonymous-Apex send test succeeded, and the
Forgot Password / Welcome / Change Password community templates are active.

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
