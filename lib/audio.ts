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
  private subOscillator: OscillatorNode | null = null;
  private filter: BiquadFilterNode | null = null;
  private shimmerFilter: BiquadFilterNode | null = null;
  private saturator: WaveShaperNode | null = null;
  private stereoPanner: StereoPannerNode | null = null;
  private tremoloLfo: OscillatorNode | null = null;
  private tremoloDepthGain: GainNode | null = null;
  private recordingDestination: MediaStreamAudioDestinationNode | null = null;
  private volume = 0.12;
  private baseFrequency = 440;
  private minFrequency = 60; // Low end (下側)
  private maxFrequency = 2000; // High end (上側)

  constructor(initialVolume = 0.12) {
    this.volume = clamp(initialVolume, 0, 1);
  }

  setFrequencyRange(minHz: number, maxHz: number) {
    this.minFrequency = clamp(minHz, 20, 5000);
    this.maxFrequency = clamp(maxHz, 20, 5000);
    if (this.minFrequency > this.maxFrequency) {
      [this.minFrequency, this.maxFrequency] = [this.maxFrequency, this.minFrequency];
    }
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

  getRecordingStream(): MediaStream | null {
    return this.recordingDestination?.stream ?? null;
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

  private createSaturatorCurve(amount = 280) {
    const sampleCount = 1024;
    const curve = new Float32Array(sampleCount);
    const k = amount;
    for (let index = 0; index < sampleCount; index += 1) {
      const x = (index * 2) / sampleCount - 1;
      curve[index] = ((1 + k) * x) / (1 + k * Math.abs(x));
    }
    return curve;
  }

  async start(preset: FormulaPreset) {
    const context = await this.ensureRunningContext();
    const now = context.currentTime;

    if (this.isPlaying()) {
      this.stop();
    }

    this.baseFrequency = preset.baseFrequency;
    this.masterGain = context.createGain();
    this.masterGain.gain.setValueAtTime(0, now);

    // Tone shaping chain for louder, more social-friendly texture
    this.filter = context.createBiquadFilter();
    this.filter.type = "lowpass";
    this.filter.frequency.setValueAtTime(2800, now);
    this.filter.Q.setValueAtTime(5.4, now);

    this.shimmerFilter = context.createBiquadFilter();
    this.shimmerFilter.type = "highshelf";
    this.shimmerFilter.frequency.setValueAtTime(1200, now);
    this.shimmerFilter.gain.setValueAtTime(5.5, now);

    this.saturator = context.createWaveShaper();
    this.saturator.curve = this.createSaturatorCurve();
    this.saturator.oversample = "2x";

    this.stereoPanner = context.createStereoPanner();
    this.stereoPanner.pan.setValueAtTime(0, now);

    this.filter.connect(this.shimmerFilter);
    this.shimmerFilter.connect(this.saturator);
    this.saturator.connect(this.stereoPanner);
    this.stereoPanner.connect(this.masterGain);

    if (!this.recordingDestination) {
      this.recordingDestination = context.createMediaStreamDestination();
    }

    this.masterGain.connect(context.destination);
    this.masterGain.connect(this.recordingDestination);

    // Main oscillator with periodic wave
    const oscillator = context.createOscillator();
    oscillator.frequency.setValueAtTime(preset.baseFrequency, now);
    oscillator.setPeriodicWave(this.createPeriodicWave(context, preset));
    oscillator.connect(this.filter);
    oscillator.start(now);
    this.oscillator = oscillator;

    this.subOscillator = context.createOscillator();
    this.subOscillator.type = "triangle";
    this.subOscillator.frequency.setValueAtTime(preset.baseFrequency * 0.5, now);
    const subGain = context.createGain();
    subGain.gain.setValueAtTime(0.18, now);
    this.subOscillator.connect(subGain);
    subGain.connect(this.filter);
    this.subOscillator.start(now);

    this.tremoloLfo = context.createOscillator();
    this.tremoloDepthGain = context.createGain();
    this.tremoloLfo.type = "sine";
    this.tremoloLfo.frequency.setValueAtTime(6.5, now);
    this.tremoloDepthGain.gain.setValueAtTime(0.08, now);
    this.tremoloLfo.connect(this.tremoloDepthGain);
    this.tremoloDepthGain.connect(this.masterGain.gain);
    this.tremoloLfo.start(now);

    // Punchy envelope suited for short clips
    const attackTime = 0.08;
    this.masterGain.gain.linearRampToValueAtTime(
      this.volume,
      now + attackTime
    );
    this.masterGain.gain.setValueAtTime(this.volume, now + attackTime);

    this.filter.frequency.setValueAtTime(2800, now);
  }

  // Update frequency based on waveform amplitude (-1 to 1)
  setRealtimeFrequency(normalizedAmplitude: number) {
    if (!this.oscillator || !this.context || !this.isPlaying()) {
      return;
    }
    // Map -1 to 1 into frequency range (REVERSED):
    // +1 (上側) = minFrequency (低周波)
    // 0 (中心) = baseFrequency
    // -1 (下側) = maxFrequency (高周波)
    const midFreq = this.baseFrequency;
    
    let freq: number;
    if (normalizedAmplitude >= 0) {
      // 0 to 1 maps to baseFreq to minFreq (上側→低周波)
      freq = midFreq + normalizedAmplitude * (this.minFrequency - midFreq);
    } else {
      // -1 to 0 maps to maxFreq to baseFreq (下側→高周波)
      freq = midFreq + normalizedAmplitude * (this.maxFrequency - midFreq);
    }
    
    const now = this.context.currentTime;
    this.oscillator.frequency.setTargetAtTime(freq, now, 0.018);
    this.subOscillator?.frequency.setTargetAtTime(Math.max(20, freq * 0.5), now, 0.02);

    const brightness = clamp(1400 + Math.abs(normalizedAmplitude) * 2200, 900, 4800);
    this.filter?.frequency.setTargetAtTime(brightness, now, 0.04);
    const pan = clamp(normalizedAmplitude * 0.9, -0.95, 0.95);
    this.stereoPanner?.pan.setTargetAtTime(pan, now, 0.07);
    this.shimmerFilter?.gain.setTargetAtTime(4 + Math.abs(normalizedAmplitude) * 3.5, now, 0.06);
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
    const subOscillatorToStop = this.subOscillator;
    const tremoloLfoToStop = this.tremoloLfo;
    if (oscillatorToStop) {
      oscillatorToStop.stop(stopAt + 0.05);
      oscillatorToStop.onended = () => {
        oscillatorToStop.disconnect();
      };
    }
    if (subOscillatorToStop) {
      subOscillatorToStop.stop(stopAt + 0.05);
      subOscillatorToStop.onended = () => {
        subOscillatorToStop.disconnect();
      };
    }
    if (tremoloLfoToStop) {
      tremoloLfoToStop.stop(stopAt + 0.05);
      tremoloLfoToStop.onended = () => {
        tremoloLfoToStop.disconnect();
      };
    }

    const currentMasterGain = this.masterGain;
    const currentFilter = this.filter;
    const currentShimmer = this.shimmerFilter;
    const currentSaturator = this.saturator;
    const currentPanner = this.stereoPanner;
    const currentTremoloDepthGain = this.tremoloDepthGain;
    window.setTimeout(() => {
      currentMasterGain.disconnect();
      currentFilter?.disconnect();
      currentShimmer?.disconnect();
      currentSaturator?.disconnect();
      currentPanner?.disconnect();
      currentTremoloDepthGain?.disconnect();
    }, 550);

    this.oscillator = null;
    this.subOscillator = null;
    this.tremoloLfo = null;
    this.tremoloDepthGain = null;
    this.masterGain = null;
    this.filter = null;
    this.shimmerFilter = null;
    this.saturator = null;
    this.stereoPanner = null;
  }

  async dispose() {
    this.stop();
    if (!this.context) {
      return;
    }
    await this.context.close();
    this.context = null;
    this.recordingDestination = null;
  }
}
