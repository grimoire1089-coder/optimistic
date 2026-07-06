# Character Needs

キャラクター用ステータスの実装です。

## Main files

- `Scripts/Systems/Needs/CharacterNeedsModule.gd`
- `Scripts/Systems/Needs/GameClockNeedsBridge.gd`
- `Scripts/Systems/Needs/NeedDrivenAIPlanner.gd`
- `Scripts/Systems/Needs/NeedEffectApplier.gd`
- `Scripts/Items/Food/FoodItemData.gd`
- `Data/Needs/Definitions/*.tres`
- `Data/Needs/Effects/*.tres`
- `Data/Items/Food/*.tres`
- `Scenes/Characters/Modules/AICharacterNeedsBundle.tscn`
- `Scenes/UI/CharacterNeeds/CharacterNeedsPanel.tscn`

## Default needs

`CharacterNeedIds.DEFAULT_DEFINITION_PATHS` の順番で UI に表示されます。
水分は `hunger.tres` の直後に読み込むため、CharacterNeedsPanel では満腹度の下に表示されます。

- 体力: `energy`
- 満腹度: `hunger`
- 水分: `water`
- 清潔度: `hygiene`
- 娯楽度: `fun`
- 交流度: `social`

## Basic call

```gdscript
needs_module.add_need_value(CharacterNeedIds.HUNGER, 25.0)
needs_module.add_need_value(CharacterNeedIds.WATER, 25.0)
var lowest := needs_module.get_lowest_need_id()
```

## Bundle

AIキャラクターには `Scenes/Characters/Modules/AICharacterNeedsBundle.tscn` を追加します。
この中に、欲求本体、時計連動、簡易プランナーが入っています。

## Planner

```gdscript
var action_id := need_planner.get_next_action_id()
```

## Effect

`Data/Needs/Effects/*.tres` を `NeedEffectApplier.effect` に入れて `apply()` を呼びます。

数値調整は `Data/Needs/Definitions/*.tres` と `Data/Needs/Effects/*.tres` で行います。

## Food / Drink direct values

食品・飲料アイテムは `FoodItemData.gd` の Inspector で、アイテムごとに回復値を直接入力できます。

- `nutrition_value`: 満腹度 `hunger` に加算する値
- `hydration_value`: 水分 `water` に加算する値
- `extra_need_values`: 追加で変化させたい欲求値の辞書
- `need_effect`: 既存の `NeedEffectData` を使いたい場合の互換用欄

`nutrition_value` と `hydration_value` は `Need Values` グループにまとまっています。
Godot エディタで `Data/Items/Food/*.tres` を開き、数値を入力するだけで食品・飲料ごとに効果を調整できます。

既存の `need_effect` 参照は残しているため、古いアイテムデータもそのまま動きます。
直接入力値と `need_effect` の両方が入っている場合は、両方の値を合算した実効効果になります。

例：

```gdscript
# バーガーなら満腹度 +30
nutrition_value = 30.0

# 水入りボトルなら水分 +100
hydration_value = 100.0

# 追加効果を入れる場合
extra_need_values = {&"fun": 5.0}
```
