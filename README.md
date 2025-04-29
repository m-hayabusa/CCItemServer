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

### サーバー

サーバーコンピュータで以下のコマンドを実行します:

```
./CCItemServer/itemServer
```

startup.luaに記載しておくと自動で起動できます:
```lua
shell.run("CCItemServer/itemServer")
```

### クライアント

クライアントコンピュータで以下のコマンドを実行します:

```
./CCItemServer/itemClient
```

startup.luaに記載しておくと自動で起動できます:
```lua
shell.run("CCItemServer/itemClient")
os.shutdown()
```

### 自動転送

自動転送を設定するには、初回実行時に生成される`autoTransfer.conf`を編集して転送元と転送先のインベントリを指定します:

```properties
{
  transfer_interval = 60,                  // 転送間隔（秒）
  dest_inventory = "minecraft:barrel_0",   // 転送先インベントリのID
  source_inventory = "minecraft:barrel_1", // 転送元インベントリのID
}
```

インベントリのIDは `peripherals` コマンドで確認するか、itemClientのインベントリ一覧 `1. barrel_1 (minecraft:barrel_0)` のような表示の `minecraft:barrel_0` の部分です。

設定後、以下のコマンドで自動転送を開始します:

```
./CCItemServer/autoTransfer
```

startup.luaに記載しておくと自動で起動できます:
```lua
shell.run("CCItemServer/autoTransfer")
```
