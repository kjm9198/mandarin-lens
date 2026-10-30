# Mandarin Lens 3.7 acceptance report — 31 October 2026

Private installed app: `~/Applications/Mandarin Lens 3.7.app`, version **3.7.0, build 37**. Private DMG: `native/build/MandarinLens-3.7-private.dmg`. The numbered bundles remain distinguishable; 3.1–3.7 share the stable approved bundle identity and Apple Development signature. No public binary was published and main was not merged. Original dictionary, categories, review progress, model preferences and translation history remain in the existing local store.

## Reproduced defects and fixes

- [x] Modifier-only activation was unpredictable. Replaced it with exclusive native Carbon Option–Space registration, conflict feedback, configurable alternatives, clean lifecycle and a repeat latch. Startup opens the menu bar, except first-run onboarding or an explicit workspace launch.
- [x] Capture could use the wrong app or coordinates after focus changed. Capture snapshots pointer/frontmost app before presentation, hit-tests the actual app under the pointer, uses AX position/range/bounds, prefers an existing selection only when the pointer is inside it, and segments Chinese with Natural Language. Protected field ancestors are rejected before text values are read. Unsupported surfaces show selected-text/explicit OCR guidance, never an automatic screen capture.
- [x] Lookup opened a large note. It now opens a constrained 340 × 252 point contextual window with exact text, pinyin, translation/progress/error, Save/Saved, language, Compact and Open full app. Accurate bounds produce a click-through outline. Escape removes both and restores focus; outside click dismissal is controlled by the persistent floating-window setting.
- [x] Translation requests and saved meanings could become stale. Immutable request IDs reject responses after input/target/cancellation changes. Exact-word save state is derived from the completed request; duplicate prevention preserves Vietnamese tones. Save-sheet presentation retains an immutable original pair/context, and failed persistence rolls back instead of showing Saved.
- [x] One window carried every task. Full workspace navigation separates Translator, My words, History, Learn, Local models and Settings/tutorial; Compact remains a smaller companion; pointer lookup is the smallest surface. Opacity persists, and Reduced Transparency/Increased Contrast force solid windows.
- [x] Local model setup offered no download action. Added explicit resumable/cancellable 2B/4B chat and Whisper small speech downloads alongside discovery/custom folders and the loopback-only server adapter.
- [x] Chat did not retain questions or show incremental output. Added real user/assistant messages, persistent conversation history, New chat and Stop. MLX keeps weights resident, performs blocking IO off the main actor, and streams generated text. Model switching cancels current inference. An actual two-word walkthrough exposed the follow-up repeating the prior word: structured user/assistant turns now preserve the newest question instead of flattening history into one prompt. Saved-word examples carry that entry's context.
- [x] Optional speaking practice added Listen, explicit recording and local recognition/comparison. Final 3.7 adds an explicit Close button with Escape; no human recording was performed.

## Actual native acceptance

Machine: Apple M5 Pro, 48 GB unified memory, macOS 27. The following are native interactions and resulting AX/store/window-state checks, separate from unit fixtures:

| Journey | Result and evidence boundary |
| --- | --- |
| TextEdit, point without clicking: beautiful → 美丽; 学习 → Study | Passed: exact targeted text, outline, pinyin for 学习, compact lookup and real Apple Translation. Save/reopen showed Saved without a duplicate; My words contained the same entry. The final 3.7 retest confirmed 学习 → Study with pinyin and Saved. |
| Selected sentence | Exact selected phrase captured; explicit full Translate translated 我喜欢学习中文。 → I like learning Chinese. No entire-screen fallback. |
| Save a token from a sentence | Passed on 3.4 (unchanged save logic): choose 学习 from original sentence, translate the token to Study; Cancel restores the original sentence, English translation, target and context. |
| Escape and focus | Passed on final 3.7 native lookup across four placements: window/outline dismissed and original fixture app foreground restored. |
| Rapid activation / ordinary modifiers | Final 3.7: five rapid Option–Space activations produced one lookup window; ordinary Option alone did not activate it. Key-repeat latch also covered by unit tests. |
| App under pointer differs from frontmost | Passed on 3.3: background native text supplied the actual pointed word while Lens was foreground. |
| Inaccessible/protected surfaces | Native secure-field fixture refused; image-only fixture returned an honest fallback. Accessibility-denied error was exercised before approval; signed 3.1+ capture then proved the user grant. No approval dialog was bypassed. |
| Floating persistence | Pin on retained lookup after a controlled outside click (3.3); setting subsequently restored off. Final 3.7 pin-off outside-click dismissal passed on controlled TextEdit text. |
| Full workspace/Compact/models | Final 3.7 full/compact controls and full-screen entry/exit exercised; screenshots show actual installed app. Navigation to Local models during active generation took 0.133 seconds in one 3.5 sample; this is not a latency distribution. |
| Multi-turn streamed chat | Passed on 3.6, same model/chat code in 3.7: user bubble/composer clear, incremental output, persisted conversation; beautiful followed by 学习 produced a new study example. Quality remains limited, as described below. |
| Model installs | Native 4B download start/cancel exercised; full 4B installation not completed. Whisper small download completed using HTTP after disabling a stalled Xet transport. Offline speech model is stored separately from chat weights. |
| Microphone | User explicitly chose to leave the real microphone test unverified. No ambient recording or approval automation. |

The UI walkthrough kept the original 你好 entry and added beautiful and 学习; it did not reset review progress. Temporary persistence/fixture tests use separate directories.

Two physical displays were exercised: primary logical frame `(0,0,1352,878)` and right-hand external `(1352,-140,1920,1080)`, both scale 2. Final 3.7 native NSTextView fixtures supplied four visible edge targets; actual lookup frames are in [final-display-frames.json](final-display-frames.json). Tests assert exact word, bounded placement, dismissal and focus restoration. A negative-left display origin is covered only by geometry tests. **Mixed-DPI, a physical left-hand display, 16 GB hardware and broad VoiceOver acceptance were not tested.** TextEdit and the native edge fixtures are different evidence, not a claim that every app exposes usable AX text.

## Automated and offline checks

- **9 Swift Testing tests passed**: native hotkey conflict/cleanup, repeat latch, word/selection targeting, placement/conversion, stale response rejection/exact saved meaning, duplicate/persistence/tone distinctions, failed-save rollback, Chinese script conversion, bounded structured conversation roles. See [unit log](final-unit-tests.txt).
- Feature smoke passed storage/corruption preservation, review/category invariants, installed discovery and local endpoint restrictions. Cancellation/model-switch checks ran with OS network access denied. Local API discovery/completion/SSE used an explicit fixture; **authenticated real LM Studio/Bionic inference remains unverified**. [API log](final-api-streaming.txt), [cancellation log](final-cancellation-switch.txt).
- Current 2B resident-worker sample with OS network access denied: cold first text **2.033 s**, total **2.164 s**, 23 chunks; warm follow-up first text **0.035 s**, total **0.187 s**, 27 chunks. These are two short samples, not p50/p95, broad quality or memory benchmarks. [Raw outputs](final-local-model.txt).
- Real 2B structured conversation under network denial changed topic to 学习 after a prior word. [Conversation smoke](final-conversation.txt), [native chat](final-native-chat.txt).
- Offline Whisper small recognized synthesized 我喜欢学习中文 correctly. Synthesized isolated 学习 with one voice returned **下期**, a false negative; another voice returned **學習**, which script-equivalence comparison accepts. [Raw speech outputs](final-offline-speech.txt). This checks recognized words, **not pronunciation, tone or accent quality**.
- Native optimized compile/sign/install/launch completed. Strict signature checks and whole-bundle comparisons cover build, installed app and read-only mounted DMG; app executable, Python workers and Applications symlink checked before detach. [Delivery record and DMG SHA-256](final-delivery.json). Apple Development signed, **not notarized**.

## Remaining practical limits

The small local language model still makes weak or incorrect explanations: the native sample inaccurately contrasted beautiful with pretty and treated study as the opposite of relax/sleep. Structured conversation fixes the wrong-turn bug; it does not certify model quality. Larger installed models, all translation pairs, sustained memory/thermal behavior and 16 GB machines were not revalidated. Previous 9B and multilingual timings are historical and not current measurements.

Speech recognition can reject a correctly spoken short word; real human microphone acceptance is intentionally unverified. Chinese/Polish Apple on-device speech was unavailable on this Mac, so the installed Whisper fallback is required. Downloaded weights and the compatible Python MLX runtime are separate from the DMG; a fresh Mac needs that runtime or the loopback server. Downloads access Hugging Face explicitly; inference uses local weights, and no prompts/audio are sent there. No cloud inference, telemetry, mandatory account or subscription was added. No claim of bug-free behavior. The optional speaking check does not fulfill professional pronunciation or Mandarin-tone scoring; it reports recognized words with an explicit limitation.

## Screenshots from installed native builds

- [Exact target outline and lookup](../screenshots/final-highlight-lookup.png)
- [Small lookup](../screenshots/final-quick-lookup.png)
- [Full word workspace](../screenshots/final-full-workspace.png)
- [Compact companion](../screenshots/final-compact.png)
- [Conversation with two different questions](../screenshots/final-chat.png)
- [Local model downloads](../screenshots/final-local-models.png)
- [Optional speaking practice](../screenshots/final-speaking-practice.png)

Screenshots are real native UI, not mockups. Earlier tracked screenshots/reports remain historical artifacts. Reproduction commands and runtime requirements are in [native README](../README.md); the native acceptance helper requires actual compatible text windows and permissions.
