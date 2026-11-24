-- VanillaRatingBusterUI.lua
-- Compact options & custom stat-weight editor for VanillaRatingBuster (strict Lua 5.0).

VRB = VRB or {}

local ALL_STAT_KEYS = {
  "STR", "AGI", "STA", "INT", "SPI", "ARMOR",
  "ATTACKPOWER", "RANGEDATTACKPOWER", "FERALATTACKPOWER",
  "CRIT", "RANGEDCRIT", "TOHIT", "HASTE", "ARMORPEN",
  "DMG", "HEAL", "SPELLCRIT", "SPELLTOHIT", "SPELLPEN", "MANAREG",
  "ARCANEDMG", "FIREDMG", "FROSTDMG", "HOLYDMG", "NATUREDMG", "SHADOWDMG",
  "DEFENSE", "DODGE", "PARRY", "BLOCK",
  "HEALTH", "MANA",
}

local uiFrame = nil
local mainCheckboxes = {}
local specCheckboxes = {}
local selectedSpecIdx = 1
local selectedStatIdx = 1
local statList = {}

local function BuildStatListForSpec(specName)
  statList = {}
  local seen = {}
  local weights = VRB_WEIGHTS and VRB_WEIGHTS[specName]
  local db = VRB.EnsureDB()
  local custom = db.customWeights and db.customWeights[specName]

  if weights then
    for _, key in ipairs(ALL_STAT_KEYS) do
      if weights[key] ~= nil then
        table.insert(statList, key)
        seen[key] = true
      end
    end
    for key in pairs(weights) do
      if not seen[key] then
        table.insert(statList, key)
        seen[key] = true
      end
    end
  end

  if custom then
    for key in pairs(custom) do
      if not seen[key] then
        table.insert(statList, key)
        seen[key] = true
      end
    end
  end

  for _, key in ipairs(ALL_STAT_KEYS) do
    if not seen[key] then
      table.insert(statList, key)
      seen[key] = true
    end
  end
end

local function FormatWeightValue(val)
  if val == nil then
    return "0 (unset)"
  elseif type(val) == "table" then
    return "<" .. tostring(val[1]) .. ": " .. tostring(val[2]) .. " / " .. tostring(val[3])
  end
  return tostring(val)
end

local function CreateCheckbox(parent, name, label, x, y, onClick)
  local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
  cb:SetWidth(22)
  cb:SetHeight(22)
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local text = getglobal(name .. "Text")
  if text then
    text:SetText(label)
    text:SetFontObject(GameFontNormalSmall)
  end
  cb:SetScript("OnClick", onClick)
  return cb
end

local function RefreshUI()
  if not uiFrame then
    return
  end
  local db = VRB.EnsureDB()

  mainCheckboxes.enabled:SetChecked(db.enabled and 1 or nil)
  mainCheckboxes.compare:SetChecked(db.compare and 1 or nil)
  mainCheckboxes.enchant:SetChecked(db.ignoreEquippedEnchants and 1 or nil)
  mainCheckboxes.shift:SetChecked(db.shiftOnly and 1 or nil)
  mainCheckboxes.capAware:SetChecked(db.capAware and 1 or nil)
  mainCheckboxes.setBreakWarning:SetChecked(db.setBreakWarning and 1 or nil)

  local ratings = VRBGetValidRatings()
  local numRatings = table.getn(ratings)
  for i, cb in ipairs(specCheckboxes) do
    local specName = ratings[i]
    if specName then
      cb.specName = specName
      local text = getglobal(cb:GetName() .. "Text")
      if text then
        text:SetText(specName)
      end
      cb:SetChecked((not db.hiddenSpecs[specName]) and 1 or nil)
      cb:Show()
    else
      cb.specName = nil
      cb:Hide()
    end
  end

  if numRatings == 0 then
    uiFrame.specLabel:SetText("No specs")
    uiFrame.statLabel:SetText("-")
    uiFrame.weightInfo:SetText("")
    return
  end

  if selectedSpecIdx < 1 then selectedSpecIdx = numRatings end
  if selectedSpecIdx > numRatings then selectedSpecIdx = 1 end

  local specName = ratings[selectedSpecIdx]
  uiFrame.specLabel:SetText(specName)

  BuildStatListForSpec(specName)
  local numStats = table.getn(statList)
  if selectedStatIdx < 1 then selectedStatIdx = numStats end
  if selectedStatIdx > numStats then selectedStatIdx = 1 end

  local statKey = statList[selectedStatIdx]
  local defaultW = VRB_WEIGHTS and VRB_WEIGHTS[specName] and VRB_WEIGHTS[specName][statKey]
  local customW = db.customWeights and db.customWeights[specName] and db.customWeights[specName][statKey]
  local effectiveW = (customW ~= nil) and customW or defaultW

  if customW ~= nil then
    uiFrame.statLabel:SetText("|cff00ff00" .. statKey .. " *|r")
  else
    uiFrame.statLabel:SetText(statKey)
  end

  uiFrame.weightInfo:SetText("Default: " .. FormatWeightValue(defaultW) .. "  |  Active: " .. FormatWeightValue(effectiveW))
  if type(effectiveW) == "number" then
    uiFrame.weightEdit:SetText(tostring(effectiveW))
  else
    uiFrame.weightEdit:SetText("")
  end
end

local function CreateOptionsFrame()
  if uiFrame then
    return uiFrame
  end

  local f = CreateFrame("Frame", "VRBOptionsFrame", UIParent)
  f:SetWidth(350)
  f:SetHeight(420)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()
  table.insert(UISpecialFrames, "VRBOptionsFrame")

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -14)
  title:SetText("VanillaRatingBuster")

  local closeBtn = CreateFrame("Button", "VRBOptionsCloseButton", f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

  mainCheckboxes.enabled = CreateCheckbox(f, "VRBOptEnabled", "Enable VRB", 18, -42, function()
    local db = VRB.EnsureDB()
    db.enabled = (this:GetChecked() == 1)
  end)
  mainCheckboxes.capAware = CreateCheckbox(f, "VRBOptCapAware", "Cap-Aware (BCS)", 190, -42, function()
    local db = VRB.EnsureDB()
    db.capAware = (this:GetChecked() == 1)
  end)
  mainCheckboxes.compare = CreateCheckbox(f, "VRBOptCompare", "Compare (+/-)", 18, -64, function()
    local db = VRB.EnsureDB()
    db.compare = (this:GetChecked() == 1)
  end)
  mainCheckboxes.setBreakWarning = CreateCheckbox(f, "VRBOptSetWarn", "Set-Break Warn", 190, -64, function()
    local db = VRB.EnsureDB()
    db.setBreakWarning = (this:GetChecked() == 1)
  end)
  mainCheckboxes.enchant = CreateCheckbox(f, "VRBOptEnchant", "Ignore Equipped Enchants in Compare", 18, -86, function()
    local db = VRB.EnsureDB()
    db.ignoreEquippedEnchants = (this:GetChecked() == 1)
    if VRB.InvalidateEquippedCache then
      VRB.InvalidateEquippedCache()
    end
  end)
  mainCheckboxes.shift = CreateCheckbox(f, "VRBOptShift", "Show Only When Holding Shift", 18, -108, function()
    local db = VRB.EnsureDB()
    db.shiftOnly = (this:GetChecked() == 1)
  end)

  local specHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  specHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -138)
  specHeader:SetText("Visible Class Specs")

  for i = 1, 6 do
    local col = math.mod(i - 1, 2)
    local row = math.floor((i - 1) / 2)
    local cb = CreateCheckbox(f, "VRBOptSpec" .. i, "", 18 + col * 160, -156 - row * 22, function()
      local db = VRB.EnsureDB()
      if this.specName then
        if this:GetChecked() == 1 then
          db.hiddenSpecs[this.specName] = nil
        else
          db.hiddenSpecs[this.specName] = true
        end
      end
    end)
    table.insert(specCheckboxes, cb)
  end

  local weightHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  weightHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -230)
  weightHeader:SetText("Custom Stat Weights")

  local prevSpecBtn = CreateFrame("Button", "VRBOptPrevSpec", f, "UIPanelButtonTemplate")
  prevSpecBtn:SetWidth(24)
  prevSpecBtn:SetHeight(20)
  prevSpecBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -250)
  prevSpecBtn:SetText("<")
  prevSpecBtn:SetScript("OnClick", function()
    selectedSpecIdx = selectedSpecIdx - 1
    selectedStatIdx = 1
    RefreshUI()
  end)

  local nextSpecBtn = CreateFrame("Button", "VRBOptNextSpec", f, "UIPanelButtonTemplate")
  nextSpecBtn:SetWidth(24)
  nextSpecBtn:SetHeight(20)
  nextSpecBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -250)
  nextSpecBtn:SetText(">")
  nextSpecBtn:SetScript("OnClick", function()
    selectedSpecIdx = selectedSpecIdx + 1
    selectedStatIdx = 1
    RefreshUI()
  end)

  f.specLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.specLabel:SetPoint("LEFT", prevSpecBtn, "RIGHT", 6, 0)
  f.specLabel:SetPoint("RIGHT", nextSpecBtn, "LEFT", -6, 0)
  f.specLabel:SetJustifyH("CENTER")

  local prevStatBtn = CreateFrame("Button", "VRBOptPrevStat", f, "UIPanelButtonTemplate")
  prevStatBtn:SetWidth(24)
  prevStatBtn:SetHeight(20)
  prevStatBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -276)
  prevStatBtn:SetText("<")
  prevStatBtn:SetScript("OnClick", function()
    selectedStatIdx = selectedStatIdx - 1
    RefreshUI()
  end)

  local nextStatBtn = CreateFrame("Button", "VRBOptNextStat", f, "UIPanelButtonTemplate")
  nextStatBtn:SetWidth(24)
  nextStatBtn:SetHeight(20)
  nextStatBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -276)
  nextStatBtn:SetText(">")
  nextStatBtn:SetScript("OnClick", function()
    selectedStatIdx = selectedStatIdx + 1
    RefreshUI()
  end)

  f.statLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.statLabel:SetPoint("LEFT", prevStatBtn, "RIGHT", 6, 0)
  f.statLabel:SetPoint("RIGHT", nextStatBtn, "LEFT", -6, 0)
  f.statLabel:SetJustifyH("CENTER")

  f.weightInfo = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.weightInfo:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -304)
  f.weightInfo:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -304)
  f.weightInfo:SetJustifyH("CENTER")

  local edit = CreateFrame("EditBox", "VRBOptWeightEdit", f, "InputBoxTemplate")
  edit:SetWidth(90)
  edit:SetHeight(20)
  edit:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -326)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  edit:SetScript("OnEnterPressed", function()
    this:ClearFocus()
    local ratings = VRBGetValidRatings()
    local specName = ratings[selectedSpecIdx]
    local statKey = statList[selectedStatIdx]
    local num = tonumber(this:GetText())
    if specName and statKey and num then
      VRB.SetCustomWeight(specName, statKey, num)
      RefreshUI()
    end
  end)
  f.weightEdit = edit

  local applyBtn = CreateFrame("Button", "VRBOptApplyWeight", f, "UIPanelButtonTemplate")
  applyBtn:SetWidth(64)
  applyBtn:SetHeight(22)
  applyBtn:SetPoint("LEFT", edit, "RIGHT", 8, 0)
  applyBtn:SetText("Apply")
  applyBtn:SetScript("OnClick", function()
    edit:ClearFocus()
    local ratings = VRBGetValidRatings()
    local specName = ratings[selectedSpecIdx]
    local statKey = statList[selectedStatIdx]
    local num = tonumber(edit:GetText())
    if specName and statKey and num then
      VRB.SetCustomWeight(specName, statKey, num)
      VRB.Print("Set " .. specName .. " [" .. statKey .. "] = " .. num)
      RefreshUI()
    else
      VRB.Print("Enter a valid number.")
    end
  end)

  local resetStatBtn = CreateFrame("Button", "VRBOptResetStat", f, "UIPanelButtonTemplate")
  resetStatBtn:SetWidth(74)
  resetStatBtn:SetHeight(22)
  resetStatBtn:SetPoint("LEFT", applyBtn, "RIGHT", 6, 0)
  resetStatBtn:SetText("Reset Stat")
  resetStatBtn:SetScript("OnClick", function()
    local ratings = VRBGetValidRatings()
    local specName = ratings[selectedSpecIdx]
    local statKey = statList[selectedStatIdx]
    if specName and statKey then
      VRB.SetCustomWeight(specName, statKey, nil)
      RefreshUI()
    end
  end)

  local resetSpecBtn = CreateFrame("Button", "VRBOptResetSpec", f, "UIPanelButtonTemplate")
  resetSpecBtn:SetWidth(120)
  resetSpecBtn:SetHeight(22)
  resetSpecBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 16)
  resetSpecBtn:SetText("Reset Spec Weights")
  resetSpecBtn:SetScript("OnClick", function()
    local ratings = VRBGetValidRatings()
    local specName = ratings[selectedSpecIdx]
    if specName then
      VRB.ResetCustomWeights(specName)
      VRB.Print("Cleared custom weights for " .. specName)
      RefreshUI()
    end
  end)

  local resetAllBtn = CreateFrame("Button", "VRBOptResetAll", f, "UIPanelButtonTemplate")
  resetAllBtn:SetWidth(100)
  resetAllBtn:SetHeight(22)
  resetAllBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
  resetAllBtn:SetText("Reset All")
  resetAllBtn:SetScript("OnClick", function()
    VanillaRatingBusterDB = nil
    VRB.EnsureDB()
    if VRB.InvalidateEquippedCache then
      VRB.InvalidateEquippedCache()
    end
    VRB.Print("All settings reset to defaults.")
    RefreshUI()
  end)

  uiFrame = f
  return f
end

function VRB.RefreshUI()
  if uiFrame and uiFrame:IsVisible() then
    RefreshUI()
  end
end

function VRB.ToggleUI()
  local f = CreateOptionsFrame()
  if f:IsVisible() then
    f:Hide()
  else
    RefreshUI()
    f:Show()
  end
end
