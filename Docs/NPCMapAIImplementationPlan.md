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
- AIキャラクターが立っているグリッドを避ける
- 2x4グリッドの足元を保つ
- クリックでAI HUDを開ける

これだけを安定させる。

### 2. 同時に動くAIを制限する

現段階では、複数AIを同時に動かさない。
`AICharacterMovementCoordinator` で移動枠を1つだけ持ち、誰かが移動中なら他のAIは待機に戻る。

これで、家具探索、グリッド移動、クリック判定、表示デバッグの原因切り分けを簡単にする。

### 3. AIキャラクターのいるグリッドは候補から外す

家具と同じ考え方で、AIキャラクターが占有しているグリッドは経路候補から外す。

現在はまず、同じ `2x4` footprint のAIとして扱う。
将来的にキャラごとにサイズが変わる場合は、`get_actor_grid_footprint()` を全AIに持たせて拡張する。

### 4. ZippyActor本体は薄く保つ

`ZippyActor.gd` に移動や行動を直書きしない。

持たせるのは以下だけ。

- 選択クリック
- HUD連携
- 初期グリッド配置
- モジュール参照
- `_physics_process` で移動モジュールの結果を適用

移動計算、方向決定、経路探索はモジュール側に置く。

### 5. 欲求行動は後回し

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

## 実装済み

```text
Scripts/Characters/Modules/AICharacterMovementCoordinator.gd
Scripts/Characters/Modules/AICharacterRandomWanderModule.gd
Scripts/Characters/Modules/AICharacterDirectionalSpriteModule.gd
Scripts/Characters/Modules/AICharacterInventoryModule.gd
Scripts/Characters/Zippy/ZippyActor.gd
Scenes/Characters/Zippy/ZippyActor.tscn
```

現在のジッピーは、ロビン風のグリッドランダム移動を使う。
遠い目標グリッドへ向かえるが、実際に補間で進む一歩は基本的に1グリッド単位にしている。

## インベントリ名の整理

AIキャラクター共通の正式名は `AICharacterInventoryModule` とする。
ジッピーなど、今後追加するAIキャラクターはこの名前でインベントリを持たせる。

`RobinInventoryModule` は既存のロビン、ショップ、制作、水分補給などの参照を壊さないため、段階的な互換名として残す。
一度に全置換せず、動作確認しながら以下の順で移行する。

1. 新規AIキャラクターは `AICharacterInventoryModule` を使う。
2. ロビンのシーン側も `AICharacterInventoryModule` へ寄せる。
3. 水分補給、制作、ショップ、インベントリUIの型参照を `AICharacterInventoryModule` へ寄せる。
4. 全部安定したら `RobinInventoryModule` は薄い互換エイリアスにする。

## 保留中

### 方向別画像

`AICharacterDirectionalSpriteModule` は作成済み。
ただし、ジッピーの背面・左・右画像がまだ無いため、方向別画像の実確認は後回しにする。

現状は `Zippy_Game_Front.png` だけを使い、未設定方向は正面画像へフォールバックする。
画像が用意できたら、以下のパスを設定して再開する。

```text
Assets/Characters/Zippy/Walk/Zippy_Game_Back.png
Assets/Characters/Zippy/Walk/Zippy_Game_Left.png
Assets/Characters/Zippy/Walk/Zippy_Game_Right.png
```

## 次の実装候補

### Step A: 移動安全性の確認を続ける

確認すること:

- ジッピーがグリッド単位で動くこと。
- ロビンが移動中ならジッピーが待機すること。
- ジッピーがロビンのいる2x4グリッドを目的地にしないこと。
- POS表示で赤枠が2x4のまま保たれること。

### Step B: 座るAIをジッピーへ追加する

画像が不要な次の候補として、既存の `AICharacterSitBehaviorModule` をジッピーへ追加する。

狙い:

- ロビンと同じ家具探索系AIの最初の共通テストにする。
- 椅子・スツール・ソファの使用確認をする。
- まずは短時間座るだけにして、欲求回復や複雑な演出は後で足す。

### Step C: 水分補給AIをジッピーへ追加する

座る動作が安定したら、既存の `AICharacterHydrateBehaviorModule` をジッピーへ追加する。

狙い:

- 欲求に応じて行動する最初の実用AIにする。
- 接続席やテーブル上の飲み物表示と連携できるか確認する。

## 注意点

- ロビンの既存AIは壊さない。
- ZippyActorで新方式を試してから、良ければロビンにも戻す。
- NPCが増えた時に全員が重い行動探索をしないよう、最初はランダム移動だけにする。
- 欲求による家具探索は、少人数で安定してから追加する。
- 画面外NPCは後で省略処理にする。
