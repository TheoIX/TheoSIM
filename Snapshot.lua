TWS = TWS or {}

local function SafeCall(func)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d, e, f = pcall(func)
    if ok then return a, b, c, d, e, f end
    return nil
end

local function ParseNameFromLink(link)
    if not link then return nil end
    local _, _, name = string.find(link, "%[(.+)%]")
    return name
end

local function GetItemNameSafe(link)
    if not link then return nil end
    local name = GetItemInfo(link)
    if name then return name end
    return ParseNameFromLink(link)
end

local function GetTalentPoints()
    local t1, t2, t3 = 0, 0, 0
    local _, _, p1 = GetTalentTabInfo(1)
    local _, _, p2 = GetTalentTabInfo(2)
    local _, _, p3 = GetTalentTabInfo(3)
    t1 = p1 or 0
    t2 = p2 or 0
    t3 = p3 or 0
    return t1, t2, t3
end

local function HasSpellInBook(targetName)
    targetName = string.lower(targetName or "")
    local bookType = BOOKTYPE_SPELL or "spell"

    local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
    local tab
    for tab = 1, numTabs do
        local _, _, offset, numSlots = GetSpellTabInfo(tab)
        offset = offset or 0
        numSlots = numSlots or 0

        local i
        for i = 1, numSlots do
            local spellName = GetSpellName(offset + i, bookType)
            if spellName and string.lower(spellName) == targetName then
                return 1
            end
        end
    end

    return 0
end

local function GetTalentRanks()
    local ranks = {
        cruelty = 0,
        precision = 0,
        unbridledwrath = 0,
        flurry = 0,
        enrage = 0,
        dwspec = 0,
        impheroicstrike = 0,
        impexecute = 0,
        impslam = 0,
        bloodthirst = 0,
        mortalstrike = 0,
        sweepingstrikes = 0,
    }

        local tabs = GetNumTalentTabs and GetNumTalentTabs() or 0
    local tab, idx
    for tab = 1, tabs do
        local talents = GetNumTalents(tab)
        for idx = 1, talents do
            local name, _, _, _, rank = GetTalentInfo(tab, idx)
            local lname = string.lower(name or "")
            rank = rank or 0

            if lname == "cruelty" then ranks.cruelty = rank end
            if lname == "precision" then ranks.precision = rank end
            if lname == "unbridled wrath" then ranks.unbridledwrath = rank end
            if lname == "flurry" then ranks.flurry = rank end
            if lname == "enrage" then ranks.enrage = rank end
            if lname == "dual wield specialization" then ranks.dwspec = rank end
            if lname == "improved heroic strike" then ranks.impheroicstrike = rank end
            if lname == "improved execute" then ranks.impexecute = rank end
            if lname == "improved slam" then ranks.impslam = rank end
            if lname == "bloodthirst" then ranks.bloodthirst = rank end
            if lname == "mortal strike" then ranks.mortalstrike = rank end
            if lname == "sweeping strikes" then ranks.sweepingstrikes = rank end
        end
    end

    local function TalentRankAt(tab, idx)
        local _, _, _, _, rank = GetTalentInfo(tab, idx)
        return rank or 0
    end

    if ranks.sweepingstrikes == 0 then ranks.sweepingstrikes = TalentRankAt(1, 13) end
    if ranks.mortalstrike == 0 then ranks.mortalstrike = TalentRankAt(1, 18) end

    if ranks.dwspec == 0 then ranks.dwspec = TalentRankAt(2, 9) end
    if ranks.impexecute == 0 then ranks.impexecute = TalentRankAt(2, 10) end
    if ranks.impslam == 0 then ranks.impslam = TalentRankAt(2, 12) end
    if ranks.flurry == 0 then ranks.flurry = TalentRankAt(2, 16) end
    if ranks.bloodthirst == 0 then ranks.bloodthirst = TalentRankAt(2, 17) end
    
    if HasSpellInBook("Bloodthirst") == 1 then ranks.bloodthirst = 1 end
    if HasSpellInBook("Mortal Strike") == 1 then ranks.mortalstrike = 1 end
    if HasSpellInBook("Sweeping Strikes") == 1 then ranks.sweepingstrikes = 1 end

    return ranks
end

local function GetCritFromBCS(fallback)
    if not BCS or type(BCS.GetCritChance) ~= "function" then
        return fallback
    end
    local ok, value = pcall(function() return BCS:GetCritChance() end)
    if ok and value then return value end
    return fallback
end

local function GetWeaponSkillsFromAPI(level, hasOffhand)
    local fallback = (level or 60) * 5
    local mhBase, mhMod, ohBase, ohMod = UnitAttackBothHands("player")

    local mhSkill = fallback
    local ohSkill = 0

    if mhBase then
        mhSkill = (mhBase or 0) + (mhMod or 0)
        if mhSkill <= 0 then
            mhSkill = fallback
        end
    end

    if hasOffhand == 1 then
        if ohBase then
            ohSkill = (ohBase or 0) + (ohMod or 0)
            if ohSkill <= 0 then
                ohSkill = fallback
            end
        else
            ohSkill = fallback
        end
    end

    return mhSkill, ohSkill
end

local function StripAPFromWeaponDamage(displayMin, displayMax, attackPower, speed)
    local apComponent = ((attackPower or 0) / 14) * (speed or 0)
    local baseMin = (displayMin or 0) - apComponent
    local baseMax = (displayMax or 0) - apComponent
    if baseMin < 0 then baseMin = 0 end
    if baseMax < 0 then baseMax = 0 end
    return baseMin, baseMax
end

local function ApplyAPToWeaponDamage(baseMin, baseMax, attackPower, speed)
    local apComponent = ((attackPower or 0) / 14) * (speed or 0)
    return (baseMin or 0) + apComponent, (baseMax or 0) + apComponent
end

function TWS:GetTargetArmorAfterDebuffs()
    local armor = self.db.sim.baseArmor or 4211

    if self.db.sim.useSunder == 1 then armor = armor - 2250 end
    if self.db.sim.useFaerieFire == 1 then armor = armor - 505 end
    if self.db.sim.useCurseOfRecklessness == 1 then armor = armor - 640 end
    if self.db.sim.useExposeArmor == 1 then armor = armor - 1700 end
    if self.db.sim.useHomunculi == 1 then armor = armor - 1550 end

    if armor < 0 then armor = 0 end
    return armor
end

function TWS:BuildSnapshot()
    local _, class = UnitClass("player")
    if class ~= "WARRIOR" then
        self:Print("This engine pass is currently warrior-only.")
        return nil
    end

    local level = UnitLevel("player")
    local raceName = UnitRace("player")

    local baseStr, effectiveStr = UnitStat("player", 1)
    local baseAgi, effectiveAgi = UnitStat("player", 2)
    local baseSta, effectiveSta = UnitStat("player", 3)

    local apBase, apPos, apNeg = UnitAttackPower("player")
    local liveAttackPower = (apBase or 0) + (apPos or 0) + (apNeg or 0)
    local attackPower = liveAttackPower

    local apiCrit = SafeCall(GetCritChance) or 0
    local crit = GetCritFromBCS(apiCrit)

    local dodge = SafeCall(GetDodgeChance) or 0
    local parry = SafeCall(GetParryChance) or 0
    local block = SafeCall(GetBlockChance) or 0

    local _, effectiveArmor = UnitArmor("player")
    local armor = effectiveArmor or 0
    local health = UnitHealthMax("player")

    local mhSpeed, ohSpeed = UnitAttackSpeed("player")
    local minDmg, maxDmg, minOff, maxOff = UnitDamage("player")

    local mhLink = GetInventoryItemLink("player", 16)
    local ohLink = GetInventoryItemLink("player", 17)
    local hasOffhand = ohLink and 1 or 0

    local mhSkill, ohSkill = GetWeaponSkillsFromAPI(level, hasOffhand)

    local haste = 0
    local armorPen = 0
    local hit = 0
    local raidBuffsEnabled = self.db.sim.useRaidBuffs == 1
    local dwEnrageEnabled = self.db.sim.useDWEnrage == 1
    local flurryBuffEnabled = self.db.sim.useFlurryBuff == 1
    local theomodeEnabled = self.db.sim.useTheomodeHaste == 1

    if BCS then
        if type(BCS.GetHaste) == "function" then
            local ok, value = pcall(function() return BCS:GetHaste() end)
            if ok and value then haste = value end
        end
        if type(BCS.GetArmorPen) == "function" then
            local ok, value = pcall(function() return BCS:GetArmorPen() end)
            if ok and value then armorPen = value end
        end
        if type(BCS.GetHitRating) == "function" then
            local ok, value = pcall(function() return BCS:GetHitRating() end)
            if ok and value then hit = value end
        end
    end

    if raidBuffsEnabled then
        attackPower = attackPower + 929
        crit = crit + 12
        haste = haste + 2
    end
    if flurryBuffEnabled then
        haste = haste + 30
    end
    if theomodeEnabled then
        haste = haste + 35
        attackPower = attackPower + 400
    end

    local castSpeed = 1 + ((haste or 0) / 100)
    if (not raidBuffsEnabled) and (not flurryBuffEnabled) and (not theomodeEnabled) and BCS and type(BCS.GetCastSpeed) == "function" then
        local ok, value = pcall(function() return BCS:GetCastSpeed() end)
        if ok and value and value > 0 then castSpeed = value end
    end

    local mhBaseMin, mhBaseMax = StripAPFromWeaponDamage(minDmg or 0, maxDmg or 0, liveAttackPower, mhSpeed or 0)
    local ohBaseMin, ohBaseMax = 0, 0
    if hasOffhand == 1 then
        ohBaseMin, ohBaseMax = StripAPFromWeaponDamage(minOff or 0, maxOff or 0, liveAttackPower, ohSpeed or 0)
    end

    local mhSimMin, mhSimMax = ApplyAPToWeaponDamage(mhBaseMin, mhBaseMax, attackPower, mhSpeed or 0)
    local ohSimMin, ohSimMax = 0, 0
    if hasOffhand == 1 then
        ohSimMin, ohSimMax = ApplyAPToWeaponDamage(ohBaseMin, ohBaseMax, attackPower, ohSpeed or 0)
    end

    local t1, t2, t3 = GetTalentPoints()
    local talentRanks = GetTalentRanks()
    local impSlam = math.min(talentRanks.impslam or 0, 5)
    local slamBaseCastTime = 2.5 - (impSlam * 0.25)
    if slamBaseCastTime < 0.5 then slamBaseCastTime = 0.5 end
    local slamCastTime = slamBaseCastTime / castSpeed
    
    local snapshot = {
        level = level,
        race = raceName,
        class = class,
        stats = {
            strength = effectiveStr or baseStr or 0,
            agility = effectiveAgi or baseAgi or 0,
            stamina = effectiveSta or baseSta or 0,
            attackPower = attackPower,
            crit = crit,
            dodge = dodge,
            parry = parry,
            block = block,
            armor = armor,
            health = health,
            hit = hit,
            haste = haste,
            castSpeed = castSpeed,
            slamBaseCastTime = slamBaseCastTime,
            slamCastTime = slamCastTime,
            armorPen = armorPen,
            raidBuffs = raidBuffsEnabled,
            dwEnrage = dwEnrageEnabled,
            flurryBuff = flurryBuffEnabled,
            theomode = theomodeEnabled,
            damageMultiplier = dwEnrageEnabled and 1.4 or 1,
            windfury = raidBuffsEnabled,
            windfuryChance = raidBuffsEnabled and 20 or 0,
            windfuryBonusAP = raidBuffsEnabled and 315 or 0,
        },
        talents = {
            tab1 = t1,
            tab2 = t2,
            tab3 = t3,
            ranks = talentRanks,
        },
        weapons = {
            mh = {
                link = mhLink,
                name = GetItemNameSafe(mhLink),
                speed = mhSpeed or 0,
                min = mhSimMin,
                max = mhSimMax,
                baseMin = mhBaseMin,
                baseMax = mhBaseMax,
                skill = mhSkill,
            },
            oh = {
                link = ohLink,
                name = GetItemNameSafe(ohLink),
                speed = hasOffhand == 1 and (ohSpeed or 0) or 0,
                min = hasOffhand == 1 and ohSimMin or 0,
                max = hasOffhand == 1 and ohSimMax or 0,
                baseMin = hasOffhand == 1 and ohBaseMin or 0,
                baseMax = hasOffhand == 1 and ohBaseMax or 0,
                enabled = hasOffhand,
                skill = ohSkill,
            },
        },
        target = {
            level = self.db.sim.targetLevel,
            count = self.db.sim.targetCount,
            baseArmor = self.db.sim.baseArmor,
            debuffedArmor = self:GetTargetArmorAfterDebuffs(),
        },
        config = {
            sims = self.db.sim.sims,
            abilities = self.db.sim.abilities,
            defaults = {
                fightMin = 90,
                fightMax = 120,
                executePercent = 15,
                startRage = 0,
            },
            slam = {
                mainCd = self.db.sim.slamMainCd or 0,
                wwCd = self.db.sim.slamWwCd or 0,
                cost = 15,
                onlyTwoHanded = 1,
                baseCastTime = 2.5,
                clipBuffer = 0,
            },
        },
    }

    return snapshot
end
