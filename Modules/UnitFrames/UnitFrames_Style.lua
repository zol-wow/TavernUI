local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("UnitFrames")
if not module then return end

local Elements = module.Elements
local CastbarShared = module.CastbarShared
local Auras = module.Auras

function module:StyleFrame(frame, unit)
    local unitType = self:GetUnitType(unit)
    local db = self:GetUnitDB(unitType)
    if not db then return end

    frame:SetSize(db.width, db.height)
    frame:RegisterForClicks("AnyUp")
    if UnitFrame_OnEnter then
        frame:SetScript("OnEnter", UnitFrame_OnEnter)
    end
    if UnitFrame_OnLeave then
        frame:SetScript("OnLeave", UnitFrame_OnLeave)
    end

    Elements:CreateBackground(frame, db)
    Elements:CreateBorder(frame, db)
    Elements:CreateHealth(frame, unit, db)
    Elements:CreatePower(frame, unit, db)
    Elements:CreatePortrait(frame, unit, db)
    Elements:CreateIndicators(frame, unit, db)
    Elements:CreateClassPower(frame, unit, db)
    Elements:CreateInfoBar(frame, unit, db)

    CastbarShared:CreateCastbar(frame, unit, db)

    Auras:CreateBuffs(frame, unit, db)
    Auras:CreateDebuffs(frame, unit, db)

    Elements:CreateNameTag(frame, unit, db)
    Elements:CreateHealthTag(frame, unit, db)
    Elements:CreatePowerTag(frame, unit, db)

    self:ApplyBarLayout(frame, db)

    if db.rangeAlpha and db.rangeAlpha < 1 then
        frame.Range = {
            insideAlpha = 1,
            outsideAlpha = db.rangeAlpha,
        }
    end

    if module.Anchoring and not unit:match("^boss[2-5]$") and not unit:match("^arena[2-3]$") then
        module.Anchoring:RegisterFrame(unit, frame)
    end
end
