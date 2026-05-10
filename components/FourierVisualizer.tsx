"use client";

import { forwardRef, useEffect, useRef } from "react";
import { FormulaPreset } from "@/lib/presets";

type FourierVisualizerProps = {
  preset: FormulaPreset;
  speedFactor: number;
  isLoopMode?: boolean;
  loopDurationMs?: number;
  loopStartTimestampMs?: number | null;
  effectBoost?: number;
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
const TAU = Math.PI * 2;

const clamp = (value: number, min: number, max: number) =>
  Math.min(Math.max(value, min), max);

type EpicyclePoint = {
  x: number;
  y: number;
  radius: number;
  color: string;
};

const normalizeUnit = (value: number) => {
  const wrapped = value % 1;
  return wrapped < 0 ? wrapped + 1 : wrapped;
};

const buildEpicycle = (
  terms: FormulaPreset["terms"],
  originX: number,
  originY: number,
  orbitSpan: number,
  phaseTime: number,
) => {
  const totalAmplitude =
    terms.reduce((sum, term) => sum + Math.abs(term.amplitude), 0) || 1;
  const points: EpicyclePoint[] = [];

  let x = originX;
  let y = originY;
  terms.forEach((term, index) => {
    const radius = (Math.abs(term.amplitude) / totalAmplitude) * orbitSpan;
    const angle =
      phaseTime * term.frequency +
      (term.phase ?? 0) +
      (term.amplitude < 0 ? Math.PI : 0);
    const nextX = x + radius * Math.cos(angle);
    const nextY = y + radius * Math.sin(angle);
    points.push({
      x,
      y,
      radius,
      color: NEON_COLORS[index % NEON_COLORS.length],
    });
    x = nextX;
    y = nextY;
  });

  return { points, endX: x, endY: y };
};

const FourierVisualizer = forwardRef<HTMLCanvasElement, FourierVisualizerProps>(
  function FourierVisualizer(
    {
      preset,
      speedFactor,
      isLoopMode = false,
      loopDurationMs = 6000,
      loopStartTimestampMs = null,
      effectBoost = 0.55,
      onWaveAmplitudeChange,
    }: FourierVisualizerProps,
    forwardedRef,
  ) {
    const containerRef = useRef<HTMLDivElement | null>(null);
    const canvasRef = useRef<HTMLCanvasElement | null>(null);
    const animationFrameRef = useRef<number | null>(null);
    const presetRef = useRef(preset);
    const speedFactorRef = useRef(speedFactor);
    const isLoopModeRef = useRef(isLoopMode);
    const loopDurationMsRef = useRef(loopDurationMs);
    const loopStartTimestampMsRef = useRef(loopStartTimestampMs);
    const effectBoostRef = useRef(effectBoost);
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
      isLoopModeRef.current = isLoopMode;
    }, [isLoopMode]);

    useEffect(() => {
      loopDurationMsRef.current = loopDurationMs;
    }, [loopDurationMs]);

    useEffect(() => {
      loopStartTimestampMsRef.current = loopStartTimestampMs;
    }, [loopStartTimestampMs]);

    useEffect(() => {
      effectBoostRef.current = effectBoost;
    }, [effectBoost]);

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
        const orbitSpan = Math.min(width * 0.28, height * 0.45);
        const boost = clamp(Math.abs(effectBoostRef.current), 0, 2);

        const loopOn =
          isLoopModeRef.current &&
          loopDurationMsRef.current > 0 &&
          loopStartTimestampMsRef.current !== null;
        const loopProgress = loopOn
          ? normalizeUnit(
              (timestamp - (loopStartTimestampMsRef.current ?? 0)) /
                (loopDurationMsRef.current || 1),
            )
          : 0;
        const phaseTime = loopOn
          ? loopProgress * TAU
          : timestamp * 0.0016 * speedFactorRef.current;

        const epicycle = buildEpicycle(
          terms,
          originX,
          originY,
          orbitSpan,
          phaseTime,
        );
        const x = epicycle.endX;
        const y = epicycle.endY;

        const bg = context.createRadialGradient(
          width * 0.34,
          height * 0.42,
          12,
          width * 0.5,
          height * 0.5,
          width * 0.9,
        );
        const pulse = 0.16 + Math.sin(phaseTime * 0.7) * 0.07 + boost * 0.04;
        bg.addColorStop(0, `rgba(99, 230, 255, ${pulse.toFixed(3)})`);
        bg.addColorStop(0.4, "rgba(167, 139, 250, 0.12)");
        bg.addColorStop(1, "rgba(0, 0, 0, 0.92)");

        context.clearRect(0, 0, width, height);
        context.fillStyle = bg;
        context.fillRect(0, 0, width, height);

        epicycle.points.forEach((point, index) => {
          const next = index + 1 < epicycle.points.length ? epicycle.points[index + 1] : null;
          const currentX = point.x;
          const currentY = point.y;
          const nextX = next ? next.x : x;
          const nextY = next ? next.y : y;
          const glowBoost = 16 + boost * 10;

          context.strokeStyle = point.color;
          context.lineWidth = 1.15 + index * 0.08;
          context.shadowColor = point.color;
          context.shadowBlur = glowBoost;
          context.beginPath();
          context.arc(currentX, currentY, point.radius, 0, TAU);
          context.stroke();

          context.lineWidth = 1.9;
          context.beginPath();
          context.moveTo(currentX, currentY);
          context.lineTo(nextX, nextY);
          context.stroke();
        });

        context.fillStyle = "#ffffff";
        context.shadowColor = "#ffffff";
        context.shadowBlur = 24 + boost * 10;
        context.beginPath();
        context.arc(x, y, 3.2 + boost * 0.7, 0, TAU);
        context.fill();

        const maxPoints = Math.max(
          36,
          Math.floor((width - waveStartX - rightPadding) / WAVE_STEP),
        );

        const wavePoints: number[] = [];
        if (loopOn) {
          for (let index = 0; index < maxPoints; index += 1) {
            const sampleProgress = normalizeUnit(loopProgress - index / maxPoints);
            const sampleEpicycle = buildEpicycle(
              terms,
              originX,
              originY,
              orbitSpan,
              sampleProgress * TAU,
            );
            wavePoints.push(sampleEpicycle.endY);
          }
        } else {
          const wave = waveRef.current;
          wave.unshift(y);
          if (wave.length > maxPoints) {
            wave.length = maxPoints;
          }
          wavePoints.push(...wave);
        }

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
        context.lineTo(waveStartX, wavePoints[0] ?? y);
        context.stroke();
        context.setLineDash([]);

        context.strokeStyle = presetRef.current.color;
        context.shadowColor = presetRef.current.color;
        context.shadowBlur = 28 + boost * 14;
        context.lineWidth = 2.4 + boost * 0.5;
        context.beginPath();
        wavePoints.forEach((pointY, index) => {
          const pointX = waveStartX + index * WAVE_STEP;
          if (index === 0) {
            context.moveTo(pointX, pointY);
          } else {
            context.lineTo(pointX, pointY);
          }
        });
        context.stroke();

        context.globalAlpha = 0.35;
        context.lineWidth = 5.4 + boost;
        context.stroke();
        context.globalAlpha = 1;

        if (wavePoints.length > 0) {
          context.strokeStyle = "rgba(255, 255, 255, 0.35)";
          context.shadowColor = "rgba(255, 255, 255, 0.35)";
          context.shadowBlur = 16;
          context.lineWidth = 1.1;
          context.beginPath();
          wavePoints.forEach((pointY, index) => {
            const pointX = waveStartX + index * WAVE_STEP;
            const ghostY = originY + (originY - pointY) * 0.32;
            if (index === 0) {
              context.moveTo(pointX, ghostY);
            } else {
              context.lineTo(pointX, ghostY);
            }
          });
          context.stroke();
        }

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
