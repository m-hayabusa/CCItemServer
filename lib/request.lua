-- Item Server Request Library
-- サーバーとの通信を処理するライブラリ
local request = {}

-- デフォルト設定
local DEFAULT_SERVER_CHANNEL = 137
local DEFAULT_CLIENT_CHANNEL = os.getComputerID() + 5000
local DEFAULT_SERVER_TIMEOUT = 30

-- 設定値
local serverChannel = DEFAULT_SERVER_CHANNEL
local clientChannel = DEFAULT_CLIENT_CHANNEL
local serverTimeout = DEFAULT_SERVER_TIMEOUT
local modem = nil

-- モデムの初期化
function request.init(options)
    options = options or {}

    -- 設定値の上書き
    serverChannel = options.serverChannel or DEFAULT_SERVER_CHANNEL
    clientChannel = options.clientChannel or DEFAULT_CLIENT_CHANNEL
    serverTimeout = options.serverTimeout or DEFAULT_SERVER_TIMEOUT

    -- モデムの取得
    modem = peripheral.find("modem")
    if not modem then
        return false, "No modem found! Please attach a modem."
    end

    -- クライアントチャンネルを開く
    modem.open(clientChannel)
    return true, "Client initialized on channel " .. clientChannel
end

-- サーバーにリクエストを送信し、レスポンスを待機する
function request.send(requestType, params, callback)
    if not modem then
        return {
            success = false,
            message = "Modem not initialized"
        }
    end

    -- リクエストメッセージの作成
    local requestMsg = {
        type = requestType
    }

    -- 追加パラメータの設定
    if params then
        for k, v in pairs(params) do
            requestMsg[k] = v
        end
    end

    -- リクエストの送信
    modem.transmit(serverChannel, clientChannel, requestMsg)

    -- コールバック関数が指定されている場合は非同期処理
    if callback then
        -- 非同期処理の実装（必要に応じて）
        return true
    end

    -- 同期処理：レスポンスを待機
    local timer = os.startTimer(serverTimeout)
    while true do
        local event, param1, param2, param3, message, distance = os.pullEvent()

        if event == "modem_message" and param2 == clientChannel and param3 == serverChannel then
            -- レスポンス受信
            return message
        elseif event == "timer" and param1 == timer then
            -- タイムアウト
            return {
                success = false,
                message = "Server timeout"
            }
        end
    end
end

-- インベントリ一覧の取得
function request.getInventories(forceRefresh)
    return request.send("GET_INVENTORIES", {
        forceRefresh = forceRefresh
    })
end

-- インベントリ内のアイテム一覧の取得
function request.getItems(inventoryName, forceRefresh)
    return request.send("GET_ITEMS", {
        inventory = inventoryName,
        forceRefresh = forceRefresh
    })
end

-- アイテムの転送
function request.transferItem(sourceInv, destInv, slot, count)
    return request.send("TRANSFER_ITEM", {
        source = sourceInv,
        destination = destInv,
        slot = slot,
        count = count
    })
end

-- すべてのアイテムの転送
function request.transferAllItems(sourceInv, destInv)
    return request.send("TRANSFER_ALL", {
        source = sourceInv,
        destination = destInv
    })
end

-- インベントリ名の設定
function request.setInventoryName(inventoryId, displayName)
    return request.send("SET_INVENTORY_NAME", {
        inventoryId = inventoryId,
        displayName = displayName
    })
end

-- 設定値の取得
function request.getConfig()
    return {
        serverChannel = serverChannel,
        clientChannel = clientChannel,
        serverTimeout = serverTimeout
    }
end

return request
