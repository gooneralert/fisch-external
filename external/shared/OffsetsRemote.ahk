#Requires AutoHotkey v2.0

global REMOTE_OFFSETS_URL := "https://imtheo.lol/offsets/Offsets.json"
global REMOTE_OFFSETS_CACHE_TTL_MS := 60000
global _LastRemoteFetchAt := 0
global _LastRemoteFetchResult := ""

FetchRemoteOffsets() {
    global _LastRemoteFetchAt, _LastRemoteFetchResult, REMOTE_OFFSETS_CACHE_TTL_MS, REMOTE_OFFSETS_URL

    if (_LastRemoteFetchAt && (A_TickCount - _LastRemoteFetchAt) < REMOTE_OFFSETS_CACHE_TTL_MS)
        return _LastRemoteFetchResult

    _LastRemoteFetchAt := A_TickCount
    _LastRemoteFetchResult := ""

    try {
        body := FetchTextUrl(REMOTE_OFFSETS_URL)
    } catch {
        return ""
    }

    try {
        parsed := JSON.parse(body)
    } catch {
        return ""
    }

    if !(parsed is Map) || !parsed.Has("Offsets")
        return ""

    _LastRemoteFetchResult := parsed
    return parsed
}

BackupAndWriteOffsetsFile(parsed) {
    global OFFSETS_PATH

    backupPath := OFFSETS_PATH ".bak"

    if (FileExist(OFFSETS_PATH)) {
        try {
            FileCopy(OFFSETS_PATH, backupPath, true)
        } catch {
        }
    }

    try {
        file := FileOpen(OFFSETS_PATH, "w")
        file.Write(JSON.stringify(parsed, 4))
        file.Close()
    } catch {
    }
}
