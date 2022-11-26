-- Need a frame for events
local frame, events = CreateFrame("FRAME", "!Freddie"), {}

local freddie = {}

local actionBarSlots = {
    [28] = { 'item', 110560 }, -- Garrison Hearthstone
    [29] = { 'item', 140192 }, -- Dalaran Hearthstone
    [30] = { 'item', 6948 }, -- Hearthstone
    [35] = { 'spell', 75973 }, -- X-53 Touring Rocket
    [36] = { 'spell', 122708 }, -- Grand Expedition Yak
}
local actionTypeMap = {
    ['companion'] = 'spell',
}

local talentsMain = {
    ["DEATHKNIGHT"] = { "Sargeras", "Totake" },
    ["DEMONHUNTER"] = { "Mal'Ganis", "Akeni" },
    ["DRUID"] = { "Mal'Ganis", "Keikuro" },
    ["HUNTER"] = { "Mal'Ganis", "Grigorovich" },
    ["MAGE"] = { "Sargeras", "Eteyu" },
    ["MONK"] = { "Mal'Ganis", "Momokan" },
    ["PALADIN"] = { "Feathermoon", "Tefu" },
    ["PRIEST"] = { "Mal'Ganis", "" },
    ["ROGUE"] = { "Mal'Ganis", "Akiru" },
    ["SHAMAN"] = { "Mal'Ganis", "Okuki" },
    ["WARLOCK"] = { "Mal'Ganis", "Yumame" },
    ["WARRIOR"] = { "Sargeras", "Yaken" },
}

local trackingEnabled = {
    ["Flight Master"] = true,
    ["Innkeeper"] = true,
    ["Mailbox"] = true,
    ["Points of Interest"] = true,
    ["Target"] = true,
    ["Track Hidden"] = true,
    ["Track Pets"] = true,
    ["Track Quest POIs"] = true,
    ["Trivial Quests"] = true,
}

function events:PLAYER_ENTERING_WORLD()
    if FreddieSaved == nil then
        FreddieSaved = {}
    end

    -- Enable auto-loot
    SetCVar("autoLootDefault", "1")

    local needsReload = freddie:ActivateLayout()

    -- Enable action bar 2-4
    for i = 2, 4 do
        local value = Settings.GetValue("PROXY_SHOW_ACTIONBAR_"..i)
        if value ~= true then
            print("> Enabling action bar "..i)
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_"..i, true)
            needsReload = true
        end
    end
    
    -- Disable action bar 5-8
    for i = 5, 8 do
        local value = Settings.GetValue("PROXY_SHOW_ACTIONBAR_"..i)
        if value ~= false then
            print("> Disabling action bar "..i)
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_"..i, false)
            needsReload = true
        end
    end

    -- Add actions we need
    for slotId, slotData in pairs(actionBarSlots) do
        local actionType, actionId = GetActionInfo(slotId)
        local newType, newId = unpack(slotData)

        print((actionType or 'nil')..'-'..newType..'--'..(actionId or 0)..'-'..newId)

        if actionType == nil or (actionType ~= newType and actionTypeMap[actionType] ~= newType) or actionId ~= newId then
            print('> '..(actionType == nil and 'Adding' or 'Replacing')..' action bar slot '..slotId..' with '..newType..':'..newId)
            if newType == 'item' then
                if not C_Item.IsItemDataCachedByID(newId) then
                    print('not cached')
                    --C_Item.RequestLoadItemDataByID(newId)

                    local item = Item:CreateFromItemID(newId)
                    item:ContinueOnItemLoad(function()
                        print('hi mum', newId)
                        PickupItem(newId)
                        PlaceAction(slotId)
                        ClearCursor()
                    end)
                else
                    PickupItem(newId)
                    PlaceAction(slotId)
                    ClearCursor()
                end
            else
                if newType == 'spell' then
                    PickupSpell(newId)
                end

                PlaceAction(slotId)
                ClearCursor()
            end
        end
    end

    -- Set minimap tracking
    C_Minimap.ClearAllTracking()
    local trackingTypes = C_Minimap.GetNumTrackingTypes()
    for trackingIndex = 1, trackingTypes do
        local name, _ = C_Minimap.GetTrackingInfo(trackingIndex)
        if trackingEnabled[name] == true then
            C_Minimap.SetTracking(trackingIndex, true)
        end
    end

    --freddie:ClassTalents()

    if needsReload then
        ReloadUI()
    end
end

-- function events:ACTIVE_PLAYER_SPECIALIZATION_CHANGED()
--     C_Timer.After(1, function()
--         freddie:ClassTalents(true)

--         local needsReload = freddie:ActivateLayout()
--         if needsReload then
--             ReloadUI()
--         end
--     end)
-- end

-- Call functions in the events table for events
frame:SetScript("OnEvent", function(self, event, ...)
    --print(event)
    events[event](self, ...)
end)

-- Register every event in the events table
for k, v in pairs(events) do
    frame:RegisterEvent(k)
end

function freddie:ActivateLayout()
    -- Activate "Fred" layout
    local layouts = C_EditMode.GetLayouts()
    if layouts.activeLayout ~= 3 then
        print("> Setting layout to 3")
        C_EditMode.SetActiveLayout(3)
        return true
    end
    return false
end

function freddie:ClassTalents(onlyLoad)
    local _, class = UnitClass("player")
    local charRealm = GetRealmName()
    local charName = UnitName("player")

    local mainRealm, mainName = unpack(talentsMain[class])
    local isMain = charRealm == mainRealm and charName == mainName
    local numSpecs = GetNumSpecializations()

    if isMain and onlyLoad == true then return end

    if isMain then
        print('> Saving talent builds')
        FreddieSaved[class] = {}
        
        local treeNodes = nil
        for specIndex = 1, numSpecs do
            FreddieSaved[class][specIndex] = {}

            local configIds = C_ClassTalents.GetConfigIDsBySpecID(GetSpecializationInfo(specIndex))
            local loadoutNum = 1

            for _, configId in ipairs(configIds) do
                local configInfo = C_Traits.GetConfigInfo(configId)
                
                if treeNodes == nil then
                    treeNodes = C_Traits.GetTreeNodes(configInfo.treeIDs[1])
                end

                local loadout = {
                    name = configInfo.name,
                    entries = {},
                }

                for _, treeNodeId in ipairs(treeNodes) do
                    local treeNode = C_Traits.GetNodeInfo(configId, treeNodeId)
                    if treeNode.ranksPurchased > 0 then
                        table.insert(loadout.entries, {
                            nodeID = treeNodeId,
                            ranksPurchased = treeNode.ranksPurchased,
                            selectionEntryID = treeNode.activeEntry.entryID,
                        })
                    end
                end

                FreddieSaved[class][specIndex][loadoutNum] = loadout
                loadoutNum = loadoutNum + 1
            end
        end

    elseif FreddieSaved[class] ~= nil then
        local specIndex = GetSpecialization()
        local specId, specName = GetSpecializationInfo(specIndex)
        print('> Loading talent builds for '..specName)

        local loadouts = FreddieSaved[class][specIndex]
        for _, loadout in ipairs(loadouts) do
            local activeConfigId = C_ClassTalents.GetActiveConfigID()
            local lastSavedConfigId = C_ClassTalents.GetLastSelectedSavedConfigID(specId)
            local matchingConfigId = freddie:GetConfigIdByName(specIndex, loadout.name)
            if matchingConfigId ~= nil then
                print('> Replacing loadout '..loadout.name)
                C_ClassTalents.DeleteConfig(matchingConfigId)
            else
                print('> Creating loadout '..loadout.name)
            end
            
            print((activeConfigId or 0)..':'..(lastSavedConfigId or 0)..':'..(matchingConfigId or 0))
            C_ClassTalents.ImportLoadout(matchingConfigId or activeConfigId, loadout.entries, loadout.name)

            if matchingConfigId == activeConfigId or matchingConfigId == lastSavedConfigId then
                matchingConfigId = freddie:GetConfigIdByName(specIndex, loadout.name)
                C_ClassTalents.LoadConfig(matchingConfigId, true)
                C_ClassTalents.UpdateLastSelectedSavedConfigID(specId, matchingConfigId)
            end
        end

        --C_ClassTalents.CommitConfig()
    end
end

function freddie:GetConfigIdByName(specIndex, name)
    local configIds = C_ClassTalents.GetConfigIDsBySpecID(GetSpecializationInfo(specIndex))
    for _, configId in ipairs(configIds) do
        local configInfo = C_Traits.GetConfigInfo(configId)
        if configInfo.name == name then
            return configInfo.ID
        else
            print(':'..name..':'..configInfo.name..':')
        end
    end
    return nil
end

-------------------------------------------------------------------------------

SLASH_FREDDIE1 = "/freddie"
SlashCmdList["FREDDIE"] = function(msg)
    freddie:ClassTalents()
end

SLASH_RL1 = "/rl"
SlashCmdList["RL"] = function(msg)
    ReloadUI()
end
