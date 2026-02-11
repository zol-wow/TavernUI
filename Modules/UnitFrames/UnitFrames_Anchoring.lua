local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("UnitFrames")

if not module then return end

local Anchor = LibStub("LibAnchorRegistry-1.0", true)

if not Anchor then
    module:Debug("LibAnchorRegistry-1.0 not found")
    return
end

local LibEditMode = LibStub("LibEditMode", true)
local useLibEditMode = LibEditMode and LibEditMode.AddFrame

local Anchoring = {}
local anchorHandles = {}
local libEditModeRegistered = {}
local combatApplyQueue = {}
local combatEventRegistered = false
local combatEventFrame = nil

local POSITION_CHANGE_THRESHOLD = 1
local EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B = 0.2, 0.8, 1
local EDIT_OVERLAY_FILL_R, EDIT_OVERLAY_FILL_G, EDIT_OVERLAY_FILL_B, EDIT_OVERLAY_FILL_A = 0.2, 0.8, 1, 0.25

local UNIT_DISPLAY_NAMES = {
    player       = "Player",
    target       = "Target",
    targettarget = "Target of Target",
    focus        = "Focus",
    focustarget  = "Focus Target",
    pet          = "Pet",
    boss1        = "Boss 1",
    boss2        = "Boss 2",
    boss3        = "Boss 3",
    boss4        = "Boss 4",
    boss5        = "Boss 5",
    arena1       = "Arena 1",
    arena2       = "Arena 2",
    arena3       = "Arena 3",
}

local function GetFrameForUnit(unit)
    return module.frames[unit]
end

local function GetUnitType(unit)
    return module:GetUnitType(unit) or unit
end

local function GetBarPosition(unit)
    local frame = GetFrameForUnit(unit)
    if not frame or not frame.GetPoint then return nil end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return nil end
    local relativeToName = (relativeTo and relativeTo.GetName and relativeTo:GetName()) or (relativeTo == UIParent and "UIParent") or nil
    return {
        point = point,
        relativeToName = relativeToName,
        relativePoint = relativePoint,
        x = x or 0,
        y = y or 0,
    }
end

local function HasPositionChanged(unit, startPos)
    if not startPos then return false end
    local current = GetBarPosition(unit)
    if not current then return true end
    if math.abs(current.x - startPos.x) > POSITION_CHANGE_THRESHOLD or math.abs(current.y - startPos.y) > POSITION_CHANGE_THRESHOLD then
        return true
    end
    return current.point ~= startPos.point or current.relativePoint ~= startPos.relativePoint or current.relativeToName ~= startPos.relativeToName
end

local function ShouldApplyAnchor(unit)
    local unitType = GetUnitType(unit)
    local anchorConfig = module:GetSetting("units." .. unitType .. ".anchorConfig", {})
    if not anchorConfig then return false end
    local target = anchorConfig.target
    return target and target ~= ""
end

local function SetAnchorConfig(unit, anchorConfig)
    local unitType = GetUnitType(unit)
    module:SetSetting("units." .. unitType .. ".anchorConfig", anchorConfig)
end

local function ReleaseAnchor(unit)
    local handle = anchorHandles[unit]
    if handle then
        if handle.Release then
            handle:Release()
        end
        anchorHandles[unit] = nil
    end
end

local function SetBarDraggable(frame, enable)
    if not frame or not frame.SetMovable then return end
    if enable then
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
        frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    else
        frame:SetMovable(false)
        frame:EnableMouse(true)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    end
end

local function GetEditModeLayoutPositions()
    local db = module:GetDB()
    if not db.editModeLayoutPositions then db.editModeLayoutPositions = {} end
    return db.editModeLayoutPositions
end

function Anchoring:ClearLayoutPositionForFrame(unit)
    if not useLibEditMode or not LibEditMode or not LibEditMode.GetActiveLayoutName then return end
    local layoutName = LibEditMode:GetActiveLayoutName()
    if not layoutName then return end
    local positions = GetEditModeLayoutPositions()
    if positions[layoutName] then
        positions[layoutName][unit] = nil
    end
end

local function UpdateEditOverlayInfo(unit)
    local frame = GetFrameForUnit(unit)
    local overlay = frame and frame.editModeOverlay
    if not overlay or not overlay.infoText then return end
    local w = frame:GetWidth()
    local h = frame:GetHeight()
    local dimStr = (w and h) and ("%d x %d"):format(math.floor(w + 0.5), math.floor(h + 0.5)) or "?"
    local pos = GetBarPosition(unit)
    local anchorStr
    if pos then
        local rel = (pos.relativeToName and pos.relativeToName ~= "" and pos.relativeToName ~= "UIParent") and pos.relativeToName or nil
        if rel then
            anchorStr = ("%s to %s"):format(pos.point or "CENTER", rel)
        else
            anchorStr = ("%s %d, %d"):format(pos.point or "CENTER", math.floor((pos.x or 0) + 0.5), math.floor((pos.y or 0) + 0.5))
        end
    else
        anchorStr = "?"
    end
    overlay.infoText:SetText(dimStr .. "  |  " .. anchorStr)
end

local function CreateNudgeButton(parent, direction, deltaX, deltaY, unit)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(TavernUI.WHITE8X8)
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.7)
    local line1 = btn:CreateTexture(nil, "ARTWORK")
    line1:SetColorTexture(1, 1, 1, 0.9)
    line1:SetSize(7, 2)
    local line2 = btn:CreateTexture(nil, "ARTWORK")
    line2:SetColorTexture(1, 1, 1, 0.9)
    line2:SetSize(7, 2)
    if direction == "DOWN" then
        line1:SetPoint("CENTER", btn, "CENTER", -2, 1)
        line1:SetRotation(math.rad(-45))
        line2:SetPoint("CENTER", btn, "CENTER", 2, 1)
        line2:SetRotation(math.rad(45))
    elseif direction == "UP" then
        line1:SetPoint("CENTER", btn, "CENTER", -2, -1)
        line1:SetRotation(math.rad(45))
        line2:SetPoint("CENTER", btn, "CENTER", 2, -1)
        line2:SetRotation(math.rad(-45))
    elseif direction == "LEFT" then
        line1:SetPoint("CENTER", btn, "CENTER", -1, -2)
        line1:SetRotation(math.rad(-45))
        line2:SetPoint("CENTER", btn, "CENTER", -1, 2)
        line2:SetRotation(math.rad(45))
    else
        line1:SetPoint("CENTER", btn, "CENTER", 1, -2)
        line1:SetRotation(math.rad(45))
        line2:SetPoint("CENTER", btn, "CENTER", 1, 2)
        line2:SetRotation(math.rad(-45))
    end
    btn:SetScript("OnEnter", function()
        line1:SetColorTexture(EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B, 1)
        line2:SetColorTexture(EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B, 1)
    end)
    btn:SetScript("OnLeave", function()
        line1:SetColorTexture(1, 1, 1, 0.9)
        line2:SetColorTexture(1, 1, 1, 0.9)
    end)
    btn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local frame = GetFrameForUnit(unit)
        if not frame then return end
        local pos = GetBarPosition(unit)
        if not pos then return end
        local step = IsShiftKeyDown() and 10 or 1
        local newX = (pos.x or 0) + deltaX * step
        local newY = (pos.y or 0) + deltaY * step
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.point, newX, newY)
        local layoutName = LibEditMode and LibEditMode:GetActiveLayoutName()
        if layoutName then
            local positions = GetEditModeLayoutPositions()
            if not positions[layoutName] then positions[layoutName] = {} end
            positions[layoutName][unit] = { point = pos.point, x = newX, y = newY }
        end
        SetAnchorConfig(unit, {
            target = "UIParent",
            point = pos.point,
            relativePoint = pos.point,
            offsetX = newX,
            offsetY = newY,
        })
        UpdateEditOverlayInfo(unit)
    end)
    return btn
end

local function CreateEditOverlay(unit, frame)
    if frame.editModeOverlay then return end
    local overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 5)
    overlay:SetBackdrop({
        bgFile = TavernUI.WHITE8X8,
        edgeFile = TavernUI.WHITE8X8,
        edgeSize = 2,
    })
    overlay:SetBackdropColor(EDIT_OVERLAY_FILL_R, EDIT_OVERLAY_FILL_G, EDIT_OVERLAY_FILL_B, EDIT_OVERLAY_FILL_A)
    overlay:SetBackdropBorderColor(EDIT_OVERLAY_BORDER_R, EDIT_OVERLAY_BORDER_G, EDIT_OVERLAY_BORDER_B, 1)
    overlay:EnableMouse(false)

    local nudgeLeft = CreateNudgeButton(overlay, "LEFT", -1, 0, unit)
    nudgeLeft:SetPoint("RIGHT", overlay, "LEFT", -4, 0)
    local nudgeRight = CreateNudgeButton(overlay, "RIGHT", 1, 0, unit)
    nudgeRight:SetPoint("LEFT", overlay, "RIGHT", 4, 0)
    local nudgeUp = CreateNudgeButton(overlay, "UP", 0, 1, unit)
    nudgeUp:SetPoint("BOTTOM", overlay, "TOP", 0, 4)
    local nudgeDown = CreateNudgeButton(overlay, "DOWN", 0, -1, unit)
    nudgeDown:SetPoint("TOP", overlay, "BOTTOM", 0, -4)

    local infoText = overlay:CreateFontString(nil, "OVERLAY")
    infoText:SetFont(TavernUI.DEFAULT_FONT, 10, "OUTLINE")
    infoText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    infoText:SetTextColor(0.7, 0.7, 0.7, 1)
    overlay.infoText = infoText

    overlay:Hide()
    frame.editModeOverlay = overlay
end

function Anchoring:RegisterFrame(unit, frame)
    if not frame then return end
    local anchorName = "TavernUI.UF." .. unit
    local displayName = UNIT_DISPLAY_NAMES[unit] or unit

    Anchor:Register(anchorName, frame, {
        displayName = "TavernUI " .. displayName,
        category = "unitframes",
    })

    if useLibEditMode and not libEditModeRegistered[unit] then
        local defaultPos = GetBarPosition(unit)
        local default = defaultPos and { point = defaultPos.point or "CENTER", x = defaultPos.x or 0, y = defaultPos.y or 0 }
            or { point = "CENTER", x = 0, y = 0 }

        LibEditMode:AddFrame(frame, function(f, layoutName, point, x, y)
            local uKey = f.unitKey
            if not uKey then return end
            local positions = GetEditModeLayoutPositions()
            if not positions[layoutName] then positions[layoutName] = {} end
            positions[layoutName][uKey] = { point = point, x = x, y = y }

            SetAnchorConfig(uKey, {
                target = "UIParent",
                point = point,
                relativePoint = point,
                offsetX = x,
                offsetY = y,
            })
        end, default, "TavernUI " .. displayName)

        libEditModeRegistered[unit] = true
        frame.unitKey = unit
        CreateEditOverlay(unit, frame)
    end
end

function Anchoring:UnregisterFrame(unit, frame)
    ReleaseAnchor(unit)
    local anchorName = "TavernUI.UF." .. unit
    Anchor:Unregister(anchorName)

    libEditModeRegistered[unit] = nil
    if useLibEditMode and frame and LibEditMode then
        if LibEditMode.frameSelections then LibEditMode.frameSelections[frame] = nil end
        if LibEditMode.frameCallbacks then LibEditMode.frameCallbacks[frame] = nil end
        if LibEditMode.frameDefaults then LibEditMode.frameDefaults[frame] = nil end
        if LibEditMode.frameSettings then LibEditMode.frameSettings[frame] = nil end
        if LibEditMode.frameButtons then LibEditMode.frameButtons[frame] = nil end
    end
end

local function ProcessCombatApplyQueue()
    local queue = combatApplyQueue
    combatApplyQueue = {}
    for unit, _ in pairs(queue) do
        Anchoring:ApplyAnchor(unit)
    end
end

function Anchoring:ApplyAnchor(unit)
    local frame = GetFrameForUnit(unit)
    if not frame then return end

    if InCombatLockdown() then
        combatApplyQueue[unit] = true
        if not combatEventRegistered then
            combatEventRegistered = true
            combatEventFrame = CreateFrame("Frame")
            combatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            combatEventFrame:SetScript("OnEvent", function(_, event)
                if event == "PLAYER_REGEN_ENABLED" then
                    ProcessCombatApplyQueue()
                end
            end)
        end
        return
    end

    if useLibEditMode and libEditModeRegistered[unit] then
        local layoutName = LibEditMode:GetActiveLayoutName()
        if layoutName then
            local positions = GetEditModeLayoutPositions()
            local pos = positions[layoutName] and positions[layoutName][unit]
            if pos and pos.point then
                ReleaseAnchor(unit)
                frame:ClearAllPoints()
                frame:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
                return
            end
        end
    end

    if not ShouldApplyAnchor(unit) then
        ReleaseAnchor(unit)
        return
    end

    local unitType = GetUnitType(unit)
    local anchorConfig = module:GetSetting("units." .. unitType .. ".anchorConfig", {})

    ReleaseAnchor(unit)

    local handle = Anchor:AnchorTo(frame, {
        target = anchorConfig.target,
        point = anchorConfig.point or "CENTER",
        relativePoint = anchorConfig.relativePoint or "CENTER",
        offsetX = anchorConfig.offsetX or 0,
        offsetY = anchorConfig.offsetY or 0,
        deferred = true,
    })

    if handle then
        anchorHandles[unit] = handle
    end
end

local function IsBossOrArenaFollower(unit)
    return unit:match("^boss[2-5]$") or unit:match("^arena[2-3]$")
end

local function IsBossOrArena(unit)
    return unit:match("^boss%d") or unit:match("^arena%d")
end

local function ShowBossArenaForEditMode()
    for unit, frame in pairs(module.frames) do
        if frame and IsBossOrArena(unit) then
            UnregisterUnitWatch(frame)
            frame:Show()
        end
    end
end

local function HideBossArenaAfterEditMode()
    if module.testMode then return end
    for unit, frame in pairs(module.frames) do
        if frame and IsBossOrArena(unit) then
            RegisterUnitWatch(frame)
        end
    end
end

function Anchoring:UpdateAnchors()
    if not module:IsEnabled() then return end
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end

    for unit, frame in pairs(module.frames) do
        if frame and not IsBossOrArenaFollower(unit) then
            self:RegisterFrame(unit, frame)
            self:ApplyAnchor(unit)
        end
    end
end

local editModeStartPositions = {}
local editModeHooked = false

local function OnEditModeEnter()
    if useLibEditMode or not module:IsEnabled() then return end
    editModeStartPositions = {}
    for unit, frame in pairs(module.frames) do
        if frame and not IsBossOrArenaFollower(unit) then
            editModeStartPositions[unit] = GetBarPosition(unit)
            if not libEditModeRegistered[unit] then
                ReleaseAnchor(unit)
                frame:ClearAllPoints()
                local cx, cy = frame:GetCenter()
                local px, py = UIParent:GetCenter()
                if cx and cy and px and py then
                    frame:SetPoint("CENTER", UIParent, "CENTER", math.floor(cx - px + 0.5), math.floor(cy - py + 0.5))
                end
                SetBarDraggable(frame, true)
            end
        end
    end
end

local function OnEditModeSave()
    if useLibEditMode or not module:IsEnabled() then return end
    for unit, frame in pairs(module.frames) do
        if frame and not IsBossOrArenaFollower(unit) and not libEditModeRegistered[unit] then
            SetBarDraggable(frame, false)
        end
    end
    for unit, startPos in pairs(editModeStartPositions) do
        if HasPositionChanged(unit, startPos) then
            local current = GetBarPosition(unit)
            if current then
                local target = (current.relativeToName and current.relativeToName ~= "") and current.relativeToName or "UIParent"
                SetAnchorConfig(unit, {
                    target = target,
                    point = current.point or "CENTER",
                    relativePoint = current.relativePoint or "CENTER",
                    offsetX = current.x or 0,
                    offsetY = current.y or 0,
                })
            end
            ReleaseAnchor(unit)
        else
            Anchoring:ApplyAnchor(unit)
        end
    end
    editModeStartPositions = {}
end

local function HookEditMode()
    if useLibEditMode or editModeHooked then return end
    local EditModeManagerFrame = _G.EditModeManagerFrame
    if EditModeManagerFrame then
        EditModeManagerFrame:HookScript("OnShow", OnEditModeEnter)
        EditModeManagerFrame:HookScript("OnHide", OnEditModeSave)
    end
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            OnEditModeSave()
        end
    end)
    local C_EditMode = _G.C_EditMode
    if C_EditMode and C_EditMode.SaveLayouts then
        hooksecurefunc(C_EditMode, "SaveLayouts", OnEditModeSave)
    end
    editModeHooked = true
end

local function OnLibEditModeExit()
    if not module:IsEnabled() then return end

    HideBossArenaAfterEditMode()

    for unit, _ in pairs(libEditModeRegistered) do
        local f = GetFrameForUnit(unit)
        if f and f.editModeOverlay then
            f.editModeOverlay:Hide()
        end
        Anchoring:ApplyAnchor(unit)
    end
end

function Anchoring:Initialize()
    self:UpdateAnchors()
    HookEditMode()

    if useLibEditMode and LibEditMode.RegisterCallback then
        LibEditMode:RegisterCallback("enter", function()
            ShowBossArenaForEditMode()
            for unit, _ in pairs(libEditModeRegistered) do
                local f = GetFrameForUnit(unit)
                if f and f.editModeOverlay then
                    f.editModeOverlay:Show()
                    UpdateEditOverlayInfo(unit)
                end
            end
        end)

        LibEditMode:RegisterCallback("exit", OnLibEditModeExit)
    end
end

function Anchoring:Cleanup()
    if combatEventFrame then
        combatEventFrame:UnregisterAllEvents()
        combatEventFrame:SetScript("OnEvent", nil)
        combatEventFrame = nil
        combatEventRegistered = false
    end
    combatApplyQueue = {}

    for unit, frame in pairs(module.frames) do
        self:UnregisterFrame(unit, frame)
    end
end

module.Anchoring = Anchoring
