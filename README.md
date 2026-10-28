# Mandarin Lens 1.1

Compact Chinese, pinyin and English learning captions for desktop Chrome. Free, local-first, open source. No account, analytics, subscription, server or API key.

[Download the ZIP](https://github.com/kjm9198/mandarin-lens/releases/latest) · [Website](https://kjm9198.github.io/mandarin-lens/) · [Report a bug](https://github.com/kjm9198/mandarin-lens/issues)

## Install locally or share with a friend

1. Download `mandarin-lens-1.1.0.zip` from the release and extract it into a permanent folder.
2. In desktop Chrome open `chrome://extensions`, enable **Developer mode**, choose **Load unpacked**, and select the extracted folder containing `manifest.json`.
3. Open a captioned video, turn on CC, click Mandarin Lens, then **Start learning**. On the video, press **Start learning** to authorize Chrome's local language pack. This second click is required for Chrome's model activation.
4. Chrome may download a language pack. Its size is controlled by Chrome and is not included in this ZIP. Availability depends on your browser, device and language pair.

Send the same ZIP to someone else; they follow the same steps. No Chrome Web Store account or fee is needed. This is an unpacked extension, not a Chrome Web Store reviewed or automatically updated installation. Managed browsers may prohibit unpacked extensions. Keep the extracted folder; deleting it breaks installation. For updates replace its files and press **Reload** on the extensions page. Back up vocabulary first. Chrome 138+ desktop is the API baseline, not a guarantee of model availability; mobile Chrome is not supported.

## What changed

Version 1.1 adds sentence looping, Escape-to-dismiss panels, storage usage, cache-only clearing that preserves saved words/settings, and immediate checkpoints when pausing or canceling preparation. Click the loop button beside replay after preparing captions; seeking outside that sentence stops the loop. Replay and looping respect your caption timing offset.

- Smaller 336px popup, collapsed advanced settings and compact subtitle defaults: Chinese 14px, pinyin 22px, English 14px.
- Independent font sizes, layer visibility, font choice, word spacing, opacity, background blur, tone colors, timing offset and position. Drag the overlay's title to reposition it, or use sliders and Reset appearance.
- Minimal, Comfortable and Large presets; accessible keyboard focus and reduced-motion/contrast preferences.
- English↔Chinese local browser translation, with stale-result suppression and a timeout retry path.
- Prepare accessible native caption tracks, the visible YouTube transcript panel, or imported SRT/VTT before playback. Pause/resume/cancel, line progress and resume checkpoints. Only available captions are prepared; completeness is an estimate.
- Prepared captions follow video time and support seeking, replay and a searchable transcript (200 results at a time).
- Up to three recent prepared-caption records target approximately 4 MB in extension-local storage. Identity is hashed; no full browsing URLs are stored in cache keys. Cross-tab cache limits are best effort.
- Phrase-aware pinyin for common polyphonic words, ICU character fallback and browser word segmentation.
- Local vocabulary, search/edit, CSV/JSON import, CSV/Anki TSV export, JSON backup and optional interval reviews.
- Delete all learning data closes active overlays and clears preferences, vocabulary and prepared cache.

## Honest limitations

No audio transcription or tab capture is implemented. Videos without readable captions need a matching subtitle file. The extension does not bypass DRM, access restrictions, authentication or rate limits. YouTube Shorts, current YouTube transcript markup, fullscreen, picture-in-picture, long-video performance and all desktop devices are not universally certified. Cross-origin embedded video frames are not injected.

The local dictionary is a small curated beginner glossary, not CC-CEDICT. Missing entries are disclosed; optional word translation is not a contextual grammar explanation. Pinyin combines curated phrase overrides with character fallback and can be wrong for names or uncovered contexts. Traditional/Simplified conversion, HSK classification, zhuyin, semantic explanations, reminders and separate watch/practice modes are not implemented. Review choices are a simple documented interval schedule, not validated retention claims. No full speech or translation models are bundled.

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

Packaging needs Python 3. Browser tests need the `playwright` npm package and a compatible installed Chromium (`npm install --no-save playwright`, then `npx playwright install chromium` if unavailable). They can use the Codex bundled runtime when present. `CHROMIUM_EXECUTABLE` can point to an existing compatible Chromium. Tests use a disposable profile with test-only localhost permissions and an inert discovery worker, never the user's browser profile. See [testing report](reports/1.1.0-TESTING.md).

Build output: `dist/mandarin-lens-1.1.0.zip`, unpacked `dist/mandarin-lens/`, SHA-256 checksums and a package inventory. The ZIP uses an explicit file allowlist and fixed timestamps. Run the build twice to verify deterministic output. Source stays readable; no minification hides behavior.

## Project layout

- `content.js`: isolated subtitle overlay, browser translation lifecycle, preparation and local caching.
- `core.js`, `preprocess.js`, `data/pinyin.js`: pure language helpers, timed sources, parsers and bundled readings.
- `popup.*`, `vocabulary.*`: extension controls and local learning data.
- `tests/`: unit tests, seeded synthetic journeys and real Chromium harness.
- `website/`: static project site, no analytics or runtime dependencies.
- `scripts/`: static checks and deterministic packaging.

[Privacy](PRIVACY_POLICY.md) · [Permissions](PERMISSIONS.md) · [Security](SECURITY.md) · [Threat model](THREAT_MODEL.md) · [Security review](docs/SECURITY_REVIEW.md) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Changelog](CHANGELOG.md)

Application code: MIT. Unicode-derived pinyin data: included Unicode license. The inherited generation version is unknown, as disclosed in third-party notices. Chrome's separately downloaded models and system voices are provided under their respective vendor terms and are not redistributed here.
