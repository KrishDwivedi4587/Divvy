import { useRouter } from 'expo-router';
import { useCallback } from 'react';

/**
 * Back navigation that cannot dead-end. If there is history, go back; if the
 * screen was opened directly (a reload, or a deep link on web) there is nothing
 * to go back to, so fall through to Home rather than do nothing.
 */
export function useGoBack() {
  const router = useRouter();

  return useCallback(() => {
    if (router.canGoBack()) router.back();
    else router.replace('/');
  }, [router]);
}
