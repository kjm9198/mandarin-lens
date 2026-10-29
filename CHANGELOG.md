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
