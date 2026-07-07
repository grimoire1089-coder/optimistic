# Return to AI Character System

## Status

Encyclopedia work is closed for now.
Robin confirmed the new Material and Misc tabs no longer have a draggable split boundary.

## Side work completed before returning

- Food encyclopedia unlock FPS drop was fixed.
- Hidden encyclopedia UI no longer rebuilds on every unlock.
- Message log now has an entry-based API.
- Food unlock and travel unlock notices are created as styled log cards from the start.
- Lapis is silently registered in the encyclopedia when entering the main scene.
- Encyclopedia direction was recorded as a general encyclopedia, not food-only.
- Material and Misc tabs were added.
- Material and Misc pages now use fixed panels instead of `HSplitContainer`.

## Return point

Next development should return to the AI character system.

Suggested next checks before adding new AI features:

1. Review current AI character scene/module structure.
2. Identify which AI behavior module should be the next main target.
3. Keep main scripts thin and add behavior as modules.
4. Avoid per-frame heavy processing.
5. Prefer signal/event driven updates over polling.

## Important reminder

Do not keep expanding the encyclopedia unless Robin asks for it again.
The current encyclopedia state is good enough for now.
