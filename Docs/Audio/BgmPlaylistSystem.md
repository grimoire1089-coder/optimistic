# BGM Playlist System

## 目的

BGM再生を、場所やシーンごとの直書きから分離し、`BgmPlaylistData` リソースと汎用プレイヤーで管理する。

## ファイル構成

```text
Scripts/Systems/Audio/BgmPlaylistData.gd
Scripts/Systems/Audio/BgmPlaylistPlayerModule.gd
Scripts/Systems/Audio/BgmFadePlaylistPlayerModule.gd
Data/Audio/BgmPlaylists/*.tres
```

## BgmPlaylistData

BGMプレイリスト用のResource。

主な項目:

- `playlist_id`
- `display_name`
- `tracks`
- `shuffle_tracks`
- `start_index`
- `restart_if_same`
- `advance_when_finished`
- `fade_out_seconds`
- `fade_in_seconds`

## BgmPlaylistPlayerModule

`BgmPlaylistData` を受け取り、`AudioPlayer` 経由でBGMを再生する基本モジュール。

特徴:

- `_process` 監視を使わない
- `AudioPlayer.bgm_finished` シグナルで次曲へ進む
- 読み込んだBGMはキャッシュする
- `playlist` が未設定の場合は、互換用の `bgm_paths` を使う

## BgmFadePlaylistPlayerModule

`BgmPlaylistPlayerModule` を継承したフェード対応モジュール。
場所移動などでプレイリストを切り替えるシーンでは、こちらを使う。

特徴:

- `BgmPlaylistData.fade_out_seconds` を使って旧BGMをフェードアウトする
- `BgmPlaylistData.fade_in_seconds` を使って新BGMをフェードインする
- フェード処理は `AudioPlayer.play_bgm_fade()` に任せる

## 使い方

1. `Data/Audio/BgmPlaylists/` に `.tres` を作る
2. `tracks` にBGMファイルパスを登録する
3. 場所切り替えがあるシーンには `Node` を追加する
4. script に `res://Scripts/Systems/Audio/BgmFadePlaylistPlayerModule.gd` を設定する
5. `playlist` に作成した `.tres` を設定する

## 例

```text
Data/Audio/BgmPlaylists/RobinRoomBgmPlaylist.tres
Data/Audio/BgmPlaylists/FelicityBgmPlaylist.tres
Data/Audio/BgmPlaylists/InfrastructureRoomBgmPlaylist.tres
```

## 注意

旧 `RobinRoomBgmListModule.gd` は削除済み。
新規・既存シーンとも、場所切り替えがある場合は `BgmFadePlaylistPlayerModule.gd` を使う。
単純な即時再生だけでよい場合は `BgmPlaylistPlayerModule.gd` も使える。
