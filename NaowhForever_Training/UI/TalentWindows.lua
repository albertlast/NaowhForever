-- TalentWindows.lua: finds the open talent window (Blizzard's or EllesmereUI's) and its talents' buttons.
local ns = _G.NaowhForever

local Next = ns.Training.Next

local SCAN_DEPTH = 6

local classWindow = {}
local childLists = {}
local scannedButtons = {}
local NO_BUTTONS = {}

local function NodeOf(button)
    if button.GetNodeID then return button:GetNodeID() end
    return button.nodeID
end

local function PutChildrenIn(list, ...)
    wipe(list)
    for index = 1, select("#", ...) do
        list[index] = select(index, ...)
    end
end

local function ChildrenAtDepth(frame, depth)
    local list = childLists[depth]
    if not list then
        list = {}
        childLists[depth] = list
    end
    PutChildrenIn(list, frame:GetChildren())
    return list
end

local function Scan(frame, node, depth)
    if depth > SCAN_DEPTH then return nil end
    local children = ChildrenAtDepth(frame, depth)
    for _, child in ipairs(children) do
        if child:IsShown() then
            if NodeOf(child) == node then return child end
            local found = Scan(child, node, depth + 1)
            if found then return found end
        end
    end
    return nil
end

local function ScanAll(frame, buttons, depth)
    if depth > SCAN_DEPTH then return end
    local children = ChildrenAtDepth(frame, depth)
    for _, child in ipairs(children) do
        if child:IsShown() then
            local node = NodeOf(child)
            if node and not buttons[node] then buttons[node] = child end
            ScanAll(child, buttons, depth + 1)
        end
    end
end

local function BlizzardFind(page, node)
    local buttons = page.nodeIDToButton
    if not buttons then return nil end
    return buttons[node]
end

local function FillWindow(window, outer, content, search, scan)
    window.outer = outer
    window.content = content
    window.search = search
    window.scan = scan
    return window
end

function Next.NodeOf(button)
    return NodeOf(button)
end

function Next.ClassWindow()
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if talents and talents:IsVisible() then
        return FillWindow(classWindow, PlayerSpellsFrame, talents, talents.SearchBox, false)
    end
    local ellesmere = EUI_ClassicTalents
    if ellesmere and ellesmere:IsVisible() then
        return FillWindow(classWindow, ellesmere, ellesmere, nil, true)
    end
    return nil
end

function Next.FindButton(window, node)
    if window.scan then return Scan(window.content, node, 0) end
    return BlizzardFind(window.content, node)
end

function Next.ButtonsByNode(window)
    if window.scan then
        wipe(scannedButtons)
        ScanAll(window.content, scannedButtons, 0)
        return scannedButtons
    end
    return window.content.nodeIDToButton or NO_BUTTONS
end

function Next.EachTalentPage(fn)
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if talents then fn(talents) end
    if EUI_ClassicTalents then fn(EUI_ClassicTalents) end
end
