TWS = TWS or {}

function TWS:CreatePaperDollButton()
    local parent = CharacterFrame
    if not parent then return end

    local b = CreateFrame("Button", "TurtleWarriorSimPaperDollButton", parent, "UIPanelButtonTemplate")
    b:SetWidth(60)
    b:SetHeight(22)
    b:SetText("SIM")
    b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, -32)
    b:SetScript("OnClick", function()
        if TWS.mainWindow then
            TWS.mainWindow:Show()
        end
        TWS:RunSim()
    end)

    self.paperDollButton = b
end
