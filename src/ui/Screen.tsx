import type { ReactNode } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { borderWidth, colors, layout, spacing } from '@/ui/theme/tokens';

/** Keeps content readable when the app is opened on a wide browser window. */
const MAX_CONTENT_WIDTH = 560;

export interface ScreenProps {
  children: ReactNode;
  /** Rendered above the body, below the status bar. Usually a `ScreenHeader`. */
  header?: ReactNode;
  /** Pinned to the bottom, above the home indicator. Moves up with the keyboard. */
  footer?: ReactNode;
  /** Wrap the body in a ScrollView. Default true. */
  scroll?: boolean;
  contentStyle?: StyleProp<ViewStyle>;
}

/**
 * The shared page frame: dark background, safe-area handling, an optional
 * pinned footer, and keyboard avoidance. Every screen uses it, which is what
 * keeps spacing and chrome identical across the app.
 */
export function Screen({ children, header, footer, scroll = true, contentStyle }: ScreenProps) {
  const insets = useSafeAreaInsets();
  const bottomInset = Math.max(insets.bottom, spacing.lg);

  return (
    <View style={styles.root}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={{ paddingTop: insets.top }}>
          {header ? <View style={styles.constrained}>{header}</View> : null}
        </View>

        {scroll ? (
          <ScrollView
            style={styles.flex}
            contentContainerStyle={[
              styles.content,
              { paddingBottom: footer ? spacing.xl : bottomInset + spacing.xl },
              contentStyle,
            ]}
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode={Platform.OS === 'ios' ? 'interactive' : 'on-drag'}
            showsVerticalScrollIndicator={false}
          >
            {children}
          </ScrollView>
        ) : (
          <View style={[styles.flex, styles.content, contentStyle]}>{children}</View>
        )}

        {footer ? (
          <View style={styles.footerFrame}>
            <View style={[styles.footer, styles.constrained, { paddingBottom: bottomInset }]}>
              {footer}
            </View>
          </View>
        ) : null}
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.surface.background },
  flex: { flex: 1 },
  constrained: { width: '100%', maxWidth: MAX_CONTENT_WIDTH, alignSelf: 'center' },
  content: {
    width: '100%',
    maxWidth: MAX_CONTENT_WIDTH,
    alignSelf: 'center',
    paddingHorizontal: layout.screenPadding,
    paddingTop: spacing.md,
    gap: spacing.lg,
  },
  footerFrame: {
    borderTopWidth: borderWidth.hairline,
    borderTopColor: colors.surface.border,
    backgroundColor: colors.surface.background,
  },
  footer: {
    paddingHorizontal: layout.screenPadding,
    paddingTop: spacing.md,
    gap: spacing.sm,
  },
});
