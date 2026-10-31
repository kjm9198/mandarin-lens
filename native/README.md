# Kamihi Lens 4.2

A native Chinese study workspace and screen translator for Apple Silicon Macs running macOS 15 or later. The Chrome extension in the repository root is a separate product.

## Install and use

Download the **4.2 macOS preview** DMG from [Releases](https://github.com/kjm9198/mandarin-lens/releases). Drag Kamihi Lens into Applications and open it. This is an Apple Development signed preview, **not notarized**; macOS may require approval in Privacy & Security. The current verified machine is an Apple Silicon Mac running macOS 27. Other OS versions and hardware remain unverified.

- **Option–Space**: click a word in text, an image or another readable screen surface. A small result near your cursor shows the word, system pinyin for Chinese, translation, Chinese pronunciation playback, Copy and Save. Chinese words also receive an example with a Chinese sentence, tone-mark pinyin and an English translation. Examples are generated with the selected local AI, checked for the requested word, translated with Apple Translation and saved with the history/dictionary entry; unavailable models show a retry action.
- **Control–Space**: click anywhere in a sentence. The screen selector has Word, Sentence and Section buttons, so you can switch without restarting. Dragging a rectangle from any mode selects a section. Settings offers Control–Shift–Space when macOS Input Sources reserves the default.
- **Control–Option–Space**: drag an area like a screenshot. **Space** selects the whole display. Recognized lines are translated into your chosen language and kept in reading order; lines already in that language are retained.
- **Escape** or the same shortcut again clears selection and its result. Outside clicks dismiss the result when “Keep window floating” is off.
- Allow **Screen & System Audio Recording** for screen selection. No audio is captured. Apple Vision reads a single in-memory snapshot; pixels are released after selection/cancellation. Small, stylized, unclear or protected content may not be readable. Accessibility is needed only for the separate Capture selected text action.
- **Settings → Translate into** changes the translation target; **AI explanations in** changes chat and recaps. The default target is Simplified Chinese. Automatic source detection uses a confident surrounding line or defaults short Latin words to English; **Translate from** provides an explicit override. This avoids isolated English words such as “Control” being mistaken for Romanian.
- Results automatically enter **History**, including repeated captures and translation failures. Search source, translation or pinyin, star favorites, and create local AI learning recaps from Today, Last 7 days or Favorites. A missing translation pack or model shows a recoverable message. AI recaps can be wrong.
- **My words** is your dictionary: open an entry for pinyin, meaning, captured context, Listen, Copy and Example & usage. Search and categories, local JSON export, review, optional speaking practice and Surprise me remain available.
- **Play** opens seven games inspired by Sproutsly’s language activities: Meaning finder, Reverse recall, Listen & choose, Word builder, Meaning map, Memory match and Pinyin path. Pick a language pair and category. Games use short, distinct saved pairs; insufficient decks show what to save. Word builder reorders letters, Chinese characters or phrase tiles. Answer, Check, feedback and Continue are separate steps. Listening can reveal a transcript; hints and mistakes enter a revisit list. Scores are for that round, with no timer or changes to saved words/review dates. Pinyin is system transliteration, not a reviewed dictionary.
- The interface uses one adaptive paper/charcoal/teal palette, standard macOS typography, full-width sidebar targets and consistent controls. Compact puts the translation first; expand Original to edit the source. Quiz Check/Continue actions stay visible while the question scrolls.
- Every sidebar row is clickable across its full width. The full workspace supports macOS full screen and a 760-point minimum width; Compact starts at 410 points and exposes additional sections through **More sections**.

## Translation languages and speed

Choose **From** and **To** in the translation screen. Use an explicit source for short Polish or Vietnamese words; a single word can be ambiguous in Automatic mode. Swap reverses the translated pair. **Section** means dragging a rectangle around the paragraph you want; Space captures the whole display and Escape cancels. The Sentence button shows the shortcut selected in Settings.

**Apple · Fast** is the default and requests Apple’s traditional low-latency models. **Apple · Natural**, on macOS 26.4 or later, requests Apple Translation’s high-fidelity strategy, which uses Apple Intelligence where available and falls back according to system/device/language support. Earlier macOS versions use the system translation framework available there. The engine manages its own models; the app does not choose a named Qwen model for these translations.

**Ready offline** checks the selected strategy and language pair. If Fast needs languages, choose **Prepare languages** and use Apple’s download sheet. Preparation changes no text or history. Natural being ready does not mean that the separate Fast models are installed. Language packs are shared by macOS apps.

Section translation honors From, joins likely wrapped sentence lines before translation, preserves mixed-language order and matches batch responses by identifier. Translation history caches are isolated by source selection and translation mode. Machine translation can still change a time, name or meaning; the 4.2 fixture benchmark found a written-time error in Natural mode, so these results are not a quality certification.

[4.2 selection, translation and timing evidence](reports/SELECTION-TRANSLATION-4.2.md). Apple references: [strategies](https://developer.apple.com/documentation/translation/translationsession/strategy), [high fidelity](https://developer.apple.com/documentation/translation/translationsession/strategy/highfidelity).

## Local AI

Local AI has model selection, explicit 2B/4B chat and Whisper speech downloads, a resident-model Unload control, and a separate advanced local-server section. Apple Translation and all seven games work without an AI model.

Use **Install local runtime** for one-time Python package setup from PyPI. It needs a compatible Python 3.10+ interpreter with venv, network access and disk space; it does not bundle Python. Setup uses `mlx-vlm 0.7.11`, `mlx-audio 0.6.3` and `huggingface_hub`. Downloads fetch weights from Hugging Face; learning data is not sent with them. The bundled setup helper was checked statically; a clean-machine package installation has not been independently tested.

MLX runs with offline inference settings and no remote-code option. Automatic picks the smallest installed chat model. One chat/categorization/recap request runs at a time; generation streams, can be stopped and rejects stale updates. Unload releases the resident worker and keeps downloaded files. A local LM Studio/Bionic adapter accepts only `127.0.0.1`, rejects redirects and stores tokens in Keychain. Real authenticated providers remain unverified.

Speaking practice is optional and records only after an explicit action and macOS permission. It compares recognized words, **not accent or Mandarin-tone quality**. Clips are limited to 12 seconds and deleted after recognition/cancellation. Device voices and short-word speech recognition can be inaccurate.

## Existing data

Version 4.2 retains `studio.kamihi.mandarinlens.v31`, the existing defaults and Keychain service. Vocabulary, categories, review dates, history, chat, recaps and model files remain in `~/Library/Application Support/Mandarin Lens`. The internal folder name intentionally stays unchanged. Quit the previous app before opening a replacement. No store reset or cloud sync is performed.

## Build and verification

```sh
./native/build.sh
swift test --package-path native
./native/package.sh
```

The package is `native/build/KamihiLens-4.2.0-macOS-arm64.dmg`, with a SHA-256 file. The build uses an Apple Development signing identity when available, or ad-hoc signing otherwise; `LENS_SIGNING_IDENTITY` selects an identity.

[4.1 design and acceptance](reports/DESIGN-4.1.md) separates automated, actual native UI, local-model and delivery evidence. Older reports describe historical behavior. `Tests/NativeDriver.swift` and `Tests/CaptureFixture.swift` support controlled installed-app checks with isolated learning data. No bug-free, broad VoiceOver, all-language, physical microphone, mixed-DPI or clean-machine acceptance is claimed.
