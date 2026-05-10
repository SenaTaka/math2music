# Math to Music Visualizer

数式(フーリエ級数)から音と波形を生成する、インタラクティブな可視化アプリです。  
エピサイクル表示とリアルタイム波形表示を同期し、Web Audio API で音を再生します。

## 主な機能

- 4種類の数式プリセット切り替え
  - Smooth / Punch / Square / Chaos
- エピサイクルと波形のリアルタイム描画
- ネオン強化エフェクト（背景パルス、残光、ゴースト波形）
- 再生/停止、音量調整
- 6秒シームレス `Loop Rec` 録画（ショート動画向け）
- 録画ファイルのダウンロード / 共有 / リンクコピー
- 数式パラメータ調整
  - `Formula Param` (0.5 - 2.0)
- テンポ調整
  - `Tempo` (60 - 180 BPM)
- 周波数レンジ調整
  - `Low Hz` (20 - 500)
  - `High Hz` (500 - 5000)

## 技術スタック

- Next.js 16
- React 19
- TypeScript
- Tailwind CSS 4
- Web Audio API
- Canvas 2D

## セットアップ

```bash
npm install
```

## 開発サーバー起動

```bash
npm run dev
```

ブラウザで `http://localhost:3000` を開いて確認します。

## 使い方

1. プリセットを選択する
2. `Play` で再生開始する
3. 必要に応じて以下を調整する
   - `Vol`
   - `Formula Param`
   - `Tempo`
   - `Low Hz` / `High Hz`
4. `Stop` で再生停止する

## 実装メモ

- 描画側の波形振幅(正規化値 -1 から 1)を音声側へ渡し、発振周波数をリアルタイムに変化させています。
- 音色は `PeriodicWave` に加えてサチュレーション、ステレオパン、補助オシレーターを重ねています。
- Web Audio の仕様上、再生開始はユーザー操作(クリック)後に行う必要があります。
- 録画中はループ位相モードに切り替え、先頭と末尾がつながる短尺クリップを生成します。

## 利用可能スクリプト

```bash
npm run dev
npm run build
npm run start
npm run lint
```
