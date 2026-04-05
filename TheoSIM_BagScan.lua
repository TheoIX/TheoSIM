TWS = TWS or {}

local SLOT_LABELS = {
    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulder",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [11] = "Ring",
    [12] = "Ring",
    [13] = "Trinket",
    [14] = "Trinket",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [18] = "Ranged",
}

local BAG_SCAN_TOOLTIP_NAME = "TheoSIMBagScanTooltip"
local BAG_SCAN_MODE_NOTE = "Bag Scan uses only Strength->AP, Agility->crit, and crit/hit/haste %. Melee weapon style is locked to your current setup, and ranged items compare only against slot 18."
local BAG_SCAN_ITEM_CACHE = {}

local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    local k, v
    for k, v in pairs(value) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function GetBagScanTooltip()
    local tip = _G[BAG_SCAN_TOOLTIP_NAME]
    if tip then return tip end
    tip = CreateFrame("GameTooltip", BAG_SCAN_TOOLTIP_NAME, UIParent, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    return tip
end

local function GetTooltipLineText(tip, side, index)
    local fs = _G[tip:GetName() .. "Text" .. side .. index]
    if fs then return fs:GetText() end
    return nil
end

local function GetImprovedSlamReductionFromRanks(ranks)
    local imp = math.min(ranks or 0, 5)
    return imp * 0.25
end


local function BagScanIsEquippable(itemData)
    if not itemData then return nil end
    if itemData.equipLoc and itemData.equipLoc ~= "" then return 1 end
    if IsEquippableItem then
        local probe = itemData.itemLink or itemData.name or itemData.link
        if probe and IsEquippableItem(probe) then
            return 1
        end
    end
    return nil
end

local function NormalizeText(text)
    if not text then return "" end
    text = string.lower(text)
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    local _, _, stripped = string.find(text, "^equip:%s*(.+)$")
    if stripped then text = stripped end
    local _, _, stripped2 = string.find(text, "^use:%s*(.+)$")
    if stripped2 then text = stripped2 end
    text = string.gsub(text, "%.$", "")
    return text
end

local function SMatch(text, pattern)
    return string.find(text or "", pattern)
end

local function AddNumberField(tbl, key, amount)
    if not amount or amount == 0 then return end
    tbl[key] = (tbl[key] or 0) + amount
end


local function GetRecognizedStatBudget(data)
    if not data or not data.stats then return 0 end
    local s = data.stats
    local total = 0
    total = total + math.abs((s.strength or 0) * 2)   -- translated to AP
    total = total + math.abs((s.agility or 0) * 1)    -- translated by snapshot logic into crit
    total = total + math.abs((s.crit or 0) * 20)
    total = total + math.abs((s.hit or 0) * 20)
    total = total + math.abs((s.haste or 0) * 20)
    return total
end

local function HasUnmodeledTooltipEffect(tip)
    data.hasUnmodeledEffect = HasUnmodeledTooltipEffect(tip)

    local i
    for i = 2, 30 do
        local left = NormalizeText(GetTooltipLineText(tip, "Left", i))
        local right = NormalizeText(GetTooltipLineText(tip, "Right", i))
        local function bad(s)
            if not s or s == "" then return nil end
            if string.find(s, "chance on hit") then return 1 end
            if string.find(s, "your attacks have a chance") then return 1 end
            if string.find(s, "when struck") then return 1 end
            if string.find(s, "increases defense skill") then return 1 end
            if string.find(s, "improves defense skill") then return 1 end
            if string.find(s, "chance to dodge") then return 1 end
            if string.find(s, "chance to parry") then return 1 end
            if string.find(s, "chance to block") then return 1 end
            if string.find(s, "spell damage") then return 1 end
            if string.find(s, "healing spells") then return 1 end
            if string.find(s, "mana every 5 sec") then return 1 end
            if string.find(s, "restores") and string.find(s, "mana") then return 1 end
            return nil
        end
        if bad(left) or bad(right) then return 1 end
    end
    return nil
end

local function ParseStatLine(stats, text)
    local s = NormalizeText(text)
    local n, cap

    _, _, cap = SMatch(s, "^%+?(%d+)%s+strength$")
    n = tonumber(cap)
    if n then AddNumberField(stats, "strength", n) return end
    _, _, cap = SMatch(s, "^%+?(%d+)%s+str$")
    n = tonumber(cap)
    if n then AddNumberField(stats, "strength", n) return end
    _, _, cap = SMatch(s, "strength by (%d+)")
    n = tonumber(cap)
    if n then AddNumberField(stats, "strength", n) return end

    _, _, cap = SMatch(s, "^%+?(%d+)%s+agility$")
    n = tonumber(cap)
    if n then AddNumberField(stats, "agility", n) return end
    _, _, cap = SMatch(s, "^%+?(%d+)%s+agi$")
    n = tonumber(cap)
    if n then AddNumberField(stats, "agility", n) return end
    _, _, cap = SMatch(s, "agility by (%d+)")
    n = tonumber(cap)
    if n then AddNumberField(stats, "agility", n) return end

    _, _, cap = SMatch(s, "^%+?(%d+)%%?%s+critical strike$")
    n = tonumber(cap)
    if n then AddNumberField(stats, "crit", n) return end
    _, _, cap = SMatch(s, "^%+?(%d+)%%?%s+crit$")
    n = tonumber(cap)
    if n then AddNumberField(stats, "crit", n) return end
    _, _, cap = SMatch(s, "critical strike by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "crit", n) return end
    _, _, cap = SMatch(s, "chance to get a critical strike by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "crit", n) return end
    _, _, cap = SMatch(s, "chance to get a critical strike with melee weapons by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "crit", n) return end
    _, _, cap = SMatch(s, "improves your chance to get a critical strike by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "crit", n) return end
    _, _, cap = SMatch(s, "crit by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "crit", n) return end

    _, _, cap = SMatch(s, "^%+?(%d+)%%?%s+hit$")
    n = tonumber(cap)
    if n then AddNumberField(stats, "hit", n) return end
    _, _, cap = SMatch(s, "chance to hit by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "hit", n) return end
    _, _, cap = SMatch(s, "improves your chance to hit by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "hit", n) return end
    _, _, cap = SMatch(s, "hit by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "hit", n) return end

    _, _, cap = SMatch(s, "^%+?(%d+)%%?%s+haste$")
    n = tonumber(cap)
    if n then AddNumberField(stats, "haste", n) return end
    _, _, cap = SMatch(s, "haste by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "haste", n) return end
    _, _, cap = SMatch(s, "improves your haste by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "haste", n) return end
    _, _, cap = SMatch(s, "attack speed by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "haste", n) return end
    _, _, cap = SMatch(s, "increases your attack speed by (%d+)%%")
    n = tonumber(cap)
    if n then AddNumberField(stats, "haste", n) return end
end

local function ParseWeaponLine(data, text)
    local s = NormalizeText(text)
    local _, _, minDmg, maxDmg = SMatch(s, "^(%d+)%s*%-%s*(%d+)%s+damage$")
    if minDmg and maxDmg then
        data.weaponMin = tonumber(minDmg) or 0
        data.weaponMax = tonumber(maxDmg) or 0
        return
    end

    local _, _, speed = SMatch(s, "^speed%s+([%d%.]+)$")
    if speed then
        data.weaponSpeed = tonumber(speed) or 0
        return
    end
end


local function GetTooltipEquipLoc(tip)
    local function MapTextToEquipLoc(line)
        local s = NormalizeText(line)
        if s == "" then return nil end

        if string.find(s, "held in off%-hand") or string.find(s, "held in off hand") then return "INVTYPE_HOLDABLE" end
        if string.find(s, "main hand") then return "INVTYPE_WEAPONMAINHAND" end
        if string.find(s, "off hand") then return "INVTYPE_WEAPONOFFHAND" end
        if string.find(s, "two%-hand") or string.find(s, "two hand") then return "INVTYPE_2HWEAPON" end
        if string.find(s, "one%-hand") or string.find(s, "one hand") then return "INVTYPE_WEAPON" end
        if s == "shield" then return "INVTYPE_SHIELD" end
        if s == "ranged" or string.find(s, "ranged") then return "INVTYPE_RANGEDRIGHT" end
        if s == "thrown" or string.find(s, "thrown") then return "INVTYPE_THROWN" end
        if string.find(s, "gun") or string.find(s, "bow") or string.find(s, "crossbow") then return "INVTYPE_RANGEDRIGHT" end

        if s == "head" then return "INVTYPE_HEAD" end
        if s == "neck" then return "INVTYPE_NECK" end
        if s == "shoulder" then return "INVTYPE_SHOULDER" end
        if s == "back" then return "INVTYPE_CLOAK" end
        if s == "chest" then return "INVTYPE_CHEST" end
        if s == "robe" then return "INVTYPE_ROBE" end
        if s == "wrist" then return "INVTYPE_WRIST" end
        if s == "hands" then return "INVTYPE_HAND" end
        if s == "waist" then return "INVTYPE_WAIST" end
        if s == "legs" then return "INVTYPE_LEGS" end
        if s == "feet" then return "INVTYPE_FEET" end
        if s == "finger" then return "INVTYPE_FINGER" end
        if s == "trinket" then return "INVTYPE_TRINKET" end

        return nil
    end

    local i
    for i = 1, 30 do
        local left = GetTooltipLineText(tip, "Left", i)
        local right = GetTooltipLineText(tip, "Right", i)
        local loc = MapTextToEquipLoc(left)
        if loc then return loc end
        loc = MapTextToEquipLoc(right)
        if loc then return loc end
    end
    return nil
end

local function ExtractItemHyperlink(link)
    if type(link) ~= "string" then return nil end

    local _, _, itemString = string.find(link, "|H(item:[^|]+)|h")
    if itemString then return itemString end

    local itemPos = string.find(link, "item:")
    if itemPos == 1 then return link end

    return nil
end

local function FinalizeItemData(cacheKey, rawLink, itemLink, tip)
    local name, _, quality, _, _, itemType, subType, _, equipLoc = GetItemInfo(rawLink)
    if not name then
        name, _, quality, _, _, itemType, subType, _, equipLoc = GetItemInfo(itemLink)
    end
    if not equipLoc or equipLoc == "" then
        equipLoc = GetTooltipEquipLoc(tip)
    end

    local data = {
        link = rawLink,
        itemLink = itemLink,
        name = name or GetTooltipLineText(tip, "Left", 1) or rawLink,
        quality = quality or 1,
        itemType = itemType,
        subType = subType,
        equipLoc = equipLoc,
        stats = {
            strength = 0,
            agility = 0,
            attackPower = 0,
            crit = 0,
            hit = 0,
            haste = 0,
            armorPen = 0,
            armor = 0,
            bonusWeaponDamage = 0,
        },
        weaponMin = 0,
        weaponMax = 0,
        weaponSpeed = 0,
    }

    local i
    for i = 2, 30 do
        local left = GetTooltipLineText(tip, "Left", i)
        local right = GetTooltipLineText(tip, "Right", i)

        local lnorm = NormalizeText(left)
        local rnorm = NormalizeText(right)

        -- Once we hit the item set listing / set bonus area, stop.
        if string.find(lnorm or "", "%(%d+/%d+%)") or string.find(rnorm or "", "%(%d+/%d+%)") then
            break
        end
        if string.find(lnorm or "", "^set%s*:") or string.find(rnorm or "", "^set%s*:") then
            break
        end

        if left then
            ParseStatLine(data.stats, left)
            ParseWeaponLine(data, left)
        end
        if right then
            ParseStatLine(data.stats, right)
            ParseWeaponLine(data, right)
        end
    end

    -- Do not force unknown weapons into generic weapon mode here.
    -- On this client that can misclassify two-handers as offhand candidates.

    BAG_SCAN_ITEM_CACHE[cacheKey] = data
    return data
end

local function BuildItemDataFromLink(link)
    if not link then return nil end
    if BAG_SCAN_ITEM_CACHE[link] then return BAG_SCAN_ITEM_CACHE[link] end

    local itemLink = ExtractItemHyperlink(link)
    if not itemLink then return nil end

    local tip = GetBagScanTooltip()
    tip:ClearLines()
    local ok = pcall(function() tip:SetHyperlink(itemLink) end)
    if not ok then return nil end
    tip:Show()

    return FinalizeItemData(link, link, itemLink, tip)
end

local function BuildItemDataFromBagSlot(bag, slot)
    local rawLink = GetContainerItemLink(bag, slot)
    if not rawLink then return nil end
    local cacheKey = "bag:" .. tostring(bag) .. ":" .. tostring(slot) .. ":" .. rawLink
    if BAG_SCAN_ITEM_CACHE[cacheKey] then return BAG_SCAN_ITEM_CACHE[cacheKey] end

    local itemLink = ExtractItemHyperlink(rawLink)
    if not itemLink then return nil end

    local tip = GetBagScanTooltip()
    tip:ClearLines()
    local ok = pcall(function() tip:SetBagItem(bag, slot) end)
    if not ok then
        tip:ClearLines()
        ok = pcall(function() tip:SetHyperlink(itemLink) end)
        if not ok then return nil end
    end
    tip:Show()

    return FinalizeItemData(cacheKey, rawLink, itemLink, tip)
end

local function BuildItemDataFromInventorySlot(slot)
    local rawLink = GetInventoryItemLink("player", slot)
    if not rawLink then return nil end
    local cacheKey = "inv:" .. tostring(slot) .. ":" .. rawLink
    if BAG_SCAN_ITEM_CACHE[cacheKey] then return BAG_SCAN_ITEM_CACHE[cacheKey] end

    local itemLink = ExtractItemHyperlink(rawLink)
    if not itemLink then return nil end

    local tip = GetBagScanTooltip()
    tip:ClearLines()
    local ok = pcall(function() tip:SetInventoryItem("player", slot) end)
    if not ok then
        tip:ClearLines()
        ok = pcall(function() tip:SetHyperlink(itemLink) end)
        if not ok then return nil end
    end
    tip:Show()

    return FinalizeItemData(cacheKey, rawLink, itemLink, tip)
end

local function GetCandidateModes(itemData, currentMhData)
    local modes = {}
    if not itemData then return modes end

    local raw = itemData.equipLoc or ""
    local equipLoc = NormalizeText(raw)

    local currentOhLink = GetInventoryItemLink("player", 17)
    local using2H = nil
    if currentMhData and currentMhData.equipLoc == "INVTYPE_2HWEAPON" then
        using2H = 1
    end
    if using2H ~= 1 and currentOhLink then
        using2H = nil
    end

    local function has(pat)
        return string.find(equipLoc, pat) ~= nil
    end

    if raw == "INVTYPE_HEAD" or equipLoc == "head" or has("head") then table.insert(modes, 1) end
    if raw == "INVTYPE_NECK" or equipLoc == "neck" or has("neck") then table.insert(modes, 2) end
    if raw == "INVTYPE_SHOULDER" or equipLoc == "shoulder" or has("shoulder") then table.insert(modes, 3) end
    if raw == "INVTYPE_CLOAK" or equipLoc == "back" or has("cloak") or has("back") then table.insert(modes, 15) end
    if raw == "INVTYPE_CHEST" or raw == "INVTYPE_ROBE" or equipLoc == "chest" or equipLoc == "robe" or has("chest") or has("robe") then table.insert(modes, 5) end
    if raw == "INVTYPE_WRIST" or equipLoc == "wrist" or has("wrist") or has("bracer") then table.insert(modes, 9) end
    if raw == "INVTYPE_HAND" or equipLoc == "hands" or equipLoc == "hand" or has("hand") or has("glove") then table.insert(modes, 10) end
    if raw == "INVTYPE_WAIST" or equipLoc == "waist" or has("waist") or has("belt") then table.insert(modes, 6) end
    if raw == "INVTYPE_LEGS" or equipLoc == "legs" or has("legs") then table.insert(modes, 7) end
    if raw == "INVTYPE_FEET" or equipLoc == "feet" or has("feet") or has("boot") then table.insert(modes, 8) end

    if raw == "INVTYPE_FINGER" or equipLoc == "finger" or has("finger") or has("ring") then
        table.insert(modes, 11)
        table.insert(modes, 12)
    end

    if raw == "INVTYPE_TRINKET" or equipLoc == "trinket" or has("trinket") then
        table.insert(modes, 13)
        table.insert(modes, 14)
    end

    -- Ranged slot: compare ranged/thrown items only against slot 18.
    if raw == "INVTYPE_RANGED" or raw == "INVTYPE_RANGEDRIGHT" or raw == "INVTYPE_THROWN" or has("ranged") or has("thrown") or has("bow") or has("gun") or has("crossbow") then
        table.insert(modes, 18)
    end

    -- Weapon policy:
    -- If currently using a 2H, only compare against other 2H weapons.
    -- If currently dual wielding / using a 1H setup, only compare 1H/main/off-hand weapons.
    if using2H == 1 then
        if raw == "INVTYPE_2HWEAPON" or has("two%-hand") or has("two hand") then
            table.insert(modes, "2H")
        end
        return modes
    end

    if raw == "INVTYPE_WEAPONMAINHAND" or has("main hand") then
        table.insert(modes, 16)
    end

    if raw == "INVTYPE_WEAPONOFFHAND" or has("off hand") then
        table.insert(modes, 17)
    end

    if raw == "INVTYPE_WEAPON" or has("one%-hand") or has("one hand") then
        table.insert(modes, 16)
        if currentOhLink then
            table.insert(modes, 17)
        end
    end

    return modes
end

local function StatDelta(newValue, oldValue)
    return (newValue or 0) - (oldValue or 0)
end

local function ApplyStatsDeltaToSnapshot(snapshot, deltaStats)
    snapshot.stats.strength = (snapshot.stats.strength or 0) + (deltaStats.strength or 0)
    snapshot.stats.agility = (snapshot.stats.agility or 0) + (deltaStats.agility or 0)
    snapshot.stats.attackPower = (snapshot.stats.attackPower or 0) + (deltaStats.attackPower or 0) + ((deltaStats.strength or 0) * 2)
    snapshot.stats.crit = (snapshot.stats.crit or 0) + (deltaStats.crit or 0) + ((deltaStats.agility or 0) / 20)
    snapshot.stats.hit = (snapshot.stats.hit or 0) + (deltaStats.hit or 0)
    snapshot.stats.haste = (snapshot.stats.haste or 0) + (deltaStats.haste or 0)
    snapshot.stats.armorPen = (snapshot.stats.armorPen or 0) + (deltaStats.armorPen or 0)
    snapshot.stats.armor = (snapshot.stats.armor or 0) + (deltaStats.armor or 0)

    if snapshot.stats.hit < 0 then snapshot.stats.hit = 0 end
    if snapshot.stats.crit < 0 then snapshot.stats.crit = 0 end
    if snapshot.stats.haste < 0 then snapshot.stats.haste = 0 end
    if snapshot.stats.armorPen < 0 then snapshot.stats.armorPen = 0 end

    snapshot.stats.castSpeed = 1 + ((snapshot.stats.haste or 0) / 100)

    local ranks = snapshot.talents and snapshot.talents.ranks or {}
    local slamReduction = GetImprovedSlamReductionFromRanks(ranks.impslam or 0)
    local slamBaseCastTime = 2.5 - slamReduction
    if slamBaseCastTime < 0.5 then slamBaseCastTime = 0.5 end
    snapshot.stats.slamBaseCastTime = slamBaseCastTime
    snapshot.stats.slamCastTime = slamBaseCastTime / (snapshot.stats.castSpeed or 1)
end

local function BuildDeltaStats(newItemData, oldItemData)
    local delta = {
        strength = StatDelta(newItemData and newItemData.stats.strength, oldItemData and oldItemData.stats.strength),
        agility = StatDelta(newItemData and newItemData.stats.agility, oldItemData and oldItemData.stats.agility),
        attackPower = 0,
        crit = StatDelta(newItemData and newItemData.stats.crit, oldItemData and oldItemData.stats.crit),
        hit = StatDelta(newItemData and newItemData.stats.hit, oldItemData and oldItemData.stats.hit),
        haste = StatDelta(newItemData and newItemData.stats.haste, oldItemData and oldItemData.stats.haste),
        armorPen = 0,
        armor = 0,
        bonusWeaponDamage = 0,
    }
    return delta
end

local function SetWeaponFromItemData(snapshotWeapon, itemData)
    snapshotWeapon.link = itemData.link
    snapshotWeapon.name = itemData.name
    snapshotWeapon.speed = itemData.weaponSpeed or snapshotWeapon.speed or 0
    snapshotWeapon.min = (itemData.weaponMin or 0) + (itemData.stats.bonusWeaponDamage or 0)
    snapshotWeapon.max = (itemData.weaponMax or 0) + (itemData.stats.bonusWeaponDamage or 0)
end

local function ClearOffhand(snapshot)
    snapshot.weapons.oh.link = nil
    snapshot.weapons.oh.name = nil
    snapshot.weapons.oh.speed = 0
    snapshot.weapons.oh.min = 0
    snapshot.weapons.oh.max = 0
    snapshot.weapons.oh.enabled = 0
end

local function GetSlotItemData(slot)
    return BuildItemDataFromInventorySlot(slot)
end

local function SlotIsWeapon(slot)
    -- Melee weapons only. Ranged slot is compared as a stat-only slot.
    return slot == 16 or slot == 17
end

function TWS:BuildBagScanSnapshot(baseSnapshot, itemData, mode)
    local snapshot = DeepCopy(baseSnapshot)
    local currentMhData = GetSlotItemData(16)
    local currentOhData = GetSlotItemData(17)

    if not itemData then return nil end
    if itemData.hasUnmodeledEffect then return nil end

    -- Non-melee slots are stat-only comparisons.
    -- This includes ranged slot 18: we compare only Strength->AP, Agility->crit,
    -- and crit/hit/haste %, and we do NOT use ranged base damage.
    if type(mode) == "number" and not SlotIsWeapon(mode) then
        local equippedData = GetSlotItemData(mode)
        if not equippedData or equippedData.hasUnmodeledEffect then return nil end
        if GetRecognizedStatBudget(itemData) <= 0 then return nil end
        if GetRecognizedStatBudget(equippedData) <= 0 then return nil end

        local delta = BuildDeltaStats(itemData, equippedData)
        ApplyStatsDeltaToSnapshot(snapshot, delta)
        return snapshot
    end

    -- Melee main hand comparison: include melee weapon base damage and speed.
    if mode == 16 then
        local equippedData = currentMhData
        if not equippedData then return nil end
        local delta = BuildDeltaStats(itemData, equippedData)
        ApplyStatsDeltaToSnapshot(snapshot, delta)
        SetWeaponFromItemData(snapshot.weapons.mh, itemData)
        return snapshot
    end

    -- Melee off hand comparison: include melee weapon base damage and speed.
    if mode == 17 then
        if currentMhData and currentMhData.equipLoc == "INVTYPE_2HWEAPON" then
            return nil
        end
        local equippedData = currentOhData
        if not equippedData then return nil end
        local delta = BuildDeltaStats(itemData, equippedData)
        ApplyStatsDeltaToSnapshot(snapshot, delta)
        SetWeaponFromItemData(snapshot.weapons.oh, itemData)
        snapshot.weapons.oh.enabled = 1
        return snapshot
    end

    -- Two-hand comparison: include 2H base damage/speed and remove offhand.
    if mode == "2H" then
        local deltaMh = BuildDeltaStats(itemData, currentMhData)
        local deltaOh = BuildDeltaStats(nil, currentOhData)
        local totalDelta = {
            strength = (deltaMh.strength or 0) + (deltaOh.strength or 0),
            agility = (deltaMh.agility or 0) + (deltaOh.agility or 0),
            attackPower = (deltaMh.attackPower or 0) + (deltaOh.attackPower or 0),
            crit = (deltaMh.crit or 0) + (deltaOh.crit or 0),
            hit = (deltaMh.hit or 0) + (deltaOh.hit or 0),
            haste = (deltaMh.haste or 0) + (deltaOh.haste or 0),
            armorPen = (deltaMh.armorPen or 0) + (deltaOh.armorPen or 0),
            armor = (deltaMh.armor or 0) + (deltaOh.armor or 0),
            bonusWeaponDamage = (deltaMh.bonusWeaponDamage or 0) + (deltaOh.bonusWeaponDamage or 0),
        }
        ApplyStatsDeltaToSnapshot(snapshot, totalDelta)
        SetWeaponFromItemData(snapshot.weapons.mh, itemData)
        ClearOffhand(snapshot)
        return snapshot
    end

    return nil
end

local function GetModeLabel(mode)
    if type(mode) == "number" then
        return SLOT_LABELS[mode] or ("Slot " .. tostring(mode))
    end
    if mode == "2H" then return "Two-Hand" end
    return tostring(mode)
end

local function CollectBagItems()
    local items = {}
    local seen = {}

    local function AddBag(bagId)
        local slots = GetContainerNumSlots(bagId) or 0
        local slot
        for slot = 1, slots do
            local link = GetContainerItemLink(bagId, slot)
            local itemLink = ExtractItemHyperlink(link)
            if itemLink and not seen[itemLink] then
                seen[itemLink] = 1
                table.insert(items, { bag = bagId, slot = slot, link = link })
            end
        end
    end

    AddBag(0)
    local bag
    for bag = 1, 4 do
        AddBag(bag)
    end

    if BankFrame and BankFrame:IsVisible() then
        AddBag(-1)
        for bag = 5, 10 do
            AddBag(bag)
        end
    end

    return items
end

local function ItemIsScanRelevant(itemData)
    if not itemData then return nil end

    if not BagScanIsEquippable(itemData) then return nil end

    if itemData.equipLoc == "INVTYPE_BAG" or itemData.equipLoc == "INVTYPE_AMMO" or itemData.equipLoc == "INVTYPE_QUIVER" then
        return nil
    end
    if itemData.equipLoc == "INVTYPE_RELIC" then
        return nil
    end
    if itemData.equipLoc == "INVTYPE_SHIELD" or itemData.equipLoc == "INVTYPE_HOLDABLE" then
        return nil
    end

    local modes = GetCandidateModes(itemData, GetSlotItemData(16))
    return table.getn(modes) > 0
end

function TWS:UpdateBagScanList(lines)
    if not self.mainWindow or not self.mainWindow.bagScanLines then return end
    local i
    for i = 1, table.getn(self.mainWindow.bagScanLines) do
        local fs = self.mainWindow.bagScanLines[i]
        fs:SetText(lines[i] or "")
    end
end

function TWS:RunBagScan()
    if not self.BuildSnapshot or not self.RunSimulation then return end

    local status = {}
    status[1] = "|cffffff00Scanning bags...|r"
    if not (BankFrame and BankFrame:IsVisible()) then
        status[2] = "|cffaaaaaaOpen your bank to include bank bags.|r"
    end
    self:UpdateBagScanList(status)

    local originalSims = self.db.sim.sims
    local scanSims = originalSims or 0
    if scanSims < 150 then scanSims = 150 end
    self.db.sim.sims = scanSims

    local baseSnapshot = self:BuildSnapshot()
    if not baseSnapshot then
        self.db.sim.sims = originalSims
        self:UpdateBagScanList({ "|cffff5555Unable to build snapshot.|r" })
        return
    end

    local baseResult = self:RunSimulation(baseSnapshot)
    local bagItems = CollectBagItems()
    local upgrades = {}
    local relevantCount = 0
    local testedCount = 0
    local skippedStrict = 0
    local equippableCount = 0
    local armorLikeCount = 0
    local locExamples = {}

    local idx
    for idx = 1, table.getn(bagItems) do
        local entry = bagItems[idx]
        local itemData = BuildItemDataFromBagSlot(entry.bag, entry.slot)

        if BagScanIsEquippable(itemData) then
            equippableCount = equippableCount + 1
        end
        if itemData and itemData.equipLoc and itemData.equipLoc ~= "" and itemData.equipLoc ~= "INVTYPE_WEAPON" and itemData.equipLoc ~= "INVTYPE_2HWEAPON" and itemData.equipLoc ~= "INVTYPE_WEAPONMAINHAND" and itemData.equipLoc ~= "INVTYPE_WEAPONOFFHAND" then
            armorLikeCount = armorLikeCount + 1
            if table.getn(locExamples) < 3 then
                table.insert(locExamples, tostring(itemData.equipLoc))
            end
        end

        if ItemIsScanRelevant(itemData) then
            relevantCount = relevantCount + 1
            local modes = GetCandidateModes(itemData, GetSlotItemData(16))
            local bestGain = nil
            local bestMode = nil

            local m
            for m = 1, table.getn(modes) do
                local mode = modes[m]
                local testSnapshot = self:BuildBagScanSnapshot(baseSnapshot, itemData, mode)
                if testSnapshot then
                    testedCount = testedCount + 1
                    local result = self:RunSimulation(testSnapshot)
                    local gain = (result.avgDPS or 0) - (baseResult.avgDPS or 0)
                    if (not bestGain) or gain > bestGain then
                        bestGain = gain
                        bestMode = mode
                    end
                else
                    skippedStrict = skippedStrict + 1
                end
            end

            if bestGain and bestGain > 0 then
                table.insert(upgrades, {
                    name = itemData.name or entry.link,
                    link = entry.link,
                    quality = itemData.quality or 1,
                    gain = bestGain,
                    modeLabel = GetModeLabel(bestMode),
                })
            end
        end
    end

    self.db.sim.sims = originalSims

    table.sort(upgrades, function(a, b)
        return (a.gain or 0) > (b.gain or 0)
    end)

    local lines = {}
    if table.getn(upgrades) == 0 then
        lines[1] = "|cffff5555No upgrades found.|r"
        lines[2] = "|cffaaaaaaScanned " .. tostring(table.getn(bagItems)) .. " bag items.|r"
        lines[3] = "|cffaaaaaaEquippable: " .. tostring(equippableCount) .. "|r"
        lines[4] = "|cffaaaaaaArmor-like: " .. tostring(armorLikeCount) .. "|r"
        lines[5] = "|cffaaaaaaRelevant: " .. tostring(relevantCount) .. ", tested: " .. tostring(testedCount) .. "|r"
        lines[6] = "|cffaaaaaaStrict skips: " .. tostring(skippedStrict) .. "|r"
        if table.getn(locExamples) > 0 then
            lines[7] = "|cff7777ff" .. table.concat(locExamples, ", ") .. "|r"
        end
        self:UpdateBagScanList(lines)
        return
    end

    local maxLines = table.getn(self.mainWindow.bagScanLines or {})
    local i
    for i = 1, math.min(table.getn(upgrades), maxLines) do
        local u = upgrades[i]
        local r, g, b = GetItemQualityColor(u.quality or 1)
        local color = string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255), math.floor((g or 1) * 255), math.floor((b or 1) * 255))
        local gainText = string.format("|cff00ff00+%.1f|r", u.gain or 0)
        lines[i] = gainText .. " " .. color .. (u.name or "Unknown") .. "|r |cffaaaaaa(" .. (u.modeLabel or "?") .. ")|r"
    end

    if table.getn(upgrades) > maxLines then
        lines[maxLines] = "|cffaaaaaa...more upgrades in bags/bank|r"
    end

    self:UpdateBagScanList(lines)
end

local function AttachBagScanUI(self)
    if not self.mainWindow or self.mainWindow.bagScanButton then return end

    local f = self.mainWindow
    local settingsX = 22
    local topY = -78

    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetWidth(100)
    btn:SetHeight(20)
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", settingsX, topY - 142)
    btn:SetText("Bag Scan")
    btn:SetScript("OnClick", function()
        self:CommitSimInputs()
        self:RunBagScan()
    end)
    f.bagScanButton = btn

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", settingsX, topY - 168)
    title:SetText("Upgrades")
    f.bagScanTitle = title

    f.bagScanLines = {}
    local i
    for i = 1, 8 do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", settingsX, topY - 168 - (i * 16))
        fs:SetWidth(150)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetText("")
        f.bagScanLines[i] = fs
    end
end

local originalCreateMainWindow = TWS.CreateMainWindow
if type(originalCreateMainWindow) == "function" then
    function TWS:CreateMainWindow()
        originalCreateMainWindow(self)
        AttachBagScanUI(self)
    end
end

if TWS.mainWindow then
    AttachBagScanUI(TWS)
end
