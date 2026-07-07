# Encyclopedia Generalization Plan

## Status

The current encyclopedia should be treated as a general encyclopedia, not only a food encyclopedia.
Robin confirmed Lapis is registered correctly, and noted that the original request was for an encyclopedia, but the implementation became food-focused.

## Current state

`EncyclopediaOverlay.gd` is already broader than food.
It currently has item tabs for:

- tools
- foods
- drinks
- ingredients

`FoodEncyclopedia.gd` is now a misleading name because it stores unlock state for non-food items such as Lapis.

## Desired near-term tabs

Add these item tabs next when requested:

- materials / 素材
- misc / 雑貨

## Desired long-term encyclopedia domains

Future encyclopedia records should also support non-item domains such as:

- people / 人物
- organizations / 団体
- places / 場所
- world terms / 用語

## Migration direction

Do not hard-rename everything in one risky pass.
Use a safe staged migration:

1. Keep `FoodEncyclopedia.gd` as compatibility for now.
2. Add a generic API or wrapper such as `EncyclopediaRegistry` later.
3. Keep the existing save key readable so old saves are not broken.
4. Move item unlock state to a general item encyclopedia section.
5. Add separate sections for people, organizations, and places when their data resources exist.

## Naming rule going forward

New code should avoid food-only names unless the feature is truly food-only.
Prefer names like:

- Encyclopedia
- EncyclopediaRegistry
- EncyclopediaOverlay
- EncyclopediaItemSourceModule
- EncyclopediaCategoryTabModule

## Performance rule

Keep the current hidden-UI rebuild fix.
Unlock state can update immediately, but visible UI should only rebuild when the encyclopedia overlay is open or explicitly refreshed.
