local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("UnitFrames")
if not module then return end

local WHITE8X8 = TavernUI.WHITE8X8

local Auras = {}
module.Auras = Auras

local function PostCreateButton(self, button)
    local borderWidth = TavernUI:GetThemeValue("borderWidth") or 1
    if borderWidth > 0 then
        local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        border:SetPoint("TOPLEFT", -borderWidth, borderWidth)
        border:SetPoint("BOTTOMRIGHT", borderWidth, -borderWidth)
        border:SetBackdrop({
            edgeFile = WHITE8X8,
            edgeSize = borderWidth,
        })
        local r, g, b, a = TavernUI:GetThemeColor("borderColor")
        border:SetBackdropBorderColor(r, g, b, a)
        border:SetFrameLevel(button:GetFrameLevel() + 2)
    end

    if button.Icon then
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function CreateAuraContainer(frame, db, tui_key)
    local container = CreateFrame("Frame", nil, frame)
    local size = db.size or 24
    local spacing = db.spacing or 2
    local num = db.num or 0
    local ap = db.anchorPoint or "TOPLEFT"
    container.size = size
    container.spacing = spacing
    container.num = num
    container.growthX = db.growthX or "RIGHT"
    container.growthY = db.growthY or "UP"
    container.initialAnchor = module.INITIAL_ANCHOR_MAP[ap] or "BOTTOMLEFT"
    container.onlyShowPlayer = db.onlyShowPlayer or false
    container.createdButtons = 0
    container.anchoredButtons = 0
    container.visibleButtons = 0
    container:SetSize(frame:GetWidth(), module.CalcContainerHeight(frame:GetWidth(), num, size, spacing))

    container:ClearAllPoints()
    if ap == "TOPLEFT" then
        container:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
    elseif ap == "TOPRIGHT" then
        container:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 4)
    elseif ap == "BOTTOMLEFT" then
        container:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    elseif ap == "BOTTOMRIGHT" then
        container:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
    end

    container.PostCreateButton = PostCreateButton
    frame[tui_key] = container
    return container
end

function Auras:CreateBuffs(frame, unit, db)
    local buffsDb = db.buffs or {}
    local container = CreateAuraContainer(frame, buffsDb, "TUI_Buffs")

    if buffsDb.enabled and buffsDb.num > 0 then
        frame.Buffs = container
    else
        container:Hide()
    end

    return container
end

function Auras:CreateDebuffs(frame, unit, db)
    local debuffsDb = db.debuffs or {}
    local container = CreateAuraContainer(frame, debuffsDb, "TUI_Debuffs")

    if debuffsDb.enabled and debuffsDb.num > 0 then
        frame.Debuffs = container
    else
        container:Hide()
    end

    return container
end
