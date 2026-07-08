# AI Character Code Build Handoff

作成日: 2026-07-08

この文書は、新規チャットでAIキャラクター関連のコード構築を再開するための引き継ぎメモである。

---

## リポジトリ

```text
grimoire1089-coder/optimistic
branch: main
Godot Engine v4.7.stable.official.5b4e0cb0f
```

---

## 開発方針

- GodotでUIとスプライト主体の2Dゲームを制作中。
- 修正は必要なところだけに限定する。
- 関係ないコードは絶対に消さない。
- 本体スクリプトは薄く保つ。
- 機能はモジュール形式、または行動パッケージ形式にする。
- ロビンはFPS低下とメモリリークを特に嫌う。
- 重い処理や不要な再生成を避ける。
- AIキャラクター行動は1キャラクター1ラインで管理する。

---

## すでに追加したDocs

```text
Docs/AICharacterSingleLineBehaviorSpec.md
Docs/AICharacterComponentImplementationPlan.md
Docs/AICharacterActionPackageSpec.md
Docs/AICharacterOffMapSimulationSpec.md
Docs/AICharacterEconomyAndCareSpec.md
Docs/AICharacterPersonalityInteractionScheduleSpec.md
Docs/AICharacterLifeEventDirectorAndChillLoopSpec.md
Docs/AICharacterAdoptedExtraSystemsSpec.md
Docs/AICharacterCodeBuildHandoff.md
```

---

## すでに追加したCoreコード

```text
Scripts/Characters/Actions/Core/AICharacterActionResult.gd
Scripts/Characters/Actions/Core/AICharacterActionContext.gd
Scripts/Characters/Actions/Core/AICharacterActionPackage.gd
Scripts/Characters/Actions/Core/AICharacterActionRunner.gd
Scripts/Characters/Actions/Core/AICharacterNodeActionAdapter.gd
```

目的。

- ActionRunnerの土台。
- Resource型ActionPackageの土台。
- 既存Node行動を包むNodeActionAdapterの土台。

まだRobin本体の大改造はしていない。

---

## ZippyActorの現在状態

`Scripts/Characters/Zippy/ZippyActor.gd` にActionRunner observerを追加済み。

現在は見るだけ接続。

```text
既存処理: 水分補給 → 着席 → 徘徊
Runner: 空パッケージでobserver更新のみ
```

Runnerはまだ行動制御を奪っていない。

既存挙動を壊さないため、Zippyで段階的に実験する方針。

---

## AI観測HUD

追加済み。

```text
Scripts/UI/Debug/AICharacterObserverHud.gd
Scenes/Main/MainScene.tscn
```

機能。

- F2で開閉。
- デバッグビルド限定。
- 背面パネルは不透明。
- 表示中だけ0.25秒間隔で更新。
- `ai_character_actor` グループのAIを一覧表示。
- 日本語ベース表示。
- 現在行動、行動ID、移動中、一番低い欲求、位置、速度、行動ライン、欲求値を表示。

Godot 4.7で `PackedStringArray.join()` は使えないため、手動結合関数に修正済み。

---

## 直近で採用された追加仕様

`Docs/AICharacterAdoptedExtraSystemsSpec.md` に記録済み。

特に必要仕様。

```text
7. 変化チップ安全装置
8. 安心して終了できる確認パネル
```

変化チップ安全装置の必須UI。

```text
装備中チップ一覧
元設定との差分表示
取り外すと元に戻ることの表示
```

安心して終了できる確認パネル候補。

```text
SafeExitCheckPanel
```

---

## 次にやるコード作業候補

安全な順番。

### 1. AI観測HUDの微調整

必要なら先に見やすさを整える。

候補。

- 横幅や折り返し調整。
- Runner情報の表示整理。
- 重要表示だけ色分け。
- F2以外のキーと競合しないか確認。

### 2. WanderActionPackageの準備

Zippyで最初に移行する行動は徘徊。

理由。

- 副作用が少ない。
- 家具予約がない。
- アイテム消費がない。
- 失敗時の影響が小さい。

ただし、いきなり既存徘徊を削除しない。

まずNodeActionAdapterで既存 `AICharacterRandomWanderModule` を包む。

### 3. ZippyActorに徘徊だけRunner管理を試す

既存の水分補給と着席は残す。

徘徊だけRunner側に寄せる。

想定。

```text
水分補給がactiveなら既存処理
着席がactiveなら既存処理
それ以外の徘徊をRunnerへ渡す
```

### 4. 行動理由ログの最小実装

ActionResultまたはActionRunnerの完了時に短い理由ログを出せるようにする。

まだ本格LifeLogにしない。

### 5. LifeLog / ReportUI / SafeExitCheckPanel

チル・放置方針に効くが、ActionRunnerの土台確認後がよい。

---

## 次チャット開始時のおすすめ依頼文

```text
@GitHub AICharacterCodeBuildHandoff.md を確認して、Zippyの徘徊だけをActionRunner管理へ移すための最小実装から進めてください。既存の水分補給・着席・Robin本体はまだ触らないでください。
```

---

## 絶対に守ること

- RobinWanderActorを全面改修しない。
- 既存Node行動を一気に消さない。
- Wander/Sit/Hydrateを同時に移行しない。
- Resource共有でruntime状態を混ぜない。
- cleanupなしで家具予約、経路、表示、参照を残さない。
- 毎フレーム全AI、全家具、全行動候補を総当たりしない。
