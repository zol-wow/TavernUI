local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("UnitFrames")
if not module then return end

local WHITE8X8 = TavernUI.WHITE8X8

local CastbarShared = {}
module.CastbarShared = CastbarShared

local function GetTexture()
    return TavernUI:GetThemeStatusBarTexture()
end

-- Resolve castbar color: class color > per-unit custom > theme fallback
local function GetCastbarColor(castbar, unit)
    if castbar.TUI_useClassColor then
        local _, class = UnitClass(unit)
        if class then
            local color = RAID_CLASS_COLORS[class]
            if color then
                return color.r, color.g, color.b, 1
            end
        end
    end

    if castbar.TUI_castColor then
        local c = castbar.TUI_castColor
        local r = c.r ~= nil and c.r or c[1]
        local g = c.g ~= nil and c.g or c[2]
        local b = c.b ~= nil and c.b or c[3]
        local a = c.a ~= nil and c.a or (c[4] or 1)
        return r, g, b, a
    end

    return TavernUI:GetThemeColor("castbarColor")
end

function CastbarShared:CreateCastbar(frame, unit, db)
    local cbDb = db.castbar or {}
    local anchor = cbDb.anchor or {}

    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(GetTexture())
    local r, g, b, a = TavernUI:GetThemeColor("castbarColor")
    castbar:SetStatusBarColor(r, g, b, a)
    castbar:SetHeight(cbDb.height or 20)

    -- Configurable anchor: default is below the frame
    local p1 = anchor.point or "TOPLEFT"
    local rp1 = anchor.relPoint or "BOTTOMLEFT"
    local offX = anchor.offX or 0
    local offY = anchor.offY or -4
    local p2 = anchor.point2 or "TOPRIGHT"
    local rp2 = anchor.relPoint2 or "BOTTOMRIGHT"
    castbar:SetPoint(p1, frame, rp1, offX, offY)
    castbar:SetPoint(p2, frame, rp2, offX, offY)

    local bg = castbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(TavernUI:GetThemeColor("frameBg"))

    local spark = castbar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(2, cbDb.height or 20)
    spark:SetColorTexture(1, 1, 1, 0.8)
    castbar.Spark = spark

    if cbDb.showText ~= false then
        local text = castbar:CreateFontString(nil, "OVERLAY")
        text:SetFont(TavernUI.DEFAULT_FONT, 10, "OUTLINE")
        text:SetPoint("LEFT", 4, 0)
        text:SetJustifyH("LEFT")
        local tr, tg, tb = TavernUI:GetThemeColor("textColor")
        text:SetTextColor(tr, tg, tb, 1)
        castbar.Text = text
    end

    if cbDb.showTime ~= false then
        local time = castbar:CreateFontString(nil, "OVERLAY")
        time:SetFont(TavernUI.DEFAULT_FONT, 10, "OUTLINE")
        time:SetPoint("RIGHT", -4, 0)
        time:SetJustifyH("RIGHT")
        local tr, tg, tb = TavernUI:GetThemeColor("textColor")
        time:SetTextColor(tr, tg, tb, 1)
        castbar.Time = time
    end

    if cbDb.showIcon ~= false then
        local icon = castbar:CreateTexture(nil, "ARTWORK")
        icon:SetSize(cbDb.height or 20, cbDb.height or 20)
        icon:SetPoint("RIGHT", castbar, "LEFT", -4, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        castbar.Icon = icon
    end

    local shield = castbar:CreateTexture(nil, "OVERLAY", nil, 1)
    shield:SetSize(16, 16)
    shield:SetPoint("CENTER", castbar, "LEFT", 0, 0)
    castbar.Shield = shield

    local borderWidth = TavernUI:GetThemeValue("borderWidth") or 1
    local border = CreateFrame("Frame", nil, castbar, "BackdropTemplate")
    border:SetFrameLevel(castbar:GetFrameLevel() + 2)
    if borderWidth > 0 then
        border:SetPoint("TOPLEFT", -borderWidth, borderWidth)
        border:SetPoint("BOTTOMRIGHT", borderWidth, -borderWidth)
        border:SetBackdrop({ edgeFile = WHITE8X8, edgeSize = borderWidth })
        border:SetBackdropBorderColor(TavernUI:GetThemeColor("borderColor"))
    else
        border:Hide()
    end
    castbar.TUI_Border = border

    castbar.TUI_castColor = TavernUI:GetCastbarSetting(unit, "barColor")
    castbar.TUI_useClassColor = TavernUI:GetCastbarSetting(unit, "useClassColor", false)

    castbar.PostCastStart = function(self, castUnit)
        -- Sanitize oUF's notInterruptible (may be a raw secret value in combat)
        if self.notInterruptible ~= nil and canaccessvalue and not canaccessvalue(self.notInterruptible) then
            self.notInterruptible = nil
        end

        local cr, cg, cb, ca = GetCastbarColor(self, castUnit)
        self:SetStatusBarColor(cr, cg, cb, ca)
    end

    castbar.PostCastInterruptible = function(self, castUnit)
        if self.notInterruptible then
            if self.TUI_notInterruptibleColor then
                local c = self.TUI_notInterruptibleColor
                local r = c.r ~= nil and c.r or c[1]
                local g = c.g ~= nil and c.g or c[2]
                local b = c.b ~= nil and c.b or c[3]
                local a = c.a ~= nil and c.a or (c[4] or 1)
                self:SetStatusBarColor(r, g, b, a)
            else
                local cr, cg, cb, ca = TavernUI:GetThemeColor("castbarNotInterruptibleColor")
                self:SetStatusBarColor(cr, cg, cb, ca)
            end
        else
            local cr, cg, cb, ca = GetCastbarColor(self, castUnit)
            self:SetStatusBarColor(cr, cg, cb, ca)
        end
    end

    frame.TUI_Castbar = castbar

    local unitType = module:GetUnitType(unit) or unit
    local cbHandling = TavernUI.oUFFactory
        and TavernUI.oUFFactory.IsCastbarModuleHandling
        and TavernUI.oUFFactory.IsCastbarModuleHandling(unitType)
    if db.showCastbar and not cbHandling then
        frame.Castbar = castbar
    else
        castbar:Hide()
    end

    return castbar
end

-- Apply color properties from standalone Castbar module settings
function CastbarShared:ApplyStandaloneColors(castbar, unit, settings)
    if not castbar or not settings then return end

    if settings.barColor then
        castbar.TUI_castColor = settings.barColor
    end
    castbar.TUI_useClassColor = settings.useClassColor or false

    if settings.notInterruptibleColor then
        castbar.TUI_notInterruptibleColor = settings.notInterruptibleColor
    end

    -- Apply immediately so the bar shows correct color before first cast
    local r, g, b, a = GetCastbarColor(castbar, unit)
    castbar:SetStatusBarColor(r, g, b, a)
end
