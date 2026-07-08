# AI Character Personality Interaction Schedule Spec

作成日: 2026-07-08

この文書は、AIキャラクターの好き嫌い、特性、相互作用、会話、変化チップ、年間スケジュール、お客化を整理するための仕様である。

コード作業はまだ行わない。

まず、ロビンの中で決まっている仕様を将来の実装へつなげられる形で固定する。

---

## 関連する既存方針

この仕様は、以下の方針と組み合わせる。

- 1キャラクター1ライン。
- 行動パッケージ。
- Resource型コンポーネント。
- マップ外AI軽量シミュレーション。
- AI個別クレジットとインベントリ。
- 病院送りと復帰。

---

## 全体像

AIキャラクターは、単に欲求に反応するだけではなく、個性を持つ。

```text
AIキャラクター
  ├─ 好き嫌い
  ├─ 特性
  ├─ ビッグファイブ系の性格数値
  ├─ 固有会話デッキ
  ├─ 関係値
  ├─ 変化チップ装備
  ├─ 年間スケジュール
  ├─ 個別クレジット
  ├─ 個別インベントリ
  └─ 現在の生活状態
```

これらは、行動選択、会話反応、買い物、マップ外処理、お客としての来店行動に使う。

---

## 好き嫌い

### 基本方針

各AIキャラクターには、好き嫌いがある。

対象は食品だけではない。

例。

- 特定の食品。
- 特定の飲料。
- 特定の雑貨。
- 特定カテゴリのアイテム。
- 特定の場所。
- 特定の行動。
- 特定の相手。
- 特定の話題。

### 好き嫌いの使い道

好き嫌いは以下に使う。

- 食べ物や飲み物を選ぶ。
- 買い物候補を選ぶ。
- 会話の反応を変える。
- プレゼントの反応を変える。
- お客として店に来た時の購入傾向を変える。
- マップ外AIの簡易行動選択に使う。

### データ候補

```text
AICharacterPreferenceSet
```

持つ情報の例。

```text
liked_item_ids
hated_item_ids
liked_item_tags
hated_item_tags
liked_location_ids
hated_location_ids
liked_topic_ids
hated_topic_ids
```

### 強さ

好き嫌いには強さを持たせる。

例。

```text
+100: 大好物
+50: 好き
+10: 少し好き
0: 普通
-10: 少し苦手
-50: 嫌い
-100: 大嫌い
```

最初は数値なしで、好き・嫌いだけでもよい。

---

## 特性

### 基本方針

特性は、パッケージ化またはモジュール化された性格のようなもの。

AIキャラクターが考え中の時、特性に対応した行動を選びやすくしたり、逆に除外したりするために使う。

相互作用にも使う場合がある。

### 例

```text
きれい好き
食いしん坊
社交的
内向的
仕事好き
怠け者
浪費家
節約家
機械好き
読書好き
夜型
朝型
```

### 行動選択への影響

例。

```text
きれい好き
  hygiene が少し低いだけでも衛生行動を選びやすい

食いしん坊
  hunger が低くなくても食事や買い食いを選びやすい

社交的
  social が低くなくても会話行動を選びやすい

内向的
  会話行動を選びにくい

節約家
  買い物行動のスコアを下げる

浪費家
  買い物行動のスコアを上げる
```

### 除外にも使う

特性は、行動を増やすだけでなく、除外にも使う。

例。

```text
潔癖
  汚れた場所の行動を避ける

夜型
  朝の仕事行動を避ける、または効率を下げる

内向的
  人数が多い場所での交流を避ける
```

### データ候補

```text
AICharacterTraitPackage
AICharacterTraitSet
```

TraitPackageは1つの特性。

TraitSetはキャラクターが持つ特性一覧。

---

## ビッグファイブ系の性格数値

### 基本方針

会話や相互作用の判定用に、ビッグファイブのような数値を持たせる。

完全に心理学を再現する必要はない。

ゲーム内の反応判定に使うための性格パラメータとして扱う。

候補。

```text
openness      開放性
conscientiousness 誠実性
extraversion  外向性
agreeableness 協調性
neuroticism   繊細さ / 不安定さ
```

### 値の範囲

候補。

```text
0 - 100
```

例。

```text
外向性が高い → 会話に乗りやすい
協調性が高い → 好意的に返しやすい
繊細さが高い → 失敗反応や傷つき反応が出やすい
開放性が高い → 新しい食品や雑貨を試しやすい
誠実性が高い → スケジュール行動や仕事を守りやすい
```

### ダイスロール的な判定

会話や相互作用では、固定結果ではなく、数値とランダムチェックを組み合わせる。

例。

```text
反応スコア = 基本値 + 好き嫌い補正 + 特性補正 + 関係値補正 + 性格数値補正 + ランダム値
```

結果は段階化する。

```text
大成功
成功
普通
失敗
大失敗
```

---

## 相互作用

### 基本方針

AIキャラクター同士は相互作用する。

代表は会話。

ただし、相互作用は会話だけに限定しない。

例。

- 会話。
- 挨拶。
- 一緒に食事。
- プレゼント。
- 仕事中のやり取り。
- 助ける。
- からかう。
- ケンカ。
- 仲直り。

### 相互作用の選択

相互作用も、1キャラクター1ラインの行動として扱う。

マップ内ではActionPackageになる。

候補。

```text
TalkActionPackage
GiftActionPackage
EatTogetherActionPackage
WorkTogetherActionPackage
```

マップ外では、軽量な相互作用イベントとして扱う。

候補。

```text
OffMapInteractionEvent
```

---

## 会話デッキ

### 基本方針

AIキャラクター達は、固有の会話デッキを持つ。

会話デッキは、そのキャラクターらしい話題や反応をまとめたもの。

```text
ZippyConversationDeck
RobinConversationDeck
AlbertConversationDeck
GrimConversationDeck
```

### 会話カード

会話デッキは複数の会話カードで構成する。

候補。

```text
ConversationCard
```

持つ情報の例。

```text
card_id
topic_id
speaker_line
reaction_tags
required_traits
blocked_traits
liked_topic_bonus
relationship_change
mood_change
success_threshold
failure_threshold
```

### 反応判定

相手の好き嫌い、特性、関係値、性格数値、ランダムチェックで反応を決める。

例。

```text
話題: ピザ
相手がピザ好き: 好反応補正
相手が食いしん坊: 好反応補正
相手との関係値が高い: 好反応補正
外向性が高い: 会話継続しやすい
ランダムチェック成功: 良い反応
```

反応結果。

```text
大喜び
好反応
普通
微妙
悪反応
```

---

## 変化チップ

### 基本方針

変化チップは、AIキャラクターに装備させることで好き嫌いや特性を変えるアイテム。

通常の好き嫌い・特性より強い効力を持つ。

AIキャラクターに設定された元の好き嫌いや特性と衝突した場合、元の設定を無効化するぐらいの優先度を持つ。

### 使い道

- 好きな食品を変える。
- 嫌いな雑貨を好きにする。
- 特定の特性を追加する。
- 特定の特性を無効化する。
- 会話反応を変える。
- お客としての購入傾向を変える。

### 優先度

判定順の候補。

```text
1. 一時イベント効果
2. 変化チップ効果
3. キャラクター固有設定
4. 種族・職業などの基本設定
5. デフォルト
```

つまり、変化チップはキャラクター固有設定より強い。

### データ候補

```text
AICharacterChangeChipData
AICharacterChangeChipSlot
AICharacterChangeChipEffect
```

効果の例。

```text
add_liked_item_id
remove_liked_item_id
add_hated_item_id
remove_hated_item_id
add_trait
disable_trait
modify_big_five_value
conversation_bonus
shop_preference_bonus
```

### 衝突処理

例。

```text
キャラクター固有設定: ピザが嫌い
変化チップ: ピザ好きになる
結果: ピザ好きとして扱う
```

```text
キャラクター固有特性: 内向的
変化チップ: 社交的を付与し、内向的を無効化
結果: 会話行動を選びやすくなる
```

---

## 年間スケジュール

### 基本方針

AIキャラクターごとに、1年サイクルのスケジュールを持つ。

このゲームの1年は以下。

```text
1シーズン = 30日
4シーズン = 120日
1年 = 120日
```

スケジュールは、年ごとに繰り返す。

### 用途

- この日のこの時間に特定マップへ行く。
- この日のこの時間に仕事行動パッケージを実行する。
- 季節イベントに参加する。
- 店に客として来る。
- マップ外処理で仕事や予定を進める。

### データ候補

```text
AICharacterYearSchedule
AICharacterScheduleEntry
```

ScheduleEntryの例。

```text
season_id
season_day
hour_start
hour_end
location_id
map_id
action_package_id
off_map_action_id
priority
repeat_rule
```

### 例

```text
春 5日目 09:00 - 17:00
location_id: felicity_bar
map_id: bar_felicity
行動: work_waiter_package
```

```text
夏 12日目 18:00 - 21:00
location_id: city_food_street
行動: off_map_socialize
```

### マップ内処理での使い方

現在マップにいるAIがスケジュール時間になった場合。

```text
Think時にスケジュールを確認
  ↓
予定がある
  ↓
ScheduleActionPackageを選ぶ
  ↓
必要ならマップ移動または仕事行動へつなぐ
```

### マップ外処理での使い方

マップ外AIは、1時間単位の軽量処理時にスケジュールを見る。

```text
hour_changed
  ↓
ResidentStateの年間スケジュール確認
  ↓
該当予定がある
  ↓
off_map_action_id を解決
  ↓
欲求、クレジット、関係値、経験値などをまとめて更新
```

---

## スケジュール優先度

スケジュールは強いが、絶対ではない。

優先度候補。

```text
病院中
  最優先。通常スケジュールを無視。

危険欲求
  栄養・水分・体力などが危険なら予定より優先。

プレイヤー命令
  必要に応じてスケジュールより優先。

固定イベント
  特定の日だけ強制。

通常スケジュール
  仕事や来店など。

自由行動
  欲求や特性で決める。
```

---

## お客化

### 基本方針

プレイヤーは将来的に経営を行い、お店を持てる。

AIキャラクターは、将来的にお客として来店する。

そのため、AIキャラクター仕様は「生活者」と「お客」の両方に使えるようにする。

### お客として使う情報

- 好き嫌い。
- 特性。
- 個別クレジット。
- インベントリ。
- 年間スケジュール。
- 関係値。
- 会話デッキ。
- 変化チップ。
- 現在の欲求。

### 来店判定

候補。

```text
スケジュールで来店
欲求で来店
好きな商品があるので来店
関係値が高いので来店
イベントで来店
```

### 購入判定

購入判定には以下を使う。

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

### 会話との連動

お客として来たAIは、店内で会話することもある。

```text
来店
  ↓
商品を見る
  ↓
購入するか判定
  ↓
会話するか判定
  ↓
満足度や関係値を更新
```

---

## 実装はまだしないもの

この段階では、以下は実装しない。

- 好き嫌いResource。
- TraitPackage。
- ConversationDeck。
- ChangeChip。
- YearSchedule。
- CustomerAI。

まずは仕様を固定する。

---

## 将来の推奨ディレクトリ

```text
res://Scripts/Characters/Personality/
  AICharacterPreferenceSet.gd
  AICharacterTraitPackage.gd
  AICharacterTraitSet.gd
  AICharacterPersonalityProfile.gd

res://Scripts/Characters/Conversation/
  AICharacterConversationDeck.gd
  AICharacterConversationCard.gd
  AICharacterInteractionResolver.gd

res://Scripts/Characters/ChangeChips/
  AICharacterChangeChipData.gd
  AICharacterChangeChipSlot.gd
  AICharacterChangeChipEffect.gd

res://Scripts/Characters/Schedule/
  AICharacterYearSchedule.gd
  AICharacterScheduleEntry.gd
  AICharacterScheduleResolver.gd

res://Scripts/Characters/Customer/
  AICharacterCustomerProfile.gd
  AICharacterCustomerVisitResolver.gd
  AICharacterCustomerPurchaseResolver.gd
```

---

## 完了条件

この仕様が実装されたAIキャラクターは、以下を満たす。

- 好き嫌いを持つ。
- 特性を持つ。
- 性格数値を持つ。
- 固有会話デッキを持つ。
- 好き嫌い、特性、関係値、性格数値、ランダムチェックで会話反応が決まる。
- 変化チップで好き嫌いや特性を上書きできる。
- 1年120日の年間スケジュールを持つ。
- スケジュールはマップ内処理とマップ外処理の両方で使える。
- 将来的にお客として来店・購入・会話できる。
