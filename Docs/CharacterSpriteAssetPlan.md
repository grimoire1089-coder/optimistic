# キャラクタースプライト素材方針

## 前提

マップの基本グリッドは `48px x 48px`。
`RoomMapGridModule.gd` の `cell_size` も `Vector2(48.0, 48.0)` になっている。

ロビンの現在方式は、歩行用スプライトシートを1枚で持ち、`hframes` / `vframes` で切り出している。
これは動いてはいるが、今後のキャラクター追加では扱いにくいので、将来的にやめたい。

## 足元サイズと見た目サイズを分ける

キャラクターは、ゲーム上の占有サイズと、見た目の画像サイズを分けて考える。

### 占有サイズ

移動・家具判定・クリック基準などに使うサイズ。
グリッド基準で管理する。

例:

```text
2 x 4 グリッド = 96px x 192px
```

### 見た目サイズ

表示画像そのもののキャンバスサイズ。
頭や角、装飾、身体の高さを含む。
足元を下側に置き、上方向へ伸びる形にする。

ジッピーのように大きめの立ち絵キャラは、見た目だけを高くしてよい。

例:

```text
2 x 8 グリッド = 96px x 384px
```

この場合、クリック・足元・移動判定は別途小さく保ち、画像だけ高く表示する。

## ジッピー仮素材の次の基準

現在の `Zippy_Game_0001.png` は正方形素材なので、グリッドに合わせるには扱いづらい。
次の仮素材は以下を推奨する。

```text
キャンバス: 96px x 384px
背景: 透過
足元: キャンバス下側に接地
左右: 2グリッド幅に収める
高さ: 8グリッド内に収める
```

高解像度で作る場合は、同じ比率で拡大する。

```text
2倍: 192px x 768px
3倍: 288px x 1152px
4倍: 384px x 1536px
```

Godot側ではインポート後に表示スケールで調整し、最終表示を `96px x 384px` 相当に合わせる。

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
