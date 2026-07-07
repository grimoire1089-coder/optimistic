# Food Encyclopedia FPS Fix

## Goal

Reduce FPS drops when a food encyclopedia unlock notice is shown.

## Main fix

The old notice styler scanned existing message-log cards after notices were queued.
The new flow styles only the newly entered message card through the message list child-entered signal.

## Current behavior

- Food unlock message is still added to the normal message log.
- Food unlock card still uses the gold style.
- Food unlock SFX still plays once for the new notice.
- Existing log cards are not rescanned every time a notice is pushed.

## Warmup

`FoodEncyclopedia.gd` prepares the unlock notice module on ready.
The notice module preloads the food unlock SFX through `prepare_runtime_cache()`.

## Next step if FPS still drops

Cache normal MessageLogPanel card StyleBoxFlat instances instead of creating a new StyleBoxFlat for every message card.
