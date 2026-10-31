# Kamihi Lens 4.3 — Notepad and bilingual playback

The result panel groups five equal actions: Original, Translated, Copy, Save and Notepad. Original and Translated use the corresponding language, switch to Stop during playback, and return to Play on completion. A shared speech controller stops the previous utterance when another is selected and ignores stale cancellation callbacks. Dismissing/changing a result stops speech. Mainland/Taiwan Mandarin voice selection avoids a generic Chinese fallback selecting Cantonese. No speech runtime initializes until it is needed.

Notepad is a new top-level workspace section. It stores multiple notes locally, supports title/content search, pins, short Markdown/checklist preview, writing/journal/checklist templates, a writing-focus layout, recoverable Recently deleted notes and Markdown export. The floating window opens via Control–Option–N, a toolbar button or the menu. Escape/hotkey hides it; a global quick note returns focus to the previous app, while a note opened from the workspace returns to that workspace. The app reports shortcut conflicts instead of changing macOS shortcuts.

The translation action captures both texts plus available Chinese pinyin, examples and source context. Recall hides the answer until revealed; the list preview also excludes the translation to prevent spoilers. Translate note reuses the existing translator, capped at 16,000 characters. These practice helpers do not award a streak, change review dates or require an AI request.

Notes are debounced to an atomic local JSON save, with flush on exit. A failed save retains the text and offers retry. Unreadable stores are preserved. Moving a note to Recently deleted is reversible; no permanent-delete action or cloud sync is introduced. The floating/multiple-note workflow is inspired by [Raycast Notes](https://manual.raycast.com/notes); the interface and storage are Kamihi’s own.

## Validation

The 34 Swift tests pass, including new coverage for Unicode/pins, note restore, rapid edit flushing, checklist round trips, corrupted-file preservation, retry after a file-system failure, bilingual example/context capture, duplicate capture prevention and non-spoiling note previews. Actual native UI checks are recorded separately from these model tests.

This is a signed Apple Silicon/macOS 15+ preview, not notarized. Installed voice availability and the speech framework are checked on this Mac; physical speaker/headphone audibility and all hardware/OS combinations are not certified. The translation engine and game scoring engine remain unchanged.


## Installed-app evidence

- [Native acceptance](kamihi-4.3-native-acceptance.txt): original/translated Play–Stop, language switching, natural completion, bilingual capture, edits/search/pins/checklists, reversible deletion, templates, restart persistence, Recall and global-note focus return.
- [Seven completed game rounds](kamihi-4.3-games.txt), with vocabulary and review data unchanged.
- [34 Swift tests](kamihi-4.3-unit-tests.txt).
- [Measured result controls](kamihi-4.3-action-frames.json): all five are 53 points high including the border; width differs by at most 0.5 point from pixel rounding in the equal-width layout.
- Reviewed screenshots: [bilingual playback](../screenshots/v43-bilingual-playback.png), [dark Notepad](../screenshots/v43-notepad-dark.png), [390-point floating Notepad](../screenshots/v43-floating-notepad.png).

GUI checks used an isolated profile and public fixture text, not personal notes. Export compiles and uses the native save panel; a completed export interaction was not separately exercised. Delivery verification is recorded in [the package report](kamihi-4.3-delivery.json).
