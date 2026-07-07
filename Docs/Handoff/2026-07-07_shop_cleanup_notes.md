# Shop Cleanup Notes

## Verified behavior

- Startup has no red error.
- Shop open, back, and open again looks stable.
- Shop tab switching works.
- Purchase updates price and button state without rebuilding item cards.

## Keep

- Keep current verified shop behavior.
- Do not delete unrelated code.
- Keep Godot 4.7 red-error-free.
- Keep purchase updates lightweight.
- Avoid memory leaks.

## Cleanup tasks

- Move shop cache warmup into the loading flow when local editing is available.
- Remove shop-specific warmup from `SceneRouter.gd` after the loading-flow move.
- Review typed arrays in `ShopRuntimeCache.gd`.
- Consider moving shop layout cache code into `Scripts/UI/Shop/Modules/ShopLayoutCacheModule.gd`.
- Recheck cached card cleanup and stale references.
- Recheck that invalidated cards are freed once.
- Recheck that cached button and price-label dictionaries do not keep stale references.
- Add a short shop-cache design doc if time allows.

## Final checks

- Startup no red error.
- Loading to main scene works.
- Shop open, back, and open works.
- Tab switching works.
- Purchases update state only.
- Book owned state works.
- FPS does not get worse.
