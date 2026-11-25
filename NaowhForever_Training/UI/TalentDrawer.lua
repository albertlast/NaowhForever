-- TalentDrawer.lua: the side panel beside a talent window (build picker, next talents, switches) and its button.
local ns = _G.NaowhForever

local T = ns.THEME
local UI = ns.UI
local Shared = ns.Shared
local Parts = Shared.Parts
local St = Shared.Style
local Training = ns.Training
local S = Training.Settings
local Next = Training.Next

local PANEL_W = 340
local ROW_H, BIG_H, PICK_H = 28, 48, 40
local BIG_ICON, SMALL_ICON, ICON_GAP, ICON_CROP = 30, 16, 10, 0.08
local BIG_TEXT_DROP = 1
local LABEL_GAP = 8
local CONTROL_LEVEL = 2
local UNDER_SEARCH, SEARCH_LEVEL = 64, 2
local BUTTON_SIZE = 32
local NO_SEARCH_X, NO_SEARCH_Y, NO_SEARCH_LEVEL = -30, -4, 20
local MAX_FRAME_LEVEL = 9000
local GLOW_KEY = "talentOverlayGlow"
local PREVIEW_KEY = "talentOverlayPreview"
local NO_EVENTS = {}
local BUILDS_TAB = "builds"
local TEXT_BUILD = "Build"
local TEXT_OPEN_BUILDS = "Open Builds"
local TEXT_IMPORT = "Import"
local TEXT_NEXT = "Next Talent"
local TEXT_THEN = "Then"
local TEXT_PROGRESS = "Progress"
local TEXT_OPTIONS = "Options"
local TEXT_PICK = ns.L("Build to Light")
local TEXT_PICK_TIP = ns.L("Lights this build's next talent without following it, so no points are spent for you.")
local TEXT_FOLLOWED = ns.L("%s (followed)")
local TEXT_NO_PICK = ns.L("No build picked")
local TEXT_GLOW = ns.L("Glow on the Next Talent")
local TEXT_GLOW_TIP = ns.L("A glow around the next talent's button that pulses while you have a point to spend.")
local TEXT_PREVIEW = ns.L("Preview Full Build")
local TEXT_PREVIEW_TIP = ns.L("Lights every talent the build takes, with how many ranks it takes in each.")
local TEXT_SHOW_HIDE = ns.L("Show or hide this panel.")

local summaryPieces = {}

local function LevelAbove(frame, steps)
    return math.min(frame:GetFrameLevel() + steps, MAX_FRAME_LEVEL)
end

local function FullOpacity()
    return 1
end

local function OpenBuilds()
    ns.OpenTrainingWindow(nil, BUILDS_TAB)
end

local function PickImported(classID, index)
    local _, _, myClass = UnitClass("player")
    if classID ~= myClass then return end
    local build = Training.Builds(classID)[index]
    Next.SetPick(Training.BuildKey(classID, build))
end

local function ImportBuild()
    Training.PromptImport(PickImported)
end

local function SpellTip(row)
    if not row.spellID then return end
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    GameTooltip:SetSpellByID(row.spellID)
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

local function NewPicker(view)
    local row = CreateFrame("Frame", nil, view)
    row.values = {}
    row.order = {}
    local function Picked()
        return row.pickKey
    end
    local level = LevelAbove(row, CONTROL_LEVEL)
    local dropdown = UI.BuildDropdownControl(row, nil, level, row.values, row.order, Picked, Next.SetPick)
    dropdown:ClearAllPoints()
    dropdown:SetPoint("LEFT")
    dropdown:SetPoint("RIGHT")
    ns.Tooltip(dropdown, TEXT_PICK, TEXT_PICK_TIP)
    row.dropdown = dropdown
    return row
end

local function SetPicker(row, model)
    local values = row.values
    local order = row.order
    wipe(values)
    wipe(order)
    for _, build in ipairs(model.builds) do
        local key = Training.BuildKey(model.classID, build)
        values[key] = Next.BuildLabel(build)
        order[#order + 1] = key
    end
    if model.followed then
        values[Next.FOLLOWED] = TEXT_FOLLOWED:format(Next.BuildLabel(model.followed))
    else
        values[Next.FOLLOWED] = TEXT_NO_PICK
    end
    order[#order + 1] = Next.FOLLOWED
    row.pickKey = model.pickKey
    row.dropdown._refreshLabel()
    return PICK_H
end

local function NewTalentRow(view, iconSize)
    local row = CreateFrame("Frame", nil, view)
    row:EnableMouse(true)
    row:SetScript("OnEnter", SpellTip)
    row:SetScript("OnLeave", HideTip)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(iconSize, iconSize)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.name = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    return row
end

local function NewNextTalent(view)
    local row = NewTalentRow(view, BIG_ICON)
    local textTop = (BIG_H - BIG_ICON) / 2 + BIG_TEXT_DROP
    local textLeft = BIG_ICON + ICON_GAP
    row.name:SetPoint("TOPLEFT", textLeft, -textTop)
    row.name:SetPoint("TOPRIGHT", 0, -textTop)
    row.sub = ns.Font(row, St.SMALL_SIZE, nil, T.muted)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    row.sub:SetPoint("BOTTOMLEFT", textLeft, textTop)
    row.sub:SetPoint("BOTTOMRIGHT", 0, textTop)
    return row
end

local function NewLaterTalent(view)
    local row = NewTalentRow(view, SMALL_ICON)
    row.when = ns.Font(row, St.SMALL_SIZE, nil, T.muted)
    row.when:SetJustifyH("RIGHT")
    row.when:SetPoint("RIGHT")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", LABEL_GAP, 0)
    row.name:SetPoint("RIGHT", row.when, "LEFT", -LABEL_GAP, 0)
    return row
end

local function FillTalentRow(row, talent)
    row.spellID = talent.spellID
    row.icon:SetTexture(talent.icon)
    row.name:SetText(talent.name)
end

local function SetNextTalent(row, talent)
    FillTalentRow(row, talent)
    row.sub:SetText(talent.sub)
    return BIG_H
end

local function SetLaterTalent(row, talent)
    FillTalentRow(row, talent)
    row.when:SetText(talent.when)
    return ROW_H
end

local function NewSwitchRow(view, key, text, tip)
    local function IsOn()
        return S.Get(key)
    end
    local function SetOn(on)
        S.Set(key, on)
    end
    local row = CreateFrame("Frame", nil, view)
    row:EnableMouse(true)
    local toggle = UI.BuildToggleControl(row, LevelAbove(row, CONTROL_LEVEL), IsOn, SetOn)
    toggle:SetPoint("RIGHT")
    local label = ns.Font(row, St.TEXT_SIZE, nil, T.fg)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetPoint("LEFT")
    label:SetPoint("RIGHT", toggle, "LEFT", -LABEL_GAP, 0)
    label:SetText(text)
    ns.Tooltip(row, text, tip)
    row.toggle = toggle
    return row
end

local function NewGlowRow(view)
    return NewSwitchRow(view, GLOW_KEY, TEXT_GLOW, TEXT_GLOW_TIP)
end

local function NewPreviewRow(view)
    return NewSwitchRow(view, PREVIEW_KEY, TEXT_PREVIEW, TEXT_PREVIEW_TIP)
end

local function SetSwitchRow(row)
    row.toggle._refreshValue()
    return ROW_H
end

local function AddNote(body, text)
    if text then body:Note(text) end
end

local Draw = {}

function Draw:Redraw()
    local model = self.model
    self:Clear()
    self:SectionLink(TEXT_BUILD, TEXT_OPEN_BUILDS, OpenBuilds, nil, TEXT_IMPORT, ImportBuild)
    self:Add("picker", model)
    self:Section(TEXT_NEXT)
    if model.notice then
        self:Note(model.notice)
    elseif model.count > 0 then
        self:Add("nextTalent", model.rows[1])
    end
    if model.count > 1 then
        self:Section(TEXT_THEN)
        for place = 2, model.count do
            self:Add("laterTalent", model.rows[place])
        end
    end
    if model.progress or model.extra or model.follow then
        self:Section(TEXT_PROGRESS)
        AddNote(self, model.progress)
        AddNote(self, model.extra)
        AddNote(self, model.follow)
    end
    self:Section(TEXT_OPTIONS)
    self:Add("glow")
    self:Add("preview")
    self:Fit(NO_EVENTS)
end

local function NewBody(scroll)
    local kinds = Shared.View.NewKinds()
    kinds.picker = { New = NewPicker, Set = SetPicker }
    kinds.nextTalent = { New = NewNextTalent, Set = SetNextTalent }
    kinds.laterTalent = { New = NewLaterTalent, Set = SetLaterTalent }
    kinds.glow = { New = NewGlowRow, Set = SetSwitchRow }
    kinds.preview = { New = NewPreviewRow, Set = SetSwitchRow }
    return Shared.View.New(scroll, kinds, Draw)
end

local function PanelHidden(panel)
    local view = panel.drawer
    if view.hidingPanel then return end
    local window = view.docked
    if not window or not window:IsVisible() then return end
    view.panelOpen = false
    Next.PaintButton(view)
end

local function BuildPanel(view)
    local panel = Parts.SidePanel({}, NewBody, FullOpacity, PANEL_W)
    panel:Hide()
    panel.drawer = view
    panel:HookScript("OnHide", PanelHidden)
    panel.title:SetText(view.title)
    view.panel = panel
    view.body = panel.view
end

local function ButtonClicked(button)
    local view = button.drawer
    view.panelOpen = not view.panelOpen
    Next.PaintButton(view)
    Next.Redraw()
end

local function NewButton(view, parent)
    local button = Parts.LogoButton(parent, ButtonClicked)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button.drawer = view
    ns.Tooltip(button, view.title, TEXT_SHOW_HIDE)
    view.button = button
end

local function AddPiece(piece)
    if piece == nil then
        summaryPieces[#summaryPieces + 1] = ""
    else
        summaryPieces[#summaryPieces + 1] = tostring(piece)
    end
end

function Next.DrawerSummary(model)
    wipe(summaryPieces)
    AddPiece(model.pickKey)
    if model.builds then
        AddPiece(#model.builds)
        for _, build in ipairs(model.builds) do
            AddPiece(Training.BuildKey(model.classID, build))
            AddPiece(Next.BuildLabel(build))
        end
    else
        AddPiece(nil)
    end
    AddPiece(model.notice)
    AddPiece(model.progress)
    AddPiece(model.extra)
    AddPiece(model.follow)
    AddPiece(S.Get(GLOW_KEY))
    AddPiece(S.Get(PREVIEW_KEY))
    for place = 1, model.count do
        local row = model.rows[place]
        AddPiece(row.icon)
        AddPiece(row.name)
        AddPiece(row.sub)
        AddPiece(row.when)
    end
    return table.concat(summaryPieces, ";")
end

function Next.PaintDrawer(view, model)
    if not view.panel then BuildPanel(view) end
    view.body.model = model
    view.body:Redraw()
end

function Next.ShowDrawer(view, window)
    if view.panel:IsShown() then return end
    Parts.ShowBeside(view.panel, window.outer)
end

function Next.HideDrawer(view, alsoButton)
    if view.panel then
        view.hidingPanel = true
        view.panel:Hide()
        view.hidingPanel = false
    end
    if alsoButton and view.button then view.button:Hide() end
end

function Next.PaintButton(view)
    if not view.button then return end
    Parts.LightLogoButton(view.button, view.panelOpen)
end

function Next.ShowButton(view)
    if not view.button then return end
    view.button:Show()
    Next.PaintButton(view)
end

function Next.Dock(view, window)
    if not view.button then NewButton(view, window.content) end
    local button = view.button
    button:SetParent(window.content)
    button:ClearAllPoints()
    local search = window.search
    if search then
        button:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -UNDER_SEARCH)
        button:SetFrameLevel(LevelAbove(search, SEARCH_LEVEL))
    else
        button:SetPoint("TOPRIGHT", window.outer, "TOPRIGHT", NO_SEARCH_X, NO_SEARCH_Y)
        button:SetFrameLevel(LevelAbove(window.outer, NO_SEARCH_LEVEL))
    end
end
