# Mandarin Lens privacy policy

Effective date: 30 October 2026.

Mandarin Lens helps you learn Mandarin from video captions. The extension has no mandatory account, advertising, analytics, tracking pixels, or application server. Its application code does not upload captions, audio, saved words, or learning preferences to the maintainer or a translation service.

## What stays on your device

The website prompt runs automatically on YouTube and other websites you explicitly permit. It detects visible top-level videos to offer a choice. Website preferences store hostnames and Ask/Always/Off plus the pause preference locally; they do not store browsing paths or a visit history. Caption processing begins after Learn once, Start learning, or a remembered Always choice. When active on a tab, it reads captions exposed by that page or subtitle files you choose. Captions are passed to Chrome's built-in Translator API when available. Translation runs on your device; Chrome may separately download language models through Google's browser infrastructure. Downloads require a supported Chrome environment and may use substantial disk space outside the extension package.

Ordinary display preferences, up to 500 saved vocabulary entries, review schedules, up to 100 review-history events per word, example sentences, optional YouTube video IDs (not full URLs), subtitle timestamps, and prepared subtitle records are stored in `chrome.storage.local`. The extension does not use Chrome sync storage. Prepared records contain source caption text, translations, timestamps, and a save time. Cache keys hash the video identity, caption content, translation direction, and pipeline version; raw video URLs are not stored as cache keys. The cache targets at most three prepared records and approximately 4 MB under its application size estimate; browser storage accounting can differ. Preparation checkpoints are saved periodically so work can resume.

Local cache eviction removes older prepared records automatically. The cache-only clear control removes prepared records without deleting vocabulary or preferences and cancels active preparation. The learning-data deletion control clears this local cache along with vocabulary and settings. One random deletion-revision marker remains to reject stale writes from old sessions; it contains no captions, vocabulary, URL or identity. An event-driven storage service worker serializes vocabulary and cache updates. It has no networking, capture or periodic work. Captions and translations also exist temporarily in active video tabs. Do not import private material unless you are comfortable keeping it in your browser profile. Local storage is not encrypted by this extension and should not hold passwords or credentials.

The extension does not request microphone, camera, browsing-history, or tab-audio-capture permissions. Pronunciation uses only a Mandarin voice that the browser identifies as local. If none is available, pronunciation is unavailable.

## Your controls

Choose Ask, Always or Off for each website in the extension popup. Other websites request Chrome permission when enabled. Off closes the active overlay and removes the website prompt. Chrome’s extension details can revoke optional website access. Close the subtitle overlay to stop its processing in that tab. Use the learning-data deletion control to remove saved data and settings; reload or close active video tabs to discard any in-memory captions and translations. Removing the extension removes its browser-managed local data. Files you exported remain wherever you saved them and must be deleted separately. Browser-managed language packs are controlled by Chrome and are not removed by clearing extension learning data.

Vocabulary exports are explicit downloads. Importing subtitles does not upload them. Sharing an exported file or posting a bug report may disclose its contents; remove private data first.

## Websites, source hosting, and support

Video websites retain their own privacy policies. GitHub and any static website host process ordinary requests under their policies, separately from extension processing. Clicking a source, download, support, or documentation link connects to the relevant provider. The extension does not add analytics to those requests.

Contact the maintainer through the project's repository for privacy questions. Do not post private captions, browser data, or credentials in a public issue. Changes to this policy accompany changes to the actual product behavior.

## Separately built native macOS app

The private native app stores vocabulary, review progress, categories, translation history and chat conversations in local application-support files with owner-only permissions. Preferences use macOS defaults; optional local-server tokens use Keychain. It does not share the extension's browser storage or sync these stores to a service.

The native app is named Kamihi Lens. Pressing the screen-selection shortcut explicitly requests one snapshot of the connected displays, after macOS Screen Recording approval. Apple Vision recognizes visible words locally, including raster text. Snapshot pixels and recognition candidates stay in memory only until a word is selected or selection is cancelled. The chosen word and its line are held in the app for translation when it is explicitly opened; selection alone does not save vocabulary or translation history. A small click-through highlight remains until Escape, the shortcut again, or opening the app. No background screen monitoring or audio capture occurs. The separate Capture selected text action uses approved Accessibility access and rejects secure fields. Explicit region/display OCR removes its temporary image after recognition.

Apple Translation uses on-device language packs. Direct MLX chat, categorization and speech recognition run locally. The optional server adapter accepts only loopback endpoints and rejects redirects; the external server's own model routing remains under the user's control. Download buttons fetch model files from Hugging Face, which receives ordinary download requests. Questions, vocabulary and audio are not sent with those downloads. Inference uses offline settings and telemetry is disabled.

Optional speaking practice uses on-device Apple recognition when supported or a downloaded local speech model. Microphone recording is limited to 12 seconds. Temporary audio files are owner-only and deleted after recognition, cancellation or leaving the practice screen. Audio is not added to chat history or exported vocabulary. This compares recognized words; it does not certify pronunciation, accent or Mandarin tones. App removal does not automatically delete files in Application Support, exported files, Keychain tokens or separately installed models.
