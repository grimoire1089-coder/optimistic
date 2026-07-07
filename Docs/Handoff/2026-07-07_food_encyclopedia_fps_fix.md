# Food Encyclopedia FPS Fix

## Goal

Reduce FPS drops when a food encyclopedia unlock notice is shown.

## Current main fix

Food encyclopedia unlock notices no longer scan or track existing message-log cards.

`MessageLogPanel.gd` now has a dedicated API:

```gdscript
add_food_encyclopedia_unlock_message(message, notice_stream, volume_db)
```

This queues a normal-log message with the `food_encyclopedia_unlock` style id.
The message card is created as a gold encyclopedia card from the start.

## Current behavior

- Food unlock message is still added to the normal message log.
- Food unlock card is gold at creation time.
- Food unlock SFX still plays once for the new notice.
- No message-log card scan is needed.
- No child-entered-tree styler is needed.

## Warmup

`FoodEncyclopedia.gd` prepares the unlock notice module on ready.
The notice module preloads the food unlock SFX through `prepare_runtime_cache()`.

## Performance notes

`MessageLogPanel.gd` also caches card StyleBoxFlat instances by channel and style id.
This avoids creating a new StyleBoxFlat for every message card.

## Next step if FPS still drops

Check message-card animation and queue timing next.
Possible next mitigation: disable animation for encyclopedia unlock cards or batch unlock notices.
