# BGM Playlist System

## 目的

BGM再生を、場所やシーンごとの直書きから分離し、`BgmPlaylistData` リソースと汎用プレイヤーで管理する。

## ファイル構成

```text
Scripts/Systems/Audio/BgmPlaylistData.gd
Scripts/Systems/Audio/BgmPlaylistPlayerModule.gd
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

## BgmPlaylistPlayerModule

`BgmPlaylistData` を受け取り、`AudioPlayer` 経由でBGMを再生する汎用モジュール。

特徴:

- `_process` 監視を使わない
- `AudioPlayer.bgm_finished` シグナルで次曲へ進む
- 読み込んだBGMはキャッシュする
- `playlist` が未設定の場合は、互換用の `bgm_paths` を使う

## 使い方

1. `Data/Audio/BgmPlaylists/` に `.tres` を作る
2. `tracks` にBGMファイルパスを登録する
3. シーンに `Node` を追加する
4. script に `res://Scripts/Systems/Audio/BgmPlaylistPlayerModule.gd` を設定する
5. `playlist` に作成した `.tres` を設定する

## 例

```text
Data/Audio/BgmPlaylists/RobinRoomBgmPlaylist.tres
Data/Audio/BgmPlaylists/FelicityBgmPlaylist.tres
Data/Audio/BgmPlaylists/InfrastructureBgmPlaylist.tres
```

## 注意

古い `RobinRoomBgmListModule.gd` は互換用ラッパーとして残している。
新規シーンでは使わず、必ず `BgmPlaylistPlayerModule.gd` を使う。
