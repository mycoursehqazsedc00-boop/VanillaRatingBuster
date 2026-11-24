
-- GetItemInfo's equipLoc return is the raw, language-independent enum
-- string (e.g. "INVTYPE_HEAD"), not a localized label -- the unquoted
-- globals previously here (plus the deDE/enGB string fallbacks someone
-- added to compensate) evaluated to _G["INVTYPE_HEAD"], a LOCALIZED label
-- ("Head"), which would never match the raw enum VRBCheckItemType is
-- actually compared against. That made the filter below silently reject
-- every item. Fixed by matching the raw enum directly; also adds
-- INVTYPE_RANGEDRIGHT, which on 1.12 (pre-2.4.3) is what Wands, Guns and
-- Crossbows actually report -- INVTYPE_RANGED alone only covers Bows.
local scoredItemTypes = {
  "INVTYPE_2HWEAPON", "INVTYPE_CHEST", "INVTYPE_CLOAK",
  "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_HAND", "INVTYPE_HEAD", "INVTYPE_HOLDABLE",
  "INVTYPE_LEGS", "INVTYPE_NECK", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC", "INVTYPE_ROBE", "INVTYPE_SHIELD",
  "INVTYPE_SHOULDER", "INVTYPE_TRINKET", "INVTYPE_WAIST", "INVTYPE_WEAPON",
  "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_WRIST",
}

local BCS_ENCHANT_TO_VRB_STAT = {
  ranged_crit = "RANGEDCRIT",
  hit = "TOHIT",
  spell_hit = "SPELLTOHIT",
  spell_crit = "SPELLCRIT",
  haste = "HASTE",
  armor_pen = "ARMORPEN",
  spell_pen = "SPELLPEN",
}

local RANGED_EQUIP_LOCS = {
  INVTYPE_RANGED = true,
  INVTYPE_RANGEDRIGHT = true,
  INVTYPE_THROWN = true,
}

local function VRB_ApplyEnchantStats(bonuses, itemLink, equipLoc)
  if not bonuses or not itemLink or not BCS or not BCS.EnchantStats or type(itemLink) ~= "string" then
    return
  end
  local _, _, enchantId = string.find(itemLink, "item:%d+:(%d+)")
  local extra = enchantId and BCS.EnchantStats[tonumber(enchantId)]
  if extra and (not extra.slot or (extra.slot == 18 and equipLoc and RANGED_EQUIP_LOCS[equipLoc])) then
    for stat, amount in pairs(extra) do
      if stat ~= "slot" then
        local vrbStat = BCS_ENCHANT_TO_VRB_STAT[stat]
        if vrbStat then
          bonuses[vrbStat] = (tonumber(bonuses[vrbStat]) or 0) + amount
        end
      end
    end
  end
end

local CLASS_TOKEN_TO_LABEL = {
  WARRIOR = "Warrior",
  MAGE    = "Mage",
  HUNTER  = "Hunter",
  DRUID   = "Druid",
  PALADIN = "Paladin",
  PRIEST  = "Priest",
  ROGUE   = "Rogue",
  SHAMAN  = "Shaman",
  WARLOCK = "Warlock",
}


function VRBRound(num, places)
  local mult = 10^(places or 0)
  return math.floor(num * mult + 0.5) / mult
end


function VRBCheckItemType(slot)
  for id, scoredSlot in pairs(scoredItemTypes) do
    if slot == scoredSlot then
      return true
    end
  end
  return nil
end


function VRBGetValidRatings()
  local className, classFileName = UnitClass("player")
  local labelKey = (classFileName and CLASS_TOKEN_TO_LABEL[classFileName]) or className

  if labelKey and VRB_LABELS and VRB_LABELS[labelKey] then
    return VRB_LABELS[labelKey]
  end
  return {}
end


VRB = VRB or {}

local function VRB_GetCustomSpecTable(weightTable)
  if type(VanillaRatingBusterDB) ~= "table" or type(VanillaRatingBusterDB.customWeights) ~= "table" then
    return nil
  end
  return VanillaRatingBusterDB.customWeights[weightTable]
end

function VRBCalculateRating(weightTable, bonuses)

  local baseScore = 0
  local weightTypes = VRB_WEIGHTS and VRB_WEIGHTS[weightTable]
  if not weightTypes or not bonuses then
    return 0
  end

  local customSpec = VRB_GetCustomSpecTable(weightTable)

  for t, defaultW in pairs(weightTypes) do
    local currentBonus = 0
    if BCSItemScan and BCSItemScan.bonuses and BCSItemScan.bonuses[t] then
      currentBonus = BCSItemScan.bonuses[t]
    end

    local w = defaultW
    if customSpec and customSpec[t] ~= nil then
      w = customSpec[t]
    end

    if bonuses[t] then
      if type(w) == "table" then
        local threshold = w[1]
        local beforeWeight = w[2]
        local afterWeight = w[3]

        if tonumber(currentBonus) < tonumber(threshold) then
          baseScore = baseScore + (bonuses[t] * beforeWeight)
        else
          baseScore = baseScore + (bonuses[t] * afterWeight)
        end
      else
        baseScore = baseScore + (bonuses[t] * w)
      end
    end
  end

  if customSpec then
    for t, w in pairs(customSpec) do
      if weightTypes[t] == nil and bonuses[t] and type(w) == "number" then
        baseScore = baseScore + (bonuses[t] * w)
      end
    end
  end

  return VRBRound(baseScore, 2)

end


-- Trigger mechanism rewritten from the original's "child frame of
-- GameTooltip, relying on OnShow" approach. That relies on GameTooltip's
-- OnShow firing only once everything is fully populated, but Blizzard's
-- SetInventoryItem/SetBagItem can call :Show() before all stat lines are
-- added, so the child's OnShow sometimes fired on an incomplete tooltip --
-- scanning found nothing, so no score ever showed, even though the scan
-- logic itself was correct. Hooking the population functions directly
-- (same technique BetterCharacterPanel's gear-score tooltip line uses)
-- guarantees this runs only after the real one has fully returned.
local function VRB_EnsureDB()
  if type(VanillaRatingBusterDB) ~= "table" then
    VanillaRatingBusterDB = {}
  end
  if VanillaRatingBusterDB.enabled == nil then
    VanillaRatingBusterDB.enabled = true
  end
  if VanillaRatingBusterDB.compare == nil then
    VanillaRatingBusterDB.compare = true
  end
  if VanillaRatingBusterDB.shiftOnly == nil then
    VanillaRatingBusterDB.shiftOnly = false
  end
  if VanillaRatingBusterDB.ignoreEquippedEnchants == nil then
    VanillaRatingBusterDB.ignoreEquippedEnchants = true
  end
  if VanillaRatingBusterDB.capAware == nil then
    VanillaRatingBusterDB.capAware = true
  end
  if VanillaRatingBusterDB.setBreakWarning == nil then
    VanillaRatingBusterDB.setBreakWarning = true
  end
  if type(VanillaRatingBusterDB.hiddenSpecs) ~= "table" then
    VanillaRatingBusterDB.hiddenSpecs = {}
  end
  if type(VanillaRatingBusterDB.customWeights) ~= "table" then
    VanillaRatingBusterDB.customWeights = {}
  end
  return VanillaRatingBusterDB
end

local EQUIP_LOC_TO_SLOTS = {
  INVTYPE_HEAD           = { "HeadSlot" },
  INVTYPE_NECK           = { "NeckSlot" },
  INVTYPE_SHOULDER       = { "ShoulderSlot" },
  INVTYPE_CHEST          = { "ChestSlot" },
  INVTYPE_ROBE           = { "ChestSlot" },
  INVTYPE_WAIST          = { "WaistSlot" },
  INVTYPE_LEGS           = { "LegsSlot" },
  INVTYPE_FEET           = { "FeetSlot" },
  INVTYPE_WRIST          = { "WristSlot" },
  INVTYPE_HAND           = { "HandsSlot" },
  INVTYPE_CLOAK          = { "BackSlot" },
  INVTYPE_FINGER         = { "Finger0Slot", "Finger1Slot" },
  INVTYPE_TRINKET        = { "Trinket0Slot", "Trinket1Slot" },
  INVTYPE_WEAPON         = { "MainHandSlot", "SecondaryHandSlot" },
  INVTYPE_WEAPONMAINHAND = { "MainHandSlot" },
  INVTYPE_2HWEAPON       = { "MainHandSlot", "SecondaryHandSlot" },
  INVTYPE_WEAPONOFFHAND  = { "SecondaryHandSlot" },
  INVTYPE_SHIELD         = { "SecondaryHandSlot" },
  INVTYPE_HOLDABLE       = { "SecondaryHandSlot" },
  INVTYPE_RANGED         = { "RangedSlot" },
  INVTYPE_RANGEDRIGHT    = { "RangedSlot" },
  INVTYPE_THROWN         = { "RangedSlot" },
  INVTYPE_RELIC          = { "RangedSlot" },
}

local DUAL_WIELD_CLASSES = {
  WARRIOR = true,
  ROGUE   = true,
  HUNTER  = true,
  SHAMAN  = true,
}

local VRBCompareTooltip = CreateFrame("GameTooltip", "VRBCompareTooltip", nil, "GameTooltipTemplate")
VRBCompareTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local VRB_HoveredScores = {}
local VRB_BaselineScores = {}
local VRB_SlotScoresA = {}
local VRB_SlotScoresB = {}

local function VRB_IsEnchantLine(lineObj, text)
  if not lineObj or not text or text == "" then
    return false
  end
  local r, g, b = lineObj:GetTextColor()
  if not (g and g > 0.75 and r and r < 0.3 and b and b < 0.3) then
    return false
  end
  if string.sub(text, 1, 6) == "Equip:"
    or string.sub(text, 1, 4) == "Set:"
    or string.sub(text, 1, 4) == "Use:"
    or string.sub(text, 1, 14) == "Chance on hit:"
    or string.sub(text, 1, 1) == "(" then
    return false
  end
  return true
end

local VRB_EquippedScoreCache = {}
local VRB_LastBonusesRef = nil

local function VRB_InvalidateEquippedCache()
  for k in pairs(VRB_EquippedScoreCache) do
    VRB_EquippedScoreCache[k] = nil
  end
  VRB_LastBonusesRef = nil
end

local function VRB_ScanEquippedSlotScores(slotName, ratings, ignoreEnchants, outScores)
  if BCSItemScan and BCSItemScan.bonuses ~= VRB_LastBonusesRef then
    VRB_InvalidateEquippedCache()
    VRB_LastBonusesRef = BCSItemScan.bonuses
  end

  local slotId = GetInventorySlotInfo(slotName)
  if not slotId then
    for _, r in ipairs(ratings) do
      outScores[r] = 0
    end
    return false
  end

  local eqLink = (GetInventoryItemLink and GetInventoryItemLink("player", slotId)) or ""
  local ignoreFlag = ignoreEnchants and true or false
  local cached = VRB_EquippedScoreCache[slotName]
  if cached and cached.link == eqLink and cached.ignoreEnchants == ignoreFlag then
    for _, r in ipairs(ratings) do
      outScores[r] = cached.scores[r] or 0
    end
    return cached.hasItem
  end

  for _, r in ipairs(ratings) do
    outScores[r] = 0
  end

  -- Zero-duplication fast path: reuse per-slot equipped bonuses already scanned by BCSItemScan
  if BCSItemScan and type(BCSItemScan.GetEquippedSlotStats) == "function" then
    local bcsBonuses, bcsLink = BCSItemScan:GetEquippedSlotStats(slotName, ignoreFlag)
    if bcsBonuses and bcsLink and bcsLink == eqLink then
      local cachedScores = {}
      local workBonuses = {}
      for k, v in pairs(bcsBonuses) do
        workBonuses[k] = v
      end
      if not ignoreFlag and eqLink ~= "" then
        local eqLoc = (slotName == "RangedSlot") and "INVTYPE_RANGED" or nil
        VRB_ApplyEnchantStats(workBonuses, eqLink, eqLoc)
      end
      for _, r in ipairs(ratings) do
        local s = VRBCalculateRating(r, workBonuses)
        outScores[r] = s
        cachedScores[r] = s
      end
      VRB_EquippedScoreCache[slotName] = {
        link = eqLink,
        ignoreEnchants = ignoreFlag,
        hasItem = true,
        scores = cachedScores,
      }
      return true
    end
  end

  VRBCompareTooltip:ClearLines()
  local okHas, hasItem = pcall(VRBCompareTooltip.SetInventoryItem, VRBCompareTooltip, "player", slotId)
  if not okHas or not hasItem then
    VRB_EquippedScoreCache[slotName] = {
      link = eqLink,
      ignoreEnchants = ignoreFlag,
      hasItem = false,
      scores = {},
    }
    return false
  end

  local lines = VRBCompareTooltip:NumLines()
  if not lines or lines < 2 then
    VRB_EquippedScoreCache[slotName] = {
      link = eqLink,
      ignoreEnchants = ignoreFlag,
      hasItem = false,
      scores = {},
    }
    return false
  end

  local eqBonuses
  if BCSItemScan and type(BCSItemScan.ScanTooltip) == "function" then
    eqBonuses = BCSItemScan:ScanTooltip(VRBCompareTooltip, { ignoreEnchants = ignoreFlag })
  else
    BCSItemScan.temp.sets = {}
    BCSItemScan.temp.set = ""
    BCSItemScan.temp.bonuses = {}
    BCSItemScan.temp.details = {}
    BCSItemScan.temp.slot = ""

    for i = 2, lines, 1 do
      local tmpText = getglobal("VRBCompareTooltipTextLeft" .. i)
      if tmpText then
        local line = tmpText:GetText()
        if line and (not ignoreEnchants or not VRB_IsEnchantLine(tmpText, line)) then
          BCSItemScan:ScanLine(line)
        end
      end
    end
    eqBonuses = BCSItemScan.temp.bonuses
  end
  local cachedScores = {}
  if eqBonuses then
    if not ignoreEnchants and eqLink ~= "" then
      local eqLoc = (slotName == "RangedSlot") and "INVTYPE_RANGED" or nil
      VRB_ApplyEnchantStats(eqBonuses, eqLink, eqLoc)
    end
    for _, r in ipairs(ratings) do
      local s = VRBCalculateRating(r, eqBonuses)
      outScores[r] = s
      cachedScores[r] = s
    end
  end

  VRB_EquippedScoreCache[slotName] = {
    link = eqLink,
    ignoreEnchants = ignoreFlag,
    hasItem = true,
    scores = cachedScores,
  }
  return true
end

local function VRB_GetBaselineScores(itemSlot, ratings, ignoreEnchants, outScores)
  local slots = itemSlot and EQUIP_LOC_TO_SLOTS[itemSlot]
  if not slots then
    return false
  end

  if table.getn(slots) == 1 then
    VRB_ScanEquippedSlotScores(slots[1], ratings, ignoreEnchants, outScores)
    return true
  end

  local hasA = VRB_ScanEquippedSlotScores(slots[1], ratings, ignoreEnchants, VRB_SlotScoresA)
  local hasB = VRB_ScanEquippedSlotScores(slots[2], ratings, ignoreEnchants, VRB_SlotScoresB)

  if itemSlot == "INVTYPE_2HWEAPON" then
    for _, r in ipairs(ratings) do
      outScores[r] = (VRB_SlotScoresA[r] or 0) + (VRB_SlotScoresB[r] or 0)
    end
    return true
  end

  if itemSlot == "INVTYPE_WEAPON" then
    local _, classFileName = UnitClass("player")
    if not (classFileName and DUAL_WIELD_CLASSES[classFileName]) then
      for _, r in ipairs(ratings) do
        outScores[r] = VRB_SlotScoresA[r] or 0
      end
      return true
    end

    if not hasB and hasA then
      local mhLink = GetInventoryItemLink and GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
      local mhLoc = nil
      if mhLink then
        if C_Item and C_Item.GetItemInfoInstant then
          local okCall, _, _, _, loc = pcall(C_Item.GetItemInfoInstant, mhLink)
          if okCall then mhLoc = loc end
        else
          local _, _, itemStr = string.find(mhLink, "(item:%d+[^|]*)")
          local okMh, _, _, _, _, _, _, _, loc = pcall(GetItemInfo, itemStr or mhLink)
          if okMh then mhLoc = loc end
        end
      end
      if mhLoc == "INVTYPE_2HWEAPON" then
        for _, r in ipairs(ratings) do
          outScores[r] = VRB_SlotScoresA[r] or 0
        end
        return true
      end
    elseif hasB then
      local ohLink = GetInventoryItemLink and GetInventoryItemLink("player", GetInventorySlotInfo("SecondaryHandSlot"))
      local ohLoc = nil
      if ohLink then
        if C_Item and C_Item.GetItemInfoInstant then
          local okCall, _, _, _, loc = pcall(C_Item.GetItemInfoInstant, ohLink)
          if okCall then ohLoc = loc end
        else
          local _, _, itemStr = string.find(ohLink, "(item:%d+[^|]*)")
          local okOh, _, _, _, _, _, _, _, loc = pcall(GetItemInfo, itemStr or ohLink)
          if okOh then ohLoc = loc end
        end
      end
      if ohLoc == "INVTYPE_SHIELD" or ohLoc == "INVTYPE_HOLDABLE" then
        for _, r in ipairs(ratings) do
          outScores[r] = VRB_SlotScoresA[r] or 0
        end
        return true
      end
    end
  end

  for _, r in ipairs(ratings) do
    local a = VRB_SlotScoresA[r] or 0
    local b = VRB_SlotScoresB[r] or 0
    if a <= b then
      outScores[r] = a
    else
      outScores[r] = b
    end
  end
  return true
end


function VRBOnTooltipItem(tooltip, explicitLink, skipCompare)
    if not BCSItemScan then
      return
    end
    local db = VRB_EnsureDB()
    if not db.enabled then
      return
    end
    if db.shiftOnly and not IsShiftKeyDown() then
      return
    end
    local tt = tooltip or GameTooltip
    local ttName = tt:GetName() or "GameTooltip"
    local itemSlot = nil
    local itemName = nil
    local bonuses = nil
    local tmpText, line;
    local lines = tt:NumLines();
    if not lines or lines < 2 then
      return
    end
    local hasScoreToShow = false
    local vrbscore = 0
    local normalizedLabel = nil

    -- Only equippable gear gets a rating -- without this, any tooltip with
    -- recognizable stat text (food buffs, quest items, consumables) would
    -- also show a score. scoredItemTypes/VRBCheckItemType already existed
    -- for this but were never actually wired up to anything.
    -- GameTooltip:GetItem is one of the functions ClassicAPI backports into
    -- 1.12 (not confirmed native), so this guards for its absence and falls
    -- back to the original unfiltered behavior rather than erroring.
    local itemLink = explicitLink
    if not itemLink and tt.GetItem then
      local okGet
      okGet, itemName, itemLink = pcall(tt.GetItem, tt)
      if not okGet then
        itemLink = nil
      end
    end

    if itemLink then
      -- GetItemInfo returns nil on a cache miss (the item hasn't been seen
      -- by the client yet), which is common for bag items and anything you
      -- haven't recently inspected elsewhere. When that happens we don't
      -- know the item's slot -- fail OPEN (show the score, matching the
      -- original unfiltered behavior) rather than closed, since treating
      -- "unknown" as "definitely not equipment" would hide scores on
      -- ordinary gear far more often than it correctly filters out a
      -- genuine non-equipment item.
      local okInfo, equipLoc
      if C_Item and C_Item.GetItemInfoInstant then
        local okCall, _, _, _, loc = pcall(C_Item.GetItemInfoInstant, itemLink)
        okInfo = okCall and (loc ~= nil)
        equipLoc = loc
      else
        -- Stock 1.12 GetItemInfo expects "item:<id>:..." or itemID, not a full |H...|h link,
        -- and returns equipLoc at position 8 (position 9 is texture).
        local itemQuery = itemLink
        if type(itemLink) == "string" then
          local _, _, itemStr = string.find(itemLink, "(item:%d+[^|]*)")
          if itemStr then
            itemQuery = itemStr
          end
        end
        okInfo, _, _, _, _, _, _, _, equipLoc = pcall(GetItemInfo, itemQuery)
      end

      if okInfo and equipLoc ~= nil then
        if equipLoc == "" or not VRBCheckItemType(equipLoc) then
          return
        end
        itemSlot = equipLoc
      end
    end

    local hoveredSetName = nil
    local lbl = getglobal(ttName .. "TextLeft1")
    if lbl then
      if BCSItemScan and type(BCSItemScan.ScanTooltip) == "function" then
        bonuses, hoveredSetName = BCSItemScan:ScanTooltip(tt, { stopAtCompareHeader = skipCompare })
      else
        BCSItemScan.temp.sets = {};
        BCSItemScan.temp.set = "";
        BCSItemScan.temp.bonuses = {};
        BCSItemScan.temp.details = {};
        BCSItemScan.temp.slot = "";

        for i=2, lines, 1 do
          tmpText = getglobal(ttName .. "TextLeft" .. i);
          if (tmpText and tmpText:GetText()) then
            line = tmpText:GetText();
            if skipCompare and (
              (ITEM_DELTA_DESCRIPTION and line == ITEM_DELTA_DESCRIPTION)
              or (ITEM_DELTA_MULTIPLE_COMPARISON_SEPARATOR and line == ITEM_DELTA_MULTIPLE_COMPARISON_SEPARATOR)
              or string.find(line, "^If you replace")
            ) then
              break
            end
            BCSItemScan:ScanLine(line);
          end
        end

        bonuses = BCSItemScan.temp.bonuses;
        hoveredSetName = (BCSItemScan.temp.set ~= "" and BCSItemScan.temp.set) or nil
      end

      VRB_ApplyEnchantStats(bonuses, itemLink, itemSlot)

      if(bonuses) then

        local ratings = VRBGetValidRatings()
        local className, classFileName = UnitClass("player")
        local labelPrefix = (classFileName and CLASS_TOKEN_TO_LABEL[classFileName]) or className or ""
        local color = (classFileName and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFileName]) or NORMAL_FONT_COLOR
        local anyVisiblePositive = false

        for _, r in ipairs(ratings) do
          if not db.hiddenSpecs[r] then
            vrbscore = VRBCalculateRating(r, bonuses)
            VRB_HoveredScores[r] = vrbscore
            if vrbscore > 0 then
              anyVisiblePositive = true
            end
          else
            VRB_HoveredScores[r] = 0
          end
        end

        if not anyVisiblePositive then
          return
        end

        local hasBaseline = false
        if db.compare and not skipCompare and itemSlot then
          hasBaseline = VRB_GetBaselineScores(itemSlot, ratings, db.ignoreEquippedEnchants, VRB_BaselineScores)
        end

        for _, r in ipairs(ratings) do
          vrbscore = VRB_HoveredScores[r] or 0
          if vrbscore > 0 then
            normalizedLabel = string.gsub(r, "^" .. labelPrefix, "")
            local valueText = tostring(vrbscore)
            if hasBaseline then
              local delta = VRBRound(vrbscore - (VRB_BaselineScores[r] or 0), 2)
              if delta > 0 then
                valueText = valueText .. " |cff00ff00(+" .. delta .. ")|r"
              elseif delta < 0 then
                valueText = valueText .. " |cffff3333(" .. delta .. ")|r"
              end
            end
            tt:AddDoubleLine(normalizedLabel .. ": ", valueText, color.r, color.g, color.b, color.r, color.g, color.b)
            hasScoreToShow = true
          end
        end

        -- Cap-Aware annotation from BetterCharacterStats (if installed & enabled)
        if hasScoreToShow and db.capAware and not skipCompare and BCS and type(BCS.GetStatCapStatus) == "function" then
          local okCap, cap = pcall(BCS.GetStatCapStatus, BCS)
          if okCap and cap then
            local capNotes = {}
            if (tonumber(bonuses["TOHIT"]) or 0) > 0 then
              if RANGED_EQUIP_LOCS[itemSlot] and cap.rangedHitCapped then
                table.insert(capNotes, "Ranged Hit capped (" .. cap.rangedHit .. "/" .. cap.rangedHitCap .. "%)")
              elseif not RANGED_EQUIP_LOCS[itemSlot] and cap.meleeHitCapped then
                table.insert(capNotes, "Melee Hit capped (" .. cap.meleeHit .. "/" .. cap.meleeHitCap .. "%)")
              end
            end
            if (tonumber(bonuses["SPELLTOHIT"]) or 0) > 0 and cap.spellHitCapped then
              table.insert(capNotes, "Spell Hit capped (" .. cap.spellHit .. "/" .. cap.spellHitCap .. "%)")
            end
            if (tonumber(bonuses["DEFENSE"]) or 0) > 0 and cap.defenseCapped then
              table.insert(capNotes, "Defense capped (" .. cap.defense .. "/" .. cap.defenseCap .. ")")
            end
            if table.getn(capNotes) > 0 then
              tt:AddLine("|cffffaa00VRB Cap:|r " .. table.concat(capNotes, ", "), 1, 0.82, 0)
            end
          end
        end

        -- Set-Break Warning when replacing an equipped piece of an active set
        if hasScoreToShow and db.setBreakWarning and hasBaseline and itemSlot and BCSItemScan and type(BCSItemScan.GetEquippedSlotStats) == "function" then
          local slots = EQUIP_LOC_TO_SLOTS[itemSlot]
          if slots then
            local brokenSet = nil
            for i = 1, table.getn(slots) do
              local _, _, eqSetName, eqSetCount = BCSItemScan:GetEquippedSlotStats(slots[i], false)
              if eqSetName and eqSetCount and eqSetCount >= 2 and eqSetName ~= hoveredSetName then
                brokenSet = eqSetName
                break
              end
            end
            if brokenSet then
              tt:AddLine("|cffffaa00VRB Set:|r Replacing breaks " .. brokenSet, 1, 0.75, 0.2)
            end
          end
        end

        if hasScoreToShow then
          tt:Show()
        end

      end

    end

end


local function VRB_HookTooltipMethod(tooltip, methodName, linkResolver, skipCompareFn, requireFirstReturn)
    if not tooltip or not tooltip[methodName] then
      return
    end
    local prev = tooltip[methodName]
    tooltip[methodName] = function(self, a1, a2, a3, a4)
      local r1, r2, r3 = prev(self, a1, a2, a3, a4)
      if requireFirstReturn and not r1 then
        return r1, r2, r3
      end
      local link = nil
      if linkResolver then
        link = linkResolver(a1, a2, a3, a4)
      end
      local skipCompare = false
      if skipCompareFn then
        skipCompare = skipCompareFn(a1, a2, a3, a4)
      end
      VRBOnTooltipItem(self, link, skipCompare)
      return r1, r2, r3
    end
end

local function VRB_HookHyperlink(tooltip, forceSkipCompare)
    if not tooltip or not tooltip.SetHyperlink then
      return
    end
    local prev = tooltip.SetHyperlink
    tooltip.SetHyperlink = function(self, link, a, b, c)
      local r1, r2, r3 = prev(self, link, a, b, c)
      if type(link) == "string" and string.find(link, "item:%d+") then
        VRBOnTooltipItem(self, link, forceSkipCompare)
      end
      return r1, r2, r3
    end
end

local function VRB_ResolveInventoryLink(unit, slot)
    if GetInventoryItemLink and unit and slot then
      return GetInventoryItemLink(unit, slot)
    end
    return nil
end

local function VRB_IsPlayerEquippedSlot(unit, slot)
    return unit == "player" and type(slot) == "number" and slot >= 1 and slot <= 19
end

local function VRB_ResolveBagLink(bag, slot)
    if GetContainerItemLink and bag and slot then
      return GetContainerItemLink(bag, slot)
    end
    return nil
end

local VRB_GAME_TOOLTIP_HOOKS = {
    { "SetInventoryItem", VRB_ResolveInventoryLink, VRB_IsPlayerEquippedSlot, true },
    { "SetBagItem", VRB_ResolveBagLink, nil, true },
    { "SetMerchantItem", function(index) return GetMerchantItemLink and GetMerchantItemLink(index) end },
    { "SetBuybackItem", function(index) return GetBuybackItemLink and GetBuybackItemLink(index) end },
    { "SetAuctionItem", function(itemType, index) return GetAuctionItemLink and GetAuctionItemLink(itemType, index) end },
    { "SetAuctionSellItem", nil },
    { "SetLootItem", function(slot) return GetLootSlotLink and GetLootSlotLink(slot) end },
    { "SetLootRollItem", function(id) return GetLootRollItemLink and GetLootRollItemLink(id) end },
    { "SetQuestItem", function(qType, index) return GetQuestItemLink and GetQuestItemLink(qType, index) end },
    { "SetQuestLogItem", function(qType, index) return GetQuestLogItemLink and GetQuestLogItemLink(qType, index) end },
    { "SetTradeSkillItem", function(skill, id)
        if id and GetTradeSkillReagentItemLink then
          return GetTradeSkillReagentItemLink(skill, id)
        elseif GetTradeSkillItemLink then
          return GetTradeSkillItemLink(skill)
        end
        return nil
    end },
    { "SetCraftItem", function(skill, id)
        if id and GetCraftReagentItemLink then
          return GetCraftReagentItemLink(skill, id)
        elseif GetCraftItemLink then
          return GetCraftItemLink(skill)
        end
        return nil
    end },
    { "SetInboxItem", function(index, attachIndex)
        if GetInboxItemLink then
          local ok, link = pcall(GetInboxItemLink, index, attachIndex)
          if ok then return link end
        end
        return nil
    end },
    { "SetSendMailItem", nil },
}

for _, entry in ipairs(VRB_GAME_TOOLTIP_HOOKS) do
    VRB_HookTooltipMethod(GameTooltip, entry[1], entry[2], entry[3], entry[4])
end

VRB_HookHyperlink(GameTooltip, false)
VRB_HookHyperlink(ItemRefTooltip, false)

for _, compareName in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
    local compareTooltip = getglobal(compareName)
    if compareTooltip then
      VRB_HookHyperlink(compareTooltip, true)
      VRB_HookTooltipMethod(compareTooltip, "SetInventoryItem", VRB_ResolveInventoryLink, function() return true end, true)
      VRB_HookTooltipMethod(compareTooltip, "SetBagItem", VRB_ResolveBagLink, function() return true end, true)
      VRB_HookTooltipMethod(compareTooltip, "SetHyperlinkCompareItem", nil, function() return true end, true)
    end
end

local function VRB_Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[VRB]|r " .. msg)
end

local function VRB_FlagText(val)
  if val then
    return "|cff00ff00ON|r"
  end
  return "|cffff3333OFF|r"
end

local function VRB_PrintSpecs(db)
  local ratings = VRBGetValidRatings()
  VRB_Print("Class specs (toggle with /vrb spec <number|name>):")
  for i, r in ipairs(ratings) do
    local state = VRB_FlagText(not db.hiddenSpecs[r])
    DEFAULT_CHAT_FRAME:AddMessage("  " .. i .. ". " .. r .. " [" .. state .. "]")
  end
end

local function VRB_ResolveSpecName(query)
  if not query or query == "" then
    return nil
  end
  local ratings = VRBGetValidRatings()
  local idx = tonumber(query)
  if idx and ratings[idx] then
    return ratings[idx]
  end
  local q = string.lower(query)
  for _, r in ipairs(ratings) do
    if string.lower(r) == q then
      return r
    end
  end
  for _, r in ipairs(ratings) do
    if string.find(string.lower(r), q, 1, true) then
      return r
    end
  end
  return nil
end

local function VRB_SetCustomWeight(specName, statKey, numValue)
  local db = VRB_EnsureDB()
  if not specName or not statKey then
    return false
  end
  statKey = string.upper(statKey)
  if numValue == nil then
    if db.customWeights[specName] then
      db.customWeights[specName][statKey] = nil
      if next(db.customWeights[specName]) == nil then
        db.customWeights[specName] = nil
      end
    end
    VRB_InvalidateEquippedCache()
    return true
  end
  db.customWeights[specName] = db.customWeights[specName] or {}
  db.customWeights[specName][statKey] = numValue
  VRB_InvalidateEquippedCache()
  return true
end

local function VRB_ResetCustomWeights(specName)
  local db = VRB_EnsureDB()
  if specName then
    db.customWeights[specName] = nil
  else
    db.customWeights = {}
  end
  VRB_InvalidateEquippedCache()
end

local function VRB_PrintCustomWeights()
  local db = VRB_EnsureDB()
  local any = false
  VRB_Print("Custom stat weight overrides:")
  for specName, stats in pairs(db.customWeights) do
    for statKey, val in pairs(stats) do
      any = true
      DEFAULT_CHAT_FRAME:AddMessage("  " .. specName .. " [" .. statKey .. "] = " .. tostring(val))
    end
  end
  if not any then
    DEFAULT_CHAT_FRAME:AddMessage("  (none)")
  end
end

VRB.EnsureDB = VRB_EnsureDB
VRB.Print = VRB_Print
VRB.ResolveSpecName = VRB_ResolveSpecName
VRB.SetCustomWeight = VRB_SetCustomWeight
VRB.ResetCustomWeights = VRB_ResetCustomWeights

SLASH_VRB1 = "/vrb"
SlashCmdList["VRB"] = function(msg)
  local db = VRB_EnsureDB()
  local raw = msg or ""
  local _, _, cmd, rest = string.find(raw, "^%s*(%S+)%s*(.-)%s*$")
  cmd = cmd and string.lower(cmd) or ""

  if cmd == "" then
    if VRB.ToggleUI then
      VRB.ToggleUI()
      return
    end
    cmd = "help"
  end

  if cmd == "ui" or cmd == "config" or cmd == "options" then
    if VRB.ToggleUI then
      VRB.ToggleUI()
    else
      VRB_Print("Options UI is not loaded.")
    end
    return
  end

  if cmd == "help" then
    VRB_Print("Enabled: " .. VRB_FlagText(db.enabled)
      .. " | Compare: " .. VRB_FlagText(db.compare)
      .. " | Shift-only: " .. VRB_FlagText(db.shiftOnly)
      .. " | Ignore enchants: " .. VRB_FlagText(db.ignoreEquippedEnchants)
      .. " | Cap-Aware: " .. VRB_FlagText(db.capAware)
      .. " | Set-Warn: " .. VRB_FlagText(db.setBreakWarning))
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb              - Open/close options window")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb toggle       - Toggle addon on/off")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb compare      - Toggle (+/-) delta vs equipped item")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb shift        - Toggle Shift-key-only tooltip display")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb enchant      - Toggle ignoring enchants on equipped baseline")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb cap          - Toggle BCS Cap-Aware tooltip warnings")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb setwarn      - Toggle Set-Break warning on tooltip comparison")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb spec [n|name] - List or toggle visible class specs")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb weight <spec> <stat> <val|reset> - Override a stat weight")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb export <spec> - Print shareable weight string for a spec")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb import <str>  - Import weight string (VRB1:<spec>:STAT=VAL,...)")
    DEFAULT_CHAT_FRAME:AddMessage("  /vrb reset        - Reset all settings, specs, and weights")
    return
  end

  if cmd == "toggle" then
    db.enabled = not db.enabled
    VRB_Print("Addon: " .. VRB_FlagText(db.enabled))
  elseif cmd == "compare" then
    db.compare = not db.compare
    VRB_Print("Equipped comparison: " .. VRB_FlagText(db.compare))
  elseif cmd == "shift" then
    db.shiftOnly = not db.shiftOnly
    VRB_Print("Shift-only display: " .. VRB_FlagText(db.shiftOnly))
  elseif cmd == "enchant" or cmd == "enchants" then
    db.ignoreEquippedEnchants = not db.ignoreEquippedEnchants
    VRB_InvalidateEquippedCache()
    VRB_Print("Ignore equipped enchants in comparison: " .. VRB_FlagText(db.ignoreEquippedEnchants))
  elseif cmd == "cap" or cmd == "capaware" then
    db.capAware = not db.capAware
    VRB_Print("BCS Cap-Aware warnings: " .. VRB_FlagText(db.capAware))
  elseif cmd == "setwarn" or cmd == "setbreak" then
    db.setBreakWarning = not db.setBreakWarning
    VRB_Print("Set-Break warnings: " .. VRB_FlagText(db.setBreakWarning))
  elseif cmd == "export" then
    local specName = VRB_ResolveSpecName(rest)
    if not specName then
      VRB_Print("Usage: /vrb export <spec>")
      VRB_PrintSpecs(db)
      return
    end
    local baseWeights = VRB_WEIGHTS and VRB_WEIGHTS[specName] or {}
    local custom = db.customWeights[specName] or {}
    local merged = {}
    for k, v in pairs(baseWeights) do
      if type(v) == "number" then
        merged[k] = v
      end
    end
    for k, v in pairs(custom) do
      merged[k] = v
    end
    local parts = {}
    for k, v in pairs(merged) do
      table.insert(parts, k .. "=" .. tostring(v))
    end
    table.sort(parts)
    VRB_Print("VRB1:" .. specName .. ":" .. table.concat(parts, ","))
  elseif cmd == "import" then
    local _, _, specPart, body = string.find(rest or "", "^VRB1:([^:]+):(.+)$")
    if not specPart or not body then
      VRB_Print("Invalid format. Expected: VRB1:<SpecName>:STAT=VAL,STAT2=VAL2")
      return
    end
    local specName = VRB_ResolveSpecName(specPart)
    if not specName then
      VRB_Print("Spec not found for current class: " .. specPart)
      return
    end
    local count = 0
    for pair in string.gfind(body, "[^,]+") do
      local _, _, k, v = string.find(pair, "^%s*([%a%d_]+)%s*=%s*([%-%.%d]+)%s*$")
      local num = v and tonumber(v)
      if k and num then
        VRB_SetCustomWeight(specName, k, num)
        count = count + 1
      end
    end
    VRB_Print("Imported " .. count .. " weights into " .. specName)
  elseif cmd == "spec" or cmd == "specs" then
    if not rest or rest == "" then
      VRB_PrintSpecs(db)
      return
    end
    local matched = VRB_ResolveSpecName(rest)
    if matched then
      if db.hiddenSpecs[matched] then
        db.hiddenSpecs[matched] = nil
      else
        db.hiddenSpecs[matched] = true
      end
      VRB_Print(matched .. ": " .. VRB_FlagText(not db.hiddenSpecs[matched]))
    else
      VRB_Print("Spec not found: " .. rest)
      VRB_PrintSpecs(db)
    end
  elseif cmd == "weight" or cmd == "weights" then
    if not rest or rest == "" then
      VRB_PrintCustomWeights()
      return
    end
    local _, _, specArg, statArg, valArg = string.find(rest, "^(%S+)%s+(%S+)%s*(.-)%s*$")
    if not specArg then
      VRB_Print("Usage: /vrb weight <spec> <stat> <value|reset>  OR  /vrb weight <spec> reset")
      return
    end
    local specName = VRB_ResolveSpecName(specArg)
    if not specName then
      VRB_Print("Spec not found: " .. specArg)
      VRB_PrintSpecs(db)
      return
    end
    if string.lower(statArg) == "reset" and (not valArg or valArg == "") then
      VRB_ResetCustomWeights(specName)
      VRB_Print("Cleared custom weights for " .. specName)
    elseif valArg and string.lower(valArg) == "reset" then
      VRB_SetCustomWeight(specName, statArg, nil)
      VRB_Print("Reset " .. specName .. " [" .. string.upper(statArg) .. "] to default")
    else
      local num = tonumber(valArg)
      if not num then
        VRB_Print("Invalid weight value: " .. tostring(valArg))
        return
      end
      VRB_SetCustomWeight(specName, statArg, num)
      VRB_Print("Set " .. specName .. " [" .. string.upper(statArg) .. "] = " .. num)
    end
  elseif cmd == "reset" then
    VanillaRatingBusterDB = nil
    db = VRB_EnsureDB()
    VRB_InvalidateEquippedCache()
    VRB_Print("Settings reset to defaults.")
  else
    VRB_Print("Unknown command: " .. cmd .. " (type /vrb help)")
  end

  if VRB.RefreshUI then
    VRB.RefreshUI()
  end
end

VRB.InvalidateEquippedCache = VRB_InvalidateEquippedCache

-- Public API for BetterCharacterPanel (and other addons): returns total equipped VRB scores
-- for all visible specs matching `unit`'s class. Works for both "player" and cross-faction inspect units.
local VRB_EQUIPMENT_SLOTS = {
  "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
  "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
  "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
  "MainHandSlot", "SecondaryHandSlot", "RangedSlot",
}

function VRB:GetUnitSpecScores(unit)
  if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
    return nil
  end
  if not BCSItemScan then
    return nil
  end

  local className, classFileName = UnitClass(unit)
  local labelKey = (classFileName and CLASS_TOKEN_TO_LABEL[classFileName]) or className
  local ratings = labelKey and VRB_LABELS and VRB_LABELS[labelKey]
  if not ratings or table.getn(ratings) == 0 then
    return nil
  end

  local db = VRB_EnsureDB()
  local isPlayer = (unit == "player")
  local totals = {}
  local activeRatings = {}
  for i = 1, table.getn(ratings) do
    local r = ratings[i]
    if not isPlayer or not db.hiddenSpecs[r] then
      table.insert(activeRatings, r)
      totals[r] = 0
    end
  end
  if table.getn(activeRatings) == 0 then
    return nil
  end

  local anyItem = false
  if isPlayer then
    local slotBuf = {}
    for i = 1, table.getn(VRB_EQUIPMENT_SLOTS) do
      local hasSlot = VRB_ScanEquippedSlotScores(VRB_EQUIPMENT_SLOTS[i], activeRatings, false, slotBuf)
      if hasSlot then
        anyItem = true
        for j = 1, table.getn(activeRatings) do
          local r = activeRatings[j]
          totals[r] = totals[r] + (slotBuf[r] or 0)
        end
      end
    end
  else
    for i = 1, table.getn(VRB_EQUIPMENT_SLOTS) do
      local slotName = VRB_EQUIPMENT_SLOTS[i]
      local slotId = GetInventorySlotInfo(slotName)
      if slotId then
        VRBCompareTooltip:ClearLines()
        local okHas, hasItem = pcall(VRBCompareTooltip.SetInventoryItem, VRBCompareTooltip, unit, slotId)
        if okHas and hasItem and VRBCompareTooltip:NumLines() >= 2 then
          anyItem = true
          local eqBonuses
          if type(BCSItemScan.ScanTooltip) == "function" then
            eqBonuses = BCSItemScan:ScanTooltip(VRBCompareTooltip, nil)
          end
          if eqBonuses then
            local eqLink = GetInventoryItemLink and GetInventoryItemLink(unit, slotId) or nil
            if eqLink then
              local eqLoc = (slotName == "RangedSlot") and "INVTYPE_RANGED" or nil
              VRB_ApplyEnchantStats(eqBonuses, eqLink, eqLoc)
            end
            for j = 1, table.getn(activeRatings) do
              local r = activeRatings[j]
              totals[r] = totals[r] + VRBCalculateRating(r, eqBonuses)
            end
          end
        end
      end
    end
  end

  if not anyItem then
    return nil
  end

  local out = {}
  for i = 1, table.getn(activeRatings) do
    local r = activeRatings[i]
    local shortName = string.gsub(r, "^" .. labelKey, "")
    table.insert(out, { spec = shortName, fullSpec = r, score = VRBRound(totals[r], 1) })
  end
  return out
end

local VRB_InitFrame = CreateFrame("Frame")
VRB_InitFrame:RegisterEvent("ADDON_LOADED")
VRB_InitFrame:RegisterEvent("PLAYER_LOGIN")
VRB_InitFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
VRB_InitFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "VanillaRatingBuster" then
    VRB_EnsureDB()
    if VRB.RefreshUI then
      VRB.RefreshUI()
    end
    VRB_InitFrame:UnregisterEvent("ADDON_LOADED")
  elseif event == "PLAYER_LOGIN" then
    if type(GetNampowerVersion) == "function" then
      VRB_InitFrame:UnregisterEvent("UNIT_INVENTORY_CHANGED")
      VRB_InitFrame:RegisterEvent("UNIT_INVENTORY_CHANGED_GUID")
    end
    if BCS and type(BCS.RegisterCallback) == "function" then
      BCS:RegisterCallback("GEAR_UPDATED", VRB_InvalidateEquippedCache)
      BCS:RegisterCallback("ITEMSCAN_UPDATED", VRB_InvalidateEquippedCache)
    end
  elseif event == "UNIT_INVENTORY_CHANGED_GUID" then
    if arg2 then
      VRB_InvalidateEquippedCache()
    end
  elseif event == "UNIT_INVENTORY_CHANGED" then
    if arg1 == "player" or (UnitIsUnit and arg1 and UnitIsUnit(arg1, "player")) then
      VRB_InvalidateEquippedCache()
    end
  end
end)