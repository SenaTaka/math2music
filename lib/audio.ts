import { FormulaPreset } from "@/lib/presets";

type WindowWithWebkitAudio = Window & {
  webkitAudioContext?: typeof AudioContext;
};

const clamp = (value: number, min: number, max: number) =>
  Math.min(Math.max(value, min), max);

export class FormulaAudioEngine {
  private context: AudioContext | null = null;
  private masterGain: GainNode | null = null;
  private oscillator: OscillatorNode | null = null;
  private filter: BiquadFilterNode | null = null;
  private volume = 0.12;

  constructor(initialVolume = 0.12) {
    this.volume = clamp(initialVolume, 0, 1);
  }

  private getAudioContext(): AudioContext {
    if (this.context) {
      return this.context;
    }

    if (typeof window === "undefined") {
      throw new Error("AudioContext is available only in the browser.");
    }

    const contextConstructor =
      window.AudioContext ?? (window as WindowWithWebkitAudio).webkitAudioContext;

    if (!contextConstructor) {
      throw new Error("This browser does not support Web Audio API.");
    }

    this.context = new contextConstructor();
    return this.context;
  }

  private async ensureRunningContext(): Promise<AudioContext> {
    const context = this.getAudioContext();
    if (context.state === "suspended") {
      await context.resume();
    }
    if (context.state !== "running") {
      throw new Error("Audio context is blocked. Tap Play again after user interaction.");
    }
    return context;
  }

  setVolume(nextVolume: number) {
    this.volume = clamp(nextVolume, 0, 1);
    if (!this.context || !this.masterGain) {
      return;
    }
    const now = this.context.currentTime;
    this.masterGain.gain.cancelScheduledValues(now);
    this.masterGain.gain.setValueAtTime(this.masterGain.gain.value, now);
    this.masterGain.gain.linearRampToValueAtTime(this.volume, now + 0.04);
  }

  async setPreset(preset: FormulaPreset) {
    if (this.isPlaying()) {
      await this.start(preset);
    }
  }

  isPlaying() {
    return this.oscillator !== null;
  }

  private createPeriodicWave(
    context: AudioContext,
    preset: FormulaPreset,
  ): PeriodicWave {
    const maxHarmonic = preset.terms.reduce((max, term) => {
      const harmonic = Math.max(1, Math.round(Math.abs(term.frequency)));
      return Math.max(max, harmonic);
    }, 1);

    const real = new Float32Array(maxHarmonic + 1);
    const imag = new Float32Array(maxHarmonic + 1);
    const totalAmplitude =
      preset.terms.reduce((sum, term) => sum + Math.abs(term.amplitude), 0) || 1;

    for (const term of preset.terms) {
      const harmonic = Math.max(1, Math.round(Math.abs(term.frequency)));
      const normalizedAmplitude = term.amplitude / totalAmplitude;
      const phase = term.phase ?? 0;

      real[harmonic] += normalizedAmplitude * Math.sin(phase);
      imag[harmonic] += normalizedAmplitude * Math.cos(phase);
    }

    return context.createPeriodicWave(real, imag, { disableNormalization: true });
  }

  async start(preset: FormulaPreset) {
    const context = await this.ensureRunningContext();
    const now = context.currentTime;

    if (this.isPlaying()) {
      this.stop();
    }

    this.masterGain = context.createGain();
    this.masterGain.gain.setValueAtTime(0, now);

    // Add lowpass filter for warmer, harp-like tone
    this.filter = context.createBiquadFilter();
    this.filter.type = "lowpass";
    this.filter.frequency.setValueAtTime(3200, now); // Gentle high-end rolloff
    this.filter.Q.setValueAtTime(1, now);
    this.filter.connect(this.masterGain);

    this.masterGain.connect(context.destination);

    // Main oscillator with periodic wave
    const oscillator = context.createOscillator();
    oscillator.frequency.setValueAtTime(preset.baseFrequency, now);
    oscillator.setPeriodicWave(this.createPeriodicWave(context, preset));
    oscillator.connect(this.filter!);
    oscillator.start(now);
    this.oscillator = oscillator;

    // Harp-like envelope: quick attack, long decay
    const attackTime = 0.05;
    const decayTime = 2.0; // Long sustain/decay for harp feel
    this.masterGain.gain.linearRampToValueAtTime(
      this.volume,
      now + attackTime
    );
    this.masterGain.gain.exponentialRampToValueAtTime(
      0.01,
      now + attackTime + decayTime
    );
  }

  stop() {
    if (!this.context || !this.masterGain) {
      return;
    }

    const context = this.context;
    const now = context.currentTime;
    const stopAt = now + 0.5; // Longer fade-out for harp sustain

    this.masterGain.gain.cancelScheduledValues(now);
    this.masterGain.gain.setValueAtTime(this.masterGain.gain.value, now);
    this.masterGain.gain.exponentialRampToValueAtTime(0.001, stopAt);

    const oscillatorToStop = this.oscillator;
    if (oscillatorToStop) {
      oscillatorToStop.stop(stopAt + 0.05);
      oscillatorToStop.onended = () => {
        oscillatorToStop.disconnect();
      };
    }

    const currentMasterGain = this.masterGain;
    const currentFilter = this.filter;
    window.setTimeout(() => {
      currentMasterGain.disconnect();
      currentFilter?.disconnect();
    }, 550);

    this.oscillator = null;
    this.masterGain = null;
    this.filter = null;
  }

  async dispose() {
    this.stop();
    if (!this.context) {
      return;
    }
    await this.context.close();
    this.context = null;
  }
}
