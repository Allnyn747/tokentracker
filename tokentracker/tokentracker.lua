-- TokenTracker - A World of Warcraft AddOn to track gold earned for a WoW Token.
-- Author: YourName (Remember to update your name in tokentracker.toc)
-- Version: 0.1
-- Interface: 110107 (The War Within)
-- SavedVariables: TokenTrackerData (Declared in .toc file for persistent storage)

-- Define a global table for our add-on's data and functions to avoid polluting the global namespace.
TokenTracker = {}

-- Initialize TokenTrackerData. WoW automatically loads this table from SavedVariables.lua.
-- If this is the first time the addon runs (or after a SavedVariables reset),
-- TokenTrackerData will be nil, so we initialize it as an empty table.
TokenTrackerData = TokenTrackerData or {}

-- Ensure all necessary fields exist in TokenTrackerData,
-- providing default values if they are missing. This handles first-time use
-- or future updates where new variables are added.
if TokenTrackerData.sessionStartGold == nil then
    TokenTrackerData.sessionStartGold = 0          -- Gold amount when tracking officially "started"
end
if TokenTrackerData.totalEarnedSinceStart == nil then
    TokenTrackerData.totalEarnedSinceStart = 0      -- Total gold earned since the "Start Farming" command was last used
end
if TokenTrackerData.isTrackingActive == nil then
    TokenTrackerData.isTrackingActive = false       -- Is farming tracking currently active?
end
if TokenTrackerData.lastKnownGold == nil then
    TokenTrackerData.lastKnownGold = 0              -- Last recorded gold amount to calculate changes
end
if TokenTrackerData.targetPrice == nil then
    TokenTrackerData.targetPrice = 0                -- Target gold amount for the token (in copper)
end


-- Function to display messages in the chat frame.
local function PrintMessage(message)
    print("|cff00ff99[TokenTracker]|r " .. message) -- Green color for messages
end

-- Function to format copper into gold/silver/copper string with color codes.
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

-- Create a frame to register for events. All WoW events must be registered to a frame.
local eventFrame = CreateFrame("Frame")

-- Event handler for PLAYER_LOGIN. This is called when the player logs into the game world.
local function OnLogin(self, event, ...)
    -- Set the last known gold to the current gold when logging in.
    -- This ensures accurate calculation of gold changes after a game restart.
    TokenTrackerData.lastKnownGold = GetMoney()
    PrintMessage("Addon loaded. Current character gold: " .. FormatGold(GetMoney()))

    if TokenTrackerData.isTrackingActive then
        PrintMessage("Farming session is currently active (persisted). Gold earned so far: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
    else
        PrintMessage("Farming session is currently inactive (persisted).")
    end

    -- If a target price is set, display it on login.
    if TokenTrackerData.targetPrice > 0 then
        PrintMessage("Target token price set to: " .. FormatGold(TokenTrackerData.targetPrice))
    end
end

-- Event handler for PLAYER_MONEY. This event fires whenever player's money changes.
local function OnMoneyChanged(self, event, ...)
    local currentGold = GetMoney()
    local goldChange = currentGold - TokenTrackerData.lastKnownGold

    -- Only process if there's an actual change in gold.
    if goldChange ~= 0 then
        -- Only update the total earned if tracking is currently active.
        if TokenTrackerData.isTrackingActive then
            TokenTrackerData.totalEarnedSinceStart = TokenTrackerData.totalEarnedSinceStart + goldChange
            -- Optional: Uncomment the line below if you want real-time updates for every gold change.
            -- PrintMessage("Gold changed by: " .. FormatGold(goldChange) .. ". Total tracked: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
        end
        -- Always update lastKnownGold to ensure subsequent changes are calculated correctly.
        TokenTrackerData.lastKnownGold = currentGold
    end
end

-- Register events to our eventFrame.
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_MONEY")

-- Set the OnEvent script for the frame, routing events to specific handlers.
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnLogin(self, event, ...)
    elseif event == "PLAYER_MONEY" then
        OnMoneyChanged(self, event, ...)
    end
end)

-- Chat command handler.
-- We'll register slash commands that users can type in chat.
SLASH_TOKENTRACKER1 = "/tt"         -- Primary slash command
SLASH_TOKENTRACKER2 = "/tokentracker" -- Alternative slash command

local function HandleSlashCommand(msg, editbox)
    -- Split the command message into arguments.
    local args = { string.split(" ", msg) }
    local command = string.lower(args[1] or "") -- Get the first argument (command), convert to lowercase

    if command == "start" then
        if TokenTrackerData.isTrackingActive then
            PrintMessage("Farming session is already active!")
            PrintMessage("Gold earned so far this session: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
        else
            -- Record current gold as the starting point for this farming session.
            -- This ensures subsequent calculations are relative to this point.
            TokenTrackerData.sessionStartGold = GetMoney()
            TokenTrackerData.totalEarnedSinceStart = 0 -- Reset total earned for the new session
            TokenTrackerData.isTrackingActive = true
            PrintMessage("Farming session started! Current gold: " .. FormatGold(TokenTrackerData.sessionStartGold))
        end
    elseif command == "stop" then
        if not TokenTrackerData.isTrackingActive then
            PrintMessage("Farming session is not active.")
        else
            TokenTrackerData.isTrackingActive = false
            PrintMessage("Farming session stopped.")
            PrintMessage("Total gold tracked for this session: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
        end
    elseif command == "status" or command == "" then
        -- Display current character gold and session tracking status.
        PrintMessage("Current character gold: " .. FormatGold(GetMoney()))
        if TokenTrackerData.isTrackingActive then
            PrintMessage("Farming session is active. Gold earned so far: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
        else
            PrintMessage("Farming session is inactive. Last tracked amount: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart))
        end
    elseif command == "reset" then
        -- This command resets the *accumulated* gold for the current (or next) farming session.
        -- It does NOT stop an active session; it just zeroes out the tracked amount.
        TokenTrackerData.sessionStartGold = GetMoney() -- Reset start gold to current for a new baseline
        TokenTrackerData.totalEarnedSinceStart = 0
        PrintMessage("Total tracked gold has been reset.")
        if TokenTrackerData.isTrackingActive then
            PrintMessage("Farming session remains active.")
        else
            PrintMessage("Farming session remains inactive.")
        end
    elseif command == "target" then
        local valueStr = args[2] -- Get the second argument (the target amount)
        if valueStr then
            local newTarget = tonumber(valueStr) -- Convert string to number
            if newTarget and newTarget >= 0 then
                TokenTrackerData.targetPrice = newTarget * 10000 -- Store target in copper (1 gold = 10000 copper)
                PrintMessage("Target gold for token set to: " .. FormatGold(TokenTrackerData.targetPrice))
            else
                PrintMessage("Invalid target price. Please enter a positive number (e.g., '/tt target 10000').")
            end
        else
            -- If no argument provided, show current target.
            PrintMessage("Current target gold for token: " .. FormatGold(TokenTrackerData.targetPrice))
            PrintMessage("Usage: /tt target <gold_amount>")
        end
    elseif command == "progress" then
        -- Show progress towards the set target.
        if TokenTrackerData.targetPrice > 0 then
            local remainingGold = TokenTrackerData.targetPrice - TokenTrackerData.totalEarnedSinceStart
            if remainingGold < 0 then remainingGold = 0 end -- Ensure remaining isn't negative for display
            PrintMessage("Progress towards target (" .. FormatGold(TokenTrackerData.targetPrice) .. "):")
            PrintMessage("Earned: " .. FormatGold(TokenTrackerData.totalEarnedSinceStart) .. " | Remaining: " .. FormatGold(remainingGold))
        else
            PrintMessage("No target price set. Use '/tt target <gold_amount>' to set one.")
        end
    elseif command == "help" then
        -- Display all available commands.
        PrintMessage("Available commands:")
        PrintMessage("/tt or /tokentracker - Show current status.")
        PrintMessage("/tt start - Start a new farming session.")
        PrintMessage("/tt stop - Stop the current farming session.")
        PrintMessage("/tt reset - Reset total tracked gold for the current session.")
        PrintMessage("/tt target <amount> - Set a gold target for the token (e.g., /tt target 200000).")
        PrintMessage("/tt progress - Show progress towards the set target.")
        PrintMessage("/tt help - Show this help message.")
    else
        PrintMessage("Unknown command. Type '/tt help' for a list of commands.")
    end
end

-- Register the slash command handler with WoW.
SlashCmdList["TOKENTRACKER"] = HandleSlashCommand

-- Filter out WoW's default "unknown command" messages when our addon handles them.
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(self, event, msg, ...)
    -- Check if the message contains our slash commands.
    if string.find(msg, "/tt", 1, true) or string.find(msg, "/tokentracker", 1, true) then
        return true -- Return true to "eat" the message and prevent it from being displayed by WoW.
    end
    return false -- Return false to allow other messages to be displayed normally.
end)