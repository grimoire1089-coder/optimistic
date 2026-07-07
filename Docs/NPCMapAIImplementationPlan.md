# NPCマップAI実装計画

## 目的

マップ画面にいるAIキャラクター達を、できる限りロビンと同じように動かす。
ただし、ロビンの実装をそのまま全NPCへコピーしない。
軽量、安全、モジュール式で段階的に共通化する。

## 現状

ロビンは `RobinWanderActor.tscn` に多くの機能モジュールを持っている。

主な分類:

- 移動
  - `RobinRandomWanderModule`
  - `RobinWalkSpriteAnimator`
  - `RobinMovementAreaFrame`
- 欲求
  - `AICharacterNeedsBundle`
- 欲求行動
  - `AICharacterSleepBehaviorModule`
  - `AICharacterHydrateBehaviorModule`
  - `AICharacterHygieneBehaviorModule`
  - `AICharacterSitBehaviorModule`
  - `AICharacterReadBookBehaviorModule`
  - `AICharacterCraftBehaviorModule`
  - `AICharacterEntranceTravelBehaviorModule`
- 表示補助
  - `AICharacterActionProgressBarModule`
  - `AICharacterActionItemDisplayModule`
  - `AICharacterFootprintShapeModule`
  - `AICharacterMovementDebugModule`

この構成は強いが、今のままジッピーへ全コピーすると重くなりやすく、調整も難しくなる。

## 方針

### 1. まずは「歩く・止まる」だけを共通化する

最初のNPCマップAIは、欲求行動ではなくランダム移動から始める。

- グリッド上を歩く
- たまに止まる
- 家具配置を避ける
- 2x4グリッドの足元を保つ
- クリックでAI HUDを開ける

これだけを安定させる。

### 2. RobinRandomWanderModuleを汎用化する

`RobinRandomWanderModule` は中身としてはかなり汎用的で、`setup(body: Node2D)` を受けて動く。
そのため、いきなり別ロジックを作るより、次の方針が安全。

1. 既存ファイルは消さない。
2. `AICharacterRandomWanderModule.gd` を新規作成する。
3. まずは `RobinRandomWanderModule.gd` のロジックを移植する。
4. ロビン側は後で差し替える。
5. ジッピー側は新モジュールで先に試す。

### 3. ZippyActor本体は薄く保つ

`ZippyActor.gd` に移動や行動を直書きしない。

持たせるのは以下だけ。

- 選択クリック
- HUD連携
- 初期グリッド配置
- モジュール参照
- `_physics_process` で移動モジュールの結果を適用

移動計算、方向決定、経路探索はモジュール側に置く。

### 4. 欲求行動は後回し

ジッピーにも `AICharacterNeedsBundle` はある。
ただし、睡眠、給水、シャワー、読書、クラフトなどはまだ付けない。

ランダム移動が安定してから、1つずつ足す。

推奨順:

1. ランダム移動
2. 座る
3. 水分補給
4. 睡眠
5. 清潔
6. 読書
7. クラフト
8. 入口移動

## 次の実装候補

### Step 1: 汎用ランダム移動モジュールを作る

追加予定:

```text
Scripts/Characters/Modules/AICharacterRandomWanderModule.gd
```

役割:

- グリッド移動
- 停止時間と歩行時間の抽選
- 家具配置の回避
- 2x4 footprint対応
- `get_facing_direction()`
- `is_idle()`
- `is_moving()`

### Step 2: ZippyActorへ移動モジュールを追加する

追加・変更予定:

```text
Scenes/Characters/Zippy/ZippyActor.tscn
Scripts/Characters/Zippy/ZippyActor.gd
```

`ZippyActor.gd` では以下だけ行う。

```gdscript
func _physics_process(delta: float) -> void:
    var velocity := wander_module.get_velocity(delta)
    self.velocity = velocity
    move_and_slide()
```

グリッドステップ移動を使う場合は、モジュールが直接位置補間するので `velocity` はゼロでもよい。

### Step 3: 方向別画像モジュールを作る

追加予定:

```text
Scripts/Characters/Modules/AICharacterDirectionalSpriteModule.gd
```

画像は向きごとに別ファイルで持つ。

```text
Assets/Characters/Zippy/Walk/Zippy_Game_Front.png
Assets/Characters/Zippy/Walk/Zippy_Game_Back.png
Assets/Characters/Zippy/Walk/Zippy_Game_Left.png
Assets/Characters/Zippy/Walk/Zippy_Game_Right.png
```

最初は正面だけでも動かす。
左右・背面画像が来たら切り替える。

## 注意点

- ロビンの既存AIは壊さない。
- ZippyActorで新方式を試してから、良ければロビンにも戻す。
- NPCが増えた時に全員が重い行動探索をしないよう、最初はランダム移動だけにする。
- 欲求による家具探索は、少人数で安定してから追加する。
- 画面外NPCは後で省略処理にする。

## 結論

次にやるなら、ジッピーへ「ロビン風のグリッドランダム移動」を入れるのが良い。

ただし、ロビン専用名のまま流用するのではなく、`AICharacterRandomWanderModule` として汎用化してから、ジッピーに接続する。
