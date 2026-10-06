---
name: Kinetic Haptic
colors:
  surface: '#13121b'
  surface-dim: '#13121b'
  surface-bright: '#3a3842'
  surface-container-lowest: '#0e0d16'
  surface-container-low: '#1c1a24'
  surface-container: '#201e28'
  surface-container-high: '#2a2933'
  surface-container-highest: '#35343e'
  on-surface: '#e5e0ee'
  on-surface-variant: '#cac4d4'
  inverse-surface: '#e5e0ee'
  inverse-on-surface: '#312f39'
  outline: '#948e9d'
  outline-variant: '#494552'
  surface-tint: '#cebdff'
  primary: '#cebdff'
  on-primary: '#381385'
  primary-container: '#a78bfa'
  on-primary-container: '#3c1989'
  inverse-primary: '#674bb5'
  secondary: '#ffafd3'
  on-secondary: '#620040'
  secondary-container: '#85145a'
  on-secondary-container: '#ff93c8'
  tertiary: '#7bd0ff'
  on-tertiary: '#00354a'
  tertiary-container: '#00a8e2'
  on-tertiary-container: '#00394f'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e8ddff'
  primary-fixed-dim: '#cebdff'
  on-primary-fixed: '#21005e'
  on-primary-fixed-variant: '#4f319c'
  secondary-fixed: '#ffd8e7'
  secondary-fixed-dim: '#ffafd3'
  on-secondary-fixed: '#3d0026'
  on-secondary-fixed-variant: '#85145a'
  tertiary-fixed: '#c4e7ff'
  tertiary-fixed-dim: '#7bd0ff'
  on-tertiary-fixed: '#001e2c'
  on-tertiary-fixed-variant: '#004c69'
  background: '#13121b'
  on-background: '#e5e0ee'
  surface-variant: '#35343e'
typography:
  display-lg:
    fontFamily: Space Grotesk
    fontSize: 44px
    fontWeight: '700'
    lineHeight: 52px
    letterSpacing: -0.03em
  display-md:
    fontFamily: Space Grotesk
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Space Grotesk
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Space Grotesk
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-md:
    fontFamily: Space Grotesk
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Space Grotesk
    fontSize: 9px
    fontWeight: '700'
    lineHeight: 12px
    letterSpacing: 0.06em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-compact: 0.5rem
  margin: 1.5rem
  margin-compact: 0.75rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 2rem
---

## Brand & Style

This design system translates acoustic mechanical tactility into an interactive visual language. Built around the principles of Material 3 Expressive, it bridges physical mechanical keyboards—clicky switches, heavy brass plates, dampener foams, and acoustic resonance—with hyper-modern desktop software UI.

### Personality & Tone
- **Acoustic & Tactile:** Interface elements emulate physical switches, keycaps, and resonant chambers without skeuomorphic clutter.
- **Expressive & Playful:** High-energy accents, spring-loaded spring curves, bold expressive typography, and reactive soundwave visualizers bring audio feedback to life.
- **Utilitarian Elegance:** Tailored specifically for compact menu bar overlays, floating HUDs, and deep configuration panels across macOS, Windows, and Linux.

### Visual Style
A bold synthesis of **M3 Expressive** and **Tactile Modernism**. The aesthetic relies on fluid pill-shaped geometry, tonal surface tiers, layered frosted translucency for native OS integration, and high-chroma reactive accents that mirror sound profiles (e.g., Thock, Clack, Click, Creamy).

## Colors

The palette is tuned specifically for deep-contrast, low-eye-strain utility in dark mode while keeping reactive sound indicators luminous and clear.

### Palette Architecture
- **Primary (`#A78BFA` - Electric Lavender):** Represents core user actions, primary toggles, active profile selections, and acoustic focus states.
- **Secondary (`#F472B6` - Neon Haptic Pink):** Used for pitch shifts, velocity curves, dynamic audio overdrive indicators, and playful expressive badges.
- **Tertiary (`#38BDF8` - Acoustic Cyan):** Highlights sound resonance, dynamic latency metrics, real-time waveform bars, and switch travel depths.
- **Neutral (`#12111A` - Deep Obsidian Resonance):** The foundational canvas tint. Infused with a faint violet undertone to prevent dead black surfaces and unify dark-tier surface containers.

### Surface Elevation Containers
- **Surface Dim:** `#0C0B12` (backdrop & window gutter)
- **Surface Default:** `#12111A` (canvas base)
- **Surface Container Low:** `#1A1826` (docked sidebar, background groupings)
- **Surface Container:** `#232034` (interactive cards, switch tiles)
- **Surface Container High:** `#2C2941` (hover states, modal sheets, menu-bar popover panels)
- **Surface Container Highest:** `#36324E` (active pills, elevated audio meter troughs)

## Typography

Typography establishes an expressive tension between technical precision and human playfulness.

- **Headlines & Display (`Space Grotesk`):** Chosen for its technical, geometric edge and mechanical character. Tight tracking and deliberate proportion mimic keyboard engineering specs and high-precision audio mastering gear.
- **Body (`Plus Jakarta Sans`):** Balanced, open apertures, and subtle geometric curves ensure high legibility at micro scales (essential for compact tray popovers and desktop utility panels).
- **Labels & Metrics (`Space Grotesk`):** Capitalized or numerical micro-readouts (latency in ms, volume in dB, switch force in grams) remain crisp and non-ambiguous down to 9px.

## Layout & Spacing

The layout is built for dual presentation: an ultra-compact **Menu Bar Popover / Tray Window** (340px - 380px fixed width) and an expansive **Studio Suite Desktop Window** (800px+ multi-pane layout).

### Layout Rules
- **Desktop Studio Canvas:** Uses a fluid 12-column grid with `1rem` (16px) gutters and `1.5rem` (24px) margins. Ideal for dual-column sound staging: sound pack selectors on the left, visual sound envelope tuners on the right.
- **Menu Bar / Floating Tray HUD:** Shifts to a compact single-column stack with `0.5rem` (8px) gutters and `0.75rem` (12px) padding. Layout density is tightened to preserve maximum utility in minimum screen estate.
- **Rhythm:** Spacing follows strict multiples of 4px. Component internal padding leans toward compact vertical (`space-sm`) and generous horizontal (`space-lg`) to echo mechanical keyboard keycap silhouettes.

## Elevation & Depth

This system avoids plain neutral drop shadows, utilizing **chromatic ambient shadows** combined with **tonal layer stepping** and **frosted desktop glass (vibrancy/mica integration)**.

### Tonal Tiers & Blur
1. **Level 0 (App Canvas):** Pure `Surface Default` (`#12111A`) with optional native desktop backdrop-filter blur (`24px` blur with 80% opacity on macOS/Windows 11).
2. **Level 1 (Sound Profile Cards, Sub-panels):** `Surface Container Low` with an interior 1px ghost border (`rgba(255, 255, 255, 0.06)`).
3. **Level 2 (Active Key Modules, Active Cards):** `Surface Container` with an ambient shadow: `0 8px 24px -4px rgba(0, 0, 0, 0.5)`, layered with a subtle primary hue glow: `0 0 16px -2px rgba(167, 139, 250, 0.15)`.
4. **Level 3 (Tray Popover HUD, Modals, Floating Volume Docks):** `Surface Container High` elevated with a distinct tinted drop shadow: `0 16px 40px -8px rgba(0, 0, 0, 0.65)`, rim-lit with `rgba(167, 139, 250, 0.2)` along the top edge.

### State Layers & Audio-Reactivity
- Hover states apply an expressive `8%` white tint state layer.
- Pressed / Down states compress the element visually (`transform: scale(0.97)`), mimicking mechanical switch actuation.
- Keystroke events emit a temporary concentric rim light that radiates outward across the container.

## Shapes

The design system embraces Material 3 Expressive's iconic pill and squircle geometries.

### Geometry Specifications
- **Full Pills (`border-radius: 9999px`):** Used across action buttons, category filter chips, volume sliders, profile selectors, and status badges.
- **Expressive Squircles (`rounded-xl` / `2rem` - 32px):** Applied to top-level cards, audio soundstage canvases, and desktop window shells.
- **Keycap Containers (`rounded-lg` / `1rem` - 16px):** Designed specifically for keyboard switch test pads, input blocks, and latency readouts.
- **Indicator Nodes (`full round`):** Audio level meters, haptic pulse dots, and active tray indicators remain perfect circles.

## Components

### Buttons
- **Filled Expressive (Primary):** Pill-shaped, background in `Primary` (`#A78BFA`), foreground in dark canvas (`#12111A`), typography `Space Grotesk` Bold (`label-lg`). Press state triggers switch actuation scaling (`scale(0.96)`).
- **Tonal Haptic (Secondary):** Surface Container Highest background with `Secondary` (`#F472B6`) text and iconography.
- **Outlined / Ghost:** Transparent base with a 1.5px border (`rgba(255, 255, 255, 0.12)`). On hover, rim lights with Tertiary (`#38BDF8`).

### Switch & Sound Chips
- Full pill containers. Inactive state: `Surface Container` with muted body text.
- Active state: Pill fills with dynamic gradient or solid `Primary`, accompanied by an animated mini-equalizer icon (3 vertical bouncing pill bars).

### Keycaps & Acoustic Visualizers
- **Interactive Switch Pad:** Squircle tile shaped like an artisan keycap. Displays switch type (e.g., "Holy Panda - 67g Tactile"). Includes a bottom edge bevel highlight to visually communicate key travel depth.
- **Soundwave Bar:** Live audio indicator built from rounded vertical pill bars. Colors shift dynamically based on output pitch (Cyan for high clicks, Pink for mid-range clacks, Lavender for deep bottom-out thocks).

### Slider Controls (Volume & Pitch)
- Wide track pill (8px height) in `Surface Container Highest`.
- Filled segment in `Primary` or `Tertiary`.
- Thumb: Prominent 20px pill/circle with a soft tinted drop shadow (`rgba(0, 0, 0, 0.4)`), expanding to 24px on grab/drag.

### Checkboxes & Toggle Switches
- Expressive M3 pill toggle: Track is a 32px tall, 52px wide pill. Thumb expands into an elongated lozenge shape during drag transitions.
- Key sound mute/unmute operates with instant mechanical snap easing (`cubic-bezier(0.34, 1.56, 0.64, 1)`).

### Cards & Menu-Bar Quick-Panel
- Wrapped in `Surface Container` with `rounded-xl` (32px corners for full windows, 20px for tray popovers).
- Top navigation features asymmetric expressive tabs (pill-shaped selected tab, borderless unselected tabs with hover glow).