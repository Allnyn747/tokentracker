-- TokenTracker - A World of Warcraft AddOn to track gold earned for a WoW Token.
-- Author: YourName (Remember to update your name in tokentracker.toc)
-- Version: 0.1
-- Interface: 110107 (The War Within)

-- Define a global table for our add-on's data and functions to avoid polluting the global namespace.
-- This is a common practice in WoW add-on development.
TokenTracker = {}

-- Initialize variables to store our gold tracking data.
-- For a robust add-on that saves data across game sessions, you would use SavedVariables.
-- For this initial version, we'll use a simple global that resets when you reload UI or log out.
local goldEarnedSession = 0
local lastGoldAmount = 0 -- Stores the gold amount at the last update check

-- Function to display messages in the chat frame.
-- Using print() sends messages to the default chat frame.
local function PrintMessage(message)
    print("|cff00ff99[TokenTracker]|r " .. message) -- Green color for messages
end

-- Function to get the current total gold on the character.
-- GetMoney() returns the gold in copper. We convert it to gold/silver/copper format for display.
local function GetCurrentGoldFormatted()
    local money = GetMoney()
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    return string.format("|cffFFD700%d|r|cffC0C0C0%d|r|cffCD7F32%d|r", gold, silver, copper)
end

-- Event handler for player login.
-- This is where we'll initialize our tracking or load saved data.
local function OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Get the current gold when the player logs in.
        lastGoldAmount = GetMoney()
        PrintMessage("Tracking started. Current gold: " .. GetCurrentGoldFormatted())
    elseif event == "PLAYER_MONEY" then
        -- This event fires whenever player's money changes.
        local currentGold = GetMoney()
        local goldChange = currentGold - lastGoldAmount

        -- Only update if there's an actual change in gold.
        if goldChange ~= 0 then
            goldEarnedSession = goldEarnedSession + goldChange
            lastGoldAmount = currentGold -- Update lastGoldAmount for the next comparison
        end
    end
end

-- Create a frame to register for events.
-- All WoW events must be registered to a frame.
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")    -- Fires when the player logs into the game world
eventFrame:RegisterEvent("PLAYER_MONEY")    -- Fires when the player's money changes
eventFrame:SetScript("OnEvent", OnEvent)    -- Link the OnEvent function to the frame's OnEvent script handler

-- Chat command handler.
-- We'll register a slash command that users can type in chat.
SLASH_TOKENTRACKER1 = "/tt" -- Primary slash command
SLASH_TOKENTRACKER2 = "/tokentracker" -- Alternative slash command

local function HandleSlashCommand(msg, editbox)
    local command = string.lower(msg)

    if command == "total" or command == "" then
        -- Display the total gold earned this session.
        -- Convert copper to gold/silver/copper for display.
        local totalCopper = goldEarnedSession
        local sign = ""
        if totalCopper < 0 then
            sign = "-"
            totalCopper = math.abs(totalCopper)
        end
        local gold = math.floor(totalCopper / 10000)
        local silver = math.floor((totalCopper % 10000) / 100)
        local copper = totalCopper % 100
        PrintMessage(sign .. "Gold tracked this session: |cffFFD700" .. gold .. "|r|cffC0C0C0" .. silver .. "|r|cffCD7F32" .. copper .. "|r")
    elseif command == "reset" then
        -- Reset the gold earned for the session.
        goldEarnedSession = 0
        PrintMessage("Gold tracking for this session has been reset.")
        lastGoldAmount = GetMoney() -- Reset lastGoldAmount to current money after reset
    elseif command == "help" then
        PrintMessage("Available commands:")
        PrintMessage("/tt or /tokentracker - Show total gold tracked this session.")
        PrintMessage("/tt reset - Reset gold tracking for this session.")
        PrintMessage("/tt help - Show this help message.")
    else
        PrintMessage("Unknown command. Type '/tt help' for a list of commands.")
    end
end

-- Register the slash command.
-- This tells WoW to call our HandleSlashCommand function when /tt or /tokentracker is typed.
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(self, event, msg, ...)
    if string.find(msg, "/tt", 1, true) or string.find(msg, "/tokentracker", 1, true) then
        return true -- Filter out the default "unknown command" message if we handle it
    end
    return false
end)

SlashCmdList["TOKENTRACKER"] = HandleSlashCommand