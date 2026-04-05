TWS = TWS or {}
TWS.frame = CreateFrame("Frame", "TurtleWarriorSimFrameRoot")

function TWS:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99TWSim:|r " .. tostring(msg))
end

function TWS:RunSim()
    if type(self.BuildSnapshot) ~= "function" then
        self:Print("BuildSnapshot is missing. Snapshot.lua did not load.")
        return
    end
    if type(self.RunSimulation) ~= "function" then
        self:Print("RunSimulation is missing. SimEngine.lua did not load.")
        return
    end

    local ok, snapshot = pcall(function() return self:BuildSnapshot() end)
    if not ok then
        self:Print("BuildSnapshot error: " .. tostring(snapshot))
        return
    end

    if not snapshot then
        self:Print("Unable to build player snapshot.")
        return
    end

    local ok2, result = pcall(function() return self:RunSimulation(snapshot) end)
    if not ok2 then
        self:Print("RunSimulation error: " .. tostring(result))
        return
    end

    self.lastSnapshot = snapshot
    self.lastResult = result

    if self.UpdateResultsUI then
        self:UpdateResultsUI(snapshot, result)
    end
end

function TWS:SafeInit(funcName)
    if type(self[funcName]) ~= "function" then return end
    local ok, err = pcall(function() self[funcName](self) end)
    if not ok then
        self:Print(funcName .. " error: " .. tostring(err))
    end
end

function TWS:OnLogin()
    self:InitDB()

    SLASH_TURTLEWARRIORSIM1 = "/twsim"
    SLASH_TURTLEWARRIORSIM2 = "/warriorsim"
    SlashCmdList["TURTLEWARRIORSIM"] = function(msg)
        msg = string.lower(msg or "")
        if msg == "sim" then
            TWS:RunSim()
            return
        end

        if TWS.mainWindow and TWS.mainWindow:IsShown() then
            TWS.mainWindow:Hide()
        else
            if TWS.mainWindow then
                TWS.mainWindow:Show()
            end
        end
    end

    self:SafeInit("CreateMainWindow")
    self:SafeInit("CreatePaperDollButton")

    self:Print("Loaded. Use /twsim or the SIM button on the character sheet.")
end

TWS.frame:RegisterEvent("PLAYER_LOGIN")
TWS.frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        TWS:OnLogin()
    end
end)
