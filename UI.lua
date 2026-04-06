TWS = TWS or {}

local function MakeButton(parent, label, width, height, x, y)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(height)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(label)
    return b
end

local function MakeLabel(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function CommitNumericBox(box, key, minValue, maxValue, defaultValue)
    local v = tonumber(box:GetText()) or defaultValue
    if v < minValue then v = minValue end
    if v > maxValue then v = maxValue end
    TWS.db.sim[key] = v
    box:SetText(v)
end


local function GetUITalentRanks()
    local ranks = {
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
            if lname == "bloodthirst" then ranks.bloodthirst = rank end
            if lname == "mortal strike" then ranks.mortalstrike = rank end
            if lname == "sweeping strikes" then ranks.sweepingstrikes = rank end
        end
    end

    return ranks
end

local function SetToggleVisual(btn)
    local on = btn.value == 1
    if on then
        btn.icon:SetAlpha(1.0)
        btn.label:SetAlpha(1.0)
        btn.bg:SetVertexColor(0.15, 0.15, 0.15)
    else
        btn.icon:SetAlpha(0.35)
        btn.label:SetAlpha(0.45)
        btn.bg:SetVertexColor(0.08, 0.08, 0.08)
    end
end

local function MakeIconToggle(parent, x, y, label, iconPath, initialValue, onToggle)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(140)
    btn:SetHeight(22)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetAllPoints(btn)
    btn.bg = bg

    local border = CreateFrame("Frame", nil, btn)
    border:SetAllPoints(btn)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetPoint("LEFT", btn, "LEFT", 2, 0)
    icon:SetTexture(iconPath)
    btn.icon = icon

    local labelFS = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelFS:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    labelFS:SetJustifyH("LEFT")
    labelFS:SetText(label)
    btn.label = labelFS
    btn.baseLabel = label

    btn.value = initialValue == 1 and 1 or 0
    SetToggleVisual(btn)

    btn:SetScript("OnClick", function()
        if btn.value == 1 then
            btn.value = 0
        else
            btn.value = 1
        end
        SetToggleVisual(btn)
        onToggle(btn.value)
    end)

    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        if btn.value == 1 then
            GameTooltip:AddLine("Enabled", 0.2, 1.0, 0.2)
        else
            GameTooltip:AddLine("Disabled", 1.0, 0.2, 0.2)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return btn
end

function TWS:CommitSimInputs()
    if self.targetLevelEdit then
        CommitNumericBox(self.targetLevelEdit, "targetLevel", 60, 63, 63)
    end
    if self.targetCountEdit then
        CommitNumericBox(self.targetCountEdit, "targetCount", 1, 3, 1)
    end
    if self.simCountEdit then
        CommitNumericBox(self.simCountEdit, "sims", 1, 5000, 500)
    end
    if self.slamMainCdEdit then
        CommitNumericBox(self.slamMainCdEdit, "slamMainCd", 0, 5, 0)
    end
end



function TWS:RefreshAbilityTalentGates()
    if not self.mainWindow or not self.mainWindow.abilityButtons then return end

    local ranks = GetUITalentRanks()
    local gating = {
        bloodthirst = ranks.bloodthirst > 0,
        mortalstrike = ranks.mortalstrike > 0,
        sweepingstrikes = ranks.sweepingstrikes > 0,
    }

    local key, learned
    for key, learned in pairs(gating) do
        local btn = self.mainWindow.abilityButtons[key]
        if btn then
            if learned then
                btn:Enable()
                btn.label:SetText(btn.baseLabel or btn.label:GetText())
                SetToggleVisual(btn)
            else
                btn:Disable()
                btn.icon:SetAlpha(0.20)
                btn.label:SetAlpha(0.35)
                btn.label:SetText((btn.baseLabel or btn.label:GetText()) .. " (talent)")
                btn.bg:SetVertexColor(0.05, 0.05, 0.05)
            end
        end
    end
end

function TWS:CreateMainWindow()
    local width = 560
    local height = 520
    self.db.sim.slamMainCd = self.db.sim.slamMainCd or 0
    self.db.sim.useRaidBuffs = self.db.sim.useRaidBuffs or 0
    self.db.sim.useDWEnrage = self.db.sim.useDWEnrage or 0
    self.db.sim.useFlurryBuff = self.db.sim.useFlurryBuff or 0
    self.db.sim.useTheomodeHaste = self.db.sim.useTheomodeHaste or 0
    self.db.window.width = width
    self.db.window.height = height

    local f = CreateFrame("Frame", "TurtleWarriorSimMainWindow", UIParent)
    f:SetWidth(width)
    f:SetHeight(height)
    f:SetPoint(self.db.window.point, UIParent, self.db.window.point, self.db.window.x, self.db.window.y)
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint()
        TWS.db.window.point = point
        TWS.db.window.x = x
        TWS.db.window.y = y
    end)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", f, "TOP", 0, -20)
    title:SetText("TheoSIM")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local simButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    simButton:SetWidth(110)
    simButton:SetHeight(24)
    simButton:SetPoint("TOP", f, "TOP", 0, -36)
    simButton:SetText("SIM")
    simButton:SetScript("OnClick", function()
        TWS:CommitSimInputs()
        TWS:RunSim()
    end)

    local settingsX = 22
    local abilitiesX = 190
    local debuffsX = 370
    local topY = -78

    MakeLabel(f, "Settings", settingsX, topY, "GameFontNormalLarge")
    MakeLabel(f, "Abilities", abilitiesX, topY, "GameFontNormalLarge")
    MakeLabel(f, "Armor Debuffs", debuffsX, topY, "GameFontNormalLarge")

    local targetLevelLabel = MakeLabel(f, "Target Level", settingsX, topY - 26, "GameFontNormal")
    local targetLevelEdit = CreateFrame("EditBox", "TWS_TargetLevelEdit", f, "InputBoxTemplate")
    targetLevelEdit:SetWidth(42)
    targetLevelEdit:SetHeight(20)
    targetLevelEdit:SetPoint("LEFT", targetLevelLabel, "RIGHT", 12, 0)
    targetLevelEdit:SetAutoFocus(false)
    targetLevelEdit:SetText(self.db.sim.targetLevel)
    targetLevelEdit:SetScript("OnEnterPressed", function()
        CommitNumericBox(targetLevelEdit, "targetLevel", 60, 63, 63)
        targetLevelEdit:ClearFocus()
    end)
    targetLevelEdit:SetScript("OnEditFocusLost", function()
        CommitNumericBox(targetLevelEdit, "targetLevel", 60, 63, 63)
    end)
    self.targetLevelEdit = targetLevelEdit

    local targetCountLabel = MakeLabel(f, "Targets (1-3)", settingsX, topY - 54, "GameFontNormal")
    local targetCountEdit = CreateFrame("EditBox", "TWS_TargetCountEdit", f, "InputBoxTemplate")
    targetCountEdit:SetWidth(42)
    targetCountEdit:SetHeight(20)
    targetCountEdit:SetPoint("LEFT", targetCountLabel, "RIGHT", 12, 0)
    targetCountEdit:SetAutoFocus(false)
    targetCountEdit:SetText(self.db.sim.targetCount)
    targetCountEdit:SetScript("OnEnterPressed", function()
        CommitNumericBox(targetCountEdit, "targetCount", 1, 3, 1)
        targetCountEdit:ClearFocus()
    end)
    targetCountEdit:SetScript("OnEditFocusLost", function()
        CommitNumericBox(targetCountEdit, "targetCount", 1, 3, 1)
    end)
    self.targetCountEdit = targetCountEdit

    local simCountLabel = MakeLabel(f, "Sims", settingsX, topY - 82, "GameFontNormal")
    local simCountEdit = CreateFrame("EditBox", "TWS_SimCountEdit", f, "InputBoxTemplate")
    simCountEdit:SetWidth(58)
    simCountEdit:SetHeight(20)
    simCountEdit:SetPoint("LEFT", simCountLabel, "RIGHT", 12, 0)
    simCountEdit:SetAutoFocus(false)
    simCountEdit:SetText(self.db.sim.sims)
    simCountEdit:SetScript("OnEnterPressed", function()
        CommitNumericBox(simCountEdit, "sims", 1, 5000, 500)
        simCountEdit:ClearFocus()
    end)
    simCountEdit:SetScript("OnEditFocusLost", function()
        CommitNumericBox(simCountEdit, "sims", 1, 5000, 500)
    end)
    self.simCountEdit = simCountEdit

    local slamMainCdLabel = MakeLabel(f, "Slam Main CD", settingsX, topY - 110, "GameFontNormal")
    local slamMainCdEdit = CreateFrame("EditBox", "TWS_SlamMainCdEdit", f, "InputBoxTemplate")
    slamMainCdEdit:SetWidth(42)
    slamMainCdEdit:SetHeight(20)
    slamMainCdEdit:SetPoint("LEFT", slamMainCdLabel, "RIGHT", 12, 0)
    slamMainCdEdit:SetAutoFocus(false)
    slamMainCdEdit:SetText(self.db.sim.slamMainCd)
    slamMainCdEdit:SetScript("OnEnterPressed", function()
        CommitNumericBox(slamMainCdEdit, "slamMainCd", 0, 5, 0)
        slamMainCdEdit:ClearFocus()
    end)
    slamMainCdEdit:SetScript("OnEditFocusLost", function()
        CommitNumericBox(slamMainCdEdit, "slamMainCd", 0, 5, 0)
    end)
    self.slamMainCdEdit = slamMainCdEdit

    local abilities = {
        { key = "bloodthirst", label = "Bloodthirst", icon = "Interface\\Icons\\Spell_Nature_BloodLust" },
        { key = "mortalstrike", label = "Mortal Strike", icon = "Interface\\Icons\\Ability_Warrior_SavageBlow" },
        { key = "sweepingstrikes", label = "Sweeping Strikes", icon = "Interface\\Icons\\Ability_Rogue_SliceDice" },
        { key = "whirlwind", label = "Whirlwind", icon = "Interface\\Icons\\Ability_Whirlwind" },
        { key = "execute", label = "Execute", icon = "Interface\\Icons\\INV_Sword_48" },
        { key = "heroicstrike", label = "Heroic Strike", icon = "Interface\\Icons\\Ability_Rogue_Ambush" },
        { key = "cleave", label = "Cleave", icon = "Interface\\Icons\\Ability_Warrior_Cleave" },
        { key = "hamstring", label = "Hamstring", icon = "Interface\\Icons\\Ability_ShockWave" },
        { key = "pummel", label = "Pummel", icon = "Interface\\Icons\\INV_Gauntlets_04" },
        { key = "slam", label = "Slam", icon = "Interface\\Icons\\Ability_Warrior_DecisiveStrike" },
    }

    f.abilityButtons = {}

    local i
    for i = 1, table.getn(abilities) do
        local entry = abilities[i]
        local btn = MakeIconToggle(
            f,
            abilitiesX,
            topY - 24 - ((i - 1) * 26),
            entry.label,
            entry.icon,
            self.db.sim.abilities[entry.key],
            function(v) TWS.db.sim.abilities[entry.key] = v end
        )
        f.abilityButtons[entry.key] = btn
    end

    local debuffs = {
        { key = "useSunder", label = "Sunder Armor", icon = "Interface\\Icons\\Ability_Warrior_Sunder" },
        { key = "useFaerieFire", label = "Faerie Fire", icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
        { key = "useCurseOfRecklessness", label = "Curse of Recklessness", icon = "Interface\\Icons\\Spell_Shadow_UnholyStrength" },
        { key = "useExposeArmor", label = "Expose Armor", icon = "Interface\\Icons\\Ability_Warrior_Riposte" },
        { key = "useHomunculi", label = "Homunculi", icon = "Interface\\Icons\\Spell_Shadow_CarrionSwarm" },
    }

    for i = 1, table.getn(debuffs) do
        local entry = debuffs[i]
        MakeIconToggle(
            f,
            debuffsX,
            topY - 24 - ((i - 1) * 26),
            entry.label,
            entry.icon,
            self.db.sim[entry.key],
            function(v) TWS.db.sim[entry.key] = v end
        )
    end
    f.raidBuffsButton = MakeIconToggle(
        f,
        debuffsX,
        topY - 50 - (table.getn(debuffs) * 26),
        "Raid Buffs",
        "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        self.db.sim.useRaidBuffs,
        function(v) TWS.db.sim.useRaidBuffs = v end
    )

    f.dwEnrageButton = MakeIconToggle(
        f,
        debuffsX,
        topY - 76 - (table.getn(debuffs) * 26),
        "DW+enrage",
        "Interface\\Icons\\Spell_Shadow_DeathPact",
        self.db.sim.useDWEnrage,
        function(v) TWS.db.sim.useDWEnrage = v end
    )

    f.flurryBuffButton = MakeIconToggle(
        f,
        debuffsX,
        topY - 102 - (table.getn(debuffs) * 26),
        "Flurry",
        "Interface\\Icons\\Ability_GhoulFrenzy",
        self.db.sim.useFlurryBuff,
        function(v) TWS.db.sim.useFlurryBuff = v end
    )

    f.theomodeButton = MakeIconToggle(
        f,
        debuffsX,
        topY - 128 - (table.getn(debuffs) * 26),
        "Theomode",
        "Interface\\Icons\\Temp",
        self.db.sim.useTheomodeHaste,
        function(v) TWS.db.sim.useTheomodeHaste = v end
    )

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(0.35, 0.35, 0.35, 0.8)
    divider:SetHeight(1)
    divider:SetWidth(width - 30)
    divider:SetPoint("TOP", f, "TOP", 0, -360)

    local avgLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    avgLabel:SetPoint("TOP", divider, "BOTTOM", 0, -26)
    avgLabel:SetText("Average DPS")

    local avgValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    avgValue:SetPoint("TOP", avgLabel, "BOTTOM", 0, -8)
    avgValue:SetText("0.0")

    local minmaxValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minmaxValue:SetPoint("TOP", avgValue, "BOTTOM", 0, -6)
    minmaxValue:SetText("Min / Max: 0.0 / 0.0")

    local weaponInfoValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    weaponInfoValue:SetPoint("TOP", minmaxValue, "BOTTOM", 0, -8)
    weaponInfoValue:SetWidth(250)
    weaponInfoValue:SetJustifyH("CENTER")
    weaponInfoValue:SetJustifyV("TOP")
    weaponInfoValue:SetText("")

    local leftResults = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    leftResults:SetPoint("TOPRIGHT", avgValue, "TOPLEFT", 20, 40)
    leftResults:SetWidth(170)
    leftResults:SetJustifyH("LEFT")
    leftResults:SetJustifyV("TOP")
    leftResults:SetText("")

    local rightResults = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rightResults:SetPoint("TOPLEFT", avgValue, "TOPRIGHT", 60, 50)
    rightResults:SetWidth(190)
    rightResults:SetJustifyH("LEFT")
    rightResults:SetJustifyV("TOP")
    rightResults:SetText("")

    f.avgValue = avgValue
    f.minmaxValue = minmaxValue
    f.weaponInfoValue = weaponInfoValue
    f.leftResults = leftResults
    f.rightResults = rightResults
    f:SetScript("OnShow", function() TWS:RefreshAbilityTalentGates() end)

    self.mainWindow = f
    self:RefreshAbilityTalentGates()
end

function TWS:UpdateResultsUI(snapshot, result)
    if not self.mainWindow then return end

    local breakdown = result.breakdown or {}

    if self.mainWindow.avgValue then
        self.mainWindow.avgValue:SetText(string.format("%.1f", result.avgDPS or 0))
    end

    if self.mainWindow.minmaxValue then
        self.mainWindow.minmaxValue:SetText(string.format("Min / Max: %.1f / %.1f", result.minDPS or 0, result.maxDPS or 0))
    end

    local leftText = ""
    leftText = leftText .. string.format("White DPS: %.1f\n", result.whiteDPS or 0)
    leftText = leftText .. string.format("Bloodthirst DPS: %.1f\n", breakdown.bloodthirst or 0)
    leftText = leftText .. string.format("Mortal Strike DPS: %.1f\n", breakdown.mortalstrike or 0)
    leftText = leftText .. string.format("Sweeping Strikes DPS: %.1f\n", breakdown.sweepingstrikes or 0)
    leftText = leftText .. string.format("Whirlwind DPS: %.1f\n", breakdown.whirlwind or 0)
    leftText = leftText .. string.format("Execute DPS: %.1f\n", breakdown.execute or 0)
    leftText = leftText .. string.format("Slam DPS: %.1f\n", breakdown.slam or 0)
    leftText = leftText .. string.format("Heroic Strike DPS: %.1f\n", breakdown.heroicstrike or 0)
    leftText = leftText .. string.format("Cleave DPS: %.1f\n", breakdown.cleave or 0)
    leftText = leftText .. string.format("Windfury DPS: %.1f", breakdown.windfury or 0)

    local slamCastDisplay = snapshot.stats and snapshot.stats.slamCastTime or 0
    if (not slamCastDisplay or slamCastDisplay <= 0) and snapshot.stats then
        local castSpeed = snapshot.stats.castSpeed or 1
        local impSlam = 0
        if snapshot.talents and snapshot.talents.ranks then
            impSlam = math.min(snapshot.talents.ranks.impslam or 0, 5)
        end
        local slamBaseCastTime = 2.5 - (impSlam * 0.25)
        if slamBaseCastTime < 0.5 then slamBaseCastTime = 0.5 end
        slamCastDisplay = slamBaseCastTime / castSpeed
    end

    local hasteMult = 1 + ((snapshot.stats and snapshot.stats.haste or 0) / 100)
    if hasteMult <= 0 then hasteMult = 1 end

    local mhDisplaySpeed = (snapshot.weapons.mh.speed or 0) / hasteMult
    local weaponText = string.format("MH: %s\n%.2f speed / %.0f-%.0f / skill %d", snapshot.weapons.mh.name or "None", mhDisplaySpeed or 0, snapshot.weapons.mh.min or 0, snapshot.weapons.mh.max or 0, snapshot.weapons.mh.skill or 0)

    if snapshot.weapons.oh.enabled == 1 then
        local ohDisplaySpeed = (snapshot.weapons.oh.speed or 0) / hasteMult
        weaponText = weaponText .. string.format("\nOH: %s\n%.2f speed / %.0f-%.0f / skill %d", snapshot.weapons.oh.name or "None", ohDisplaySpeed or 0, snapshot.weapons.oh.min or 0, snapshot.weapons.oh.max or 0, snapshot.weapons.oh.skill or 0)
    else
        weaponText = weaponText .. "\nOH: None"
    end

    local rightText = ""
    rightText = rightText .. string.format("Talents: %d/%d/%d\n", snapshot.talents.tab1 or 0, snapshot.talents.tab2 or 0, snapshot.talents.tab3 or 0)
    rightText = rightText .. string.format("Raid Buffs: %s\n", (snapshot.stats.raidBuffs == true or snapshot.stats.raidBuffs == 1) and "ON" or "OFF")
    rightText = rightText .. string.format("DW+enrage: %s\n", (snapshot.stats.dwEnrage == true or snapshot.stats.dwEnrage == 1) and "ON" or "OFF")
    rightText = rightText .. string.format("Flurry: %s\n", (snapshot.stats.flurryBuff == true or snapshot.stats.flurryBuff == 1) and "ON" or "OFF")
    rightText = rightText .. string.format("Theomode: %s\n", (snapshot.stats.theomode == true or snapshot.stats.theomode == 1) and "ON" or "OFF")
    rightText = rightText .. string.format("Windfury: %s\n", (snapshot.stats.windfury == true or snapshot.stats.windfury == 1) and "ON" or "OFF")
    rightText = rightText .. string.format("Crit: %d\n", snapshot.stats.crit or 0)
    rightText = rightText .. string.format("AP: %d\n", snapshot.stats.attackPower or 0)
    rightText = rightText .. string.format("Hit: %d\n", snapshot.stats.hit or 0)
    rightText = rightText .. string.format("Haste: %d\n", snapshot.stats.haste or 0)
    rightText = rightText .. string.format("Damage Mod: x%.2f\n", snapshot.stats.damageMultiplier or 1)
    rightText = rightText .. string.format("Slam Cast: %.2fs\n", slamCastDisplay or 0)
    rightText = rightText .. string.format("ArP: %d\n", snapshot.stats.armorPen or 0)
    rightText = rightText .. string.format("Armor After Debuffs: %d\n", result.targetArmor or 0)
    if self.mainWindow.leftResults then
        self.mainWindow.leftResults:SetText(leftText)
    end
    if self.mainWindow.rightResults then
        self.mainWindow.rightResults:SetText(rightText)
    end
    if self.mainWindow.weaponInfoValue then
        self.mainWindow.weaponInfoValue:SetText(weaponText)
    end
end


