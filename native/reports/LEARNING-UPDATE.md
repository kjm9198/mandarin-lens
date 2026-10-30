# Saved-word learning update — 30 October 2026

Installed app: `~/Applications/Mandarin Lens.app`. Private development DMG: `native/build/MandarinLens-dev.dmg`. Build 4, version 3.0.0; ad-hoc signed, not notarized. The DMG requires separately installed Apple language packs and, for AI, the local MLX runtime/model or a compatible local server.

## What changed

Words is now a dedicated personal dictionary. Save word lets you choose one token from the original or translated sentence, translate that token separately, edit the meaning and save. It avoids storing a sentence translation as the meaning of an individual word and restores the original sentence afterward. Duplicate entries are blocked without folding Vietnamese tone marks together.

New saves get an immediate local keyword-based category suggestion; unknown items remain Unsorted. Categorize all uses the selected local AI in bounded batches, accepts only known category names for supplied word IDs, preserves manual category choices and retains completed batches on interruption. Categories remain editable. Added category filters, search, local JSON export, installed-voice pronunciation and a simple spaced-review flow.

Chinese support includes Simplified/Traditional target choices, Hanzi, system pinyin and model-generated example sentences with tone-mark pinyin. Pinyin is system transliteration, not a verified polyphonic or tone-sandhi dictionary. Explain-in preferences include English, Vietnamese, Polish and Chinese. The question-mark button opens a four-step tutorial, also shown to new installations.

The model chooser discovers installed MLX folders and downloaded GGUF catalogue entries. This machine yielded three MLX folders plus one GGUF entry. Automatic uses the small model for conservative 16–24 GB profiles and the tested 9B model on this 48 GB Mac. Larger custom models are optional and unverified. LM Studio/Bionic connections are limited to loopback; optional API tokens use Keychain. No large model downloads were added in this update.

## Verification performed

On this Apple M5 Pro, 48 GB unified memory, macOS 27:

- Native compile, ad-hoc signing and actual app launch. Mounted the final DMG read-only, checked the executable app bundle and its signature, detached it, and verified that the installed executable SHA-256 matches the build.
- Real Apple Translation: English → Simplified Chinese, then 你好 → Hello. Earlier English → Vietnamese/Polish checks are retained; other pairs, including Traditional Chinese, remain unverified.
- Native UI actions followed by accessibility-state inspection: opened Save word, chose 你好 from a sentence, translated it separately, saved it, confirmed it in Words, opened Review and revealed its meaning. Retesting duplicate save left one entry and restored the original sentence/target after dismissal.
- Native Categorize all completed on the saved entry. Separate real-model test categorized temporary test words and preserved a manual category.
- Native model chooser switched to the small model and back to Automatic. Native Example & usage generated an actual Hanzi/pinyin example from the saved word.
- All four tutorial steps advanced, completion dismissed the sheet, and the question-mark button reopened step one.
- Smoke assertions cover duplicate prevention, Chinese pinyin/segmentation/category suggestion, Vietnamese tone distinction, persistence, owner-only file permissions, review scheduling, manual categories, corrupt-file preservation, rejection of unknown category IDs/names, discovery, port validation and inference cancellation. Logs are adjacent to this report.
- OpenAI-compatible discovery/completion tested using an explicit local mock server (`local-api-fixture.txt`). The actual LM Studio endpoint returned an authentication requirement. Authenticated real LM Studio/Bionic inference is not claimed.
- Direct model tests ran under `sandbox-exec` with `(deny network*)`. The synthetic image OCR sentence/no-text checks from the capture milestone remain separate evidence.

## Actual local-model samples

Single fresh-subprocess samples, with OS network access denied; these are not p50/p95 benchmarks or full RAM/battery measurements:

| Installed candidate | First text | Total | Assessment of this sample |
| --- | ---: | ---: | --- |
| Qwen 3.5 2B 4-bit MLX | 2.01 s | 2.10 s | Recognized 银行 and produced pinyin; added a questionable loanword claim. Fast candidate with limited quality. |
| Custom Qwen 3.5 9B MLX | 5.82 s | 6.06 s | Useful bank explanation and Chinese example with English translation. Chosen for Automatic on this machine. |

The 9B model also returned short Vietnamese and Polish explanations for 谢谢 with network access denied. Outputs are in `multilingual-9b.txt`; they are small samples, not human-reviewed language certification. The Polish sample has a minor grammatical error. No 16 GB Mac or 27B/31B model inference was tested. Disk footprint does not establish peak unified-memory use.

## Screenshots from the running native app

- [Chinese translation and pinyin](../screenshots/chinese-learning.png)
- [Choose one word and its meaning](../screenshots/save-single-word.png)
- [Saved Chinese word and category](../screenshots/saved-chinese-words.png)
- [Review card with revealed meaning](../screenshots/word-review.png)
- [Model chooser populated from local files](../screenshots/model-chooser.png)
- [First-run tutorial](../screenshots/first-run-tutorial.png)
- [Real usage explanation from saved vocabulary](../screenshots/word-example-chat.png)

During inspection, fixed the Save word action being too low in the scroll area, stale sheet initialization and original-sentence state changing during word lookup. Existing screenshots from earlier milestones remain historical evidence.

## Reproduce

From the repository root:

```sh
native/build.sh
# Optional: create a private DMG with app bundle and Applications shortcut
native/package.sh
xcrun swiftc -target arm64-apple-macos15.0 -parse-as-library native/Sources/MandarinLens/LocalModels.swift native/Sources/MandarinLens/Vocabulary.swift native/Tests/FeatureSmoke.swift -framework AppKit -framework NaturalLanguage -framework Security -o /tmp/lens-feature-smoke
/tmp/lens-feature-smoke
python3 native/Tests/api_fixture.py
sandbox-exec -p '(version 1)(allow default)(deny network*)' /tmp/lens-feature-smoke --inference
sandbox-exec -p '(version 1)(allow default)(deny network*)' /tmp/lens-feature-smoke --inference --small
sandbox-exec -p '(version 1)(allow default)(deny network*)' /tmp/lens-feature-smoke --categorize
sandbox-exec -p '(version 1)(allow default)(deny network*)' /tmp/lens-feature-smoke --cancel
```

The smoke runner uses temporary vocabulary files and deletes them afterward. The native UI walkthrough saved one useful starter entry, 你好 → Hello, in the user's dictionary. Cross-app word capture, permissions, multi-monitor screen OCR, speech playback and full accessibility acceptance still need dedicated validation. Private mode, Chrome integration and launch-at-login remain outside this delivered update.

References for the optional external-server adapter: [LM Studio local server](https://lmstudio.ai/docs/developer/core/server) and [offline operation](https://lmstudio.ai/docs/app/offline).
