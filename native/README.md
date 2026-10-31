# Kamihi Lens 3.8 — native private build

SwiftUI/AppKit for Apple Silicon, macOS 15+. Current verification: macOS 27, M5 Pro, 48 GB. Other hardware and OS versions have not been independently validated.

## Build and install

Run `native/build.sh` from the repository root. Copy `native/build/Kamihi Lens.app` to `~/Applications` and open it. `native/package.sh` creates `native/build/KamihiLens-3.8-private.dmg` with the app and Applications shortcut. It uses an available Apple Development signing identity, or ad-hoc signing if none exists. Set `LENS_SIGNING_IDENTITY` to select a certificate. This is a private development build, not notarized or a public binary release.

Kamihi Lens is the renamed native app. Version 3.8 retains the stable `studio.kamihi.mandarinlens.v31` identity, development signature, existing defaults and Keychain service. Dictionary, review progress, categories, translation history, chat history and downloaded models remain in `~/Library/Application Support/Mandarin Lens`. This internal folder name intentionally stays unchanged. Quit the previous app before opening the new one; only one instance may use the stores.

The DMG does not bundle model weights or Python. The current Mac has Python 3.12 with `mlx-vlm 0.7.11`, `mlx-audio 0.6.3` and `huggingface_hub` in `~/Library/Application Support/Mandarin Lens/mlx-runtime`. A fresh Mac needs a compatible local runtime or a local LM Studio/Bionic server. Apple Translation may separately request language packs.

## Everyday use

- Press **Option–Space** to enter screen selection, then click a word. A crosshair and a light outline follow recognized words. No translation panel, notification or app window opens from the shortcut.
- Screen selection uses local Apple Vision OCR on an in-memory snapshot of the connected displays. It works on readable raster text in images, videos and apps without native text selection. The snapshot keeps moving content still while you choose. Pixels are released when a word is chosen or the mode is cancelled. It needs macOS **Screen & System Audio Recording** permission (no audio is captured); allow it in Kamihi Lens → Settings before first use. A permission denial stays in the app's status text and does not open a popup from the shortcut.
- Arrow keys or Tab move through recognized words; Return chooses the highlighted word.
- After a click, only a small click-through highlight remains. Normal clicks return to the source app. **Escape** or **Option–Space again** cancels both the selection mode and the remaining highlight. Repeating a held shortcut does not create duplicate windows. Clicking blank space keeps selection mode active.
- Open **Kamihi Lens** from Applications or the Dock to translate the last selected word, save it or use the full workspace. Cancelling the highlight preserves that word for later. Selection itself never starts translation, writes vocabulary or adds history.
- Settings offers Option–Space, Control–Option–Space and Option–Shift–Space, conflict feedback, opacity, explanation language and permission controls. Modifier keys alone never start selection. The floating-window preference only affects the app window.
- Text must be visible and readable. OCR can misread small, low-contrast or stylized text; protected/DRM content cannot be promised. Selection is a snapshot, not continuous monitoring. Capture → Selected text still provides the explicit Accessibility route for an already selected sentence. Secure Accessibility fields remain rejected. Explicit area/display OCR is also available from the app.
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

See [the 3.8 selection acceptance report](reports/KAMIHI-LENS-3.8.md) and [the prior workspace report](reports/LEARNING-UPDATE.md) for native journeys, actual display geometry, screenshots, automated tests and model-quality limits. No 16 GB hardware, mixed-DPI display, broad VoiceOver or human pronunciation certification is claimed. The shortcut explicitly starts snapshot OCR; additional region/display capture remains available in the app. All recognition uses local Apple Vision. No cloud inference, analytics, mandatory accounts, subscriptions or sync were added.

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

`Tests/NativeDriver.swift` and `Tests/TargetFixture.swift` support real installed-app acceptance. The older `Tests/native_edges.py` documents the former 3.7 lookup-panel behavior and is not a test of the new selection workflow. Never grant macOS permissions programmatically. Microphone practice requires the user's permission and real voice for human acceptance.
