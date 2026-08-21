var API_BASE = "https://unofficialurbandictionaryapi.com/api"

function todayString(now) {
  var d = now || new Date()
  var month = d.getMonth() + 1
  var day = d.getDate()
  return d.getFullYear() + "-" + (month < 10 ? "0" + month : month) + "-" + (day < 10 ? "0" + day : day)
}

function searchUrl(term, limit) {
  return API_BASE + "/search?term=" + encodeURIComponent(term) + "&limit=" + limit
}

function randomUrl() {
  return API_BASE + "/random"
}

function stripMarkup(text) {
  if (!text) return ""
  return String(text).replace(/\[([^\]\n]+)\]/g, "$1")
}

function cleanEntry(entry) {
  if (!entry) return null
  var word = stripMarkup(entry.word).trim()
  if (word === "") return null
  return {
    word: word,
    meaning: stripMarkup(String(entry.meaning || "")).trim(),
    example: stripMarkup(String(entry.example || "")).trim(),
    contributor: String(entry.contributor || "").trim()
  }
}

function parseResponse(raw) {
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
  if (!parsed || parsed.statusCode !== 200) {
    out.error = "HTTP " + (parsed && parsed.statusCode ? parsed.statusCode : "error")
    return out
  }
  out.ok = true
  out.found = parsed.found === true
  out.term = String(parsed.term || "").trim()
  if (Array.isArray(parsed.data)) {
    for (var i = 0; i < parsed.data.length; i++) {
      var entry = cleanEntry(parsed.data[i])
      if (entry) out.results.push(entry)
    }
  }
  return out
}
