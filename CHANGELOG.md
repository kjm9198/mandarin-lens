# 2.1.1 · 30 October 2026

## Kamihi Lens 4.2.0 — easier selection and translation controls

- Switch Word, Sentence and Section directly in the screen selector. Drag a section from any mode; click a sentence to capture its full text.
- Visible From/To pickers, Swap, selected-strategy offline readiness and language preparation.
- Natural/Fast requests for Apple Translation, with system fallback and macOS 15 compatibility. The Qwen study model remains separate.
- Section translation respects the chosen source, rejoins likely wrapped sentences, and matches batch results by identifier.
- Cached results distinguish source preference and translation mode.

## Kamihi Lens 4.1.0 — native design update

- Shared adaptive paper, charcoal and Kamihi teal palette, system typography, branded sidebar and compact toolbar.
- Rebuilt translation workspace, dictionary, history, local-model settings, learning recap and chat presentation.
- More compact practice selection, clear answer states and fixed Check/Continue controls.
- Smaller cursor results with prominent Chinese and pinyin; character exploration lives in the action bar.
- Compact prioritizes the current translation and keeps source editing in an expandable section.
- Saving through the full save sheet preserves the bilingual example and captured context, including the correct source-language meaning target.

## Kamihi Lens 4.0.0 — native macOS preview

- Word, sentence and screenshot-area selection with immediate cursor results, Chinese pinyin, Listen, Copy and Save.
- Chinese-first translation, explicit translation/source settings, a fix for ambiguous short English words such as Control, and persisted example sentences with Chinese, English and pinyin.
- Mixed-language area translation preserves line order and already translated-language lines.
- Searchable history for each capture, favorites and local AI learning recaps.
- Dictionary detail, refreshed local-model setup/download screens and resident-model unload.
- Full-width sidebar click targets and seven vocabulary games inspired by Sproutsly: meaning, reverse recall, listening, word building, pair matching, memory and pinyin.
- Isolated native acceptance, game-state regression coverage and signed DMG packaging. This development preview is not notarized.

- Showcase whole sentences by buffering streaming captions into complete sentences/clauses; eliminate 1-word expanding jitter.
- Hover protection keeps subtitle and definition cards open during inspection; pause video on hover so words can be studied comfortably.
- Fixed video prompt choices closing Mandarin Lens on YouTube SPA navigation; added dismissible '×' button and compact pill mode.
- Redesigned extension popup with modern card-based hierarchy, subtitle style presets, and expanded settings.
- Start the YouTube CC feed automatically instead of requiring a manual CC toggle.
- Replace native YouTube subtitle text while displaying Mandarin Lens captions; preserve the source caption DOM.
- Save automatic-CC and replacement preferences, with native-caption restoration on failure, opt-out and stop.
- Distinguish waiting for speech from a video without an available CC track.

# 2.1.0 · 30 October 2026

- Automatic per-video YouTube choice: Learn once, Always here, Skip video and Off here.
- Persistent per-website Ask/Always/Off and optional pause while asking; individual optional website grants.
- Reopen control, same-tab video changes, existing local-model auto-start and preserved live customization.
- First-time translation still requires Chrome model activation; no audio transcription or universal compatibility claim.

# Changelog

## 2.0.0 — 29 October 2026

- Integrate PR #1: beginner segmentation, punctuation on Hanzi, explicit Context, accessible compact actions and preparation layout. Ordinary clicks now select words; Alt-click selects characters.
- Licensed 6,500-headword CC-CEDICT subset, traditional aliases, numbered-tone conversion, additional polyphonic overrides and optional limited phrase tone changes.
- Watch/Learn preferences, click-only lookup, optional resume, line spacing, alignment, outline/shadow, local-voice speed/repetition and popup Stop.
- Reuse aligned bilingual subtitle files without a model. Finite slow sentence replay restores speed. Shadowing pauses for practice and hides/reveals English without recording or scoring speech.
- Vocabulary sorting, recent/known states, bounded review history and five offline practice formats; preserve legacy words.
- Event-driven, sender-validated persistence worker serializes multi-tab changes; revision tokens reject stale saves after deletion/cache clearing. No new permissions, network code, tracking or capture.
- Offline transcription is clearly disabled pending a packaged, measured recognizer. See V2 reports for actual checks and untested cases.

## 1.3.0 — 29 October 2026

Redesigned the video overlay around compact subtitles. Word explanations are small anchored popovers outside the subtitle layout; hover has no action row or context, pinning reveals compact actions, and context expands only on request. Replaced the permanent branded toolbar with one explicit ··· control. Added smaller/lighter 12/18/12 subtitle defaults, transparent background and tighter spacing, with one-time migration of exact old defaults that preserves custom choices and vocabulary. Verified fixed subtitle geometry with hover/pin and bounded popovers at narrow viewport widths.

## 1.2.0 — 28 October 2026

Prefer the main visible video over hidden or small players, prioritize fullscreen and playback, and filter live native caption tracks by source language and kind. Invalidate prepared/imported captions on media element/source changes even when the page URL stays the same. Restore a visible retry action after live/model preparation failure while preserving completed preparation lines. Clear obsolete caption warnings when captions return. No new permissions, services or dependencies.

## 1.1.0 — 28 October 2026

Added sentence looping for prepared captions, with a visible active state and automatic release when seeking outside the selected sentence. Replay now respects the timing offset. Escape dismisses word explanations, settings and transcripts with keyboard focus restored. Prepared caption storage usage is visible, and a cache-only clear keeps vocabulary and display preferences. Pausing/canceling preparation checkpoints completed lines immediately; canceled in-flight work cannot append to that checkpoint. Cache eviction no longer counts discarded records against the remaining storage budget.

## 1.0.0 — 28 October 2026

Compact customizable learning overlay and popup; independent subtitle layers and sizes; positioning/drag, presets, opacity, blur, fonts, spacing and tone colors. Hardened parsers and phrase-aware polyphonic readings. Pause/resume/cancel preparation with bounded local checkpoints, timestamp synchronization and searchable transcript. Vocabulary editing/import/backup/export and optional interval reviews. Narrow permissions, explicit CSP, safe text rendering, local data deletion and improved async cleanup. Added reproducible tests, security/privacy documentation, deterministic ZIP packaging and free GitHub distribution.

This release does not add audio transcription, guarantee translation accuracy or claim Chrome Web Store review. Detailed test and feature limitations are documented in README and reports.

## 0.4.0 — supplied baseline

Existing local translator, subtitle overlay, pinyin map, SRT/VTT preparation and basic vocabulary. Supplied directory had no Git history, automated test suite, package tooling or release documentation, so no historical passing-test claim is made.
