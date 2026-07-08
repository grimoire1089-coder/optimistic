# AI Character Action Package Spec

作成日: 2026-07-08

この文書は、AIキャラクターの行動を **1行動単位でパッケージ化** するための仕様である。

`AICharacterSingleLineBehaviorSpec.md` の「1キャラクター1ライン」と、`AICharacterComponentImplementationPlan.md` の「本体は薄く、機能は部品」を実装へ落とし込むために使う。

---

## 基本思想

AIキャラクターの行動は、以下のように1つずつ独立したパッケージとして扱う。

```text
HydrateActionPackage
SitActionPackage
SleepActionPackage
HygieneActionPackage
ReadBookActionPackage
CraftActionPackage
WanderActionPackage
EntranceTravelActionPackage
```

1つの行動パッケージは、1つの行動だけに責任を持つ。

水分補給パッケージは水分補給だけ。

着席パッケージは着席だけ。

制作パッケージは制作だけ。

他の行動の開始、停止、優先度判断を直接行わない。

---

## 絶対ルール

### 1. 1パッケージ = 1行動

1つの行動パッケージに複数の行動を詰め込まない。

禁止例。

```text
HydrateActionPackage の中で着席行動を直接完結させる
SitActionPackage の中で読書行動を開始する
CraftActionPackage の中で睡眠不足チェックから睡眠を開始する
```

許可例。

```text
HydrateActionPackage が「飲むために椅子を使う」
ReadBookActionPackage が「読むために椅子を使う」
```

この場合、椅子の使用は行動の一部だが、別の `SitAction` を開始しているわけではない。

---

### 2. パッケージは自分の開始、継続、終了、片付けだけを持つ

各パッケージは以下を持つ。

```text
can_start
get_score
start
tick
cancel
cleanup
get_debug_summary
```

行動を選ぶのはActionRunnerまたはBrain。

パッケージ自身が他パッケージを選んだり起動したりしない。

---

### 3. パッケージ間で直接参照しない

行動パッケージ同士は、原則として直接参照しない。

禁止例。

```gdscript
var sit_action := get_node("../SitActionPackage")
sit_action.start(...)
```

必要な共通機能は、共通HelperまたはContext経由で使う。

例。

```text
AICharacterActionContext
AICharacterMovementHelper
AICharacterFurnitureUseHelper
AICharacterSeatReservationHelper
AICharacterInventoryAccessHelper
```

---

### 4. 行動中のランタイム状態はパッケージ内に閉じる

行動中に必要な一時状態は、その行動パッケージが持つ。

例。

水分補給。

```text
_target_kitchen
_target_dining_seat
_target_cell
_path_cells
_drink_timer
_drink_food_data
_saved_body_z_index
```

着席。

```text
_target_chair
_target_cell
_path_cells
_sit_timer
_reserved_chair_id
```

制作。

```text
_target_workbench
_recipe
_quantity
_craft_timer
_reserved_station_id
```

行動が終わったら必ずcleanupで消す。

---

### 5. 表示系は行動パッケージから直接生成しすぎない

進捗バー、アイテム表示、吹き出しなどは、可能なら表示専用モジュールへ依頼する。

行動パッケージは、表示に必要な情報を返す。

```text
is_progress_visible
progress_ratio
is_item_display_visible
item_icon_path
display_text
```

実際のNode生成や表示位置調整は、表示モジュール側に寄せる。

---

## 推奨ディレクトリ構成

最終的には以下を目指す。

```text
res://Scripts/Characters/Actions/
  Core/
    AICharacterActionResult.gd
    AICharacterActionContext.gd
    AICharacterActionRunner.gd
    AICharacterActionPackage.gd
    AICharacterNodeActionAdapter.gd

  Packages/
    Wander/
      AICharacterWanderActionPackage.gd
      AICharacterWanderActionConfig.gd

    Sit/
      AICharacterSitActionPackage.gd
      AICharacterSitActionConfig.gd

    Hydrate/
      AICharacterHydrateActionPackage.gd
      AICharacterHydrateActionConfig.gd

    Sleep/
      AICharacterSleepActionPackage.gd
      AICharacterSleepActionConfig.gd

    Hygiene/
      AICharacterHygieneActionPackage.gd
      AICharacterHygieneActionConfig.gd

    ReadBook/
      AICharacterReadBookActionPackage.gd
      AICharacterReadBookActionConfig.gd

    Craft/
      AICharacterCraftActionPackage.gd
      AICharacterCraftActionConfig.gd

    EntranceTravel/
      AICharacterEntranceTravelActionPackage.gd
      AICharacterEntranceTravelActionConfig.gd
```

最初から全部作らない。

まずは `Core` と `Wander` だけでよい。

---

## ActionPackageの基本インターフェース案

将来的なResource型コンポーネント化を見据え、ActionPackageはResourceベースを基本候補にする。

```gdscript
extends Resource
class_name AICharacterActionPackage

@export var action_id: StringName = &"idle"
@export var display_name: String = "待機"
@export var priority: int = 0

var _actor: Node

func bind(actor: Node) -> void:
	_actor = actor

func unbind() -> void:
	cleanup(null)
	_actor = null

func can_start(context: AICharacterActionContext) -> bool:
	return false

func get_score(context: AICharacterActionContext) -> float:
	return 0.0

func start(context: AICharacterActionContext) -> bool:
	return false

func tick(context: AICharacterActionContext, delta: float) -> AICharacterActionResult:
	return AICharacterActionResult.completed()

func cancel(context: AICharacterActionContext) -> void:
	pass

func cleanup(context: AICharacterActionContext) -> void:
	pass

func get_debug_summary() -> String:
	return String(action_id)
```

実装初期はNode版Adapterで包んでもよい。

---

## ConfigとRuntime Stateを分ける

行動パッケージは、できるだけ以下の2つを分ける。

### Config

エディタで調整する値。

```text
walk_speed
arrival_distance
duration_range
need_threshold
cooldown_seconds
sfx_path
item_path
```

### Runtime State

実行中だけ変わる値。

```text
is_active
target_node
target_cell
path_cells
timer
reserved_meta_id
cached_refs
```

Resource共有事故を避けるため、Runtime Stateを共有 `.tres` に残さない。

Actorに渡すときは実行時複製する。

```gdscript
var runtime_package := package.duplicate(true) as AICharacterActionPackage
runtime_package.bind(actor)
```

---

## NodeActionAdapterとの関係

既存Nodeモジュールをすぐ消さないため、移行初期は以下の形を許可する。

```text
ActionRunner
  ↓
NodeActionAdapter
  ↓
既存Node行動モジュール
```

ただし、これは移行用の橋渡しである。

最終的には以下へ寄せる。

```text
ActionRunner
  ↓
Resource ActionPackage
  ↓
必要な共通Helper / 表示モジュール / Actor API
```

---

## パッケージの完了条件

1つの行動パッケージは、以下を満たして完成とする。

- `can_start()` で開始可能か判定できる。
- `get_score()` でRunnerが選択判断できる。
- `start()` でターゲットと必要状態を固定できる。
- `tick()` で1フレーム分だけ進められる。
- `completed / failed / canceled` を返せる。
- `cancel()` で外部中断できる。
- `cleanup()` で予約、表示、参照、経路、z_indexを片付けられる。
- `get_debug_summary()` で現在状態を説明できる。
- 他の行動パッケージを直接起動しない。
- 毎フレーム全家具や全候補を総当たりしない。

---

## 既存行動ごとのパッケージ境界

### WanderActionPackage

責務。

- 待機。
- ランダム移動。
- 移動範囲内の目的地選択。
- 経路保持。
- 移動完了判定。

持たない責務。

- 水分補給の開始。
- 睡眠の開始。
- 着席の開始。

---

### SitActionPackage

責務。

- 座れる椅子を探す。
- 使用椅子を固定する。
- 椅子を予約する。
- 椅子へ移動する。
- 着席時間を進める。
- 予約を解除する。

持たない責務。

- 読書を開始する。
- 水分補給を開始する。

---

### HydrateActionPackage

責務。

- 水分補給が必要か判定する。
- 水分補給対象を固定する。
- 必要ならキッチンや接続席を使う。
- 飲むアイテムを固定する。
- 飲む進捗を進める。
- 欲求回復とアイテム消費を行う。
- 表示用アイテム情報を返す。
- 椅子予約やz_indexをcleanupする。

持たない責務。

- 汎用着席行動を起動する。
- 別行動の優先度を決める。

---

### CraftActionPackage

責務。

- 制作可能か判定する。
- レシピと数量を固定する。
- 作業台を固定する。
- 制作進捗を進める。
- 材料消費と成果物付与を行う。
- 経験値を付与する。

持たない責務。

- 水分不足を見て水分補給を開始する。
- 疲労を見て睡眠を開始する。

それらの判断はRunnerまたはBrainが行う。

---

## 作業単位

今後の実装では、PRまたはチャット作業単位を以下にする。

```text
1作業 = 1行動パッケージの追加または修正
```

例。

```text
OK: WanderActionPackageだけ作る
OK: SitActionPackageのcleanupだけ直す
OK: HydrateActionPackageのtarget固定だけ直す
NG: Wander/Sit/Hydrateを同時に移行する
NG: ActionRunnerと全行動Resource化を同時に行う
```

---

## 合言葉

```text
行動はパッケージ。
パッケージは1責務。
Runnerが選び、Packageがやり切る。
```
