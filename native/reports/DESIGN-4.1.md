# Kamihi Lens 4.1 design

Visual thesis: a precise native study workspace, with warm paper and charcoal surfaces, Kamihi teal for actions, and Chinese typography as the focal point.

Content plan: a compact branded sidebar, one workspace toolbar, working surfaces for translation and vocabulary, and shared controls across practice, local models, history and examples. Operational labels replace promotional headlines. Flat lists replace passive card stacks; game choices and text editors remain bounded where the boundary helps interaction.

Interaction thesis: immediate hover/press feedback makes the entire target clear; quiz Check/Continue controls remain visible while long content scrolls; capture results keep translation, pronunciation and next actions together. No ornamental animation is added. macOS appearance, increased contrast, keyboard labels and reduced-motion behavior remain respected.

Palette check: the accent/canvas contrast ratios are 6.92:1 in light mode and 9.81:1 in dark mode. This checks those palette pairs only, not a full accessibility certification.

## Acceptance

- Optimized native build and all 28 Swift tests pass. Full native rounds pass for Meaning finder, Reverse recall, Listen & choose, Pinyin path, Word builder, Meaning map and Memory match; the practice walkthrough also verifies that saved vocabulary and review dates remain unchanged.
- The installed app translates the image-only fixture word “Control” into 控制 with kòng zhì and displays a Chinese/English/pinyin usage example. The final cursor panel keeps the character-exploration menu in its action bar.
- The full save sheet retains original source context, Chinese headword, English meaning language and the bilingual example. Returning from the sheet retains the displayed example.
- A real pointer click on the blank trailing edge of the Play sidebar row navigates successfully. Check/Continue remains in the game footer while content scrolls.
- Light and dark appearances were reviewed at full workspace size and at 390 × 560 compact size. Full translation, vocabulary, dictionary, practice, model and settings views share the same palette, type and controls. Compact content scrolls vertically; the example translation stays readable.
- The build, installed app and read-only mounted DMG have identical bundle file hashes and pass strict signature verification. All three original personal JSON data files remain unchanged during acceptance testing. Tests use an isolated profile; the installed app was then reopened normally with that profile disabled.

Screens: [translation, dark](../screenshots/v41-translate-dark.png), [translation, light](../screenshots/v41-translate-light.png), [compact, dark](../screenshots/v41-compact-dark.png), [compact, light](../screenshots/v41-compact-light.png), [cursor result](../screenshots/v41-cursor-dark.png), [games](../screenshots/v41-play-dark.png), [question](../screenshots/v41-quiz-dark.png), [words](../screenshots/v41-words-dark.png), [local models](../screenshots/v41-models-dark.png).

Evidence: [Swift tests](kamihi-4.1-unit-tests.txt), [native game rounds](kamihi-4.1-native-games.txt), [delivery checks](kamihi-4.1-delivery.json).

Scope: this pass changes the native presentation and fixes the save-sheet context handoff. It does not change the translation engine, model discovery/download logic or game scoring engine. The packaged Apple Silicon app requires macOS 15 or later and is signed but not notarized. These checks do not establish a full VoiceOver audit or physical-device speech acceptance. No decorative motion was introduced.
