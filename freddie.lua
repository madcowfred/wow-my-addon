local freddie = select(2, ...)

-- Need a frame for events
local frame, events = CreateFrame("FRAME", "!Freddie"), {}

local actionBarSlots = {
    [30] = { 'spell', 436854 }, -- Switch Flight Style
    [43] = { 'spell', 465235 }, -- Trader's Gilded Brutosaur
    [44] = { 'spell', 122708 }, -- Grand Expedition Yak
    [45] = { 'spell', 75973 }, -- X-53 Touring Rocket
    [46] = { 'item', 110560 }, -- Garrison Hearthstone
    [47] = { 'item', 140192 }, -- Dalaran Hearthstone
    [48] = { 'item', 6948 }, -- Hearthstone
}
local actionTypeMap = {
    ['companion'] = 'spell',
}

local suggestionToQuest = {
    ['Ara-Kara, City of Echoes'] = 83465,
    ['Cinderbrew Meadery'] = 83436,
    ['City of Threads'] = 83469,
    ['Darkflame Cleft'] = 83443,
    ['Priory of the Sacred Flame'] = 83458,
    ['The Dawnbreaker'] = 83459,
    ['The Rookery'] = 83432,
    ['The Stonevault'] = 83457,
}

local trackingEnabled = {
    ["Find Fish"] = false,
    ["Find Herbs"] = true,
    ["Find Minerals"] = true,
    ["Flight Master"] = true,
    ["Focus Target"] = true,
    ["Innkeeper"] = true,
    ["Low-Level Quests"] = true,
    ["Mailbox"] = true,
    ["Points of Interest"] = true,
    ["Target"] = true,
    ["Track Hidden"] = true,
    ["Track Pets"] = true,
    ["Track Quest POIs"] = true,
    ["Trivial Quests"] = true,
    ["Warband Completed Quests"] = true,
}

function events:PLAYER_ENTERING_WORLD()
    if FreddieSaved == nil then
        FreddieSaved = {}
    end

    -- Enable auto-loot
    SetCVar("autoLootDefault", "1")

    -- Camera thing
    SetCVar("cameraIndirectOffset", "10")
    SetCVar("cameraIndirectVisibility", 1)

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

    -- Chat garbage
    local fontFile, _, fontFlags = DEFAULT_CHAT_FRAME:GetFont()
    DEFAULT_CHAT_FRAME:SetFont(fontFile, 16, fontFlags)

    local frameName = DEFAULT_CHAT_FRAME:GetName()
    for _, value in pairs(CHAT_FRAME_TEXTURES) do
        _G[frameName..value]:SetAlpha(0.6)
    end
    SetChatWindowAlpha(1, 0.6)

    ChatFrame_AddMessageGroup(DEFAULT_CHAT_FRAME, 'COMBAT_XP_GAIN')

    ChatFrame_RemoveChannel(DEFAULT_CHAT_FRAME, 'Trade')
    LeaveChannelByName('Services')

    -- This stupid goddamn reagent bag "help" tip
    C_Timer.After(5, function() HelpTip:HideAllSystem('TutorialReagentBag') end)

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
                        C_Item.PickupItem(newId)
                        PlaceAction(slotId)
                        ClearCursor()
                    end)
                else
                    C_Item.PickupItem(newId)
                    PlaceAction(slotId)
                    ClearCursor()
                end
            else
                if newType == 'spell' then
                    C_Spell.PickupSpell(newId)
                end

                PlaceAction(slotId)
                ClearCursor()
            end
        end
    end

    -- Set minimap tracking
    C_Minimap.ClearAllTracking()
    C_Timer.After(0, function()
        local trackingTypes = C_Minimap.GetNumTrackingTypes()
        for trackingIndex = 1, trackingTypes do
            local trackingInfo = C_Minimap.GetTrackingInfo(trackingIndex)
            if trackingEnabled[trackingInfo.name] == true then
                C_Minimap.SetTracking(trackingIndex, true)
                --print('Enabled tracking: '..name)
            elseif trackingEnabled[trackingInfo.name] == false then
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

local guildRosterUpdated = 0
local waitingOnGuildRoster = false
function events:GUILD_ROSTER_UPDATE(a, b, c)
    guildRosterUpdated = time()
    if waitingOnGuildRoster then
        waitingOnGuildRoster = false
        freddie:InviteFromGuild()
    end
end

function events:PLAYER_CHOICE_UPDATE()
    local choiceInfo = C_PlayerChoice.GetCurrentPlayerChoiceInfo()
    if choiceInfo ~= nil and choiceInfo.choiceID == 786 then
        C_PlayerChoice.SendPlayerChoiceResponse(choiceInfo.options[1].buttons[1].id)
    end
end

-- local ordersUpdated = false
-- function events:TRADE_SKILL_SHOW()
--     ordersUpdated = false
-- end

-- function events:TRADE_SKILL_LIST_UPDATE()
--     if ordersUpdated then return end

--     local tab = ProfessionsFrame:GetTab()
--     if tab == 3 then
--         ordersUpdated = true
--         C_TradeSkillUI.SetShowUnlearned(false)
--         RunNextFrame(function()
--             ProfessionsFrame.OrdersPage:RequestOrders(nil, false, false)
--         end)
--     end
-- end

function freddie:CheckSuggestions()
    local availableSuggestions = C_AdventureJournal.GetNumAvailableSuggestions()
    if availableSuggestions == 0 then
        C_AdventureJournal.UpdateSuggestions()
        C_Timer.After(1, function() freddie:CheckSuggestions() end)
    end
    -- print('Checking '..availableSuggestions..' suggestions')

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

    if
        title == 'Bonus Event: Dungeons' or
        title == 'Bonus Event: World Quests' or
        title == 'Brawl: Arathi Basin Comp Stomp' or
        title == 'Bag of Coins' or
        title == 'Copper Coin' or
        title == 'Gold Coin' or
        title == 'Mysterious Coin' or
        title == 'Silver Coin' or
        title == 'Theater Troupe' or
        suggestionToQuest[title]
        -- string.find(title, '^A Worthy Ally:') or
        -- string.find(title, '^Preserving the Past:') or
        -- string.find(title, '^Relic Recovery:') or
        -- string.find(title, '^The Big Dig:')
    then
        local tryMe = true
        
        if suggestionToQuest[title] then
            if C_QuestLog.IsOnQuest(suggestionToQuest[title]) or
                C_QuestLog.IsQuestFlaggedCompleted(suggestionToQuest[title]) then
                tryMe = false
            end
        end

        -- Adventure Journal is super janky, try to accept things twice
        if tryMe then
            table.insert(acceptMe, { offset, index, title })
            table.insert(acceptMe, { offset, index, title })
        end
    end
end

function freddie:AcceptSuggestions(acceptMe)
    local offset, index, title = unpack(tremove(acceptMe))

    print('Accepting ' .. offset .. '/' .. index .. ': ' .. title)
    
    if C_AdventureJournal.GetPrimaryOffset() ~= offset then
        C_AdventureJournal.SetPrimaryOffset(offset)
    end

    local suggestions = C_AdventureJournal.GetSuggestions()
    if suggestions ~= nil then
        if suggestions[index].title == title then
            C_AdventureJournal.ActivateEntry(index)

            if #acceptMe > 0 then
                C_Timer.After(1, function() freddie:AcceptSuggestions(acceptMe) end)
            end
        else
            print('Expected "' .. title .. '", got "' .. suggestions[index].title .. '" - restarting')
            C_Timer.After(0, function() freddie:CheckSuggestions() end)
        end
    else
        print('No suggestions??')
        C_Timer.After(0, function() freddie:CheckSuggestions() end)
    end
end

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

function freddie:InviteFromCommunity()
    local clubs = C_Club.GetSubscribedClubs()
    if clubs == nil then
        print('No clubs! :()')
        return
    end

    local found = false
    for _, club in ipairs(clubs) do
        if club.name == 'Freddie Freak Factory' then
            local memberIds = C_Club.GetClubMembers(club.clubId)
            for _, memberId in ipairs(memberIds) do
                local info = C_Club.GetMemberInfo(club.clubId, memberId)
                if info ~= nil and info.isSelf == false then
                    -- online / away / busy
                    if info.presence == 1 or info.presence == 4 or info.presence == 5 then
                        print('Inviting ' .. info.name .. ' from community')
                        C_PartyInfo.InviteUnit(info.name)
                        found = true
                        break
                    end
                end
            end
        end

        if found then break end
    end

    if found == false then
        print('No match in community')
    end
end

function freddie:TryInviteFromGuild()
    if not IsInGuild() then return end

    if time() - guildRosterUpdated > 10 then
        print('requested')
        waitingOnGuildRoster = true
        C_GuildInfo.GuildRoster()
    else
        freddie:InviteFromGuild()
    end
end

function freddie:InviteFromGuild()
    local found = false
    local _, online = GetNumGuildMembers()
    for i = 1, online do
        local name, _, _, _, _, _, publicNote = GetGuildRosterInfo(i)
        if publicNote == 'Freddie' or publicNote == 'Freddie alt' then
            C_PartyInfo.InviteUnit(name)
            found = true
            break
        end
    end

    if found == false then
        print('No match in guild')
    end
end

-------------------------------------------------------------------------------

SLASH_FRED1 = "/fred"
SlashCmdList["FRED"] = function(msg)
    freddie:InviteFromCommunity()
    freddie:TryInviteFromGuild()
end

SLASH_RL1 = "/rl"
SlashCmdList["RL"] = function(msg)
    ReloadUI()
end
