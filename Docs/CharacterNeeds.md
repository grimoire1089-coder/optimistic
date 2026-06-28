# Character Needs

キャラクター用ステータスの最初の実装です。

## Main files

- `Scripts/Systems/Needs/CharacterNeedsModule.gd`
- `Scripts/Systems/Needs/GameClockNeedsBridge.gd`
- `Data/Needs/Definitions/*.tres`
- `Scenes/UI/CharacterNeeds/CharacterNeedsPanel.tscn`

## Basic call

```gdscript
needs_module.add_need_value(CharacterNeedIds.HUNGER, 25.0)
var lowest := needs_module.get_lowest_need_id()
```

数値調整は `Data/Needs/Definitions/*.tres` で行います。
