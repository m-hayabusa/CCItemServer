-- Inventory Scanner for ComputerCraft
-- Lists all inventories accessible via modem
-- Configuration
local REFRESH_INTERVAL = 3 -- Refresh interval in seconds
local VIEW_MODE = "list" -- "list" or "transfer"
local selectedSourceIndex = nil
local selectedDestIndex = nil

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

function transferItems(sourceInventory, destInventory, sourceSlot, count)
    -- 名前が正しい形式かチェック（末尾のコロンを削除）
    local sourceName = sourceInventory.name:gsub(":$", "")
    local destName = destInventory.name:gsub(":$", "")

    -- ペリフェラルが存在するか確認
    local source = peripheral.wrap(sourceName)
    local dest = peripheral.wrap(destName)

    -- 両方のペリフェラルが有効かチェック
    if not source then
        return false, "Source peripheral not found: " .. sourceName
    end

    if not dest then
        return false, "Destination peripheral not found: " .. destName
    end

    local success, transferred = pcall(source.pushItems, destName, sourceSlot, count)

    if success and transferred > 0 then
        return true, "Transferred " .. transferred .. " items"
    else
        return false, "Failed to transfer items"
    end
end

function showAvailableInventories(inventories)
    print("Available inventories:")
    for i, inventory in ipairs(inventories) do
        print(i .. ". " .. inventory.name .. " (" .. inventory.type .. ")")
    end
end

-- Function to display transfer interface
function showTransferInterface(inventories)
    clearScreen()
    print("Item Transfer Interface")
    print("-----------------------------")

    -- Display source selection
    print("Source Inventory: " .. (selectedSourceIndex and inventories[selectedSourceIndex].name or "Not selected"))
    print("Destination Inventory: " .. (selectedDestIndex and inventories[selectedDestIndex].name or "Not selected"))
    print("")

    -- If both source and destination are selected
    if selectedSourceIndex and selectedDestIndex then
        local sourceInv = inventories[selectedSourceIndex]
        local destInv = inventories[selectedDestIndex]

        print("Source Contents:")
        if sourceInv.items > 0 then
            local count = 0
            for slot, item in pairs(sourceInv.contents) do
                count = count + 1
                print(count .. ". " .. (item.displayName or item.name) .. " x" .. item.count)
                if count >= 9 then
                    break
                end -- Limit display to 9 items for keyboard selection
            end

            print("\nEnter slot number to transfer, or 'a' to transfer all items, or 'q' to quit:")
        else
            print("Source inventory is empty")
            sleep(2)
            selectedSourceIndex = nil
            selectedDestIndex = nil
            showTransferInterface(inventories)
        end
    else
        showAvailableInventories(inventories)
    end
end

-- Function to handle user input for transfer
function handleTransferInput(inventories)

    -- If both source and destination are selected, handle item transfer
    if selectedSourceIndex and selectedDestIndex then
        write("> ")
        local input = read()

        local sourceInv = inventories[selectedSourceIndex]

        if input == "" or input == "q" then
            selectedSourceIndex = nil
            selectedDestIndex = nil
            VIEW_MODE = "list"
            return
        end

        -- 'a' key to transfer all items
        if input == "a" or input == "all" then
            print("\nTransferring all items...")
            local transferCount = 0

            for slot, item in pairs(sourceInv.contents) do
                local success, message = transferItems(sourceInv, inventories[selectedDestIndex], slot, item.count)
                if success then
                    transferCount = transferCount + 1
                    print(message)
                end
            end

            print("Transferred items from " .. transferCount .. " slots")
            sleep(2) -- Pause to show results
            return
        end

        -- Number keys 1-9 to transfer specific items
        local numKey = tonumber(input)

        if numKey then
            -- Find the nth item in the inventory
            local count = 0
            for slot, item in pairs(sourceInv.contents) do
                count = count + 1
                if count == numKey then
                    print("\nTransferring " .. (item.displayName or item.name) .. " x" .. item.count)
                    local success, message = transferItems(sourceInv, inventories[selectedDestIndex], slot, item.count)
                    print(message)
                    sleep(2) -- Pause to show results
                    break
                end
            end
        end
    else
        local target = selectedSourceIndex == nil and "source" or selectedDestIndex == nil and "destination" or nil
        if target then
            write("\nEnter " .. target .. " inventory number: ")
            local input = read()

            if input == "" or input == "q" then
                selectedSourceIndex = nil
                selectedDestIndex = nil
                VIEW_MODE = "list"
                return
            end

            local num = tonumber(input)
            if num and num >= 1 and num <= #inventories then
                if target == "source" then
                    selectedSourceIndex = num
                elseif target == "destination" then
                    selectedDestIndex = num
                end
            end
        end
    end
end

function redirectToMonitor()
    local monitor = peripheral.find("monitor")
    term.redirect(monitor)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setTextScale(0.5)
end

-- Main function
function main()
    -- redirectToMonitor()

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
        local peripherals = getAllPeripherals()
        local inventories = {}

        -- Find all inventories
        for _, peripheral in ipairs(peripherals) do
            if isInventory(peripheral.name) then
                table.insert(inventories, getInventoryDetails(peripheral.name))
            end
        end

        clearScreen()
        if VIEW_MODE == "list" then
            print("Inventory Scanner")
            print("Press Ctrl+T to exit, T to enter transfer mode")
            print("-----------------------------")

            -- Display inventory information
            if #inventories == 0 then
                print("No inventories found!")
            else
                print("Found " .. #inventories .. " inventories:")
                print("")

                for i, inventory in ipairs(inventories) do
                    print(i .. ". " .. inventory.name)

                    if inventory.items > 0 then
                        local count = 0
                        for slot, item in pairs(inventory.contents) do
                            count = count + 1
                            if count <= 5 then -- Show only first 5 items to avoid clutter
                                print("     #" .. slot .. ": \t" .. item.count .. " * " ..
                                          (item.displayName or item.name))
                            end
                        end

                        if count > 5 then
                            print("     ... and " .. (count - 5) .. " more items")
                        end
                    end

                    print("")
                end
            end
            -- Check for 'T' key press to switch to transfer mode
            local timer = os.startTimer(REFRESH_INTERVAL)
            while true do
                local event, param = os.pullEvent()
                if event == "timer" and param == timer then
                    break
                elseif event == "key" and param == keys.t then
                    VIEW_MODE = "transfer"
                    break
                end
            end
        elseif VIEW_MODE == "transfer" then
            showTransferInterface(inventories)
            handleTransferInput(inventories)
        end
    end
end

-- Run the main function
main()
