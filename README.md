# OmaSlang

Omarchy shell plugin that searches Urban Dictionary from the bar. Type a word
or phrase, get definitions and examples in a panel anchored to the bar widget,
plus a daily Word of the Day. Backed by the official
[Urban Dictionary API](https://api.urbandictionary.com).

<img width="563" height="411" alt="image" src="https://github.com/user-attachments/assets/7a65d9d5-3ea1-4d1e-81c4-13505928b7bd" />



## Install

From a git checkout:

```sh
omarchy plugin add https://github.com/SlowburnAZ/omaslang.git --enable
```

Or copy the folder directly:

```sh
cp -r . ~/.config/omarchy/plugins/slowburnaz.omaslang
omarchy plugin enable slowburnaz.omaslang
omarchy bar put slowburnaz.omaslang --section right
```

## Usage

- Click the book icon in the bar to open the search panel (field is focused).
- Type to search — results update as you type (400 ms debounce), or press Enter to search immediately.
- Click **Random** (or middle-click the bar icon) for a random word.
- Bracketed words in definitions and examples are cross-references — click one to search that term.
- Click the speaker icon to play pronunciation audio, the clipboard icon to copy a definition.
- Recent searches appear as chips when the input is empty — click one to re-run it.
- Escape closes the panel.

## Word of the Day

On the first panel open (or shell start) each day, the plugin fetches the
Word of the Day and pins it above the search field for the rest of the day.
Click the refresh button next to the **WORD OF THE DAY** header to pull a new
one at any time. If the entry is long, the text area scrolls independently so
the search field stays in view.

The word is cached in `~/.local/state/omarchy/omaslang-wotd.json`; delete that
file to force a refetch on the next panel open.

## Search History

Recent searched and random words are kept in
`~/.local/state/omarchy/omaslang-history.json` (up to 10, most recent first)
and shown as clickable chips when the search field is empty. Delete the file
to clear history.

## Dependencies

- `curl` (preinstalled on Omarchy) — all API calls run through it; no keys required.
- `magick` from [ImageMagick](https://imagemagick.org) (preinstalled on Omarchy) — converts Urban Dictionary WebP thumbnails to PNG so Qt can render them.
- `mpv` (preinstalled on Omarchy) — plays pronunciation audio for entries that have it.
- `wl-copy` from [wl-clipboard](https://github.com/bugaevc/wl-clipboard) (preinstalled on Omarchy) — copies definitions to the Wayland clipboard.

## Remove

```sh
omarchy plugin remove slowburnaz.omaslang
```
