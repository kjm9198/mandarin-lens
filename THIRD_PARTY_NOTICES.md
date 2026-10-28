# Third-party notices

## Packaged pinyin data

`data/pinyin.js` identifies its source as ICU Han–Latin transliteration data under the Unicode license. The full current Unicode license notice is included in [licenses/UNICODE-LICENSE.txt](licenses/UNICODE-LICENSE.txt), obtained during release preparation from the official Unicode license source. The original supplied workspace did not include a generator, ICU version, or precise source revision. That provenance remains unknown; do not claim a precisely reproducible generation process until the generator and source version are recorded.

The phrase pronunciation overrides and small beginner dictionary are shipped as project code. They are not CC-CEDICT and do not provide a complete or independently verified Chinese dictionary.

## Browser and operating-system capabilities

Chrome's Translator API, its language-model downloads, `Intl.Segmenter`, and operating-system speech voices are runtime capabilities. Their implementations and model weights are not redistributed in this extension. Availability, separate terms, licensing, and disk usage are controlled by their providers. No Whisper weights or other speech-recognition models are packaged.

## Fonts and graphics

The UI uses system font stacks rather than downloaded font files. Review the provenance of the supplied extension icons before representing them as newly commissioned artwork.

## Application dependencies

The supplied extension uses browser APIs and packaged JavaScript without third-party application runtime packages. Development/test dependencies, if added, must be audited from the final lockfile and are not automatically part of the installable extension. A dependency audit does not audit the browser, operating system, or native models.
