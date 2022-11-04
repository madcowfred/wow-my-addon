-- Need a frame for events
local frame, events = CreateFrame("FRAME", "!Freddie"), {}

local trackingEnabled = {
    1,  -- Pets
    7,  -- Flight Master
    9,  -- Innkeeper
    11, -- Mailbox
    15, -- Trivial Quests
    19, -- Target
    --21, -- Track Quest POIs ?
}

function events:PLAYER_ENTERING_WORLD()
    local needsReload = false

    -- Enable auto-loot
    SetCVar('autoLootDefault', '1')

    -- Activate 'Fred' layout
    local layouts = C_EditMode.GetLayouts()
    if layouts.activeLayout ~= 3 then
        print('> Setting layout to 3')
        C_EditMode.SetActiveLayout(3)
        needsReload = true
    end

    -- Enable action bar 2-4
    for i = 2, 4 do
        local value = Settings.GetValue('PROXY_SHOW_ACTIONBAR_'..i)
        if value ~= true then
            print('> Enabling action bar '..i)
            Settings.SetValue('PROXY_SHOW_ACTIONBAR_'..i, true)
            needsReload = true
        end
    end
    
    -- Disable action bar 5-8
    for i = 5, 8 do
        local value = Settings.GetValue('PROXY_SHOW_ACTIONBAR_'..i)
        if value ~= false then
            print('> Disabling action bar '..i)
            Settings.SetValue('PROXY_SHOW_ACTIONBAR_'..i, false)
            needsReload = true
        end
    end

    -- Set minimap tracking
    for _, index in ipairs(trackingEnabled) do
        C_Minimap.SetTracking(index, true)
    end

    if needsReload then
        ReloadUI()
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
