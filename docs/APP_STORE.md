# Math2Music iOS — App Store 公開戦略

## 競合分析(2026年7月調査)

| 競合 | 内容 | 価格 | 弱点 |
|---|---|---|---|
| [Fourier Series Visualiser](https://apps.apple.com/us/app/fourier-series-visualiser/id1582827502) (Jack Finnis) | 手描き図形→エピサイクル描画 | 無料 | **音が出ない**、動画書き出しなし |
| [Fourier Synthesizer](https://www.148apps.com/app/404166615/) (Eiji Konaka) | 倍音スライダー→音 | 教育系 | **映像美なし**、SNS 共有なし、古い |
| [Epicycles](https://apps.apple.com/us/app/epicycles/id6450433959) | 複素フーリエ級数の教育可視化 | 教育系 | 音楽・共有要素なし |
| [Vibely](https://apps.apple.com/us/app/music-visualizer-vibely/id1528056717) / [STAELLA](https://apps.apple.com/us/app/staella-music-visualizer-vj/id1370376584) / [Spectra](https://apps.apple.com/us/app/spectra-music-visualizer/id1505140281) 等 | 既存楽曲のビジュアライズ→動画 | freemium / サブスク | **数式・シンセ要素なし**、透かし・課金誘導 |
| [Bloom](https://generativemusic.com/bloom.html) / [Wotja](https://wotja.com/app/) / Musyc(生成音楽トイ) | タッチ→アンビエント生成 | 買い切り $4 前後 / freemium | 数式・エピサイクル映像なし |

### ポジショニング

**「数式エディット × ネオンエピサイクル映像 × リアルタイムシンセ × シームレスループ動画書き出し」を1本で完結させるアプリは存在しない。**
教育ツール(音なし)とミュージックビジュアライザー(数式なし)の間の空白を取る。

### 差別化の柱(ストア訴求点)

1. スライダー8本で「自分の数式」を作れる — 教育系の説得力 × トイの触り心地
2. 波形がリアルタイムに音程を操る唯一の体験(音階クオンタイズで音楽として成立)
3. **数学的に**シームレスな 3/6/12 秒ループ MP4(透かしなし・画面録画でなくオフライン再レンダリング)
4. 買い切り・広告なし・トラッキングなし・オフライン完結

## 機能改善アイデア(2026-07-20 ASO 競合調査より、優先度順)

1. **9:16 縦動画書き出し** — TikTok/Reels/Spotify Canvas 用。Canvas は縦・3〜8 秒ループが仕様で、既存の 6 秒ループがそのまま刺さる。競合 Vibely はこの用途訴求(Canvas/Shorts)で TikTok 実績を伸ばしている
2. **書き出し動画への音声トラック同梱**(未対応なら)— 競合ビジュアライザーは音楽入り動画が前提。対応済みならストア文言・スクショで明示する
3. **数式の共有**(URL/QR でプリセットを渡す)— 受け取った人がアプリに誘導される拡散ループ
4. **長尺書き出し**(1〜10 分、作業用 BGM 用途)— STAELLA は「1曲まるごと自動録画」を訴求点にしている
5. **日本語ローカライズの優位維持** — Fourier 系競合(Visualiser/Epicycles)は ja ページ未ローカライズ。日本語検索は現状ほぼ無風で、ja メタデータの質がそのまま順位に効く

## 価格戦略

- **買い切り ¥600 / $3.99**(Bloom と同帯)
- サブスク疲れ層に「透かしなし・追加課金なし」を明示
- 学割/セールは教育系ハッシュタグ(#math #satisfying)が伸びるタイミングで

## ストア メタデータ案(初期案 — 現行の正は `store/metadata/`。2026-07-20 に「AI 感」除去の書き直し・ASC 反映済み)

### 日本語

- **名前**: Math2Music — 数式が音楽になる
- **サブタイトル**: フーリエ級数シンセ&ループ動画メーカー
- **キーワード**: 数式,フーリエ,音楽,シンセ,ビジュアライザー,ループ動画,エピサイクル,数学,satisfying,波形
- **説明文(冒頭)**: スライダーを動かすと数式が変わり、数式が円を描き、円が波形を描き、波形が音を奏でる。Math2Music は数学がそのまま音楽になる、新感覚のジェネレーティブ・シンセです。完璧にループする動画を書き出して、SNS でシェアしよう。

### English

- **Name**: Math2Music — Formulas Made Audible
- **Subtitle**: Fourier synth & loop video maker
- **Keywords**: math,fourier,synth,visualizer,loop,video,epicycle,satisfying,waveform,generative
- **Description (lead)**: Move a slider, change the formula. The formula spins circles, the circles draw a wave, and the wave plays the music. Export a mathematically perfect seamless loop and share it anywhere.

### カテゴリ / 対象年齢

- プライマリ: ミュージック / セカンダリ: エンターテインメント
- 4+(UGC なし・ネットワークなし)

### スクリーンショット構成(6.7" / 6.1" 各5枚)

1. メイン1画面 UI(再生中・Neon Cyan)+「数式が音楽になる」
2. 倍音スライダー操作中(数式ラベルが変わる様子)
3. スケールクオンタイズのメニュー+「ちゃんと音楽になる」
4. 書き出しシート+「つなぎ目のないループ動画を4Kで」
5. テーマ4種の比較グリッド

## 審査チェックリスト

- [x] `PrivacyInfo.xcprivacy`: データ収集ゼロ、UserDefaults = CA92.1
- [x] App Privacy 申告 →「データは収集されません」
- [x] `NSPhotoLibraryAddUsageDescription`(共有シートの「ビデオを保存」で必須)
- [x] マイク・位置情報・トラッキング API 不使用
- [x] `ITSAppUsesNonExemptEncryption: false`(輸出コンプライアンス自動回答)
- [x] Mac で `xcodegen generate` → Simulator ビルド+実機向けアーカイブ成功(2026-07-18)。実機での動作確認は未実施
- [x] bundle id を `com.senatakasawa.math2music` に変更 + Signing Team(6325NASDSP)設定
- [x] プライバシーポリシー/サポートページ作成(homepage リポジトリ、要デプロイ)
  - サポート URL: `https://takasawadynamics.com/apps/math2music/`
  - プライバシーポリシー URL: `https://takasawadynamics.com/apps/math2music/privacy`
- [ ] App Store Connect でアプリ作成+スクリーンショット/説明文を登録
- [ ] 実機で最終確認(下記の確認項目)→ Xcode からアーカイブをアップロード

## Mac でのビルド手順

```bash
brew install xcodegen
cd ios
xcodegen generate
open Math2Music.xcodeproj
```

1. TARGETS → Math2Music → Signing & Capabilities で Team と bundle id を設定
2. 実機(iPhone)を選んで Run — Simulator は音声レイテンシ/ルートが実機と異なるため最終確認は実機で
3. 確認項目: 8プリセットの再生 / スライダー即時反映 / スケールの音楽性 / iPhone SE でスクロールが出ないこと / 3・6・12 秒書き出し → リピート再生でシームレスなこと / 共有シートから「ビデオを保存」

## 調査ソース

- https://apps.apple.com/us/app/fourier-series-visualiser/id1582827502
- https://jackfinnis.com/apps/fourier
- https://www.148apps.com/app/404166615/
- https://apps.apple.com/us/app/epicycles/id6450433959
- https://apps.apple.com/us/app/music-visualizer-vibely/id1528056717
- https://apps.apple.com/us/app/staella-music-visualizer-vj/id1370376584
- https://apps.apple.com/us/app/spectra-music-visualizer/id1505140281
- https://generativemusic.com/bloom.html
- https://wotja.com/app/
