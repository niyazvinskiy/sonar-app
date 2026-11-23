---
name: Sonar
description: A quiet native connection desk in night water and pearl.
colors:
  night-0: "#070B16"
  night-1: "#0E1630"
  night-2: "#1E2D4A"
  surface: "#101B2B"
  surface-active: "#24344E"
  mist: "#DDE2E8"
  feather: "#AEB6C2"
  paper: "#F6F7F9"
  aqua: "#5EEAD4"
  idle-primary: "#7C8CFF"
  idle-secondary: "#3B4A8F"
  connecting-primary: "#9AA8FF"
  connecting-secondary: "#B48CFF"
  connected-secondary: "#8B9CFF"
  failure-primary: "#FF7A90"
  failure-secondary: "#7A3358"
  latency-warning: "#FFC979"
  ledger-line: "#314054"
  settings-line: "#29364A"
  disabled-action: "#26344B"
typography:
  title:
    fontFamily: "Jost"
    fontSize: "30px"
    fontWeight: 400
    lineHeight: 1.15
    letterSpacing: "-0.2px"
  body:
    fontFamily: "Jost"
    fontSize: "15px"
    lineHeight: 1.5
  label:
    fontFamily: "Jost"
    fontSize: "12px"
    fontWeight: 500
    letterSpacing: "0.7px"
  value:
    fontFamily: "Jost"
    fontSize: "17px"
    fontWeight: 500
    fontFeature: "tnum"
  item:
    fontFamily: "Jost"
    fontSize: "16px"
    fontWeight: 500
  hint:
    fontFamily: "Jost"
    fontSize: "13px"
    lineHeight: 1.35
rounded:
  route-option: "9px"
  action: "12px"
  route-control: "13px"
  settings-group: "14px"
  surface: "16px"
  dialog: "24px"
  sheet: "28px"
spacing:
  inset: "4px"
  tight: "8px"
  control: "12px"
  standard: "16px"
  card: "20px"
  page: "24px"
  section: "28px"
  desktop-gap: "40px"
components:
  connection-action:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.night-0}"
    typography: "{typography.item}"
    rounded: "{rounded.action}"
    padding: "15px 24px"
  connection-action-disabled:
    backgroundColor: "{colors.disabled-action}"
    textColor: "{colors.mist}"
    rounded: "{rounded.action}"
  route-option-selected:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.night-0}"
    rounded: "{rounded.route-option}"
    padding: "12px 10px"
  route-control:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.route-control}"
    padding: "4px"
  channel-row:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.action}"
    padding: "16px"
  settings-group:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.settings-group}"
  switch-selected:
    backgroundColor: "{colors.aqua}"
    textColor: "{colors.night-0}"
---

# Design System: Sonar

## Overview

**Creative North Star: “A quiet connection desk.”** This wording comes from the approved Windows surface contract. Night-water grounds, pearl text and Jost preserve the existing identity; direct native controls make the current connection and its next action easy to read.

The signature drop carries living connection color. The surrounding controls use solid tonal surfaces and fine boundaries rather than ornamental glass. Settings are compact grouped native rows; measurements are an open ledger. The current document records implemented Flutter values, not a proposal for a new visual direction.

Source authority: `lib/sonar/sonar.dart`, `sonar_style.dart`, `sonar_home_view.dart`, `sonar_settings.dart`, `sonar_sphere.dart`, `sonar_aurora.dart` and `lib/core/theme/app_theme.dart`. Measurements below are Flutter logical pixels; CSS-style units in the frontmatter are a portable token representation.

## Colors

Night 0 is the deep ground, Night 1 the upper background and native overlay ground, and Night 2 a stronger tonal layer. Paper is primary text and selected route/action fill; Mist is body text and fine boundary material; Feather is secondary text. The home connection action and selected routing option use dark text on Paper.

Idle uses the indigo pair; connecting shifts toward lavender; connected uses Aqua with the secondary blue; failure uses the rose pair. These states also have explicit text. Aqua remains the inherited native theme's selected switch, progress and secondary action accent, so the drop is not the only component allowed to use it. Positive measured latency below 90 ms uses Aqua, 90–219 ms uses the warning tone, and higher latency uses the failure tone; unavailable latency uses Feather.

The `sonarGlass` helper retains a legacy name but renders a solid Surface or Surface Active with a Mist border at 12% or 32% opacity. Do not infer a blur requirement from its name.

## Typography

Jost is bundled in the app; native Windows emoji fallback is a separate font. The source's common roles are captured in the frontmatter. Connection headings override Title to 34 on wide windows or 28 on narrow ones. Settings app identity uses 24; the native app-bar title uses 20. Route option labels use Item at 14. Numeric values use tabular figures; Russian units and comma decimals follow the existing formatting helpers.

Respect the system text scaler. Long explanations wrap; do not force them into fixed-height rows or shrink the font to preserve a composition.

## Layout

The home view becomes two columns at an available width of 760 logical pixels: a flexible connection stage, 40-pixel gap and 340-pixel route/session rail. The outer content is centered with maximum width 1060 and 40-pixel side padding. Narrow windows use 24-pixel side padding and a single vertical flow. Both use a 64-pixel top inset and 28-pixel bottom inset inside a scroll view.

The signature stage is 310 pixels wide on desktop, 220 on a regular narrow layout and 160 on a narrow layout whose available height is below 700. Connection status, explanation, drop and action form one group; routing and current-session measurements follow. Essential controls can move below the initial viewport at enlarged text, but scrolling must keep them reachable.

Settings groups use 14-pixel corners. Rows use native ListTile layout with directional padding 18/10/14/10, a 22-pixel leading icon and 14-pixel title gap. Section labels use 28 pixels above and 12 below. Internal dividers are inset 56/18. Session ledger rows have 11-pixel vertical padding, flexible label/value columns and 12-pixel separation.

## Elevation & Depth

Controls are flat tonal layers. Groups and ledger rules establish structure without card shadows. The connection drop and its painter use authored light, rings, particles and waves; the background uses slow, low-opacity aurora fields over a Night 1 to Night 0 gradient. These are signature native canvas effects, not replacement textures or web-style glass cards.

Ambient animation loops over two minutes, while mood transitions use 700 ms and `easeInOutCubic`. `MediaQuery.disableAnimations` stops both ambient and drop loops and removes mood-transition duration; calm settings backgrounds are still by default. See the sidecar for motion metadata and source pointers.

## Shapes

Rectangular controls have restrained rounded corners: 12 for the connection action/channel, 13 for routing, 14 for settings groups. Route options nest at radius 9 within a four-pixel inset. Native dialogs use 24; bottom sheets use a 28-pixel top radius. The pearl drop's circular, fluid state language is the signature exception to the control geometry.

## Components

**Connection action.** A native FilledButton with power icon duplicates the drop's primary action visibly and accessibly. Labels are Подключить, Отключить, Остановить, Подключение… or Подключить снова according to real state and availability. Its width is constrained from 190 to 320; text remains allowed to wrap. Disabled styling uses Disabled Action and Mist.

**Route selection.** Two equal-width TextButton options share a tonal container. Paper marks the selected route, and the explanation below spells out what traffic the route includes. The selected option has selected semantics. Native focus/hover feedback remains supplied by Material controls.

**Channel row.** Surface fill, 16-pixel padding, a consistent Material icon, small Канал label and Item value. Only a usable channel row exposes a chevron and action. A missing key uses an honest unavailable-channel explanation.

**Session ledger.** Text and thin rules, without an enclosing card. Show real elapsed time, latency, transfer rates and totals. Disconnected and unavailable values use em dashes or the explicit empty-state explanation; no fabricated city is added to this surface.

**Settings group and tile.** Native rows retain wrapping titles/explanations and switches or chevrons. Windows startup, automatic connection and setup are separate discoverable rows. The app/version block remains open with a bottom rule, dynamic updater status and a native update/check action.

**Native forms and overlays.** Existing theme inputs use filled white at 4%, a Mist outline at 14%, radius 12 and a 1.4-pixel Aqua focus border. Dialogs, menus and sheets retain themed native affordances rather than bespoke interaction models. Sidecar HTML previews translate these motifs for documentation only; Flutter remains the implementation authority.

## Do's and Don'ts

- **Do** keep the dark identity, Jost, pearl drop and explicit state labels together.
- **Do** preserve native focus, keyboard activation and selected/disabled semantics.
- **Do** allow vertical scrolling and wrapping at small sizes and enlarged text.
- **Do** distinguish synthetic screenshot telemetry from live network evidence.
- **Don't** replace empty measurements with plausible-looking numbers or locations.
- **Don't** reintroduce a tall stack of ornamental glass cards around the home controls.
- **Don't** rely on color alone for connection state or defeat reduced motion.
- **Don't** treat this Windows-first review as proof of mobile-platform or live updater validation.
