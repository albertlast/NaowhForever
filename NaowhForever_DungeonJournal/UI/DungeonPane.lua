-- DungeonPane.lua: the new look's dungeon page: its header, then the map, quests or keys and the picked boss on the left, beside every boss's loot (J.DungeonPane).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Map = J.DungeonMap
local Parts = J.View.Parts
local C = J.C
local St = J.Style
local TAB_H, TEXT_SIZE, SCROLLBAR = St.TAB_H, St.TEXT_SIZE, St.SCROLLBAR
local LIST_BAR, LIST_BAR_GAP = St.LIST_BAR, St.LIST_BAR_GAP

local LEFT_W = 440
local PANE_GAP, ROW_GAP, HEAD_GAP = 16, 8, 10
local MAP_TOP = TAB_H + ROW_GAP + TAB_H + ROW_GAP
local NAMED_FLOORS, NUMBER_W, FLOOR_NAME_GAP = 3, 48, 10
local SIDE_TOP = TAB_H + ROW_GAP
local MAP, QUESTS, KEYS = "map", "quests", "keys"
local TAB_MAP = { key = MAP, label = "Map and Boss" }
local TAB_QUESTS = { key = QUESTS, label = "Quests" }
local TAB_KEYS = { key = KEYS, label = "Keys" }

local SOON_SIZE, SOON_GAP, SOON_ART = 18, 6, 0.25
local BUTTON_ART = { left = 10 / 256, right = 164 / 256, top = 10 / 128, bottom = 86 / 128 }

local TEXT_NO_MAP = ns.L("No map of this dungeon yet.")
local TEXT_COMING_SOON = ns.L("Coming soon")

local frame, left, tabs, headView, mapView, infoScroll, infoView, sideScroll, sideView, noMap
local floorTabs, floorName
local floorItems, floorPool = {}, {}
local mainView, mainScroll
local dungeon, picked
local mode = MAP
local width, headHeight = 0, 0
local leftW, wantW = LEFT_W, LEFT_W
local tabItems = {}

local function MapHeight(w)
    return math.floor(C.MAP_H * w / C.MAP_W)
end

local function SizeLeft()
    leftW = wantW
    local mapScale = leftW / C.MAP_W
    local sideW = leftW - LIST_BAR - LIST_BAR_GAP
    left:SetWidth(leftW)
    tabs:SetWidth(leftW)
    Parts.SetTabs(tabs, tabItems)
    mapView.scale = mapScale
    mapView.canvas:SetScale(mapScale)
    mapView.canvas:SetPoint("TOPLEFT", 0, -MAP_TOP / mapScale)
    noMap:SetSize(leftW, TAB_H + ROW_GAP + MapHeight(leftW))
    infoScroll:SetPoint("TOPLEFT", 0, -(MAP_TOP + MapHeight(leftW) + ROW_GAP))
    infoScroll:SetWidth(sideW)
    infoView:SetWidth(sideW)
    sideScroll:SetWidth(sideW)
    sideView:SetWidth(sideW)
end

local function IsBoss(row, boss)
    return row.boss == boss
end

local function PlaceMain(height)
    headHeight = height or headHeight
    local top = headHeight + HEAD_GAP
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", 0, -top)
    left:SetPoint("BOTTOMLEFT")
    mainScroll:ClearAllPoints()
    mainScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", leftW + PANE_GAP, -top)
    mainScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SCROLLBAR, 0)
end

local function ShowBoss(boss, scrollTo)
    picked = boss
    mainView.marked = boss
    mainView:ApplyPin()
    if scrollTo and boss then
        local row = mainView:Find("boss", IsBoss, boss)
        if row then mainView:ScrollToRow(mainScroll, row) end
    end
    if mode ~= MAP then return end
    infoScroll:SetShown(boss ~= nil)
    if not boss then return end
    if J.Maps[dungeon.key] then
        local key = Map.KeyOf(boss)
        local spot = Map.Spot(dungeon, key)
        if type(spot) == "table" and mapView.floor ~= spot[1] and mapView:FloorAt(spot[1]) then
            mapView.floor = spot[1]
            mapView:Draw()
        end
        mapView:Pick(key)
    end
    infoScroll:SetVerticalScroll(0)
    infoView:DrawBossInfo(boss, dungeon)
end

local ShowMode

local function ShowHistory(boss)
    picked = boss
    mode = MAP
    ShowMode()
    infoScroll:SetVerticalScroll(math.min(infoView.historyTop,
        math.max(0, infoView:GetHeight() - infoScroll:GetHeight())))
end

local function PinPicked(boss)
    ShowBoss(boss, true)
end

local function HideStepper()
    mapView.down:Hide()
    mapView.up:Hide()
    mapView.floorName:Hide()
end

local function FloorPicked(floor)
    mapView.floor = floor
    mapView:Draw()
end

local function MapDrawn()
    HideStepper()
    local floors, map = mapView.floors, J.Maps[dungeon.key]
    local named = #floors <= NAMED_FLOORS
    wipe(floorItems)
    for i, floor in ipairs(floors) do
        local item = floorPool[i] or {}
        floorPool[i] = item
        item.key, item.label = floor, named and Map.FloorName(map, floor) or tostring(i)
        floorItems[i] = item
    end
    floorTabs:SetShown(#floors > 1)
    floorTabs:SetWidth(named and leftW or math.min(leftW, #floors * NUMBER_W))
    Parts.SetTabs(floorTabs, floorItems)
    Parts.PaintTabs(floorTabs, mapView.floor)
    floorName:SetShown(#floors > 1 and not named)
    floorName:SetText(Map.FloorName(map, mapView.floor))
end

local function ShowMap(shown)
    local has = shown and J.Maps[dungeon.key] ~= nil
    mapView.canvas:SetShown(has)
    noMap:SetShown(shown and not has)
    local painting = J.Paintings[dungeon.key]
    noMap.art:SetShown(painting ~= nil)
    if painting then noMap.art:SetTexture(painting[1]) end
    if has then
        mapView:Draw()
    else
        HideStepper()
        floorTabs:Hide()
        floorName:Hide()
    end
end

function ShowMode()
    Parts.PaintTabs(tabs, mode)
    ShowMap(mode == MAP)
    infoScroll:SetShown(mode == MAP and picked ~= nil)
    sideScroll:SetShown(mode ~= MAP)
    if mode == MAP then
        ShowBoss(picked)
    elseif mode == QUESTS then
        sideView.part = "DrawAside"
        sideView:DrawAside(dungeon)
    else
        sideView.part = "DrawKeysPage"
        sideView:DrawKeysPage(dungeon)
    end
end

local function TabPicked(key)
    mode = key
    ShowMode()
end

local function FirstBoss(shown)
    for _, wing in ipairs(shown.wings) do
        for _, boss in ipairs(wing.bosses) do
            if not boss.trash then return boss end
        end
    end
end

local function BuildMap()
    mapView = Map.NewView(left, left, false)
    mapView.onPick = PinPicked
    mapView.onDraw = MapDrawn
    mapView.down:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -(TAB_H + ROW_GAP))
    floorTabs = Parts.Tabs(left, LEFT_W, floorItems, FloorPicked)
    floorTabs:SetPoint("TOPLEFT", 0, -(TAB_H + ROW_GAP))
    floorName = ns.Font(left, TEXT_SIZE, nil, T.fg)
    floorName:SetPoint("LEFT", floorTabs, "RIGHT", FLOOR_NAME_GAP, 0)
    noMap = CreateFrame("Frame", nil, left)
    noMap:SetPoint("TOPLEFT", 0, -(TAB_H + ROW_GAP))
    ns.Solid(noMap, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(noMap, St.BORDER_RGB)
    noMap.art = noMap:CreateTexture(nil, "BORDER")
    noMap.art:SetAllPoints()
    noMap.art:SetTexCoord(BUTTON_ART.left, BUTTON_ART.right, BUTTON_ART.top, BUTTON_ART.bottom)
    noMap.art:SetAlpha(SOON_ART)
    local title = ns.Font(noMap, SOON_SIZE, nil, T.fg)
    title:SetPoint("BOTTOM", noMap, "CENTER", 0, SOON_GAP / 2)
    title:SetText(TEXT_COMING_SOON)
    local note = ns.Font(noMap, TEXT_SIZE, nil, T.muted)
    note:SetPoint("TOP", noMap, "CENTER", 0, -SOON_GAP / 2)
    note:SetText(TEXT_NO_MAP)
end

local function BuildViews()
    infoScroll = ns.UI.SlimScroll(left, LIST_BAR, LIST_BAR_GAP)
    infoScroll:SetPoint("BOTTOMLEFT")
    infoView = J.View.New(infoScroll)
    infoView.part = "RedrawInfo"
    infoView.openHistory = ShowHistory
    infoScroll:SetScrollChild(infoView)
    sideScroll = ns.UI.SlimScroll(left, LIST_BAR, LIST_BAR_GAP)
    sideScroll:SetPoint("TOPLEFT", 0, -SIDE_TOP)
    sideScroll:SetPoint("BOTTOMLEFT")
    sideView = J.View.New(sideScroll)
    sideView.questInline = true
    sideScroll:SetScrollChild(sideView)
end

local Pane = {}
J.DungeonPane = Pane

function Pane.Built()
    return frame ~= nil
end

function Pane.Build(window, view, scroll, navigate, step)
    mainView, mainScroll = view, scroll
    frame = CreateFrame("Frame", nil, window)
    headView = J.View.New(frame)
    headView.part = "DrawHead"
    headView.newLook = true
    headView.navigate, headView.step = navigate, step
    headView.onResize = PlaceMain
    headView:SetPoint("TOPLEFT")
    left = CreateFrame("Frame", nil, frame)
    tabs = Parts.Tabs(left, LEFT_W, tabItems, TabPicked)
    tabs:SetPoint("TOPLEFT")
    BuildMap()
    BuildViews()
    SizeLeft()
end

function Pane.Grown(roomW, roomH)
    local most = LEFT_W + math.max(0, math.min(roomW, math.floor(roomH * C.MAP_W / C.MAP_H)))
    wantW = math.min(math.floor(LEFT_W * (S.Get("mapSize") or 1)), most)
    return wantW - LEFT_W, MapHeight(wantW) - MapHeight(LEFT_W)
end

function Pane.Place(x, top, right, bottom)
    if leftW ~= wantW then SizeLeft() end
    width = frame:GetParent():GetWidth() - x - right
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", x, -top)
    frame:SetPoint("BOTTOMRIGHT", -right, bottom)
    headView:SetWidth(width)
    mainView:SetWidth(width - leftW - PANE_GAP - SCROLLBAR)
    PlaceMain()
end

function Pane.SetShown(shown)
    frame:SetShown(shown)
end

function Pane.Show(shown)
    local same = shown == dungeon
    dungeon = shown
    headView:DrawHead(shown)
    wipe(tabItems)
    tabItems[1], tabItems[2] = TAB_MAP, TAB_QUESTS
    if J.Keys[shown.key] then tabItems[3] = TAB_KEYS end
    Parts.SetTabs(tabs, tabItems)
    if mode == KEYS and not tabItems[3] then mode = MAP end
    if not same then
        picked = FirstBoss(shown)
        sideView.openQuest = nil
        if J.Maps[shown.key] then mapView:Open(shown) end
    end
    ShowMode()
end

function Pane.Pick(boss)
    ShowBoss(boss, false)
end

Pane.History = ShowHistory

function Pane.Redraw()
    if not (frame and frame:IsShown() and dungeon) then return end
    headView:Redraw()
    if mode == MAP then
        if J.Maps[dungeon.key] then mapView:Draw() end
        infoView:Redraw()
    else
        sideView:Redraw()
    end
end
