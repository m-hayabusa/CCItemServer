-- Inventory Scanner and Transfer Tool for ComputerCraft
-- Lists all inventories accessible via modem and allows item transfer between them
-- Configuration
local REFRESH_INTERVAL = 30 -- Refresh interval in seconds
local VIEW_MODE = "inventories" -- "inventories" or "items"
local selectedSourceIndex = nil
local selectedDestIndex = nil
local backButtonPos = nil
local transferAllPos = nil
local scrollOffset = 0 -- アイテムリストのスクロールオフセット
local ITEMS_PER_PAGE = 9 -- 1ページあたりの表示アイテム数
local scrollUpPos = nil -- スクロールアップボタンの位置
local scrollDownPos = nil -- スクロールダウンボタンの位置
local cachedInventories = {} -- インベントリ情報のキャッシュ
local inventoryOrder = {} -- インベントリの順序を保持する配列
local lastRefreshTime = 0 -- 最後にインベントリ情報を更新した時間
local cachedItemLists = {} -- アイテム一覧のキャッシュ
local cachedItemListsTime = {} -- アイテム一覧キャッシュの最終更新時間

-- スクロール位置をリセットする関数
function resetScroll()
    scrollOffset = 0
end

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
function getInventoryDetails(peripheralName, forceRefresh)
    -- キャッシュにあり、強制更新でなければキャッシュを返す
    if not forceRefresh and cachedInventories[peripheralName] then
        return cachedInventories[peripheralName]
    end

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

    -- 結果をキャッシュに保存
    cachedInventories[peripheralName] = details
    return details
end

-- Function to refresh inventory data only when needed
function refreshInventories(peripherals, forceRefresh)
    local currentTime = os.clock()
    local inventories = {}

    -- 前回の更新から一定時間経過していない場合、かつ強制更新でない場合はキャッシュを使用
    if not forceRefresh and (currentTime - lastRefreshTime < REFRESH_INTERVAL) and next(cachedInventories) then
        -- キャッシュされたインベントリ情報を使用（順序を保持）
        for _, name in ipairs(inventoryOrder) do
            if cachedInventories[name] then
                table.insert(inventories, cachedInventories[name])
            end
        end
        return inventories
    end

    -- インベントリ情報を更新
    inventoryOrder = {} -- 順序をリセット
    for _, peripheral in ipairs(peripherals) do
        if isInventory(peripheral.name) then
            local details = getInventoryDetails(peripheral.name, true)
            table.insert(inventories, details)
            table.insert(inventoryOrder, peripheral.name) -- 順序を記録
        end
    end

    lastRefreshTime = currentTime
    return inventories
end

-- アイテム一覧を取得する関数（キャッシュ対応）
function getItemList(inventory, forceRefresh)
    local inventoryName = inventory.name
    local currentTime = os.clock()

    -- キャッシュが有効かチェック
    if not forceRefresh and cachedItemLists[inventoryName] and
        (currentTime - (cachedItemListsTime[inventoryName] or 0) < REFRESH_INTERVAL) then
        return cachedItemLists[inventoryName]
    end

    -- アイテムリストを作成
    local itemList = {}
    local totalItems = 0

    for slot, item in pairs(inventory.contents) do
        totalItems = totalItems + 1
        table.insert(itemList, {
            slot = slot,
            name = item.name,
            displayName = item.displayName or item.name,
            count = item.count
        })
    end

    -- 結果をキャッシュ
    cachedItemLists[inventoryName] = itemList
    cachedItemListsTime[inventoryName] = currentTime

    return itemList
end

-- Function to transfer items between inventories
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

    -- アイテム転送を試みる
    local success, transferred = pcall(source.pushItems, destName, sourceSlot, count)

    if success and transferred > 0 then
        -- 転送成功後、関連するインベントリのキャッシュを無効化
        cachedInventories[sourceName] = nil
        cachedInventories[destName] = nil
        -- アイテム一覧のキャッシュも無効化
        cachedItemLists[sourceName] = nil
        cachedItemLists[destName] = nil
        return true, "Transferred " .. transferred .. " items"
    else
        return false, "Failed to transfer items"
    end
end

-- Function to transfer all items from source to destination
function transferAllItems(sourceInventory, destInventory)
    print("\nTransferring all items...")
    local transferCount = 0

    for slot, item in pairs(sourceInventory.contents) do
        local success, message = transferItems(sourceInventory, destInventory, slot, item.count)
        if success then
            transferCount = transferCount + 1
            print(message)
        end
    end

    print("Transferred items from " .. transferCount .. " slots")
    sleep(0.5)

    -- 転送後、関連するインベントリのキャッシュを無効化
    cachedInventories[sourceInventory.name] = nil
    cachedInventories[destInventory.name] = nil
    -- アイテム一覧のキャッシュも無効化
    cachedItemLists[sourceInventory.name] = nil
    cachedItemLists[destInventory.name] = nil

    return transferCount > 0
end

-- Function to display transfer interface
function showTransferInterface(inventories)
    clearScreen()

    if selectedSourceIndex and selectedDestIndex then
        local x, y = term.getCursorPos()
        backButtonPos = {
            head = y,
            tail = y
        }
        print("[Back to Inventory List (q)]")
    else
        backButtonPos = nil
    end

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
            -- アイテムリストを取得（キャッシュ利用）
            local itemList = getItemList(sourceInv, false)
            local totalItems = #itemList

            -- スクロールコントロールの表示（アイテムが多い場合）
            if totalItems > ITEMS_PER_PAGE then
                local currentPage = math.ceil(scrollOffset / ITEMS_PER_PAGE) + 1
                local totalPages = math.ceil(totalItems / ITEMS_PER_PAGE) + 1
                print("Page " .. currentPage .. " of " .. totalPages .. " (Up/Down keys to change page)")
            end

            -- 0番目に「すべてのアイテム」を表示
            local x, y = term.getCursorPos()
            transferAllPos = {
                head = y,
                tail = y
            }
            print(" 0. [Transfer All Items] (" .. sourceInv.items .. " items)\n")

            -- スクロールアップボタン（アイテムが多い場合のみ表示）
            if scrollOffset > 0 then
                local x, y = term.getCursorPos()
                scrollUpPos = {
                    head = y,
                    tail = y
                }
                print(" -. [Scroll Up]")
            else
                scrollUpPos = nil
            end

            -- 個別アイテムの表示（スクロールオフセットを考慮）
            local itemPerPage = ITEMS_PER_PAGE - 2
            if (scrollOffset > 0) then
                itemPerPage = itemPerPage - 1
            end
            if (totalItems - scrollOffset) < ITEMS_PER_PAGE then
                itemPerPage = itemPerPage - 1
            end

            local displayCount = 0
            for i = scrollOffset + 1, math.min(scrollOffset + itemPerPage, totalItems) do
                local item = itemList[i]
                displayCount = displayCount + 1

                local x, y = term.getCursorPos()
                item.pos = {
                    head = y,
                    tail = y
                }
                print(" " .. displayCount .. ". " .. item.displayName .. " *" .. item.count)
            end

            -- スクロールダウンボタン（まだ表示していないアイテムがある場合のみ表示）
            if scrollOffset + ITEMS_PER_PAGE - 2 < totalItems then
                local x, y = term.getCursorPos()
                scrollDownPos = {
                    head = y,
                    tail = y
                }
                print(" +. [Scroll Down]")
            else
                scrollDownPos = nil
            end

            VIEW_MODE = "items"

            -- 入力プロンプトの表示
            -- term.setCursorPos(1, ({term.getSize()})[1] - 3)
            write("\nEnter slot number to transfer, or 'q' to quit: ")
        else
            print("Source inventory is empty")
            sleep(0.5)
            selectedSourceIndex = nil
            selectedDestIndex = nil
            showTransferInterface(inventories)
        end
    else
        inventories = printInventories(inventories, 2)
    end

    return inventories
end

-- Function to handle key events
function handleKeyEvents(inventories, key)
    -- 共通のキー処理
    if key == keys.q or key == keys.backspace or key == keys.escape then
        -- BackspaceまたはEscキーで前の画面に戻る
        if VIEW_MODE == "items" then
            VIEW_MODE = "inventories"
            selectedSourceIndex = nil
            selectedDestIndex = nil
            resetScroll() -- スクロール位置をリセット
        end
        return true
    end

    -- VIEW_MODEに応じた処理
    if VIEW_MODE == "inventories" then
        if key == keys.s then
            -- Sキーで転送元選択モード
            os.pullEvent("key_up") -- キーが離されるのを待つ
            write("\nEnter source inventory number: ")
            local input = read()
            local num = tonumber(input)
            if num and num >= 1 and num <= #inventories then
                selectedSourceIndex = num
                print("Selected source: " .. inventories[num].name)
            end
            return true
        elseif key == keys.d then
            -- Dキーで転送先選択モード
            os.pullEvent("key_up") -- キーが離されるのを待つ
            write("\nEnter destination inventory number: ")
            local input = read()
            local num = tonumber(input)
            if num and num >= 1 and num <= #inventories then
                selectedDestIndex = num
                print("Selected destination: " .. inventories[num].name)
            end
            return true
        elseif key >= keys.one and key <= keys.nine then
            -- 数字キー1-9でインベントリを直接選択
            local num = key - keys.one + 1
            if num >= 1 and num <= #inventories then
                if selectedSourceIndex == nil then
                    selectedSourceIndex = num
                    print("Selected source: " .. inventories[num].name)
                elseif selectedDestIndex == nil then
                    selectedDestIndex = num
                    print("Selected destination: " .. inventories[num].name)
                end

                -- 両方選択されたらアイテム表示モードに切り替え
                if selectedSourceIndex and selectedDestIndex then
                    VIEW_MODE = "items"
                end
                return true
            end
        end
    elseif VIEW_MODE == "items" then
        -- スクロール処理
        if key == keys.up then
            -- 上キーでページアップ（PgUp相当）
            local sourceInv = inventories[selectedSourceIndex]
            local itemList = getItemList(sourceInv, false)
            local totalItems = #itemList

            scrollOffset = math.max(0, scrollOffset - (ITEMS_PER_PAGE - 2))
            return true
        elseif key == keys.down then
            -- 下キーでページダウン（PgDn相当）
            local sourceInv = inventories[selectedSourceIndex]
            local itemList = getItemList(sourceInv, false)
            local totalItems = #itemList

            scrollOffset = math.min(totalItems - (ITEMS_PER_PAGE - 2), scrollOffset + (ITEMS_PER_PAGE - 2))
            return true
        elseif key == keys.a or key == keys.zero then
            -- 0キーまたはAキーですべてのアイテムを転送
            local sourceInv = inventories[selectedSourceIndex]
            transferAllItems(sourceInv, inventories[selectedDestIndex])
            return true
        elseif key >= keys.one and key <= keys.nine then
            -- 数字キー1-9でアイテムを直接選択して転送
            local numKey = key - keys.one + 1

            -- 1番目のアイテムがスクロールアップボタンの場合
            if numKey == 1 and scrollUpPos then
                scrollOffset = math.max(0, scrollOffset - (ITEMS_PER_PAGE - 2))
                return true
            end

            -- 最後のアイテムがスクロールダウンボタンの場合
            local sourceInv = inventories[selectedSourceIndex]
            local itemList = getItemList(sourceInv, false)
            local totalItems = #itemList

            if numKey == ITEMS_PER_PAGE - 2 and scrollDownPos then
                scrollOffset = math.min(totalItems - (ITEMS_PER_PAGE - 2), scrollOffset + (ITEMS_PER_PAGE - 2))
                return true
            end

            -- 通常のアイテム選択処理
            local sourceInv = inventories[selectedSourceIndex]
            local itemList = getItemList(sourceInv, false)

            -- 選択されたアイテムのインデックスを計算
            local selectedIndex = scrollOffset + numKey

            if selectedIndex <= #itemList then
                local item = itemList[selectedIndex]
                print("\nTransferring " .. item.displayName .. " x" .. item.count)

                local success, message = transferItems(sourceInv, inventories[selectedDestIndex], item.slot, item.count)
                print(message)
                sleep(0.5) -- Pause to show results
                return true
            end
        end
    end

    return false
end

-- Function to handle mouse clicks for inventory selection
function handleMouseClick(inventories, button, x, y)
    -- 戻るボタンがクリックされたかチェック
    if backButtonPos and y == backButtonPos.head then
        selectedSourceIndex = nil
        selectedDestIndex = nil
        VIEW_MODE = "inventories"
        resetScroll() -- スクロール位置をリセット
        return true
    end

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

            -- 「すべてのアイテム」行がクリックされたかチェック
            if transferAllPos and y == transferAllPos.head then
                transferAllItems(sourceInv, inventories[selectedDestIndex])
                return true
            end

            -- スクロールアップボタンがクリックされたかチェック
            if scrollUpPos and y == scrollUpPos.head then
                scrollOffset = math.max(0, scrollOffset - (ITEMS_PER_PAGE - 2))
                return true
            end

            -- スクロールダウンボタンがクリックされたかチェック
            if scrollDownPos and y == scrollDownPos.head then
                local itemList = getItemList(sourceInv, false)
                local totalItems = #itemList

                scrollOffset = math.min(totalItems - (ITEMS_PER_PAGE - 2), scrollOffset + (ITEMS_PER_PAGE - 2))
                return true
            end

            -- 個別アイテムリストの位置を特定
            local itemList = getItemList(sourceInv, false)

            -- 表示されているアイテムをチェック
            for i = 1, math.min(ITEMS_PER_PAGE - 2, #itemList - scrollOffset) do
                local itemIndex = scrollOffset + i
                local item = itemList[itemIndex]

                -- アイテム行の位置を確認
                if item.pos and item.pos.head <= y and y <= item.pos.tail then
                    print("\nTransferring " .. item.displayName .. " x" .. item.count)
                    local success, message = transferItems(sourceInv, inventories[selectedDestIndex], item.slot,
                        item.count)
                    print(message)
                    sleep(0.5) -- 結果表示のための短い待機
                    return true
                end
            end
        end
    end

    return false
end

-- Function to redirect output to a monitor if available
function redirectToMonitor()
    local monitor = peripheral.find("monitor")
    if monitor then
        term.redirect(monitor)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setTextScale(0.5)
        return true
    end
    return false
end

-- Function to print inventory list with items
function printInventories(inventories, limit)
    for i, inventory in ipairs(inventories) do
        inventory.pos = {
            head = nil,
            tail = nil
        }
        local x, y = term.getCursorPos()
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
        local x, y = term.getCursorPos()
        inventory.pos.tail = y

        print("")
    end
    VIEW_MODE = "inventories"
    return inventories
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

    -- 可能であればモニターにリダイレクト
    redirectToMonitor()

    -- Main loop
    while true do
        local peripherals = getAllPeripherals()
        -- 初回または定期的な更新時のみインベントリ情報を取得
        local inventories = refreshInventories(peripherals, false)

        inventories = showTransferInterface(inventories)

        local timer = os.startTimer(REFRESH_INTERVAL)
        local shouldRefresh = false
        local forceRefresh = false

        -- イベント処理ループ
        while not shouldRefresh do
            local event, param, param2, param3 = os.pullEvent()

            if event == "timer" and param == timer then
                -- タイマーイベント：画面を更新
                shouldRefresh = true
                forceRefresh = true -- 定期更新時は強制的にインベントリ情報を更新
            elseif event == "key" then
                -- キーボードイベント
                if handleKeyEvents(inventories, param) then
                    shouldRefresh = true
                    -- アイテム転送操作の場合のみ強制更新
                    if VIEW_MODE == "items" and
                        (param == keys.a or param == keys.zero or (param >= keys.one and param <= keys.nine)) then
                        forceRefresh = true
                    end
                end
            elseif event == "mouse_click" then
                -- マウスクリックイベント
                if handleMouseClick(inventories, param, param2, param3) then
                    shouldRefresh = true
                    -- アイテム転送操作の場合のみ強制更新
                    if VIEW_MODE == "items" and
                        ((transferAllPos and param3 == transferAllPos.head) or
                            (not scrollUpPos or param3 ~= scrollUpPos.head) and
                            (not scrollDownPos or param3 ~= scrollDownPos.head)) then
                        forceRefresh = true
                    end
                end
            elseif event == "mouse_scroll" then
                -- マウスホイールイベント（スクロールのみなので強制更新不要）
                if VIEW_MODE == "items" then
                    local sourceInv = inventories[selectedSourceIndex]
                    local itemList = getItemList(sourceInv, false)
                    local totalItems = #itemList

                    if param > 0 then
                        -- 上にスクロール
                        if scrollOffset > 0 then
                            scrollOffset = math.max(0, scrollOffset - 1)
                            shouldRefresh = true
                        end
                    else
                        -- 下にスクロール
                        if scrollOffset < totalItems - (ITEMS_PER_PAGE - 2) then
                            scrollOffset = math.min(totalItems - (ITEMS_PER_PAGE - 2), scrollOffset + 1)
                            shouldRefresh = true
                        end
                    end
                end
            end
        end

        -- 次のループでインベントリ情報を更新するかどうか
        if forceRefresh then
            -- キャッシュをクリアして次回の更新で強制的に再取得
            cachedInventories = {}
            cachedItemLists = {}
            cachedItemListsTime = {}
        end
    end
end

-- Run the main function
main()
