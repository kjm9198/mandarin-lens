# Threat model

Reviewed architecture: Manifest V3 extension with a popup, isolated injected content script, local vocabulary page, packaged pinyin data, and browser-provided translation and pronunciation APIs. No application backend is required.

## Assets and trust boundaries

| Asset | Boundary and protection |
| --- | --- |
| Browser capabilities | Chrome grants temporary current-tab access after the user activates the extension. No global host permissions are required. |
| Captions and imported subtitles | Website DOM, HTML5 text tracks, transcript panels, and local subtitle files are untrusted inputs. Text rendering prevents them from becoming executable markup. |
| Saved learning data | Extension-scoped `chrome.storage.local` holds ordinary preferences, saved words, review history, and prepared subtitle caches. The preparation key is a SHA-256 digest of normalized video identity, source captions, direction, and pipeline version. Captions remain plaintext locally; this is not an encrypted secrets vault. |
| Translation results | Browser model output is untrusted text. It is normalized before display and cached only within bounded application limits. |
| Executable package | Code and language data ship inside the extension. Browser security boundaries and package integrity remain dependencies. |
| Pronunciation | Only a Mandarin voice reported by the browser as `localService` is selected. Voice implementation remains an operating-system/browser responsibility. |

## Attackers and scenarios

An attacker may control a video page, caption text, a subtitle file, a shared vocabulary file, or content suggested for import. Such content must not execute code, request broader access, write arbitrary extension settings, or start audio capture. The extension does not expose a web-page message bridge, remote execution endpoint, or external connection handler.

A malicious page already controls its own DOM, can remove or cover the overlay, and can supply false captions. A closed shadow root provides encapsulation, not an independent security boundary against the browser or a compromised device. Translation accuracy and source truth cannot be guaranteed by extension permissions.

Large captions and subtitle files may consume memory and model time. File, text, cue, vocabulary, and cache limits reduce this exposure; model downloads and native browser resources are outside the extension's accounting. Cancellation must invalidate late results and release extension observers, timers, and translation instances when stopped.

Concurrent preparation across tabs and deletion during pending writes require explicit invalidation checks. A cache key is an identity/integrity mechanism for selecting the right transcript, not an encryption mechanism or protection against someone with access to the browser profile. The cache targets three records and approximately 4 MB based on its own size estimate.

A malicious package update or compromised maintainer account could change behavior. Review source and release notes, enable account two-factor authentication, and use the official distribution links and published checksums. A checksum detects a mismatched download; it does not prove the publisher is trustworthy.

## Explicit exclusions and uncertainty

The extension does not implement local speech transcription, DRM circumvention, account synchronization, credential storage, or a cloud translation server. Browser/OS compromise, a malicious installed extension, and third-party video-site privacy practices are outside this model. Compatibility with real Chrome translation models must be measured separately from mocked or synthetic tests. The source audit does not verify Google's internal handling of model downloads or browser-wide settings.
