# Release validation — 1.0.0

28 October 2026. Tested locally on macOS arm64, Apple M5 Pro. No real beta participants were recruited. The supplied v0.4 directory contained no tests or package tooling; baseline automated results were unavailable.

## Pure engine tests

`npm test`: 12/12 tests passed. Covers hostile/malformed input bounds, inherited object properties, polyphonic phrase readings, fallback segmentation, SRT/VTT clocks/metadata, cue validation, oversized imports, gaps/overlaps/seeks, source-language selection, versioned cache keys and completeness estimates. Curated pinyin assertions are developer-authored; they are not an independent bilingual evaluation.

## 10,000 synthetic engine journeys

`npm run simulate`: 10,000/10,000 assertion-successful seeded synthetic journeys. These exercise Node engine branches, not 10,000 browsers or humans. The seed and raw results are in `tests/simulation-results.json`.

- 2,662 timed-caption journeys, including 53,240 timestamp checks.
- 2,635 live-caption fallback branches.
- 2,727 no-caption fallback branches.
- 1,976 model-unavailable fallback branches.
- 664 interruptions across those journeys.

A correctly chosen fallback is not a successful translation. Node lookup timing, CPU time and heap figures in the JSON measure only this script, not video playback or translation. No satisfaction scores or invented feedback were generated.

## Packaged MV3 browser integration

`npm run test:browser`: 11 checks passed on Chromium 156.0.8078.4; zero page errors. The harness builds the release ZIP, extracts it to a disposable profile, then adds test-only localhost host access and an inert service worker for discovery. It verifies the original manifest/ZIP were not modified. These test grants replace the manual toolbar activeTab permission gesture; that toolbar installation/activation path is not proven by this automation.

Actual chrome.storage.local persists settings/presets; popup has no overflow at 360px. Canceling deletion keeps settings; confirmed deletion clears storage and closes an active overlay. Actual injected isolated-world content scripts import a real SRT file, prepare and synchronize captions, keep malicious text inert, expose timed transcript navigation and clean up their host when closed. Unsupported-API messaging is also tested.

This integration test deliberately substitutes a Translator double. It verifies extension behavior and text rendering, not actual translation quality. The real Translator API separately reports downloadable support in that Chromium environment. Screenshots are labeled by their actual source and model status.

## Real Chrome language-model test

`node tests/real-model.cjs` was run after explicit owner consent for language-pack downloads. Actual installed Google Chrome 156.0.8078.48 used a disposable profile on Apple M5 Pro, macOS arm64, 48 GiB system memory. Chrome downloaded a real language pack and translated five original short sentences per direction. All ten yielded nonempty translations. No service API key, cloud translation endpoint or mock was used.

| API-only sample | Model creation | p50 translation | Sample p95 translation | Sequential short-sentence throughput |
| --- | ---: | ---: | ---: | ---: |
| English → Chinese, n=5 | 13.19 s, includes initial download | 2.8 ms | 13.7 ms | 155.8 sentences/s |
| Chinese → English, n=5 | 56.4 ms, reused browser pack | 2.5 ms | 11.8 ms | 245.1 sentences/s |

For five samples, nearest-rank p95 is simply the maximum. These tiny API measurements exclude caption discovery, rendering, video scheduling, diverse language input and long-session behavior. They must not be advertised as general latency or accuracy guarantees. Examples: “The bank is next to the school.” → “银行就在学校旁边。”; “我明天还书。” → “I will return the book tomorrow.” There was no independent bilingual adequacy grading.

CDP page JS heap was about 2.45–2.56 MB during this fixture. It excludes native/model memory and other processes. TaskDuration/ScriptDuration are cumulative page CPU times, not playback CPU utilization. Total browser/model memory and sustained video CPU utilization remain unmeasured. Language-pack download size was not exposed by Chrome.

## Real model inside the packaged extension

`node tests/real-extension.cjs`: actual installed Chrome 156.0.8078.48 loaded the ZIP-derived extension in an isolated temporary profile through the official CDP Extensions.loadUnpacked method. The test copy adds the same explicit localhost grant and discovery worker; the shipped manifest remains unchanged. A real mouse click activated the extension's own Translator code; no model double was installed.

Six checks passed: real English captions prepared into Chinese with Hanzi/pinyin/original display; seeking the original local 12-second WebM to the second prepared cue displayed the matching translation; Chinese SRT import prepared through the real reverse language pair and displayed English while retaining Hanzi/pinyin; seeking showed the second English cue; overlay cleanup completed; original package and manifest were unchanged. Both language pairs were available afterwards. The fixture has only two caption lines per direction, and correctly reports partial-track coverage. This verifies those flows, not broad video-site coverage or an accuracy percentage. Raw records and actual screenshots are separate from the stubbed rendering tests.

Observed compatibility failures are retained as limitations: Chrome for Testing 156.0.8078.4 advertised a downloadable model but stalled without download progress. Fresh-profile installed Chrome attempts intermittently returned “Unable to create translator for the given source and target language”; the final successful run required two model-initialization retries, handled by the extension’s visible retry control. Chrome's model/device setup remains fallible and the extension offers retry/fallback messaging. A failed initial seek test was traced to the fixture server lacking byte-range handling; its server was fixed and real media seek readiness asserted before retesting.

## Static website

`node tests/site.cjs` with the local static server: no horizontal overflow at 390/768/1440px, privacy/security pages reachable, zero page errors. All scripts/fonts/images are local; no analytics. Screenshots show the actual extension on an original generated video fixture and disclose simulated model output where used.

## Source and package checks

`npm run check`: application syntax, exact minimal permission set, restrictive CSP, forbidden runtime network/execution sinks and selected credential patterns passed. This is not a full vulnerability scanner. Runtime has no npm packages to audit; test browser/OS/model supply chains remain external.

`npm run build`: explicit allowlist, root manifest, fixed ZIP timestamps, no test-only permissions/workers or development assets. SHA256SUMS.txt and package-report.json describe the final distribution. The final hash is recorded with the GitHub release. Repeated builds are compared for determinism.

## Remaining validation and beta work

A bounded public YouTube inspection returned HTTP 200 with playable video (Me at the zoo, 19.021 seconds), but CC reported subtitles unavailable and native text tracks were empty. This proves only that the chosen no-caption sample loads; it does not verify YouTube translation. Current captioned YouTube/Shorts compatibility, real browser toolbar activation, fullscreen/native picture-in-picture, offline restart behavior, screen-reader use, long videos, many simultaneous tabs, slow hardware and ±150ms rendered timing targets have not been comprehensively verified. No site-wide compatibility claim follows from local fixtures. Test 10–30 consenting real learners next, prioritizing these cases and genuinely observed translation/pinyin errors. Audio transcription is not implemented and is not advertised.

Final reviewed ZIP: `mandarin-lens-1.0.0.zip`, 169,418 bytes; SHA-256 `94e573223ecb1b03e7aa93ddea406904a0339857646954717d3e8664e4b9d597`. Both the stubbed integration harness and real-model extension harness tested this exact ZIP after extraction, with only the disclosed test-only manifest additions. Two deterministic builds matched before the final UI-only polish; the frozen final build also reproduces its published checksum.
