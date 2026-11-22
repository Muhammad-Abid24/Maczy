# UI-UX.md — Maczy Design System & OpenDesign MCP

> Source of truth split: **Dashboard = Product Owner-approved OpenDesign project/screen revision**; **Menu Bar & Dynamic Notch = Apple-native macOS patterns**. Do not render a dashboard guessed from generic SaaS layouts as final. Use system control sizes, semantics, material and accessibility on native surfaces.

## 1. Surfaces and navigation
**Main App:** Dashboard overview + left/sidebar navigation to Capture, Recording, Battery Guardian, Dynamic Notch, Smart Unlock, Updates, Always On, Cleaner, Permissions, General Settings, History. All functions are operable here.

**Menu Bar:** compact icon plus 7 module groups and quick toggles/actions (screenshot action, recording start/stop, battery limit selection, notch visibility, Smart Unlock macOS Face Unlock opt-in/status/compatibility controls, update check, Awake start/stop, cleaner scan). Always offer `Open Maczy`, `Preferences`, `Quit` and precise status. No pretend "On" toggle for one-shot actions.

**Dynamic Notch:** compact pill and expanded panel; contextual controls for screenshot, recording, battery, Now Playing, notifications, volume/brightness, opt-in clipboard, window snap, system Lock Screen, Maczy Live Activity, AirPods/TWS connection animation. Virtual island fallback if no physical notch. Avoid copying Apple-private visuals/trademarks or obstructing camera/menu bar.

## 2. Dashboard OpenDesign MCP contract — exclusive source of truth
1. OpenDesign is the **only authoritative design source for the Dashboard**. The Product Owner approves a specific OpenDesign project, screen set and revision. Neither generic mockups nor another design system override it.
2. Agent verifies the installed OpenDesign CLI executable identity (`/usr/bin/od` is a different macOS command), connects OpenDesign MCP to Antigravity, and successfully invokes a real MCP tool. Do not claim connectivity merely because an installer succeeded.
3. Read the actual OpenDesign project/screens via MCP, then record project ID, screen IDs, revision, typography, colors, spacing, component tokens, icons/assets and any licensing constraints in task evidence (TASK.md or reviewed PR).
4. Translate approved OpenDesign tokens/layout into **native SwiftUI and AppKit**. Never ship OpenDesign, a browser renderer, generated React/CSS or MCP as a Maczy runtime dependency.
5. Keep prototypes and unapproved changes clearly marked. If there is no approved OpenDesign revision or MCP access, build only a neutral native navigation scaffold; mark dashboard design acceptance BLOCKED, never invent fidelity.
6. Compare native dashboard screenshots to the pinned OpenDesign screenshots on actual Apple Silicon Mac hardware across light/dark, resizable window layouts and relevant macOS versions; record owner approval, accessibility, VoiceOver, keyboard and reduced-motion results.
7. Design change control: after approval, any changed OpenDesign revision requires an explicit new approval before replacing dashboard styling. Do not silently switch revisions.

## 3. Appearance rules
- Menu Bar: `NSStatusItem` / `MenuBarExtra`, SF Symbols, native fonts, native popovers, material, macOS keyboard navigation. Respect system dark/light, reduce transparency.
- Notch: use native-looking compact/expanded layouts, safe-area geometry, rounded corners, restrained animations; accessibility and per-display choice. Never assume notch exists on desktop Macs.
- Dashboard: approved OpenDesign typography/colors/layout; still comply with native focus, menu commands, system dialogs and permission prompts.
- Prefer custom assets only when licensed and owner-approved. No screenshot recreation of CleanShot X, Notchy, Mole or Apple private system UI.

## 4. Module screen specifications
| Screen | Primary components | Required states |
|---|---|---|
| Screenshot | Area / Full Window / Scrolling segmented control, capture, preview, OCR copy | idle, targeting, capturing, processing, failed, unsupported |
| Recording | Window / Region / Display, size preset + custom width/height, Speaker/System Audio toggle, Microphone toggle, destination, record/stop timer | permission needed, active, paused if supported, encoding, saved, error |
| Battery | percent/health/cycles and actual state, selected limit 80/85/90/95/100, backend details | reading, charging, limited, bypass verified, discharge, unsupported, error |
| Notch | feature preferences and per-display settings for 9 subfeatures | physical, virtual, permission needed, unavailable |
| Smart Unlock | Face Unlock for **actual macOS locked session** (when feasible), enroll/unenroll, camera/liveness, compatibility; explain OS-managed Touch ID/password fallback | not enrolled, enrolled, lock detected, verifying, OS unlock confirmed, blocked/unsupported, denied, rate-limited |
| Updates | current/new version, changelog, channel, update settings | checking, available, downloading, verify failed, installed |
| Always On | keep system/display awake, duration, AC-only, run timer | on, off, paused due to power, unavailable |
| Cleaner | Three integrated sections (Cleaner \| Uninstall \| Optimize): cache scanning & review; application inventory, leftover safety classification & Trash workflow; evidence-first startup items, maintenance tasks, dev caches & live resource monitoring | scanning, review, cleaning, cancelled, completed, partial fail |

## 5. Interaction details / requirements
- Screenshot scrolling: progress and Cancel; explain app compatibility; no forced Accessibility prompts until feature used.
- Recording: default **System Audio OFF, Microphone OFF**; show per-track status and output resolution before starting. Speaker toggle captures *system audio*, not simply output volume.
- Battery: expose limit options but read back actual effective limit; avoid "charging bypass" badge unless backend certifies it.
- Now Playing: show unavailable/provider integration state when macOS does not expose metadata.
- System notification view: native Maczy notices only unless supported API explicitly authorizes others.
- HUDs: do not guarantee ownership of Apple's built-in HUD. Use native-looking Maczy overlay with verified observation/controls only.
- Lock Screen action invokes genuine system lock; **Smart Unlock seeks a verified OS-authorized unlock of that locked session**, never a Maczy-only overlay dismissal. No password injection or bypass of system security. Show blocked state until the supported pathway is proven.
- Clipboard off by default and can clear private history; permission/consent disclosure.
- TWS animation may be limited to observable Bluetooth connection events, not all pairing flows.
- All interactions require keyboard focus/VoiceOver labels; status messages must be announced; implement reduce-motion fallback.

## 6. QA / design acceptance
- Approved OpenDesign dashboard diff reviewed and approved by Product Owner on actual macOS screenshots.
- Notch/menu bar style reviewed for macOS 14, 15, 26, 27 native consistency in light/dark and with different scaling.
- Compact menu never clips; notch doesn't occlude critical OS controls; external-monitor virtual island behavior tested.
- Verified permission denial, offline, battery-unavailable, no Touch ID and webcam denied states. Smart Unlock must distinguish simulated face match from verified macOS session unlock. Include opt-in, liveness failure, account locked, unsupported login state and fallback states.

## 7. OpenDesign MCP reference
https://github.com/nexu-io/open-design

Integration command (only after verifying the real OpenDesign CLI): `od mcp install antigravity`. Confirm connectivity with an actual MCP tool call.

## Design acceptance record (include in task PR)
- OpenDesign project and screen identifiers; approved design revision and owner decision.
- Relevant font, spacing, color, layout, icon and component tokens.
- Native SwiftUI mapping and known deliberate differences.
- Comparison screenshots from real macOS with light/dark and responsive window sizing.
- Accessibility results, remaining deviations and blockers.

The design revision is a reproducibility reference, **not documentation versioning**.
