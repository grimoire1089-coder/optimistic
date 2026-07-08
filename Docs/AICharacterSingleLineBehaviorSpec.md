# AI Character Single Line Behavior Spec

作成日: 2026-07-08

この仕様書は、AIキャラクターが増えても処理が重くならず、挙動が破綻しにくいようにするための基本設計をまとめる。

本プロジェクトでは、AIキャラクターの行動は **1キャラクター1ライン** を原則とする。

つまり、1体のAIキャラクターは同時に複数の行動を走らせない。

```text
考える → 1つの行動を決める → 行動する → 終了処理 → また考える
```

この流れを繰り返す。

---

## 目的

- AIキャラクターが増えてもFPSを落としにくくする。
- 各行動モジュールが勝手に動き出して競合する状態を避ける。
- キャラクター本体スクリプトを薄く保つ。
- 行動の開始、継続、完了、キャンセルを追いやすくする。
- デバッグログと経路表示で、現在の行動を一目で確認できるようにする。
- 将来的なResource型コンポーネントシステムへ移行しやすくする。

---

## 絶対ルール

### 1. 1体のAIキャラクターが同時に持てる active 行動は1つだけ

許可される状態は以下。

```text
Idle / Thinking
ActiveAction: Hydrate
ActiveAction: Sit
ActiveAction: Sleep
ActiveAction: Hygiene
ActiveAction: ReadBook
ActiveAction: Craft
ActiveAction: EntranceTravel
```

禁止される状態は以下。

```text
Hydrate と Sit が同時に active
Sleep と Wander が同時に active
Craft と ReadBook が同時に active
複数の行動モジュールが毎フレームそれぞれ移動判断する
```

1つの行動が移動を担当している間、他の行動は移動を要求しない。

---

### 2. 次の行動を考えるのは「行動の切れ目」だけ

毎フレーム、全行動候補を評価し続けない。

次のタイミングだけで再思考する。

- 現在の行動が完了した。
- 現在の行動が失敗した。
- 現在の行動がキャンセルされた。
- ターゲット家具が消えた、移動した、使用不能になった。
- プレイヤー命令など、明示的な割り込みが入った。
- デバッグ用リセットが実行された。

通常の行動中は、決めた行動を最後まで進める。

---

### 3. 行動中に毎フレーム家具候補を再探索しない

行動開始時に、必要なターゲットを固定する。

例。

- 水分補給: 使うキッチン、または使う椅子とテーブルを固定する。
- 着席: 使う椅子を固定する。
- 睡眠: 使う寝具、または床睡眠位置を固定する。
- 読書: 使う座席、読む本、読書位置を固定する。
- 制作: 使う作業台、レシピ、数量を固定する。

行動中に無効化された場合だけ、失敗または再計画する。

---

### 4. 移動を所有する行動は1つだけ

現在の active 行動だけが、以下を行える。

- `velocity` を決める。
- `move_and_slide()` 相当の移動要求を出す。
- 進行方向を決める。
- 経路デバッグ表示の情報を出す。

Actor本体は、active 行動から受け取った結果を反映するだけにする。

---

### 5. 行動完了後は必ず cleanup する

行動が終わったら、以下を必ず片付ける。

- 椅子や家具の予約meta。
- 経路セル。
- ターゲット家具参照。
- 表示中のアイテム。
- 進捗バー。
- 一時的なz_index変更。
- 再生中扱いのSFX状態。
- actor参照やキャッシュ参照。

Resource型へ移行する場合は、`unbind()` でActor参照を必ず外す。

---

## 基本フロー

AIキャラクターは以下の状態機械で動く。

```text
Idle
  ↓
Think
  ↓
ActionStart
  ↓
ActionRunning
  ↓
ActionComplete / ActionFailed / ActionCanceled
  ↓
Cleanup
  ↓
Idle
```

### Idle

何もしていない状態。

短い待機時間を持ってもよい。

### Think

次の行動を1つだけ決める。

このタイミングで、必要度、現在地、家具状態、インベントリ、スキル、プレイヤー命令などを見る。

### ActionStart

決めた行動を開始する。

ここでターゲット家具、使用セル、必要アイテム、経路などを確定する。

### ActionRunning

決めた行動だけを進める。

この間、他の行動候補は動かない。

### ActionComplete

正常終了。

欲求回復、経験値付与、アイテム消費、ログ追加などを行う。

### ActionFailed

失敗終了。

ターゲットが使えない、経路がない、必要アイテムがないなど。

失敗時も cleanup は必ず行う。

### ActionCanceled

外部要因で中断。

プレイヤー命令、マップ移動、デバッグリセットなど。

---

## 行動選択の考え方

行動候補は、全員が勝手に実行するのではなく、BrainまたはActionRunnerが1つ選ぶ。

候補は以下のような関数を持つ想定。

```gdscript
func can_start(context: AICharacterActionContext) -> bool
func get_score(context: AICharacterActionContext) -> float
func start(context: AICharacterActionContext) -> bool
func tick(context: AICharacterActionContext, delta: float) -> AICharacterActionTickResult
func cancel(context: AICharacterActionContext) -> void
func cleanup(context: AICharacterActionContext) -> void
```

`get_score()` は毎フレーム呼ばない。

原則、Thinkタイミングだけで呼ぶ。

---

## 行動優先度の基本案

優先度は、固定順序とスコアの組み合わせにする。

例。

1. プレイヤー命令
2. 進行中の必須イベント
3. 生命維持系の欲求
4. 作業予約
5. 生活行動
6. 余暇行動
7. 徘徊
8. 待機

ただし、1キャラクター1ラインなので、選ばれる行動は常に1つだけ。

---

## Resource型コンポーネントへ移行する場合のルール

### Runtime状態を共有Resourceに持たせない

`.tres` を複数キャラで共有すると、状態が混ざる危険がある。

そのため、Actorに登録されたコンポーネントは実行時に複製して使う。

```gdscript
var runtime_component := component.duplicate(true) as AICharacterComponent
```

または、必要に応じて `resource_local_to_scene = true` を使う。

### Actor参照はbind/unbindで管理する

Resourceは自分の所有者を自動では知らない。

そのため、必ず手動で紐付ける。

```gdscript
func bind(actor: Node) -> void:
	_actor = actor

func unbind() -> void:
	_actor = null
```

循環参照やメモリリークを避けるため、終了時は必ず `unbind()` する。

### Nodeが必要なものは無理にResource化しない

以下はNodeのままでよい。

- `CharacterBody2D`
- `Sprite2D`
- `Area2D`
- `CollisionShape2D`
- HUD
- 進捗バー表示
- 実際に画面に出るアイテム表示
- SceneTreeに直接ぶら下げる必要がある視覚演出

Resource化する候補は、行動判断、状態遷移、ターゲット選択、移動計画などのロジック部分。

---

## Actor本体の理想形

Actor本体は、以下だけを担当する。

- クリック選択。
- SpriteやCollisionなど実体Nodeの保持。
- active actionの実行結果を反映する。
- HUDに現在状態を渡す。
- 外部からの命令をBrain/Runnerへ渡す。

Actor本体に、全行動の長いifチェーンを増やし続けない。

理想は以下。

```gdscript
func _physics_process(delta: float) -> void:
	_ai_runner.physics_update(delta)
```

またはResource配列方式なら以下。

```gdscript
func _physics_process(delta: float) -> void:
	_action_runner.physics_update(delta)
```

---

## ActionRunnerの責務

ActionRunnerは、1キャラクターにつき1つだけ存在する。

責務は以下。

- 現在のactive actionを保持する。
- active actionがないときだけThinkする。
- actionの開始、tick、完了、失敗、キャンセル、cleanupを管理する。
- 他の行動が同時にactiveにならないようにする。
- デバッグ用に現在の行動名を返す。

---

## デバッグ表示のルール

デバッグ表示は、現在のactive actionだけを表示する。

表示したい情報。

- actor名
- current_action_id
- phase
- target_cell
- next_cell
- path length
- footprint
- target furniture name
- fail reason

複数行動の経路を同時表示しない。

---

## 既存モジュールからの移行方針

既存の行動Nodeを一気に削除しない。

移行は以下の順で行う。

1. 仕様書だけ追加する。
2. 新規の `AICharacterActionRunner` を追加する。
3. ジッピーなど、影響範囲が小さいAIキャラで試す。
4. 既存Node行動をラップして、1ライン制御だけ先に導入する。
5. 安定した行動からResource型へ移す。
6. ロビン本体の大きな移行は最後にする。

---

## 最初に移行しやすい候補

### 1. 待機 / 徘徊

副作用が少ないため、最初に試しやすい。

### 2. 着席

家具予約とcleanupの確認に向いている。

### 3. 水分補給

インベントリ、家具、欲求回復、アイテム表示が絡むため、1ライン設計の検証に向いている。

ただし、既存機能を壊さないように最後まで慎重に移す。

---

## 禁止事項

- 関係ないコードを消さない。
- 既存の安定している行動を一気に置き換えない。
- 各行動モジュールが毎フレーム勝手に `is_active()` 判定して動き出す構造を増やさない。
- 毎フレーム全家具を総当たりで探し続けない。
- 毎フレーム全行動候補のスコア計算をしない。
- Resourceを複数キャラで共有したままruntime状態を持たせない。
- cleanupなしで家具予約、z_index変更、参照キャッシュを残さない。

---

## 完了条件

この仕様に沿ったAIキャラクターは、以下を満たす。

- 1体につきactive actionは常に0個または1個。
- 行動中は再思考しない。
- 行動完了後だけ次の行動を考える。
- 移動担当は現在のactive actionだけ。
- ターゲット家具は行動開始時に固定される。
- 無効化された場合のみ失敗または再計画する。
- cleanupで予約、表示、参照を必ず片付ける。
- デバッグ表示で現在の1行動だけを追える。
- Actor本体は薄く、行動ロジックはRunnerまたはComponent側にある。

---

## 合言葉

```text
1キャラクター、1ライン、1アクション。
終わったら考える。決めたら最後までやる。
```
