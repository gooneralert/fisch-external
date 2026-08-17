#Requires AutoHotkey v2.0

GetHotbarTotems() {
    totems := []
    seen := Map()
    hotbar := GetHotbarGui()

    if !hotbar
        return totems

    for itemAddr in ReadChildren(hotbar) {
        if (ReadClassName(itemAddr) != "ImageButton" || ReadInstanceName(itemAddr) != "ItemTemplate")
            continue

        toolName := ReadHotbarItemName(itemAddr)
        if !IsSupportedAutoTotem(toolName)
            continue

        if seen.Has(toolName)
            continue

        seen[toolName] := true
        totems.Push(toolName)
    }

    return totems
}

HasHotbarTotem(totemName) {
    return FindHotbarItemByName(totemName) ? true : false
}

GetHotbarItemSlotKey(itemName) {
    itemAddr := FindHotbarItemByName(itemName)
    if !itemAddr
        return ""

    return ReadHotbarItemSlotKey(itemAddr)
}

SelectHotbarSlot(slotKey) {
    if (slotKey = "")
        return false

    SendInput("{" slotKey "}")
    Sleep(75)
    return true
}

UseHotbarSlot(slotKey) {
    if !SelectHotbarSlot(slotKey)
        return false

    Click()
    Sleep(75)
    return true
}

UseEquippedHotbarItem() {
    Click()
    Sleep(75)
    return true
}

GetAutoTotemWaitMs() {
    return 30000
}

GetCharacterModel() {
    workspace := GetWorkspaceRoot()
    if !workspace
        return 0

    localPlayer := GetLocalPlayer()
    if !localPlayer
        return 0

    playerName := ReadInstanceName(localPlayer)
    if (playerName = "" || playerName = "<null>")
        return 0

    return FindChildByName(workspace, playerName)
}

GetEquippedToolName() {
    character := GetCharacterModel()
    if !character
        return ""

    for childAddr in ReadChildren(character) {
        if (ReadClassName(childAddr) = "Tool")
            return ReadInstanceName(childAddr)
    }

    return ""
}

IsAnythingEquipped() {
    character := GetCharacterModel()
    if !character
        return false

    for childAddr in ReadChildren(character) {
        if (ReadClassName(childAddr) = "Tool")
            return true
    }

    return false
}

IsRodEquipped() {
    equippedTool := GetEquippedToolName()
    if (equippedTool = "")
        return false

    rodName := GetHotbarRodName()
    if (rodName != "")
        return (equippedTool = rodName)

    return InStr(equippedTool, "Rod") ? true : false
}

EnsureRodEquipped() {
    if IsRodEquipped()
        return true

    return SelectHotbarSlot("1")
}

TryUseHotbarItem(itemName) {
    slotKey := GetHotbarItemSlotKey(itemName)
    if (slotKey = "")
        return false

    Loop 2 {
        equippedBefore := GetEquippedToolName()

        if (equippedBefore != itemName) {
            if !SelectHotbarSlot(slotKey)
                return false

            Sleep(175)
        }

        Click()
        Sleep(100)

        equippedAfter := GetEquippedToolName()

        if (equippedAfter = itemName || equippedBefore = itemName)
            return true

        Sleep(125)
    }

    return false
}

ResolveWorldStatuses() {
    global g_CachedWorldStatuses

    if (g_CachedWorldStatuses)
        return g_CachedWorldStatuses

    localPlayer := GetLocalPlayer()
    if (!localPlayer)
        return 0

    playerGui := FindChildByClass(localPlayer, "PlayerGui")
    if (!playerGui)
        return 0

    hud := FindChildByName(playerGui, "hud")
    if (!hud)
        return 0

    safezone := FindChildByName(hud, "safezone")
    if (!safezone)
        return 0

    worldStatuses := FindChildByName(safezone, "worldstatuses")
    if (worldStatuses)
        g_CachedWorldStatuses := worldStatuses

    return worldStatuses
}

GetWorldStatusText(statusName) {
    global OFFSETS

    worldStatuses := ResolveWorldStatuses()
    if !worldStatuses
        return ""

    statusAddr := FindChildByName(worldStatuses, statusName)
    if !statusAddr
        return ""

    labelAddr := FindChildByName(statusAddr, "label")
    if !labelAddr
        return ""

    text := ""

    if OFFSETS.Has("TextLabelText")
        text := ReadString(labelAddr + (OFFSETS["TextLabelText"] + 0))

    if (text = "")
        text := ReadGuiText(labelAddr)

    return NormalizeHotbarItemText(text)
}

GetWorldStatusVisible(statusName) {
    global OFFSETS

    worldStatuses := ResolveWorldStatuses()
    if !worldStatuses
        return false

    statusAddr := FindChildByName(worldStatuses, statusName)
    if !statusAddr
        return false

    if OFFSETS.Has("TextLabelVisible")
        return ReadByte(statusAddr + (OFFSETS["TextLabelVisible"] + 0)) ? true : false

    if OFFSETS.Has("FrameVisible")
        return ReadByte(statusAddr + (OFFSETS["FrameVisible"] + 0)) ? true : false

    return true
}

IsNightCycle() {
    cycleText := StrLower(GetWorldStatusText("4_cycle"))
    return InStr(cycleText, "night") ? true : false
}

IsAuroraActive() {
    return IsWorldStatusMatchVisible("2_event", "aurora")
        || IsWorldStatusMatchVisible("3_weather", "aurora")
}

FindHotbarItemByName(itemName) {
    hotbar := GetHotbarGui()
    if !hotbar
        return 0

    for itemAddr in ReadChildren(hotbar) {
        if (ReadClassName(itemAddr) != "ImageButton" || ReadInstanceName(itemAddr) != "ItemTemplate")
            continue

        if (ReadHotbarItemName(itemAddr) = itemName)
            return itemAddr
    }

    return 0
}

ReadHotbarItemName(itemAddr) {
    nameInst := FindChildByName(itemAddr, "ItemName")
    if !nameInst
        return ""

    return NormalizeHotbarItemText(ReadGuiText(nameInst))
}

ReadHotbarItemSlotKey(itemAddr) {
    for childAddr in ReadChildren(itemAddr) {
        childClass := ReadClassName(childAddr)
        childName := ReadInstanceName(childAddr)

        if (childClass = "TextLabel" && childName = "TextLabel")
            return NormalizeHotbarItemText(ReadGuiText(childAddr))
    }

    return ""
}

NormalizeHotbarItemText(text) {
    if (text = "")
        return ""

    return Trim(RegExReplace(text, "<[^>]+>"))
}

IsSupportedAutoTotem(toolName) {
    return (toolName = "Aurora Totem")
}

IsWorldStatusMatchVisible(statusName, needle) {
    if !GetWorldStatusVisible(statusName)
        return false

    return InStr(StrLower(GetWorldStatusText(statusName)), StrLower(needle)) ? true : false
}

FindDescendantByNameAndClass(rootAddr, targetName, targetClass := "") {
    queue := [rootAddr]
    index := 1

    while (index <= queue.Length) {
        current := queue[index]
        index += 1

        currentName := ReadInstanceName(current)
        currentClass := ReadClassName(current)

        if (currentName = targetName && (targetClass = "" || currentClass = targetClass))
            return current

        for childAddr in ReadChildren(current)
            queue.Push(childAddr)
    }

    return 0
}
