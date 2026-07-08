# AI Character Life Event Director and Chill Loop Spec

作成日: 2026-07-08

この文書は、AIキャラクター生活シムをインクリメンタル、放置、チル寄りにするための追加仕様である。

対象は以下。

- LifeEventDirector
- Memory / LifeLog
- DailyWish
- CustomerVisitReason
- ReportUI
- Director担当者による難易度と街の空気の変化

コード作業はまだ行わない。

---

## 基本方針

本作は、RimWorldやSims系の影響を受けたAIキャラクター生活シムである。

ただし、重く厳密な生活シミュレーションではなく、以下を目指す。

```text
AIキャラクターの生活が勝手に少しずつ進む。
プレイヤーは見守り、介入し、店を整え、生活ログを読む。
失敗しても破滅しすぎない。
放置して戻ってくると、街とAIキャラに小さな変化がある。
```

---

## 追加する中心システム

### 1. LifeEventDirector

街や施設の小さな出来事を管理するシステム。

役割。

- 街の空気を少し揺らす。
- AIキャラクターの行動理由を作る。
- お客の来店理由を作る。
- 放置中の小さな出来事を作る。
- 失敗や危機をチル寄りに調整する。

例。

```text
今日は客が少し多い。
静かな雨で来店数は減るが、温かい料理が売れやすい。
ジッピーが新商品に興味を持つ。
ロビンが誰かと話したがっている。
フェリシティで小さな音楽イベントがある。
街の一部で軽い物流遅延がある。
```

### 2. Memory / LifeLog

AIキャラクターや街の出来事を短く残すシステム。

役割。

- AIキャラクターの生活に連続性を出す。
- プレイヤーが放置後に何が起きたか読めるようにする。
- 会話や関係値の材料にする。
- 店舗経営の振り返りに使う。

例。

```text
ジッピーは朝に水を飲んだ。
ロビンは昼に椅子で休んだ。
アルバートはグリムと会話して少し仲良くなった。
ヘリオはお気に入りの飲料を買った。
```

保存方針。

```text
通常ログ: 短期間だけ保存
重要ログ: 長めに保存
関係値に関わるログ: 必要に応じて保存
店の売上ログ: 日次集計へ圧縮
```

大量ログを無制限に保存しない。

---

### 3. DailyWish

AIキャラクターが今日やりたいこと、食べたいもの、会いたい相手を持つ仕組み。

役割。

- 放置中の行動に目的を持たせる。
- 好き嫌い、特性、関係値、スケジュールと連動する。
- 達成できた時に小さな満足感を出す。

例。

```text
今日は甘いものが食べたい。
誰かと話したい。
静かな場所で休みたい。
新しい雑貨を見たい。
お気に入りの席に座りたい。
仕事を少し頑張りたい。
```

DailyWishは、達成できなくても大きな罰にしない。

チル寄りなので、達成時の小さな報酬を中心にする。

---

### 4. CustomerVisitReason

AIキャラクターがお客として店に来る理由を作る仕組み。

役割。

- プレイヤー経営とAI生活をつなぐ。
- AIキャラの欲求、好み、予定、関係値を来店に反映する。
- 店舗経営が単なる数字ではなく、AI生活と接続されるようにする。

来店理由の例。

```text
水分が低いから飲料を買いに来る。
好きな食品があるから来る。
スケジュールで来る。
プレイヤーや店との関係値が高いから顔を出す。
特性が浪費家なので、ふらっと買い物に来る。
変化チップで好みが変わったので、新商品を試しに来る。
イベント中なので来る。
```

購入判定に使うもの。

```text
所持クレジット
好き嫌い
特性
現在の欲求
商品のタグ
価格
店の評判
プレイヤーとの関係値
ランダムチェック
```

---

### 5. ReportUI

放置や日次進行の結果を読みやすくまとめるUI。

役割。

- 放置後に何が起きたかを確認する。
- 店の売上や人気商品を確認する。
- AIキャラクターの体調や関係値変化を確認する。
- 次に何を整えるべきか、プレイヤーに優しく示す。

表示候補。

```text
1時間の生活報告
1日の売上報告
AIキャラの欲求変化まとめ
来店客まとめ
人気商品ランキング
関係値が動いた相手
病院・体調注意リスト
今日達成されたDailyWish
街イベントの結果
```

UIは数字だけでなく、短い文章ログを中心にする。

---

## LifeEventDirectorの担当者

LifeEventDirectorは、抽象システムとしてだけではなく、ゲーム内の担当者として表現できる。

候補。

```text
Deus Ex Machina
マスター
街の管理AI
別の管理者
```

担当者を変えることで、同じシステムでも街の空気、イベント傾向、難易度が変わる。

---

## Deus Ex MachinaをDirectorにする案

デウス・エクス・マキナは、中央管理センターの管理AIであり、都市制御者、非常時対処機構としての役割を持つ。

そのため、LifeEventDirectorを任せる存在として相性がよい。

### 基本スタイル

```text
穏やか。
保護的。
チル寄り。
破滅を避ける。
危機は早めに警告する。
奇跡的な救済イベントが起きやすい。
AIキャラクター同士のつながりを重視する。
```

### 得意なイベント

```text
小さな回復イベント。
病院送り前の警告。
孤独なAIへの交流誘導。
静かな音楽イベント。
フェリシティでの穏やかな来店増加。
生活に必要な最低限の補給。
関係修復のきっかけ。
```

### 苦手または抑制するイベント

```text
過度な破滅イベント。
理不尽な損失。
長期の放置で取り返しがつかない失敗。
AIキャラの完全な脱落。
```

---

## Directorによる難易度変更

LifeEventDirectorの担当者を変えると、難易度や街の空気が変わる。

これは単なる数値難易度ではなく、物語上の担当者変更として表現できる。

### Deus Ex Machina Mode

```text
難易度: やさしい
空気: 神聖、穏やか、保護的
特徴: 危機前に警告が出やすい。回復支援が入りやすい。
向き: チル、放置、見守り重視
```

### Master Mode

```text
難易度: 標準
空気: Bar Felicity中心、現実的、温かい
特徴: 支援はあるが、ある程度は自分たちで乗り越える。
向き: 生活シム、店舗経営、関係値重視
```

### City Management Mode

```text
難易度: 標準から少し高め
空気: 事務的、都市運営、効率重視
特徴: イベントは経済や物流に寄る。救済は規則的。
向き: 経営、最適化、街全体の管理
```

### Night Masters Mode

```text
難易度: 高い
空気: 危険、退廃、事件性が高い
特徴: トラブルや誘惑が増える。報酬も大きい。
向き: 慣れたプレイヤー、刺激が欲しい時
```

最初は `Deus Ex Machina Mode` を基本にする。

ロビンのゲームはチル寄りなので、デフォルトは保護的でよい。

---

## Directorが見る情報

Directorは、すべてを毎フレーム見るわけではない。

ゲーム内時間の節目で軽く見る。

候補。

```text
1時間ごと
1日ごと
シーズン開始時
イベント発生時
放置復帰時
```

見る情報。

```text
AIキャラの欲求概要
病院リスク
関係値の大きな変化
店の売上
人気商品
在庫不足
街の天候
季節
スケジュール
来店予定
```

---

## Directorの出力

Directorは直接AIキャラを細かく操作しない。

小さなイベントや補正を出す。

例。

```text
city_event_id
customer_flow_modifier
shop_demand_modifier
ai_daily_wish_seed
relationship_event_seed
hospital_warning
care_support_event
report_message
```

---

## チル寄りフェイルセーフ

Directorは、チル寄りの安全網も担当できる。

例。

```text
栄養と水分が危険 → 体調注意ログを出す
病院送り直前 → 低コストの補給機会を出す
店の在庫が足りない → 報告UIでやさしく知らせる
関係値が悪化 → 仲直りの小イベントを出す
長時間放置 → 深刻すぎる悪化を一定以上で止める設定も可能
```

ただし、すべてを自動で解決しない。

プレイヤーが整える余地は残す。

---

## 既存仕様との接続

### AICharacterOffMapSimulationSpec

マップ外AI処理の1時間単位処理にDirectorを接続する。

```text
hour_changed
  ↓
OffMapSimulation
  ↓
Directorが軽いイベント補正を出す
  ↓
ResidentStateに結果を反映
```

### AICharacterEconomyAndCareSpec

病院送り、回復、買い物、体調注意にDirectorを接続する。

```text
危険状態検出
  ↓
Directorが警告または支援イベントを出す
  ↓
病院送り、補給、報告UIに反映
```

### AICharacterPersonalityInteractionScheduleSpec

DailyWish、会話、関係値、スケジュール、お客化にDirectorを接続する。

```text
AIの個性と予定
  ↓
Directorが日ごとの流れを少し整える
  ↓
来店、会話、生活ログに反映
```

---

## 推奨ディレクトリ構成

```text
res://Scripts/Systems/LifeDirector/
  LifeEventDirector.gd
  LifeEventDirectorProfile.gd
  LifeEventDirectorMode.gd
  LifeEventDirectorEvent.gd

res://Scripts/Characters/Memory/
  AICharacterLifeLog.gd
  AICharacterMemoryEntry.gd

res://Scripts/Characters/Wishes/
  AICharacterDailyWish.gd
  AICharacterDailyWishResolver.gd

res://Scripts/Characters/Customer/
  AICharacterCustomerVisitReason.gd
  AICharacterCustomerVisitResolver.gd

res://Scripts/UI/Reports/
  LifeReportPanel.gd
  DailyShopReportPanel.gd
```

---

## 最初の実装順

まだコード作業はしない。

実装するなら、以下の順が安全。

### Phase 1

`LifeEventDirectorProfile` の仕様だけ作る。

担当者、難易度、イベント傾向をデータで持つ。

### Phase 2

`LifeLog` を作る。

まずは短いログを貯めて表示するだけ。

### Phase 3

`ReportUI` を作る。

放置後、1日後、イベント後に何が起きたかを表示する。

### Phase 4

`DailyWish` を作る。

AIキャラごとに今日の小さな願望を1つだけ持たせる。

### Phase 5

`CustomerVisitReason` を作る。

来店理由をログと購入判定に使う。

### Phase 6

`LifeEventDirector` を本格接続する。

最初の担当者は `Deus Ex Machina`。

---

## 完了条件

この仕様が実装された場合、以下を満たす。

- 街や店に小さな出来事が起こる。
- 出来事はチル寄りで、破滅しすぎない。
- AIキャラクターの行動が生活ログとして読める。
- AIキャラクターはDailyWishを持つ。
- AIキャラクターがお客として来る理由を持つ。
- 放置後にReportUIで結果を確認できる。
- Director担当者により難易度と街の空気が変わる。
- 初期DirectorはDeus Ex Machinaを想定する。
