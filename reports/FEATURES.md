# Version 1 feature status

Added in 1.2: visible-player selection, live caption language/kind filtering, same-URL media invalidation and local model retry/resume.

Added in 1.1: sentence looping, Escape dismissal, prepared-cache usage and cache-only clearing, plus immediate pause/cancel checkpoints.

Implemented: compact popup/overlay, independent appearance controls and reset, title dragging, reduced-motion/contrast preferences, two translation directions using Chrome's local API, native/live YouTube caption detection, SRT/VTT imports, accessible transcript preparation with pause/resume/cancel and local checkpoints, timed display/replay/search, phrase-aware pinyin, small offline glossary, locally reported pronunciation voices, local vocabulary and interval reviews, editing/import/export/backup, deletion, release tooling and free GitHub ZIP distribution.

Limitations: compatibility and performance vary by browser/device/site; caption completeness is estimated. Pinyin fallback and glossary are limited. No speech recognition, audio capture, automatic language conversion, HSK estimates, zhuyin, semantic grammar tutoring, system reminders, automatic updates or Chrome Web Store distribution. See README and TESTING.md for the exact evidence; version 1 does not imply every optional item in the original aspirational development prompt is complete.

Simplification: no account, backend, paid API, npm runtime dependency, global host permission, always-on injection, or model weight in the ZIP. Advanced settings and transcript stay closed until requested.
