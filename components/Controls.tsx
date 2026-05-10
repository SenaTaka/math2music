"use client";

import { FormulaPreset } from "@/lib/presets";

type ControlsProps = {
  presets: FormulaPreset[];
  activePresetId: string;
  isPlaying: boolean;
  onPresetChange: (presetId: string) => void;
  onPlay: () => void | Promise<void>;
  onStop: () => void;
  volume: number;
  onVolumeChange: (value: number) => void;
  formulaParam: number;
  onFormulaParamChange: (value: number) => void;
  tempoBpm: number;
  onTempoBpmChange: (value: number) => void;
  minFrequencyHz: number;
  onMinFrequencyChange: (value: number) => void;
  maxFrequencyHz: number;
  onMaxFrequencyChange: (value: number) => void;
  message?: string;
};

export default function Controls({
  presets,
  activePresetId,
  isPlaying,
  onPresetChange,
  onPlay,
  onStop,
  volume,
  onVolumeChange,
  formulaParam,
  onFormulaParamChange,
  tempoBpm,
  onTempoBpmChange,
  minFrequencyHz,
  onMinFrequencyChange,
  maxFrequencyHz,
  onMaxFrequencyChange,
  message,
}: ControlsProps) {
  return (
    <section className="relative z-20 space-y-3 rounded-2xl border border-white/10 bg-white/5 p-3 backdrop-blur-md">
      <div className="grid grid-cols-4 gap-2">
        {presets.map((preset) => {
          const isActive = preset.id === activePresetId;
          return (
            <button
              key={preset.id}
              type="button"
              onClick={() => onPresetChange(preset.id)}
              className={`rounded-full border px-3 py-1.5 text-xs font-medium tracking-wide transition ${
                isActive
                  ? "border-white/70 bg-white/20 text-white"
                  : "border-white/20 bg-black/20 text-white/70 hover:text-white"
              }`}
            >
              {preset.name}
            </button>
          );
        })}
      </div>

      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={() => {
            void onPlay();
          }}
          disabled={isPlaying}
          className="rounded-full border border-cyan-300/60 bg-cyan-300/10 px-4 py-1.5 text-sm text-cyan-100 transition enabled:hover:bg-cyan-300/20 disabled:cursor-not-allowed disabled:opacity-50"
        >
          Play
        </button>
        <button
          type="button"
          onClick={onStop}
          disabled={!isPlaying}
          className="rounded-full border border-pink-300/60 bg-pink-300/10 px-4 py-1.5 text-sm text-pink-100 transition enabled:hover:bg-pink-300/20 disabled:cursor-not-allowed disabled:opacity-50"
        >
          Stop
        </button>
        <label className="ml-auto flex items-center gap-2 text-xs text-white/70">
          Vol
          <input
            type="range"
            min={0}
            max={0.8}
            step={0.01}
            value={volume}
            onChange={(event) => onVolumeChange(Number(event.currentTarget.value))}
            className="w-24 accent-cyan-300"
            aria-label="Volume"
          />
        </label>
      </div>

      <div className="space-y-2 rounded-xl border border-white/10 bg-black/20 p-2.5">
        <label className="flex items-center justify-between text-xs text-white/75">
          <span>Formula Param</span>
          <span>{formulaParam.toFixed(2)}</span>
        </label>
        <input
          type="range"
          min={0.5}
          max={2}
          step={0.05}
          value={formulaParam}
          onChange={(event) => onFormulaParamChange(Number(event.currentTarget.value))}
          className="w-full accent-fuchsia-300"
          aria-label="Formula parameter"
        />
      </div>

      <div className="space-y-2 rounded-xl border border-white/10 bg-black/20 p-2.5">
        <label className="flex items-center justify-between text-xs text-white/75">
          <span>Tempo</span>
          <span>{Math.round(tempoBpm)} BPM</span>
        </label>
        <input
          type="range"
          min={60}
          max={180}
          step={1}
          value={tempoBpm}
          onChange={(event) => onTempoBpmChange(Number(event.currentTarget.value))}
          className="w-full accent-cyan-300"
          aria-label="Tempo BPM"
        />
      </div>

      <div className="grid grid-cols-2 gap-2">
        <div className="space-y-1.5 rounded-xl border border-white/10 bg-black/20 p-2">
          <label className="flex items-center justify-between text-xs text-white/75">
            <span>↓ Low Hz</span>
            <span>{Math.round(minFrequencyHz)}</span>
          </label>
          <input
            type="range"
            min={20}
            max={500}
            step={10}
            value={minFrequencyHz}
            onChange={(event) => onMinFrequencyChange(Number(event.currentTarget.value))}
            className="w-full accent-blue-400"
            aria-label="Minimum frequency"
          />
        </div>

        <div className="space-y-1.5 rounded-xl border border-white/10 bg-black/20 p-2">
          <label className="flex items-center justify-between text-xs text-white/75">
            <span>↑ High Hz</span>
            <span>{Math.round(maxFrequencyHz)}</span>
          </label>
          <input
            type="range"
            min={500}
            max={5000}
            step={50}
            value={maxFrequencyHz}
            onChange={(event) => onMaxFrequencyChange(Number(event.currentTarget.value))}
            className="w-full accent-amber-300"
            aria-label="Maximum frequency"
          />
        </div>
      </div>

      {message ? (
        <p className="text-xs text-amber-200/90">{message}</p>
      ) : null}
    </section>
  );
}
