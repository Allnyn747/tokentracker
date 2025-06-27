-- TokenTracker - A World of Warcraft AddOn to track gold earned for a WoW Token.
-- Author: Allnyn747
-- Version: 0.1
-- Interface: 110107 (The War Within)
-- SavedVariables: TokenTrackerData
-- Loads: TokenTrackerUI.xml

TokenTracker = TokenTracker or {} -- Changed for robustness: use existing table if it exists
TokenTrackerData = TokenTrackerData or {}

-- Initialize SavedVariables fields with default values if they are missing.
if TokenTrackerData.sessionStartGold == nil then TokenTrackerData.sessionStartGold = 0 end
if TokenTrackerData.totalEarnedSinceStart == nil then TokenTrackerData.totalEarnedSinceStart = 0 end
if TokenTrackerData.isTrackingActive == nil then TokenTrackerData.isTrackingActive = false end
if TokenTrackerData.lastKnownGold == nil then TokenTrackerData.lastKnownGold = 0 end
if TokenTrackerData.targetPrice == nil then TokenTrackerData.targetPrice = 0 end
if TokenTrackerData.frameVisible == nil then TokenTrackerData.frameVisible = true end
if TokenTrackerData.MinimapButtonPosition == nil then TokenTrackerData.MinimapButtonPosition = nil end

-- UI Element References (Now storing them directly in TokenTracker table for global access)
-- Removed local declarations as they are now properties of the global TokenTracker table
-- mainFrame, statusText, goldEarnedText, targetText, progressText, startButton, stopButton, minimapButton

-- Chat message function
local function PrintMessage(message)
    print("|cff00ff99[TokenTracker]|r " .. message)
end

-- Gold formatting function
local function FormatGold(copperAmount, useColor)
    local sign = ""
    if copperAmount < 0 then
        sign = "-"
        copperAmount = math.abs(copperAmount)
    end
    local gold = math.floor(copperAmount / 10000)
    local silver = math.floor((copperAmount % 10000) / 100)
    local copper = copperAmount % 100
    if useColor then
        return sign .. string.format("|cffFFD700%d|r|cffC0C0C0%02d|r|cffCD7F32%02d|r", gold, silver, copper)
    else
        return sign .. string.format("%dg %ds %dc", gold, silver, copper)
    end
end

-- Function to update UI
local function InternalUpdateUI()
    -- Use the references from the TokenTracker table
    if not TokenTracker.mainFrame or not TokenTracker.statusText or not TokenTracker.goldEarnedText or not TokenTracker.targetText or not TokenTracker.progressText then
        return
    end

    local earnedText = "Earned: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart, false)
    local targetDisplay = "Target: " .. FormatGold(TokenTrackerData.targetPrice, false)

    TokenTracker.goldEarnedText:SetText(earnedText)
    TokenTracker.targetText:SetText(targetDisplay)

    if TokenTrackerData.isTrackingActive then
        TokenTracker.statusText:SetText("Status: Active")
        TokenTracker.statusText:SetTextColor(0, 1, 0) -- Green
        TokenTracker.startButton:Disable()
        TokenTracker.stopButton:Enable()
    else
        TokenTracker.statusText:SetText("Status: Inactive")
        TokenTracker.statusText:SetTextColor(1, 0, 0) -- Red
        TokenTracker.startButton:Enable()
        TokenTracker.stopButton:Disable()
    end

    if TokenTrackerData.targetPrice > 0 then
        local remainingGold = TokenTrackerData.targetPrice - TokenTrackerData.totalEarnedSinceStart
        if remainingGold < 0 then remainingGold = 0 end
        TokenTracker.progressText:SetText("Progress: Remaining " .. FormatGold(remainingGold, false))
    else
        TokenTracker.progressText:SetText("Progress: N/A (Set target with /tt target)")
    end
end

-- Expose update function globally
TokenTracker.UpdateUI = InternalUpdateUI

-- Core functions
function TokenTracker.StartFarming()
    if TokenTrackerData.isTrackingActive then
        PrintMessage("Farming session is already active!")
    else
        TokenTrackerData.sessionStartGold = GetMoney()
        TokenTrackerData.totalEarnedSinceStart = 0
        TokenTrackerData.isTrackingActive = true
        PrintMessage("Farming session started! Current gold: " .. FormatGold(TokenTrackerData.sessionStartGold, true))
    end
    TokenTracker.UpdateUI()
end

function TokenTracker.StopFarming()
    if not TokenTrackerData.isTrackingActive then
        PrintMessage("Farming session is not active.")
    else
        TokenTrackerData.isTrackingActive = false
        PrintMessage("Farming session stopped.")
        PrintMessage("Total gold tracked for this session: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart, true))
    end
    TokenTracker.UpdateUI()
end

-- Minimap Button Global Functions

-- This function is called by the TokenTrackerMinimapButton's OnLoad handler in the XML.
-- It's crucial for initializing the button's behavior and setting its global reference.
function TokenTracker_MinimapButton_OnLoad(self)
    -- Assign the button reference to the TokenTracker table for global access
    TokenTracker.MinimapButtonFrame = self
    self:EnableMouse(true)
    self:SetMovable(true)
    self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self:RegisterForDrag("LeftButton")
    self:SetClampedToScreen(true)
    self:Show() -- ensures the button is visible
    self:SetAlpha(1) -- Added to ensure full opacity

    -- Set the icon texture here, as the button is now loaded
    local iconTexture = _G["TokenTrackerMinimapButtonIcon"] or self:GetNormalTexture()
    if iconTexture then
        iconTexture:SetTexture("Interface\\Icons\\WoW_Token01")
        iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        PrintMessage("DEBUG: Minimap button icon NOT found for setting texture.")
    end

    TokenTracker.LoadMinimapButtonPosition() -- Load saved position
end

-- This function is called by the TokenTrackerMinimapButton's OnClick handler in the XML.
function TokenTracker_MinimapButton_OnClick(self, button)
    if button == "LeftButton" then
        TokenTracker.ToggleMainFrame()
    elseif button == "RightButton" then
        TokenTracker.ShowOptions() -- This will now call the new function to show help
    end
end

-- NEW: This function is called by the TokenTrackerMinimapButton's OnDragStart handler in the XML.
function TokenTracker_MinimapButton_OnDragStart(self)
    self:SetScript("OnUpdate", TokenTracker_MinimapButton_OnUpdate)
end

-- NEW: This function handles smooth circular dragging around the minimap
function TokenTracker_MinimapButton_OnUpdate(self)
    local mx, my = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    mx, my = mx / scale, my / scale
    
    -- Get minimap center
    local mmx, mmy = Minimap:GetCenter()
    
    -- Calculate angle from minimap center to mouse
    local angle = math.atan2(my - mmy, mx - mmx)
    
    -- Set radius (distance from minimap center)
    local radius = 80 -- Adjust this value if needed
    
    -- Calculate new position
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    
    -- Update button position
    self:ClearAllPoints()
    self:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- UPDATED: This function is called by the TokenTrackerMinimapButton's OnDragStop handler in the XML.
function TokenTracker_MinimapButton_OnDragStop(self)
    -- Stop the OnUpdate script
    self:SetScript("OnUpdate", nil)
    
    -- Save the final position
    TokenTracker.SaveMinimapButtonPosition()
end

-- This function is called by the TokenTrackerMinimapButton's OnEnter handler in the XML.
function TokenTracker_MinimapButton_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Token Tracker", nil, nil, nil, nil, true)
    GameTooltip:AddLine("Left-click to toggle main frame", 1, 1, 1)
    GameTooltip:AddLine("Right-click for options", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

-- This function is called by the TokenTrackerMinimapButton's OnLeave handler in the XML.
function TokenTracker_MinimapButton_OnLeave(self)
    GameTooltip:Hide()
end

-- Other TokenTracker Functions

function TokenTracker.ToggleMainFrame()
    -- Use the reference from the TokenTracker table
    if TokenTracker.mainFrame then
        if TokenTracker.mainFrame:IsShown() then
            TokenTracker.mainFrame:Hide()
        else
            TokenTracker.mainFrame:Show()
        end
    else
        PrintMessage("DEBUG: Attempted to toggle mainFrame, but it's not assigned yet.")
    end
end

-- MODIFIED: This is the function that TokenTracker_MinimapButton_OnClick now calls for a right-click
function TokenTracker.ShowOptions()
    -- Clear existing text
    TokenTrackerHelpFrame.text:SetText("");

    -- Hardcode the commands you provided for reliable display
    local helpText = ""
    helpText = helpText .. "|cffffffff[TokenTracker]|r Available commands:\n"
    helpText = helpText .. "|cffffffff[TokenTracker]|r /tt start - Start a new session.\n"
    helpText = helpText .. "|cffffffff[TokenTracker]|r /tt stop - Stop the session.\n"
    helpText = helpText .. "|cffffffff[TokenTracker]|r /tt reset - Reset earned gold.\n"
    helpText = helpText .. "|cffffffff[TokenTracker]|r /tt target <amount> - Set goal.\n"
    helpText = helpText .. "|cffffffff[TokenTracker]|r /tt progress - Show progress.\n"
    helpText = helpText .. "|cffffffff[TokenTracker]|r /tt show | /tt hide - Toggle UI.\n"
    helpText = helpText .. "|cffffffff[TokenTracker]|r /tt help - Show this list."

    TokenTrackerHelpFrame.text:SetText(helpText);
    TokenTrackerHelpFrame:Show();
end
-- --- END OF NEW/MODIFIED CODE ---


-- UPDATED: Save minimap button position with circular positioning
function TokenTracker.SaveMinimapButtonPosition()
    if TokenTracker.MinimapButtonFrame then
        local point, relativeTo, relativePoint, x, y = TokenTracker.MinimapButtonFrame:GetPoint()
        local relativeToName = nil

        if relativeTo and relativeTo.GetName then
            relativeToName = relativeTo:GetName()
        end

        TokenTrackerData.MinimapButtonPosition = {
            point = point or "CENTER",
            relativeTo = relativeToName or "Minimap", 
            relativePoint = relativePoint or "CENTER",
            x = x or 80, 
            y = y or 0
        }
    end
end

-- UPDATED: Load minimap button position with circular positioning
function TokenTracker.LoadMinimapButtonPosition()
    if TokenTracker.MinimapButtonFrame then
        if TokenTrackerData.MinimapButtonPosition then
            local pos = TokenTrackerData.MinimapButtonPosition
            TokenTracker.MinimapButtonFrame:ClearAllPoints()
            -- Ensure we're positioning relative to Minimap
            local relativeTo = _G[pos.relativeTo] or Minimap
            TokenTracker.MinimapButtonFrame:SetPoint(pos.point, relativeTo, pos.relativePoint, pos.x, pos.y)
            PrintMessage("DEBUG: Minimap button position loaded: " .. pos.x .. ", " .. pos.y)
        else
            -- Default position on minimap edge
            TokenTracker.MinimapButtonFrame:SetPoint("CENTER", Minimap, "CENTER", 80, 0)
        end
    end
end

-- Event Handling & Slash Commands

-- Event frame for addon load and player money changes
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, addonName, ...)
    if event == "ADDON_LOADED" and addonName == "TokenTracker" then
    elseif event == "PLAYER_LOGIN" then
        -- Assign UI elements to the TokenTracker table for global access
        TokenTracker.mainFrame = TokenTrackerFrame
        TokenTracker.statusText = TokenTrackerStatusText
        TokenTracker.goldEarnedText = TokenTrackerGoldEarnedText
        TokenTracker.targetText = TokenTrackerTargetText
        TokenTracker.progressText = TokenTrackerProgressText
        TokenTracker.startButton = TokenTrackerStartButton
        TokenTracker.stopButton = TokenTrackerStopButton
        TokenTrackerHelpFrame.text = _G["TokenTrackerHelpFrameMainContentText"]
        -- TokenTracker.MinimapButtonFrame is assigned in its OnLoad, but we can double check here for safety
        if not TokenTracker.MinimapButtonFrame then
            TokenTracker.MinimapButtonFrame = TokenTrackerMinimapButton
            PrintMessage("DEBUG: Minimap button assigned at PLAYER_LOGIN (fallback).")
        end

        if TokenTracker.mainFrame and TokenTracker.goldEarnedText and TokenTracker.MinimapButtonFrame then
            -- No action needed here, just condition check
        else
            PrintMessage("DEBUG: ERROR - Some TokenTracker UI elements NOT found at PLAYER_LOGIN.")
        end

        -- Set backdrop for TokenTracker.mainFrame
        TokenTracker.mainFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        TokenTracker.mainFrame:SetBackdropColor(0, 0, 0, 0.8)
        TokenTracker.mainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

        -- ADDED: Set backdrop for TokenTrackerHelpFrame
        TokenTrackerHelpFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        TokenTrackerHelpFrame:SetBackdropColor(0, 0, 0, 0.8)
        TokenTrackerHelpFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)


        TokenTracker.startButton:SetScript("OnClick", TokenTracker.StartFarming)
        TokenTracker.stopButton:SetScript("OnClick", TokenTracker.StopFarming)

        TokenTracker.mainFrame:SetScript("OnHide", function() TokenTrackerData.frameVisible = false end)
        TokenTracker.mainFrame:SetScript("OnShow", function() TokenTrackerData.frameVisible = true end)
        if TokenTrackerData.frameVisible then TokenTracker.mainFrame:Show() else TokenTracker.mainFrame:Hide() end

        TokenTrackerData.lastKnownGold = GetMoney()
        PrintMessage("Addon ready. Current character gold: " .. FormatGold(GetMoney(), true))

        if TokenTrackerData.isTrackingActive then
            PrintMessage("Farming session is active. Gold earned so far: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart, true))
        else
            PrintMessage("Farming session is inactive.")
        end

        if TokenTrackerData.targetPrice > 0 then
            PrintMessage("Target token price set to: " .. FormatGold(TokenTrackerData.targetPrice, true))
        end

        TokenTracker.UpdateUI()

    elseif event == "PLAYER_MONEY" then
        local currentGold = GetMoney()
        local goldChange = currentGold - TokenTrackerData.lastKnownGold
        if goldChange ~= 0 then
            if TokenTrackerData.isTrackingActive then
                TokenTrackerData.totalEarnedSinceStart = TokenTrackerData.totalEarnedSinceStart + goldChange
            end
            TokenTrackerData.lastKnownGold = currentGold
            TokenTracker.UpdateUI()
        end
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_MONEY")

-- Slash commands
SLASH_TOKENTRACKER1 = "/tt"
SLASH_TOKENTRACKER2 = "/TokenTracker"

local function HandleSlashCommand(msg, editbox)
    local args = { string.split(" ", msg) }
    local command = string.lower(args[1] or "")

    if command == "start" then
        TokenTracker.StartFarming()
    elseif command == "stop" then
        TokenTracker.StopFarming()
    elseif command == "status" or command == "" then
        PrintMessage("Current character gold: " .. FormatGold(GetMoney(), true))
        if TokenTrackerData.isTrackingActive then
            PrintMessage("Farming session is active. Gold earned so far: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart, true))
        else
            PrintMessage("Farming session is inactive. Last tracked amount: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart, true))
        end
        TokenTracker.UpdateUI()
    elseif command == "reset" then
        TokenTrackerData.sessionStartGold = GetMoney()
        TokenTrackerData.totalEarnedSinceStart = 0
        PrintMessage("Total tracked gold has been reset.")
        TokenTracker.UpdateUI()
    elseif command == "target" then
        local valueStr = args[2]
        if valueStr then
            local newTarget = tonumber(valueStr)
            if newTarget and newTarget >= 0 then
                TokenTrackerData.targetPrice = newTarget * 10000
                PrintMessage("Target gold for token set to: " .. FormatGold(TokenTrackerData.targetPrice, true))
            else
                PrintMessage("Invalid target price. Use '/tt target 200000'")
            end
        else
            PrintMessage("Current target: " .. FormatGold(TokenTrackerData.targetPrice, true))
            PrintMessage("Usage: /tt target <gold_amount>")
        end
        TokenTracker.UpdateUI()
    elseif command == "progress" then
        if TokenTrackerData.targetPrice > 0 then
            local remainingGold = TokenTrackerData.targetPrice - TokenTrackerData.totalEarnedSinceStart
            if remainingGold < 0 then remainingGold = 0 end
            PrintMessage("Progress to target (" .. FormatGold(TokenTrackerData.targetPrice, true) .. "):")
            PrintMessage("Earned: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart, true) ..
                                         " | Remaining: " .. FormatGold(remainingGold, true))
        else
            PrintMessage("No target set. Use '/tt target <amount>'.")
        end
        TokenTracker.UpdateUI()
    elseif command == "show" then
        if TokenTracker.mainFrame then TokenTracker.mainFrame:Show() end
    elseif command == "hide" then
        if TokenTracker.mainFrame then TokenTracker.mainFrame:Hide() end
    elseif command == "help" then
        -- This is the slash command help, which you may want to keep
        PrintMessage("Available commands:")
        PrintMessage("/tt start - Start a new session.")
        PrintMessage("/tt stop - Stop the session.")
        PrintMessage("/tt reset - Reset earned gold.")
        PrintMessage("/tt target <amount> - Set goal.")
        PrintMessage("/tt progress - Show progress.")
        PrintMessage("/tt show | /tt hide - Toggle UI.")
        PrintMessage("/tt help - Show this list.")
    else
        PrintMessage("Unknown command. Try '/tt help'.")
    end
end

SlashCmdList["TOKENTRACKER"] = HandleSlashCommand

-- Filter chat messages to prevent slash commands from appearing in chat
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(self, event, msg, ...)
    if string.find(msg, "/tt", 1, true) or string.find(msg, "/TokenTracker", 1, true) then
        return true
    end
    return false
end)