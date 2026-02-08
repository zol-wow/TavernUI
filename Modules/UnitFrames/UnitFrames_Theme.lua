local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("UnitFrames")
if not module then return end

local HEALTH_COLOR_MODES = {
    CLASS = "Class Color",
    REACTION = "Reaction Color",
    HEALTH_GRADIENT = "Health Gradient",
    SOLID = "Solid Color",
}

local POWER_COLOR_MODES = {
    POWER_TYPE = "Power Type Color",
    CLASS = "Class Color",
    SOLID = "Solid Color",
}

local function ColorGet(key)
    return function()
        local c = module:GetSetting(key, { r = 1, g = 1, b = 1, a = 1 })
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end
end

local function ColorSet(key)
    return function(_, r, g, b, a)
        module:SetSetting(key, { r = r, g = g, b = b, a = a })
        module:RefreshAllFrames()
    end
end

function module:BuildThemeOptions()
    return {
        type = "group",
        name = "Theme",
        order = 0,
        args = {
            globalHeader = {
                type = "header",
                name = "Global",
                order = 1,
            },
            statusBarTexture = {
                type = "select",
                name = "Statusbar Texture",
                desc = "Texture used for status bars.",
                order = 10,
                values = function()
                    return TavernUI:GetLSMMediaDropdownValues("statusbar", "", "Default")
                end,
                get = function()
                    local v = module:GetSetting("statusBarTexture", "")
                    return (v and v ~= "") and v or ""
                end,
                set = function(_, value)
                    module:SetSetting("statusBarTexture", (value and value ~= "") and value or "")
                    module:RefreshAllFrames()
                end,
            },
            frameBg = {
                type = "color",
                name = "Frame Background",
                desc = "Default background color for frames.",
                order = 20,
                hasAlpha = true,
                get = ColorGet("frameBg"),
                set = ColorSet("frameBg"),
            },
            borderColor = {
                type = "color",
                name = "Border Color",
                desc = "Default border color for frames.",
                order = 30,
                hasAlpha = true,
                get = ColorGet("borderColor"),
                set = ColorSet("borderColor"),
            },
            borderWidth = {
                type = "range",
                name = "Border Width",
                desc = "Border thickness in pixels.",
                order = 40,
                min = 0,
                max = 4,
                step = 1,
                get = function() return module:GetSetting("borderWidth", 1) end,
                set = function(_, value)
                    module:SetSetting("borderWidth", value)
                    module:RefreshAllFrames()
                end,
            },
            textColor = {
                type = "color",
                name = "Text Color",
                desc = "Default text color.",
                order = 50,
                hasAlpha = true,
                get = ColorGet("textColor"),
                set = ColorSet("textColor"),
            },
            healthHeader = {
                type = "header",
                name = "Health Bars",
                order = 100,
            },
            healthColorMode = {
                type = "select",
                name = "Health Color Mode",
                desc = "How health bars are colored.",
                order = 110,
                values = HEALTH_COLOR_MODES,
                get = function() return module:GetSetting("healthColorMode", "CLASS") end,
                set = function(_, value)
                    module:SetSetting("healthColorMode", value)
                    module:RefreshAllFrames()
                end,
            },
            healthColor = {
                type = "color",
                name = "Health Solid Color",
                desc = "Used when Health Color Mode is set to Solid.",
                order = 120,
                hasAlpha = true,
                get = ColorGet("healthColor"),
                set = ColorSet("healthColor"),
            },
            healthBgColor = {
                type = "color",
                name = "Health Background",
                desc = "Background color behind the health bar.",
                order = 130,
                hasAlpha = true,
                get = ColorGet("healthBgColor"),
                set = ColorSet("healthBgColor"),
            },
            powerHeader = {
                type = "header",
                name = "Power Bars",
                order = 200,
            },
            powerColorMode = {
                type = "select",
                name = "Power Color Mode",
                desc = "How power bars are colored.",
                order = 210,
                values = POWER_COLOR_MODES,
                get = function() return module:GetSetting("powerColorMode", "POWER_TYPE") end,
                set = function(_, value)
                    module:SetSetting("powerColorMode", value)
                    module:RefreshAllFrames()
                end,
            },
            powerColor = {
                type = "color",
                name = "Power Solid Color",
                desc = "Used when Power Color Mode is set to Solid.",
                order = 220,
                hasAlpha = true,
                get = ColorGet("powerColor"),
                set = ColorSet("powerColor"),
            },
            powerBgColor = {
                type = "color",
                name = "Power Background",
                desc = "Background color behind the power bar.",
                order = 230,
                hasAlpha = true,
                get = ColorGet("powerBgColor"),
                set = ColorSet("powerBgColor"),
            },
            castbarHeader = {
                type = "header",
                name = "Castbar",
                order = 300,
            },
            castbarColor = {
                type = "color",
                name = "Castbar Color",
                desc = "Default castbar fill color.",
                order = 310,
                hasAlpha = true,
                get = ColorGet("castbarColor"),
                set = ColorSet("castbarColor"),
            },
            castbarNotInterruptibleColor = {
                type = "color",
                name = "Not Interruptible Color",
                desc = "Castbar color when cast cannot be interrupted.",
                order = 320,
                hasAlpha = true,
                get = ColorGet("castbarNotInterruptibleColor"),
                set = ColorSet("castbarNotInterruptibleColor"),
            },
        },
    }
end
