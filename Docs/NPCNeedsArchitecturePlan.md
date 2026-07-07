# NPC欲求システム設計メモ

## 目的

ロビン以外のAIキャラクターも、ロビンと同じ欲求を持てるようにする。
ただし、最初から全NPCを常時AI更新しない。
軽量、安全、モジュール式を優先する。

## 現状の使える土台

- `Scenes/Characters/Modules/AICharacterNeedsBundle.tscn`
  - `CharacterNeedsModule`
  - `GameClockNeedsBridge`
  - `NeedDrivenAIPlanner`
  - `CharacterMoodModule`
  - 欲求からムードへ変換するBridge群

- `Scripts/Systems/Needs/CharacterNeedsModule.gd`
  - 欲求値の保持、増減、最低欲求取得を担当する。
  - `process_fallback_enabled` は初期値falseなので、通常は毎フレーム処理しない。

- `Scripts/Systems/Needs/GameClockNeedsBridge.gd`
  - `/root/GameClock.minute_changed` に接続して、ゲーム内1分ごとに欲求をtickする。
  - `_process` ではなく時計イベントで動くので軽い。

- `Scripts/Systems/Needs/NeedDrivenAIPlanner.gd`
  - 一番低い欲求から次の行動IDを返す。
  - `low_only = true` なら、欲求が低くない時はIDLEになる。

## 方針

### 1. NPCは「表示データ」と「実体」を分ける

住人ページは、まず `NpcResidentData` のような軽量Resourceを読む。
画面上に実体がいないNPCでも、住人ページには表示できる。

実体Actorを作る段階になったら、そのActorへ欲求Bundleを付ける。
住人ページは、実体が存在する時だけ実体の欲求値や現在行動を参照する。
実体が存在しない時は、Resource側の静的な様子テキストを表示する。

### 2. 欲求は各NPCに1つずつ持たせる

各NPC Actorに `AICharacterNeedsBundle.tscn` を子として置く。
同じ欲求定義を共有しつつ、値そのものはActorごとの `CharacterNeedsModule` が持つ。

最初はジッピーだけで試す。
NPCが増えても、同じBundleを追加していくだけにする。

### 3. 欲求更新はGameClockベースにする

NPCごとに `_process` で欲求を減らさない。
既存の `GameClockNeedsBridge` を使い、ゲーム内1分ごとのイベントでだけ更新する。

少人数なら、各NPCのBridgeが `/root/GameClock.minute_changed` に接続する方式で十分軽い。
人数が増えて重くなったら、後から `NPCNeedsTickHub` のような中央管理に差し替える。

### 4. 行動決定は毎フレームしない

`NeedDrivenAIPlanner.get_next_action_id()` は、以下のタイミングでだけ呼ぶ。

- 欲求がlow/criticalになった時
- 今の行動が終わった時
- 住人ページを開いて表示更新する時
- デバッグ更新時

毎フレーム全NPCの行動を考えない。

### 5. 見えていないNPCは省略処理にする

画面上にいないNPCは、欲求値だけ進める。
移動・アニメ・経路探索・家具探索はしない。

必要になった時だけ、以下の順番で段階的に起動する。

1. 住人ページ表示用データだけ
2. 欲求値だけ持つNPC
3. 部屋内に立つだけのNPC
4. 低頻度の欲求行動
5. 家具・会話・関係値イベント

## ジッピー実装の初期案

### 追加予定ファイル

```text
Scenes/Characters/Zippy/ZippyActor.tscn
Scripts/Characters/Zippy/ZippyActor.gd
Data/NPC/Residents/Npc_Zippy.tres
Data/NPC/Relationships/Relationship_Zippy_Robin.tres
```

### ZippyActorの構成案

```text
ZippyActor : CharacterBody2D
  Sprite2D
  ClickArea2D
  AICharacterNeedsBundle
  ZippyIdleModule
  ZippyNeedActionModule
```

最初からロビンの全機能をコピーしない。
まずはクリック、立ち絵、欲求Bundle、住人ページ反映だけにする。

## 安全ルール

- ロビンの既存コードを壊さない。
- 既存のRobinWanderActorへNPC汎用化を急いで入れない。
- 最初は新規ZippyActorで小さく試す。
- 欲求更新は時計イベントのみ。
- 経路探索や家具検索は必要になるまで入れない。
- 住人ページは表示専用。NPCの本体処理を直接重くしない。

## 次の小さな実装候補

1. `ZippyActor.tscn` を作る。
2. `AICharacterNeedsBundle.tscn` をZippyActorに追加する。
3. 住人ページで、実体がいる時だけジッピーの現在欲求を1行表示する。
4. 行動はまだしない。まず値が安全に減るかだけ見る。
