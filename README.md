# 落閘

第一人稱 3D 決鬥遊戲。在乾掉的水庫底，用你自己改的傢伙，一場一場把閘門打開。

> **改版中**：遊戲正要改成西部決鬥《六響》。新企劃在 [docs/GDD.md](docs/GDD.md)，待確認；目前的程式仍是舊版《落閘》。

- 新企劃（草案）：[docs/GDD.md](docs/GDD.md)
- 舊企劃：[docs/archive/](docs/archive/)
- 引擎：Godot 4.4（Compatibility 渲染器）。所有場景、模型、動作都由程式產生，沒有美術素材檔。

## 執行

1. 安裝 [Godot 4.4](https://godotengine.org/download)（標準版即可）。
2. 用 Godot 開啟這個資料夾的 `project.godot`，第一次會自動匯入音效。
3. 按 F5。

## 操作

| 動作 | 鍵鼠 | 手把 |
|---|---|---|
| 移動 / 視角 | WASD / 滑鼠 | 左搖桿 / 右搖桿 |
| 攻擊（按住＝重擊）/ 開槍 | 左鍵 | RT |
| 格擋（剛按下的瞬間＝彈反）/ 瞄準 | 右鍵 | LT |
| 閃避（按住＝衝刺） | 空白鍵 | B |
| 換手（近戰 ⇄ 槍） | Q / 滾輪 | Y |
| 卸件 | F | LB |
| 第二核心 | G | 十字鍵下 |
| 奇械 | E | RB |
| 喝水（近戰時）/ 裝填（持槍時） | R | 十字鍵上 / X |
| 互動 / 處決 | V / 滑鼠側鍵 | 右搖桿按下 |
| 跳 | Ctrl | A |
| 暫停 | Esc | Start |

工棚裡走到東西前面按互動鍵。介面內用 WASD 選、左鍵確認、右鍵返回。

## 目錄

- `src/combatant.gd`：戰鬥規則，玩家和 Boss 共用
- `src/data.gd`：武器、零件、Boss 招式表、台詞
- `src/ai.gd`、`src/body.gd`、`src/rig.gd`：Boss 的腦、身體、骨架
- `src/player.gd`：輸入、鏡頭、第一人稱手部
- `src/fight.gd`、`src/cine.gd`：一場決鬥與演出
- `src/hub.gd`：工棚（改槍、鍛造、調校、武器架、筆記本、選項）
- `src/arena.gd`、`src/objs.gd`：場地與場上物件
- `tools/gen_audio.py`：產生 `audio/` 下所有音效、音樂、語音音節

## 測試

```
godot --headless --path . -- --test parse            # 載入所有腳本
godot --headless --path . -- --test sim bao 0.6 5    # 用機器人打 5 場老鮑
```

## 連線對戰

暫緩。程式已有直連版本，把 `src/game.gd` 的 `ONLINE` 改成 `true` 就會在工棚開出對戰的門。
