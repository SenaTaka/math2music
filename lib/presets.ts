export type HarmonicTerm = {
  frequency: number;
  amplitude: number;
  phase?: number;
};

export type FormulaPreset = {
  id: string;
  name: string;
  label: string;
  color: string;
  baseFrequency: number;
  terms: HarmonicTerm[];
};

const smoothTerms: HarmonicTerm[] = Array.from({ length: 7 }, (_, index) => {
  const n = index + 1;
  return { frequency: n, amplitude: 1.5 / Math.sqrt(n) };
});

const punchTerms: HarmonicTerm[] = [
  { frequency: 1, amplitude: 5 },
  { frequency: 5, amplitude: -1 },
];

const squareTerms: HarmonicTerm[] = Array.from({ length: 7 }, (_, index) => {
  const odd = 2 * index + 1;
  return { frequency: odd, amplitude: 2 / odd };
});

const chaosTerms: HarmonicTerm[] = Array.from({ length: 12 }, (_, index) => {
  const odd = 2 * (index + 1) + 1;
  return { frequency: odd, amplitude: 6 / odd };
});

export const formulaPresets: FormulaPreset[] = [
  {
    id: "smooth",
    name: "Smooth",
    label: "y = Σ[n=1..7] 1.5 / √n · sin(nx)",
    color: "#63e6ff",
    baseFrequency: 110,
    terms: smoothTerms,
  },
  {
    id: "punch",
    name: "Punch",
    label: "y = 5sin(x) - sin(5x)",
    color: "#f472ff",
    baseFrequency: 132,
    terms: punchTerms,
  },
  {
    id: "square",
    name: "Square",
    label: "y = Σ[k=0..6] 2 / (2k + 1) · sin((2k + 1)x)",
    color: "#ffe066",
    baseFrequency: 147,
    terms: squareTerms,
  },
  {
    id: "chaos",
    name: "Chaos",
    label: "y = 6Σ[k=1..12] 1 / (2k + 1) · sin((2k + 1)x)",
    color: "#7c83ff",
    baseFrequency: 165,
    terms: chaosTerms,
  },
];

export const defaultPresetId = formulaPresets[0].id;

const clamp = (value: number, min: number, max: number) =>
  Math.min(Math.max(value, min), max);

export const DEFAULT_FORMULA_PARAM = 1;
export const DEFAULT_TEMPO_BPM = 120;

export const buildPresetWithParameters = (
  preset: FormulaPreset,
  formulaParam: number,
  tempoBpm: number,
): FormulaPreset => {
  const normalizedParam = clamp(formulaParam, 0.5, 2);
  const normalizedTempo = clamp(tempoBpm, 60, 180);
  const tempoRatio = normalizedTempo / DEFAULT_TEMPO_BPM;

  return {
    ...preset,
    baseFrequency: preset.baseFrequency * tempoRatio,
    terms: preset.terms.map((term) => ({
      ...term,
      amplitude: term.amplitude * normalizedParam,
    })),
  };
};
