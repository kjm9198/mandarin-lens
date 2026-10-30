# Development security review

Review date: 28 October 2026. Initial target: the supplied Mandarin Lens v0.4.0 workspace, before version 1 release changes. Method: source inspection of every application JavaScript, HTML, CSS, and manifest file; static inspection of the generated pinyin map as data; local searches for executable/network sinks and embedded credentials. Icon content and original authorship are not verified. This is an internal development review, not an independent audit or a completed hosted Codex Security scan.

## Initial findings and controls

No source-backed critical or high severity vulnerability was identified in the supplied files. This statement is scoped to the reviewed source and does not certify absence of vulnerabilities.

- Captions, translations, dictionary output, and saved words are displayed with safe DOM APIs and `textContent`; no `innerHTML`, `eval`, `new Function`, remote scripts, or application network upload calls were found.
- The manifest requests only `activeTab`, `scripting`, and `storage`. No global host access, audio capture, external connection handler, or privileged webpage message bridge was present.
- Imports limit subtitle files to 2 MB; caption text is normalized to 600 characters; parsed cues and caches are bounded. Very large website DOM/text-track enumeration occurs before some of those bounds, so limits should be applied during discovery as a further availability improvement.
- Vocabulary CSV export already quotes cells and neutralizes common spreadsheet formula prefixes. All imported vocabulary fields also need explicit type and length bounds.
- Translation generation checks invalidate obsolete results after mode changes or shutdown. Reverse-dictionary model creation needs the same closed-session cleanup to avoid retaining a model after the overlay closes.
- Pronunciation selects only voices reported as local. The extension itself has no audio capture capability.
- No credentials or private keys were found in the supplied source. No live credentials were used to validate this observation.
- The supplied code has no runtime package manager dependencies. This does not establish the safety of subsequently introduced test tooling or browser model implementations.

## Release hardening to verify

Before publishing, verify the final source and ZIP have an explicit restrictive extension-page CSP, bounded vocabulary imports, local data deletion, cache limits, complete third-party notices, no debug-only assets or secrets, and exactly the documented permissions. Recheck those controls after any release edits. A deterministic package allowlist and published SHA-256 checksums help identify accidental package changes.

## Remaining risks and limits

Chrome model availability, translation accuracy, language-pack sizes, memory and CPU use, real video-site compatibility, and third-party platform behavior require real-device validation. A synthetic translation stub cannot validate them. Website captions can be wrong, deceptive, or incomplete. On-device models and local voices depend on the browser's claims and implementation. Browser-profile data is not encrypted by this extension. The full current official Unicode license notice is included under `licenses/UNICODE-LICENSE.txt`. The inherited ICU data still needs better generator/version provenance.

No claim is made here about Chrome Web Store approval, an independent penetration test, or risk-free operation. Final packaging checks and test outcomes belong in the release validation report with the actual commands, build hash, browser, and hardware used.


## Version 1 implementation follow-up

A second source pass reviewed the expanded popup, vocabulary import/export/edit/review controls, preprocessing cache identity, and preparation lifecycle. The new vocabulary import accepts JSON backups or CSV, limits files to 2 MB and 500 entries, builds allowlisted field objects, and rejects invalid/oversized fields. Export escapes CSV and neutralizes formula-leading spreadsheet fields. UI text continues to use safe DOM APIs. No cloud calls or audio capture were introduced by these changes.

The popup now includes explicit deletion of all extension local storage and appearance controls with bounded numeric values and allowlisted fonts. Prepared subtitle records use `chrome.storage.local` with a target of three records and roughly 4 MB using the application's UTF-16 size estimate. SHA-256 cache identities include pipeline version, normalized video identity, source cue content, and direction. Those identities do not encrypt the stored captions. Browser storage accounting and concurrent writes require separate verification.

Source review identified preparation invalidation and model lifecycle race conditions and reported them to the implementation owner: unrelated cache eviction invalidating active preparation; non-prefix resume validation; initialization exceptions leaving preparation busy; direction changes while model creation is pending; late-created reverse models after close; pending cache writes after data deletion; and inconsistent saved-date representation. A follow-up source inspection confirmed matching-key eviction checks, contiguous-prefix cache validation, a friendly preparation initialization catch, generation/direction checks around main model creation, destruction of reverse models that complete after close, numeric saved dates, cache-write cancellation checks after awaited reads/removals, and a data-epoch signal that closes active overlays before local-data deletion. The final implementation also guards closed-session vocabulary writes and settings reads, handles settings rejection, exposes timeout retry, and uses native TextTrack cuechange events. Packaged browser tests separately verified delete-all closes the active overlay; arbitrary concurrent races have not been exhaustively tested. These are correctness, availability, and local-data lifecycle concerns; no remote code execution or caption-upload path was established.

All final ZIP inspection, real Chrome model behavior, and packaged browser results remain outside this source-only follow-up. Do not substitute the synthetic-session report for those checks.


## Distribution decision

The owner chose a freely shareable extension ZIP and a GitHub release. Chrome Web Store registration, payment, and submission are excluded from this release. Loading an unpacked extension through Chrome Developer mode is different from store installation and has no Google store approval. The download and installation documentation must state that distinction. This review does not claim Chrome Web Store publication or certification.


## Static verification result

`node scripts/check.cjs` passed during the version 1 source follow-up. It verified version `1.0.0`, Manifest V3, the exact three permissions, absence of host/content/external connection exposure, and the restrictive extension-page policy `script-src 'self'; object-src 'none'; base-uri 'none'; connect-src 'none'`. JavaScript syntax checks passed. Its source patterns found none of the selected unsafe HTML/code/network sinks or selected credential patterns in packaged application sources. The full included Unicode license notice was present. Pattern checks are limited by their specific patterns and are not proof that all possible secrets or vulnerabilities are absent.


## Version 1.1 follow-up

The added cache-only deletion UI measures extension-local prepared records and removes only keys with the existing `prepared:` namespace. A local cache-epoch signal cancels active preparation before deletion; generation checks remain in the checkpoint writer. Saved vocabulary and appearance settings are retained and verified in the packaged browser test. No new permission, network/capture API, runtime dependency, external message handler or executable source was introduced. Sentence-loop media listeners follow the existing cleanup path. The safe text-rendering and restrictive CSP policies remain. This is an internal source review of these changes; model availability, concurrent storage accounting and general browser security retain their documented limits.


## Version 1.2 follow-up

Source review of media selection, live track filtering and retry handling confirms no new permissions, executable sources, message bridges, uploads or runtime dependencies. Candidate enumeration is bounded to 32 videos/tracks/cues; DOM caption fallback is scoped to the chosen player. Video/source changes invalidate old generation-sensitive preparation and clear in-memory imported captions. Rejected live translations expose user-initiated restart; preparation failures checkpoint the completed prefix before resetting the local translator. Existing safe text rendering, source-file import validation, cache limits and restrictive CSP remain in place. These are correctness and availability improvements, not a new independent audit or proof of universal site compatibility.


## Version 1.3 follow-up

Word explanations remain safe text nodes inside the closed extension shadow tree; moving them outside the subtitle layout does not add a page message bridge or external API. Positioning uses local element rectangles and viewport bounds. The popup loads the already-packaged core script to share a pure appearance migration helper. The migration only writes known appearance fields and a constant layout-version marker, preserves vocabulary and custom font settings, and is tested against actual extension storage. No permission, network/capture capability or dependency was added. Existing CSP and package allowlist checks remain. This is internal review and does not certify universal accessibility or security.

## Version 2.0 follow-up

See [reports/2.0.0-SECURITY.md](../reports/2.0.0-SECURITY.md) for the current worker trust boundary, concurrent-write/deletion fixes, actual regression evidence and remaining risks. Previous findings above describe their release-time state; V2 replaces tab-local vocabulary/cache mutations with sender-validated serialized worker operations.


## Version 2.1 website controls

Required YouTube host access now runs a packaged video-choice script. Optional HTTP/HTTPS host declarations support individual user-requested website grants and persistent prompt registration. See PERMISSIONS.md and PRIVACY_POLICY.md for the current scope. Worker site-start requests require this extension sender, a top-level tab and HTTP/HTTPS. No webpage message bridge or external message handler is added. Caption scripts remain isolated and local. This update is locally installed, not a store-reviewed or published release.
