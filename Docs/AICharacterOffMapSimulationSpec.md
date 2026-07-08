# AI Character Off Map Simulation Spec

作成日: 2026-07-08

この文書は、マップ外にいるAIキャラクターを軽量に処理するための設計仕様である。

本プロジェクトでは、マップ内のAIキャラクターとマップ外のAIキャラクターを同じ重さで処理しない。

```text
マップ内AI: 見えるので細かく動かす。
マップ外AI: 見えないので軽く進める。
```

---

## 目的

- AIキャラクターが増えてもFPSを落としにくくする。
- マップ外AIに物理移動、Sprite更新、家具探索、経路探索をさせない。
- マップ外でも欲求、関係値、簡易行動、予定、回復を進める。
- 将来的に街全体の住民シミュレーションへ拡張できる形にする。
- 1キャラクター1ライン設計と矛盾しないようにする。

---

## 基本方針

### 1. マップ内AIとマップ外AIは処理レイヤーを分ける

### マップ内AI

実際にSceneTree上にいるAIキャラクター。

処理してよいもの。

- Sprite表示。
- Animation。
- Collision。
- Area入力。
- 物理移動。
- 家具探索。
- 経路探索。
- ActionRunnerによる1行動処理。
- 画面上のアイテム表示。
- 進捗バー。

### マップ外AI

現在表示中のマップに存在しないAIキャラクター。

処理してはいけないもの。

- Sprite生成。
- CharacterBody2D生成。
- Collision生成。
- 物理移動。
- `move_and_slide()`。
- 毎フレーム処理。
- 毎分ごとの細かい行動tick。
- 家具総当たり探索。
- 経路探索。
- 表示用Node生成。

マップ外AIは、Resourceまたは軽量データだけで進める。

---

## マップ外AIの処理単位

マップ外AIは、原則として **ゲーム内1時間単位** で処理する。

```text
GameClock hour_changed
  ↓
OffMapAISimulationSystem
  ↓
数キャラずつ処理
  ↓
欲求・関係値・簡易行動結果を更新
```

ただし、全員を同じフレームで処理しない。

AIキャラクターが増えた場合に備えて、分割処理する。

例。

```text
1時間目: A, B, C, D を処理
2時間目: E, F, G, H を処理
3時間目: I, J, K, L を処理
```

または、1時間の中で数フレームに分ける。

```text
hour_changed を受け取る
  ↓
処理待ちキューへ追加
  ↓
1フレームにつき最大 N 人だけ処理
```

---

## 欲求処理

マップ内AIは、現在どおりゲーム内1分ごとに欲求を減らしてよい。

マップ外AIは、1時間単位でまとめて減らす。

式は同じ考え方にする。

```text
減少量 = decay_per_game_minute * 経過ゲーム内分
```

1時間分なら以下。

```text
減少量 = decay_per_game_minute * 60
```

これにより、マップ内とマップ外で欲求の時間経過が大きくズレない。

---

## マップ外AIの簡易行動

マップ外AIは、1キャラクター1ラインの考え方を簡略化して使う。

```text
状態を見る
  ↓
必要なら1つだけ簡易行動を決める
  ↓
時間ぶんまとめて結果を反映する
```

マップ外では、行動を細かい移動やアニメーションとして実行しない。

例。

### 水分が低い

```text
条件: water が低い
行動: off_map_hydrate
結果: water を一定量回復
副作用: 所持品、クレジット、施設利用記録などを必要に応じて更新
```

### 体力が低い

```text
条件: energy が低い
行動: off_map_rest
結果: energy を一定量回復
副作用: 数時間ぶん他行動をしない扱いにすることも可能
```

### 交流度が低い

```text
条件: social が低い
行動: off_map_socialize
結果: social を一定量回復
副作用: 関係値を少し変化させる
```

### 特に問題がない

```text
行動: off_map_routine
結果: 欲求を少し維持、関係値や気分を軽く変化
```

---

## 関係値処理

マップ外AIは、関係値も軽量に処理する。

毎フレーム処理しない。

基本は以下。

- 1時間単位。
- または数時間単位。
- またはイベント発生時だけ。

例。

```text
同じ施設にいたAI同士: 交流度と関係値が少し上がる
長時間会っていないAI同士: 関係値は基本変えない
イベントが発生したAI同士: 関係値をまとめて更新
```

関係値の更新は、将来的に別システムへ分ける。

候補。

```text
res://Scripts/Characters/Simulation/AICharacterRelationshipSimulation.gd
```

---

## マップ外AIデータの候補

SceneTree上のActorではなく、軽量なデータで持つ。

候補。

```text
AICharacterResidentState
```

持つ情報の例。

```text
resident_id
表示名
現在いる場所ID
現在の簡易行動ID
欲求値
気分ID
関係値
所持品の概要
次にマップへ出す予定
最後に処理したゲーム内時刻
```

Node参照、Sprite参照、家具Node参照、Path配列などは持たない。

---

## 推奨ディレクトリ構成

```text
res://Scripts/Characters/Simulation/
  AICharacterResidentState.gd
  AICharacterOffMapSimulationSystem.gd
  AICharacterOffMapActionResolver.gd
  AICharacterOffMapNeedsSimulator.gd
  AICharacterRelationshipSimulation.gd

res://Data/Characters/Residents/
  ZippyResidentState.tres
  RobinResidentState.tres
  CommonResidentDefaults.tres
```

最初から全部作らない。

まずは仕様と、最小の `AICharacterResidentState` だけでよい。

---

## マップ内へ入る時

マップ外AIを現在マップへ出す場合、軽量StateからActorへ状態を反映する。

```text
ResidentState
  ↓
Actor生成
  ↓
欲求値、位置、現在行動などを反映
  ↓
マップ内AIとして通常処理へ切り替え
```

この時点で、マップ外シミュレーション対象から外す。

二重に欲求が減らないようにする。

---

## マップ外へ出る時

Actorが現在マップから消える場合、Actor状態をResidentStateへ保存する。

```text
Actor
  ↓
ResidentStateへ保存
  ↓
Actor Nodeを解放
  ↓
マップ外AIとして軽量処理へ戻す
```

この時点で、SceneTree上の子Nodeや行動Nodeは持たない。

---

## 二重処理禁止

同じAIキャラクターを、マップ内処理とマップ外処理の両方で同時に進めない。

禁止例。

```text
Zippy ActorがSceneTreeにいる
かつ
Zippy ResidentStateもOffMapSimulationでtickされる
```

必要な判定。

```text
resident_id が現在マップ内Actorとして存在するか
```

存在するなら、OffMapSimulationでは処理しない。

---

## 処理負荷対策

### 1. 毎フレーム全員処理しない

マップ外AIは、ゲーム内時間の節目で処理する。

### 2. 一度に全員処理しない

人数が多い場合はキューに積んで、1フレーム数人ずつ処理する。

例。

```gdscript
@export var max_residents_per_frame: int = 4
```

### 3. 家具探索しない

マップ外では家具Nodeを探さない。

施設IDや場所IDだけで判定する。

### 4. Pathfindingしない

マップ外では経路を求めない。

「その施設にいる扱い」だけでよい。

### 5. 表示Nodeを作らない

マップ外AIにSprite、ProgressBar、ItemDisplayを作らない。

---

## 既存の欲求処理との関係

現在の `CharacterNeedsModule` は、ゲーム内分数を受け取って欲求を減らす設計になっている。

```text
tick_game_minutes(game_minutes)
```

この考え方はマップ外処理にも使える。

ただし、マップ外AIはNodeとしての `CharacterNeedsModule` を持たず、軽量State上で同じ計算をする方がよい。

最初の実装では、既存の `NeedDefinition.decay_per_game_minute` を読むだけにする。

---

## 最初の実装案

最初はコードを大きくしない。

### Phase 1

- `AICharacterOffMapSimulationSpec.md` を追加する。
- まだゲームコードは変えない。

### Phase 2

- `AICharacterResidentState.gd` を作る。
- resident_id、display_name、location_id、needs を持つ。

### Phase 3

- `AICharacterOffMapNeedsSimulator.gd` を作る。
- `decay_per_game_minute * 経過分` で欲求をまとめて減らす。

### Phase 4

- `AICharacterOffMapSimulationSystem.gd` を作る。
- GameClock の `hour_changed` を受けて処理キューを作る。
- 1フレーム数人ずつ処理する。

### Phase 5

- マップ内Actorがいるresident_idは処理対象から外す。

### Phase 6

- 関係値や簡易行動を追加する。

---

## 完了条件

マップ外AIシミュレーションは、以下を満たす。

- マップ外AIはSceneTreeに存在しない。
- マップ外AIは毎フレーム行動しない。
- マップ外AIはゲーム内1時間単位などで軽量処理される。
- 大人数の場合は数キャラずつ分割処理される。
- 欲求減少は `decay_per_game_minute * 経過分` でマップ内と整合する。
- マップ内Actorが存在するAIはマップ外処理されない。
- マップ内へ出す時にResidentStateからActorへ状態反映できる。
- マップ外へ出す時にActorからResidentStateへ状態保存できる。

---

## 合流方針

この仕様は、以下の既存方針と組み合わせる。

- 1キャラクター1ライン。
- ActionRunner。
- 行動パッケージ。
- Resource型コンポーネント。

ただし、マップ外ではActionRunnerをそのまま動かさない。

マップ外では、ActionRunnerの思想だけを使って、軽量な `OffMapActionResolver` が1つの簡易行動を選ぶ。

```text
マップ内: Runnerが選び、Packageがやり切る。
マップ外: Resolverが選び、Stateに結果だけ反映する。
```
