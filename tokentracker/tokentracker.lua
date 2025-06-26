-- TokenTracker - A World of Warcraft AddOn to track gold earned for a WoW Token.
-- Author: Allyny747
-- Version: 0.1
-- Interface: 110107 (The War Within)
-- SavedVariables: TokenTrackerData
-- Loads: TokenTrackerUI.xml

TokenTracker = {}
TokenTrackerData = TokenTrackerData or {}

-- Initialize SavedVariables fields
if TokenTrackerData.sessionStartGold == nil then TokenTrackerData.sessionStartGold = 0 end
if TokenTrackerData.totalEarnedSinceStart == nil then TokenTrackerData.totalEarnedSinceStart = 0 end
if TokenTrackerData.isTrackingActive == nil then TokenTrackerData.isTrackingActive = false end
if TokenTrackerData.lastKnownGold == nil then TokenTrackerData.lastKnownGold = 0 end
if TokenTrackerData.targetPrice == nil then TokenTrackerData.targetPrice = 0 end
if TokenTrackerData.framePosition == nil then TokenTrackerData.framePosition = { x = 0, y = 0 } end
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
local function FormatGold(copperAmount)
    local sign = ""
    if copperAmount < 0 then
        sign = "-"
        copperAmount = math.abs(copperAmount)
    end
    local gold = math.floor(copperAmount / 10000)
    local silver = math.floor((copperAmount % 10000) / 100)
    local copper = copperAmount % 100
    return sign .. string.format("|cffFFD700%d|r|cffC0C0C0%d|r|cffCD7F32%d|r", gold, silver, copper)
end

-- UI update function
local function UpdateUI()
    if not mainFrame then return end

    goldEarnedText:SetText("Earned: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
    targetText:SetText("Target: " .. FormatGold(TokenTrackerData.targetPrice))

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
        progressText:SetText("Progress: Remaining " .. FormatGold(remainingGold))
    else
        progressText:SetText("Progress: N/A (Set target with /tt target)")
    end
end

-- TokenTracker core functions
function TokenTracker.StartFarming()
    if TokenTrackerData.isTrackingActive then
        PrintMessage("Farming session is already active!")
    else
        TokenTrackerData.sessionStartGold = GetMoney()
        TokenTrackerData.totalEarnedSinceStart = 0
        TokenTrackerData.isTrackingActive = true
        PrintMessage("Farming session started! Current gold: " .. FormatGold(TokenTrackerData.sessionStartGold))
    end
    UpdateUI()
end

function TokenTracker.StopFarming()
    if not TokenTrackerData.isTrackingActive then
        PrintMessage("Farming session is not active.")
    else
        TokenTrackerData.isTrackingActive = false
        PrintMessage("Farming session stopped.")
        PrintMessage("Total gold tracked for this session: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
    end
    UpdateUI()
end

-- Event handling frame
local eventFrame = CreateFrame("Frame")

-- Main OnEvent handler
eventFrame:SetScript("OnEvent", function(self, event, addonName, ...)
    if event == "ADDON_LOADED" and addonName == "TokenTracker" then
        mainFrame = TokenTrackerFrame
        statusText = TokenTrackerStatusText
        goldEarnedText = TokenTrackerGoldEarnedText
        targetText = TokenTrackerTargetText
        progressText = TokenTrackerProgressText
        startButton = TokenTrackerStartButton
        stopButton = TokenTrackerStopButton

        -- Set backdrop programmatically
        mainFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        mainFrame:SetBackdropColor(0, 0, 0, 0.8)
        mainFrame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

        -- Set button click handlers
        startButton:SetScript("OnClick", TokenTracker.StartFarming)
        stopButton:SetScript("OnClick", TokenTracker.StopFarming)

        -- Set scripts for frame visibility and movement to save state
        mainFrame:SetScript("OnHide", function() TokenTrackerData.frameVisible = false end)
        mainFrame:SetScript("OnShow", function() TokenTrackerData.frameVisible = true end)
        mainFrame:SetScript("OnStopMovingOrSizing", function()
            local _, _, _, x, y = mainFrame:GetPoint("CENTER", UIParent)
            TokenTrackerData.framePosition.x = x
            TokenTrackerData.framePosition.y = y
        end)

        -- Apply saved position
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", TokenTrackerData.framePosition.x, TokenTrackerData.framePosition.y)

        -- Apply saved visibility
        if TokenTrackerData.frameVisible then
            mainFrame:Show()
        else
            mainFrame:Hide()
        end

        UpdateUI()
    elseif event == "PLAYER_LOGIN" then
        TokenTrackerData.lastKnownGold = GetMoney()
        PrintMessage("Addon loaded. Current character gold: " .. FormatGold(GetMoney()))

        if TokenTrackerData.isTrackingActive then
            PrintMessage("Farming session is currently active (persisted). Gold earned so far: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
        else
            PrintMessage("Farming session is currently inactive (persisted).")
        end

        if TokenTrackerData.targetPrice > 0 then
            PrintMessage("Target token price set to: " .. FormatGold(TokenTrackerData.targetPrice))
        end
        UpdateUI()
    elseif event == "PLAYER_MONEY" then
        local currentGold = GetMoney()
        local goldChange = currentGold - TokenTrackerData.lastKnownGold

        if goldChange ~= 0 then
            if TokenTrackerData.isTrackingActive then
                TokenTrackerData.totalEarnedSinceStart = TokenTrackerData.totalEarnedSinceStart + goldChange
            end
            TokenTrackerData.lastKnownGold = currentGold
            UpdateUI()
        end
    end
end)

-- Register events
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_MONEY")


-- Chat command handler
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
        PrintMessage("Current character gold: " .. FormatGold(GetMoney()))
        if TokenTrackerData.isTrackingActive then
            PrintMessage("Farming session is active. Gold earned so far: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
        else
            PrintMessage("Farming session is inactive. Last tracked amount: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
        end
    elseif command == "reset" then
        TokenTrackerData.sessionStartGold = GetMoney()
        TokenTrackerData.totalEarnedSinceStart = 0
        PrintMessage("Total tracked gold has been reset.")
        if TokenTrackerData.isTrackingActive then
            PrintMessage("Farming session remains active.")
        else
            PrintMessage("Farming session remains inactive.")
        end
        UpdateUI()
    elseif command == "target" then
        local valueStr = args[2]
        if valueStr then
            local newTarget = tonumber(valueStr)
            if newTarget and newTarget >= 0 then
                TokenTrackerData.targetPrice = newTarget * 10000
                PrintMessage("Target gold for token set to: " .. FormatGold(TokenTrackerData.targetPrice))
            else
                PrintMessage("Invalid target price. Please enter a positive number (e.g., '/tt target 10000').")
            -- Removed the problematic line here
            end
        else
            PrintMessage("Current target gold for token: " .. FormatGold(TokenTrackerData.targetPrice))
            PrintMessage("Usage: /tt target <gold_amount>")
        end
        UpdateUI()
    elseif command == "progress" then
        if TokenTrackerData.targetPrice > 0 then
            local remainingGold = TokenTrackerData.targetPrice - TokenTrackerData.totalEarnedSinceStart
            if remainingGold < 0 then remainingGold = 0 end
            PrintMessage("Progress towards target (" .. FormatGold(TokenTrackerData.targetPrice) .. "):")
            PrintMessage("Earned: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart) .. " | Remaining: " .. FormatGold(remainingGold))
        else
            PrintMessage("No target price set. Use '/tt target <gold_amount>' to set one.")
        end
    elseif command == "show" then
        if mainFrame then
            mainFrame:Show()
            PrintMessage("TokenTracker frame shown.")
        end
    elseif command == "hide" then
        if mainFrame then
            mainFrame:Hide()
            PrintMessage("TokenTracker frame hidden.")
        end
    elseif command == "help" then
        PrintMessage("Available commands:")
        PrintMessage("/tt or /tokentracker - Show current status.")
        PrintMessage("/tt start - Start a new farming session.")
        PrintMessage("/tt stop - Stop the current farming session.")
        PrintMessage("/tt reset - Reset total tracked gold for the current session.")
        PrintMessage("/tt target <amount> - Set a gold target for the token (e.g., /tt target 200000).")
        PrintMessage("/tt progress - Show progress towards the set target.")
        PrintMessage("/tt show - Show the TokenTracker UI frame.")
        PrintMessage("/tt hide - Hide the TokenTracker UI frame.")
        PrintMessage("/tt help - Show this help message.")
    else
        PrintMessage("Unknown command. Type '/tt help' for a list of commands.")
    end
end

SlashCmdList["TOKENTRACKER"] = HandleSlashCommand

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(self, event, msg, ...)
    if string.find(msg, "/tt", 1, true) or string.find(msg, "/tokentracker", 1, true) then
        return true
    end
    return false
end)
