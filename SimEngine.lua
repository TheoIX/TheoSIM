TWS = TWS or {}

local RESULT_HIT = 0
local RESULT_MISS = 1
local RESULT_DODGE = 2
local RESULT_CRIT = 3
local RESULT_GLANCE = 4

local function Clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function Avg(a, b)
    return ((a or 0) + (b or 0)) / 2
end

local function RNG(minV, maxV)
    return math.random() * (maxV - minV) + minV
end

local function RollChance(pct)
    return (math.random() * 100) < pct
end


local function AbilityEnabledValue(v)
    return v == 1 or v == true or v == "1"
end

function TWS:EstimateArmorReduction(playerLevel, targetArmor)
    local reduction = 0
    local denom = targetArmor + 400 + 85 * playerLevel
    if denom > 0 then
        reduction = targetArmor / denom
    end
    if reduction > 0.75 then reduction = 0.75 end
    if reduction < 0 then reduction = 0 end
    return reduction
end

function TWS:GetRageConversion(level)
    local conversion = ((0.0091107836 * level * level) + 3.225598133 * level) + 4.2652911
    if level == 25 then conversion = 82.25 end
    if level == 40 then conversion = 140.5 end
    return conversion
end

function TWS:GetTargetDefense(snapshot)
    return (snapshot.target.level or 63) * 5
end

function TWS:GetWeaponSkill(snapshot, hand)
    if hand == "oh" then
        return snapshot.weapons.oh.skill or (snapshot.level * 5)
    end
    return snapshot.weapons.mh.skill or (snapshot.level * 5)
end

function TWS:GetMissChance(snapshot, hand, isDualWield, queuedHS)
    local hit = snapshot.stats.hit or 0
    local targetDefense = self:GetTargetDefense(snapshot)
    local skill = self:GetWeaponSkill(snapshot, hand)
    local diff = targetDefense - skill

    local miss = 5 + math.max(diff * 0.2, 0)
    if isDualWield == 1 then
        miss = miss * 0.8 + 20
    end

    if queuedHS == 1 and hand == "mh" then
        miss = 5 + math.max(diff * 0.2, 0)
    end

    miss = miss - hit
    return Clamp(miss, 0, 100)
end

function TWS:GetDodgeChance(snapshot, hand)
    local targetDefense = self:GetTargetDefense(snapshot)
    local skill = self:GetWeaponSkill(snapshot, hand)
    local diff = targetDefense - skill
    local dodge = 5 + (diff * 0.1)
    return Clamp(dodge, 0, 100)
end

function TWS:GetGlanceChance(snapshot, hand)
    local targetDefense = self:GetTargetDefense(snapshot)
    local skill = self:GetWeaponSkill(snapshot, hand)
    return Clamp(10 + math.max(targetDefense - skill, 0) * 2, 0, 100)
end

function TWS:GetGlanceMultiplier(snapshot, hand)
    local targetDefense = self:GetTargetDefense(snapshot)
    local skill = self:GetWeaponSkill(snapshot, hand)
    local diff = targetDefense - skill

    local low = 0.9 - 0.023 * diff
    local high = 1.0 - 0.017 * diff

    low = Clamp(low, 0.01, 0.90)
    high = Clamp(high, 0.20, 1.00)

    return (low + high) / 2
end

function TWS:GetEffectiveCrit(snapshot, hand)
    local crit = snapshot.stats.crit or 0
    local targetDefense = self:GetTargetDefense(snapshot)
    local skill = self:GetWeaponSkill(snapshot, hand)
    local effective = crit + ((skill - targetDefense) * 0.04)

    local cruelty = snapshot.talents.ranks.cruelty or 0
    effective = effective + cruelty

    return Clamp(effective, 0, 100)
end

function TWS:RollWhiteResult(snapshot, hand, queuedHS)
    local isDualWield = 0
    if snapshot.weapons.oh.enabled == 1 then
        isDualWield = 1
    end

    local miss = self:GetMissChance(snapshot, hand, isDualWield, queuedHS)
    local dodge = self:GetDodgeChance(snapshot, hand)
    local glance = self:GetGlanceChance(snapshot, hand)
    local crit = self:GetEffectiveCrit(snapshot, hand)

    local roll = math.random() * 100
    local total = miss
    if roll < total then return RESULT_MISS end

    total = total + dodge
    if roll < total then return RESULT_DODGE end

    total = total + glance
    if roll < total then return RESULT_GLANCE end

    total = total + crit
    if roll < total then return RESULT_CRIT end

    return RESULT_HIT
end

function TWS:RollYellowResult(snapshot, hand)
    local miss = self:GetMissChance(snapshot, hand, 0, 0)
    local dodge = self:GetDodgeChance(snapshot, hand)
    local crit = self:GetEffectiveCrit(snapshot, hand)

    local roll = math.random() * 100
    local total = miss
    if roll < total then return RESULT_MISS end

    total = total + dodge
    if roll < total then return RESULT_DODGE end

    total = total + crit
    if roll < total then return RESULT_CRIT end

    return RESULT_HIT
end

function TWS:GetWeaponAPContribution(snapshot, hand, bonusAP)
    local ap = (snapshot and snapshot.stats and snapshot.stats.attackPower or 0) + (bonusAP or 0)
    local speed = 0

    if hand == "oh" then
        speed = snapshot and snapshot.weapons and snapshot.weapons.oh and snapshot.weapons.oh.speed or 0
    else
        speed = snapshot and snapshot.weapons and snapshot.weapons.mh and snapshot.weapons.mh.speed or 0
    end

    return (ap / 14) * speed
end

function TWS:GetWeaponAverage(snapshot, hand, bonusAP)
    local weapon
    if hand == "oh" then
        weapon = snapshot and snapshot.weapons and snapshot.weapons.oh or nil
    else
        weapon = snapshot and snapshot.weapons and snapshot.weapons.mh or nil
    end

    if not weapon then return 0 end

    local baseMin = weapon.baseMin or weapon.min or 0
    local baseMax = weapon.baseMax or weapon.max or 0
    return Avg(baseMin, baseMax) + self:GetWeaponAPContribution(snapshot, hand, bonusAP)
end

function TWS:GetArmorAdjustedDamage(snapshot, rawDamage)
    local armorPen = snapshot.stats.armorPen or 0
    local targetArmor = (snapshot.target.debuffedArmor or 0) - armorPen
    if targetArmor < 0 then targetArmor = 0 end
    local reduction = self:EstimateArmorReduction(snapshot.level, targetArmor)
    return rawDamage * (1 - reduction)
end

function TWS:GetAutoAttackDamage(snapshot, hand, result)
    local avg = self:GetWeaponAverage(snapshot, hand)
    local dmg = avg

    if hand == "oh" then
        dmg = dmg * 0.625
        local dws = snapshot.talents.ranks.dwspec or 0
        dmg = dmg * (1 + (dws * 0.05))
    end

    if result == RESULT_GLANCE then
        dmg = dmg * self:GetGlanceMultiplier(snapshot, hand)
    elseif result == RESULT_CRIT then
        dmg = dmg * 2
    end

    return self:GetArmorAdjustedDamage(snapshot, dmg)
end

function TWS:AddRageFromWhite(state, snapshot, hand, damage, result)
    local level = snapshot.level or 60
    local rageConv = self:GetRageConversion(level)

    if hand == "oh" then
        local speed = snapshot.weapons.oh.speed or 2.0
        if result == RESULT_DODGE then
            state.rage = state.rage + ((self:GetWeaponAverage(snapshot, "oh") / rageConv) * 7.5 * 0.75)
        elseif result == RESULT_HIT then
            state.rage = state.rage + ((((damage / rageConv) * 7.5) / 1.075) + ((speed * 1.75) / 2.4))
        elseif result == RESULT_CRIT or result == RESULT_GLANCE then
            state.rage = state.rage + ((((damage / rageConv) * 7.5) / 1.075) + ((speed * 3.5) / 2.25))
        end
    else
        local speed = snapshot.weapons.mh.speed or 2.8
        if result == RESULT_DODGE then
            state.rage = state.rage + ((self:GetWeaponAverage(snapshot, "mh") / rageConv) * 7.5 * 0.75)
        elseif result == RESULT_HIT then
            state.rage = state.rage + ((((damage / rageConv) * 7.5) / 1.075) + ((speed * 3.5) / 2.25))
        elseif result == RESULT_CRIT or result == RESULT_GLANCE then
            state.rage = state.rage + ((((damage / rageConv) * 7.5) / 1.075) + ((speed * 7.5) / 2.25))
        end
    end

    local ubw = snapshot.talents.ranks.unbridledwrath or 0
    if ubw > 0 and result ~= RESULT_MISS and result ~= RESULT_DODGE then
        if RollChance(ubw * 8) then
            state.rage = state.rage + 1
        end
    end

    if state.rage > 100 then state.rage = 100 end
end

function TWS:ApplyFlurryOnCrit(state, snapshot)
    local flurry = snapshot.talents.ranks.flurry or 0
    if flurry > 0 then
        state.flurryCharges = 3
        state.flurryBonus = 5 + (flurry * 5)
    end
end

function TWS:GetCurrentHasteMultiplier(state, snapshot)
    local base = 1 + ((snapshot.stats.haste or 0) / 100)
    if state.flurryCharges and state.flurryCharges > 0 then
        base = base * (1 + ((state.flurryBonus or 0) / 100))
    end
    return base
end

function TWS:GetCurrentCastSpeedMultiplier(state, snapshot)
    local base = snapshot.stats.castSpeed or (1 + ((snapshot.stats.haste or 0) / 100))
    if state.flurryCharges and state.flurryCharges > 0 then
        base = base * (1 + ((state.flurryBonus or 0) / 100))
    end
    return base
end

function TWS:GetImprovedSlamReduction(snapshot)
    local ranks = snapshot.talents and snapshot.talents.ranks or {}
    local imp = math.min(ranks.impslam or 0, 2)
    return imp * 0.25
end

function TWS:GetSlamCastTime(snapshot, state)
    local slam = snapshot.config.slam or {}
    local baseCast = slam.baseCastTime or 2.5
    local castTime = baseCast - self:GetImprovedSlamReduction(snapshot)
    if castTime < 0.5 then castTime = 0.5 end
    return castTime / self:GetCurrentCastSpeedMultiplier(state, snapshot)
end

function TWS:GetTimeRemaining(untilTime, currentTime)
    local remain = (untilTime or 0) - (currentTime or 0)
    if remain < 0 then remain = 0 end
    return remain
end

function TWS:ConsumeSwingCharge(state)
    if state.flurryCharges and state.flurryCharges > 0 then
        state.flurryCharges = state.flurryCharges - 1
        if state.flurryCharges <= 0 then
            state.flurryBonus = 0
        end
    end
end

function TWS:AddBreakdown(state, key, amount)
    if not amount or amount <= 0 then return end
    state.breakdown[key] = (state.breakdown[key] or 0) + amount
end

function TWS:IsWindfuryEnabled(snapshot)
    return snapshot and snapshot.stats and (snapshot.stats.windfury == 1 or snapshot.stats.windfury == true) and 1 or nil
end

function TWS:GetWindfuryBonusRawDamage(snapshot)
    local bonusAP = snapshot and snapshot.stats and snapshot.stats.windfuryBonusAP or 0
    local speed = snapshot and snapshot.weapons and snapshot.weapons.mh and snapshot.weapons.mh.speed or 0
    return (bonusAP / 14) * speed
end

function TWS:GetWindfuryAttackDamage(snapshot, result)
    local raw = self:GetWeaponAverage(snapshot, "mh") + self:GetWindfuryBonusRawDamage(snapshot)

    if result == RESULT_GLANCE then
        raw = raw * self:GetGlanceMultiplier(snapshot, "mh")
    elseif result == RESULT_CRIT then
        raw = raw * 2
    end

    return self:GetArmorAdjustedDamage(snapshot, raw)
end

function TWS:TryWindfuryProc(snapshot, state)
    if self:IsWindfuryEnabled(snapshot) ~= 1 then return 0 end
    if not RollChance(snapshot.stats.windfuryChance or 0) then return 0 end

    local result = self:RollWhiteResult(snapshot, "mh", 0)
    local dmg = 0

    if result ~= RESULT_MISS and result ~= RESULT_DODGE then
        dmg = self:GetWindfuryAttackDamage(snapshot, result)
        self:AddRageFromWhite(state, snapshot, "mh", dmg, result)
        if result == RESULT_CRIT then
            self:ApplyFlurryOnCrit(state, snapshot)
        end
        self:AddBreakdown(state, "windfury", dmg)
        dmg = dmg + self:ApplySweepingStrikeCopy(snapshot, state, dmg, 0, 1)
    else
        self:AddRageFromWhite(state, snapshot, "mh", 0, result)
    end

    self:ConsumeSwingCharge(state)
    return dmg
end

function TWS:GetExecuteStartTime(state, snapshot)
    return state.duration * (1 - ((snapshot.config.defaults.executePercent or 15) / 100))
end


function TWS:IsAbilityEnabled(snapshot, key)
    local a = snapshot.config and snapshot.config.abilities or nil
    local v = a and a[key] or nil
    if AbilityEnabledValue(v) then return 1 end

    if self.mainWindow and self.mainWindow.abilityButtons and self.mainWindow.abilityButtons[key] then
        local btn = self.mainWindow.abilityButtons[key]
        if AbilityEnabledValue(btn.value) then
            return 1
        end
    end

    return nil
end

function TWS:HasTalent(snapshot, key)
    return (snapshot.talents and snapshot.talents.ranks and (snapshot.talents.ranks[key] or 0) > 0) and 1 or 0
end

function TWS:CanUseBloodthirst(snapshot)
    return self:HasTalent(snapshot, "bloodthirst")
end

function TWS:CanUseMortalStrike(snapshot)
    return self:HasTalent(snapshot, "mortalstrike")
end

function TWS:CanUseSweepingStrikes(snapshot)
    return self:HasTalent(snapshot, "sweepingstrikes")
end

function TWS:GetMortalStrikeWeaponMultiplier(snapshot)
    -- Turtle WoW in-game tooltip shown by user: "A vicious strike that deals 130% weapon damage"
    -- Treat Mortal Strike as a flat 130% weapon-damage hit in this sim.
    return 1.30
end

function TWS:IsSweepingActive(state)
    if (state.ssCharges or 0) <= 0 then return nil end
    if (state.ssUntil or 0) <= (state.time or 0) then
        state.ssCharges = 0
        state.ssUntil = 0
        return nil
    end
    return 1
end

function TWS:ApplySweepingStrikeCopy(snapshot, state, damage, isOffhand, consumesCharge)
    if not damage or damage <= 0 then return 0 end
    if isOffhand == 1 then return 0 end
    if (snapshot.target.count or 1) < 2 then return 0 end
    if self:IsSweepingActive(state) ~= 1 then return 0 end

    local copy = damage
    self:AddBreakdown(state, "sweepingstrikes", copy)

    if consumesCharge == 1 then
        state.ssCharges = (state.ssCharges or 0) - 1
        if state.ssCharges <= 0 then
            state.ssCharges = 0
            state.ssUntil = 0
        end
    end

    return copy
end

function TWS:TryQueueHeroic(snapshot, state)
    local a = snapshot.config.abilities
    local targetCount = snapshot.target.count or 1
    local executeStart = self:GetExecuteStartTime(state, snapshot)
    local inExecute = state.time >= executeStart

    if state.queueSpell then return end

    if targetCount > 1 and self:IsAbilityEnabled(snapshot, "cleave") == 1 then
        if (not inExecute and state.rage >= 35) or (targetCount >= 3 and state.rage >= 30) then
            state.queueSpell = "cleave"
            return
        end
    end

    if self:IsAbilityEnabled(snapshot, "heroicstrike") == 1 then
        if (not inExecute and state.rage >= 55) or (inExecute and state.rage >= 70) then
            state.queueSpell = "heroicstrike"
        end
    end
end

function TWS:CastBloodthirst(snapshot, state)
    if self:CanUseBloodthirst(snapshot) ~= 1 then return 0, 0 end

    local cost = 30
    if state.rage < cost then return 0, 0 end

    state.rage = state.rage - cost
    state.gcdUntil = state.time + 1.5
    state.btCdUntil = state.time + 6.0

    local result = self:RollYellowResult(snapshot, "mh")
    if result == RESULT_MISS or result == RESULT_DODGE then
        state.rage = state.rage + (cost * 0.8)
        if state.rage > 100 then state.rage = 100 end
        return 0, result
    end

    local raw = (snapshot.stats.attackPower or 0) * 0.45
    local dmg = self:GetArmorAdjustedDamage(snapshot, raw)
    if result == RESULT_CRIT then
        dmg = dmg * 2
        self:ApplyFlurryOnCrit(state, snapshot)
    end

    self:AddBreakdown(state, "bloodthirst", dmg)
    local ss = self:ApplySweepingStrikeCopy(snapshot, state, dmg, 0, 1)
    return dmg + ss, result
end

function TWS:CastMortalStrike(snapshot, state)
    if self:CanUseMortalStrike(snapshot) ~= 1 then return 0, 0 end

    local cost = 30
    if state.rage < cost then return 0, 0 end

    state.rage = state.rage - cost
    state.gcdUntil = state.time + 1.5
    state.msCdUntil = state.time + 6.0

    local result = self:RollYellowResult(snapshot, "mh")
    if result == RESULT_MISS or result == RESULT_DODGE then
        state.rage = state.rage + (cost * 0.8)
        if state.rage > 100 then state.rage = 100 end
        return 0, result
    end

    local raw = self:GetWeaponAverage(snapshot, "mh") * self:GetMortalStrikeWeaponMultiplier(snapshot)
    local dmg = self:GetArmorAdjustedDamage(snapshot, raw)
    if result == RESULT_CRIT then
        dmg = dmg * 2
        self:ApplyFlurryOnCrit(state, snapshot)
    end

    self:AddBreakdown(state, "mortalstrike", dmg)
    local ss = self:ApplySweepingStrikeCopy(snapshot, state, dmg, 0, 1)
    local wf = self:TryWindfuryProc(snapshot, state)
    return dmg + ss + wf, result
end

function TWS:CastSweepingStrikes(snapshot, state)
    if self:CanUseSweepingStrikes(snapshot) ~= 1 then return 0, 0 end
    if (snapshot.target.count or 1) < 2 then return 0, 0 end
    if self:IsSweepingActive(state) == 1 then return 0, 0 end
    if state.time < (state.ssCdUntil or 0) then return 0, 0 end

    local cost = 20
    if state.rage < cost then return 0, 0 end

    state.rage = state.rage - cost
    state.gcdUntil = state.time + 1.5
    state.ssCdUntil = state.time + 30.0
    state.ssUntil = state.time + 20.0
    state.ssCharges = 5

    return 0, RESULT_HIT
end

function TWS:CastWhirlwind(snapshot, state)
    local cost = 25
    if state.rage < cost then return 0, 0 end

    state.rage = state.rage - cost
    state.gcdUntil = state.time + 1.5
    state.wwCdUntil = state.time + 10.0

    local targets = snapshot.target.count or 1
    if targets < 1 then targets = 1 end
    if targets > 4 then targets = 4 end

    local total = 0
    local t

    for t = 1, targets do
        local mhResult = self:RollYellowResult(snapshot, "mh")
        if mhResult ~= RESULT_MISS and mhResult ~= RESULT_DODGE then
            local mh = self:GetArmorAdjustedDamage(snapshot, self:GetWeaponAverage(snapshot, "mh"))
            if mhResult == RESULT_CRIT then
                mh = mh * 2
                self:ApplyFlurryOnCrit(state, snapshot)
            end
            total = total + mh
        end

        if snapshot.weapons.oh.enabled == 1 then
            local ohResult = self:RollYellowResult(snapshot, "oh")
            if ohResult ~= RESULT_MISS and ohResult ~= RESULT_DODGE then
                local oh = self:GetArmorAdjustedDamage(snapshot, self:GetWeaponAverage(snapshot, "oh") * 0.625)
                local dws = snapshot.talents.ranks.dwspec or 0
                oh = oh * (1 + (dws * 0.05))
                if ohResult == RESULT_CRIT then
                    oh = oh * 2
                    self:ApplyFlurryOnCrit(state, snapshot)
                end
                total = total + oh
            end
        end
    end

    self:AddBreakdown(state, "whirlwind", total)
    return total, RESULT_HIT
end

function TWS:CastExecute(snapshot, state)
    local imp = snapshot.talents.ranks.impexecute or 0
    local cost = 15 - math.min(imp, 5)
    if state.rage < cost then return 0, 0 end

    local spent = state.rage - cost
    state.rage = 0
    state.gcdUntil = state.time + 1.5

    local result = self:RollYellowResult(snapshot, "mh")
    if result == RESULT_MISS or result == RESULT_DODGE then
        state.rage = cost * 0.8
        return 0, result
    end

    local raw = 600 + (spent * 15)
    local dmg = self:GetArmorAdjustedDamage(snapshot, raw)
    if result == RESULT_CRIT then
        dmg = dmg * 2
        self:ApplyFlurryOnCrit(state, snapshot)
    end

    self:AddBreakdown(state, "execute", dmg)
    local ss = self:ApplySweepingStrikeCopy(snapshot, state, dmg, 0, 1)
    return dmg + ss, result
end


function TWS:CanCastSlam(snapshot, state)
    local a = snapshot.config.abilities or {}
    local slam = snapshot.config.slam or {}

    if self:IsAbilityEnabled(snapshot, "slam") ~= 1 then return nil end
    if slam.onlyTwoHanded == 1 and snapshot.weapons.oh.enabled == 1 then return nil end
    if state.castingSlam == 1 then return nil end

    local cost = slam.cost or 15
    if state.rage < cost then return nil end

    local mhRemain = self:GetTimeRemaining(state.nextMh, state.time)
    local slamCast = self:GetSlamCastTime(snapshot, state)
    local clipBuffer = slam.clipBuffer or 0
    if mhRemain < (slamCast + clipBuffer) then return nil end

    local mainCd = slam.mainCd or 0
    if mainCd > 0 then
        if self:IsAbilityEnabled(snapshot, "bloodthirst") == 1 and self:CanUseBloodthirst(snapshot) == 1 then
            local btRemain = self:GetTimeRemaining(state.btCdUntil, state.time)
            if btRemain > 0 and btRemain < mainCd then return nil end
        end
        if self:IsAbilityEnabled(snapshot, "mortalstrike") == 1 and self:CanUseMortalStrike(snapshot) == 1 then
            local msRemain = self:GetTimeRemaining(state.msCdUntil, state.time)
            if msRemain > 0 and msRemain < mainCd then return nil end
        end
        if self:IsAbilityEnabled(snapshot, "execute") == 1 then
            local executeStart = self:GetExecuteStartTime(state, snapshot)
            if state.time >= executeStart then return nil end
        end
    end

    local wwCd = slam.wwCd or 0
    if wwCd > 0 and self:IsAbilityEnabled(snapshot, "whirlwind") == 1 then
        local wwRemain = self:GetTimeRemaining(state.wwCdUntil, state.time)
        if wwRemain > 0 and wwRemain < wwCd then return nil end
    end

    return 1
end

function TWS:StartSlamCast(snapshot, state)
    local castTime = self:GetSlamCastTime(snapshot, state)
    local slamGcd = math.max(1.5 - self:GetImprovedSlamReduction(snapshot), 0)

    state.castingSlam = 1
    state.slamCastEnd = state.time + castTime
    state.gcdUntil = state.time + slamGcd

    return 0, RESULT_HIT, 1
end

function TWS:FinishSlamCast(snapshot, state)
    local slam = snapshot.config.slam or {}
    local cost = slam.cost or 15

    state.castingSlam = 0
    state.slamCastEnd = 0

    if state.rage < cost then return 0, 0 end

    state.rage = state.rage - cost

    local result = self:RollYellowResult(snapshot, "mh")
    if result == RESULT_MISS or result == RESULT_DODGE then
        state.rage = state.rage + (cost * 0.8)
        if state.rage > 100 then state.rage = 100 end
        return 0, result
    end

    local raw = self:GetWeaponAverage(snapshot, "mh")
    local dmg = self:GetArmorAdjustedDamage(snapshot, raw)
    if result == RESULT_CRIT then
        dmg = dmg * 2
        self:ApplyFlurryOnCrit(state, snapshot)
    end

    self:AddBreakdown(state, "slam", dmg)
    local ss = self:ApplySweepingStrikeCopy(snapshot, state, dmg, 0, 1)
    local wf = self:TryWindfuryProc(snapshot, state)
    return dmg + ss + wf, result
end

function TWS:ResolveQueuedMainhand(snapshot, state)
    local queued = state.queueSpell
    state.queueSpell = nil

    if queued == "heroicstrike" then
        local cost = 15 - (snapshot.talents.ranks.impheroicstrike or 0)
        if state.rage >= cost then
            state.rage = state.rage - cost
            local result = self:RollYellowResult(snapshot, "mh")
            if result == RESULT_MISS or result == RESULT_DODGE then
                state.rage = state.rage + (cost * 0.8)
                return 0, result
            end

            local raw = self:GetWeaponAverage(snapshot, "mh") + 138
            local dmg = self:GetArmorAdjustedDamage(snapshot, raw)
            if result == RESULT_CRIT then
                dmg = dmg * 2
                self:ApplyFlurryOnCrit(state, snapshot)
            end
            self:AddBreakdown(state, "heroicstrike", dmg)
            local ss = self:ApplySweepingStrikeCopy(snapshot, state, dmg, 0, 1)
            local wf = self:TryWindfuryProc(snapshot, state)
            return dmg + ss + wf, result
        end
    elseif queued == "cleave" then
        local cost = 20
        if state.rage >= cost then
            state.rage = state.rage - cost

            local targets = snapshot.target.count or 1
            if targets > 2 then targets = 2 end
            if targets < 1 then targets = 1 end

            local total = 0
            local procWindfury = nil
            local k
            for k = 1, targets do
                local result = self:RollYellowResult(snapshot, "mh")
                if result ~= RESULT_MISS and result ~= RESULT_DODGE then
                    local raw = self:GetWeaponAverage(snapshot, "mh") + 50
                    local dmg = self:GetArmorAdjustedDamage(snapshot, raw)
                    if result == RESULT_CRIT then
                        dmg = dmg * 2
                        self:ApplyFlurryOnCrit(state, snapshot)
                    end
                    total = total + dmg
                    if k == 1 then
                        procWindfury = 1
                    end
                else
                    if k == 1 then
                        state.rage = state.rage + (cost * 0.8)
                    end
                end
            end

            self:AddBreakdown(state, "cleave", total)
            if procWindfury == 1 then
                total = total + self:TryWindfuryProc(snapshot, state)
            end
            return total, RESULT_HIT
        end
    end

    return self:ResolveMainhandWhite(snapshot, state)
end

function TWS:ResolveMainhandWhite(snapshot, state)
    local result = self:RollWhiteResult(snapshot, "mh", 0)
    local dmg = 0

    if result ~= RESULT_MISS and result ~= RESULT_DODGE then
        dmg = self:GetAutoAttackDamage(snapshot, "mh", result)
        self:AddRageFromWhite(state, snapshot, "mh", dmg, result)
        if result == RESULT_CRIT then
            self:ApplyFlurryOnCrit(state, snapshot)
        end
        self:AddBreakdown(state, "white", dmg)
        dmg = dmg + self:ApplySweepingStrikeCopy(snapshot, state, dmg, 0, 1)
        dmg = dmg + self:TryWindfuryProc(snapshot, state)
    else
        self:AddRageFromWhite(state, snapshot, "mh", 0, result)
    end

    self:ConsumeSwingCharge(state)
    return dmg, result
end

function TWS:ResolveMainhandSwing(snapshot, state)
    if state.queueSpell then
        local dmg, result = self:ResolveQueuedMainhand(snapshot, state)
        self:ConsumeSwingCharge(state)
        return dmg, result
    end
    return self:ResolveMainhandWhite(snapshot, state)
end

function TWS:ResolveOffhandSwing(snapshot, state)
    if snapshot.weapons.oh.enabled ~= 1 then return 0, RESULT_HIT end

    local result = self:RollWhiteResult(snapshot, "oh", 0)
    local dmg = 0

    if result ~= RESULT_MISS and result ~= RESULT_DODGE then
        dmg = self:GetAutoAttackDamage(snapshot, "oh", result)
        self:AddRageFromWhite(state, snapshot, "oh", dmg, result)
        if result == RESULT_CRIT then
            self:ApplyFlurryOnCrit(state, snapshot)
        end
        self:AddBreakdown(state, "white", dmg)
    else
        self:AddRageFromWhite(state, snapshot, "oh", 0, result)
    end

    self:ConsumeSwingCharge(state)
    return dmg, result
end

function TWS:TryCastAbility(snapshot, state)
    local a = snapshot.config.abilities or {}
    local executeStart = self:GetExecuteStartTime(state, snapshot)

    if state.time >= executeStart and self:IsAbilityEnabled(snapshot, "execute") == 1 then
        if state.rage >= (15 - math.min(snapshot.talents.ranks.impexecute or 0, 5)) then
            return self:CastExecute(snapshot, state)
        end
    end

    if self:IsAbilityEnabled(snapshot, "sweepingstrikes") == 1 and self:CanUseSweepingStrikes(snapshot) == 1 then
        if self:IsSweepingActive(state) ~= 1 and state.time >= (state.ssCdUntil or 0) and (snapshot.target.count or 1) >= 2 and state.rage >= 20 then
            return self:CastSweepingStrikes(snapshot, state)
        end
    end

    if self:IsAbilityEnabled(snapshot, "bloodthirst") == 1 and self:CanUseBloodthirst(snapshot) == 1 and state.time >= state.btCdUntil and state.rage >= 30 then
        return self:CastBloodthirst(snapshot, state)
    end

    if self:IsAbilityEnabled(snapshot, "mortalstrike") == 1 and self:CanUseMortalStrike(snapshot) == 1 and state.time >= (state.msCdUntil or 0) and state.rage >= 30 then
        return self:CastMortalStrike(snapshot, state)
    end

    if self:IsAbilityEnabled(snapshot, "whirlwind") == 1 and state.time >= state.wwCdUntil and state.rage >= 25 then
        return self:CastWhirlwind(snapshot, state)
    end

    if self:CanCastSlam(snapshot, state) then
        return self:StartSlamCast(snapshot, state)
    end

    self:TryQueueHeroic(snapshot, state)
    return 0, 0, 0
end

function TWS:RunOneIteration(snapshot)
    local hasteMult = 1 + ((snapshot.stats.haste or 0) / 100)
    local mhBaseSpeed = snapshot.weapons.mh.speed or 2.8
    local ohBaseSpeed = snapshot.weapons.oh.speed or 2.0

    local state = {
        time = 0,
        duration = RNG(snapshot.config.defaults.fightMin or 90, snapshot.config.defaults.fightMax or 120),
        rage = snapshot.config.defaults.startRage or 0,
        gcdUntil = 0,
        btCdUntil = 0,
        msCdUntil = 0,
        wwCdUntil = 0,
        ssCdUntil = 0,
        ssUntil = 0,
        ssCharges = 0,
        castingSlam = 0,
        slamCastEnd = 0,
        queueSpell = nil,
        flurryCharges = 0,
        flurryBonus = 0,
        nextMh = mhBaseSpeed / hasteMult,
        nextOh = snapshot.weapons.oh.enabled == 1 and ((ohBaseSpeed / hasteMult) / 2) or 999999,
        total = 0,
        breakdown = {
            white = 0,
            bloodthirst = 0,
            mortalstrike = 0,
            sweepingstrikes = 0,
            whirlwind = 0,
            execute = 0,
            slam = 0,
            heroicstrike = 0,
            cleave = 0,
            windfury = 0,
        },
    }

    while state.time < state.duration do
        if state.castingSlam == 1 then
            if state.slamCastEnd > state.time then
                state.time = state.slamCastEnd
            end
            local dmg = self:FinishSlamCast(snapshot, state)
            state.total = state.total + (dmg or 0)
        else
            if state.gcdUntil <= state.time then
                local dmg, _, startedSlam = self:TryCastAbility(snapshot, state)
                state.total = state.total + (dmg or 0)
                if startedSlam ~= 1 then
                    local currentHaste = self:GetCurrentHasteMultiplier(state, snapshot)
                    local progressed = 0

                    if state.nextMh <= state.time + 0.0001 then
                        local swingDmg = self:ResolveMainhandSwing(snapshot, state)
                        state.total = state.total + (swingDmg or 0)
                        state.nextMh = state.time + (mhBaseSpeed / currentHaste)
                        progressed = 1
                    end

                    if snapshot.weapons.oh.enabled == 1 and state.nextOh <= state.time + 0.0001 then
                        local offDmg = self:ResolveOffhandSwing(snapshot, state)
                        state.total = state.total + (offDmg or 0)
                        state.nextOh = state.time + (ohBaseSpeed / currentHaste)
                        progressed = 1
                    end

                    if progressed == 0 then
                        local nextEvent = state.duration
                        if state.nextMh < nextEvent then nextEvent = state.nextMh end
                        if state.nextOh < nextEvent then nextEvent = state.nextOh end
                        if state.gcdUntil > state.time and state.gcdUntil < nextEvent then nextEvent = state.gcdUntil end
                        if nextEvent < state.time then nextEvent = state.time end
                        if nextEvent == state.time then nextEvent = state.time + 0.0001 end
                        state.time = nextEvent
                    end
                end
            else
                self:TryQueueHeroic(snapshot, state)

                local currentHaste = self:GetCurrentHasteMultiplier(state, snapshot)
                local progressed = 0

                if state.nextMh <= state.time + 0.0001 then
                    local swingDmg = self:ResolveMainhandSwing(snapshot, state)
                    state.total = state.total + (swingDmg or 0)
                    state.nextMh = state.time + (mhBaseSpeed / currentHaste)
                    progressed = 1
                end

                if snapshot.weapons.oh.enabled == 1 and state.nextOh <= state.time + 0.0001 then
                    local offDmg = self:ResolveOffhandSwing(snapshot, state)
                    state.total = state.total + (offDmg or 0)
                    state.nextOh = state.time + (ohBaseSpeed / currentHaste)
                    progressed = 1
                end

                if progressed == 0 then
                    local nextEvent = state.duration
                    if state.nextMh < nextEvent then nextEvent = state.nextMh end
                    if state.nextOh < nextEvent then nextEvent = state.nextOh end
                    if state.gcdUntil > state.time and state.gcdUntil < nextEvent then nextEvent = state.gcdUntil end
                    if nextEvent < state.time then nextEvent = state.time end
                    if nextEvent == state.time then nextEvent = state.time + 0.0001 end
                    state.time = nextEvent
                end
            end
        end
    end

    return (state.total / state.duration), state.breakdown, state.duration
end

function TWS:RunSimulation(snapshot)
    local sims = self.db.sim.sims or 500
    local total = 0
    local minDPS = nil
    local maxDPS = nil
    local totals = {
        white = 0,
        bloodthirst = 0,
        mortalstrike = 0,
        sweepingstrikes = 0,
        whirlwind = 0,
        execute = 0,
        slam = 0,
        heroicstrike = 0,
        cleave = 0,
        windfury = 0,
        duration = 0,
    }

    local i
    for i = 1, sims do
        local dps, breakdown, duration = self:RunOneIteration(snapshot)
        total = total + dps
        totals.duration = totals.duration + duration

        local key
        for key, value in pairs(breakdown) do
            totals[key] = totals[key] + value
        end

        if not minDPS or dps < minDPS then minDPS = dps end
        if not maxDPS or dps > maxDPS then maxDPS = dps end
    end

    local avgDPS = total / sims
    local avgDuration = totals.duration / sims

    if self:CanUseBloodthirst(snapshot) ~= 1 then totals.bloodthirst = 0 end
    if self:CanUseMortalStrike(snapshot) ~= 1 then totals.mortalstrike = 0 end
    if self:CanUseSweepingStrikes(snapshot) ~= 1 then totals.sweepingstrikes = 0 end

    local whiteDPS = totals.white / avgDuration / sims
    local abilityDPS = (totals.bloodthirst + totals.mortalstrike + totals.sweepingstrikes + totals.whirlwind + totals.execute + totals.slam + totals.heroicstrike + totals.cleave + totals.windfury) / avgDuration / sims

    return {
        sims = sims,
        avgDPS = avgDPS,
        minDPS = minDPS or 0,
        maxDPS = maxDPS or 0,
        whiteDPS = whiteDPS,
        abilityDPS = abilityDPS,
        targetArmor = snapshot.target.debuffedArmor,
        breakdown = {
            white = totals.white / avgDuration / sims,
            bloodthirst = totals.bloodthirst / avgDuration / sims,
            mortalstrike = totals.mortalstrike / avgDuration / sims,
            sweepingstrikes = totals.sweepingstrikes / avgDuration / sims,
            whirlwind = totals.whirlwind / avgDuration / sims,
            execute = totals.execute / avgDuration / sims,
            slam = totals.slam / avgDuration / sims,
            heroicstrike = totals.heroicstrike / avgDuration / sims,
            cleave = totals.cleave / avgDuration / sims,
            windfury = totals.windfury / avgDuration / sims,
        },
        note = "Engine pass v0.8: Ability toggles now resolve from both snapshot config and live UI button state, so BT/MS/SS/WW/Execute/HS/Cleave/Slam no longer silently fail from stale toggle values; Mortal Strike remains 130% weapon damage and Slam remains haste-scaled/no-clip, with Improved Slam using live Turtle's 0.25s-per-rank reduction.",
    }
end
