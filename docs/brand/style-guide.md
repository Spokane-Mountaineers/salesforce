# Style Guide

The **Alpine Field Guide** design system — the shared look for Spokane
Mountaineers digital surfaces. It started as the member [FAQ
page](../members/index.md) and is now a reusable theme we apply as we convert
existing content.

The look: a warm topographic "paper," deep evergreen, a trail-marker rust
accent, and an editorial serif (Fraunces) paired with a clean humanist body
(Public Sans). Calm, scannable, outdoorsy — a printed field guide, on screen.

---

## Using the theme

One stylesheet, `smi-theme.css`, holds the tokens and `smi-` component classes.

- **Docs site** — loaded via `extra_css` in `mkdocs.yml`. Add `class="smi-…"` in
  HTML blocks (this page is the reference).
- **Experience Cloud (LWC)** — the same file is mirrored to the `smi_theme`
  static resource (`just sync-theme` keeps the copies identical). Light-DOM
  components load it with `loadStyle`; the `faqPage` LWC is the shadow-DOM
  reference implementation and uses the same tokens inline.
- **Anywhere else** — link `smi-theme.css` directly (standalone HTML, email).

Tokens are declared on `:root, :host`, so the file works in a normal document
**and** inside an LWC shadow root unchanged.

!!! note "Keep the two copies in sync"

    `docs/stylesheets/smi-theme.css` is canonical. After editing it, run
    `just sync-theme` to mirror it into the Salesforce static resource before
    deploying.

---

## Color

Brand colors carry meaning — evergreen for structure, rust for emphasis and
calls to action, sky for links and information, moss for gentle/secondary notes.

<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px;margin:1em 0" markdown>
<div style="border:1px solid var(--smi-line);border-radius:10px;overflow:hidden"><div style="height:64px;background:var(--smi-pine)"></div><div style="padding:8px 10px;font-size:.8rem"><strong>Pine</strong><br><code>--smi-pine</code><br>#1E4B38</div></div>
<div style="border:1px solid var(--smi-line);border-radius:10px;overflow:hidden"><div style="height:64px;background:var(--smi-pine-2)"></div><div style="padding:8px 10px;font-size:.8rem"><strong>Pine&nbsp;2</strong><br><code>--smi-pine-2</code><br>#2C6A4E</div></div>
<div style="border:1px solid var(--smi-line);border-radius:10px;overflow:hidden"><div style="height:64px;background:var(--smi-moss)"></div><div style="padding:8px 10px;font-size:.8rem"><strong>Moss</strong><br><code>--smi-moss</code><br>#6E9173</div></div>
<div style="border:1px solid var(--smi-line);border-radius:10px;overflow:hidden"><div style="height:64px;background:var(--smi-rust)"></div><div style="padding:8px 10px;font-size:.8rem"><strong>Rust</strong><br><code>--smi-rust</code><br>#B14A1E</div></div>
<div style="border:1px solid var(--smi-line);border-radius:10px;overflow:hidden"><div style="height:64px;background:var(--smi-sky)"></div><div style="padding:8px 10px;font-size:.8rem"><strong>Sky</strong><br><code>--smi-sky</code><br>#2C6A8C</div></div>
<div style="border:1px solid var(--smi-line);border-radius:10px;overflow:hidden"><div style="height:64px;background:var(--smi-paper)"></div><div style="padding:8px 10px;font-size:.8rem"><strong>Paper</strong><br><code>--smi-paper</code><br>#F4EFE3</div></div>
<div style="border:1px solid var(--smi-line);border-radius:10px;overflow:hidden"><div style="height:64px;background:var(--smi-ink)"></div><div style="padding:8px 10px;font-size:.8rem;color:var(--smi-ink)"><strong>Ink</strong><br><code>--smi-ink</code><br>#1C2520</div></div>
</div>

| Token                                              | Use                                        |
| -------------------------------------------------- | ------------------------------------------ |
| `--smi-pine` / `--smi-pine-2` / `--smi-pine-deep`  | Primary structure, headings, hero gradient |
| `--smi-rust` / `--smi-rust-soft`                   | Accent, warnings, primary buttons          |
| `--smi-sky`                                        | Links, informational notes                 |
| `--smi-moss`                                       | Soft/secondary notes, list markers         |
| `--smi-paper` / `--smi-paper-2` / `--smi-card`     | Surfaces                                   |
| `--smi-ink` / `--smi-ink-soft` / `--smi-ink-faint` | Text                                       |
| `--smi-line` / `--smi-line-strong`                 | Hairlines, borders                         |

---

## Typography

<div class="smi-prose" markdown>

- **Display** — Fraunces (`--smi-font-display`). High-contrast editorial serif.
  Headings, hero, numerals.
- **Body** — Public Sans (`--smi-font-body`). Clean and legible at length.
- **Mono** — JetBrains Mono (`--smi-font-mono`). Code and the `.smi` username token.

</div>

<div style="margin:1em 0" markdown>
<div style="font-family:var(--smi-font-display);font-weight:900;font-size:48px;line-height:1;letter-spacing:-.02em;color:var(--smi-pine)">Frequently <em style="font-weight:500">Asked</em></div>
<div style="font-family:var(--smi-font-display);font-weight:600;font-size:30px;color:var(--smi-pine);margin-top:.3em">Section heading</div>
<div style="font-family:var(--smi-font-body);font-size:18px;line-height:1.7;margin-top:.5em;max-width:60ch">Body copy in Public Sans. The system pairs a characterful display serif with a quiet, readable body so long content stays calm and scannable. Inline tokens like <code class="smi-code">you@example.com.smi</code> use the mono face.</div>
</div>

---

## Components

The gallery below renders the actual `smi-` classes.

### Eyebrow + section header

<div class="smi-prose" style="background:var(--smi-paper);border:1px solid var(--smi-line);border-radius:12px;padding:24px" markdown>
<p class="smi-eyebrow">Spokane Mountaineers · Member Help</p>
<div class="smi-section__head"><span class="smi-badge-idx">01</span><h2 style="margin:0">Logging in</h2></div>
<div class="smi-rule"></div>
<p style="margin:0">Section body introduces the topic in a sentence or two.</p>
</div>

### Callouts

<div class="smi-prose" markdown>
<div class="smi-callout smi-callout--warn"><p><strong>Warning.</strong> Use for the highest-stakes guidance — e.g. renew with your email, never your <code class="smi-code">.smi</code> username.</p></div>
<div class="smi-callout smi-callout--note"><p><strong>Note.</strong> Use for helpful asides and clarifications.</p></div>
<div class="smi-callout smi-callout--tip"><p><strong>Tip.</strong> Use for optional, nice-to-know guidance.</p></div>
</div>

### Table

<div markdown>
<table class="smi-table">
<thead><tr><th>Setting</th><th>What you get</th></tr></thead>
<tbody>
<tr><td>Every Post</td><td>An email every time someone posts to the group</td></tr>
<tr><td>Weekly Digest</td><td>The past 7 days in a Sunday-morning email</td></tr>
</tbody>
</table>
</div>

### Buttons & tags

<div style="display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:1em 0" markdown>
<a class="smi-btn smi-btn--primary">Renew membership</a>
<a class="smi-btn smi-btn--ghost">Learn more</a>
<span class="smi-tag">Members only</span>
</div>

### Call-to-action

<div class="smi-cta" markdown>
<h2>Still need help?</h2>
<p style="margin:0">Email <a href="mailto:membership@spokanemountaineers.org">membership@spokanemountaineers.org</a> and a club volunteer will help you out.</p>
</div>

---

## Principles

1. **Calm and scannable.** One idea per section, generous spacing, a clear
   trailhead (eyebrow → title → rule).
2. **Accent with intent.** Rust draws the eye to the few things that matter most
   — not everything.
3. **Frame the evidence.** Screenshots get a consistent border, radius, and
   shadow (`.smi-figure`), and enlarge on click.
4. **Motion is a whisper.** A single staggered rise on load; everything respects
   `prefers-reduced-motion`.
5. **Tokens first.** Reach for a `--smi-*` token, never a raw hex, so a future
   palette tweak flows everywhere.
