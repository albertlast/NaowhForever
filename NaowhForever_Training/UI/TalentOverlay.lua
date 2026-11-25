-- TalentOverlay.lua: turns the Talent Overlay on and off, and redraws its glow and panel while a talent window is open.
local ns = _G.NaowhForever

local Training = ns.Training
local S = Training.Settings
local Next = Training.Next

local WINDOW_ADDONS = { "Blizzard_PlayerSpells", "EllesmereUIForeverEssentials" }
local EVENTS = {
    "PLAYER_LEVEL_UP", "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_NODE_ENTRY_UPDATED",
    "TRAIT_TREE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_TALENT_UPDATE",
}
local SPELL_EVENT = "SPELL_DATA_LOAD_RESULT"
local MAX_RETRIES = 10
local GLOW_KEY = "talentOverlayGlow"
local DRAWER_KEY = "talentOverlayDrawer"
local PREVIEW_KEY = "talentOverlayPreview"
local TEXT_TITLE = ns.L("Talent Overlay")

local view = { title = TEXT_TITLE, panelOpen = true, previewMarks = {} }

local events
local installed = false
local queued = false
local listeningForTalents = false
local listeningForSpellNames = false
local ellesmereHooked = false
local retries = 0
local hooked = {}
local Refresh

local function On()
    return Training.On() and S.Get("talentOverlay") and not ns.GamepadStandDown()
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, Refresh)
end

local function Schedule()
    if not installed or not On() then return end
    retries = 0
    Queue()
end

local function ListenForTalents(windowOpen)
    if windowOpen == listeningForTalents then return end
    listeningForTalents = windowOpen
    if windowOpen then
        for _, event in ipairs(EVENTS) do
            events:RegisterEvent(event)
        end
    else
        events:UnregisterAllEvents()
        listeningForSpellNames = false
    end
end

local function ListenForSpellNames(wanted)
    if wanted == listeningForSpellNames then return end
    listeningForSpellNames = wanted
    if wanted then
        events:RegisterEvent(SPELL_EVENT)
    else
        events:UnregisterEvent(SPELL_EVENT)
    end
end

local function Hook(page)
    if hooked[page] then return end
    hooked[page] = true
    page:HookScript("OnShow", Schedule)
    page:HookScript("OnHide", Schedule)
end

local function OnEllesmereEscape(frame)
    if not frame then return end
    if frame == EUI_ClassicTalents then Hook(frame) end
end

local function HookEllesmere()
    if ellesmereHooked then return end
    if not EllesmereUI or not EllesmereUI.RegisterEscapeClose then return end
    ellesmereHooked = true
    hooksecurefunc(EllesmereUI, "RegisterEscapeClose", OnEllesmereEscape)
end

local function OnWindowAddOnLoaded()
    Next.EachTalentPage(Hook)
    HookEllesmere()
    Schedule()
end

local function HidePreview(fromPlace)
    local marks = view.previewMarks
    for place = fromPlace, #marks do
        Next.PlaceMark(marks[place], nil)
    end
end

local function ClearView()
    Next.HideDrawer(view, false)
    Next.PlaceMark(view.mark, nil)
    HidePreview(1)
    view.open = false
end

local function UpdateDrawer(window, model)
    if not S.Get(DRAWER_KEY) then
        Next.HideDrawer(view, true)
        return
    end
    Next.ShowButton(view)
    if not view.panelOpen then
        Next.HideDrawer(view, false)
        return
    end
    local summary = Next.DrawerSummary(model)
    if summary ~= view.paintedSummary then
        view.paintedSummary = summary
        Next.PaintDrawer(view, model)
    end
    Next.ShowDrawer(view, window)
end

local function UpdateMark(window, model)
    if model.count == 0 or not S.Get(GLOW_KEY) then
        Next.PlaceMark(view.mark, nil)
        return
    end
    local nextTalent = model.rows[1]
    local button = Next.ButtonFor(view.mark, window, nextTalent.node)
    Next.PlaceMark(view.mark, button, nextTalent.ready)
    if not button then view.buttonMissing = true end
end

local function UpdatePreview(window, model)
    if not S.Get(PREVIEW_KEY) then
        HidePreview(1)
        return
    end
    local buttons = Next.ButtonsByNode(window)
    local marks = view.previewMarks
    for place = 1, model.previewCount do
        local talent = model.preview[place]
        local mark = marks[place]
        if not mark then
            mark = Next.NewPreviewMark()
            marks[place] = mark
        end
        local button = buttons[talent.node]
        Next.PlacePreviewMark(mark, button, talent)
        if not button then view.buttonMissing = true end
    end
    HidePreview(model.previewCount + 1)
end

local function UpdateView()
    view.buttonMissing = false
    view.namesLoading = false
    local window = Next.ClassWindow()
    if not window then
        ClearView()
        return
    end
    view.open = true
    Hook(window.content)
    if view.docked ~= window.content then
        view.docked = window.content
        view.paintedSummary = nil
        Next.HideDrawer(view, false)
        Next.Dock(view, window)
    end
    local model = Next.ClassModel()
    view.namesLoading = model.namesLoading
    UpdateDrawer(window, model)
    UpdateMark(window, model)
    UpdatePreview(window, model)
end

function Refresh()
    queued = false
    if not installed or not On() then return end
    UpdateView()
    ListenForTalents(view.open)
    ListenForSpellNames(view.open and view.namesLoading)
    if view.buttonMissing and retries < MAX_RETRIES then
        retries = retries + 1
        Queue()
    end
end

local function Quiet()
    if events then events:UnregisterAllEvents() end
    listeningForTalents = false
    listeningForSpellNames = false
    Next.HideDrawer(view, true)
    if view.mark then Next.PlaceMark(view.mark, nil) end
    HidePreview(1)
    view.open = false
    view.docked = nil
    view.paintedSummary = nil
end

local function Install()
    installed = true
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", Schedule)
    view.mark = Next.NewMark()
    for _, name in ipairs(WINDOW_ADDONS) do
        EventUtil.ContinueOnAddOnLoaded(name, OnWindowAddOnLoaded)
    end
end

local function Apply()
    if not On() then
        Quiet()
        return
    end
    if not installed then Install() end
    Schedule()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "talentOverlay" then
        Apply()
    elseif key == DRAWER_KEY then
        view.panelOpen = true
        Schedule()
    elseif key == GLOW_KEY or key == PREVIEW_KEY then
        Schedule()
    end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

Next.Redraw = Schedule
Training.OnChange(Schedule)
S.OnChange(OnSettingChanged)
ns.OnApply(Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)
