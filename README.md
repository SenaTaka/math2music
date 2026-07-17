# Math to Music Visualizer

数式(フーリエ級数)から音と波形を生成する、インタラクティブな可視化アプリです。  
エピサイクル表示とリアルタイム波形表示を同期し、Web Audio API で音を再生します。

**Web 版(このリポジトリ直下)に加えて、SwiftUI フルネイティブの iOS 版(`ios/`)があります。**
iOS 版の詳細は後述の「iOS アプリ」セクションを参照してください。

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

## iOS アプリ (`ios/`)

有料アプリとして公開できる品質を目標にした SwiftUI フルネイティブ実装です。
スクロールなしの1画面 UI で、Web 版の機能に加えて以下を備えます。

### iOS 版の機能

- **自由数式エディタ**: 倍音スライダー8本(n = 1..8, −5〜+5)で y = Σ aₙ·sin(nx) を直接編集。数式ラベルは自動生成
- **プリセット8種**: Smooth / Punch / Square / Chaos(Web 版由来)+ Saw / Organ / Bell / Pulse
- **🎲 ランダマイズ**: ワンタップで数式を抽選
- **音階クオンタイズ**: Free / ペンタトニック / メジャー / マイナー(12平均律・ルート A)
- **カラーテーマ4種**: Neon Cyan / Magenta Pop / Amber Glow / Matrix
- **シームレスループ動画書き出し**: 3/6/12 秒 × 1080p/4K の透かしなし MP4。画面録画ではなく AVAssetWriter によるオフライン再レンダリング(映像は決定的関数、音声はウォームアップ1周+等パワークロスフェードで数学的に継ぎ目なし)
- **お気に入り保存 / ハプティクス / 日英ローカライズ / オンボーディング**
- プライバシー: データ収集ゼロ(`PrivacyInfo.xcprivacy` 同梱)、マイク・ネットワーク不使用

### iOS 版の技術構成

- SwiftUI + `@Observable`(iOS 17+, iPhone 縦画面専用)
- 音声: AVAudioEngine + AVAudioSourceNode + 自作 DSP(加算合成)。Web 版の `PeriodicWave` 構築と数学的に等価(数値クロスチェック済み、誤差 ~1e-16)
- Web Audio 互換の要点: lowpass の Q は dB 解釈(5.4 dB → linear ≈ 1.86)、`setTargetAtTime` は one-pole で再現、フィルタ→サチュレータ→パンのチェーン順も同一
- パラメータ受け渡しは swift-atomics によるロックフリー(レンダースレッドはアロケーションなし)
- 描画: CGContext ベースの `SceneRenderer` をライブ表示(SwiftUI Canvas)と動画書き出しで共用

### ビルド方法(Mac が必要)

```bash
brew install xcodegen
cd ios
xcodegen generate
open Math2Music.xcodeproj
```

Signing & Capabilities で Team と bundle id(`com.example.math2music` を変更)を設定し、実機で Run してください。
公開準備(競合分析・価格戦略・審査チェックリスト)は `docs/APP_STORE.md`、機能改善の提案リストは `docs/IMPROVEMENTS.md` を参照してください。
