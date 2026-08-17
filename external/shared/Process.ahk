#Requires AutoHotkey v2.0

GetRobloxPID() {
    global ROBLOX_INSTANCE
    return ProcessExist(ROBLOX_INSTANCE)
}

GetProcessBase(pid) {
    global H_PROCESS
    static PROCESS_QUERY_INFORMATION := 0x0400
    static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000
    static PROCESS_VM_READ := 0x0010
    static LIST_MODULES_ALL := 0x03

    access := PROCESS_QUERY_INFORMATION | PROCESS_VM_READ
    H_PROCESS := DllCall("OpenProcess", "UInt", access, "Int", false, "UInt", pid, "Ptr")

    if !H_PROCESS
        H_PROCESS := DllCall("OpenProcess", "UInt", PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, "Int", false, "UInt", pid, "Ptr")

    if !H_PROCESS
        throw Error("Failed to open process " pid " (Error: " A_LastError ")")

    hMods := Buffer(A_PtrSize * 1024)
    cbNeeded := 0

    enumResult := DllCall("psapi\EnumProcessModulesEx"
        , "Ptr", H_PROCESS
        , "Ptr", hMods.Ptr
        , "UInt", hMods.Size
        , "UInt*", &cbNeeded
        , "UInt", LIST_MODULES_ALL)

    if !enumResult {
        DllCall("CloseHandle", "Ptr", H_PROCESS)
        H_PROCESS := 0
        throw Error("Failed to enumerate modules for process " pid " (Error: " A_LastError ")")
    }

    return NumGet(hMods, 0, "UPtr")
}

GetRunningRobloxVersionHash(pid) {
    static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000
    static MAX_PATH_CHARS := 1024

    hProc := DllCall("OpenProcess", "UInt", PROCESS_QUERY_LIMITED_INFORMATION, "Int", 0, "UInt", pid, "Ptr")
    if !hProc
        throw Error("OpenProcess failed (pid=" pid ", error=" A_LastError ")")

    try {
        buf := Buffer(MAX_PATH_CHARS * 2, 0)  ; UTF-16: 2 bytes per char
        size := MAX_PATH_CHARS
        if !DllCall("QueryFullProcessImageNameW", "Ptr", hProc, "UInt", 0, "Ptr", buf.Ptr, "UInt*", &size)
            throw Error("QueryFullProcessImageNameW failed (error=" A_LastError ")")
    } finally {
        DllCall("CloseHandle", "Ptr", hProc)
    }

    exePath := StrGet(buf, size, "UTF-16")
    if RegExMatch(exePath, "(version-[a-f0-9]+)", &m)
        return m[1]

    throw Error("Version hash not found in path: " exePath)
}

CreateHttpRequest() {
    request := ComObject("WinHttp.WinHttpRequest.5.1")
    request.SetTimeouts(5000, 5000, 15000, 15000)
    return request
}

SendHttpRequest(method, url, headers := "", redirectCount := 0) {
    if (redirectCount >= 5)
        throw Error("Too many redirects for " url)

    request := CreateHttpRequest()
    request.Open(method, url, false)
    request.SetRequestHeader("User-Agent", "OpenMacro-XTernal")

    if (headers is Map) {
        for name, value in headers
            request.SetRequestHeader(name, value)
    }

    request.Send()

    if (request.Status >= 300 && request.Status < 400) {
        try {
            location := request.GetResponseHeader("Location")
        } catch {
            location := ""
        }

        if (location != "")
            return SendHttpRequest(method, ResolveRedirectUrl(url, location), headers, redirectCount + 1)
    }

    return request
}

ResolveRedirectUrl(baseUrl, redirectUrl) {
    if RegExMatch(redirectUrl, "i)^[a-z][a-z0-9+\-.]*://")
        return redirectUrl

    if (SubStr(redirectUrl, 1, 1) = "/") {
        if RegExMatch(baseUrl, "i)^(https?://[^/]+)", &origin)
            return origin[1] redirectUrl
    }

    if RegExMatch(baseUrl, "i)^(.*/)[^/]*$", &parent)
        return parent[1] redirectUrl

    return redirectUrl
}

FetchTextUrl(url) {
    request := SendHttpRequest("GET", url)

    if !IsSuccessfulHttpStatus(request.Status)
        throw Error("HTTP " request.Status " returned for " url)

    return request.ResponseText
}

IsSuccessfulHttpStatus(status) {
    return status >= 200 && status < 300
}

GetLatestRobloxVersionHash() {
    static URL := "https://clientsettingscdn.roblox.com/v1/client-version/WindowsPlayer"

    req := CreateHttpRequest()
    req.Open("GET", URL, false)
    req.Send()

    if req.Status != 200
        throw Error("Version fetch failed: HTTP " req.Status)

    json := req.ResponseText
    if RegExMatch(json, '"clientVersionUpload"\s*:\s*"(version-[a-f0-9]+)"', &m)
        return m[1]

    throw Error("clientVersionUpload not found in response")
}
