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
4. 書き出しシート — 「完璧ループを 4K で書き出し」/ "Export perfect 4K loops"
5. 別テーマ(Magenta Pop)— 「気分で選べる4つのネオン」/ "Four neon themes"
