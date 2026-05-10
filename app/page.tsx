"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Controls from "@/components/Controls";
import FourierVisualizer from "@/components/FourierVisualizer";
import FormulaDisplay from "@/components/FormulaDisplay";
import { FormulaAudioEngine } from "@/lib/audio";
import {
  DEFAULT_FORMULA_PARAM,
  DEFAULT_TEMPO_BPM,
  buildPresetWithParameters,
  defaultPresetId,
  formulaPresets,
} from "@/lib/presets";

const LOOP_RECORDING_MS = 6_000;
const RECORDING_FPS = 30;
const RECORDING_MIME_TYPES = [
  "video/webm;codecs=vp9,opus",
  "video/webm;codecs=vp8,opus",
  "video/webm;codecs=opus",
  "video/webm",
];

const clamp = (value: number, min: number, max: number) =>
  Math.min(Math.max(value, min), max);

const parseNumberParam = (
  value: string | null,
  fallback: number,
  min: number,
  max: number,
) => {
  if (!value) {
    return fallback;
  }
  const parsed = Number(value);
  if (Number.isNaN(parsed)) {
    return fallback;
  }
  return clamp(parsed, min, max);
};

const getSupportedRecordingMimeType = () => {
  if (typeof MediaRecorder === "undefined") {
    return "";
  }
  for (const mimeType of RECORDING_MIME_TYPES) {
    if (MediaRecorder.isTypeSupported(mimeType)) {
      return mimeType;
    }
  }
  return "";
};

type InitialState = {
  activePresetId: string;
  formulaParam: number;
  tempoBpm: number;
  minFrequencyHz: number;
  maxFrequencyHz: number;
  volume: number;
};

const getInitialStateFromUrl = (): InitialState => {
  const fallbackState: InitialState = {
    activePresetId: defaultPresetId,
    formulaParam: DEFAULT_FORMULA_PARAM,
    tempoBpm: DEFAULT_TEMPO_BPM,
    minFrequencyHz: 60,
    maxFrequencyHz: 2000,
    volume: 0.18,
  };

  if (typeof window === "undefined") {
    return fallbackState;
  }

  const search = new URLSearchParams(window.location.search);
  const preset = search.get("preset");
  const nextPreset =
    preset && formulaPresets.some((item) => item.id === preset)
      ? preset
      : fallbackState.activePresetId;

  return {
    activePresetId: nextPreset,
    formulaParam: parseNumberParam(search.get("param"), DEFAULT_FORMULA_PARAM, 0.5, 2),
    tempoBpm: parseNumberParam(search.get("bpm"), DEFAULT_TEMPO_BPM, 60, 180),
    minFrequencyHz: parseNumberParam(search.get("low"), 60, 20, 500),
    maxFrequencyHz: parseNumberParam(search.get("high"), 2000, 500, 5000),
    volume: parseNumberParam(search.get("vol"), 0.18, 0, 0.8),
  };
};

export default function Home() {
  const initialState = useMemo(() => getInitialStateFromUrl(), []);
  const [activePresetId, setActivePresetId] = useState(
    initialState.activePresetId,
  );
  const [isPlaying, setIsPlaying] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [loopStartTimestampMs, setLoopStartTimestampMs] = useState<number | null>(null);
  const [volume, setVolume] = useState(initialState.volume);
  const [message, setMessage] = useState("");
  const [formulaParam, setFormulaParam] = useState(initialState.formulaParam);
  const [tempoBpm, setTempoBpm] = useState(initialState.tempoBpm);
  const [minFrequencyHz, setMinFrequencyHz] = useState(initialState.minFrequencyHz);
  const [maxFrequencyHz, setMaxFrequencyHz] = useState(initialState.maxFrequencyHz);
  const [recordingBlob, setRecordingBlob] = useState<Blob | null>(null);
  const audioEngineRef = useRef<FormulaAudioEngine | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const recordingChunksRef = useRef<BlobPart[]>([]);
  const recordingTimeoutRef = useRef<number | null>(null);

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

  const clearRecordingTimeout = () => {
    if (recordingTimeoutRef.current === null) {
      return;
    }
    window.clearTimeout(recordingTimeoutRef.current);
    recordingTimeoutRef.current = null;
  };

  const stopRecording = () => {
    const recorder = mediaRecorderRef.current;
    clearRecordingTimeout();
    setLoopStartTimestampMs(null);
    if (!recorder) {
      setIsRecording(false);
      return;
    }
    if (recorder.state !== "inactive") {
      recorder.stop();
    } else {
      setIsRecording(false);
    }
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
    stopRecording();
    audioEngineRef.current?.stop();
    setIsPlaying(false);
    setMessage("");
  };

  const handleVolumeChange = (nextVolume: number) => {
    setVolume(nextVolume);
    audioEngineRef.current?.setVolume(nextVolume);
  };

  const handleRecordToggle = async () => {
    if (typeof MediaRecorder === "undefined") {
      setMessage("Recording is not supported in this browser.");
      return;
    }

    if (isRecording) {
      stopRecording();
      setMessage("Recording stopped. Processing video...");
      return;
    }

    const canvas = canvasRef.current;
    if (!canvas) {
      setMessage("Recording failed: canvas is not available.");
      return;
    }

    const engine = getAudioEngine();
    if (!engine.isPlaying()) {
      await handlePlay();
    }
    if (!engine.isPlaying()) {
      setMessage("Start playback first, then try recording again.");
      return;
    }

    const canvasStream = canvas.captureStream(RECORDING_FPS);
    const mixedStream = new MediaStream();
    canvasStream.getVideoTracks().forEach((track) => mixedStream.addTrack(track));

    const recordingAudioStream = engine.getRecordingStream();
    recordingAudioStream?.getAudioTracks().forEach((track) => mixedStream.addTrack(track));

    const mimeType = getSupportedRecordingMimeType();
    const recorder = mimeType
      ? new MediaRecorder(mixedStream, { mimeType })
      : new MediaRecorder(mixedStream);
    mediaRecorderRef.current = recorder;
    recordingChunksRef.current = [];

    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) {
        recordingChunksRef.current.push(event.data);
      }
    };

    recorder.onerror = () => {
      setIsRecording(false);
      setLoopStartTimestampMs(null);
      setMessage("Recording failed. Please retry.");
    };

    recorder.onstop = () => {
      clearRecordingTimeout();
      setIsRecording(false);
      setLoopStartTimestampMs(null);
      mixedStream.getTracks().forEach((track) => track.stop());

      if (recordingChunksRef.current.length === 0) {
        setRecordingBlob(null);
        setMessage("No recording data was captured.");
        return;
      }

      const blobType = recorder.mimeType || "video/webm";
      const nextBlob = new Blob(recordingChunksRef.current, { type: blobType });
      setRecordingBlob(nextBlob);
      setMessage("Recording ready. Download or share it.");
    };

    recorder.start(250);
    setRecordingBlob(null);
    setIsRecording(true);
    setLoopStartTimestampMs(performance.now());
    setMessage("Loop recording started.");

    recordingTimeoutRef.current = window.setTimeout(() => {
      const currentRecorder = mediaRecorderRef.current;
      if (currentRecorder && currentRecorder.state === "recording") {
        currentRecorder.stop();
      }
    }, LOOP_RECORDING_MS);
  };

  const handleDownloadRecording = () => {
    if (!recordingBlob) {
      setMessage("No recording yet. Record first.");
      return;
    }

    const url = URL.createObjectURL(recordingBlob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `math2music-${Date.now()}.webm`;
    anchor.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  };

  const handleCopyLink = async () => {
    const shareUrl = window.location.href;
    try {
      await navigator.clipboard.writeText(shareUrl);
      setMessage("Link copied.");
    } catch {
      setMessage("Clipboard is blocked. Copy the URL from your browser bar.");
    }
  };

  const handleShare = async () => {
    const shareUrl = window.location.href;
    const shareText = "This equation makes music.";

    try {
      if (navigator.share) {
        if (recordingBlob) {
          const file = new File([recordingBlob], "math2music.webm", {
            type: recordingBlob.type || "video/webm",
          });
          if (navigator.canShare && navigator.canShare({ files: [file] })) {
            await navigator.share({
              title: "Math to Music",
              text: shareText,
              files: [file],
            });
            setMessage("Shared.");
            return;
          }
        }

        await navigator.share({
          title: "Math to Music",
          text: shareText,
          url: shareUrl,
        });
        setMessage("Shared.");
        return;
      }
    } catch (error) {
      if (error instanceof Error && error.name === "AbortError") {
        return;
      }
    }

    await handleCopyLink();
  };

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }
    const search = new URLSearchParams();
    search.set("preset", activePresetId);
    search.set("param", formulaParam.toFixed(2));
    search.set("bpm", String(Math.round(tempoBpm)));
    search.set("low", String(Math.round(minFrequencyHz)));
    search.set("high", String(Math.round(maxFrequencyHz)));
    search.set("vol", volume.toFixed(2));

    const nextQuery = search.toString();
    const nextUrl = nextQuery
      ? `${window.location.pathname}?${nextQuery}`
      : window.location.pathname;
    window.history.replaceState({}, "", nextUrl);
  }, [activePresetId, formulaParam, tempoBpm, minFrequencyHz, maxFrequencyHz, volume]);

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
      if (recordingTimeoutRef.current !== null) {
        window.clearTimeout(recordingTimeoutRef.current);
      }
      const recorder = mediaRecorderRef.current;
      if (recorder && recorder.state !== "inactive") {
        recorder.stop();
      }
      if (!audioEngineRef.current) {
        return;
      }
      void audioEngineRef.current.dispose();
    };
  }, []);

  return (
    <main className="relative mx-auto flex min-h-screen w-full max-w-md flex-col px-4 pb-5 pt-6 sm:max-w-lg">
      <header className="mb-3 rounded-2xl bg-white px-4 py-3 text-center text-black shadow-[0_10px_38px_rgba(255,255,255,0.2)]">
        <p className="text-lg font-semibold leading-snug sm:text-xl">
          This formula sounds illegal.
        </p>
        <p className="mt-1 text-xs font-medium tracking-wide text-black/70">
          Watch until the end, it loops perfectly.
        </p>
      </header>

      <section className="flex flex-1 flex-col justify-center gap-4 py-4">
        <FourierVisualizer
          ref={canvasRef}
          preset={paramPreset}
          speedFactor={speedFactor}
          isLoopMode={isRecording}
          loopDurationMs={LOOP_RECORDING_MS}
          loopStartTimestampMs={loopStartTimestampMs}
          effectBoost={isRecording ? 1.3 : 0.65}
          onWaveAmplitudeChange={(amplitude) => {
            audioEngineRef.current?.setRealtimeFrequency(amplitude);
          }}
        />
        <FormulaDisplay
          formula={paramPreset.label}
          name={paramPreset.name}
          details={`Param: ${formulaParam.toFixed(2)} · ${Math.round(tempoBpm)} BPM`}
        />
      </section>

      <Controls
        presets={formulaPresets}
        activePresetId={activePreset.id}
        isPlaying={isPlaying}
        isRecording={isRecording}
        hasRecording={recordingBlob !== null}
        loopDurationSec={LOOP_RECORDING_MS / 1000}
        onPresetChange={(presetId) => {
          setActivePresetId(presetId);
          setMessage("");
        }}
        onPlay={handlePlay}
        onStop={handleStop}
        onRecordToggle={handleRecordToggle}
        onDownloadRecording={handleDownloadRecording}
        onShareRecording={handleShare}
        onCopyLink={handleCopyLink}
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
