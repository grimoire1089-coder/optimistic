# AI Character Component Implementation Plan

作成日: 2026-07-08

この文書は、`AICharacterSingleLineBehaviorSpec.md` を実装へ移すための段階的な作業計画である。

本プロジェクトでは、AIキャラクターの行動を **1キャラクター1ライン** で管理しつつ、将来的に **Resource型コンポーネントシステム** へ移行できる構成を目指す。

ただし、既存の安定しているNodeモジュールを一気に置き換えない。

```text
本体は薄く。
機能は小さく。
行動は1つずつ。
移行は少しずつ。
```

---

## 基本方針

### 1. 大改造しない

既存の `RobinWanderActor.gd` や既存行動モジュールを一気に書き換えない。

まずは影響範囲が小さいAIキャラクター、または新規AIキャラクターで試す。

### 2. 本体と機能モジュールを分ける

Actor本体は以下に絞る。

- クリック選択。
- 表示Nodeの保持。
- CollisionやAreaなど実体Nodeの保持。
- ActionRunnerへの委譲。
- HUD表示用の情報提供。

行動の詳細は、ActionRunner、Action、Component、または既存Nodeモジュール側に置く。

### 3. 1回に触る機能は1つだけ

1回の作業で、複数行動をまとめて移行しない。

例。

- 徘徊だけ。
- 着席だけ。
- 水分補給だけ。
- 進捗バーだけ。
- アイテム表示だけ。

1つずつ動作確認してから次へ進む。

### 4. 先にRunnerで1ライン制御を作る

Resource型への移行より先に、行動の交通整理を行う。

最初の目標は、既存Node行動を使ったままでも、active actionが常に1つだけになる状態を作ること。

### 5. Resource化は後から行う

Resource型コンポーネントは最終形に近いが、最初から全部Resource化しない。

まずはNode版ActionをRunnerで包む。

安定したら、内部ロジックだけResourceへ移していく。

---

## 目標ディレクトリ案

```text
res://Scripts/Characters/Actions/
  AICharacterActionIds.gd
  AICharacterActionResult.gd
  AICharacterActionContext.gd
  AICharacterActionRunner.gd
  AICharacterNodeActionAdapter.gd

res://Scripts/Characters/Components/
  AICharacterComponent.gd
  AICharacterBehaviorComponent.gd

res://Scripts/Characters/Components/Behaviors/
  AICharacterWanderComponent.gd
  AICharacterSitComponent.gd
  AICharacterHydrateComponent.gd

res://Data/Characters/ComponentSets/
  ZippyComponentSet.tres
  CommonAICharacterComponentSet.tres
```

最初から全部作らない。

まず必要なのは `Actions` 側の最小構成だけ。

---

## 段階的な実装手順

## Phase 0: 仕様固定

完了条件。

- `Docs/AICharacterSingleLineBehaviorSpec.md` がある。
- `Docs/AICharacterComponentImplementationPlan.md` がある。
- 今後のAI行動修正では、1キャラクター1ラインを前提にする。

この段階ではゲームコードを変更しない。

---

## Phase 1: ActionRunnerの土台を作る

目的。

Actor本体から、行動更新処理を1か所へ委譲できるようにする。

追加候補。

```text
res://Scripts/Characters/Actions/AICharacterActionResult.gd
res://Scripts/Characters/Actions/AICharacterActionContext.gd
res://Scripts/Characters/Actions/AICharacterActionRunner.gd
```

最初のRunnerは、まだ高機能にしない。

必要な責務だけ持つ。

- current_action_id を保持する。
- 現在の行動phaseを保持する。
- active actionがなければThinkへ進む。
- actionを1つだけ開始する。
- tick結果を受けてcomplete / failed / canceledへ進む。
- cleanupを呼ぶ。

この段階では、実際の行動はまだ既存Nodeでもよい。

---

## Phase 2: NodeActionAdapterを作る

目的。

既存のNode行動モジュールをすぐ消さず、Runnerから扱えるようにする。

追加候補。

```text
res://Scripts/Characters/Actions/AICharacterNodeActionAdapter.gd
```

Adapterの役割。

- 既存Nodeモジュールへの参照を持つ。
- `can_start()` 相当の判定を行う。
- `start()` で既存モジュールへ開始要求を出す。
- `tick()` で既存モジュールの状態を読む。
- `cancel()` で既存モジュールを止める。
- `cleanup()` で予約や一時状態を片付ける。

これにより、既存Nodeを残したまま1ライン制御へ寄せられる。

---

## Phase 3: ジッピーで最小実験する

目的。

ロビン本体を壊さず、ジッピーで1ライン制御の土台を確認する。

対象候補。

```text
res://Scripts/Characters/Zippy/ZippyActor.gd
res://Scenes/Characters/Zippy/ZippyActor.tscn
```

最初にやること。

- ZippyActorにActionRunner参照を追加する。
- 既存の徘徊、水分補給、着席の処理をすぐ消さない。
- まずはRunnerが現在行動名を返せるだけでもよい。
- 次に、徘徊だけRunner管理へ移す。

完了条件。

- ジッピーが従来通り表示される。
- クリックHUDが壊れない。
- 徘徊が従来通り動く。
- current_action_idが確認できる。
- active actionが複数にならない。

---

## Phase 4: 徘徊行動を1ライン化する

最初に移行する行動は徘徊。

理由。

- 副作用が少ない。
- アイテム消費がない。
- 家具予約がない。
- 失敗時の影響が小さい。

作業方針。

- 徘徊中は他行動を開始しない。
- 徘徊が終わったらThinkへ戻る。
- 徘徊を毎フレーム全行動評価の一部にしない。

完了条件。

- 徘徊開始、徘徊中、徘徊終了がログまたはデバッグで追える。
- 徘徊中に他行動が勝手に移動を奪わない。

---

## Phase 5: 着席行動を1ライン化する

次に着席を移行する。

理由。

- 家具予約とcleanupを検証しやすい。
- 水分補給より副作用が少ない。

重点確認。

- 使う椅子を行動開始時に固定する。
- 着席中に毎フレーム椅子を探し直さない。
- 失敗またはキャンセル時に椅子予約metaを消す。
- 着席中は徘徊が動かない。

完了条件。

- 椅子の予約が残らない。
- 他キャラと椅子予約が競合しない。
- デバッグ表示で着席行動だけを追える。

---

## Phase 6: 水分補給行動を1ライン化する

水分補給は後回しにする。

理由。

- 欲求。
- インベントリ。
- キッチン。
- 椅子とテーブル。
- アイテム表示。
- SFX。
- z_index。

関係するものが多い。

重点確認。

- 開始時に使う対象を固定する。
- 飲む対象アイテムを固定する。
- 飲んでいる間は移動しない。
- 完了時に欲求回復、アイテム消費、表示非表示を整理する。
- 失敗時に予約metaと表示を必ず消す。

完了条件。

- 水分補給中に着席や徘徊が割り込まない。
- 飲食物表示が残らない。
- 椅子予約が残らない。
- z_indexが元に戻る。

---

## Phase 7: Resource型コンポーネントの土台を作る

1ライン制御が安定してから、Resource型の土台を追加する。

追加候補。

```text
res://Scripts/Characters/Components/AICharacterComponent.gd
res://Scripts/Characters/Components/AICharacterBehaviorComponent.gd
```

基本インターフェース案。

```gdscript
extends Resource
class_name AICharacterComponent

var _actor: Node

func bind(actor: Node) -> void:
	_actor = actor

func unbind() -> void:
	_actor = null

func get_component_id() -> StringName:
	return &"component"
```

行動系は以下。

```gdscript
extends AICharacterComponent
class_name AICharacterBehaviorComponent

func can_start(context: AICharacterActionContext) -> bool:
	return false

func get_score(context: AICharacterActionContext) -> float:
	return 0.0

func start(context: AICharacterActionContext) -> bool:
	return false

func tick(context: AICharacterActionContext, delta: float) -> AICharacterActionResult:
	return null

func cancel(context: AICharacterActionContext) -> void:
	pass

func cleanup(context: AICharacterActionContext) -> void:
	pass
```

---

## Phase 8: Runtime Resourceの安全ルールを実装する

Resource型コンポーネントをActorへ持たせる場合、必ず実行時複製して使う。

```gdscript
var runtime_component := component.duplicate(true) as AICharacterComponent
```

共有 `.tres` にruntime状態を持たせない。

Actor終了時は必ず `unbind()` する。

```gdscript
func _exit_tree() -> void:
	for component in _runtime_components:
		component.unbind()
	_runtime_components.clear()
```

---

## Phase 9: 安定した行動からResource化する

Resource化の順番。

1. 待機。
2. 徘徊。
3. 着席。
4. 水分補給。
5. 衛生。
6. 読書。
7. 制作。
8. 睡眠。
9. マップ移動。

重いもの、参照が多いもの、外部システム連携が多いものは後回し。

---

## 本体スクリプトの段階的な理想形

最終的にはActor本体を以下のように薄くする。

```gdscript
func _ready() -> void:
	_setup_visuals()
	_setup_click()
	_setup_ai_runner()

func _physics_process(delta: float) -> void:
	_ai_runner.physics_update(delta)

func _exit_tree() -> void:
	_ai_runner.shutdown()
```

ただし、これは最終形。

最初からここへ飛ばない。

既存処理を安全に残しながら、1機能ずつ委譲していく。

---

## 作業ごとのチェックリスト

各作業では必ず確認する。

- 変更対象は1機能だけか。
- 関係ないコードを消していないか。
- Actor本体がさらに肥大化していないか。
- active actionが複数になっていないか。
- 毎フレーム全候補評価をしていないか。
- 毎フレーム家具総当たりをしていないか。
- cleanupで予約や参照を消しているか。
- 既存HUD表示が壊れていないか。
- FPS低下につながる処理を増やしていないか。
- Resource共有による状態混線が起きない設計か。

---

## すぐにやらないこと

- RobinWanderActorを全面改修する。
- 既存Nodeモジュールを全部Resource化する。
- 全行動を一度にRunnerへ移す。
- `.tscn` の子Nodeを大量削除する。
- デバッグ表示を先に消す。
- 完成している行動を理由なく作り直す。

---

## 次の具体的な一手

次に作るなら、以下の順で小さく進める。

1. `AICharacterActionResult.gd`
2. `AICharacterActionContext.gd`
3. `AICharacterActionRunner.gd`
4. `AICharacterNodeActionAdapter.gd`
5. ZippyActorにRunnerを接続する最小修正
6. 徘徊だけRunner管理へ移す

ここまでできたら、コンポーネントシステムへ移る土台ができる。

---

## 合言葉

```text
本体は薄く、行動は1本、機能は部品。
Nodeで包んで、Resourceへ育てる。
```
