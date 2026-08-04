# Simplified main UI — design spec

- **Issue:** [#92 — P1 UX: Reduce on-screen text and make the app understandable at a glance](https://github.com/meldusadm-coder/Unrecorded/issues/92)
- **Related:** [PR #90 — Simplify main protection experience](https://github.com/meldusadm-coder/Unrecorded/pull/90) (open, unmerged, based on `main`; superseded by this design — see "Relationship to PR #90" below)
- **Scope:** Single PR, whole issue (all screens listed in "Screen-by-screen treatment")
- **Status:** Approved by user in brainstorming session, pending written-spec review

## Problem

Unrecorded's screens currently show too much explanatory text at once. Users must read paragraphs before understanding protection state, and repeated caveats create visual noise. The goal is **glance first, detail on demand**: a user should identify protection state, current activity, and the primary control within a few seconds, with everything else progressively disclosed.

## Product guardrails (must hold throughout)

- Never claim recording can be proven; keep "possible risk," "signals that may match," "not proof of recording" language.
- Do not hide permission failures, OS limitations, or privacy information — relocate detail, don't delete it.
- Do not repeat the same caveat multiple times on one screen.
- No onboarding carousel/wizard introduced merely to relocate text.
- Keep British English and a calm, non-technical tone.

## Relationship to PR #90

PR #90 is open, targets `main` (not `dev`), and its `scan_screen.dart`/`ProtectionScreenUiState` implementation has diverged substantially from `dev`'s current `scan_screen.dart` (which already has partial simplification — a status card, collapsible helper text, a next-step banner). This design treats **`dev`'s current state as the real starting point** and is a fresh implementation. PR #90 is left untouched; whether to close it is a separate git-workflow decision outside this spec.

## Foundations (shared architecture)

### 1. Compact main-screen state model

`ScanStatus` (12 raw values) maps to a small user-facing state set, each with a fixed colour/icon/copy shape. This is a new `MainScreenUiState`, computed from `ScanState` and unit-tested independently of widgets (same spirit as `protection_screen_ui_state_test.dart`, fresh implementation).

| User-facing state | Raw `ScanStatus` values folded in | Hero colour |
|---|---|---|
| Off | `idle`, `paused` | grey (`UnrecordedColors.muted`) |
| Starting | `starting` | purple (`primary`), with a progress ring instead of a static icon |
| Protecting | `scanning`, `resting`, `confirmingRisk` (no elevated risk) | purple (`primary`) |
| Possible risk | `possibleRiskDetected` | amber (`warning`) for medium, red (`danger`) for high |
| Action needed | `permissionDenied`, `permissionPermanentlyDenied`, `bluetoothOff`, `bluetoothUnsupported` | blue (`info`) |
| Error | `error` | dark grey (`muted`/`onSurfaceVariant`) |

"Action needed" carries a contextual message + one recovery action (e.g. "Open settings" vs. a Bluetooth prompt) — the cause changes the text, not the visual treatment.

Background protection (on/off, Android-only) is orthogonal to this state model — it's a separate toggle row, not a hero state, since it can be on or off underneath any of the above.

### 2. Shared `ProtectionHero` widget

Replaces `ScanStatusCard`. A single widget whose colour/icon/title/subtitle are driven entirely by `MainScreenUiState`. Full-width, colour-tinted, matching the approved "Bold Status Hero" visual direction.

**Alert integration:** when state is "Possible risk," the hero itself becomes the alert (approved option) — same widget, alert variant shows the likely device/category name if known, one short uncertainty line, and a "View details" action, with "Dismiss" presented as a distinct action below the hero. There is no separate `RiskAlertCard` competing with the hero on the main screen for a *live* alert.

A visually quieter treatment (not the full hero) is used for the *historical* "recent/missed alert" reminder, since it is not a current risk — see "Main protection screen" below.

### 3. One shared disclosure pattern: bottom sheet

A single `UnrecordedDisclosureSheet` component (wraps `showModalBottomSheet`) replaces `HelperText.expandableDetail` and `ExpansionTile` as the one consistent pattern for all "more info" content across the app: how protection works, why a permission is needed, detection limitations, notification guidance, per-device signal evidence, and the consolidated Settings privacy detail.

- Trigger is always the same compact text-link pattern, e.g. `"How protection works ›"`.
- Full destinations that are their own journey — Help, Settings & Privacy, Alert details, Remove ads, Feedback — remain dedicated routes. The sheet is only for short supporting text that would otherwise clutter the screen it lives on.
- Sheets must be reachable and dismissible via screen reader and the system back button (see Accessibility).

### 4. One shared `StatusNoticeRow` for contextual banners

`NotificationModeBanner` and `BackgroundProtectionStoppedBanner` currently use two different ad-hoc coloured `Material` cards with paragraph-length text, always evaluated even when there's nothing actionable to say. Both become a single `StatusNoticeRow` (icon + one short sentence + optional action link), rendered **only when there is something the user needs to know or do** (e.g. "Notifications are off" only while they're off). Longer explanation moves into a disclosure sheet reachable from the row or from Settings/Help.

## Screen-by-screen treatment

### Main protection screen (`scan_screen.dart`)

- `ProtectionHero` at top. When off, its subtitle absorbs today's separate "Turn on protection to keep checking…" `NextStepBanner` text — removing a redundant stacked element.
- Background protection toggle stays as one row directly under the hero; the always-visible "Background protection is active" helper line is removed (redundant with the switch + hero state).
- `StatusNoticeRow` for anything needing attention (notifications off, Android stopped background protection), shown only when relevant.
- One "How protection works ›" disclosure-sheet link replaces the current `HelperText` + `PrivacyDisclaimer.detectionDisclaimer` pairing.
- Possible-risk state: hero becomes the alert (see Foundations §2). "Why this risk level?" reasons list and full per-signal evidence move to Alert details — not shown on the main screen.
- "Other nearby devices" becomes a disclosure-sheet link instead of a native `ExpansionTile`.
- Recent/missed-alert reminder: quieter `StatusNoticeRow`-style line with "View details," distinct from a live alert's hero treatment.
- Demo-mode indicator becomes a small persistent pill, not a `MaterialBanner` block.
- Feedback stays as the unobtrusive text link at the bottom.

### Alert details (`alert_details_screen.dart`)

- Keep badge + title + one short body line.
- Drop the duplicate "not proof of recording" statement down to a single instance (currently stated once inline and once via the linked helper).
- Per-device evidence (confidence/last-seen/strength/evidence labels — currently 4+ always-visible lines per device) collapses into a disclosure sheet per device.
- "Why this risk level?" reasons list (moved from the main screen) lives here, visible by default since this is the detail screen for an alert.

### Alert explanation ("How detection works", `alert_explanation_screen.dart`)

- Currently one continuous scroll of ~7 always-expanded text sections. Becomes an accordion: each section (why you see a warning, risk levels, what it can/can't detect, why it's probabilistic, Android scanning behaviour, repeated sightings) collapses by default. Nothing is removed — only not all visible at once.

### Recent risk / missed alert (`recent_risk_screen.dart`)

- Same badge + title + one-line body pattern.
- "Why this reminder" list becomes a disclosure sheet.
- Consolidate the two separate closing lines (privacy note + "not proof of recording") into one.

### Settings & Privacy (`settings_screen.dart`)

- The 5 stacked `ListTile`s (local-first, no account, no cloud upload, no analytics, ads) collapse into **one** "Privacy & data ›" row opening a single disclosure sheet listing all of them as short bullets.
- The top-line `PrivacyNoticeCard` stays as the one concise on-screen reassurance ("Scan data stays on this device"), matching the issue's own example phrasing.
- Notification and recent-risk-reminder helper texts move behind small "?" disclosure triggers instead of always-visible paragraphs.
- Funding paragraph shortens to one line + a "Learn more" sheet.
- Remove ads / feedback nav tiles are already concise and stay as-is.

### Help (`help_screen.dart`)

- Same accordion treatment as Alert explanation. The example alert card stays visible (short, illustrative). "Missed alerts," widget help, and notifications help become collapsed disclosure rows instead of always-expanded headed paragraphs.

### Remove ads (`remove_ads_screen.dart`)

- The three stacked `HelperText` paragraphs (body, free-note, amount-hint) consolidate into one short paragraph. Slider, purchase button, and restore action are already minimal and stay.

### Feedback (`feedback_screen.dart`)

- Out of scope — not called out in the issue and already minimal. No changes planned.

## Visual style

Approved via mockup review:

- **Bold Status Hero**: a full-width, colour-tinted banner at the top of state-driven screens (icon, title, short subtitle), replacing the bordered `ScanStatusCard`.
- Colour mapping (see Foundations §1 table) reuses only existing `UnrecordedColors` tokens — no new colours introduced.
- Colour is always paired with an icon + text label, never used alone to convey state or risk severity.

## Accessibility (issue requirement #7)

- All bottom sheets and disclosure triggers have explicit semantic labels/hints (not a bare chevron icon), and are reachable/dismissible via screen reader and the system back button.
- Layouts verified at larger Android text-scale settings (e.g. 1.3× and 2.0×) and on a small-screen profile (~360dp width) — no fixed-height containers that clip scaled text; disclosure is used instead of shrinking type.
- Minimum 48×48 tap targets for the toggle row, disclosure links, and hero action buttons.

## Testing plan

- Unit tests for `MainScreenUiState` mapping — every `ScanStatus`/`RiskLevel` combination resolves to the expected compact state, colour, and copy.
- Widget/golden tests for `ProtectionHero` across all 6 states (off, starting, protecting, possible-risk medium, possible-risk high, action-needed, error).
- Widget tests confirming disclosure sheets open, contain expected content, and are dismissible.
- Updates to `copy_guard_test.dart` so relocated (not deleted) copy is still asserted to exist somewhere reachable.
- A widget test for the consolidated Settings "Privacy & data" sheet asserting each original privacy statement is still present in its content.
- A small-screen + large-text-scale variant added to the golden/widget test matrix.
- `meetsGuideline` accessibility matchers (contrast, tap-target size, labelling) at least for the hero and primary action button.
- Update `app_test.dart` and other main-screen state tests to reflect the new hero-based states.
- Manual physical-device walkthrough as the final verification step, per the issue's suggested approach.

## Non-goals / explicitly out of scope

- No changes to scanning/detection engine, scoring, notification triggering, background service logic, or ads/entitlement logic — UI/IA/copy only.
- No new colour tokens.
- No onboarding carousel/wizard.
- No changes to `apps/site` — mobile app only.
- Feedback screen left as-is.
- PR #90 stays untouched; closing it is a separate decision outside this spec.
- No wording/tone changes beyond brevity — existing risk/privacy phrasing is preserved, only de-duplicated and relocated.
