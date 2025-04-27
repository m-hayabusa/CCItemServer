-- Auto Item Transfer Script
-- Periodically transfers items from a fixed source to a fixed destination
-- Load libraries
local inventoryUtils = require("lib.inventoryUtils")

-- Configuration
local SOURCE_INVENTORY = "minecraft:barrel_4" -- Source inventory name (change to actual name)
local DEST_INVENTORY = "minecraft:barrel_5" -- Destination inventory name (change to actual name)
local TRANSFER_INTERVAL = 60 -- Transfer interval in seconds
local LOG_FILE = "autoTransfer.log" -- Log file name

-- Logging function
function writeLog(message)
    local file = fs.open(LOG_FILE, "a")
    if file then
        file.writeLine("[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. message)
        file.close()
    end
    print(message)
end

-- Main process
function main()
    writeLog("Starting automatic transfer")
    writeLog("Source: " .. SOURCE_INVENTORY)
    writeLog("Destination: " .. DEST_INVENTORY)
    writeLog("Transfer interval: " .. TRANSFER_INTERVAL .. " seconds")

    -- Check for modem
    local hasModem = false
    local peripherals = peripheral.getNames()

    for _, name in ipairs(peripherals) do
        if peripheral.getType(name) == "modem" then
            hasModem = true
            writeLog("Detected modem: " .. name)
            peripheral.call(name, "open", 1) -- Open channel 1
        end
    end

    if not hasModem then
        writeLog("No modem found! Please connect a modem.")
        return
    end

    -- Main loop
    while true do
        writeLog("Starting transfer cycle...")

        -- Get inventory information (using library function)
        local sourceInv = inventoryUtils.getInventoryDetails(SOURCE_INVENTORY, true)
        local destInv = inventoryUtils.getInventoryDetails(DEST_INVENTORY, true)

        if sourceInv and destInv then
            -- Check item count
            if sourceInv.items > 0 then
                writeLog("Source has " .. sourceInv.items .. " items")

                -- Use library function to transfer all items
                local success = inventoryUtils.transferAllItems(sourceInv, destInv)

                if success then
                    writeLog("Transfer completed successfully")
                else
                    writeLog("Error occurred during transfer")
                end
            else
                writeLog("Source inventory is empty")
            end
        else
            writeLog("Failed to get inventory information")
        end

        writeLog("Waiting " .. TRANSFER_INTERVAL .. " seconds until next transfer")
        sleep(TRANSFER_INTERVAL)
    end
end

-- Run the program
main()
