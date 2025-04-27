-- Inventory Scanner for ComputerCraft
-- Lists all inventories accessible via modem
-- Configuration
local REFRESH_INTERVAL = 3 -- Refresh interval in seconds

-- Function to clear the screen
function clearScreen()
    term.clear()
    term.setCursorPos(1, 1)
end

-- Function to get all peripherals
function getAllPeripherals()
    local peripheralList = {}
    local names = peripheral.getNames()

    for _, name in ipairs(names) do
        table.insert(peripheralList, {
            name = name,
            type = peripheral.getType(name)
        })
    end

    return peripheralList
end

-- Function to check if a peripheral is an inventory
function isInventory(peripheralName)
    local methods = peripheral.getMethods(peripheralName)

    -- Check for common inventory methods
    for _, method in ipairs(methods) do
        if method == "list" or method == "getItemDetail" or method == "size" then
            return true
        end
    end

    return false
end

-- Function to get inventory details
function getInventoryDetails(peripheralName)
    local inventory = peripheral.wrap(peripheralName)
    local details = {
        name = peripheralName,
        type = peripheral.getType(peripheralName),
        size = 0,
        items = 0,
        contents = {}
    }

    -- Try to get inventory size
    if inventory.size then
        details.size = inventory.size()
    end

    -- Try to get inventory contents
    if inventory.list then
        local contents = inventory.list()
        local itemCount = 0

        for slot, item in pairs(contents) do
            itemCount = itemCount + 1

            -- Get more details if possible
            if inventory.getItemDetail then
                local itemDetail = inventory.getItemDetail(slot)
                if itemDetail then
                    details.contents[slot] = {
                        name = itemDetail.name,
                        count = itemDetail.count,
                        displayName = itemDetail.displayName or itemDetail.name
                    }
                else
                    details.contents[slot] = {
                        name = "unknown",
                        count = item.count
                    }
                end
            else
                details.contents[slot] = {
                    name = "unknown",
                    count = item.count
                }
            end
        end

        details.items = itemCount
    end

    return details
end

-- Main function
function main()
    print("Scanning for inventories via modem...")

    -- Check if a modem is present
    local hasModem = false
    local peripherals = peripheral.getNames()

    for _, name in ipairs(peripherals) do
        if peripheral.getType(name) == "modem" then
            hasModem = true
            print("Found modem: " .. name)
            peripheral.call(name, "open", 1) -- Open channel 1 just in case
        end
    end

    if not hasModem then
        print("No modem found! Please attach a modem.")
        return
    end

    -- Main loop
    while true do
        clearScreen()
        print("Inventory Scanner")
        print("Press Ctrl+T to exit")
        print("-----------------------------")

        local peripherals = getAllPeripherals()
        local inventories = {}

        -- Find all inventories
        for _, peripheral in ipairs(peripherals) do
            if isInventory(peripheral.name) then
                table.insert(inventories, getInventoryDetails(peripheral.name))
            end
        end

        -- Display inventory information
        if #inventories == 0 then
            print("No inventories found!")
        else
            print("Found " .. #inventories .. " inventories:")
            print("")

            for i, inventory in ipairs(inventories) do
                print(i .. ". " .. inventory.name .. " (" .. inventory.type .. ")")
                print("   Size: " .. inventory.size .. " slots")
                print("   Items: " .. inventory.items .. " slots used")

                if inventory.items > 0 then
                    print("   Contents:")
                    local count = 0
                    for slot, item in pairs(inventory.contents) do
                        count = count + 1
                        if count <= 5 then -- Show only first 5 items to avoid clutter
                            print("     Slot " .. slot .. ": " .. item.displayName or item.name .. " x" .. item.count)
                        end
                    end

                    if count > 5 then
                        print("     ... and " .. (count - 5) .. " more items")
                    end
                end

                print("")
            end
        end

        -- print("Refreshing in " .. REFRESH_INTERVAL .. " seconds...")
        sleep(REFRESH_INTERVAL)
    end
end

-- Run the main function
main()
