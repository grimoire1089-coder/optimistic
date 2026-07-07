# 2026-07-08 AI 行動アイテム表示まわり引継ぎメモ

## 背景

AIキャラクターの行動中アイテム表示を、毎フレーム/定期監視寄りの pull 型から、行動側が「出す」「しまう」を宣言する push 型へ少しずつ移行中。

ユーザー確認では、水分補給のアイテム表示は正常に動作した。

その後、制作・読書・ラピス操作にも同じ方式を適用したが、読書とラピス操作でアイテム表示が高速点滅する不具合が出た。

## 点滅の状況

現象:

- 読書中の本アイコンが高速点滅
- ラピス操作中のラピスアイコンが高速点滅

推定原因:

- `AICharacterActionItemDisplayModule` はキャラごとの共有表示モジュール。
- 水分補給・制作・読書・ラピス操作が同じ表示モジュールに対して `show_item_icon()` / `clear_item_icon()` を呼ぶ。
- 他の行動モジュールの `_reset()` / `_reset_action()` が、現在表示中の別行動アイコンまで `clear_item_icon()` で消していた可能性が高い。
- Timer 側の旧フォールバック表示が再表示し、消す/出すが交互に起きて点滅したと考えられる。

## 直近の修正

`AICharacterActionItemDisplayModule.gd` に表示 owner 管理を追加した。

- `show_item_icon(icon_path, global_center, owner = null)` で表示 owner を保持。
- owner は直接参照ではなく `WeakRef` で保持し、メモリリークを避ける。
- `clear_item_icon(owner = null)` は、現在の owner がまだ有効な場合、別モジュールからの空振りクリアを無視する。
- owner が `is_action_item_display_visible()` を返せる場合、それが false になった時だけ Timer 側で自動クリアする。

該当コミット:

- `d3f0ac76a7b0fef22a5b1fbd9d216bdb02c2f4c2` — `Guard action item display clears by owner`

ユーザー確認:

- 点滅は収まった。

## ただし設計上の違和感

ユーザーから「なんか変な仕様」と指摘あり。

現状は、以下が混在していて少し複雑。

1. 行動側が明示的に `show_item_icon()` / `clear_item_icon()` する push 型
2. 表示モジュールが定期的に各行動モジュールを見に行く旧 pull 型フォールバック
3. 共有表示モジュールなので、owner ガードが必要になっている

短期的には点滅対策として owner ガードは有効だが、長期的には仕様を整理した方が良い。

## 次のチャットで話すべき設計方針

候補A: 完全 push 型に寄せる

- `AICharacterActionItemDisplayModule` は「表示する/消す」だけにする。
- 行動モジュールを毎回見に行く `_get_active_item_source()` フォールバックを最終的に削除する。
- 各行動モジュールが必ず開始/終了/中断時に表示を制御する。
- 一番軽く、仕様も明確。
- ただし、全行動の終了パスで消し忘れがないか慎重に確認が必要。

候補B: 表示要求を専用 Resource/State にまとめる

- `ActionItemDisplayRequest` のような小さな状態データを作る。
- owner、icon_path、global_center、priority をまとめる。
- 表示モジュールは現在の request だけを見る。
- 拡張しやすいが、今の規模では少し大げさかもしれない。

候補C: owner ガードを維持しつつ、旧フォールバックを段階的に削る

- 今の状態から安全に進める方針。
- 水分補給・制作・読書・ラピスは push 型へ移行済みなので、まずこの4つを `_get_active_item_source()` から外すか、フォールバック自体を無効化する検討ができる。
- ただし、他に未移行の行動表示がないか検索してから行う。

## 変更済みコミット一覧

- `96e7d674018ac070ebb1912aa5b595b11b0f4833` — 進行バーを `_process()` から Timer 更新へ移行
- `0fae4b754492437e2fe68a6850eea04232ff9e14` — アイテム表示に待機中低頻度チェック設定を追加
- `137f938d6cf1f036801767304088f91cf2bb57a1` — アイテム表示を `_process()` から Timer 更新へ移行
- `d6e09bd368d03df30591babf0420765bd8ba2081` — `show_item_icon()` / `clear_item_icon()` の表示 API を追加
- `d3cf1af1e191a5b628898d291c77b27d03c1424d` — 水分補給を宣言型アイテム表示へ接続
- `794e192455c4476afaa7290750756ec0a65f8f47` — 制作を宣言型アイテム表示へ接続
- `d0fe8edb3d787494b4a8b5e6899477fbaa61ddb7` — 読書を宣言型アイテム表示へ接続
- `49b0a96335f3981db6b4c4cb30234b8454a2f7b2` — ラピス操作を宣言型アイテム表示へ接続
- `d3f0ac76a7b0fef22a5b1fbd9d216bdb02c2f4c2` — owner ガードで点滅対策

## 次にやるなら

1. `AICharacterActionItemDisplayModule.gd` の責務を整理する。
2. push 型に完全移行するか、owner ガード付きの暫定仕様を残すか決める。
3. 完全 push 型にするなら、旧フォールバック `_get_active_item_source()` / `_should_show_source()` / 各 behavior path export の削除または無効化を検討する。
4. 削除する場合も、関係ないコードは消さず、表示系の責務だけを最小変更で整理する。

## 注意

ロビンは FPS 低下とメモリリークが特に嫌い。

- 毎フレーム監視は避ける。
- owner 参照は強参照で保持し続けない。
- 共有表示モジュールで複数行動が取り合う設計は、できれば単純化する。
