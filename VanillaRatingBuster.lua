
-- GetItemInfo's equipLoc return is the raw, language-independent enum
-- string (e.g. "INVTYPE_HEAD"), not a localized label -- the unquoted
-- globals previously here (plus the deDE/enGB string fallbacks someone
-- added to compensate) evaluated to _G["INVTYPE_HEAD"], a LOCALIZED label
-- ("Head"), which would never match the raw enum VRBCheckItemType is
-- actually compared against. That made the filter below silently reject
-- every item. Fixed by matching the raw enum directly; also adds
-- INVTYPE_RANGEDRIGHT, which on 1.12 (pre-2.4.3) is what Wands, Guns and
-- Crossbows actually report -- INVTYPE_RANGED alone only covers Bows.
scoredItemTypes = {
  "INVTYPE_2HWEAPON", "INVTYPE_CHEST", "INVTYPE_CLOAK",
  "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_HAND", "INVTYPE_HEAD", "INVTYPE_HOLDABLE",
  "INVTYPE_LEGS", "INVTYPE_NECK", "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_RELIC", "INVTYPE_ROBE", "INVTYPE_SHIELD",
  "INVTYPE_SHOULDER", "INVTYPE_TRINKET", "INVTYPE_WAIST", "INVTYPE_WEAPON",
  "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_WRIST",
}


function istable(t)
  return type(t) == 'table'
end


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
  local ratings
  local class = UnitClass("player")

  ratings = VRB_LABELS[class]
  if ratings then
    return ratings
  end
  return {}

end


function VRBCalculateRating(weightTable, bonuses)

  local baseScore = 0
  local weightTypes = VRB_WEIGHTS[weightTable]

  for t,w in pairs(weightTypes) do
    
    -- Reset currentBonus at the start of every stat iteration to prevent state leaks
    local currentBonus = 0

    if (BCSItemScan.bonuses and BCSItemScan.bonuses[t]) then
      currentBonus = BCSItemScan.bonuses[t]
    end

    if(bonuses[t]) then
      -- Now check if the weight is a compound structure; has a threshold
      if type(w) == "table" then  -- Changed from istable(w) to standard Lua for safety
        local threshold = w[1]
        local beforeWeight = w[2]
        local afterWeight = w[3]
        
        if tonumber(currentBonus) < tonumber(threshold) then
          baseScore = baseScore + ( bonuses[t] * beforeWeight )
        else
          baseScore = baseScore + ( bonuses[t] * afterWeight )
        end
      else
        baseScore = baseScore + ( bonuses[t] * w )
      end
    end

  end

  return VRBRound(baseScore, 2)

end


VRBItemScoreTooltip = CreateFrame( "Frame" , "VRBItemScoreTooltip", GameTooltip )
VRBItemScoreTooltip:SetScript("OnShow", function (self)
    local itemLevel = nil
    local itemRarity = nil
    local itemSlot = nil
    local itemName = nil
    local itemID = nil
    local bonuses = nil
    local tmpTxt, line;
    local lines = GameTooltip:NumLines();
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
    local itemLink
    if GameTooltip.GetItem then
      local okGet
      okGet, itemName, itemLink = pcall(GameTooltip.GetItem, GameTooltip)
      if not okGet then
        itemLink = nil
      end
    end

    if itemLink then
      local okInfo, _, _, _, _, _, _, _, _, equipLoc = pcall(GetItemInfo, itemLink)
      itemSlot = okInfo and equipLoc or nil

      if not (itemSlot and VRBCheckItemType(itemSlot)) then
        return
      end
    end

    BCSItemScan.temp.sets = {};
    BCSItemScan.temp.set = "";
    BCSItemScan.temp.bonuses = {};
    BCSItemScan.temp.details = {};
    BCSItemScan.temp.slot = "";

    local lbl = getglobal("GameTooltipTextLeft1")
    if lbl then

      for i=2, lines, 1 do
        tmpText = getglobal("GameTooltipTextLeft"..i);
        val = nil;
        if (tmpText:GetText()) then
          line = tmpText:GetText();
          BCSItemScan:ScanLine(line);
        end
      end

      bonuses = BCSItemScan.temp.bonuses;

      if(bonuses) then

        local ratings = VRBGetValidRatings()
        local className, classFileName = UnitClass("player")
        local color = RAID_CLASS_COLORS[classFileName]

        for _, r in ipairs(ratings) do
          vrbscore = VRBCalculateRating(r, bonuses)
          if vrbscore > 0 then
            normalizedLabel = string.gsub(r, className, "")
            -- GameTooltip:AddLine(normalizedLabel .. ": " .. vrbscore, color.r, color.g, color.b)
            GameTooltip:AddDoubleLine(normalizedLabel .. ": ", vrbscore , color.r, color.g, color.b, color.r, color.g, color.b)
            hasScoreToShow = true
          end
        end

        if hasScoreToShow then
          GameTooltip:Show()
        end

      end

    end

  end)


SLASH_VRBSCORE1, SLASH_VRBSCORE2 = '/vrb';