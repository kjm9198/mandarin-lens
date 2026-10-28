# Changelog

## 1.1.0 — 28 October 2026

Added sentence looping for prepared captions, with a visible active state and automatic release when seeking outside the selected sentence. Replay now respects the timing offset. Escape dismisses word explanations, settings and transcripts with keyboard focus restored. Prepared caption storage usage is visible, and a cache-only clear keeps vocabulary and display preferences. Pausing/canceling preparation checkpoints completed lines immediately; canceled in-flight work cannot append to that checkpoint. Cache eviction no longer counts discarded records against the remaining storage budget.

## 1.0.0 — 28 October 2026

Compact customizable learning overlay and popup; independent subtitle layers and sizes; positioning/drag, presets, opacity, blur, fonts, spacing and tone colors. Hardened parsers and phrase-aware polyphonic readings. Pause/resume/cancel preparation with bounded local checkpoints, timestamp synchronization and searchable transcript. Vocabulary editing/import/backup/export and optional interval reviews. Narrow permissions, explicit CSP, safe text rendering, local data deletion and improved async cleanup. Added reproducible tests, security/privacy documentation, deterministic ZIP packaging and free GitHub distribution.

This release does not add audio transcription, guarantee translation accuracy or claim Chrome Web Store review. Detailed test and feature limitations are documented in README and reports.

## 0.4.0 — supplied baseline

Existing local translator, subtitle overlay, pinyin map, SRT/VTT preparation and basic vocabulary. Supplied directory had no Git history, automated test suite, package tooling or release documentation, so no historical passing-test claim is made.
