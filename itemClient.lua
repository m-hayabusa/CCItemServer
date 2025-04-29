-- Item Management Client
-- Connects to item server and provides user interface for inventory management
-- ライブラリのインポート
local request = require("lib.request")

-- Configuration
local SERVER_CHANNEL = 137 -- Server communication channel
local CLIENT_CHANNEL = os.getComputerID() + 5000 -- Unique client channel
local SERVER_TIMEOUT = 30 -- Timeout for server responses in seconds
local INACTIVITY_TIMEOUT = 300 -- Inactivity timeout in seconds

-- UI state
local VIEW_MODE = "inventories" -- "inventories" or "items"
local selectedSourceIndex = nil
local selectedDestIndex = nil
local backButtonPos = nil
local transferAllPos = nil
local scrollOffset = 0
local ITEMS_PER_PAGE = 8
local scrollUpPos = nil
local scrollDownPos = nil
local inventories = {}
local currentItems = {}
local lastActivityTime = os.clock() -- 最後の操作時間を記録

-- リクエストライブラリの初期化
local success, message = request.init({
    serverChannel = SERVER_CHANNEL,
    clientChannel = CLIENT_CHANNEL,
    serverTimeout = SERVER_TIMEOUT
})

if not success then
    print(message)
    return
end

print(message)

-- 操作があったときに最終活動時間を更新する関数
function updateActivityTime()
    lastActivityTime = os.clock()
end

-- 非アクティブ時間をチェックする関数
function checkInactivity()
    local currentTime = os.clock()
    local inactiveTime = currentTime - lastActivityTime

    if inactiveTime >= INACTIVITY_TIMEOUT then
        clearScreen()
        print("Shutting down due to inactivity (" .. math.floor(INACTIVITY_TIMEOUT / 60) .. " minutes)")
        sleep(2)
        return true -- シャットダウンする
    end

    return false -- 継続する
end

-- Function to clear the screen
function clearScreen()
    term.clear()
    term.setCursorPos(1, 1)
end

-- Function to reset scroll position
function resetScroll()
    scrollOffset = 0
end

-- Function to get all inventories from server
function getInventories(forceRefresh)
    local response = request.getInventories(forceRefresh)

    if response.success then
        inventories = response.data
        return true
    else
        print("Error: " .. response.message)
        sleep(2)
        return false
    end
end

-- Function to get items from an inventory
function getItems(inventoryName, forceRefresh)
    local response = request.getItems(inventoryName, forceRefresh)

    if response.success then
        currentItems = response.data
        return true
    else
        print("Error: " .. response.message)
        sleep(2)
        return false
    end
end

-- Function to transfer an item
function transferItem(sourceInv, destInv, slot, count)
    local response = request.transferItem(sourceInv, destInv, slot, count)

    print(response.message)
    return response.success
end

-- Function to transfer all items
function transferAllItems(sourceInv, destInv)
    local response = request.transferAllItems(sourceInv, destInv)

    print(response.message)
    return response.success
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
function printInventories(limit)
    for i, inventory in ipairs(inventories) do
        inventory.pos = {
            head = nil,
            tail = nil
        }
        local x, y = term.getCursorPos()
        inventory.pos.head = y

        -- 表示名を使用（存在する場合）
        local displayName = inventory.displayName or inventory.name
        print(i .. ". " .. displayName .. " (" .. inventory.name .. ")")

        if inventory.items > 0 then
            local count = 0
            -- We don't have contents in the inventory list from server
            -- So we just show the item count
            print("     Items: " .. inventory.items .. "/" .. inventory.size)
        end
        local x, y = term.getCursorPos()
        inventory.pos.tail = y

        print("")
    end
    VIEW_MODE = "inventories"
    return inventories
end

-- Function to display transfer interface
function showTransferInterface()
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

    -- 表示名を使用（存在する場合）
    local sourceDisplayName = selectedSourceIndex and
                                  (inventories[selectedSourceIndex].displayName or inventories[selectedSourceIndex].name) or
                                  "Not selected (L-Click)"

    local destDisplayName = selectedDestIndex and
                                (inventories[selectedDestIndex].displayName or inventories[selectedDestIndex].name) or
                                "Not selected (R-Click)"

    -- Display source selection with display names
    print("From: " .. sourceDisplayName)
    print("To:   " .. destDisplayName)
    print("-----------------------------")

    -- If both source and destination are selected
    if selectedSourceIndex and selectedDestIndex then
        local sourceInv = inventories[selectedSourceIndex]
        local destInv = inventories[selectedDestIndex]

        -- Get items if not already loaded
        if #currentItems == 0 then
            getItems(sourceInv.name, true)
        end

        print("Source Contents:")
        if #currentItems > 0 then
            -- スクロールコントロールの表示（アイテムが多い場合）
            if #currentItems > ITEMS_PER_PAGE then
                local currentPage = math.ceil(scrollOffset / ITEMS_PER_PAGE) + 1
                local totalPages = math.ceil(#currentItems / ITEMS_PER_PAGE)
                print("Page " .. currentPage .. " of " .. totalPages .. " (Up/Down keys to change page)")
            end

            -- 0番目に「すべてのアイテム」を表示
            local x, y = term.getCursorPos()
            transferAllPos = {
                head = y,
                tail = y
            }
            print(" 0. [Transfer All Items] (" .. #currentItems .. " items)\n")

            local itemPerPage = ITEMS_PER_PAGE

            local showScrollUp = scrollOffset > 0
            if (showScrollUp) then
                itemPerPage = itemPerPage - 1
            end

            local showScrollDown = scrollOffset < #currentItems - itemPerPage

            if showScrollDown then
                itemPerPage = itemPerPage - 1
            end

            -- スクロールアップボタン
            if showScrollUp then
                local x, y = term.getCursorPos()
                scrollUpPos = {
                    head = y,
                    tail = y
                }
                print(" -. [Scroll Up]")
            else
                scrollUpPos = nil
            end

            -- 個別アイテムの表示
            local displayCount = 0
            for i = scrollOffset + 1, math.min(scrollOffset + itemPerPage, #currentItems) do
                local item = currentItems[i]
                displayCount = displayCount + 1

                local x, y = term.getCursorPos()
                item.pos = {
                    head = y,
                    tail = y
                }
                print(" " .. displayCount .. ". " .. item.displayName .. " *" .. item.count)
            end

            -- スクロールダウンボタン
            if showScrollDown then
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
            write("\nEnter slot number to transfer, or 'q' to quit: ")
        else
            print("Source inventory is empty")
            sleep(0.5)
            selectedSourceIndex = nil
            selectedDestIndex = nil
            resetScroll() -- スクロール位置をリセット
            showTransferInterface()
        end
    else
        printInventories(2)
    end
end

-- インベントリ名を編集する機能を追加
function editInventoryName(inventoryIndex)
    local inventory = inventories[inventoryIndex]
    if not inventory then
        return false
    end

    clearScreen()
    print("Edit Inventory Name")
    print("-----------------------------")
    print("Current name: " .. (inventory.displayName or inventory.name))
    print("ID: " .. inventory.name)
    print("-----------------------------")
    write("Enter new display name: ")

    local newName = read()
    updateActivityTime() -- 名前入力も操作とみなす

    if newName and newName ~= "" then
        -- サーバーに名前変更リクエストを送信
        local response = request.setInventoryName(inventory.name, newName)

        if response.success then
            inventory.displayName = newName
            print("Name updated successfully!")
        else
            print("Failed to update name: " .. response.message)
        end
        sleep(0.5)
        return true
    end

    return false
end

-- Function to handle key events
function handleKeyEvents(key)
    updateActivityTime() -- キー操作があったことを記録

    -- 共通のキー処理
    if key == keys.q then
        -- Qキーで前の画面に戻る
        if VIEW_MODE == "items" then
            VIEW_MODE = "inventories"
            selectedSourceIndex = nil
            selectedDestIndex = nil
            resetScroll() -- スクロール位置をリセット
            currentItems = {} -- アイテムリストをクリア
        elseif VIEW_MODE == "inventories" then
            os.pullEvent("key_up") -- キーが離されるのを待つ
            return false, true
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
            updateActivityTime() -- 入力も操作とみなす
            local num = tonumber(input)
            if num and num >= 1 and num <= #inventories then
                selectedSourceIndex = num
                currentItems = {} -- アイテムリストをクリア
                print("Selected source: " .. (inventories[num].displayName or inventories[num].name))
            end
            return true
        elseif key == keys.d then
            -- Dキーで転送先選択モード
            os.pullEvent("key_up") -- キーが離されるのを待つ
            write("\nEnter destination inventory number: ")
            local input = read()
            updateActivityTime() -- 入力も操作とみなす
            local num = tonumber(input)
            if num and num >= 1 and num <= #inventories then
                selectedDestIndex = num
                print("Selected destination: " .. (inventories[num].displayName or inventories[num].name))
            end
            return true
        elseif key == keys.e then
            -- Eキーでインベントリ名編集モード
            os.pullEvent("key_up") -- キーが離されるのを待つ
            write("\nEnter inventory number to edit name: ")
            local input = read()
            updateActivityTime() -- 入力も操作とみなす
            local num = tonumber(input)
            if num and num >= 1 and num <= #inventories then
                editInventoryName(num)
            end
            return true
        elseif key >= keys.one and key <= keys.nine then
            -- 数字キー1-9でインベントリを直接選択
            local num = key - keys.one + 1
            if num >= 1 and num <= #inventories then
                if selectedSourceIndex == nil then
                    selectedSourceIndex = num
                    print("Selected source: " .. (inventories[num].displayName or inventories[num].name))
                elseif selectedDestIndex == nil then
                    selectedDestIndex = num
                    print("Selected destination: " .. (inventories[num].displayName or inventories[num].name))
                end

                -- 両方選択されたらアイテム表示モードに切り替え
                if selectedSourceIndex and selectedDestIndex then
                    VIEW_MODE = "items"
                    getItems(inventories[selectedSourceIndex].name, true)
                end
                return true
            end
        end
    elseif VIEW_MODE == "items" then
        -- スクロール処理
        if key == keys.up then
            -- 上キーでページアップ（PgUp相当）
            scrollOffset = math.max(0, scrollOffset - (ITEMS_PER_PAGE - 2))
            return true
        elseif key == keys.down then
            -- 下キーでページダウン（PgDn相当）
            scrollOffset = math.min(#currentItems - (ITEMS_PER_PAGE - 2), scrollOffset + (ITEMS_PER_PAGE - 2))
            return true
        elseif key == keys.a or key == keys.zero then
            -- 0キーまたはAキーですべてのアイテムを転送
            transferAllItems(inventories[selectedSourceIndex].name, inventories[selectedDestIndex].name)
            getItems(inventories[selectedSourceIndex].name, true)
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
            if numKey == ITEMS_PER_PAGE - 2 and scrollDownPos then
                scrollOffset = math.min(#currentItems - (ITEMS_PER_PAGE - 2), scrollOffset + (ITEMS_PER_PAGE - 2))
                return true
            end

            -- 通常のアイテム選択処理
            -- 選択されたアイテムのインデックスを計算
            local selectedIndex = scrollOffset + numKey

            if selectedIndex <= #currentItems then
                local item = currentItems[selectedIndex]
                print("\nTransferring " .. item.displayName .. " x" .. item.count)

                transferItem(inventories[selectedSourceIndex].name, inventories[selectedDestIndex].name, item.slot,
                    item.count)
                getItems(inventories[selectedSourceIndex].name, true)
                return true
            end
        end
    end

    return false
end

-- Function to handle mouse clicks for inventory selection
function handleMouseClick(button, x, y)
    updateActivityTime() -- マウス操作があったことを記録

    -- 戻るボタンがクリックされたかチェック
    if backButtonPos and y == backButtonPos.head then
        selectedSourceIndex = nil
        selectedDestIndex = nil
        VIEW_MODE = "inventories"
        resetScroll() -- スクロール位置をリセット
        currentItems = {} -- アイテムリストをクリア
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
                    currentItems = {} -- アイテムリストをクリア
                    print("Selected source: " .. (inventory.displayName or inventory.name))
                    return true
                elseif button == 2 then -- 右クリック = destination
                    selectedDestIndex = i
                    print("Selected destination: " .. (inventory.displayName or inventory.name))
                    return true
                elseif button == 3 then -- 中クリック = 名前編集
                    editInventoryName(i)
                    return true
                end
            end
        end
        -- VIEW_MODEがitemsの場合（アイテムリスト表示時）
    elseif VIEW_MODE == "items" then
        -- 両方のインベントリが選択されている場合のみ
        if selectedSourceIndex and selectedDestIndex then
            -- 「すべてのアイテム」行がクリックされたかチェック
            if transferAllPos and y == transferAllPos.head then
                transferAllItems(inventories[selectedSourceIndex].name, inventories[selectedDestIndex].name)
                getItems(inventories[selectedSourceIndex].name, true)
                return true
            end

            -- スクロールアップボタンがクリックされたかチェック
            if scrollUpPos and y == scrollUpPos.head then
                scrollOffset = math.max(0, scrollOffset - (ITEMS_PER_PAGE - 2))
                return true
            end

            -- スクロールダウンボタンがクリックされたかチェック
            if scrollDownPos and y == scrollDownPos.head then
                scrollOffset = math.min(#currentItems - (ITEMS_PER_PAGE - 2), scrollOffset + (ITEMS_PER_PAGE - 2))
                return true
            end

            -- 個別アイテムリストの位置を特定
            -- 表示されているアイテムをチェック
            for i = 1, math.min(ITEMS_PER_PAGE - 2, #currentItems - scrollOffset) do
                local itemIndex = scrollOffset + i
                local item = currentItems[itemIndex]

                -- アイテム行の位置を確認
                if item.pos and item.pos.head <= y and y <= item.pos.tail then
                    print("\nTransferring " .. item.displayName .. " x" .. item.count)
                    transferItem(inventories[selectedSourceIndex].name, inventories[selectedDestIndex].name, item.slot,
                        item.count)
                    getItems(inventories[selectedSourceIndex].name, true)
                    return true
                end
            end
        end
    end

    return false
end

-- Function to handle mouse scroll events
function handleMouseScroll(direction)
    updateActivityTime() -- マウススクロール操作があったことを記録

    if VIEW_MODE == "items" then
        if direction > 0 then
            -- 上にスクロール
            if scrollOffset > 0 then
                scrollOffset = math.max(0, scrollOffset - 1)
                return true
            end
        else
            -- 下にスクロール
            if scrollOffset < #currentItems - (ITEMS_PER_PAGE - 2) then
                scrollOffset = math.min(#currentItems - (ITEMS_PER_PAGE - 2), scrollOffset + 1)
                return true
            end
        end
    end
    return false
end

-- メインインターフェースに操作ガイドを追加
function showMainInterface()
    clearScreen()

    -- ヘッダー情報とガイド表示
    print("=== Item Management System ===")
    print("Controls:")
    print("- Left-click   / S: Select source inventory")
    print("- Right-click  / D: Select destination inventory")
    print("- Middle-click / E: Edit inventory name")
    print("-                Q: Back/Exit")
    print("==============================")

    -- 非アクティブタイマーの表示
    local inactiveTime = os.clock() - lastActivityTime
    local remainingTime = INACTIVITY_TIMEOUT - inactiveTime
    if remainingTime < 60 then
        print("Auto-shutdown in " .. math.floor(remainingTime) .. " seconds\n")
    end

    -- インベントリリスト表示
    printInventories()
end

-- Main function
function main()
    -- Check if server is available
    print("Connecting to item server...")
    local response = request.getInventories(true)

    if not response.success then
        print("Could not connect to server: " .. response.message)
        print("Make sure the server is running on channel " .. SERVER_CHANNEL)
        return
    end

    inventories = response.data
    print("Connected to server. Found " .. #inventories .. " inventories.")

    -- 可能であればモニターにリダイレクト
    redirectToMonitor()

    -- Main loop
    while true do
        -- 非アクティブ時間をチェック
        if checkInactivity() then
            -- 非アクティブタイムアウトが発生したらプログラム終了
            return
        end

        -- メインインターフェース表示に変更
        if VIEW_MODE == "inventories" and not selectedSourceIndex and not selectedDestIndex then
            showMainInterface()
        else
            showTransferInterface()
        end

        local timer = os.startTimer(5) -- 5秒ごとに画面更新（非アクティブチェックのため短くする）
        local shouldRefresh = false
        local forceRefresh = false

        -- イベント処理ループ
        while not shouldRefresh do
            local event, param, param2, param3 = os.pullEvent()

            if event == "timer" and param == timer then
                -- タイマーイベント：画面を更新
                shouldRefresh = true

                -- 非アクティブ時間をチェック
                if checkInactivity() then
                    -- 非アクティブタイムアウトが発生したらプログラム終了
                    os.shutdown()
                    return
                end
            elseif event == "key" then
                -- キーボードイベント
                local refreshRequired, exitProgram = handleKeyEvents(param)
                if exitProgram then
                    -- プログラム終了
                    print("Exiting program.")
                    return
                end
                if refreshRequired then
                    shouldRefresh = true
                    -- アイテム転送操作の場合のみ強制更新
                    if VIEW_MODE == "items" and
                        (param == keys.a or param == keys.zero or (param >= keys.one and param <= keys.nine)) then
                        forceRefresh = true
                    end
                end
            elseif event == "mouse_click" then
                -- マウスクリックイベント
                if handleMouseClick(param, param2, param3) then
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
                if handleMouseScroll(param) then
                    shouldRefresh = true
                end
            end
        end

        -- 次のループでインベントリ情報を更新するかどうか
        if forceRefresh then
            -- インベントリ情報を更新
            getInventories(true)
            if selectedSourceIndex and selectedDestIndex then
                getItems(inventories[selectedSourceIndex].name, true)
            end
        end
    end
end

-- Run the program
main()
