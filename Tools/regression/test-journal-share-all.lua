-- Run with Lua 5.1 from the repository root: the Dungeon Journal's Share All (DungeonJournal/
-- ShareQuests.lua). A quest in your log is shared only while someone in your group is not on it
-- and can take it (faction, class, race, the level it needs), the chat line says who for, and a
-- member the game says has completed a quest is not shared it again this session.
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local function Set(t)
    local out = {}
    for _, id in ipairs(t or {}) do out[id] = true end
    return out
end

local HUMAN, UNDEAD, TAUREN = 1, 5, 6
local TITLES = { [214] = "Red Silk Bandanas", [600] = "Plain", [700] = "Tauren Only" }

local function Data()
    return {
        QuestData = {},
        QuestPrereqs = {}, QuestChains = {}, QuestWhere = {}, QuestChainNames = {},
        QuestChainStarts = {}, QuestTurnIns = {},
        QuestMinLevel = { [214] = 14, [600] = 30 },
    }
end

local DUNGEON = { quests = { quests = {
    { 214, "Red Silk Bandanas", 17, "A", true, "Westfall" },
    { 600, "Plain", 30, "B", true, "Plain place" },
    { 700, "Tauren Only", 30, "H", true, "Mulgore", races = 32 },
} } }

-- opts.mine: quest IDs in your log; opts.party: { name, level, faction, race, class, on = { IDs },
-- offline } per member, party1 first.
local function Fixture(opts)
    local mine = Set(opts.mine)
    local party = opts.party or {}
    local seen = { pushed = {}, printed = {}, timers = {} }
    local J = Data()
    J.Sharing = {}
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        OnApply = function() end,
        Journal = J, Shared = {},
        Print = function(text) seen.printed[#seen.printed + 1] = text end,
        CanPlaceWaypoint = function() return true end,
    }
    local index = {}
    for i, id in ipairs(opts.mine or {}) do index[id] = i end
    local function Member(unit)
        if unit == "player" then return { level = 40, faction = "Alliance", race = HUMAN, class = "MAGE" } end
        return party[tonumber(unit:match("%d+$"))] or {}
    end
    local frames = {}
    local env
    env = setmetatable({
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        issecretvalue = function() return false end,
        C_QuestLog = {
            IsOnQuest = function(id) return mine[id] == true end,
            IsComplete = function() return false end,
            IsQuestFlaggedCompleted = function() return false end,
            GetTitleForQuestID = function(id) return TITLES[id] end,
            GetQuestDifficultyLevel = function() return 0 end,
            IsPushableQuest = function(id) return mine[id] == true end,
            GetLogIndexForQuestID = function(id) return index[id] end,
            IsUnitOnQuest = function(unit, id)
                local on = Member(unit).on
                return on ~= nil and Set(on)[id] == true
            end,
        },
        QuestLogPushQuest = function(i) seen.pushed[#seen.pushed + 1] = opts.mine[i] end,
        C_Timer = { NewTimer = function(_, fn)
            seen.timers[#seen.timers + 1] = fn
            return { Cancel = function() end }
        end },
        CreateFrame = function()
            local f = { events = {} }
            function f:SetScript(_, fn) self.script = fn end
            function f:RegisterEvent(e) self.events[e] = true end
            function f:UnregisterEvent(e) self.events[e] = nil end
            function f:UnregisterAllEvents() self.events = {} end
            frames[#frames + 1] = f
            return f
        end,
        IsInGroup = function() return #party > 0 end,
        InCombatLockdown = function() return opts.combat == true end,
        GetNumSubgroupMembers = function() return #party end,
        UnitName = function(unit) return Member(unit).name end,
        UnitIsConnected = function(unit) return not Member(unit).offline end,
        UnitLevel = function(unit) return Member(unit).level or 40 end,
        UnitClass = function(unit) local c = Member(unit).class or "WARRIOR" return c, c end,
        UnitRace = function(unit) return "Race", "Race", Member(unit).race or HUMAN end,
        UnitFactionGroup = function(unit) return Member(unit).faction or "Alliance" end,
        ERR_QUEST_PUSH_SUCCESS_S = "Sharing quest with %s...",
        ERR_QUEST_PUSH_ACCEPTED_S = "%s has accepted your quest.",
        ERR_QUEST_PUSH_ALREADY_DONE_S = "%s has completed that quest.",
        ERR_QUEST_PUSH_BUSY_S = "%s is busy.",
    }, { __index = _G })
    env._G, env.NaowhForever = env, ns
    for _, path in ipairs({ "Shared/Data/SameMaps.lua", "Shared/Game/Places.lua",
            "NaowhForever_DungeonJournal/Constants.lua", "NaowhForever_DungeonJournal/Quests.lua",
            "NaowhForever_DungeonJournal/ShareQuests.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    seen.Fire = function(event, text)
        for _, f in ipairs(frames) do
            if f.events[event] then f.script(f, event, text) end
        end
    end
    seen.Say = function(text) seen.Fire("CHAT_MSG_SYSTEM", text) end
    return J.Sharing, seen
end

local VORDA = { name = "Vorda", level = 35 }

Case("a quest goes only to members who are not on it and can take it, and the line says who", function()
    local Sharing, seen = Fixture({ mine = { 214, 600 }, party = {
        { name = "Emmy", level = 30, on = { 600 } },
        { name = "Tiif", level = 12 },
        VORDA,
        { name = "Grim", level = 35, faction = "Horde", on = {} },
        { name = "Gone", level = 35, offline = true },
    } })
    Sharing.ShareAll(DUNGEON)
    local line = seen.printed[1]
    assert(line:find("Red Silk Bandanas (Emmy, Vorda); Plain (Vorda, Grim)", 1, true), line)
    assert(#seen.pushed == 1 and seen.pushed[1] == 214, "one at a time, the first now")
end)

Case("nothing is shared while everyone has the quests or cannot take them", function()
    local Sharing, seen = Fixture({ mine = { 214 }, party = {
        { name = "Emmy", level = 30, on = { 214 } },
        { name = "Tiif", level = 12 },
    } })
    Sharing.ShareAll(DUNGEON)
    assert(#seen.pushed == 0)
    assert(seen.printed[1] == "Your group has these quests already, or cannot take them.", seen.printed[1])
    assert(#Sharing.Shareable(DUNGEON) == 0, "and the tracker's button counts none")
end)

Case("a quest only some races can take goes only to them", function()
    local Sharing, seen = Fixture({ mine = { 700 }, party = {
        { name = "Hoof", level = 35, faction = "Horde", race = TAUREN },
        { name = "Bones", level = 35, faction = "Horde", race = UNDEAD },
    } })
    Sharing.ShareAll(DUNGEON)
    assert(seen.printed[1]:find("Tauren Only (Hoof)", 1, true), seen.printed[1])
end)

Case("a member the game says has completed a quest is not shared it again, named with or without a realm", function()
    local Sharing, seen = Fixture({ mine = { 214 }, party = { VORDA } })
    Sharing.ShareAll(DUNGEON)
    assert(#seen.pushed == 1)
    seen.Say("Sharing quest with Vorda...")
    seen.Say("Vorda-Stormrage has completed that quest.")
    Sharing.ShareAll(DUNGEON)
    assert(#seen.pushed == 1, "not pushed a second time")
    assert(seen.printed[#seen.printed] == "Your group has these quests already, or cannot take them.",
        seen.printed[#seen.printed])
end)

Case("in combat every logged quest is queued, and checked when sharing carries on", function()
    local opts = { mine = { 214 }, combat = true, party = { { name = "Emmy", level = 30, on = { 214 } } } }
    local Sharing, seen = Fixture(opts)
    assert(#Sharing.Shareable(DUNGEON) == 1, "the members are not read in combat")
    Sharing.ShareAll(DUNGEON)
    assert(#seen.pushed == 0)
    opts.combat = false
    seen.Fire("PLAYER_REGEN_ENABLED")
    assert(#seen.pushed == 0, "Emmy has it, so it is skipped after combat")
    assert(seen.printed[#seen.printed] == "Done sharing.", seen.printed[#seen.printed])
end)

print("test-journal-share-all: " .. count .. " cases passed")
