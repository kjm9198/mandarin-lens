# Permission justifications

| Permission | Why it is required | Scope |
| --- | --- | --- |
| `activeTab` | Apply learning subtitles to the page the user chooses. | Chrome grants temporary access following an explicit extension action. Access ends according to Chrome's active-tab rules; reload may require activation again. |
| `scripting` | Inject packaged caption, pinyin, and overlay code into the selected tab. | Used with the user's active-tab grant, in Chrome's isolated content-script world. |
| `storage` | Save ordinary appearance settings and vocabulary locally. | Extension-scoped local browser storage. Not an encrypted vault. |

There are no required or optional global host permissions, no `<all_urls>` permission, and no microphone, tab capture, browsing history, or network interception permissions. An event-driven service worker serializes local data changes; it has no timers, polling or networking and is suspended by Chrome when idle. It is not an always-running background page. Protected browser pages cannot be injected into.

Chrome's on-device Translator API availability and model downloads are browser capabilities, not additional extension host permissions. Installed local text-to-speech voices are used only after the user asks for pronunciation.
