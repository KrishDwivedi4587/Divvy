import { Text as RNText, type TextProps as RNTextProps, type TextStyle } from 'react-native';

import { colors, numeric, typography, type TypographyVariant } from '@/ui/theme/tokens';

export type TextTone =
  | 'primary'
  | 'secondary'
  | 'muted'
  | 'inverse'
  | 'onAction'
  | 'success'
  | 'warning'
  | 'error'
  | 'info';

const TONE: Record<TextTone, string> = {
  primary: colors.text.primary,
  secondary: colors.text.secondary,
  muted: colors.text.muted,
  inverse: colors.text.inverse,
  onAction: colors.action.onPrimary,
  success: colors.status.success,
  warning: colors.status.warning,
  error: colors.status.error,
  info: colors.status.info,
};

export interface TextProps extends RNTextProps {
  variant?: TypographyVariant;
  tone?: TextTone;
  /** Tabular figures. Set on every money value so digits keep a fixed width. */
  tabular?: boolean;
  align?: TextStyle['textAlign'];
}

/** The one text component. Type and colour come from the design tokens only. */
export function Text({
  variant = 'body',
  tone = 'primary',
  tabular = false,
  align,
  style,
  ...rest
}: TextProps) {
  return (
    <RNText
      {...rest}
      style={[
        typography[variant],
        { color: TONE[tone] },
        tabular ? numeric : null,
        align ? { textAlign: align } : null,
        style,
      ]}
    />
  );
}
