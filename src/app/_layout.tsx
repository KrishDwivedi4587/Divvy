import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';

import { BillProvider } from '@/store/BillProvider';
import { colors } from '@/ui/theme/tokens';

export default function RootLayout() {
  return (
    <BillProvider>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          // Every screen draws its own header (ScreenHeader) so the chrome is
          // identical on iOS, Android and web.
          headerShown: false,
          contentStyle: { backgroundColor: colors.surface.background },
          animation: 'slide_from_right',
        }}
      />
    </BillProvider>
  );
}
