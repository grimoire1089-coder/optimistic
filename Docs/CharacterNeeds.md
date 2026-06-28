# Character Needs

キャラクター用ステータスの実装です。

## Main files

- `Scripts/Systems/Needs/CharacterNeedsModule.gd`
- `Scripts/Systems/Needs/GameClockNeedsBridge.gd`
- `Scripts/Systems/Needs/NeedDrivenAIPlanner.gd`
- `Scripts/Systems/Needs/NeedEffectApplier.gd`
- `Data/Needs/Definitions/*.tres`
- `Data/Needs/Effects/*.tres`
- `Scenes/Characters/Modules/AICharacterNeedsBundle.tscn`
- `Scenes/UI/CharacterNeeds/CharacterNeedsPanel.tscn`

## Basic call

```gdscript
needs_module.add_need_value(CharacterNeedIds.HUNGER, 25.0)
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
