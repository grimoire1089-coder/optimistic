# AI Character Economy and Care Spec

作成日: 2026-07-08

この文書は、AIキャラクターごとのクレジット、インベントリ、買い物、アイテム使用、病院送り、復帰処理の仕様である。

本仕様は、以下の設計と組み合わせて使う。

- 1キャラクター1ライン。
- 行動パッケージ。
- Resource型コンポーネント。
- マップ外AI軽量シミュレーション。

---

## 基本方針

AIキャラクターは、プレイヤーとは別に個別の生活資産を持つ。

```text
AIキャラクター
  ├─ 個別クレジット
  ├─ 個別インベントリ
  ├─ 欲求
  ├─ 関係値
  ├─ 現在地
  └─ 現在の行動状態
```

AIキャラクターは、必要に応じて自分の持ち物を使い、自分のクレジットで買い物する。

---

## AI個別クレジット

### 目的

AIキャラクターが自分の生活資金を持つことで、以下を可能にする。

- 食品や飲料を自分で買う。
- 生活用品を買う。
- サービスや施設利用料を払う。
- 病院費やケア費を払う。
- 仕事やイベントで収入を得る。

### 既存プレイヤークレジットとの関係

既存の `CreditWallet` はプレイヤーまたはグローバル財布として使う。

AIキャラクター個人のクレジットは、別データとして持つ。

候補。

```text
AICharacterWalletState
```

または、ResidentState内に以下を持つ。

```text
credits: int
```

最初はResidentState内の `credits` だけでよい。

---

## AI個別インベントリ

AIキャラクターは個別インベントリを持つ。

マップ内AIは、既存の `AICharacterInventoryModule` を使える。

マップ外AIは、Node版インベントリを持たず、軽量State上にアイテム概要だけを持つ。

候補。

```text
inventory_items: Array[Dictionary]
```

各要素の例。

```text
item_id
category_id
amount
stack_max
need_values
buy_price
sell_price
can_transfer
```

---

## マップ内とマップ外の違い

### マップ内AI

SceneTree上にActorが存在する。

使ってよいもの。

- `AICharacterInventoryModule`
- 表示用アイテムNode
- 飲食アニメーション
- 進捗バー
- ActionPackage
- 家具利用

### マップ外AI

SceneTree上にActorが存在しない。

使わないもの。

- `AICharacterInventoryModule` Node
- 表示用アイテムNode
- ProgressBar
- 家具探索
- 物理移動

マップ外では、ResidentState上の軽量インベントリだけを更新する。

---

## アイテム使用行動

AIキャラクターは、欲求が低いときに所持品を使える。

例。

```text
water が低い
  ↓
所持品に飲料がある
  ↓
飲料を1個消費
  ↓
water を回復
```

```text
hunger が低い
  ↓
所持品に食品がある
  ↓
食品を1個消費
  ↓
hunger を回復
```

1キャラクター1ラインに従い、アイテム使用も1つの行動として扱う。

候補行動。

```text
UseInventoryItemActionPackage
OffMapUseInventoryItemAction
```

---

## 買い物行動

AIキャラクターは、必要なアイテムがない場合、自分のクレジットで買い物できる。

例。

```text
water が低い
  ↓
飲料を持っていない
  ↓
クレジットが足りる
  ↓
飲料を購入
  ↓
飲む、またはインベントリへ入れる
```

```text
hunger が低い
  ↓
食品を持っていない
  ↓
クレジットが足りる
  ↓
食品を購入
  ↓
食べる、またはインベントリへ入れる
```

### マップ内AIの場合

買い物は、将来的に店舗、販売機、施設などのマップ内オブジェクトを使ってもよい。

ただし、最初は簡易処理でよい。

```text
購入可能判定
  ↓
credits を減らす
  ↓
インベントリへ追加
```

### マップ外AIの場合

マップ外では、店舗Nodeを探さない。

場所IDや施設IDだけで購入可能か判断する。

```text
現在地 location_id が shopping_area
  ↓
購入可能
```

または、最低限は以下でもよい。

```text
生活圏内にいるなら購入可能
```

---

## 買い物の失敗

買い物に失敗する理由。

- クレジット不足。
- アイテムが売っていない。
- インベントリがいっぱい。
- 病院中などで通常行動できない。

失敗した場合は、別行動を考える。

例。

```text
飲料が買えない
  ↓
無料の水分補給施設を探す
  ↓
それも無理なら状態悪化を許容
```

---

## 病院送り仕様

ロビン達AIキャラクターは、栄養と水分が尽きた状態で体力も尽きると、病院送りになる。

条件。

```text
hunger <= 0
water <= 0
energy <= 0
```

この条件を満たしたAIキャラクターは、通常行動を停止し、病院状態へ移行する。

状態ID候補。

```text
hospitalized
```

---

## 病院中の扱い

病院は通常マップではなく、UIまたは軽量State上で扱う。

```text
病院 = マップではない
病院中AI = SceneTree上の通常Actorではない
```

病院中は、以下を行わない。

- 通常移動。
- 家具探索。
- 作業。
- 買い物。
- 通常の交流。
- 通常ActionRunner。

病院中は、一定期間ゆっくり欲求を回復する。

---

## 病院中の回復

病院中AIは、ゲーム内時間で徐々に回復する。

例。

```text
1時間ごとに回復
  energy + 5
  hunger + 3
  water + 3
  hygiene + 1
```

数値は仮。

最終的には調整用Resourceに分離する。

候補。

```text
AICharacterHospitalCareConfig
```

退院条件の候補。

```text
energy >= 40
hunger >= 40
water >= 40
```

または、最低入院時間を設定する。

```text
minimum_hospital_hours = 12
```

---

## 病院費

病院費は将来追加する。

候補。

```text
hospital_base_cost
hospital_cost_per_hour
```

支払い優先度。

```text
1. AI本人のクレジット
2. 所属組織や施設の支払い
3. プレイヤー負担
4. 未払い記録
```

最初の実装では、病院費は未実装でもよい。

病院送りと復帰の流れを先に作る。

---

## 通常処理への復帰

退院条件を満たしたAIキャラクターは、通常処理へ復帰する。

マップ内へ戻す場合。

```text
HospitalState
  ↓
ResidentStateへ戻す
  ↓
必要ならActorを生成
  ↓
マップ内AI処理へ復帰
```

マップ外へ戻す場合。

```text
HospitalState
  ↓
ResidentStateへ戻す
  ↓
OffMapSimulationへ復帰
```

復帰直後は、すぐ再入院しないように短い保護時間を持たせてもよい。

候補。

```text
hospital_recovery_grace_hours = 2
```

---

## 状態遷移

```text
normal
  ↓ 条件: hunger <= 0 and water <= 0 and energy <= 0
hospitalized
  ↓ 条件: 最低入院時間 + 退院欲求条件を満たす
recovering
  ↓ 条件: 保護時間終了
normal
```

`recovering` は任意。

最初は `normal` と `hospitalized` だけでもよい。

---

## マップ内AIでの病院送り

マップ内Actorが病院送りになった場合。

```text
Actor状態をResidentStateへ保存
  ↓
Actorをマップから取り除く
  ↓
HospitalStateへ登録
  ↓
HUDまたは通知を出す
```

この時、以下を必ずcleanupする。

- 家具予約。
- 経路。
- 表示中アイテム。
- 進捗バー。
- 一時z_index。
- 行動中の参照。

---

## マップ外AIでの病院送り

マップ外AIが軽量シミュレーション中に条件を満たした場合。

```text
ResidentState
  ↓
HospitalStateへ移動
  ↓
OffMapSimulation通常処理から除外
```

マップ外なので、Node cleanupは不要。

---

## UI案

病院はマップとして作らず、UIで扱う。

候補。

```text
AICharacterHospitalPanel
```

表示内容。

```text
入院中のAI一覧
現在の回復状態
退院までの目安
病院費
復帰予定
```

最初は、デバッグHUDまたは簡易リストでもよい。

---

## OffMapSimulationとの関係

病院中AIは、通常のOffMapSimulationでは処理しない。

代わりにHospitalCareSystemで処理する。

```text
normal off-map residents
  → OffMapSimulationSystem

hospitalized residents
  → HospitalCareSystem
```

これにより、通常行動と病院回復が混ざらない。

---

## 推奨ディレクトリ構成

```text
res://Scripts/Characters/Economy/
  AICharacterWalletState.gd
  AICharacterPurchaseResolver.gd

res://Scripts/Characters/Care/
  AICharacterHospitalState.gd
  AICharacterHospitalCareSystem.gd
  AICharacterHospitalCareConfig.gd

res://Scripts/Characters/Simulation/
  AICharacterResidentState.gd
  AICharacterOffMapActionResolver.gd
```

---

## 最初の実装順

### Phase 1

仕様書を追加する。

この段階ではゲームコードを変えない。

### Phase 2

`AICharacterResidentState.gd` に以下を持たせる。

```text
credits
inventory_items
life_state
hospitalized_until_hour
```

### Phase 3

マップ外欲求シミュレーションで、危険条件をチェックする。

```text
hunger <= 0 and water <= 0 and energy <= 0
```

### Phase 4

HospitalCareSystemを追加する。

ゲーム内1時間ごとに入院中AIを少し回復する。

### Phase 5

退院処理を追加する。

### Phase 6

AI個別クレジットと買い物を追加する。

### Phase 7

アイテム使用行動を追加する。

---

## 完了条件

- AIキャラクターが個別クレジットを持てる。
- AIキャラクターが個別インベントリを持てる。
- 必要なら持ち物を使って欲求を回復できる。
- 必要なら自分のクレジットで買い物できる。
- 栄養、水分、体力がすべて0になったら病院送りになる。
- 病院中は通常AI処理から除外される。
- 病院中はUIまたは軽量State上で管理される。
- 病院中は時間経過でゆっくり回復する。
- 条件を満たしたら通常処理へ復帰する。
- マップ内AIとマップ外AIで二重処理されない。
