# Kamihi Lens 3.8 acceptance

Installed app: `~/Applications/Kamihi Lens.app`, version 3.8.0, build 38. This renames the native app and retains its existing bundle identity, defaults, Application Support directory, model files and Keychain service. The Chrome extension remains a separate product.

## Requested behavior

Option–Space toggles screen selection instead of opening quick lookup. A crosshair and light word outline provide direct feedback over a screen snapshot. Clicking a recognized word removes the full-screen selection surface and leaves only a small click-through highlight. Escape or the shortcut again clears it. No translation request, saved word or history entry is created merely by selecting. Opening Kamihi Lens explicitly opens the workspace and translates the last selected word. Cancelling the highlight keeps that word in memory until app exit.

Local Apple Vision recognizes raster text as well as text that apps normally expose through Accessibility. The user approved macOS Screen Recording before native acceptance. Capture occurs once per activation; there is no continuous screen or audio recording. Pixels are held in memory only for selection/recognition and discarded afterward. Protected or unreadable content can remain unavailable. Permission errors appear in the app's status/settings; the shortcut does not open a permission popup or workspace. Its explicit Settings button requests the macOS grant.

Escape is registered separately only while selection/highlight is active, without requiring background keyboard monitoring permission. It is unregistered on cancellation, failure, shutdown or screen configuration change. Distinct hotkey signatures prevent Escape events from firing the activation handler. Delayed capture/OCR results are rejected after cancellation. Default macOS panel close animations are disabled for immediate clearing, and the highlight stays visible when Lens is in the background.

## Verified on the installed app

- An image-only native fixture exposes an AX image, with no accessible word text. Both raster `coffee` and `学习` were recognized and selected at the correct location.
- After each selection, the app's on-screen window list contained only the bounded highlight: no full workspace, lookup window or translation popup. The source app remained foreground in the sampled pointer journeys.
- Escape cleared both the active selector and the selected highlight. Option–Space again cleared the selected highlight. Three additional start/cancel cycles left no overlays or late OCR resurrection. Ordinary Option alone did not activate selection.
- Explicitly opening the app retained `学习`, showed `xué xí`, translated it to `Study`, and cleared selection UI.
- Arrow-key input changed the preview in a separate native sample. This is not a broad VoiceOver certification.
- The renamed full workspace rendered correctly, with updated instructions and permission settings.
- The installed app passed strict signing verification. Complete installed/build/read-only-DMG bundle comparisons and the DMG's Applications shortcut passed. The private build is not notarized.
- Words and chat store hashes remained unchanged. See the delivery record for the history hash comparison. Existing model folders and preferences retain their original locations; no store migration/reset was performed.

The final native selection journeys used the current single Retina display at logical 1512 × 982. Two displays were present during initial capture checks, but the display configuration changed during the session. The final positive selection journey is not claimed as two-display acceptance. Geometry tests cover display offsets and negative origins; mixed-DPI and broad physical-display configurations remain unverified.

## Automated evidence

12 Swift Testing cases passed, including individual English/Chinese OCR word bounds, display-coordinate conversion, refusing nearest-word guesses in blank space, selection without popup/translation, stale-save protection, hotkey lifecycle/repeat latch and existing persistence/chat behavior. Storage/security smoke checks also passed.

- [Unit output](kamihi-3.8-unit-tests.txt)
- [Native acceptance output](kamihi-3.8-native.txt)
- [Storage smoke output](kamihi-3.8-storage.txt)
- [Signed delivery/parity record](kamihi-3.8-delivery.json)
- [Actual subtle selection screenshot](../screenshots/kamihi-3.8-selected-word.png)

`Tests/selection_smoke.py` reproduces the native acceptance with the installed app and `Tests/SelectionFixture.swift` running. Compile native helpers with `-target arm64-apple-macos15.0`; the fixture also requires `-parse-as-library`. The script does not change privacy permissions. It checks resulting windows and translated text after input delivery instead of treating synthetic input as success by itself.

## Limits

OCR can misread small, low-contrast, stylized or obscured text; there is no guarantee of recognizing every word or protected/DRM surface. Selection freezes the captured content while choosing and does not track moving text after the click. If the source moves, clear and select again. A screenshot, a successful compile and a passed fixture do not certify every application or language. The existing small-model explanation and speech-recognition limitations remain as documented in the [prior workspace report](LEARNING-UPDATE.md). No human microphone or tone-scoring acceptance was added.
