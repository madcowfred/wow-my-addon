local freddie = select(2, ...)

-- Need a frame for events
local frame, events = CreateFrame("FRAME", "!Freddie"), {}

local actionBarSlots = {
    [44] = { 'item', 110560 }, -- Garrison Hearthstone
    [45] = { 'item', 140192 }, -- Dalaran Hearthstone
    [46] = { 'item', 6948 }, -- Hearthstone
    [47] = { 'spell', 75973 }, -- X-53 Touring Rocket
    [48] = { 'spell', 122708 }, -- Grand Expedition Yak
}
local actionTypeMap = {
    ['companion'] = 'spell',
}

local aidingQuests = {
    70750, -- Aiding the Accord
    72068, -- Aiding the Accord: A Feast For All
    72373, -- Aiding the Accord: A Hunt Is On
    72374, -- Aiding the Accord: Dragonbane Keep
    72375, -- Aiding the Accord: The Isles Call
    75259, -- Aiding the Accord: Zskera Vaults
    75859, -- Aiding the Accord: Sniffenseeking
    75860, -- Aiding the Accord: Researchers Under Fire
    75861, -- Aiding the Accord: Suffusion Camp
    77254, -- Aiding the Accord: Time Rift
    77976, -- Aiding the Accord: Dreamsurge
    78446, -- Aiding the Accord: Superbloom
    78447, -- Aiding the Accord: Emerald Bounty
}

-- TraitNode.dbc TraitTreeID=672
local dragonTalents = {
    { 64066, 0 }, -- T1
    { 81466, 0 }, -- T2/1
    { 64069, 0 }, -- T2/2
    { 94579, 0 }, -- T2/3
    { 64068, 0 }, -- T2/4
    { 64067, 0 }, -- T3
    { 64065, 82385 }, -- T4 choice (shield)
    { 92672, 0 }, -- T5/1
    { 64064, 0 }, -- T5/2
    { 92679, 0 }, -- T5/3
    { 92671, 0 }, -- T6/1
    { 64063, 0 }, -- T6/2
    { 92678, 0 }, -- T6/3
    { 94578, 0 }, -- T7/1
    { 64061, 0 }, -- T7/2
    { 94577, 0 }, -- T7/3
    { 64062, 82382 }, -- T8 choice (gathering)
    { 64059, 0 }, -- T9/1
    { 64060, 0 }, -- T9/2
    { 64058, 0 }, -- T9/3
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
    ["Find Fish"] = false,
    ["Find Herbs"] = true,
    ["Find Minerals"] = true,
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
    for i = 2, 5 do
        local value = Settings.GetValue("PROXY_SHOW_ACTIONBAR_" .. i)
        if value ~= true then
            print("> Enabling action bar " .. i)
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. i, true)
            needsReload = true
        end
    end

    -- Disable action bar 6-8
    for i = 6, 8 do
        local value = Settings.GetValue("PROXY_SHOW_ACTIONBAR_" .. i)
        if value ~= false then
            print("> Disabling action bar " .. i)
            Settings.SetValue("PROXY_SHOW_ACTIONBAR_" .. i, false)
            needsReload = true
        end
    end

    -- Add actions we need
    for slotId, slotData in pairs(actionBarSlots) do
        local actionType, actionId = GetActionInfo(slotId)
        local newType, newId = unpack(slotData)

        --print((actionType or 'nil')..'-'..newType..'--'..(actionId or 0)..'-'..newId)

        if actionType == nil or (actionType ~= newType and actionTypeMap[actionType] ~= newType) or actionId ~= newId then
            --print('> '..(actionType == nil and 'Adding' or 'Replacing')..' action bar slot '..slotId..' with '..newType..':'..newId)
            if newType == 'item' then
                if not C_Item.IsItemDataCachedByID(newId) then
                    local item = Item:CreateFromItemID(newId)
                    item:ContinueOnItemLoad(function()
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

    -- Dragonriding
    local configId = C_Traits.GetConfigIDBySystemID(1)
    for _, talentData in ipairs(dragonTalents) do
        if talentData[2] == 0 then
            C_Traits.PurchaseRank(configId, talentData[1])
        else
            C_Traits.SetSelection(configId, talentData[1], talentData[2])
        end
    end
    C_Traits.CommitConfig(configId)

    --freddie:ClassTalents()

    -- Set minimap tracking
    C_Minimap.ClearAllTracking()
    C_Timer.After(0, function()
        local trackingTypes = C_Minimap.GetNumTrackingTypes()
        for trackingIndex = 1, trackingTypes do
            local name, _ = C_Minimap.GetTrackingInfo(trackingIndex)
            if trackingEnabled[name] == true then
                C_Minimap.SetTracking(trackingIndex, true)
                --print('Enabled tracking: '..name)
            elseif trackingEnabled[name] == false then
                C_Minimap.SetTracking(trackingIndex, false)
            end
        end
    end)

    -- Suggested Content
    C_AdventureJournal.UpdateSuggestions()
    C_Timer.After(2, function() freddie:CheckSuggestions() end)

    if needsReload then print('RELOAD UI YO') end
end

function events:CRAFTINGORDERS_UPDATE_PERSONAL_ORDER_COUNTS()
    FlashClientIcon()
end

function events:PLAYER_CHOICE_UPDATE()
    local choiceInfo = C_PlayerChoice.GetCurrentPlayerChoiceInfo()
    if choiceInfo.choiceID == 786 then
        C_PlayerChoice.SendPlayerChoiceResponse(choiceInfo.options[1].buttons[1].id)
    end
end

function freddie:CheckSuggestions()
    local availableSuggestions = C_AdventureJournal.GetNumAvailableSuggestions()
    if availableSuggestions == 0 then
        C_AdventureJournal.UpdateSuggestions()
        C_Timer.After(1, function() freddie:CheckSuggestions() end)
    end
    print('Checking '..availableSuggestions..' suggestions')

    local acceptMe = {}

    -- Check the extras too?
    local suggestions = C_AdventureJournal.GetSuggestions()
    for i = 2, #suggestions do
        freddie:CheckSuggestion(acceptMe, suggestions[i], 0, i)
    end

    for i = 0, availableSuggestions - 1 do
        C_AdventureJournal.SetPrimaryOffset(i)
        suggestions = C_AdventureJournal.GetSuggestions()
        freddie:CheckSuggestion(acceptMe, suggestions[1], i, 1)
    end

    if #acceptMe > 0 then
        print('Accepting '..#acceptMe..' suggestion(s)')
        C_Timer.After(2, function() freddie:AcceptSuggestions(acceptMe) end)
    end
end

function freddie:CheckSuggestion(acceptMe, suggestion, offset, index)
    local title = suggestion.title

    if title == 'Aiding the Accord' then
        for _, questId in ipairs(aidingQuests) do
            if C_QuestLog.IsOnQuest(questId) then return end
            if C_QuestLog.IsQuestFlaggedCompleted(questId) then return end
        end
    end

    if
        title == 'Aiding the Accord' or
        title == 'Bonus Event: Dungeons' or
        title == 'Bonus Event: World Quests' or
        title == 'Copper Coin' or
        -- title == 'Fighting is Its Own Reward' or
        title == 'Silver Coin' or
        title == 'Gold Coin' or
        title == 'Bag of Coins' or
        title == 'Mysterious Coin' or
        string.find(title, '^Preserving the Past:') or
        string.find(title, '^Relic Recovery:')
    then
        -- Adventure Journal is super janky, try to accept things twice
        table.insert(acceptMe, { offset, index, title })
        table.insert(acceptMe, { offset, index, title })
    end
end

function freddie:AcceptSuggestions(acceptMe)
    local offset, index, title = unpack(tremove(acceptMe))

    print('Accepting ' .. offset .. '/' .. index .. ': ' .. title)
    if C_AdventureJournal.GetPrimaryOffset() ~= offset then
        C_AdventureJournal.SetPrimaryOffset(offset)
    end
    local suggestions = C_AdventureJournal.GetSuggestions()
    if suggestions[index].title == title then
        C_AdventureJournal.ActivateEntry(index)

        if #acceptMe > 0 then
            C_Timer.After(1, function() freddie:AcceptSuggestions(acceptMe) end)
        end
    else
        print('Expected "' .. title .. '", got "' .. suggestions[index].title .. '" - restarting')
        C_Timer.After(0, function() freddie:CheckSuggestions() end)
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
    freddie:CheckSuggestions()
end

SLASH_RL1 = "/rl"
SlashCmdList["RL"] = function(msg)
    ReloadUI()
end
