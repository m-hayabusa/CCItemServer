-- インベントリ操作のユーティリティ関数ライブラリ
local inventoryUtils = {}

-- キャッシュ変数
local cachedInventories = {}
local cachedItemLists = {}
local cachedItemListsTime = {}

-- Function to check if a peripheral is an inventory
function inventoryUtils.isInventory(peripheralName)
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
function inventoryUtils.getInventoryDetails(peripheralName, forceRefresh)
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

-- アイテム一覧を取得する関数（キャッシュ対応）
function inventoryUtils.getItemList(inventory, forceRefresh)
    local inventoryName = inventory.name
    local currentTime = os.clock()

    -- キャッシュが有効かチェック
    if not forceRefresh and cachedItemLists[inventoryName] and
        (currentTime - (cachedItemListsTime[inventoryName] or 0) < 30) then
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
function inventoryUtils.transferItems(sourceInventory, destInventory, sourceSlot, count)
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
function inventoryUtils.transferAllItems(sourceInventory, destInventory)
    print("\nTransferring all items...")
    local transferCount = 0
    local retryCount = 0
    local maxRetries = 2
    local remainingSlots = {}

    -- 最初に転送するスロットのリストを作成
    for slot, _ in pairs(sourceInventory.contents) do
        table.insert(remainingSlots, slot)
    end

    -- すべてのアイテムが転送されるか、最大リトライ回数に達するまで繰り返す
    while #remainingSlots > 0 and retryCount < maxRetries do
        local slotsToRetry = {}

        -- 現在のリストにあるスロットを処理
        for _, slot in ipairs(remainingSlots) do
            -- 転送前に最新のインベントリ情報を取得
            local source = peripheral.wrap(sourceInventory.name)

            -- スロットにアイテムがあるか確認
            local items = source.list()
            if items[slot] then
                local success, message = inventoryUtils.transferItems(sourceInventory, destInventory, slot,
                    items[slot].count)
                if success then
                    transferCount = transferCount + 1
                    print(message)
                else
                    -- 転送失敗したスロットを再試行リストに追加
                    table.insert(slotsToRetry, slot)
                    print("Failed to transfer from slot " .. slot .. ": " .. message)
                end
            end
        end

        -- 再試行リストを次のイテレーションのリストとして設定
        remainingSlots = slotsToRetry

        -- 再試行が必要な場合は少し待機
        if #remainingSlots > 0 then
            retryCount = retryCount + 1
            print("Retrying " .. #remainingSlots .. " slots... (Attempt " .. retryCount .. "/" .. maxRetries .. ")")
            sleep(0.5)

            -- 再試行前にキャッシュを無効化して最新情報を取得
            cachedInventories[sourceInventory.name] = nil
            cachedInventories[destInventory.name] = nil
            cachedItemLists[sourceInventory.name] = nil
            cachedItemLists[destInventory.name] = nil

            -- 転送元インベントリの情報を更新
            sourceInventory = inventoryUtils.getInventoryDetails(sourceInventory.name, true)
        end
    end

    -- 結果の表示
    if #remainingSlots > 0 then
        print("Warning: " .. #remainingSlots .. " slots could not be transferred after " .. maxRetries .. " attempts")
    else
        print("Successfully transferred all items from " .. transferCount .. " slots")
    end

    sleep(0.5)

    -- 転送後、関連するインベントリのキャッシュを無効化
    cachedInventories[sourceInventory.name] = nil
    cachedInventories[destInventory.name] = nil
    cachedItemLists[sourceInventory.name] = nil
    cachedItemLists[destInventory.name] = nil

    return transferCount > 0
end

-- キャッシュをクリアする関数
function inventoryUtils.clearCache()
    cachedInventories = {}
    cachedItemLists = {}
    cachedItemListsTime = {}
end

return inventoryUtils
