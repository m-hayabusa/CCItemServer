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

-- すべての面のレッドストーン状態を取得する関数
function getRedstoneStates()
    local states = {}
    for _, side in ipairs(redstone.getSides()) do
        states[side] = redstone.getInput(side)
    end
    return states
end

-- レッドストーン状態が変化したかチェックする関数（LOWからHIGHへの変化のみ）
function checkRedstoneRisingEdge(oldStates, newStates)
    for side, newState in pairs(newStates) do
        -- LOWからHIGHに変化した面があるか確認
        if not oldStates[side] and newState then
            return true, side
        end
    end
    return false, nil
end

-- Main process
function main()
    logMessage("Starting automatic transfer")
    logMessage("Source: " .. SOURCE_INVENTORY)
    logMessage("Destination: " .. DEST_INVENTORY)
    logMessage("Transfer interval: " .. TRANSFER_INTERVAL .. " seconds")
    logMessage("Press any key to launch the interactive client")
    logMessage("Redstone signal will trigger transfer")

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

    -- レッドストーンの初期状態を記録
    local lastRedstoneStates = getRedstoneStates()

    -- Main loop
    while true do
        local timer = os.startTimer(TRANSFER_INTERVAL)
        logMessage("Waiting " .. TRANSFER_INTERVAL .. " seconds until next transfer")
        logMessage("Press any key to launch the interactive client")

        -- イベントを待機
        while true do
            local event, param = os.pullEvent()

            if event == "key" then
                -- キー入力があった場合、itemClientを起動
                logMessage("Key pressed, launching itemClient...")
                shell.run("./itemClient")
                logMessage("itemClient exited.")
            elseif event == "timer" and param == timer then
                -- タイマーイベント：転送処理を実行
                logMessage("Timer triggered, starting transfer...")
                break
            elseif event == "redstone" then
                -- レッドストーン信号の変化を検出
                local currentStates = getRedstoneStates()
                local changed, side = checkRedstoneRisingEdge(lastRedstoneStates, currentStates)

                -- LOWからHIGHに変化した面がある場合、処理を実行
                if changed then
                    logMessage("Triggered redstone on " .. side .. ", starting transfer...")
                    break
                end

                -- 状態を更新
                lastRedstoneStates = currentStates
            end
        end

        logMessage("Starting transfer cycle...")

        -- Transfer all items
        local transferResponse = request.transferAllItems(SOURCE_INVENTORY, DEST_INVENTORY)

        if transferResponse.success then
            logMessage("Transfer completed successfully")
        else
            logMessage("Error occurred during transfer: " .. transferResponse.message)
        end
    end
end

-- Run the program
main()
