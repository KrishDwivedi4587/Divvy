import { StyleSheet, type TextStyle } from 'react-native';

/**
 * Divvy design tokens.
 *
 * The single source of truth for colour, type, spacing, radii, elevation and
 * motion. Components must consume these rather than literal values — roadmap
 * §12: "set these in ui/theme/tokens.ts on day one and never deviate".
 *
 * This module is a leaf dependency. It must never import from the store, the
 * calculation engine, the database, OCR, or any feature module.
 *
 * Divvy is dark-only (roadmap T1.12). A light theme is Tier 3 (T3.6) and is
 * deliberately not implemented; see docs/design-tokens.md for the migration
 * path that keeps component code unchanged if it is ever added.
 */

/* ------------------------------------------------------------------ *
 * Palette (raw)                                                       *
 * Internal. Components consume the semantic `colors` export below,    *
 * never these names, so the palette can change without touching UI.   *
 * ------------------------------------------------------------------ */

const palette = {
  navy900: '#0B1220',
  navy800: '#131C2E',
  navy700: '#1B2740',
  navy600: '#24324F',
  navy500: '#35456A',

  slate100: '#F5F7FA',
  slate300: '#A9B4C7',
  slate500: '#7A879E',

  indigo: '#6B4EEA',
  indigoPressed: '#5A3FD1',

  red: '#F87171',
  orange: '#FB923C',
  amber: '#FBBF24',
  mint: '#34D399',
  cyan: '#22D3EE',
  blue: '#60A5FA',
  violet: '#A78BFA',
  pink: '#F472B6',

  white: '#FFFFFF',
} as const;

/* ------------------------------------------------------------------ *
 * Semantic colours                                                    *
 * ------------------------------------------------------------------ */

export const colors = {
  /**
   * Screen and container backgrounds. Depth is expressed as a lighter surface,
   * not a shadow — see `elevation` below for why.
   */
  surface: {
    background: palette.navy900,
    raised: palette.navy800,
    elevated: palette.navy700,
    /** Bottom sheets and modals. */
    overlay: palette.navy600,
    border: palette.navy600,
    borderStrong: palette.navy500,
  },

  text: {
    /** 17.5:1 on background. */
    primary: palette.slate100,
    /** 9.0:1 on background. */
    secondary: palette.slate300,
    /** 5.2:1 on background — still AA for body text. */
    muted: palette.slate500,
    /** For text sitting on an avatar colour. */
    inverse: palette.navy900,
  },

  action: {
    /** The single saturated accent. 5.4:1 with white text, 3.5:1 on background. */
    primary: palette.indigo,
    primaryPressed: palette.indigoPressed,
    onPrimary: palette.white,
  },

  status: {
    success: palette.mint,
    warning: palette.amber,
    error: palette.red,
    info: palette.blue,
  },

  /**
   * Fixed 8-colour avatar palette (roadmap Phase 0 task 8). Assigned via
   * `Person.colorIndex`. All eight carry `text.inverse` at 6:1 or better.
   * Colour is never the sole identifier — avatars always show initials too.
   */
  avatar: [
    palette.red,
    palette.orange,
    palette.amber,
    palette.mint,
    palette.cyan,
    palette.blue,
    palette.violet,
    palette.pink,
  ],
} as const;

/** Number of distinct avatar colours available. */
export const AVATAR_COLOR_COUNT = colors.avatar.length;

/* ------------------------------------------------------------------ *
 * Typography                                                          *
 * One typeface, two weights (roadmap T1.12).                          *
 * ------------------------------------------------------------------ */

/**
 * No `fontFamily` is set, so the platform default is used (Roboto on Android).
 * No font package is installed. Shipping a custom face such as Inter is a
 * documented future decision, not a current dependency.
 */
export const fontWeight = {
  regular: '400',
  bold: '700',
} as const;

export const typography = {
  /** Grand total only. */
  display: { fontSize: 40, lineHeight: 44, fontWeight: fontWeight.bold, letterSpacing: -0.5 },
  h1: { fontSize: 32, lineHeight: 38, fontWeight: fontWeight.bold, letterSpacing: -0.4 },
  h2: { fontSize: 24, lineHeight: 30, fontWeight: fontWeight.bold, letterSpacing: -0.2 },
  h3: { fontSize: 20, lineHeight: 26, fontWeight: fontWeight.bold },
  body: { fontSize: 16, lineHeight: 24, fontWeight: fontWeight.regular },
  bodySmall: { fontSize: 14, lineHeight: 20, fontWeight: fontWeight.regular },
  /** Buttons and field labels. */
  label: { fontSize: 14, lineHeight: 18, fontWeight: fontWeight.bold },
  caption: { fontSize: 12, lineHeight: 16, fontWeight: fontWeight.regular },
} as const satisfies Record<string, TextStyle>;

/**
 * Apply to every rendered money value. Tabular figures keep digit columns a
 * fixed width, which is what lets a total roll cleanly instead of jittering
 * (roadmap §12 A9 and A16).
 */
export const numeric = {
  fontVariant: ['tabular-nums'],
} as const satisfies TextStyle;

/* ------------------------------------------------------------------ *
 * Spacing — 4 / 8 / 12 / 16 / 24 / 32 (roadmap Phase 0 task 8)        *
 * ------------------------------------------------------------------ */

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
} as const;

export const layout = {
  /** Horizontal screen gutter. Nothing important within 16px of an edge. */
  screenPadding: spacing.lg,
  /** Minimum interactive target on both axes. */
  minTouchTarget: 44,
} as const;

/* ------------------------------------------------------------------ *
 * Radii and borders                                                   *
 * ------------------------------------------------------------------ */

export const radii = {
  sm: 8,
  md: 12,
  lg: 16,
  /** Fully rounded ends — item chips, pills. */
  pill: 999,
} as const;

export const borderWidth = {
  hairline: StyleSheet.hairlineWidth,
  thin: 1,
  /** Focus rings and selected states. */
  thick: 2,
} as const;

/* ------------------------------------------------------------------ *
 * Elevation                                                           *
 * ------------------------------------------------------------------ */

/**
 * Android draws elevation shadows in black, which are nearly invisible against
 * a near-black background. Depth in Divvy is therefore carried primarily by the
 * `colors.surface` steps (background, raised, elevated, overlay). `elevation`
 * is reserved for content that genuinely floats above other content — above all
 * the chip lifted during a drag (roadmap §12 A5).
 *
 * Android-only `elevation` is used deliberately in preference to the
 * cross-platform `boxShadow` also available in React Native 0.86: this is an
 * Android-only project, and `elevation` maps to the platform's native API.
 */
export const elevation = {
  none: 0,
  sm: 2,
  md: 6,
  /** Dragged chip. */
  lg: 12,
} as const;

/* ------------------------------------------------------------------ *
 * Opacity                                                             *
 * ------------------------------------------------------------------ */

export const opacity = {
  disabled: 0.38,
  /** Assigned item chips dim to this (roadmap §12 A13). */
  muted: 0.6,
  pressed: 0.7,
  /** Scrim behind sheets and modals. */
  scrim: 0.6,
} as const;

/* ------------------------------------------------------------------ *
 * Layering                                                            *
 * ------------------------------------------------------------------ */

export const zIndex = {
  base: 0,
  raised: 10,
  /** Pinned avatar dock. */
  dock: 20,
  /** Portal layer the dragged chip renders into, above the scrolling list. */
  dragLayer: 30,
  modal: 40,
  toast: 50,
} as const;

/* ------------------------------------------------------------------ *
 * Motion                                                              *
 * ------------------------------------------------------------------ */

export const duration = {
  fast: 150,
  normal: 250,
  slow: 400,
  press: 100,
  sheet: 300,
} as const;

/** Per-item delay for staggered list entry. Roadmap §12 specifies 30–50ms. */
export const stagger = 40;

/**
 * The only three springs in the app (roadmap §12: "Springs, not linear tweens.
 * Define exactly three"). Shaped for Reanimated's `withSpring` config.
 *
 * These are starting values. Roadmap §4 Spike 1 and Phase 2 budget real device
 * time to tune them by feel; emulator feel is explicitly not evidence.
 */
export const spring = {
  /** Default. Chip pickup, quick-add entry. */
  snappy: { damping: 20, stiffness: 300, mass: 0.8 },
  /** Settling and returning. Invalid-drop spring-back. */
  gentle: { damping: 26, stiffness: 140, mass: 1 },
  /** Celebratory overshoot. Use sparingly. */
  bouncy: { damping: 12, stiffness: 220, mass: 0.9 },
} as const;

/**
 * Interaction thresholds taken directly from roadmap §12, centralised so the
 * gesture system and its spike share one definition rather than drifting.
 */
export const interaction = {
  /** Long-press before a chip lifts (A5). */
  longPressMs: 180,
  /** Chip scale while dragging (A5). */
  chipLiftScale: 1.08,
  /** Avatar pulse when drop targets announce themselves (A6). */
  avatarPulseScale: 1.1,
  avatarPulseMs: 200,
  /** Magnetic attraction radius (A8). */
  magneticSnapPx: 40,
  /** Dwell before a two-person centre-hold split commits (A11). */
  centreHoldMs: 250,
} as const;

/* ------------------------------------------------------------------ *
 * Sizing                                                              *
 * ------------------------------------------------------------------ */

export const iconSize = { sm: 16, md: 20, lg: 24 } as const;

/** `lg` is the avatar-dock size on the assign screen. */
export const avatarSize = { sm: 32, md: 44, lg: 56 } as const;

/* ------------------------------------------------------------------ *
 * Types                                                               *
 * ------------------------------------------------------------------ */

export type Spacing = keyof typeof spacing;
export type Radius = keyof typeof radii;
export type TypographyVariant = keyof typeof typography;
export type SpringName = keyof typeof spring;
export type StatusColor = keyof typeof colors.status;

/* ------------------------------------------------------------------ *
 * Tints                                                               *
 * ------------------------------------------------------------------ */

/**
 * Translucent fills for notices and selected states: the status or accent
 * colour at low alpha (8-digit hex), so a tint always stays in step with its
 * parent colour. Meaning is never carried by the tint alone — notices also have
 * an icon and text (see docs/design-tokens.md, Accessibility).
 */
export const tint = {
  action: `${colors.action.primary}33`,
  success: `${colors.status.success}1F`,
  warning: `${colors.status.warning}1F`,
  error: `${colors.status.error}1F`,
  info: `${colors.status.info}1F`,
} as const;
