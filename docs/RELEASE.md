# Release and recovery

1. Run the documented tests and source checks. Record remaining limitations.
2. Build twice and compare SHA-256 checksums; inspect allowlisted ZIP with manifest at root.
3. Load unpacked ZIP in a separate Chrome profile; check permissions, appearance, vocabulary and supported device behavior. Do not call model stubs real translation validation.
4. Publish source tag and ZIP/checksum on GitHub. Never include credentials, test-only manifest permissions or downloaded model weights.
5. Updates are manual; back up vocabulary, replace extracted files and Reload. Keep the same installation path to preserve extension identity and storage.
6. If faulty, mark the GitHub release with the known issue and publish a corrected version. Users may load a prior reviewed ZIP in the same directory after backing up their data. Uninstalling can erase local data. No automatic rollback is promised.

Chrome Web Store registration/payment/submission was explicitly excluded by the owner on 28 October 2026. GitHub ZIP distribution requires Developer mode and carries no Google store review. No extension-store listing is implied.

## Real beta next

Invite 10–30 opt-in participants after initial technical checks. Ask consent before collecting browser/hardware, timing observations or screenshots; avoid their private transcripts. Prioritize actual English/Chinese model quality, seeking/live caption latency, current YouTube/Shorts markup, fullscreen, audio gaps, long-session CPU/memory and screen-reader use. Record only feedback actually received; no participant feedback has been collected in this project.
