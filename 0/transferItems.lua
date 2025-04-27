-- Inventory Scanner for ComputerCraft
-- Lists all inventories accessible via modem
-- Configuration
local REFRESH_INTERVAL = 3 -- Refresh interval in seconds
local VIEW_MODE = "inventories" -- "inventories" or "items"
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

-- Function to display transfer interface
function showTransferInterface(inventories)
    clearScreen()
    print("Item Transfer")
    print("-----------------------------")

    -- Display source selection
    print("From: " .. (selectedSourceIndex and inventories[selectedSourceIndex].name or "Not selected (L-Click)"))
    print("To:   " .. (selectedDestIndex and inventories[selectedDestIndex].name or "Not selected (R-Click)"))
    print("-----------------------------")

    -- If both source and destination are selected
    if selectedSourceIndex and selectedDestIndex then
        local sourceInv = inventories[selectedSourceIndex]
        local destInv = inventories[selectedDestIndex]

        print("Source Contents:")
        if sourceInv.items > 0 then
            local count = 0
            for slot, item in pairs(sourceInv.contents) do
                count = count + 1
                local x, y = term.getCursorPos()
                item.pos = {
                    head = y,
                    tail = y
                }
                print(" " .. count .. ". " .. (item.displayName or item.name) .. " *" .. item.count)
                if count >= 9 then
                    break
                end
            end

            VIEW_MODE = "items"

            print("\nEnter slot number to transfer, or 'a' to transfer all items, or 'q' to quit: ")
        else
            print("Source inventory is empty")
            sleep(1)
            selectedSourceIndex = nil
            selectedDestIndex = nil
            showTransferInterface(inventories)
        end
    else
        inventories = printInventories(inventories, 5)
    end

    return inventories
end

function redirectToMonitor()
    local monitor = peripheral.find("monitor")
    term.redirect(monitor)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setTextScale(0.5)
end

function printInventories(inventories, limit)
    for i, inventory in ipairs(inventories) do
        inventory.pos = {
            head = nil,
            tail = nil
        }
        x, y = term.getCursorPos()
        inventory.pos.head = y
        print(i .. ". " .. inventory.name)

        if inventory.items > 0 then
            local count = 0
            for slot, item in pairs(inventory.contents) do
                count = count + 1
                if limit and count <= limit then -- Show only first 5 items to avoid clutter
                    print("     #" .. count .. ": \t" .. item.count .. " * " .. (item.displayName or item.name))
                end
            end

            if limit and count > limit then
                print("     ... and " .. (count - limit) .. " more items")
            end
        end
        x, y = term.getCursorPos()
        inventory.pos.tail = y

        print("")
    end
    VIEW_MODE = "inventories"
    return inventories
end

-- Function to handle keyboard input for transfer
function handleKeyboardInput(inventories)
    -- If both source and destination are selected, handle item transfer
    if VIEW_MODE == "items" then
        write("> ")
        local input = read()

        local sourceInv = inventories[selectedSourceIndex]

        if input == "" or input == "q" then
            selectedSourceIndex = nil
            selectedDestIndex = nil
            VIEW_MODE = "inventories"
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
            sleep(2)
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
            write("\nEnter " .. target .. " number, or 'q' to quit\n> ")
            local input = read()

            if input == "" or input == "q" then
                selectedSourceIndex = nil
                selectedDestIndex = nil
                VIEW_MODE = "inventories"
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

-- Function to handle mouse clicks for inventory selection
function handleMouseClick(inventories, button, x, y)

    -- VIEW_MODEがinventoriesの場合（インベントリリスト表示時）
    if VIEW_MODE == "inventories" then
        -- インベントリリストの位置を特定
        for i, inventory in ipairs(inventories) do
            -- インベントリ名の行
            if inventory.pos.head <= y and y <= inventory.pos.tail then
                if button == 1 then -- 左クリック = source
                    selectedSourceIndex = i
                    print("Selected source: " .. inventory.name)
                    return true
                elseif button == 2 then -- 右クリック = destination
                    selectedDestIndex = i
                    print("Selected destination: " .. inventory.name)
                    return true
                end
            end
        end
        -- VIEW_MODEがitemsの場合（アイテムリスト表示時）
    elseif VIEW_MODE == "items" then
        -- 両方のインベントリが選択されている場合のみ
        if selectedSourceIndex and selectedDestIndex then
            local sourceInv = inventories[selectedSourceIndex]

            -- アイテムリストの位置を特定
            local count = 0
            for slot, item in pairs(sourceInv.contents) do
                count = count + 1

                -- アイテム行の位置を確認
                if item.pos and item.pos.head <= y and y <= item.pos.tail then
                    print("\nTransferring " .. (item.displayName or item.name) .. " x" .. item.count)
                    local success, message = transferItems(sourceInv, inventories[selectedDestIndex], slot, item.count)
                    print(message)
                    sleep(1) -- 結果表示のための短い待機
                    return true
                end

                -- 表示されている最大アイテム数を超えたら終了
                if count >= 9 then
                    break
                end
            end
        end
    end

    return false
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
        local peripherals = getAllPeripherals()
        local inventories = {}

        -- Find all inventories
        for _, peripheral in ipairs(peripherals) do
            if isInventory(peripheral.name) then
                table.insert(inventories, getInventoryDetails(peripheral.name))
            end
        end

        inventories = showTransferInterface(inventories)

        local timer = os.startTimer(REFRESH_INTERVAL)

        while true do
            local event, param, param2, param3 = os.pullEvent()
            if event == "timer" and param == timer then
                break
            elseif event == "key" then
                -- キーボードイベントの処理
                if param == keys.q then
                    -- Qキーでプログラム終了
                    print("Exiting program...")
                    return
                elseif param == keys.backspace or param == keys.escape then
                    -- BackspaceまたはEscキーで前の画面に戻る
                    if VIEW_MODE == "items" then
                        VIEW_MODE = "inventories"
                        selectedSourceIndex = nil
                        selectedDestIndex = nil
                    end
                    break
                elseif VIEW_MODE == "inventories" then
                    if param == keys.s then
                        -- Sキーで転送元選択モード
                        os.pullEvent("key_up") -- キーが離されるのを待つ
                        print("\nEnter source inventory number: ")
                        local input = read()
                        local num = tonumber(input)
                        if num and num >= 1 and num <= #inventories then
                            selectedSourceIndex = num
                            print("Selected source: " .. inventories[num].name)
                            sleep(1)
                        end
                        break
                    elseif param == keys.d then
                        -- Dキーで転送先選択モード
                        os.pullEvent("key_up") -- キーが離されるのを待つ
                        print("\nEnter destination inventory number: ")
                        local input = read()
                        local num = tonumber(input)
                        if num and num >= 1 and num <= #inventories then
                            selectedDestIndex = num
                            print("Selected destination: " .. inventories[num].name)
                            sleep(1)
                        end
                        break
                    elseif param >= keys.one and param <= keys.nine then
                        -- 数字キー1-9でインベントリを直接選択
                        local num = param - keys.one + 1
                        if num >= 1 and num <= #inventories then
                            if selectedSourceIndex == nil then
                                selectedSourceIndex = num
                                print("Selected source: " .. inventories[num].name)
                                sleep(1)
                            elseif selectedDestIndex == nil then
                                selectedDestIndex = num
                                print("Selected destination: " .. inventories[num].name)
                                sleep(1)
                            end

                            -- 両方選択されたらアイテム表示モードに切り替え
                            if selectedSourceIndex and selectedDestIndex then
                                VIEW_MODE = "items"
                            end
                            break
                        end
                    end
                elseif VIEW_MODE == "items" then
                    if param == keys.a then
                        -- Aキーですべてのアイテムを転送
                        local sourceInv = inventories[selectedSourceIndex]
                        print("\nTransferring all items...")
                        local transferCount = 0

                        for slot, item in pairs(sourceInv.contents) do
                            local success, message = transferItems(sourceInv, inventories[selectedDestIndex], slot,
                                item.count)
                            if success then
                                transferCount = transferCount + 1
                                print(message)
                            end
                        end

                        print("Transferred items from " .. transferCount .. " slots")
                        sleep(2)
                        break
                    elseif param >= keys.one and param <= keys.nine then
                        -- 数字キー1-9でアイテムを直接選択して転送
                        local numKey = param - keys.one + 1
                        local sourceInv = inventories[selectedSourceIndex]

                        -- Find the nth item in the inventory
                        local count = 0
                        for slot, item in pairs(sourceInv.contents) do
                            count = count + 1
                            if count == numKey then
                                print("\nTransferring " .. (item.displayName or item.name) .. " x" .. item.count)
                                local success, message = transferItems(sourceInv, inventories[selectedDestIndex], slot,
                                    item.count)
                                print(message)
                                sleep(2) -- Pause to show results
                                break
                            end

                            if count >= 9 then
                                break
                            end -- 最大9アイテムまで
                        end
                        break
                    end
                end
            elseif event == "mouse_click" then
                -- マウスクリックでもtransferモードに切り替え
                if handleMouseClick(inventories, param, param2, param3) then
                    break
                end
            end
        end
    end
end

-- Run the main function
main()
