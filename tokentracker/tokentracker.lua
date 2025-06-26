-- TokenTracker - A World of Warcraft AddOn to track gold earned for a WoW Token.
-- Author: Allyny747
-- Version: 0.1
-- Interface: 110107 (The War Within)
-- SavedVariables: TokenTrackerData
-- Loads: TokenTrackerUI.xml

TokenTracker = {}
TokenTrackerData = TokenTrackerData or {}

-- Initialize SavedVariables fields with default values if they are missing.
if TokenTrackerData.sessionStartGold == nil then TokenTrackerData.sessionStartGold = 0 end
if TokenTrackerData.totalEarnedSinceStart == nil then TokenTrackerData.totalEarnedSinceStart = 0 end
if TokenTrackerData.isTrackingActive == nil then TokenTrackerData.isTrackingActive = false end
if TokenTrackerData.lastKnownGold == nil then TokenTrackerData.lastKnownGold = 0 end
if TokenTrackerData.targetPrice == nil then TokenTrackerData.targetPrice = 0 end
-- TokenTrackerData.framePosition is no longer needed as frame position is not saved
if TokenTrackerData.frameVisible == nil then TokenTrackerData.frameVisible = true end

-- UI Element References
local mainFrame
local statusText
local goldEarnedText
local targetText
local progressText
local startButton
local stopButton

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
    if not mainFrame then
        PrintMessage("DEBUG: UI not ready in UpdateUI()")
        return
    end

    local earnedText = "Earned: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart, false)
    local targetDisplay = "Target: " .. FormatGold(TokenTrackerData.targetPrice, false)

    PrintMessage("DEBUG: UpdateUI - " .. earnedText .. " | " .. targetDisplay)

    goldEarnedText:SetText(" ")  -- Force redraw
    goldEarnedText:SetText(earnedText)
    targetText:SetText(targetDisplay)

    if TokenTrackerData.isTrackingActive then
        statusText:SetText("Status: Active")
        statusText:SetTextColor(0, 1, 0)
        startButton:Disable()
        stopButton:Enable()
    else
        statusText:SetText("Status: Inactive")
        statusText:SetTextColor(1, 0, 0)
        startButton:Enable()
        stopButton:Disable()
    end

    if TokenTrackerData.targetPrice > 0 then
        local remainingGold = TokenTrackerData.targetPrice - TokenTrackerData.totalEarnedSinceStart
        if remainingGold < 0 then remainingGold = 0 end
        progressText:SetText("Progress: Remaining " .. FormatGold(remainingGold, false))
    else
        progressText:SetText("Progress: N/A (Set target with /tt target)")
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

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, addonName, ...)
    if event == "ADDON_LOADED" and addonName == "TokenTracker" then
        -- Wait for PLAYER_LOGIN to initialize UI fully
        PrintMessage("Addon loaded, waiting for PLAYER_LOGIN to initialize UI.")

    elseif event == "PLAYER_LOGIN" then
        -- Assign UI elements now, after UI is loaded
        mainFrame = TokenTrackerFrame
        statusText = TokenTrackerStatusText
        goldEarnedText = TokenTrackerGoldEarnedText
        targetText = TokenTrackerTargetText
        progressText = TokenTrackerProgressText
        startButton = TokenTrackerStartButton
        stopButton = TokenTrackerStopButton

        if mainFrame and goldEarnedText then
            PrintMessage("DEBUG: UI elements assigned at PLAYER_LOGIN.")
        else
            PrintMessage("DEBUG: ERROR - UI elements NOT found at PLAYER_LOGIN.")
        end

        mainFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        mainFrame:SetBackdropColor(0, 0, 0, 0.8)
        mainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

        startButton:SetScript("OnClick", TokenTracker.StartFarming)
        stopButton:SetScript("OnClick", TokenTracker.StopFarming)

        mainFrame:SetScript("OnHide", function() TokenTrackerData.frameVisible = false end)
        mainFrame:SetScript("OnShow", function() TokenTrackerData.frameVisible = true end)
        -- The OnStopMovingOrSizing script is removed as per your request,
        -- as you do not need to save the frame's position across reloads.
        -- If you decide to add position saving back, you'll need to re-add this script.

        if TokenTrackerData.frameVisible then mainFrame:Show() else mainFrame:Hide() end

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
SLASH_TOKENTRACKER2 = "/tokentracker"

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
        if mainFrame then mainFrame:Show() end
    elseif command == "hide" then
        if mainFrame then mainFrame:Hide() end
    elseif command == "help" then
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

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(self, event, msg, ...)
    if string.find(msg, "/tt", 1, true) or string.find(msg, "/tokentracker", 1, true) then
        return true
    end
    return false
end)