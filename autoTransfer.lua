-- Auto Item Transfer Script
-- Periodically transfers items from a fixed source to a fixed destination
-- Load libraries
local request = require("lib.request")

local CONFIG_FILE = "autoTransfer.conf"
local SERVER_CHANNEL = 137 -- Server communication channel
local CLIENT_CHANNEL = os.getComputerID() + 5000 -- Unique client channel

-- Default configuration
local config = {
    source_inventory = "", -- Source inventory name (change to actual name)
    dest_inventory = "", -- Destination inventory name (change to actual name)
    transfer_interval = 60 -- Transfer interval in seconds
}

-- Load configuration from file
function loadConfig()
    if fs.exists(CONFIG_FILE) then
        local file = fs.open(CONFIG_FILE, "r")
        if file then
            local content = file.readAll()
            file.close()

            local loadedConfig = textutils.unserialise(content)
            if loadedConfig then
                -- Override existing config with loaded values
                for k, v in pairs(loadedConfig) do
                    config[k] = v
                end
                return true
            end
        end
    end
    return false
end

-- Save configuration to file
function saveConfig()
    local file = fs.open(CONFIG_FILE, "w")
    if file then
        file.write(textutils.serialise(config)) -- pretty print
        file.close()
        return true
    end
    return false
end

function logMessage(message)
    local currentTime = os.time("local")
    local formattedTime = textutils.formatTime(currentTime, true)
    print("[" .. formattedTime .. "] " .. message)
end

-- すべての面のレッドストーン状態を取得する関数
function getRedstoneStates()
    local states = {}
    for _, side in ipairs(redstone.getSides()) do
        states[side] = redstone.getInput(side)
    end
    return states
end

-- レッドストーン状態が変化したかチェックする関数（LOWからHIGHへの変化のみ）
function checkRedstoneRisingEdge(oldStates, newStates)
    for side, newState in pairs(newStates) do
        -- LOWからHIGHに変化した面があるか確認
        if not oldStates[side] and newState then
            return true, side
        end
    end
    return false, nil
end

-- Main process
function main()
    -- Load configuration
    local configLoaded = loadConfig()

    -- Check if config is missing or incomplete
    if not configLoaded or config.source_inventory == "" or config.dest_inventory == "" then
        logMessage("Configuration file missing or incomplete.")

        -- Save default configuration
        saveConfig()

        logMessage("Default configuration saved to " .. CONFIG_FILE)
        logMessage("Please edit this file to set source_inventory and dest_inventory.")
        logMessage("Run this program again after configuration is complete.")
        return
    end

    logMessage("Starting automatic transfer")
    logMessage("Source: " .. config.source_inventory)
    logMessage("Destination: " .. config.dest_inventory)
    logMessage("Transfer interval: " .. config.transfer_interval .. " seconds")
    logMessage("Press any key to launch the interactive client")
    logMessage("Redstone signal will trigger transfer")

    -- Initialize request library
    local success, message = request.init({
        serverChannel = config.server_channel,
        clientChannel = CLIENT_CHANNEL
    })

    if not success then
        logMessage("Error initializing communication: " .. message)
        return
    end

    logMessage(message)

    -- Record initial redstone states
    local lastRedstoneStates = getRedstoneStates()

    -- Main loop
    while true do
        local timer = os.startTimer(config.transfer_interval)
        logMessage("Waiting " .. config.transfer_interval .. " seconds until next transfer")
        logMessage("Press any key to launch the interactive client")

        -- Wait for events
        while true do
            local event, param = os.pullEvent()

            if event == "key" then
                -- Launch itemClient on key press
                logMessage("Key pressed, launching itemClient...")
                shell.run("./itemClient")
                logMessage("itemClient exited.")
            elseif event == "timer" and param == timer then
                -- Timer event: execute transfer
                logMessage("Timer triggered, starting transfer...")
                break
            elseif event == "redstone" then
                -- Detect redstone signal changes
                local currentStates = getRedstoneStates()
                local changed, side = checkRedstoneRisingEdge(lastRedstoneStates, currentStates)

                -- Execute if there's a rising edge
                if changed then
                    logMessage("Triggered redstone on " .. side .. ", starting transfer...")
                    break
                end

                -- Update states
                lastRedstoneStates = currentStates
            end
        end

        logMessage("Starting transfer cycle...")

        -- Transfer all items
        local transferResponse = request.transferAllItems(config.source_inventory, config.dest_inventory)

        if transferResponse.success then
            logMessage("Transfer completed successfully")
        else
            logMessage("Error occurred during transfer: " .. transferResponse.message)
        end
    end
end

-- Run the program
main()
