# OmaSlang

Omarchy shell plugin that searches Urban Dictionary from the bar. Type a word
or phrase, get definitions and examples in a panel anchored to the bar widget,
plus a daily random Word of the Day. Backed by the free
[Unofficial Urban Dictionary API](https://unofficialurbandictionaryapi.com).

## Install

From a git checkout:

```sh
omarchy plugin add https://github.com/SlowburnAZ/omaslang.git --enable
```

Or copy the folder directly:

```sh
cp -r . ~/.config/omarchy/plugins/chris.omaslang
omarchy plugin enable chris.omaslang
omarchy bar put chris.omaslang --section right
```

## Usage

- Click the book icon in the bar to open the search panel (field is focused).
- Type to search — results update as you type (400 ms debounce), or press Enter to search immediately.
- Click **Random** (or middle-click the bar icon) for a random word.
- Escape closes the panel.

## Word of the Day

On the first panel open (or shell start) each day, the plugin fetches a random
word and pins it above the search field for the rest of the day. The word is
cached in `~/.local/state/omarchy/omaslang-wotd.json`; delete that file to
force a refetch.

## Dependencies

- `curl` (preinstalled on Omarchy) — all API calls run through it; no keys, no rate limits.

## Remove

```sh
omarchy plugin remove chris.omaslang
```
