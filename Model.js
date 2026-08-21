var API_BASE = "https://api.urbandictionary.com/v0"

function todayString(now) {
  var d = now || new Date()
  var month = d.getMonth() + 1
  var day = d.getDate()
  return d.getFullYear() + "-" + (month < 10 ? "0" + month : month) + "-" + (day < 10 ? "0" + day : day)
}

function searchUrl(term) {
  return API_BASE + "/define?term=" + encodeURIComponent(term)
}

function randomUrl() {
  return API_BASE + "/random"
}

function wotdUrl() {
  return API_BASE + "/words_of_the_day"
}

function thumbCachePath(home, defid) {
  var safe = String(defid || "").replace(/[^0-9A-Za-z]/g, "")
  return home + "/.cache/omarchy/omaslang/thumbs/" + safe + ".png"
}

function thumbCommand(thumbUrl, cachePath) {
  return ["bash", "-c",
    'mkdir -p "$(dirname "$2")" && rm -f "$2" && curl -fsS --max-time 8 "$1" | magick webp:- png:"$2"',
    "bash", thumbUrl, cachePath]
}

function audioCommand(url) {
  return ["mpv", "--no-video", "--really-quiet", url]
}

function copyCommand(text) {
  return ["wl-copy", text]
}

function stripMarkup(text) {
  if (!text) return ""
  return String(text).replace(/\[([^\]\n]+)\]/g, "$1")
}

function linkifyMarkup(text, color) {
  if (!text) return ""
  var s = String(text)
  s = s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  s = s.replace(/\r\n|\r|\n/g, "<br>")
  var css = color ? ' style="color: ' + color + '; text-decoration: underline"' : ' style="text-decoration: underline"'
  s = s.replace(/\[([^\]\n]+)\]/g, '<a href="$1"' + css + '>$1</a>')
  return s
}

function cleanEntry(entry) {
  if (!entry) return null
  var word = stripMarkup(entry.word).trim()
  if (word === "") return null
  return {
    word: word,
    meaning: String(entry.definition || "").trim(),
    example: String(entry.example || "").trim(),
    contributor: String(entry.author || "").trim(),
    thumb: String(entry.udimg_url || "").trim(),
    permalink: String(entry.permalink || "").trim(),
    defid: String(entry.defid || "").trim(),
    audio: String(entry.play_sound_url || "").trim(),
    wotdDate: String(entry.date || "").trim()
  }
}

function parseResponse(raw, maxResults) {
  var out = { ok: false, found: false, term: "", results: [], error: "" }
  var text = String(raw || "").trim()
  if (text === "") {
    out.error = "Network error"
    return out
  }
  try {
    var parsed = JSON.parse(text)
  } catch (e) {
    out.error = "Bad response"
    return out
  }
  if (!parsed || !Array.isArray(parsed.list)) {
    out.error = "Bad response"
    return out
  }
  out.ok = true
  var list = parsed.list
  var n = maxResults && maxResults > 0 ? Math.min(maxResults, list.length) : list.length
  for (var i = 0; i < n; i++) {
    var entry = cleanEntry(list[i])
    if (entry) out.results.push(entry)
  }
  out.found = out.results.length > 0
  return out
}

function historyPath(home) {
  return home + "/.local/state/omarchy/omaslang-history.json"
}

function loadHistory(raw) {
  try { var a = JSON.parse(raw || "[]") } catch (e) { return [] }
  return Array.isArray(a) ? a : []
}

function addHistory(list, term) {
  var q = (term || "").trim()
  if (q === "") return list
  var out = [q]
  for (var i = 0; i < list.length; i++) {
    if (list[i] !== q && out.length < 10) out.push(list[i])
  }
  return out
}
