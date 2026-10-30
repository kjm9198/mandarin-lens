# Mandarin Lens native development build

Build with Xcode's command line tools on Apple Silicon: `./native/build.sh`.
The result is `native/build/Mandarin Lens.app`. Copy it into `~/Applications` and open it. This is an ad-hoc signed private development build, not notarized.

The menu-bar icon opens a floating note that joins all Spaces. Its opacity slider, target language and Control/Option/Command lookup preference persist across launches. Tap the selected modifier and click accessible text in another app. One activation handles one click. Escape cancels lookup while the note has focus; arbitrary shortcut recording is not implemented yet. The Arm lookup button is an alternative activation.

Enable Accessibility using Allow access before using word capture. Selection is preferred; otherwise a bounded range around the clicked location is tokenized. Apps that do not expose the required Accessibility attributes need selected text or manual paste. Secure text fields are rejected. This is not universal capture.

English, Vietnamese and Polish targets use Apple Translation with automatic source detection. Apple controls supported pairs and installed packs; first use may require a language-pack download. Tested on this Mac: English → Vietnamese and English → Polish. Other directions are not yet verified.

Successful translations are stored locally, limited to 500 entries, with owner-only file permissions. Delete individual items from History's context menu. The assistant receives the eight latest entries as reference text and uses the separately installed Qwen3.5 2B MLX model and Python runtime under Application Support/Mandarin Lens. It has no tools, network server or remote inference fallback. It uses offline Hugging Face settings. This is not a network-disconnection certification. Model responses in Polish and Vietnamese remain unreliable in earlier direct tests. Example sentences are generated, not dictionary-verified. Chat conversation persistence and follow-up memory are not implemented.

Verified 30 October 2026 on this M5 Pro: native compilation, ad-hoc signing, application launch, real Apple English → Vietnamese and English → Polish translation, both results persisted in history, and a real local-model answer displayed in the native chat. Screenshots are in screenshots/. Control-click capture, appearance/transparency interactions, menu navigation, all-Spaces behavior, restart persistence of preferences and broad UI accessibility still need interactive acceptance. These are not claimed as passed.

Not yet included: launch-at-login, Chrome native messaging/shared vocabulary, Chinese target, private mode, dictionary retrieval, export, spaced review, full hardware adaptation, complete multilingual quality corpus, DMG notarization. This is an initial native development build, not the full 3.0 acceptance release.

## Compact interface update

The floating note now opens at 392 × 440 points (minimum 360 × 420), with a shared custom header and Translate / History / Learn navigation. Shortcut and permission controls live in an anchored settings popover. Opacity remains reachable in the footer on every page. History supports inline search and reopening saved translations; learning includes suggested questions and a bounded composer. The menu-bar panel uses the same compact visual identity. The welcome window was removed to avoid duplicate windows.

Uses the local Apple design skill, system type and adaptive colors, a teal accent with darker values for light appearance, native focus and context menus, and no decorative transitions. Reduced Transparency forces full panel opacity while preserving the chosen value for later use. High Contrast strengthens the composer boundary.

Design verification: compiled and installed on this Mac; inspected actual screenshots of translation in light appearance, history at 360 × 420 in dark appearance, local chat output and the settings popover. Re-ran a real Apple English → Polish translation and a real local model generation. Fixed text truncation found in settings screenshot inspection. Screenshots: `screenshots/redesign-*.png`. Broader VoiceOver, keyboard navigation, menu-bar pointer interactions and cross-app capture acceptance remain pending; the design update does not establish those results.
