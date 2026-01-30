local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local module = TavernUI:GetModule("DataBar")
local LibSharedMedia = LibStub("LibSharedMedia-3.0", true)
local Anchor = LibStub("LibAnchorRegistry-1.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)

local function ensureBarAnchorConfig(bar, defaults)
    if not bar.anchorConfig then
        bar.anchorConfig = defaults or {
            target = "UIParent",
            point = "CENTER",
            relativePoint = "CENTER",
            offsetX = 0,
            offsetY = 0,
        }
    end
    return bar.anchorConfig
end

local function ensureDualAnchorConfig(bar)
    if not bar.anchorConfig then
        bar.anchorConfig = {
            target = "UIParent",
            point = "LEFT",
            relativePoint = "LEFT",
            offsetX = 0,
            offsetY = 0,
            useDualAnchor = true,
            target2 = "UIParent",
            point2 = "RIGHT",
            relativePoint2 = "RIGHT",
            offsetX2 = 0,
            offsetY2 = 0,
        }
    else
        bar.anchorConfig.useDualAnchor = true
        if not bar.anchorConfig.target2 then
            bar.anchorConfig.target2 = "UIParent"
            bar.anchorConfig.point2 = "RIGHT"
            bar.anchorConfig.relativePoint2 = "RIGHT"
            bar.anchorConfig.offsetX2 = 0
            bar.anchorConfig.offsetY2 = 0
        end
    end
    return bar.anchorConfig
end

local function ensureSlotAnchorConfig(slot, barAnchorName)
    if not slot.anchorConfig then
        slot.anchorConfig = {
            target = barAnchorName,
            point = "CENTER",
            relativePoint = "CENTER",
            offsetX = 0,
            offsetY = 0,
        }
    else
        slot.anchorConfig.target = barAnchorName
    end
    return slot.anchorConfig
end

local function createAnchorOptionSetter(barId, bar, field, default)
    return function(_, value)
        ensureBarAnchorConfig(bar)
        module:SetSetting(string.format("bars[%d].anchorConfig.%s", barId, field), value)
        module:UpdateBar(barId)
    end
end

local function createDualAnchorOptionSetter(barId, bar, field, default)
    return function(_, value)
        ensureDualAnchorConfig(bar)
        module:SetSetting(string.format("bars[%d].anchorConfig.%s", barId, field), value)
        module:UpdateBar(barId)
    end
end

local function createSlotAnchorOptionSetter(barId, slotIndex, slot, barAnchorName, field, default)
    return function(_, value)
        ensureSlotAnchorConfig(slot, barAnchorName)
        module:SetSetting(string.format("bars[%d].slots[%d].anchorConfig.%s", barId, slotIndex, field), value)
        module:UpdateBar(barId)
    end
end

local function createSimpleOptionSetter(barId, settingPath)
    return function(_, value)
        module:SetSetting(string.format("bars[%d].%s", barId, settingPath), value)
        module:UpdateBar(barId)
    end
end

local anchorPointValues = {
    TOPLEFT = "TOPLEFT",
    TOP = "TOP",
    TOPRIGHT = "TOPRIGHT",
    LEFT = "LEFT",
    CENTER = "CENTER",
    RIGHT = "RIGHT",
    BOTTOMLEFT = "BOTTOMLEFT",
    BOTTOM = "BOTTOM",
    BOTTOMRIGHT = "BOTTOMRIGHT",
}

local function addAnchorOption(args, barId, bar, prefix, order, field, default, isDual)
    local name = prefix .. (field:sub(1,1):upper() .. field:sub(2))
    local getter = function() return bar.anchorConfig and bar.anchorConfig[field] or default end
    local setter = isDual and createDualAnchorOptionSetter(barId, bar, field, default) or createAnchorOptionSetter(barId, bar, field, default)
    local disabled = isDual and function() return not (bar.anchorConfig and bar.anchorConfig.useDualAnchor) end or nil

    if field == "target" or field == "target2" then
        args[prefix .. field] = {
            type = "select",
            name = name,
            desc = "Anchor target frame",
            order = order,
            disabled = disabled,
            values = function()
                local vals = { UIParent = "Screen" }
                if Anchor then
                    local dropdownData = Anchor:GetDropdownData()
                    for _, entry in ipairs(dropdownData) do
                        vals[entry.value] = entry.text
                    end
                end
                return vals
            end,
            get = function()
                local val = bar.anchorConfig and bar.anchorConfig[field]
                if not val or val == "" then return "UIParent" end
                return val
            end,
            set = function(_, value)
                if isDual then
                    ensureDualAnchorConfig(bar)
                else
                    ensureBarAnchorConfig(bar, {target = value, point = "CENTER", relativePoint = "CENTER", offsetX = 0, offsetY = 0})
                end
                module:SetSetting(string.format("bars[%d].anchorConfig.%s", barId, field), value)
                module:UpdateBar(barId)
            end,
        }
    elseif field == "point" or field == "point2" or field:find("Point") then
        local descText = "Point on the bar to anchor"
        if field == "relativePoint" or field == "relativePoint2" then
            descText = "Point on the target to anchor to"
        end
        args[prefix .. field] = {
            type = "select",
            name = name,
            desc = descText,
            order = order,
            disabled = disabled,
            values = anchorPointValues,
            get = getter,
            set = setter,
        }
    else
        args[prefix .. field] = {
            type = "range",
            name = name,
            desc = (field:find("X") and "Horizontal" or "Vertical") .. " offset",
            order = order,
            min = -500,
            max = 500,
            step = 1,
            disabled = disabled,
            get = getter,
            set = setter,
        }
    end
end

function module:RegisterOptions()
    if not self.optionsBuilt then
        self:BuildOptions()
        self.optionsBuilt = true
    end
end

function module:RefreshOptions(rebuild)
    if rebuild then
        self.optionsBuilt = false
        self:BuildOptions()
        self.optionsBuilt = true
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("TavernUI")
end

function module:BuildOptions()
    local options = {
        type = "group",
        name = "DataBar",
        childGroups = "tab",
        args = {
            bars = {
                type = "group",
                name = "Bars",
                desc = "Configure your information bars",
                order = 10,
                childGroups = "select",
                args = {},
            },
        },
    }

    self:BuildBarListOptions(options.args.bars.args)

    TavernUI:RegisterModuleOptions("DataBar", options, "DataBar")
end

function module:BuildBarListOptions(args)
    local bars = self:GetAllBars()

    args.addBar = {
        type = "execute",
        name = "Create New Bar",
        desc = "Create a new information bar",
        order = 1,
        func = function()
            self:CreateBar("New Bar")
            self:RefreshOptions(true)
        end,
    }

    local barIds = {}
    for barId in pairs(bars) do
        table.insert(barIds, barId)
    end
    table.sort(barIds)

    for i, barId in ipairs(barIds) do
        local bar = bars[barId]
        local barName = bar.name or ("Bar " .. barId)

        local barArgs = {
            type = "group",
            name = barName,
            desc = string.format("Configure %s", barName),
            order = (i + 1) * 10,
            childGroups = "tab",
            args = {},
        }

        local generalArgs = {
            type = "group",
            name = "General",
            order = 10,
            args = {},
        }

        generalArgs.args.enabled = {
            type = "toggle",
            name = "Enabled",
            desc = "Enable or disable this bar",
            order = 1,
            get = function() return bar.enabled end,
            set = function(_, value)
                self:SetSetting(string.format("bars[%d].enabled", barId), value)
                self:UpdateBar(barId)
            end,
        }

        generalArgs.args.name = {
            type = "input",
            name = "Name",
            desc = "Name of this bar",
            order = 2,
            get = function() return bar.name or "" end,
            set = function(_, value)
                self:SetSetting(string.format("bars[%d].name", barId), value)
                if Anchor and self.anchorNames[barId] then
                    Anchor:UpdateMetadata(self.anchorNames[barId], {
                        displayName = value,
                    })
                end
                self:RefreshOptions(true)
            end,
        }

        generalArgs.args.delete = {
            type = "execute",
            name = "Delete Bar",
            desc = "Permanently delete this bar",
            order = 3,
            confirm = true,
            func = function()
                self:DeleteBar(barId)
                self:RefreshOptions(true)
            end,
        }

        barArgs.args.general = generalArgs
        barArgs.args.slots = {
            type = "group",
            name = "Slots",
            desc = "Configure datatext slots for this bar",
            order = 20,
            args = {},
        }
        barArgs.args.styling = {
            type = "group",
            name = "Styling",
            desc = "Configure the appearance of this bar",
            order = 30,
            args = {},
        }
        barArgs.args.position = {
            type = "group",
            name = "Position",
            desc = "Configure the position and anchoring of this bar",
            order = 40,
            args = {},
        }

        self:BuildSlotOptions(barArgs.args.slots.args, barId, bar)
        self:BuildStylingOptions(barArgs.args.styling.args, barId, bar)
        self:BuildPositionOptions(barArgs.args.position.args, barId, bar)

        args["bar" .. barId] = barArgs
    end
end

local function getDatatextValues()
    local values = {}
    for name in pairs(module:GetAllDatatexts()) do
        values[name] = name
    end
    return values
end

local function getDatatextSorting()
    local sorting = {}
    local builtinNames, ldbNames = {}, {}
    for name in pairs(module:GetAllDatatexts()) do
        if name:sub(1, 5) == "LDB: " then
            table.insert(ldbNames, name)
        else
            table.insert(builtinNames, name)
        end
    end
    table.sort(builtinNames)
    table.sort(ldbNames)
    for _, n in ipairs(builtinNames) do table.insert(sorting, n) end
    for _, n in ipairs(ldbNames) do table.insert(sorting, n) end
    return sorting
end

function module:BuildSlotOptions(args, barId, bar)
    args.addSlot = {
        type = "select",
        name = "Add Datatext",
        desc = "Add a new datatext slot to this bar",
        order = 1,
        values = getDatatextValues,
        sorting = getDatatextSorting,
        get = function() return "" end,
        set = function(_, value)
            if value == "" then return end
            self:AddSlot(barId, nil, value)
            local newSlotIndex = #bar.slots
            self:RefreshOptions(true)
            if AceConfigDialog then
                C_Timer.After(0, function()
                    AceConfigDialog:SelectGroup("TavernUI", "modules", "DataBar", "bars", "bar" .. barId, "slots", "slot" .. newSlotIndex)
                end)
            end
        end,
    }

    args.spacer1 = {
        type = "description",
        name = " ",
        order = 3,
    }

    for slotIndex, slot in ipairs(bar.slots) do
        local slotArgs = {
            type = "group",
            name = string.format("Slot %d", slotIndex),
            desc = string.format("Configure slot %d", slotIndex),
            order = (slotIndex + 1) * 10,
            args = {},
        }

        slotArgs.args.datatext = {
            type = "select",
            name = "Datatext",
            desc = "Select which datatext to display",
            order = 1,
            values = getDatatextValues,
            sorting = getDatatextSorting,
            get = function() return slot.datatext or "" end,
            set = function(_, value)
                local path = string.format("bars[%d].slots[%d]", barId, slotIndex)
                local oldDt = self:GetDatatext(slot.datatext or "")
                if oldDt and oldDt.options then
                    for key in pairs(oldDt.options) do
                        self:SetSetting(path .. "." .. key, nil)
                    end
                end
                self:SetSetting(path .. ".datatext", value)
                self:SetSetting(path .. ".width", nil)
                self:SetSetting(path .. ".labelMode", nil)
                self:SetSetting(path .. ".anchorConfig", nil)
                self:UpdateBar(barId)
                self:RefreshOptions(true)
            end,
        }

        slotArgs.args.width = {
            type = "input",
            name = "Width",
            desc = "Slot width (leave empty for auto)",
            order = 4,
            get = function() return slot.width and tostring(slot.width) or "" end,
            set = function(_, value)
                local width = nil
                if value ~= "" and value ~= "nil" then
                    width = tonumber(value)
                end
                self:SetSetting(string.format("bars[%d].slots[%d].width", barId, slotIndex), width)
                self:UpdateBar(barId)
            end,
        }

        slotArgs.args.labelMode = {
            type = "select",
            name = "Label",
            desc = "Show label before value",
            order = 7,
            values = {none = "None", short = "Short", full = "Full"},
            get = function() return slot.labelMode or "none" end,
            set = function(_, value)
                self:SetSetting(string.format("bars[%d].slots[%d].labelMode", barId, slotIndex), value)
                self:UpdateBar(barId)
            end,
        }

        local selectedDatatext = self:GetDatatext(slot.datatext or "")
        if selectedDatatext and selectedDatatext.options then
            local optOrder = 8
            for key, opt in pairs(selectedDatatext.options) do
                slotArgs.args["dt_" .. key] = {
                    type = opt.type or "select",
                    name = opt.name or key,
                    desc = opt.desc,
                    order = optOrder,
                    values = opt.values,
                    get = function() return slot[key] or opt.default end,
                    set = function(_, value)
                        self:SetSetting(string.format("bars[%d].slots[%d].%s", barId, slotIndex, key), value)
                        self:UpdateBar(barId)
                    end,
                }
                optOrder = optOrder + 1
            end
        end

        slotArgs.args.spacer1 = {
            type = "description",
            name = " ",
            order = 10,
        }

        self:BuildSlotPositionOptions(slotArgs.args, barId, slotIndex, slot, bar)

        slotArgs.args.spacer2 = {
            type = "description",
            name = " ",
            order = 90,
        }

        slotArgs.args.remove = {
            type = "execute",
            name = "Remove Slot",
            desc = "Remove this slot from the bar",
            order = 100,
            confirm = true,
            func = function()
                self:RemoveSlot(barId, slotIndex)
                self:RefreshOptions(true)
            end,
        }

        args["slot" .. slotIndex] = slotArgs
    end
end

function module:BuildStylingOptions(args, barId, bar)
    local function addHeader(name, order)
        args[name .. "Header"] = {type = "header", name = name, order = order}
    end

    local function addRange(key, name, desc, order, min, max, step)
        args[key] = {type = "range", name = name, desc = desc, order = order, min = min, max = max, step = step,
            get = function() return bar[key] end, set = createSimpleOptionSetter(barId, key)}
    end

    local function addColor(key, name, desc, order, getColor, setColor)
        args[key] = {type = "color", name = name, desc = desc, order = order, hasAlpha = false,
            get = getColor, set = setColor}
    end

    addHeader("Size", 10)
    addRange("width", "Width", "Bar width in pixels", 11, 50, 2560, 1)
    addRange("height", "Height", "Bar height in pixels", 12, 20, 200, 1)

    addHeader("Background", 20)
    args.backgroundType = {type = "select", name = "Background Type", desc = "Type of background to display", order = 21,
        values = {solid = "Solid Color", texture = "Texture"},
        get = function() return bar.background.type or "solid" end,
        set = createSimpleOptionSetter(barId, "background.type")}
    args.backgroundColor = {type = "color", name = "Background Color", desc = "Background color and opacity", order = 22,
        hasAlpha = true,
        get = function()
            local c = bar.background.color
            return c.r, c.g, c.b, bar.background.opacity or 1
        end,
        set = function(_, r, g, b, a)
            self:SetSetting(string.format("bars[%d].background.color", barId), {r = r, g = g, b = b})
            self:SetSetting(string.format("bars[%d].background.opacity", barId), a)
            self:UpdateBar(barId)
        end}
    if LibSharedMedia then
        local function getStatusbarTextures()
            local textures = {}
            for _, name in ipairs(LibSharedMedia:List("statusbar")) do
                textures[name] = name
            end
            return textures
        end
        args.backgroundTexture = {type = "select", name = "Background Texture", desc = "LibSharedMedia statusbar texture", order = 24,
            values = getStatusbarTextures,
            hidden = function() return bar.background.type ~= "texture" end,
            get = function() return bar.background.texture or "" end,
            set = function(_, value)
                self:SetSetting(string.format("bars[%d].background.texture", barId), value)
                self:UpdateBar(barId)
            end}
    end

    addHeader("Text", 30)
    addRange("fontSize", "Font Size", "Font size for datatext", 31, 8, 32, 1)
    addColor("textColor", "Text Color", "Default text color for datatexts", 32,
        function() local c = bar.textColor; return c.r, c.g, c.b end,
        function(_, r, g, b) self:SetSetting(string.format("bars[%d].textColor", barId), {r = r, g = g, b = b}); self:UpdateBar(barId) end)
    args.useClassColor = {
        type = "toggle",
        name = "Use Class Color",
        desc = "Use player class color for datatext values",
        order = 33,
        get = function() return bar.useClassColor end,
        set = function(_, value)
            self:SetSetting(string.format("bars[%d].useClassColor", barId), value)
            self:UpdateBar(barId)
        end,
    }

    addColor("labelColor", "Label Color", "Color for label prefix text", 34,
        function() local c = bar.labelColor or {r = 0.7, g = 0.7, b = 0.7}; return c.r, c.g, c.b end,
        function(_, r, g, b) self:SetSetting(string.format("bars[%d].labelColor", barId), {r = r, g = g, b = b}); self:UpdateBar(barId) end)
    args.useLabelClassColor = {
        type = "toggle",
        name = "Use Class Color for Labels",
        desc = "Use player class color for label prefix text",
        order = 35,
        get = function() return bar.useLabelClassColor end,
        set = function(_, value)
            self:SetSetting(string.format("bars[%d].useLabelClassColor", barId), value)
            self:UpdateBar(barId)
        end,
    }

    addHeader("Border", 40)
    args.borderEnabled = {
        type = "toggle",
        name = "Show Border",
        desc = "Show border around the bar",
        order = 41,
        get = function() return bar.borders.top.enabled end,
        set = function(_, value)
            local path = "bars[%d].borders.%s.enabled"
            self:SetSetting(string.format(path, barId, "top"), value)
            self:SetSetting(string.format(path, barId, "bottom"), value)
            self:SetSetting(string.format(path, barId, "left"), value)
            self:SetSetting(string.format(path, barId, "right"), value)
            self:UpdateBar(barId)
        end,
    }
    args.borderColor = {
        type = "color",
        name = "Border Color",
        desc = "Border color",
        order = 42,
        hasAlpha = false,
        get = function()
            local c = bar.borders.top.color
            return c.r, c.g, c.b
        end,
        set = function(_, r, g, b)
            local color = {r = r, g = g, b = b}
            local path = "bars[%d].borders.%s.color"
            self:SetSetting(string.format(path, barId, "top"), color)
            self:SetSetting(string.format(path, barId, "bottom"), CopyTable(color))
            self:SetSetting(string.format(path, barId, "left"), CopyTable(color))
            self:SetSetting(string.format(path, barId, "right"), CopyTable(color))
            self:UpdateBar(barId)
        end,
    }
    args.borderWidth = {
        type = "range",
        name = "Border Width",
        desc = "Border width in pixels",
        order = 43,
        min = 1,
        max = 5,
        step = 1,
        get = function() return bar.borders.top.width or 1 end,
        set = function(_, value)
            local path = "bars[%d].borders.%s.width"
            self:SetSetting(string.format(path, barId, "top"), value)
            self:SetSetting(string.format(path, barId, "bottom"), value)
            self:SetSetting(string.format(path, barId, "left"), value)
            self:SetSetting(string.format(path, barId, "right"), value)
            self:UpdateBar(barId)
        end,
    }

    addHeader("Layout", 50)
    args.growthDirection = {type = "select", name = "Growth Direction", desc = "Direction slots grow in", order = 51,
        values = {horizontal = "Horizontal", vertical = "Vertical"},
        get = function() return bar.growthDirection end,
        set = createSimpleOptionSetter(barId, "growthDirection")}
    addRange("spacing", "Spacing", "Spacing between slots", 52, 0, 50, 1)
end

function module:BuildPositionOptions(args, barId, bar)
    if not Anchor then
        args.noAnchor = {type = "description", name = "LibAnchorRegistry not available", order = 1}
        return
    end

    args.useDualAnchor = {
        type = "toggle",
        name = "Use Dual Anchor",
        desc = "Enable dual anchor mode to stretch the bar between two points",
        order = 1,
        get = function() return bar.anchorConfig and bar.anchorConfig.useDualAnchor or false end,
        set = function(_, value)
            if value then ensureDualAnchorConfig(bar) end
            self:SetSetting(string.format("bars[%d].anchorConfig.useDualAnchor", barId), value)
            self:UpdateBar(barId)
        end,
    }

    args.anchorHeader = {type = "header", name = "First Anchor Point", order = 10}
    addAnchorOption(args, barId, bar, "anchor", 11, "target", "UIParent", false)
    addAnchorOption(args, barId, bar, "anchor", 12, "point", "CENTER", false)
    addAnchorOption(args, barId, bar, "relative", 13, "relativePoint", "CENTER", false)
    addAnchorOption(args, barId, bar, "", 14, "offsetX", 0, false)
    addAnchorOption(args, barId, bar, "", 15, "offsetY", 0, false)

    args.dualAnchorHeader = {type = "header", name = "Second Anchor Point", order = 20, disabled = function() return not (bar.anchorConfig and bar.anchorConfig.useDualAnchor) end}
    addAnchorOption(args, barId, bar, "anchor", 21, "target2", "UIParent", true)
    addAnchorOption(args, barId, bar, "anchor", 22, "point2", "RIGHT", true)
    addAnchorOption(args, barId, bar, "relative", 23, "relativePoint2", "RIGHT", true)
    addAnchorOption(args, barId, bar, "", 24, "offsetX2", 0, true)
    addAnchorOption(args, barId, bar, "", 25, "offsetY2", 0, true)

    args.clearAnchor = {
        type = "execute",
        name = "Clear Anchor",
        desc = "Remove all anchor configuration",
        order = 100,
        func = function() self:SetSetting(string.format("bars[%d].anchorConfig", barId), nil); self:UpdateBar(barId) end,
    }
end

function module:BuildSlotPositionOptions(args, barId, slotIndex, slot, bar)
    if not Anchor then
        args.noAnchor = {
            type = "description",
            name = "LibAnchorRegistry not available",
            order = 1,
        }
        return
    end

    local barAnchorName = self.anchorNames[barId] or ("TavernUI.DataBar" .. barId)

    args.anchorPoint = {
        type = "select",
        name = "Anchor Point",
        desc = "Point on the slot to anchor",
        order = 1,
        values = anchorPointValues,
        get = function() return slot.anchorConfig and slot.anchorConfig.point or "CENTER" end,
        set = createSlotAnchorOptionSetter(barId, slotIndex, slot, barAnchorName, "point", "CENTER"),
    }

    args.relativePoint = {
        type = "select",
        name = "Relative Point",
        desc = "Point on the bar to anchor to",
        order = 2,
        values = anchorPointValues,
        get = function() return slot.anchorConfig and slot.anchorConfig.relativePoint or "CENTER" end,
        set = createSlotAnchorOptionSetter(barId, slotIndex, slot, barAnchorName, "relativePoint", "CENTER"),
    }

    args.offsetX = {
        type = "range",
        name = "Offset X",
        desc = "Horizontal offset",
        order = 3,
        min = -500,
        max = 500,
        step = 1,
        get = function() return slot.anchorConfig and slot.anchorConfig.offsetX or 0 end,
        set = createSlotAnchorOptionSetter(barId, slotIndex, slot, barAnchorName, "offsetX", 0),
    }

    args.offsetY = {
        type = "range",
        name = "Offset Y",
        desc = "Vertical offset",
        order = 4,
        min = -500,
        max = 500,
        step = 1,
        get = function() return slot.anchorConfig and slot.anchorConfig.offsetY or 0 end,
        set = createSlotAnchorOptionSetter(barId, slotIndex, slot, barAnchorName, "offsetY", 0),
    }

    args.clearAnchor = {
        type = "execute",
        name = "Clear Anchor",
        desc = "Remove anchor configuration and use auto layout",
        order = 5,
        func = function()
            self:SetSetting(string.format("bars[%d].slots[%d].anchorConfig", barId, slotIndex), nil)
            self:UpdateBar(barId)
        end,
    }
end
