# Chat Handoff: Audio / Ambience / Debug UI

## プロジェクト

- Repository: `grimoire1089-coder/optimistic`
- Godot: 4.7 stable
- 方針:
  - 修正は必要なところだけ。
  - 本体スクリプトは本体、機能はモジュール形式。
  - 軽い処理を優先。
  - `_process` 常時監視を増やさない。
  - ファイル配置を整理して進める。

## 完了済み: BGM軽量化・最適化

BGMまわりは一区切り完了。

### 重要な構成

```text
Scripts/Core/Audio/AudioPlayer.gd
Scripts/Systems/Audio/BgmPlaylistData.gd
Scripts/Systems/Audio/BgmPlaylistRegistry.gd
Scripts/Systems/Audio/BgmPlaylistPlayerModule.gd
Scripts/Systems/Audio/BgmFadePlaylistPlayerModule.gd
Data/Audio/BgmPlaylists/*.tres
Docs/Audio/BgmPlaylistSystem.md
```

### 現状

- `AudioPlayer.gd` に `bgm_finished(stream)` シグナルあり。
- BGMは毎フレーム監視ではなく、`AudioPlayer.bgm_finished` のシグナルで次曲へ進む。
- BGM読み込みはキャッシュあり。
- `MainScene.tscn` は `BgmFadePlaylistPlayerModule.gd` を使っている。
- 場所別BGMは `MainSceneBgmLocationModule.gd` が担当。
- 場所ID対応は `MainSceneBgmRegistry.tres`。
- ロビン部屋BGMとインフラ室BGMの切り替えはユーザー確認済み。
- フェード切り替えも導入済み。

### ユーザー確認済み

- ロビン部屋でBGMが鳴る。
- インフラ室へ移動するとBGMが切り替わる。
- ロビン部屋へ戻るとロビン部屋BGMへ戻る。
- FPS 60維持。
- `_process nodes` に `MainSceneBgmLocationModule` が残り続けない。

## 完了済み: Ambience環境音システム

環境音もBGMと同じ思想で整理済み。

### 重要な構成

```text
Scripts/Systems/Audio/AmbiencePlaylistData.gd
Scripts/Systems/Audio/AmbiencePlaylistRegistry.gd
Scripts/Systems/Audio/AmbiencePlaylistPlayerModule.gd
Scripts/Scenes/Main/Modules/MainSceneWeatherAmbienceModule.gd
Data/Audio/AmbiencePlaylists/NoAmbiencePlaylist.tres
Data/Audio/AmbiencePlaylists/RainAmbiencePlaylist.tres
Data/Audio/AmbiencePlaylists/MainSceneWeatherAmbienceRegistry.tres
Docs/Audio/AmbiencePlaylistSystem.md
```

### 現状

- `AudioPlayer.gd` に `play_ambience_fade()` 追加済み。
- `AmbiencePlaylistPlayerModule.gd` は `_process` を使わない。
- 環境音はロード後にキャッシュする。
- プレイリストが空なら `AudioPlayer.stop_ambience()`。
- 雨環境音は `res://Assets/Audio/Ambience/Rain.ogg`。
- `RainAmbiencePlaylist.tres` に登録済み。
- `MainSceneWeatherAmbienceRegistry.tres` は以下の対応。

```text
sunny -> NoAmbiencePlaylist
rain  -> RainAmbiencePlaylist
```

- `WeatherSystem.gd` は天気判定だけを担当する方針。
- `WeatherSystem.gd` の直接環境音再生は `play_ambience_directly = false` が標準。
- 実際の環境音再生は `MainSceneWeatherAmbienceModule.gd` が `WeatherSystem.weather_changed` を受けて行う。
- 雨音が1回で止まる問題は、`loop_tracks = true` と `AmbiencePlaylistPlayerModule._apply_stream_loop_setting()` で修正済み。

### ユーザー確認済み

- 晴れの日は環境音なし。
- 雨の日は `Rain.ogg` が鳴る。
- 雨→晴れで環境音が止まる。
- BGMの場所切り替えは今まで通り。
- FPS 60維持。
- `_process nodes` に `MainSceneWeatherAmbienceModule` が残り続けない。
- その後、雨音がループしない問題が出たため修正済み。次チャットでは雨音ループ確認から始めるとよい。

## 完了済み: DBGパネル天候操作

### 重要ファイル

```text
Scripts/UI/Debug/AIDebugPanel.gd
```

### 現状

- `DBG` パネルに天候操作を追加済み。
  - `晴れ`
  - `雨`
  - `抽選`
- `晴れ / 雨` は `WeatherSystem.set_weather()` を呼ぶ。
- `抽選` は `WeatherSystem.update_daily_weather(GameClock.day)` を呼ぶ。
- パネル内に現在天候表示あり。
- ユーザー確認: 天候操作はOK。

## 完了済み: DBGパネル位置・高さ調整

### 現状

- `AIDebugPanel.gd` の `PANEL_SIZE` は `Vector2(356.0, 336.0)`。
- `PANEL_MARGIN` は `Vector2(24.0, 92.0)`。
- AIキャラクターHUDと同じ右下詰め・同じ高さに合わせた。
- 中身が増えたため、パネル内は `ScrollContainer` 化済み。

### ユーザー確認済み

- 天候操作などはOK。
- 最後の修正で「UIの高さも合わせてほしい、今のは下すぎる」に対応済み。
- 次チャットでは、まずDBGパネルの高さ・位置感の確認から再開するとよい。

## 次チャットで最初に確認すること

```text
git pull
Godot起動
DBGパネルの高さがAIキャラクターHUDと揃っているか
DBGパネルが下すぎないか
雨ボタンで雨音が鳴るか
雨音が最後まで行ってもループするか
晴れボタンで雨音が止まるか
FPS 60維持
_process nodes に不要なデバッグ/環境音モジュールが残り続けないか
```

## 次の候補

1. DBGパネルの見た目微調整
2. 環境音素材追加時に `.tres` を増やす
3. 天候表示UIを通常HUDにも出す
4. AudioSettings UIで Ambience 音量も操作できるようにする
5. SFX / Voice 側の軽量化確認
