# math2music ASO ノート

## 2026-07-19 初回設計
- 競合調査は `docs/APP_STORE.md`(2026-07 実施)を採用(二重調査しない):
  教育系フーリエ可視化(音なし)とミュージックビジュアライザー(数式なし)の間の空白を取るポジショニング。
- name(ja): `Math2Music — 数式が音楽になる`(21字)/ subtitle: `フーリエ級数シンセ&ループ動画メーカー`(19字)
- name(en): `Math2Music — Formula Synth`(26字)/ subtitle: `Equations into loop videos`(26字)
- keywords はクロスローカライズ総枠(ja+en 200字)で重複ゼロ設計:
  - ja: ビジュアライザー,エピサイクル,数学,satisfying,波形,作曲,音,サイン波,関数,理系
  - en: math,fourier,visualizer,epicycle,waveform,generative,sound,music,wave,educational
  - name/subtitle 使用語(数式,音楽,フーリエ,級数,シンセ,ループ,動画,formula,synth,equations,loop,videos)は keywords から除外済み。
- 価格: 買い切り ¥600(JPN ベース、ASC には API で設定済み)。
- 検索順位の記録はリリース 4 週後にここへ追記する。

## スクリーンショット構成(6.9" 縦 1290×2796、ja/en 各5枚)
1. メイン画面(再生中・Neon Cyan)— 「数式が音楽になる」/ "Math becomes music"
2. 倍音スライダー操作 — 「スライダー8本で自分の数式を作る」/ "Shape your own formula"
3. スケール選択 — 「動かすだけで、ちゃんと音楽になる」/ "Always in key"
4. 書き出しシート — 「つなぎ目のないループ動画を4Kで」/ "Seamless loops, exported in 4K"(2026-07-20 変更)
5. 別テーマ(Magenta Pop)— 「気分で選べる4つのネオン」/ "Four neon themes"

## 2026-07-20 「AI 感」除去+キーワード見直し(ユーザー指摘対応、ASC 反映済み)
- 指摘: 説明・スクショの文言が AI 生成っぽい。「完璧ループ」が不自然。
- 書き直し方針(今後もこの規律で書く):
  - 「AがBを描き、BがCを描き…」の連鎖レトリック、「新感覚」「〜を奏でる」「数学的に完璧」「安心して使える」型の宣伝語を避ける
  - 動作の事実を です・ます で淡々と書く(「適当に動かしても音を外しません」等)
  - 「完璧ループ」→「つなぎ目のない(ループ)」/ en "mathematically perfect" → "no visible seam"
- keywords 変更(理由付き):
  - ja: エピサイクル→動画素材(検索ボリュームほぼゼロの専門語を、ループ素材を探す実需要語に)/ 理系→音遊び / 音→リズム(初回設計時から実ファイルは リズム 採用)
  - en: stem→oscilloscope(oscilloscope music はニッチだが実在するコミュニティ語。epicycle は 3Blue1Brown 圏の検索があるため維持)
- 競合ページ確認(2026-07-20): Fourier Series Visualiser / Epicycles は ja 未ローカライズ → 日本語検索はほぼ無風。Vibely は実績数字+用途(TikTok/Reels/Spotify Canvas)で訴求 → 機能改善アイデアは docs/APP_STORE.md に記録。
- en promotional_text の "watermark-free" は store_lint が「free」を価格表現として検出 → "with no watermark" に言い換え(以後も free を含む複合語に注意)。
