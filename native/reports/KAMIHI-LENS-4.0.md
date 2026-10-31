# Kamihi Lens 4.0 acceptance — 31 October 2026

Native Apple Silicon preview, version 4.0.0/build 40. The installed app is `~/Applications/Kamihi Lens.app`. It retains the approved bundle identity, existing storage, defaults and Keychain service. The Chrome extension remains separate. This is an Apple Development signed preview, **not notarized**.

## Result

Word, sentence and area shortcuts now translate immediately into the selected language and show a bounded result near the cursor. Chinese word results contain characters, system tone-mark pinyin, Chinese playback, and a local AI usage example with Chinese, English and sentence pinyin. Saving a Chinese translation stores the Chinese headword with its original meaning, context and available example. Examples completing after Save are attached to the saved entry.

The reported `Control` failure was reproduced: Natural Language identified the isolated English word as Romanian (`ro`). Automatic translation-source resolution now uses confident surrounding context, or English for short ASCII Latin words. Settings exposes separate **Translate into**, **Translate from** and **AI explanations in** controls. Source changes invalidate the request/cache key. The normal installed app was left using Simplified Chinese and automatic source detection; test launch arguments were removed.

Every sidebar row has a full-width hit region, including blank space. A Play section adapts Sproutsly’s large choices, explicit Check/feedback/Continue flow, matching, memory and tile building into seven native games: Meaning finder, Reverse recall, Listen & choose, Word builder, Meaning map, Memory match and Pinyin path. Games use one language pair and optional category, reject ambiguous duplicate answers, retain hints/mistakes for a revisit round and leave review dates unchanged. Legacy `zh`/`zh-Hans` and ambiguous single-Han codes share a Chinese practice deck. Pinyin remains system transliteration.

Local AI now has readable model choices, explicit runtime/model setup, download information, a resident-model Unload button and a separate advanced server section. History preserves every successful capture and translation error, supports source/translation/pinyin search, favorites, and bounded local learning recaps. Old history and dictionaries decode without the new optional fields; corrupt files remain preserved.

## Current automated evidence

**28 Swift Testing cases pass.** [Raw output](kamihi-4.0-unit-tests.txt) covers shortcut registration/repeat, screen geometry, raster OCR word bounds, wrapped sentences and area punctuation, stale translation/save protection, source-cache invalidation, Chinese conversion, tone distinctions, failed persistence, legacy/corrupt files, bounded history recap context, Chinese example validation/persistence, and game state.

Game regressions include explicit checking before advancement, no double scoring, unknown choices, ambiguous meanings/pinyin, repeated builder tiles and undo, hint scoring, self-pair rejection, blocked third flips, mismatch recovery, all-pair completion, language isolation and unchanged dictionary/review files. The runtime helper and native acceptance script also passed Python compilation. A clean-machine runtime download/install was not performed.

## Actual installed-app checks

Acceptance used isolated fixture data. Personal learning data was not mixed into screenshots or public test logs.

- **Option–Space over image-only `Control`** selected the raster word, translated to **控制**, and displayed **kòng zhì**, without opening the full app. The result included **我控制着这辆车的速度。**, system sentence pinyin, and **I control the speed of this car.** The example was produced by the real installed 2B local model and translated by Apple Translation.
- Save created a Chinese dictionary headword with context and the three example lines. My words → 控制 opened the persisted detail. Done dismissed its sheet. Chinese playback was invoked; physical audio quality is not certified.
- **Control–Space** selected `Control the volume, please.` and translated to **请控制音量。**
- **Control–Option–Space** dragged a controlled mixed-language region. Its final result was `我喜欢学习中文。`, `请控制音量。`, `我们一起喝咖啡。`, in that order. Existing Chinese lines were retained. Escape cleared the result and all overlays.
- Whole-display Space selection passed in the preceding session using the same capture workflow; it was not repeated in this final capture pass. Geometry tests cover negative origins; final physical acceptance used one Retina display.
- A physical pointer click on the empty trailing edge of the Play sidebar row opened Play. Full and compact playground layouts were visually inspected. Compact provides More sections; the full workspace has a minimum width of 760 points.
- **All seven games completed full native UI rounds**, including an intentional wrong meaning, listening transcript hints, word reconstruction and both matching boards. The saved vocabulary/review JSON hash remained unchanged. [Raw game results](kamihi-4.0-native-games.txt). The explicit driver scopes actions to a front sheet and actionable controls, avoiding a prior test-helper error where background static text shared a quiz answer label.
- A real local recap completed and persisted references to 15 isolated history entries. Navigation to Local AI remained available while generation was active. Unload then released the worker and kept downloaded weights. Model factual quality is not certified.

The exact word result is visible in [the cursor screenshot](../screenshots/v4-word-result.png), with [area translation](../screenshots/v4-area-result.png), [Play](../screenshots/v4-playground.png), [compact Play](../screenshots/v4-compact-playground.png), and [Local AI](../screenshots/v4-local-ai.png). These are actual native screenshots.

## Delivery

Strict signature verification passed on the built, installed and read-only mounted DMG apps. Complete bundle file hashes matched across all three; the DMG contains the Applications symlink. [Delivery record](kamihi-4.0-delivery.json) includes the package SHA-256. Original personal vocabulary, history and chat JSON hashes were unchanged throughout isolated acceptance. The normal installed process was reopened without test arguments and the Chinese preference was verified.

The DMG contains the native app and setup helpers, with no model weights or Python interpreter. Fresh machines need compatible Python/venv or a configured local server for AI features; Apple Translation may request language packs. Games and Apple Translation are independent of the AI runtime. The public GitHub release is marked as a prerelease, keeping the stable Chrome extension release separate.

## Practical limits

OCR cannot guarantee very small, stylized, low-contrast or protected text. Single Latin words can be ambiguous; use Translate from for Polish, Vietnamese or another supported intended source. Local AI sentences and recaps can be inaccurate, and system transliteration is not a reviewed pronunciation dictionary. Missing/busy models expose a retry message rather than fabricated examples. Speaking practice recognizes words and does not score Mandarin tones or accent. No broad VoiceOver, human microphone, mixed-DPI, clean-machine installation, all-language-pair or lower-memory-device certification is claimed. No bug-free claim is made.
