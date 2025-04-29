-- Item Management Server
-- Monitors inventories and handles item transfer requests
local inventoryUtils = require("lib.inventoryUtils")

-- Configuration
local SERVER_CHANNEL = 137 -- Communication channel
local REFRESH_INTERVAL = 30 -- Inventory refresh interval in seconds
local INVENTORY_NAMES_FILE = "inventory_names.json" -- JSONファイルのパス
local inventoryCache = {} -- Cache of inventory information
local lastRefreshTime = 0 -- Time of last inventory refresh
local inventoryNames = {} -- インベントリIDと表示名のマッピング

function logMessage(message)
    local currentTime = os.time("local")
    local formattedTime = textutils.formatTime(currentTime, true)
    print("[" .. formattedTime .. "] " .. message)
end

-- Initialize modem
local modem = peripheral.find("modem")
if not modem then
    logMessage("No modem found! Please attach a modem.")
    return
end

modem.open(SERVER_CHANNEL)
logMessage("Server started on channel " .. SERVER_CHANNEL)

-- インベントリ名マッピングをJSONファイルから読み込む
function loadInventoryNames()
    if fs.exists(INVENTORY_NAMES_FILE) then
        local file = fs.open(INVENTORY_NAMES_FILE, "r")
        local content = file.readAll()
        file.close()

        local success, result = pcall(textutils.unserializeJSON, content)
        if success then
            logMessage("Loaded inventory name mappings\n" .. textutils.serialize(result))
        else
            logMessage("Error loading inventory names: " .. result)
            inventoryNames = {}
        end
    else
        logMessage("No inventory name mappings found, using default names")
        inventoryNames = {}
    end
end

-- インベントリ名マッピングをJSONファイルに保存する
function saveInventoryNames()
    local file = fs.open(INVENTORY_NAMES_FILE, "w")
    file.write(textutils.serializeJSON(inventoryNames))
    file.close()
    logMessage("Saved inventory name mappings")
end

-- インベントリIDから表示名を取得する（なければデフォルト名を生成）
function getDisplayName(inventoryId)
    if inventoryNames[inventoryId] then
        return inventoryNames[inventoryId]
    end

    -- デフォルト名を生成（例：chest_1, barrel_2など）
    local baseType = "container"
    if inventoryId:find("chest") then
        baseType = "chest"
    elseif inventoryId:find("barrel") then
        baseType = "barrel"
    elseif inventoryId:find("shulker") then
        baseType = "shulker"
    end

    -- 同じタイプの数をカウント
    local count = 1
    for id, _ in pairs(inventoryNames) do
        if id:find(baseType) then
            count = count + 1
        end
    end

    local displayName = baseType .. "_" .. count
    inventoryNames[inventoryId] = displayName
    saveInventoryNames()

    return displayName
end

-- 起動時にインベントリ名マッピングを読み込む
loadInventoryNames()

-- Function to refresh inventory data
function refreshInventories(forceRefresh)
    local currentTime = os.clock()

    -- Use cache if not forced and cache is fresh
    if not forceRefresh and (currentTime - lastRefreshTime < REFRESH_INTERVAL) then
        return inventoryCache
    end

    logMessage("Refreshing inventory data...")
    local peripherals = peripheral.getNames()
    local inventories = {}

    for _, name in ipairs(peripherals) do
        if name:find(":") and inventoryUtils.isInventory(name) then
            local details = inventoryUtils.getInventoryDetails(name, true)
            inventories[name] = details
        end
    end

    inventoryCache = inventories
    lastRefreshTime = currentTime
    return inventories
end

-- Function to handle client requests
function handleRequest(sender, message)
    if type(message) ~= "table" or not message.type then
        return {
            success = false,
            message = "Invalid request format"
        }
    end

    local requestType = message.type
    local response = {
        success = false,
        message = "Unknown request type"
    }

    if requestType == "GET_INVENTORIES" then
        local inventories = refreshInventories(message.forceRefresh)
        local inventoryList = {}

        -- Convert to array format for transmission
        for name, details in pairs(inventories) do
            table.insert(inventoryList, {
                name = name,
                displayName = getDisplayName(name), -- 表示名を追加
                type = details.type,
                size = details.size,
                items = details.items
            })
        end

        response = {
            success = true,
            data = inventoryList,
            message = "Retrieved " .. #inventoryList .. " inventories"
        }

    elseif requestType == "GET_ITEMS" then
        local inventoryName = message.inventory

        if not inventoryName then
            response = {
                success = false,
                message = "No inventory specified"
            }
        else
            local inventories = refreshInventories(false)
            local inventory = inventories[inventoryName]

            if not inventory then
                response = {
                    success = false,
                    message = "Inventory not found: " .. inventoryName
                }
            else
                local itemList = inventoryUtils.getItemList(inventory, message.forceRefresh)
                response = {
                    success = true,
                    data = itemList,
                    displayName = getDisplayName(inventoryName), -- 表示名を追加
                    message = "Retrieved " .. #itemList .. " items"
                }
            end
        end

    elseif requestType == "TRANSFER_ITEM" then
        local sourceInv = message.source
        local destInv = message.destination
        local slot = message.slot
        local count = message.count or 64 -- Default to a full stack

        if not sourceInv or not destInv or not slot then
            response = {
                success = false,
                message = "Missing required parameters"
            }
        else
            local inventories = refreshInventories(true) -- Force refresh for transfers

            if not inventories[sourceInv] then
                response = {
                    success = false,
                    message = "Source inventory not found"
                }
            elseif not inventories[destInv] then
                response = {
                    success = false,
                    message = "Destination inventory not found"
                }
            else
                local success, message = inventoryUtils.transferItems(inventories[sourceInv], inventories[destInv],
                    slot, count)

                response = {
                    success = success,
                    message = message
                }

                -- Refresh cache after transfer
                refreshInventories(true)
            end
        end

    elseif requestType == "TRANSFER_ALL" then
        local sourceInv = message.source
        local destInv = message.destination

        if not sourceInv or not destInv then
            response = {
                success = false,
                message = "Missing required parameters"
            }
        else
            local inventories = refreshInventories(true) -- Force refresh for transfers

            if not inventories[sourceInv] then
                response = {
                    success = false,
                    message = "Source inventory not found"
                }
            elseif not inventories[destInv] then
                response = {
                    success = false,
                    message = "Destination inventory not found"
                }
            else
                local success = inventoryUtils.transferAllItems(inventories[sourceInv], inventories[destInv])

                response = {
                    success = success,
                    message = success and "All items transferred successfully" or "Some items could not be transferred"
                }

                -- Refresh cache after transfer
                refreshInventories(true)
            end
        end
    elseif requestType == "SET_INVENTORY_NAME" then
        -- インベントリの表示名を設定するリクエストを追加
        local inventoryId = message.inventoryId
        local displayName = message.displayName

        if not inventoryId or not displayName then
            response = {
                success = false,
                message = "Missing inventory ID or display name"
            }
        else
            inventoryNames[inventoryId] = displayName
            saveInventoryNames()

            response = {
                success = true,
                message = "Display name set for " .. inventoryId
            }
        end
    end

    return response
end

-- Main server loop
logMessage("Waiting for client requests...")
while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

    if channel == SERVER_CHANNEL then
        logMessage("Received request from " .. replyChannel)

        -- Process the request
        local response = handleRequest(replyChannel, message)

        -- Send the response back
        modem.transmit(replyChannel, SERVER_CHANNEL, response)
        logMessage("Response sent")
    end
end
