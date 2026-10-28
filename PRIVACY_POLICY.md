# Mandarin Lens privacy policy

Effective date: 28 October 2026.

Mandarin Lens helps you learn Mandarin from video captions. The extension has no mandatory account, advertising, analytics, tracking pixels, or application server. Its application code does not upload captions, audio, saved words, or learning preferences to the maintainer or a translation service.

## What stays on your device

When you activate the extension on a tab, it reads captions exposed by that page or subtitle files you choose. Captions are passed to Chrome's built-in Translator API when available. Translation runs on your device; Chrome may separately download language models through Google's browser infrastructure. Downloads require a supported Chrome environment and may use substantial disk space outside the extension package.

Ordinary display preferences, up to 500 saved vocabulary entries, review schedules, example sentences, and prepared subtitle records are stored in `chrome.storage.local`. The extension does not use Chrome sync storage. Prepared records contain source caption text, translations, timestamps, and a save time. Cache keys hash the video identity, caption content, translation direction, and pipeline version; raw video URLs are not stored as cache keys. The cache targets at most three prepared records and approximately 4 MB under its application size estimate; browser storage accounting can differ. Preparation checkpoints are saved periodically so work can resume.

Local cache eviction removes older prepared records automatically. The cache-only clear control removes prepared records without deleting vocabulary or preferences and cancels active preparation. The learning-data deletion control clears this local cache along with vocabulary and settings. Captions and translations also exist temporarily in active video tabs. Do not import private material unless you are comfortable keeping it in your browser profile. Local storage is not encrypted by this extension and should not hold passwords or credentials.

The extension does not request microphone, camera, browsing-history, or tab-audio-capture permissions. Pronunciation uses only a Mandarin voice that the browser identifies as local. If none is available, pronunciation is unavailable.

## Your controls

Activate the extension only on pages where you want it to read captions. Close the subtitle overlay to stop its processing in that tab. Use the learning-data deletion control to remove saved data and settings; reload or close active video tabs to discard any in-memory captions and translations. Removing the extension removes its browser-managed local data. Files you exported remain wherever you saved them and must be deleted separately. Browser-managed language packs are controlled by Chrome and are not removed by clearing extension learning data.

Vocabulary exports are explicit downloads. Importing subtitles does not upload them. Sharing an exported file or posting a bug report may disclose its contents; remove private data first.

## Websites, source hosting, and support

Video websites retain their own privacy policies. GitHub and any static website host process ordinary requests under their policies, separately from extension processing. Clicking a source, download, support, or documentation link connects to the relevant provider. The extension does not add analytics to those requests.

Contact the maintainer through the project's repository for privacy questions. Do not post private captions, browser data, or credentials in a public issue. Changes to this policy accompany changes to the actual product behavior.
