import { SymbolView } from 'expo-symbols';
import type { ComponentProps } from 'react';

import { colors, iconSize } from '@/ui/theme/tokens';

type SymbolName = ComponentProps<typeof SymbolView>['name'];
type SymbolSpec = Exclude<SymbolName, string>;

/**
 * Icons are SF Symbols on iPhone — the platform's native icon set, so they
 * match system UI and scale with Dynamic Type — with a Material Symbols
 * equivalent for web and Android.
 *
 * `expo-symbols` is already part of the Expo SDK, so no icon library is added.
 * `satisfies` makes the compiler reject any name that does not exist on a
 * platform, so a typo fails typecheck instead of rendering a blank square.
 */
const ICONS = {
  camera: { ios: 'camera.fill', android: 'photo_camera', web: 'photo_camera' },
  photo: { ios: 'photo.on.rectangle', android: 'photo_library', web: 'photo_library' },
  chevronLeft: { ios: 'chevron.left', android: 'chevron_left', web: 'chevron_left' },
  chevronRight: { ios: 'chevron.right', android: 'chevron_right', web: 'chevron_right' },
  chevronDown: { ios: 'chevron.down', android: 'expand_more', web: 'expand_more' },
  chevronUp: { ios: 'chevron.up', android: 'expand_less', web: 'expand_less' },
  plus: { ios: 'plus', android: 'add', web: 'add' },
  close: { ios: 'xmark', android: 'close', web: 'close' },
  trash: { ios: 'trash', android: 'delete', web: 'delete' },
  person: { ios: 'person.fill', android: 'person', web: 'person' },
  people: { ios: 'person.2.fill', android: 'group', web: 'group' },
  receipt: { ios: 'doc.text', android: 'receipt_long', web: 'receipt_long' },
  check: { ios: 'checkmark', android: 'check', web: 'check' },
  checkCircle: { ios: 'checkmark.circle.fill', android: 'check_circle', web: 'check_circle' },
  warning: { ios: 'exclamationmark.triangle.fill', android: 'warning', web: 'warning' },
  info: { ios: 'info.circle.fill', android: 'info', web: 'info' },
  settings: { ios: 'gearshape.fill', android: 'settings', web: 'settings' },
  retake: { ios: 'arrow.counterclockwise', android: 'refresh', web: 'refresh' },
  share: { ios: 'square.and.arrow.up', android: 'share', web: 'share' },
  lock: { ios: 'lock.fill', android: 'lock', web: 'lock' },
  edit: { ios: 'pencil', android: 'edit', web: 'edit' },
  arrowRight: { ios: 'arrow.right', android: 'arrow_forward', web: 'arrow_forward' },
} as const satisfies Record<string, SymbolSpec>;

export type IconName = keyof typeof ICONS;

export interface IconProps {
  name: IconName;
  size?: number;
  color?: string;
}

/** Decorative by default: hidden from screen readers. Label the parent control instead. */
export function Icon({ name, size = iconSize.md, color = colors.text.primary }: IconProps) {
  return (
    <SymbolView
      name={ICONS[name]}
      size={size}
      tintColor={color}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    />
  );
}
