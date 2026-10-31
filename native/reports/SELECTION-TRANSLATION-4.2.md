# Kamihi Lens 4.2 — selection and translation

## Easier capture

- Sentence: Control–Space, then click anywhere in the sentence. The button reflects Control–Shift–Space if chosen in Settings.
- Section: Control–Option–Space, then drag a rectangle around a paragraph or section. Space selects the whole display; Escape cancels.
- The selector itself has accessible Word, Sentence and Section buttons, plus Cancel. Keys 1/2/3 switch those modes. A drag from Word or Sentence also captures a section.
- Visible From/To pickers, Swap and an explicit Apple engine/mode control remove the need to find language settings elsewhere. Short Latin words prompt for a source choice because they are intrinsically ambiguous.

## Engine and quality

Fast is the default. On macOS 26.4 or later the app explicitly requests Apple Translation’s low-latency strategy. Natural requests high fidelity, which uses Apple Intelligence where available with system fallback. Earlier macOS versions retain the system framework. Apple manages the specific model; its API does not expose a named model/version or parameter count. The separately selected Qwen 3.5 2B 4-bit model is used for study examples, conversations and recaps, not these translations.

Sources: [Apple strategies](https://developer.apple.com/documentation/translation/translationsession/strategy), [high fidelity behavior](https://developer.apple.com/documentation/translation/translationsession/strategy/highfidelity), [configuration and fallback](https://developer.apple.com/documentation/translation/translationsession/configuration/init(source:target:preferredstrategy:)).

The section pipeline now honors an explicit source, rejoins likely wrapped sentence lines while keeping list items and short headings separate, and maps batch responses by client identifier. History caches distinguish mode and source selection. Chinese script conversion remains a local transform.

The controlled benchmark uses two public travel/scheduling sentences per directed pair among English, Polish, Vietnamese, Simplified Chinese and Traditional Chinese. It checks installed models only and excludes UI, OCR and downloads from timing. Direct Chinese script pairs use the app’s local conversion instead of the translation API.

Natural completed 36 API translations with a median of 418.5 ms (351–1036 ms). Inspection found substantive errors: Polish “dziewiętnastą” became nine o’clock, Vietnamese seven in the evening became seventeen in Polish, and some Chinese-to-Polish table quantities changed. These are failures, not passing quality evidence. Fast completed the same 36 API translations with a median of 126 ms (22–479 ms), after all language packs had finished preparing. It rendered the Polish hour as seven instead of nine (but omitted an explicit evening indicator), preserved the Vietnamese evening hour, and ran more quickly. This supports the default choice while leaving precision limits visible. This is a small smoke test, not proof of universal translation accuracy. Natural remains an optional alternative.

Evidence: [Natural output/timing](kamihi-4.2-natural-benchmark.json), [Fast output/timing](kamihi-4.2-fast-benchmark.json), [30 passing Swift tests](kamihi-4.2-unit-tests.txt). Regression checks cover explicit-source sections, sentence wrapping/list boundaries, mode cache invalidation and language swapping, alongside existing persistence/capture/game checks.

## Delivery

The app remains an Apple Silicon macOS 15+ signed development preview, not notarized. Language availability is checked for the selected strategy: Natural readiness does not establish that Fast packs are installed. Prepare languages uses Apple’s system download sheet; completed packs are shared across macOS apps. No text is sent to a new external translation provider.

## Installed-app checks

The final installed build passes explicit Polish “kawa” → English “Coffee”, English → Vietnamese, Swap followed by back-translation, Word → Sentence toolbar switching with full sentence capture, dragging a mixed-language section from Word mode, and the Section shortcut followed by Space for the whole display. The output order remains intact. The desktop layout keeps longer translations beside the source; compact was reviewed at 390 × 560 points. [Native acceptance](kamihi-4.2-native-acceptance.txt).

Screens: [English → Vietnamese](../screenshots/v42-english-vietnamese-dark.png), [compact language controls](../screenshots/v42-compact-dark.png), [screen selector](../screenshots/v42-selection-toolbar.png).

Fast language packs for English, Polish, Vietnamese and both Chinese scripts were prepared with Apple’s system UI on this Mac, then verified by the full 36-translation matrix. The two direct script-conversion directions remain handled locally by the app. Other machines may need their own downloads.

The build, installed app and read-only mounted DMG match file-for-file and pass strict signature checks. All three original personal JSON stores stayed unchanged during isolated acceptance. [Delivery checks](kamihi-4.2-delivery.json).
