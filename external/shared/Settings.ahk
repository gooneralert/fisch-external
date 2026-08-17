#Requires AutoHotkey v2.0

EnsureAppDataDirs() {
    if (!DirExist(APPDATA_DIR))
        DirCreate(APPDATA_DIR)

    if (!DirExist(CONFIGS_DIR))
        DirCreate(CONFIGS_DIR)
}

SaveSettingsFile() {
    global SETTINGS

    try {
        file := FileOpen(APPDATA_DIR "\settings.json", "w")
        file.Write(JSON.stringify(SETTINGS, 4))
        file.Close()
    } catch as err {
        MsgBox("Failed to save settings: " err.Message, "Settings Error")
    }
}

FormatSettingValue(value, isInteger := false, decimals := 2) {
    if (isInteger)
        return Round(value)

    return Format("{:." decimals "f}", value)
}

ValidateAndSaveMain(key, ctrl, minValue, maxValue, isInteger := false, decimals := 2) {
    global SETTINGS, MAIN

    oldValue := MAIN[key]
    rawValue := Trim(ctrl.Value)

    if (rawValue = "") {
        ctrl.Value := FormatSettingValue(oldValue, isInteger, decimals)
        MsgBox("This field cannot be empty.", "Invalid Value")
        return
    }

    if !RegExMatch(rawValue, "^-?(?:\d+|\d*\.\d+)$") {
        ctrl.Value := FormatSettingValue(oldValue, isInteger, decimals)
        MsgBox("Please enter a valid number.", "Invalid Value")
        return
    }

    numericValue := rawValue + 0

    if (isInteger)
        numericValue := Round(numericValue)

    if (numericValue < minValue || numericValue > maxValue) {
        ctrl.Value := FormatSettingValue(oldValue, isInteger, decimals)
        MsgBox("Value must be between " minValue " and " maxValue ".", "Invalid Range")
        return
    }

    MAIN[key] := numericValue
    SETTINGS["main"][key] := numericValue

    ctrl.Value := FormatSettingValue(numericValue, isInteger, decimals)

    if (key = "update_rate")
        SetTimer(MacroLoop, MAIN["update_rate"])

    SaveSettingsFile()
}

ListConfigs() {
    configs := []

    if (!DirExist(CONFIGS_DIR))
        return configs

    Loop Files, CONFIGS_DIR "\*.json" {
        name := RegExReplace(A_LoopFileName, "\.json$")
        configs.Push(name)
    }

    return configs
}

SaveConfig(name, useDefaults := false) {
    global SETTINGS

    data := useDefaults ? GetDefaultSettings()["main"] : SETTINGS["main"].Clone()
    PruneObsoleteMainSettings(data)
    NormalizeMainSettings(data)

    try {
        file := FileOpen(CONFIGS_DIR "\" name ".json", "w")
        file.Write(JSON.stringify(data, 4))
        file.Close()
    } catch as err {
        MsgBox("Failed to save config: " err.Message, "Config Error")
    }
}

LoadConfig(name) {
    global SETTINGS, MAIN

    filePath := CONFIGS_DIR "\" name ".json"

    try {
        jsonData := FileRead(filePath)
        configMap := JSON.parse(jsonData)

        for key, value in configMap {
            SETTINGS["main"][key] := value
            MAIN[key] := value
        }

        configDirty := PruneObsoleteMainSettings(SETTINGS["main"])
        if (NormalizeMainSettings(SETTINGS["main"]))
            configDirty := true

        defaults := GetDefaultSettings()["main"]
        for key, defaultVal in defaults {
            if (!MAIN.Has(key)) {
                MAIN[key] := defaultVal
                SETTINGS["main"][key] := defaultVal
                configDirty := true
            }
        }

        if (configDirty)
            SaveConfig(name)

        SETTINGS["last_config"] := name
        SaveSettingsFile()
        ReloadMacro()
    } catch as err {
        MsgBox("Failed to load config: " err.Message, "Config Error")
    }
}

DeleteConfig(name) {
    global SETTINGS

    try {
        FileDelete(CONFIGS_DIR "\" name ".json")
        if (SETTINGS["last_config"] = name) {
            SETTINGS["last_config"] := ""
            SaveSettingsFile()
        }
    } catch as err {
        MsgBox("Failed to delete config: " err.Message, "Config Error")
    }
}

MigrateAllConfigs() {
    global SETTINGS, FULL_VER

    if (SETTINGS.Has("last_migrated_version") && SETTINGS["last_migrated_version"] = FULL_VER)
        return

    if (!DirExist(CONFIGS_DIR))
        return

    defaults := GetDefaultSettings()["main"]

    Loop Files, CONFIGS_DIR "\*.json" {
        try {
            jsonData := FileRead(A_LoopFileFullPath)
            configMap := JSON.parse(jsonData)
            changed := false

            if (PruneObsoleteMainSettings(configMap))
                changed := true
            if (NormalizeMainSettings(configMap))
                changed := true

            for key, defaultVal in defaults {
                if (!configMap.Has(key)) {
                    configMap[key] := defaultVal
                    changed := true
                }
            }

            if (changed) {
                file := FileOpen(A_LoopFileFullPath, "w")
                file.Write(JSON.stringify(configMap, 4))
                file.Close()
            }
        } catch {
        }
    }

    SETTINGS["last_migrated_version"] := FULL_VER
    SaveSettingsFile()
}
