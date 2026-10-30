# Mandarin Lens 3.7 — native private build

SwiftUI/AppKit for Apple Silicon, macOS 15+. Current verification: macOS 27, M5 Pro, 48 GB. Other hardware and OS versions have not been independently validated.

## Build and install

Run `native/build.sh` from the repository root. Copy `native/build/Mandarin Lens 3.7.app` to `~/Applications` and open it. `native/package.sh` creates `native/build/MandarinLens-3.7-private.dmg` with the app and Applications shortcut. It uses an available Apple Development signing identity, or ad-hoc signing if none exists. Set `LENS_SIGNING_IDENTITY` to select a certificate. This is a private development build, not notarized or a public binary release.

Versioned app names distinguish installations. Builds 3.1–3.7 intentionally share the approved `studio.kamihi.mandarinlens.v31` identity and development signature to retain permission grants. Quit the previous version before opening another. Only one instance may use the shared stores. Dictionary, review progress, categories, translation history and chat history remain in `~/Library/Application Support/Mandarin Lens`. Preferences migrate from the original app; API tokens remain in the same Keychain service.

The DMG does not bundle model weights or Python. The current Mac has Python 3.12 with `mlx-vlm 0.7.11`, `mlx-audio 0.6.3` and `huggingface_hub` in `~/Library/Application Support/Mandarin Lens/mlx-runtime`. A fresh Mac needs a compatible local runtime or a local LM Studio/Bionic server. Apple Translation may separately request language packs.

## Everyday use

- Point at a word, then press **Option–Space**. No click or prior selection is required in compatible apps. A selection is preferred only when the pointer lies inside it. The app under the pointer supplies the text, even when another application has focus.
- A 340 × 252 point lookup shows the exact text, relevant pinyin, translation/progress/error, Save/Saved, target language, Open full app and Compact. Accurate Accessibility bounds produce a click-through outline. Unsupported or protected surfaces receive an honest fallback; lookup never silently captures a screen.
- Escape dismisses lookup and restores focus. An outside click dismisses it when **Keep floating windows above other apps** is off. When enabled, the companion stays above other apps and quick lookup remains open after outside clicks. Clicks clear its old highlight.
- Settings offers Option–Space, Control–Option–Space and Option–Shift–Space, native conflict feedback, persistent opacity, explanation language and permission controls. Modifier keys alone never activate lookup.
- **Open full app** opens a larger workspace with Translator, My words, History, Learn, Local models and Settings/tutorial. The window supports macOS full screen. **Compact** opens the smaller companion. Expanding preserves the word, translation and captured context.
- In the full translator, Save word uses an immutable presentation snapshot. Select a token, translate its own meaning, edit it and save; dismissing restores the original pair/context. Duplicate prevention preserves Vietnamese tone distinctions. A failed disk write does not report Saved.
- My words retains search, categories, validated local-AI categorization, review, pronunciation, examples and JSON export. Pinyin is system transliteration, not an authoritative pronunciation dictionary.
- Learn displays user and assistant messages, live model output, Stop, New chat and local Chat history. Context is bounded to recent messages, a limited vocabulary sample and captured text. Chat history is persistent, owner-only JSON; corrupt chat files are preserved.
- Speaking practice is optional. Apple on-device recognition is used where available; the downloaded Whisper small model supplies an offline fallback. Recording is limited to 12 seconds; temporary clips are deleted after recognition/cancellation. Recognized words are compared with the entry, accepting Simplified/Traditional spelling equivalence while preserving Vietnamese tones. This does **not** grade accent, Mandarin tones or pronunciation quality. Short-word recognition can be wrong.

## Local models

Local models has explicit downloads for Qwen 3.5 2B, Qwen 3.5 4B and Whisper small speech recognition, plus installed-model discovery and custom folders. Downloads use Hugging Face; prompts, vocabulary and audio are not sent there. Downloads can be cancelled and resumed. Speech models are stored separately and cannot accidentally become the chat model.

Automatic uses the smallest installed MLX chat model. One chat/categorization request runs at a time. The worker keeps weights resident between requests, streams JSON-framed text, bounds prompts/output and has a two-minute deadline. Stop and model switching cancel the running request; stale results cannot replace newer requests. Models over 8 GB of weight files are refused on machines with 24 GB or less. This is a conservative guard, not a complete memory-pressure manager or an accuracy ranking.

Direct MLX inference uses offline Hugging Face settings and no remote-code option. GGUF catalogue entries require a compatible local server. The optional API adapter constructs only `127.0.0.1` URLs, rejects redirects and streams responses; tokens stay in Keychain. Real authenticated LM Studio/Bionic inference remains unverified. The adapter's protocol is tested against an explicit local fixture.

## Verification and limits

See [the acceptance report](reports/LEARNING-UPDATE.md) for native journeys, actual display geometry, screenshots, automated tests and model-quality limits. No 16 GB hardware, mixed-DPI display, broad VoiceOver or human pronunciation certification is claimed. Region/display OCR remains explicit and uses local Apple Vision. No cloud inference, analytics, mandatory accounts, subscriptions or sync were added.

Reproduce automated checks:

```sh
cd native
swift test
cd ..
xcrun swiftc -target arm64-apple-macos15.0 -parse-as-library native/Sources/MandarinLens/LocalModels.swift native/Sources/MandarinLens/ModelWorker.swift native/Sources/MandarinLens/Vocabulary.swift native/Tests/FeatureSmoke.swift -framework AppKit -framework NaturalLanguage -framework Security -o /tmp/lens-feature-smoke
python3 native/Tests/api_fixture.py
sandbox-exec -p '(version 1)(allow default)(deny network*)' /tmp/lens-feature-smoke --cancel --switch
sandbox-exec -p '(version 1)(allow default)(deny network*)' /usr/bin/python3 native/Tests/worker_smoke.py
```

`Tests/NativeDriver.swift`, `Tests/TargetFixture.swift` and `Tests/native_edges.py` support real installed-app acceptance. The edge test requires two connected displays and four visible fixture text windows; it is not a headless substitute for cross-app UI testing. Never grant macOS permissions programmatically. Microphone practice requires the user's permission and real voice for human acceptance.
