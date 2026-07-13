import { createFileRoute, Link } from "@tanstack/react-router";
import { useState, useEffect, useRef } from "react";
import {
  ChevronLeft,
  Pause,
  Mic,
  Minus,
  Plus,
  Sparkles,
} from "lucide-react";

export const Route = createFileRoute("/focus")({
  head: () => ({
    meta: [
      { title: "Focus Mode — Personal TrAIner" },
      { name: "description", content: "Entrenamiento activo con IA" },
    ],
  }),
  component: FocusMode,
});

function FocusMode() {
  const [heartRate, setHeartRate] = useState(148);
  const [restTime, setRestTime] = useState(105);
  const [isResting, setIsResting] = useState(true);
  const [weight, setWeight] = useState(24);
  const [reps, setReps] = useState(8);
  const [rpe, setRpe] = useState(8.5);

  useEffect(() => {
    const interval = setInterval(() => {
      setHeartRate((prev) => {
        const change = (Math.random() - 0.5) * 3;
        return Math.min(180, Math.max(100, Math.round(prev + change)));
      });
    }, 1200);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (!isResting) return;
    const interval = setInterval(() => {
      setRestTime((prev) => {
        if (prev <= 0) {
          setIsResting(false);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, [isResting]);

  return (
    <div className="min-h-screen bg-black">
      <div className="relative mx-auto flex min-h-screen w-full max-w-[430px] flex-col pb-28">
        {/* Ambient glow */}
        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          <div className="absolute -top-40 left-1/2 h-[500px] w-[500px] -translate-x-1/2 rounded-full bg-gradient-to-b from-cyan-500/10 via-violet-500/5 to-transparent blur-3xl" />
        </div>

        {/* Header */}
        <header className="relative z-20 px-6 pb-4 pt-14">
          <div className="flex items-center justify-between">
            <Link
              to="/"
              className="grid h-11 w-11 place-items-center rounded-full bg-neutral-900/80 text-white/90 backdrop-blur-md transition active:scale-95"
            >
              <ChevronLeft className="h-6 w-6" strokeWidth={2.5} />
            </Link>

            <div className="text-center">
              <p className="text-[11px] font-medium tracking-tight text-neutral-500">
                Personal Tr<span className="text-ai-gradient font-bold">AI</span>ner
              </p>
            </div>

            <button className="grid h-11 w-11 place-items-center rounded-full bg-neutral-900/80 text-white/90 backdrop-blur-md transition active:scale-95">
              <Pause className="h-6 w-6" strokeWidth={2.5} />
            </button>
          </div>

          {/* Exercise Title */}
          <div className="mt-6 text-center">
            <h1 className="text-[28px] font-bold tracking-tight text-white">
              Press Militar
            </h1>
            <p className="mt-1 text-[15px] font-medium text-neutral-500">
              Serie 3 de 4
            </p>
          </div>
        </header>

        {/* Main Content */}
        <main className="relative z-10 flex-1 space-y-4 px-6">
          {/* Heart Rate Card - The AI Brain */}
          <HeartRateCard heartRate={heartRate} />

          {/* Exercise Inputs */}
          <ExerciseInputs
            weight={weight}
            setWeight={setWeight}
            reps={reps}
            setReps={setReps}
            rpe={rpe}
            setRpe={setRpe}
          />

          {/* AI Rest Card */}
          <AIRestCard
            restTime={restTime}
            isResting={isResting}
            setIsResting={setIsResting}
          />
        </main>

        {/* Floating CTA */}
        <div className="fixed bottom-0 inset-x-0 z-30 px-6 pb-8 pt-4">
          <div className="mx-auto max-w-[430px]">
            <button className="inline-flex h-16 w-full items-center justify-center rounded-full bg-white py-4 text-lg font-semibold text-black shadow-[0_0_40px_rgba(255,255,255,0.15)] transition active:scale-[0.98]">
              Completar Serie
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

function HeartRateCard({ heartRate }: { heartRate: number }) {
  const getZone = () => {
    if (heartRate < 120) return { label: "Recuperación", color: "text-sky-400", bg: "bg-sky-400/20" };
    if (heartRate < 140) return { label: "Cardio", color: "text-emerald-400", bg: "bg-emerald-400/20" };
    if (heartRate < 160) return { label: "Alta Intensidad", color: "text-amber-400", bg: "bg-amber-400/20" };
    return { label: "Pico", color: "text-rose-400", bg: "bg-rose-400/20" };
  };

  const zone = getZone();

  return (
    <section className="relative overflow-hidden rounded-3xl bg-neutral-900/60 p-6 backdrop-blur-xl">
      {/* Glassmorphism border */}
      <div className="pointer-events-none absolute inset-0 rounded-3xl ring-1 ring-inset ring-white/[0.06]" />

      {/* Heart Rate Chart */}
      <div className="relative">
        <HeartRateChart heartRate={heartRate} />

        {/* BPM Display */}
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <div className="flex items-baseline gap-2">
            <span className="text-[52px] font-black leading-none tabular-nums tracking-tight text-white">
              {heartRate}
            </span>
            <span className="text-[18px] font-medium text-neutral-500">BPM</span>
          </div>

          {/* Zone Badge */}
          <div className={`mt-3 inline-flex items-center gap-2 rounded-full ${zone.bg} px-4 py-1.5`}>
            <span className={`h-2 w-2 rounded-full ${zone.color.replace('text-', 'bg-')} animate-pulse`} />
            <span className={`text-[13px] font-semibold ${zone.color}`}>
              {zone.label}
            </span>
          </div>
        </div>
      </div>
    </section>
  );
}

function HeartRateChart({ heartRate }: { heartRate: number }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [points, setPoints] = useState<number[]>(() =>
    Array.from({ length: 100 }, () => 0.45 + Math.random() * 0.25)
  );

  useEffect(() => {
    const interval = setInterval(() => {
      setPoints((prev) => {
        const baseLevel = heartRate / 200;
        const newPoint = baseLevel + (Math.random() - 0.5) * 0.12;
        return [...prev.slice(1), Math.max(0.15, Math.min(0.9, newPoint))];
      });
    }, 80);
    return () => clearInterval(interval);
  }, [heartRate]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    ctx.scale(dpr, dpr);

    ctx.clearRect(0, 0, rect.width, rect.height);

    // Draw glow layer first
    const glowGradient = ctx.createLinearGradient(0, 0, 0, rect.height);
    glowGradient.addColorStop(0, "rgba(34, 211, 238, 0.25)");
    glowGradient.addColorStop(0.5, "rgba(34, 211, 238, 0.08)");
    glowGradient.addColorStop(1, "rgba(34, 211, 238, 0)");

    ctx.beginPath();
    ctx.moveTo(0, rect.height);

    const midY = rect.height * 0.4;
    points.forEach((point, i) => {
      const x = (i / (points.length - 1)) * rect.width;
      const y = rect.height - point * rect.height * 0.6 - midY;

      if (i === 0) {
        ctx.lineTo(x, y);
      } else {
        const prevX = ((i - 1) / (points.length - 1)) * rect.width;
        const prevY = rect.height - points[i - 1] * rect.height * 0.6 - midY;
        const cpX = (prevX + x) / 2;
        ctx.bezierCurveTo(cpX, prevY, cpX, y, x, y);
      }
    });

    ctx.lineTo(rect.width, rect.height);
    ctx.closePath();
    ctx.fillStyle = glowGradient;
    ctx.fill();

    // Draw the main curve
    ctx.beginPath();
    points.forEach((point, i) => {
      const x = (i / (points.length - 1)) * rect.width;
      const y = rect.height - point * rect.height * 0.6 - midY;

      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        const prevX = ((i - 1) / (points.length - 1)) * rect.width;
        const prevY = rect.height - points[i - 1] * rect.height * 0.6 - midY;
        const cpX = (prevX + x) / 2;
        ctx.bezierCurveTo(cpX, prevY, cpX, y, x, y);
      }
    });

    // Cyan gradient stroke
    const lineGradient = ctx.createLinearGradient(0, 0, rect.width, 0);
    lineGradient.addColorStop(0, "#22d3ee");
    lineGradient.addColorStop(0.5, "#06b6d4");
    lineGradient.addColorStop(1, "#14b8a6");

    ctx.strokeStyle = lineGradient;
    ctx.lineWidth = 3;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.stroke();

    // Add glow effect
    ctx.shadowColor = "#22d3ee";
    ctx.shadowBlur = 20;
    ctx.stroke();
    ctx.shadowBlur = 0;
  }, [points]);

  return (
    <canvas
      ref={canvasRef}
      className="h-[200px] w-full"
    />
  );
}

function ExerciseInputs({
  weight,
  setWeight,
  reps,
  setReps,
  rpe,
  setRpe,
}: {
  weight: number;
  setWeight: (v: number) => void;
  reps: number;
  setReps: (v: number) => void;
  rpe: number;
  setRpe: (v: number) => void;
}) {
  return (
    <section className="grid grid-cols-3 gap-3">
      <InputTile
        label="Peso"
        value={weight}
        step={0.5}
        onChange={setWeight}
        unit="kg"
      />
      <InputTile
        label="Reps"
        value={reps}
        step={1}
        onChange={setReps}
        unit=""
      />
      <InputTile
        label="RPE"
        value={rpe}
        step={0.5}
        onChange={setRpe}
        unit=""
      />
    </section>
  );
}

function InputTile({
  label,
  value,
  step,
  onChange,
  unit,
}: {
  label: string;
  value: number;
  step: number;
  onChange: (v: number) => void;
  unit: string;
}) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-3xl bg-neutral-900/60 p-4 backdrop-blur-xl ring-1 ring-inset ring-white/[0.06]">
      <p className="text-[11px] font-semibold uppercase tracking-widest text-neutral-500">
        {label}
      </p>

      <div className="flex items-center gap-3">
        <button
          onClick={() => onChange(Math.max(0, value - step))}
          className="grid h-12 w-12 place-items-center rounded-full bg-neutral-800 text-white transition active:scale-90 active:bg-neutral-700"
        >
          <Minus className="h-5 w-5" strokeWidth={2.5} />
        </button>

        <div className="flex min-w-[56px] flex-col items-center">
          <span className="text-[28px] font-bold tabular-nums tracking-tight text-white">
            {value}
          </span>
          {unit && (
            <span className="text-[12px] font-medium text-neutral-500">{unit}</span>
          )}
        </div>

        <button
          onClick={() => onChange(value + step)}
          className="grid h-12 w-12 place-items-center rounded-full bg-neutral-800 text-white transition active:scale-90 active:bg-neutral-700"
        >
          <Plus className="h-5 w-5" strokeWidth={2.5} />
        </button>
      </div>
    </div>
  );
}

function AIRestCard({
  restTime,
  isResting,
  setIsResting,
}: {
  restTime: number;
  isResting: boolean;
  setIsResting: (v: boolean) => void;
}) {
  const minutes = Math.floor(restTime / 60);
  const seconds = restTime % 60;
  const maxTime = 105;
  const progress = restTime / maxTime;

  return (
    <section className="relative overflow-hidden rounded-3xl bg-neutral-900/60 p-5 backdrop-blur-xl ring-1 ring-inset ring-indigo-500/20">
      {/* Ambient shimmer */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden rounded-3xl">
        <div className="absolute -left-20 -top-20 h-40 w-40 rounded-full bg-indigo-500/10 blur-2xl" />
      </div>

      <div className="relative flex items-center justify-between gap-4">
        {/* Timer */}
        <div className="flex items-center gap-4">
          <div className="relative h-[68px] w-[68px] shrink-0">
            <svg className="h-full w-full -rotate-90" viewBox="0 0 68 68">
              <circle
                cx="34"
                cy="34"
                r="30"
                stroke="white"
                strokeOpacity="0.08"
                strokeWidth="4"
                fill="none"
              />
              <circle
                cx="34"
                cy="34"
                r="30"
                stroke="url(#restGradient)"
                strokeWidth="4"
                strokeLinecap="round"
                fill="none"
                strokeDasharray={2 * Math.PI * 30}
                strokeDashoffset={2 * Math.PI * 30 * (1 - progress)}
                className="transition-all duration-500"
              />
              <defs>
                <linearGradient id="restGradient" x1="0" y1="0" x2="68" y2="68">
                  <stop offset="0%" stopColor="#818cf8" />
                  <stop offset="100%" stopColor="#c084fc" />
                </linearGradient>
              </defs>
            </svg>
            <div className="absolute inset-0 grid place-items-center">
              <Sparkles className="h-6 w-6 text-indigo-400" strokeWidth={2} />
            </div>
          </div>

          <div className="min-w-0">
            <p className="text-[20px] font-bold tabular-nums text-white">
              {minutes}:{seconds.toString().padStart(2, "0")}
            </p>
            <p className="text-[13px] text-neutral-400">Descanso óptimo</p>
          </div>
        </div>

        {/* AI Voice FAB */}
        <button className="group relative grid h-14 w-14 place-items-center rounded-full transition active:scale-95">
          {/* Animated gradient background */}
          <div className="absolute inset-0 rounded-full bg-gradient-to-tr from-violet-600 via-indigo-500 to-cyan-500 opacity-100 transition group-active:opacity-80" />
          {/* Glow ring */}
          <div className="pointer-events-none absolute -inset-1 rounded-full bg-gradient-to-tr from-violet-600/50 to-cyan-500/50 opacity-60 blur-lg transition group-active:opacity-80" />

          <Mic className="relative z-10 h-6 w-6 text-white" strokeWidth={2.5} />

          {/* Audio wave animation */}
          <div className="absolute inset-0 overflow-hidden rounded-full">
            <div className="absolute left-4 top-1/2 flex -translate-y-1/2 items-center gap-[2px]">
              {[0.35, 0.7, 0.5, 0.85, 0.4, 0.65, 0.55, 0.75].map((h, i) => (
                <span
                  key={i}
                  className="w-[2px] rounded-full bg-white/90 animate-wave"
                  style={{
                    height: `${h * 14}px`,
                    animationDelay: `${i * 0.1}s`,
                  }}
                />
              ))}
            </div>
          </div>
        </button>
      </div>

      <p className="relative mt-3 text-[13px] text-neutral-500">
        Basado en tu recuperación cardíaca actual
      </p>
    </section>
  );
}
