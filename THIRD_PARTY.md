# Third-party credits

This file records every source of copied code and data in this project. Each entry names the source, its license, its version, and the date of the copy. An entry that says "not copied yet" marks work that a later ticket plans to do. When a copy happens, update the entry with the date of the copy and the files that were copied.

The license of this project is GPL-3.0-or-later. See [LICENSE](LICENSE). Every source in this file must have a license that works with the GPL before anything is copied from it.

The directory `prior_art/` holds local reference copies of most sources. Git does not track this directory.

## Trailwright

- Source: the Trailwright addon, https://trailwrightguides.com. The local reference copy is `prior_art/Trailwright/`.
- License: GPL-3.0-or-later, as its manifest and its own third-party file state.
- Version: 0.1.81-beta, from its manifest, and 1.51.0, from its README. The two numbers do not agree. The record keeps both.
- Status: not copied yet. Later tickets port the quest engine and copy the generated quest tables from this one-time snapshot. There are no ongoing merges. The copied data carries the credits of the Trailwright third-party file, which include its QuestieDB origin.
- Copied on: nothing copied yet.

## Embedded libraries

The addon embeds three small libraries. Each one is a verbatim copy and ships inside the addon folder under `dist/EfficientQuests/Libs/`.

### LibStub

- Source: `LibStub.lua` as shipped inside the Trailwright reference copy.
- License: public domain, as the library file states.
- Version: 2, the library minor version.
- Status: copied. The verbatim copy ships at `dist/EfficientQuests/Libs/LibStub/LibStub.lua`.
- Copied on: 2026-11-16.

### CallbackHandler-1.0

- Source: `CallbackHandler-1.0.lua` as shipped inside the Trailwright reference copy.
- License: BSD-style, as the Trailwright third-party file states.
- Version: 8, the library minor version.
- Status: copied. The verbatim copy ships at `dist/EfficientQuests/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua`.
- Copied on: 2026-11-16.

### HereBeDragons-2.0

- Source: `HereBeDragons-2.0.lua` as shipped inside the Trailwright reference copy.
- License: BSD, as the HereBeDragons manifest in the reference copies states (`X-License: BSD` in `prior_art/TomTom/libs/HereBeDragons/HereBeDragons.toc`). The copied file itself carries no license text, so this entry is the record of the license.
- Version: 35, the library minor version. The copy is a Forever-aware build: it knows the Camelot project id of the Forever client.
- Status: copied. The verbatim copy ships at `dist/EfficientQuests/Libs/HereBeDragons/HereBeDragons-2.0.lua`. The pins library of HereBeDragons is not embedded, because pins draw on maps.
- Copied on: 2026-11-16.

## Runtime integrations

The addon talks to the addons below at run time. No code or data is copied from them.

### FlareUI

- Source: the FlareUI addon by Malkkav. The local reference copy is `prior_art/FlareUI/`.
- License: MIT, as its `LICENSE.txt` states.
- Version: 6.9, from its manifest.
- Status: not copied. The look adapter reads the colors, the backdrop, and the fonts of the live FlareUI tracker when FlareUI is present. FlareUI stays optional.

### TomTom

- Source: the TomTom addon. The local reference copy is `prior_art/TomTom/`.
- License: All Rights Reserved, as its manifest states. No copy is planned, so the reservation blocks nothing.
- Version: v4.4.1-release, from its manifest.
- Status: not copied. The TomTom bridge only calls the TomTom interface when TomTom is present. TomTom stays optional.

### QuestieDB

- Source: the QuestieDB addon for Forever. The local reference copy is `prior_art/QuestieDB/`.
- License: its `LICENSE.md` allows copies and forks of its content under the terms of GPLv3. The Questie name and logo are not licensed. This project does not use them.
- Version: 1.1.2, from its Forever manifest.
- Status: not copied. The quest state reader only calls the QuestieDB interface at run time when QuestieDB is present. QuestieDB stays optional.
