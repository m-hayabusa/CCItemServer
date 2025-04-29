# CCItemServer

ComputerCraftのためのアイテム管理システム。複数のインベントリ間でアイテムを転送できます。

## インストール方法

1. サーバーとクライアントのコンピュータを用意します
2. 各コンピュータとインベントリにモデムを取り付け、ネットワークケーブルで接続します
3. cloneします:
    ```
    wget https://gist.github.com/SquidDev/e0f82765bfdefd48b0b15a5c06c0603b/raw/06be706a772fa0a64195be1146bff6360c04d27c/clone.min.lua clone.lua
    clone https://github.com/m-hayabusa/CCItemServer.git
    ```

## 使用方法

### サーバーの起動

サーバーコンピュータで以下のコマンドを実行します:

```
./CCItemServer/itemServer
```

startup.luaに記載しておくと自動で起動できます:
```lua
shell.run("CCItemServer/itemServer")
```

### クライアントの起動

クライアントコンピュータで以下のコマンドを実行します:

```
./CCItemServer/itemClient
```

startup.luaに記載しておくと自動で起動できます:
```lua
shell.run("CCItemServer/itemClient")
os.shutdown()
```

### 自動転送の設定

自動転送を設定するには、`autoTransfer.lua`を編集して転送元と転送先のインベントリを指定します:

```lua
local SOURCE_INVENTORY = "minecraft:barrel_4" -- 転送元インベントリ名
local DEST_INVENTORY = "minecraft:barrel_5" -- 転送先インベントリ名
local TRANSFER_INTERVAL = 60 -- 転送間隔（秒）
```
その後、以下のコマンドで自動転送を開始します:

```
./CCItemServer/autoTransfer
```

startup.luaに記載しておくと自動で起動できます:
```lua
shell.run("CCItemServer/autoTransfer")
```

## 設定

各ファイルの先頭にある設定変数を編集することで、動作をカスタマイズできます:

### サーバー設定 (itemServer.lua)

```lua
local SERVER_CHANNEL = 137 -- 通信チャンネル
local REFRESH_INTERVAL = 30 -- インベントリ更新間隔（秒）
```

### クライアント設定 (itemClient.lua)

```lua
local SERVER_CHANNEL = 137 -- 通信チャンネル
local INACTIVITY_TIMEOUT = 300 -- 非アクティブタイムアウト（秒）
```
