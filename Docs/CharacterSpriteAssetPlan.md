# キャラクタースプライト素材方針

## 前提

マップの基本グリッドは `48px x 48px`。
`RoomMapGridModule.gd` の `cell_size` も `Vector2(48.0, 48.0)` になっている。

ロビンの現在方式は、歩行用スプライトシートを1枚で持ち、`hframes` / `vframes` で切り出している。
これは動いてはいるが、今後のキャラクター追加では扱いにくいので、将来的にやめたい。

## 基準サイズ

キャラクターの基本表示サイズは、まず `2 x 4 グリッド` を基準にする。

```text
2 x 4 グリッド = 96px x 192px
```

このサイズを、ゲーム内での表示サイズ、クリック範囲、初期テスト用の見た目基準として使う。

## 制作用の高解像度素材

画像制作は3倍解像度で行う。
ゲーム内では縮小して `96px x 192px` 相当に表示する。

```text
ゲーム内表示: 96px x 192px
制作画像: 288px x 576px
倍率: 3倍
背景: 透過
足元: キャンバス下側に接地
左右: 2グリッド幅に収める
高さ: 4グリッド内に収める
```

Godot側では `AICharacterSpriteFitModule` で、画像サイズから自動的に表示スケールを決める。
3倍素材 `288px x 576px` なら、表示倍率は `1/3` になり、ゲーム内では `96px x 192px` になる。

## 足元・見た目・クリック範囲

最初は全部 `96px x 192px` を基準に揃える。

将来的に角や装飾が大きいキャラクターで、見た目だけ大きくしたい場合は、以下を分ける。

- 足元・移動判定
- クリック範囲
- 見た目キャンバス

ただしジッピーの初期テストでは分けすぎない。
まずは `96px x 192px` で安定させる。

## 将来の向き画像方式

今後は1枚のスプライトシートではなく、向きごとに別ファイルを使う方針にする。

例:

```text
Assets/Characters/Zippy/Sprites/Zippy_Idle_Down.png
Assets/Characters/Zippy/Sprites/Zippy_Idle_Up.png
Assets/Characters/Zippy/Sprites/Zippy_Idle_Left.png
Assets/Characters/Zippy/Sprites/Zippy_Idle_Right.png
Assets/Characters/Zippy/Sprites/Zippy_Walk_Down_01.png
Assets/Characters/Zippy/Sprites/Zippy_Walk_Down_02.png
Assets/Characters/Zippy/Sprites/Zippy_Walk_Up_01.png
Assets/Characters/Zippy/Sprites/Zippy_Walk_Up_02.png
```

斜め方向が必要になったら、後から追加する。
最初は4方向だけでよい。

## 実装方針

- 最初は `ZippyActor` に単体立ち絵だけを表示する。
- 方向別画像の読み替えは、後で `DirectionalSpriteModule` として追加する。
- `ZippyActor` 本体には画像切り替えロジックを詰め込まない。
- クリック範囲、足元範囲、見た目範囲は別々に可視化できるようにする。
- ロビンの既存方式は壊さず、ジッピー側で新方式を試す。
