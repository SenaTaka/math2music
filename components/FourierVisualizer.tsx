"use client";

import { forwardRef, useEffect, useRef } from "react";
import { FormulaPreset } from "@/lib/presets";

type FourierVisualizerProps = {
  preset: FormulaPreset;
  speedFactor: number;
  onWaveAmplitudeChange?: (amplitude: number) => void;
};

const NEON_COLORS = [
  "#63e6ff",
  "#a78bfa",
  "#ff7ac6",
  "#ffe066",
  "#2ceaa3",
  "#f87171",
  "#60a5fa",
];

const WAVE_STEP = 2.25;

const FourierVisualizer = forwardRef<HTMLCanvasElement, FourierVisualizerProps>(
  function FourierVisualizer(
    { preset, speedFactor, onWaveAmplitudeChange }: FourierVisualizerProps,
    forwardedRef,
  ) {
    const containerRef = useRef<HTMLDivElement | null>(null);
    const canvasRef = useRef<HTMLCanvasElement | null>(null);
    const animationFrameRef = useRef<number | null>(null);
    const presetRef = useRef(preset);
    const speedFactorRef = useRef(speedFactor);
    const onWaveAmplitudeChangeRef = useRef(onWaveAmplitudeChange);
    const waveRef = useRef<number[]>([]);
    const geometryRef = useRef({
      width: 0,
      height: 0,
      originX: 0,
      originY: 0,
      waveStartX: 0,
      rightPadding: 20,
    });

    useEffect(() => {
      presetRef.current = preset;
      waveRef.current = [];
    }, [preset]);

    useEffect(() => {
      speedFactorRef.current = speedFactor;
    }, [speedFactor]);

    useEffect(() => {
      onWaveAmplitudeChangeRef.current = onWaveAmplitudeChange;
    }, [onWaveAmplitudeChange]);

    useEffect(() => {
      const canvas = canvasRef.current;
      const container = containerRef.current;

      if (!canvas || !container) {
        return;
      }

      const context = canvas.getContext("2d");
      if (!context) {
        return;
      }

    const resize = () => {
      const rect = container.getBoundingClientRect();
      const width = Math.max(1, rect.width);
      const height = Math.max(1, rect.height);
      const dpr = Math.min(window.devicePixelRatio || 1, 2);

      canvas.width = Math.floor(width * dpr);
      canvas.height = Math.floor(height * dpr);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      context.setTransform(dpr, 0, 0, dpr, 0, 0);

      geometryRef.current = {
        width,
        height,
        originX: width * 0.2,
        originY: height * 0.5,
        waveStartX: width * 0.56,
        rightPadding: 18,
      };

      waveRef.current = [];
    };

    const draw = (timestamp: number) => {
      const { width, height, originX, originY, waveStartX, rightPadding } = geometryRef.current;
      const terms = presetRef.current.terms;
      const totalAmplitude =
        terms.reduce((sum, term) => sum + Math.abs(term.amplitude), 0) || 1;
      const orbitSpan = Math.min(width * 0.26, height * 0.42);

      context.clearRect(0, 0, width, height);
      context.fillStyle = "rgba(0, 0, 0, 0.25)";
      context.fillRect(0, 0, width, height);

      let x = originX;
      let y = originY;
      const time = timestamp * 0.0016 * speedFactorRef.current;

      terms.forEach((term, index) => {
        const radius = (Math.abs(term.amplitude) / totalAmplitude) * orbitSpan;
        const angle =
          time * term.frequency +
          (term.phase ?? 0) +
          (term.amplitude < 0 ? Math.PI : 0);
        const nextX = x + radius * Math.cos(angle);
        const nextY = y + radius * Math.sin(angle);
        const color = NEON_COLORS[index % NEON_COLORS.length];

        context.strokeStyle = color;
        context.lineWidth = 1;
        context.shadowColor = color;
        context.shadowBlur = 16;
        context.beginPath();
        context.arc(x, y, radius, 0, Math.PI * 2);
        context.stroke();

        context.lineWidth = 1.8;
        context.beginPath();
        context.moveTo(x, y);
        context.lineTo(nextX, nextY);
        context.stroke();

        context.fillStyle = color;
        context.beginPath();
        context.arc(nextX, nextY, 2.4, 0, Math.PI * 2);
        context.fill();

        x = nextX;
        y = nextY;
      });

      const wave = waveRef.current;
      const maxPoints = Math.max(
        36,
        Math.floor((width - waveStartX - rightPadding) / WAVE_STEP),
      );
      wave.unshift(y);
      if (wave.length > maxPoints) {
        wave.length = maxPoints;
      }

      // Normalize wave amplitude to -1 to 1 range relative to center
      const normalizedAmplitude = (y - originY) / (height * 0.4);
      if (onWaveAmplitudeChangeRef.current) {
        onWaveAmplitudeChangeRef.current(normalizedAmplitude);
      }

      context.shadowBlur = 0;
      context.strokeStyle = "rgba(255, 255, 255, 0.35)";
      context.lineWidth = 1;
      context.beginPath();
      context.moveTo(waveStartX, originY);
      context.lineTo(width - rightPadding, originY);
      context.stroke();

      context.beginPath();
      context.moveTo(waveStartX, originY - height * 0.4);
      context.lineTo(waveStartX, originY + height * 0.4);
      context.stroke();

      context.setLineDash([4, 6]);
      context.strokeStyle = "rgba(255, 255, 255, 0.45)";
      context.beginPath();
      context.moveTo(x, y);
      context.lineTo(waveStartX, wave[0] ?? y);
      context.stroke();
      context.setLineDash([]);

      context.strokeStyle = presetRef.current.color;
      context.shadowColor = presetRef.current.color;
      context.shadowBlur = 24;
      context.lineWidth = 2.2;
      context.beginPath();
      wave.forEach((pointY, index) => {
        const pointX = waveStartX + index * WAVE_STEP;
        if (index === 0) {
          context.moveTo(pointX, pointY);
        } else {
          context.lineTo(pointX, pointY);
        }
      });
      context.stroke();

      context.globalAlpha = 0.28;
      context.lineWidth = 5;
      context.stroke();
      context.globalAlpha = 1;

      animationFrameRef.current = window.requestAnimationFrame(draw);
    };

      resize();
      const resizeObserver = new ResizeObserver(resize);
      resizeObserver.observe(container);

      animationFrameRef.current = window.requestAnimationFrame(draw);

      return () => {
        resizeObserver.disconnect();
        if (animationFrameRef.current !== null) {
          window.cancelAnimationFrame(animationFrameRef.current);
        }
      };
    }, []);

    return (
      <div
        ref={containerRef}
        className="pointer-events-none relative z-0 h-[44vh] min-h-[340px] w-full overflow-hidden rounded-3xl border border-white/10 bg-black/35"
      >
        <canvas
          ref={(node) => {
            canvasRef.current = node;
            if (typeof forwardedRef === "function") {
              forwardedRef(node);
              return;
            }
            if (forwardedRef) {
              forwardedRef.current = node;
            }
          }}
          className="h-full w-full pointer-events-none"
        />
      </div>
    );
  },
);

export default FourierVisualizer;
