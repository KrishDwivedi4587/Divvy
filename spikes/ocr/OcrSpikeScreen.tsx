/**
 * Spike 0 harness — ML Kit text recognition.
 *
 * ⚠️ UNVERIFIED. This has never been executed: Spike 0 stopped before runtime
 * validation because no Android device was connected and no receipt fixtures
 * existed. Treat it as a starting point to debug on device, not as working
 * code.
 *
 * Scope: recognition ONLY. It deliberately does not parse anything — no line
 * items, no amounts, no totals. Parsing is a separate concern that lands in
 * src/ocr/parseReceipt.ts in Phase 5.
 *
 * Throwaway. Never imported by src/.
 */

import TextRecognition from '@react-native-ml-kit/text-recognition';
import { Asset } from 'expo-asset';
import { useCallback, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

/**
 * Fixtures are bundled as app assets rather than pushed with `adb push`, which
 * avoids Android's scoped-storage permissions entirely — ML Kit just needs a
 * readable local file URI.
 *
 * Populate spikes/ocr/fixtures/ first (see its README), then uncomment.
 */
const FIXTURES: { id: string; module: number }[] = [
  // { id: 'r1', module: require('./fixtures/r1.jpg') },
  // { id: 'r2', module: require('./fixtures/r2.jpg') },
  // ... through r8
];

type Result = {
  id: string;
  ok: boolean;
  error?: string;
  elapsedMs: number;
  charCount: number;
  blockCount: number;
  lineCount: number;
  /** Full raw ML Kit response, preserved verbatim for offline inspection. */
  raw: unknown;
};

async function runFixture(id: string, moduleRef: number): Promise<Result> {
  const started = Date.now();
  try {
    const asset = Asset.fromModule(moduleRef);
    await asset.downloadAsync();
    const uri = asset.localUri ?? asset.uri;

    const result = await TextRecognition.recognize(uri);

    const blocks = result.blocks ?? [];
    const lineCount = blocks.reduce((n, b) => n + (b.lines?.length ?? 0), 0);

    return {
      id,
      ok: true,
      elapsedMs: Date.now() - started,
      charCount: (result.text ?? '').length,
      blockCount: blocks.length,
      lineCount,
      raw: result,
    };
  } catch (e) {
    return {
      id,
      ok: false,
      error: e instanceof Error ? e.message : String(e),
      elapsedMs: Date.now() - started,
      charCount: 0,
      blockCount: 0,
      lineCount: 0,
      raw: null,
    };
  }
}

export default function OcrSpikeScreen() {
  const [results, setResults] = useState<Result[]>([]);
  const [running, setRunning] = useState(false);

  const run = useCallback(async () => {
    setRunning(true);
    setResults([]);

    const collected: Result[] = [];
    // Sequential on purpose: concurrent recognition would make the per-fixture
    // timings meaningless.
    for (const f of FIXTURES) {
      const r = await runFixture(f.id, f.module);
      collected.push(r);
      setResults([...collected]);
    }

    // Deterministic, copy-pasteable. Pipe from `npx expo start --dev-client`
    // into spikes/ocr/results/ and inspect offline.
    console.log('=== SPIKE 0 RAW OCR OUTPUT ===');
    console.log(JSON.stringify(collected, null, 2));
    console.log('=== END ===');

    setRunning(false);
  }, []);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Spike 0 — ML Kit OCR</Text>

      {FIXTURES.length === 0 ? (
        <Text style={styles.warn}>
          No fixtures. Add receipt images to spikes/ocr/fixtures/ and uncomment the FIXTURES array.
        </Text>
      ) : (
        <Pressable style={styles.button} onPress={run} disabled={running}>
          <Text style={styles.buttonText}>
            {running ? 'Running…' : `Recognise ${FIXTURES.length} fixtures`}
          </Text>
        </Pressable>
      )}

      {results.map((r) => (
        <View key={r.id} style={styles.row}>
          <Text style={styles.rowTitle}>
            {r.id} — {r.ok ? 'OK' : 'FAILED'}
          </Text>
          <Text style={styles.rowMeta}>
            {r.ok
              ? `${r.charCount} chars · ${r.blockCount} blocks · ${r.lineCount} lines · ${r.elapsedMs}ms`
              : r.error}
          </Text>
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16, gap: 12 },
  title: { fontSize: 20, fontWeight: '700' },
  warn: { fontSize: 14, lineHeight: 20 },
  button: { padding: 14, borderRadius: 8, backgroundColor: '#6B4EEA' },
  buttonText: { color: '#FFFFFF', fontWeight: '700', textAlign: 'center' },
  row: { paddingVertical: 8, borderTopWidth: 1, borderTopColor: '#CCCCCC' },
  rowTitle: { fontWeight: '700' },
  rowMeta: { fontSize: 12 },
});
