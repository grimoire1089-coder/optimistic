# Ambience Playlist System

## 目的

環境音を、場所やシーンごとの直書きから分離し、`AmbiencePlaylistData` リソースと汎用プレイヤーで管理する。

BGMと同じく、常時 `_process` 監視や毎フレーム `load()` を使わない軽量構成にする。

## ファイル構成

```text
Scripts/Systems/Audio/AmbiencePlaylistData.gd
Scripts/Systems/Audio/AmbiencePlaylistRegistry.gd
Scripts/Systems/Audio/AmbiencePlaylistPlayerModule.gd
Data/Audio/AmbiencePlaylists/*.tres
```

## AmbiencePlaylistData

環境音プレイリスト用のResource。

主な項目:

- `playlist_id`
- `display_name`
- `tracks`
- `shuffle_tracks`
- `start_index`
- `restart_if_same`
- `fade_out_seconds`
- `fade_in_seconds`

## AmbiencePlaylistRegistry

場所IDと環境音プレイリストを対応させるResource。

例:

```text
robin_room -> NoAmbiencePlaylist
infrastructure_room -> NoAmbiencePlaylist
```

## AmbiencePlaylistPlayerModule

`AmbiencePlaylistData` を受け取り、`AudioPlayer` 経由で環境音を再生する汎用モジュール。

特徴:

- `_process` 監視を使わない
- 読み込んだ環境音はキャッシュする
- プレイリストが空の場合は `AudioPlayer.stop_ambience()` で環境音を止める
- `AudioPlayer.play_ambience_fade()` が存在する場合はフェード切り替えを使う

## MainSceneAmbienceLocationModule

`MainSceneMapTravelModule.active_map_changed` を受け取り、場所IDに応じて `AmbiencePlaylistPlayerModule.set_playlist()` を呼ぶ。

参照解決が終わったら `_process` を停止する。

## 使い方

1. `Data/Audio/AmbiencePlaylists/` に `.tres` を作る
2. `tracks` に環境音ファイルパスを登録する
3. `MainSceneAmbienceRegistry.tres` に場所IDとプレイリストを登録する
4. シーンに `AmbiencePlaylistPlayerModule` を配置する
5. 場所連動が必要な場合は `MainSceneAmbienceLocationModule` を配置する

## 現在の初期状態

環境音素材が未確定でも安全に動くよう、最初は `NoAmbiencePlaylist.tres` を使う。

```text
Data/Audio/AmbiencePlaylists/NoAmbiencePlaylist.tres
Data/Audio/AmbiencePlaylists/MainSceneAmbienceRegistry.tres
```

`NoAmbiencePlaylist.tres` は空のプレイリストなので、再生中の環境音があれば止める。

## 注意

環境音はBGMと違い、曲終了で次へ進める用途よりも、場所ごとに鳴り続けるループ音として使う想定。
複数トラックを登録した場合は、場所切り替え時や再設定時に開始トラックとして選ばれる。
