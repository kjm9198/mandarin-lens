# Security policy

Mandarin Lens is a local-first browser extension. Report a suspected vulnerability privately through the repository's **Security → Report a vulnerability** feature when available. If private reporting is unavailable, open an issue asking the maintainer for a private reporting channel without including exploit details, personal captions, credentials, or learning data.

Include the affected version, Chrome version, operating system, reproduction steps, and expected versus actual behavior. Use a harmless demonstration. Do not access another person's browser, upload private video content, or disrupt a service.

Only the latest published release is maintained. There is no guaranteed response or repair deadline. Security changes are documented in release notes. Keep Chrome and the extension updated. If a release is suspected unsafe, disable it until a corrected release is available.

## Engineering requirements

- Keep `activeTab`, `scripting`, and `storage` as the minimum permission set. New permissions require an implemented feature, an explanation, and review.
- Treat captions, subtitle files, translations, dictionary output, and imported learning data as untrusted text. Render them with `textContent` and DOM APIs.
- Package executable code locally. Do not add `eval`, dynamic executable downloads, remote scripts, telemetry, or cloud translation without a separate product/privacy decision.
- Do not expose privileged extension APIs through page messages or externally connectable handlers.
- Bound imports, cue counts, caches, and vocabulary. Validate persistent data as well as file input.
- Preserve user control over activation and downloads. Do not capture microphone or tab audio silently.
- Verify the final ZIP, permissions, third-party notices, and checksums before release.

Security review reduces risk; it cannot establish that software is risk-free. The development review in this project is not an independent third-party audit.


## Distribution

The current distribution route is the project's GitHub release and installable source ZIP. Users load the extracted extension through Chrome Developer mode. This is not a Chrome Web Store listing and has not been approved by Google. The owner has excluded store registration, payment, and submission from the current release.
