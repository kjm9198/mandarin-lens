# Mandarin Lens 2.0

Compact Chinese, pinyin and English learning captions for desktop Chrome. Free, local-first, open source. No account, analytics, subscription, server or API key.

[Download the ZIP](https://github.com/kjm9198/mandarin-lens/releases/latest) · [Website](https://kjm9198.github.io/mandarin-lens/) · [Report a bug](https://github.com/kjm9198/mandarin-lens/issues)

## Install locally or share with a friend

1. Download `mandarin-lens-2.0.0.zip` from the release and extract it into a permanent folder.
2. In desktop Chrome open `chrome://extensions`, enable **Developer mode**, choose **Load unpacked**, and select the extracted folder containing `manifest.json`.
3. Open a captioned video, turn on CC, click Mandarin Lens, then **Start learning**. On the video, press **Start learning** to authorize Chrome's local language pack. This second click is required for Chrome's model activation.
4. Chrome may download a language pack. Its size is controlled by Chrome and is not included in this ZIP. Availability depends on your browser, device and language pair.

Send the same ZIP to someone else; they follow the same steps. No Chrome Web Store account or fee is needed. This is an unpacked extension, not a Chrome Web Store reviewed or automatically updated installation. Managed browsers may prohibit unpacked extensions. Keep the extracted folder; deleting it breaks installation. For updates replace its files and press **Reload** on the extensions page, then refresh video tabs. Back up vocabulary first. Chrome 138+ desktop is the API baseline, not a guarantee of model availability; mobile Chrome is not supported.

## What changed

Version 2.0 integrates PR #1 and adds Watch/Learn modes, click-only lookup, optional resume after word dismissal, bounded contextual notes, a licensed offline lexicon, and traditional lookup. The first screen stays small; interaction/playback preferences live in expandable sections. Alt-click a character for a secondary lookup; ordinary clicks select the full segmented word. Arrow keys move between focused words and Escape dismisses details.

Import **two aligned files together**, one Chinese and one English SRT/VTT, to reuse bilingual captions without translation. Pairing tolerates 350 ms start / 500 ms end differences, reports matched versus total lines and omits unmatched lines. One-file import follows the translation preparation workflow. Language detection is a basic Hanzi heuristic; check the result. Already bilingual HTML tracks are not automatically paired.

Sentence replay uses your selected 1/2/3 repetitions and 0.5×/0.75×/1× speed, then restores the original speed. Continuous loop remains separate. Shadow listens once, pauses at the caption end with English hidden, and offers Reveal English / Continue. It records no speech and does not assess pronunciation. Local-voice speed and repetitions are configurable.

Vocabulary adds a marked-known state, recent filter, sorting, bounded review history and flashcards, meaning matching, pinyin recall, listening recall and sentence recall. Listening needs a browser-reported local Mandarin voice; sentence recall needs a saved example. A simple interval schedule is transparent, not a validated learning-outcome claim. JSON backups preserve the metadata; old vocabulary is retained.

Version 1.3 replaces the large inline word card with a small anchored popover outside the subtitle layout. Hover shows only the word, pinyin and meaning; clicking reveals compact actions, with sentence context behind a separate control. The permanent branded toolbar is replaced by a small **···** button. Hovering captions never reveals the toolbar. Compact defaults reduce font weight, spacing and background shading. Exact previous default appearances migrate once; custom sizes and saved words are preserved.

Version 1.2 improves main-player selection on multi-video pages, excludes wrong-language and metadata tracks from live subtitles, invalidates old captions when the media source changes at the same URL, and restores a visible retry path after local translation failures. Prepared progress is retained after model failure.

Version 1.1 adds sentence looping, Escape-to-dismiss panels, storage usage, cache-only clearing that preserves saved words/settings, and immediate checkpoints when pausing or canceling preparation. Click the loop button beside replay after preparing captions; seeking outside that sentence stops the loop. Replay and looping respect your caption timing offset.

- Smaller 336px popup, collapsed advanced settings and compact subtitle defaults: Chinese 12px, pinyin 18px, English 12px, transparent background.
- Independent font sizes, layer visibility, font choice, word spacing, opacity, background blur, tone colors, timing offset and position. Open the ··· controls and drag the strip's label to reposition it, or use sliders and Reset appearance.
- Compact, Comfortable and Learning presets; accessible keyboard focus and reduced-motion/contrast preferences.
- English↔Chinese local browser translation, with stale-result suppression and a timeout retry path.
- Prepare accessible native caption tracks, the visible YouTube transcript panel, or imported SRT/VTT before playback. Pause/resume/cancel, line progress and resume checkpoints. Only available captions are prepared; completeness is an estimate.
- Prepared captions follow video time and support seeking, replay and a searchable transcript (200 results at a time).
- Up to three recent prepared-caption records target approximately 4 MB in extension-local storage. Identity is hashed; no full browsing URLs are stored in cache keys. A serialized storage worker enforces the application cache limits across tabs.
- Phrase-aware pinyin for common polyphonic words, ICU character fallback and browser word segmentation.
- Local vocabulary, search/edit, CSV/JSON import, CSV/Anki TSV export, JSON backup and optional interval reviews.
- Delete all learning data closes active overlays and clears preferences, vocabulary and prepared cache.

## Honest limitations

No audio transcription or tab capture is implemented. Videos without readable captions need a matching subtitle file. The extension does not bypass DRM, access restrictions, authentication or rate limits. YouTube Shorts, current YouTube transcript markup, fullscreen, picture-in-picture, long-video performance and all desktop devices are not universally certified. Cross-origin embedded video frames are not injected.

The offline lexicon includes 6,500 selected CC-CEDICT headwords and traditional aliases, with attribution and ShareAlike terms for dictionary data. This is a bounded selection, not the full dictionary or an HSK frequency list. Curated context notes cover only a few recognizable patterns and disclose other contexts as unsupported. Pinyin combines dictionary readings, phrase overrides and character fallback; names and unfamiliar contexts can be wrong. Tone changes cover only listed common phrases, not full prosody. HSK classification, zhuyin and reminders are not implemented. Review choices are a simple documented interval schedule, not validated retention claims. No full speech or translation models are bundled.

The release test report distinguishes actual Chromium extension behavior, simulated translation output and 10,000 synthetic engine journeys. Real Chrome on this Mac also passed both translation directions, preparation and seeking on original local video fixtures; short API timings and observed model-initialization retries are recorded in the test report. Broad translation quality and long-run playback CPU/memory remain unverified; do not infer them from passing synthetic tests.

## Development

Runtime has zero npm dependencies; no build tool or network service is needed to use the extension.

```sh
npm test
npm run simulate
npm run check
npm run build
npm run test:browser
```

Packaging needs Python 3. Browser tests need the `playwright` npm package and a compatible installed Chromium (`npm install --no-save playwright`, then `npx playwright install chromium` if unavailable). They can use the Codex bundled runtime when present. `CHROMIUM_EXECUTABLE` can point to an existing compatible Chromium. Tests use a disposable profile with test-only localhost permissions and an inert discovery worker, never the user's browser profile. See [testing report](reports/1.3.0-TESTING.md).

Build output: `dist/mandarin-lens-2.0.0.zip`, unpacked `dist/mandarin-lens/`, SHA-256 checksums and a package inventory. The ZIP uses an explicit file allowlist and fixed timestamps. Run the build twice to verify deterministic output. Source stays readable; no minification hides behavior.

## Project layout

- `content.js`: isolated subtitle overlay, browser translation lifecycle, preparation and local caching.
- `core.js`, `preprocess.js`, `data/pinyin.js`: pure language helpers, timed sources, parsers and bundled readings.
- `popup.*`, `vocabulary.*`: extension controls and local learning data.
- `tests/`: unit tests, seeded synthetic journeys and real Chromium harness.
- `website/`: static project site, no analytics or runtime dependencies.
- `scripts/`: static checks and deterministic packaging.

[Privacy](PRIVACY_POLICY.md) · [Permissions](PERMISSIONS.md) · [Security](SECURITY.md) · [Threat model](THREAT_MODEL.md) · [Security review](docs/SECURITY_REVIEW.md) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Changelog](CHANGELOG.md)

Application code: MIT. Unicode-derived pinyin data: included Unicode license. The inherited generation version is unknown, as disclosed in third-party notices. Chrome's separately downloaded models and system voices are provided under their respective vendor terms and are not redistributed here.
