-- Auto Item Transfer Script
-- Periodically transfers items from a fixed source to a fixed destination
-- Load libraries
local request = require("lib.request")

-- Configuration
local SOURCE_INVENTORY = "minecraft:barrel_0" -- Source inventory name (change to actual name)
local DEST_INVENTORY = "minecraft:barrel_1" -- Destination inventory name (change to actual name)
local TRANSFER_INTERVAL = 60 -- Transfer interval in seconds
local SERVER_CHANNEL = 137 -- Server communication channel
local CLIENT_CHANNEL = os.getComputerID() + 5000 -- Unique client channel

function logMessage(message)
    local currentTime = os.time("local")
    local formattedTime = textutils.formatTime(currentTime, true)
    print("[" .. formattedTime .. "] " .. message)
end

-- Main process
function main()
    logMessage("Starting automatic transfer")
    logMessage("Source: " .. SOURCE_INVENTORY)
    logMessage("Destination: " .. DEST_INVENTORY)
    logMessage("Transfer interval: " .. TRANSFER_INTERVAL .. " seconds")

    -- Initialize request library
    local success, message = request.init({
        serverChannel = SERVER_CHANNEL,
        clientChannel = CLIENT_CHANNEL
    })

    if not success then
        logMessage("Error initializing communication: " .. message)
        return
    end

    logMessage(message)

    -- Main loop
    while true do
        logMessage("Starting transfer cycle...")

        -- Transfer all items
        local transferResponse = request.transferAllItems(SOURCE_INVENTORY, DEST_INVENTORY)

        if transferResponse.success then
            logMessage("Transfer completed successfully")
        else
            logMessage("Error occurred during transfer: " .. transferResponse.message)
        end

        logMessage("Waiting " .. TRANSFER_INTERVAL .. " seconds until next transfer")
        sleep(TRANSFER_INTERVAL)
    end
end

-- Run the program
main()
