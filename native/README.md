# Mandarin Lens — native private development build

SwiftUI and AppKit menu-bar utility for Apple Silicon, macOS 15+. Tested on macOS 27 on an M5 Pro with 48 GB; other hardware and OS versions are not independently verified.

## Build and install

From the repository root, run `native/build.sh`. Copy `native/build/Mandarin Lens.app` to `~/Applications` and open it. This is an ad-hoc signed private development build, not notarized. Generate the private DMG with `native/package.sh`. The DMG is generated locally; model files and the Python runtime are not bundled. Translation uses Apple Translation, which may request language-pack installation. The tested MLX runtime lives in `~/Library/Application Support/Mandarin Lens/mlx-runtime` and was installed using Python 3.12 and `pip install mlx-vlm huggingface_hub`.

## Everyday use

- Tap the configured modifier, then click an accessible word. Choose Control, Option or Command in settings.
- Select text in another app and press Control–Shift–T. Screen area capture is Control–Shift–S; Entire display is available in Capture. Accessibility/Screen Recording permissions may need approval after updating an ad-hoc signed build. Clipboard contents are not modified.
- Translation targets: English, Vietnamese, Polish, Simplified Chinese and Traditional Chinese. Pair availability depends on Apple packs. Tested pairs include English → Vietnamese, Polish, Simplified Chinese and Simplified Chinese → English. Other pairs remain unverified.
- Choose Save word after translating. Pick a token from the original or translation, get its own translation, edit its meaning, and save it to Words. The original sentence is restored afterward.
- Words offers search, category filtering, manual categories, installed-voice pronunciation, JSON export, examples and review. Meanings are user-saved translations, not an authoritative lexical dictionary. Pinyin uses system transliteration and can depend on context.
- New words receive a rule-based category suggestion. Uncertain items stay Unsorted. Categorize all uses the selected local model in batches of eight, validates category names and IDs, persists completed batches and preserves manual categories. AI categorization is fallible and editable.
- Review: reveal the meaning, then Again (10 minutes) or Remembered (initially one day, doubling to 30 days).
- Learn uses up to 12 saved words, four recent translations and six in-memory conversation turns. Chats are not persisted. Clear with New question. Translation history and saved words are persistent local JSON files with owner-only permissions; corrupt vocabulary files are preserved instead of overwritten.
- The question-mark button reopens the four-step tutorial. New installations show it on first launch.

## Models

Choose model is accessible from Learn or note settings. Discovery scans installed model directories and user-chosen folders. It does not download weights or execute model-provided code. The installed models discovered on this machine include Qwen 3.5 2B MLX, custom Qwen 3.5 9B MLX, custom Qwen 3.8 27B MLX and a Gemma 4 31B GGUF catalogue entry.

Automatic uses the smallest installed MLX model on 16–24 GB machines; on this 48 GB machine it chooses the tested 9B model. This is a conservative size heuristic, not a complete memory-pressure manager or a universal accuracy ranking. One local AI request runs at a time, with bounded prompts, output and a two-minute deadline. Models run in a subprocess and unload on exit. Models exceeding 8 GB of weight files are refused on machines with 24 GB or less. Small-model multilingual quality is limited; neither candidate is certified as the best model available.

MLX folders run directly with offline Hugging Face settings and no remote-code option. Custom quantization/runtime formats may be incompatible; untested large models are listed without claiming runtime support. Downloaded GGUF entries require a local server: they cannot be run by the direct MLX provider.

For LM Studio/Bionic, enable their local OpenAI-compatible server, enter its port, and Connect. Only `127.0.0.1` endpoints are constructed, redirects are rejected, and the app opens no inference listener. A token, if required by the server, can be saved to Keychain. The server on this machine required a token, so authenticated real-server inference remains unverified. The adapter was tested against a local explicit fixture. Use downloaded local models in the external server; its own routing/LM Link configuration is outside Lens's control. Lens's direct MLX inference was tested with network access denied at the OS sandbox layer.

## Privacy and limits

No analytics, accounts, remote AI endpoints or cloud sync are added. Local prompts are bounded; AI has no command/file/system tools. Screen captures occur only on explicit request, are OCR'd with Apple Vision, and temporary images are removed. Captures are bounded to 16,000 characters. Secure text fields are rejected by Accessibility capture; inaccessible/protected surfaces and OCR errors remain possible. Real cross-app capture permission acceptance and multi-display behavior still need user validation.

Private mode, Chrome native messaging/shared vocabulary, launch-at-login, dictionary datasets, full memory/thermal scheduling and complete multilingual quality evaluation are not included. Speech playback, broad VoiceOver/keyboard interaction, 16 GB hardware performance and all translation pairs are not certified by the current checks.

See `reports/LEARNING-UPDATE.md` for test results, measurements, screenshots and reproducible checks.
