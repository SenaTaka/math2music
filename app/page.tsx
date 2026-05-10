"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Controls from "@/components/Controls";
import FourierVisualizer from "@/components/FourierVisualizer";
import FormulaDisplay from "@/components/FormulaDisplay";
import { FormulaAudioEngine } from "@/lib/audio";
import { defaultPresetId, formulaPresets, buildPresetWithParameters, DEFAULT_FORMULA_PARAM, DEFAULT_TEMPO_BPM } from "@/lib/presets";

export default function Home() {
  const [activePresetId, setActivePresetId] = useState(defaultPresetId);
  const [isPlaying, setIsPlaying] = useState(false);
  const [volume, setVolume] = useState(0.18);
  const [message, setMessage] = useState("");
  const [formulaParam, setFormulaParam] = useState(DEFAULT_FORMULA_PARAM);
  const [tempoBpm, setTempoBpm] = useState(DEFAULT_TEMPO_BPM);
  const [minFrequencyHz, setMinFrequencyHz] = useState(60);
  const [maxFrequencyHz, setMaxFrequencyHz] = useState(2000);
  const audioEngineRef = useRef<FormulaAudioEngine | null>(null);

  const activePreset = useMemo(() => {
    const preset = formulaPresets.find((item) => item.id === activePresetId);
    return preset ?? formulaPresets[0];
  }, [activePresetId]);

  const paramPreset = useMemo(
    () => buildPresetWithParameters(activePreset, formulaParam, tempoBpm),
    [activePreset, formulaParam, tempoBpm],
  );

  const speedFactor = useMemo(() => tempoBpm / DEFAULT_TEMPO_BPM, [tempoBpm]);

  const getAudioEngine = () => {
    if (!audioEngineRef.current) {
      audioEngineRef.current = new FormulaAudioEngine(volume);
    }
    return audioEngineRef.current;
  };

  const handlePlay = async () => {
    try {
      const engine = getAudioEngine();
      engine.setVolume(volume);
      await engine.start(paramPreset);
      setIsPlaying(true);
      setMessage("");
    } catch (error) {
      const reason = error instanceof Error ? error.message : "Unknown audio error.";
      setMessage(`Audio start failed: ${reason}`);
      setIsPlaying(false);
    }
  };

  const handleStop = () => {
    audioEngineRef.current?.stop();
    setIsPlaying(false);
    setMessage("");
  };

  const handleVolumeChange = (nextVolume: number) => {
    setVolume(nextVolume);
    audioEngineRef.current?.setVolume(nextVolume);
  };

  useEffect(() => {
    if (!isPlaying || !audioEngineRef.current) {
      return;
    }
    void audioEngineRef.current.setPreset(paramPreset);
  }, [paramPreset, isPlaying]);

  useEffect(() => {
    audioEngineRef.current?.setFrequencyRange(minFrequencyHz, maxFrequencyHz);
  }, [minFrequencyHz, maxFrequencyHz]);

  useEffect(() => {
    return () => {
      if (!audioEngineRef.current) {
        return;
      }
      void audioEngineRef.current.dispose();
    };
  }, []);

  return (
    <main className="relative mx-auto flex min-h-screen w-full max-w-md flex-col px-4 pb-5 pt-6 sm:max-w-lg">


      <section className="flex flex-1 flex-col justify-center gap-4 py-4">
        <FourierVisualizer 
          preset={paramPreset} 
          speedFactor={speedFactor}
          onWaveAmplitudeChange={(amplitude) => {
            audioEngineRef.current?.setRealtimeFrequency(amplitude);
          }}
        />
        <FormulaDisplay formula={paramPreset.label} name={paramPreset.name} details={`Param: ${formulaParam.toFixed(2)} · ${Math.round(tempoBpm)} BPM`} />
      </section>

      <Controls
        presets={formulaPresets}
        activePresetId={activePreset.id}
        isPlaying={isPlaying}
        onPresetChange={(presetId) => {
          setActivePresetId(presetId);
          setMessage("");
        }}
        onPlay={handlePlay}
        onStop={handleStop}
        volume={volume}
        onVolumeChange={handleVolumeChange}
        formulaParam={formulaParam}
        onFormulaParamChange={(v) => setFormulaParam(v)}
        tempoBpm={tempoBpm}
        onTempoBpmChange={(v) => setTempoBpm(v)}
        minFrequencyHz={minFrequencyHz}
        onMinFrequencyChange={(v) => setMinFrequencyHz(v)}
        maxFrequencyHz={maxFrequencyHz}
        onMaxFrequencyChange={(v) => setMaxFrequencyHz(v)}
        message={message}
      />
    </main>
  );
}
