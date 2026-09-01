/**
 * Spike 0 harness — ML Kit text recognition.
 *
 * ⚠️ NOT YET EXECUTED. No Android device has been connected, so nothing below
 * has run. Treat it as a starting point to debug on device.
 *
 * It answers two separable questions, deliberately kept apart:
 *
 *   1. Does the native module LOAD and does recognize() work at all?
 *      Needs only a device and any photo of printed text. No fixtures.
 *   2. Is OCR good enough on real Indian receipts?
 *      Needs the eight fixtures in ./fixtures.
 *
 * Question 1 is the one that gates the architecture, and it is answerable the
 * moment a phone is plugged in.
 *
 * Scope: recognition ONLY. No parsing — no line items, amounts or totals.
 * Parsing lands in src/ocr/parseReceipt.ts in Phase 5.
 *
 * Throwaway. Never imported by src/. See ./RUNBOOK.md to run it.
 */

import TextRecognition from '@react-native-ml-kit/text-recognition';
import { useCallback, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  type TextStyle,
} from 'react-native';

/** Where RUNBOOK.md tells you to `adb push` a test image. */
const DEFAULT_URI = 'file:///data/local/tmp/ocr/test.jpg';

type Outcome = {
  ok: boolean;
  /** Distinguishes "module missing" from "recognition failed" — the key diagnostic. */
  moduleLoaded: boolean;
  error?: string;
  elapsedMs: number;
  text: string;
  blockCount: number;
  lineCount: number;
  raw: unknown;
};

/**
 * A missing/unlinked native module throws a specific shape. Under the New
 * Architecture interop layer this is exactly the failure we are looking for, so
 * it is reported separately rather than lumped in with recognition errors.
 */
function looksLikeMissingNativeModule(message: string): boolean {
  const m = message.toLowerCase();
  return (
    m.includes('null is not an object') ||
    m.includes('cannot read property') ||
    m.includes('turbomodule') ||
    m.includes('native module') ||
    m.includes('not found') ||
    m.includes('undefined is not a function')
  );
}

async function recognizeUri(uri: string): Promise<Outcome> {
  const started = Date.now();
  try {
    const result = await TextRecognition.recognize(uri);
    const blocks = result?.blocks ?? [];
    return {
      ok: true,
      moduleLoaded: true,
      elapsedMs: Date.now() - started,
      text: result?.text ?? '',
      blockCount: blocks.length,
      lineCount: blocks.reduce((n, b) => n + (b.lines?.length ?? 0), 0),
      raw: result,
    };
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return {
      ok: false,
      moduleLoaded: !looksLikeMissingNativeModule(message),
      error: message,
      elapsedMs: Date.now() - started,
      text: '',
      blockCount: 0,
      lineCount: 0,
      raw: null,
    };
  }
}

export default function OcrSpikeScreen() {
  const [uri, setUri] = useState(DEFAULT_URI);
  const [running, setRunning] = useState(false);
  const [outcome, setOutcome] = useState<Outcome | null>(null);

  const run = useCallback(async () => {
    setRunning(true);
    setOutcome(null);

    const result = await recognizeUri(uri.trim());
    setOutcome(result);

    // Deterministic and copy-pasteable out of the Metro terminal.
    console.warn('=== SPIKE 0 RAW OCR OUTPUT ===');
    console.warn(JSON.stringify({ uri, ...result }, null, 2));
    console.warn('=== END ===');

    setRunning(false);
  }, [uri]);

  const status: { label: string; style: TextStyle } = !outcome
    ? { label: 'not run', style: styles.neutral }
    : outcome.ok
      ? { label: 'RECOGNITION OK', style: styles.good }
      : outcome.moduleLoaded
        ? { label: 'MODULE LOADED, RECOGNITION FAILED', style: styles.warn }
        : { label: 'NATIVE MODULE DID NOT LOAD', style: styles.bad };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Spike 0 — ML Kit OCR</Text>
      <Text style={styles.hint}>Push an image to the device first, then run. See RUNBOOK.md.</Text>

      <TextInput
        style={styles.input}
        value={uri}
        onChangeText={setUri}
        autoCapitalize="none"
        autoCorrect={false}
        placeholder="file:///…"
      />

      <Pressable style={styles.button} onPress={run} disabled={running}>
        <Text style={styles.buttonText}>{running ? 'Recognising…' : 'Recognise'}</Text>
      </Pressable>

      <Text style={[styles.status, status.style]}>{status.label}</Text>

      {outcome ? (
        <View style={styles.results}>
          <Text style={styles.meta}>
            {outcome.text.length} chars · {outcome.blockCount} blocks · {outcome.lineCount} lines ·{' '}
            {outcome.elapsedMs}ms
          </Text>
          {outcome.error ? <Text style={styles.error}>{outcome.error}</Text> : null}
          {outcome.text ? <Text style={styles.raw}>{outcome.text}</Text> : null}
        </View>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16, gap: 12 },
  title: { fontSize: 20, fontWeight: '700' },
  hint: { fontSize: 12 },
  input: { borderWidth: 1, borderColor: '#999999', borderRadius: 8, padding: 10, fontSize: 12 },
  button: { padding: 14, borderRadius: 8, backgroundColor: '#6B4EEA' },
  buttonText: { color: '#FFFFFF', fontWeight: '700', textAlign: 'center' },
  status: { fontWeight: '700', fontSize: 14 },
  neutral: { color: '#7A879E' },
  good: { color: '#0B7A55' },
  warn: { color: '#8A6100' },
  bad: { color: '#B00020' },
  results: { gap: 8 },
  meta: { fontSize: 12 },
  error: { fontSize: 12, color: '#B00020' },
  raw: { fontSize: 11, fontFamily: 'monospace' },
});
