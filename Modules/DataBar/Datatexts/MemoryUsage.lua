local TavernUI = LibStub("AceAddon-3.0"):GetAddon("TavernUI")
local DataBar = TavernUI:GetModule("DataBar")

local min = math.min

local cachedAddons = {}
local cachedTotal = 0
local pendingUpdate = false

local function CollectMemoryData()
    local count = 0
    local total = 0
    for i = 1, C_AddOns.GetNumAddOns() do
        local mem = GetAddOnMemoryUsage(i)
        if mem > 0 then
            count = count + 1
            total = total + mem
            local entry = cachedAddons[count]
            if entry then
                entry.name = C_AddOns.GetAddOnInfo(i)
                entry.mem = mem
            else
                cachedAddons[count] = { name = C_AddOns.GetAddOnInfo(i), mem = mem }
            end
        end
    end
    for i = count + 1, #cachedAddons do
        cachedAddons[i] = nil
    end
    table.sort(cachedAddons, function(a, b) return a.mem > b.mem end)
    cachedTotal = total
    pendingUpdate = false
end

DataBar:RegisterDatatext("Memory Usage", {
    label = "Memory",
    labelShort = "Mem",
    pollInterval = 10,
    update = function()
        if not pendingUpdate then
            pendingUpdate = true
            UpdateAddOnMemoryUsage()
            C_Timer.After(0, CollectMemoryData)
        end
        return DataBar:FormatMemory(cachedTotal)
    end,
    tooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Addon Memory", 1, 1, 1)
        GameTooltip:AddLine(" ")
        for i = 1, min(#cachedAddons, 15) do
            local a = cachedAddons[i]
            GameTooltip:AddDoubleLine(a.name, DataBar:FormatMemory(a.mem), 1, 1, 1, 1, 1, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total", DataBar:FormatMemory(cachedTotal), 1, 1, 1, 0, 1, 0)
        GameTooltip:Show()
    end,
})
