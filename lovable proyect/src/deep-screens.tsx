import { useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowLeft, Sparkles, X, ArrowUp,
  ChevronLeft, Pause, Mic, Minus, Plus,
  Clock, Flame, Heart, Activity, TrendingUp,
  Moon, Watch, Smartphone, Circle as Ring, RefreshCw,
  FileText, Image as ImageIcon, Keyboard, Upload, ChevronRight,
  Dumbbell, Bike, HeartPulse, Wind, Trophy, Pencil, Trash2, Zap,
  Search, Copy, GripVertical, Check,
  AlertTriangle,
} from 'lucide-react';
import { useNav } from './nav';

/* ============================== SHARED ============================== */

function TopBar({ title, onBack }: { title: string; onBack: () => void }) {
  return (
    <div className="flex items-center gap-3 px-5 pt-6 pb-2">
      <button
        onClick={onBack}
        className="grid h-10 w-10 place-items-center rounded-full bg-surface-1 text-foreground transition active:scale-95"
        aria-label="Volver"
      >
        <ArrowLeft className="h-4 w-4" />
      </button>
      <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
        {title}
      </span>
    </div>
  );
}

/* ============================== CHAT ============================== */

const SUGGESTIONS = [
  '¿Cómo voy de recuperación hoy?',
  'Plan de comida alta en proteína',
  'Rutina rápida de 20 min',
  'Interpreta mi última FC media',
];

export function ChatScreen() {
  const { goBack } = useNav();
  const [input, setInput] = useState('');
  const [messages, setMessages] = useState<{ id: number; role: 'user' | 'assistant'; text: string }[]>([]);
  const [isTyping, setIsTyping] = useState(false);
  const taRef = useRef<HTMLTextAreaElement>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    taRef.current?.focus();
  }, []);
  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isTyping]);

  const submit = (text: string) => {
    const t = text.trim();
    if (!t || isTyping) return;
    const userMsg = { id: Date.now(), role: 'user' as const, text: t };
    setMessages((prev) => [...prev, userMsg]);
    setInput('');
    setIsTyping(true);
    setTimeout(() => {
      setMessages((prev) => [...prev, {
        id: Date.now() + 1,
        role: 'assistant',
        text: 'Basándome en tus métricas recientes, tu recuperación está en un 78%. Te recomiendo mantener la intensidad moderada hoy y priorizar 8 horas de sueño. ¿Quieres que ajuste tu rutina?',
      }]);
      setIsTyping(false);
    }, 1500);
  };

  return (
    <div className="min-h-screen w-full bg-surface-2">
      <div className="relative mx-auto flex min-h-screen w-full max-w-[440px] flex-col bg-background">
        <header className="sticky top-0 z-20 glass">
          <div className="flex items-center gap-3 px-4 pb-3 pt-5">
            <button
              onClick={goBack}
              className="flex h-9 w-9 items-center justify-center rounded-full bg-surface-2 text-foreground/80 ring-1 ring-border"
              aria-label="Volver"
            >
              <ArrowLeft className="h-4 w-4" />
            </button>
            <div className="flex min-w-0 flex-1 items-center gap-2">
              <div className="grid h-8 w-8 place-items-center rounded-lg bg-ai-gradient text-white">
                <Sparkles className="h-4 w-4" />
              </div>
              <div className="min-w-0">
                <p className="truncate text-[15px] font-semibold leading-tight">AI Coach</p>
                <p className="flex items-center gap-1 text-[11px] text-muted-foreground">
                  <span className="inline-block h-1.5 w-1.5 rounded-full bg-emerald-500" />
                  En línea · contexto de tus datos
                </p>
              </div>
            </div>
          </div>
        </header>

        <main className="flex-1 px-4 pb-40 pt-4">
          {messages.length === 0 ? (
            <div className="flex flex-col items-center pt-10 text-center">
              <div className="bg-ai-gradient mb-4 flex h-16 w-16 items-center justify-center rounded-2xl shadow-soft">
                <Sparkles className="h-7 w-7 text-white" />
              </div>
              <h1 className="text-[22px] font-semibold tracking-tight">¿En qué te ayudo hoy?</h1>
              <p className="mt-1 max-w-[300px] text-sm text-muted-foreground">
                Tu coach personal con acceso a tus métricas, entrenamientos y nutrición.
              </p>
              <div className="mt-6 grid w-full grid-cols-1 gap-2">
                {SUGGESTIONS.map((s) => (
                  <button
                    key={s}
                    onClick={() => submit(s)}
                    className="rounded-2xl bg-surface-2 px-4 py-3 text-left text-sm text-foreground/90 ring-1 ring-border transition-colors hover:bg-surface-1"
                  >
                    {s}
                  </button>
                ))}
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              {messages.map((m) => (
                <div key={m.id} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                  <div
                    className={
                      m.role === 'user'
                        ? 'rounded-[22px] rounded-br-md bg-primary px-4 py-2.5 text-[15px] leading-relaxed text-primary-foreground shadow-soft max-w-[82%]'
                        : 'max-w-[88%] whitespace-pre-wrap text-[15px] leading-relaxed text-foreground'
                    }
                  >
                    {m.text}
                  </div>
                </div>
              ))}
              {isTyping && (
                <div className="flex items-center gap-1.5 px-1 text-muted-foreground">
                  <span className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground/60 [animation-delay:-0.2s]" />
                  <span className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground/60 [animation-delay:-0.1s]" />
                  <span className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground/60" />
                </div>
              )}
            </div>
          )}
          <div ref={endRef} />
        </main>

        <div className="fixed bottom-0 left-1/2 z-30 w-full max-w-[440px] -translate-x-1/2 px-4 pb-5 pt-3">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              submit(input);
            }}
            className="glass rounded-[24px] p-2 pl-2 shadow-card ring-1 ring-border"
          >
            <div className="flex items-end gap-1.5">
              <textarea
                ref={taRef}
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    submit(input);
                  }
                }}
                placeholder="Pregunta a tu AI Coach…"
                rows={1}
                className="max-h-32 flex-1 resize-none bg-transparent py-2 pl-2 text-[15px] leading-snug outline-none placeholder:text-muted-foreground"
              />
              <button
                type="submit"
                disabled={!input.trim() || isTyping}
                className="bg-ai-gradient flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-white shadow-soft transition-opacity disabled:opacity-40"
                aria-label="Enviar"
              >
                <ArrowUp className="h-4 w-4" />
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}

/* ============================== FOCUS MODE ============================== */

export function FocusScreen() {
  const { goBack } = useNav();
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
        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          <div className="absolute -top-40 left-1/2 h-[500px] w-[500px] -translate-x-1/2 rounded-full bg-gradient-to-b from-cyan-500/10 via-violet-500/5 to-transparent blur-3xl" />
        </div>

        <header className="relative z-20 px-6 pb-4 pt-14">
          <div className="flex items-center justify-between">
            <button
              onClick={goBack}
              className="grid h-11 w-11 place-items-center rounded-full bg-neutral-900/80 text-white/90 backdrop-blur-md transition active:scale-95"
            >
              <ChevronLeft className="h-6 w-6" strokeWidth={2.5} />
            </button>
            <div className="text-center">
              <p className="text-[11px] font-medium tracking-tight text-neutral-500">
                Personal Tr<span className="text-ai-gradient font-bold">AI</span>ner
              </p>
            </div>
            <button className="grid h-11 w-11 place-items-center rounded-full bg-neutral-900/80 text-white/90 backdrop-blur-md transition active:scale-95">
              <Pause className="h-6 w-6" strokeWidth={2.5} />
            </button>
          </div>

          <div className="mt-6 text-center">
            <h1 className="text-[28px] font-bold tracking-tight text-white">
              Press Militar
            </h1>
            <p className="mt-1 text-[15px] font-medium text-neutral-500">
              Serie 3 de 4
            </p>
          </div>
        </header>

        <main className="relative z-10 flex-1 space-y-4 px-6">
          <HeartRateCard heartRate={heartRate} />
          <ExerciseInputs
            weight={weight} setWeight={setWeight}
            reps={reps} setReps={setReps}
            rpe={rpe} setRpe={setRpe}
          />
          <AIRestCard restTime={restTime} isResting={isResting} setIsResting={setIsResting} />
        </main>

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
    if (heartRate < 120) return { label: 'Recuperación', color: 'text-sky-400', bg: 'bg-sky-400/20' };
    if (heartRate < 140) return { label: 'Cardio', color: 'text-emerald-400', bg: 'bg-emerald-400/20' };
    if (heartRate < 160) return { label: 'Alta Intensidad', color: 'text-amber-400', bg: 'bg-amber-400/20' };
    return { label: 'Pico', color: 'text-rose-400', bg: 'bg-rose-400/20' };
  };
  const zone = getZone();

  return (
    <section className="relative overflow-hidden rounded-3xl bg-neutral-900/60 p-6 backdrop-blur-xl">
      <div className="pointer-events-none absolute inset-0 rounded-3xl ring-1 ring-inset ring-white/[0.06]" />
      <div className="relative">
        <HeartRateChart heartRate={heartRate} />
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <div className="flex items-baseline gap-2">
            <span className="text-[52px] font-black leading-none tabular-nums tracking-tight text-white">
              {heartRate}
            </span>
            <span className="text-[18px] font-medium text-neutral-500">BPM</span>
          </div>
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
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    ctx.scale(dpr, dpr);

    ctx.clearRect(0, 0, rect.width, rect.height);

    const glowGradient = ctx.createLinearGradient(0, 0, 0, rect.height);
    glowGradient.addColorStop(0, 'rgba(34, 211, 238, 0.25)');
    glowGradient.addColorStop(0.5, 'rgba(34, 211, 238, 0.08)');
    glowGradient.addColorStop(1, 'rgba(34, 211, 238, 0)');

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

    const lineGradient = ctx.createLinearGradient(0, 0, rect.width, 0);
    lineGradient.addColorStop(0, '#22d3ee');
    lineGradient.addColorStop(0.5, '#06b6d4');
    lineGradient.addColorStop(1, '#14b8a6');

    ctx.strokeStyle = lineGradient;
    ctx.lineWidth = 3;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.stroke();

    ctx.shadowColor = '#22d3ee';
    ctx.shadowBlur = 20;
    ctx.stroke();
    ctx.shadowBlur = 0;
  }, [points]);

  return <canvas ref={canvasRef} className="h-[200px] w-full" />;
}

function ExerciseInputs({
  weight, setWeight, reps, setReps, rpe, setRpe,
}: {
  weight: number; setWeight: (v: number) => void;
  reps: number; setReps: (v: number) => void;
  rpe: number; setRpe: (v: number) => void;
}) {
  return (
    <section className="grid grid-cols-3 gap-3">
      <InputTile label="Peso" value={weight} step={0.5} onChange={setWeight} unit="kg" />
      <InputTile label="Reps" value={reps} step={1} onChange={setReps} unit="" />
      <InputTile label="RPE" value={rpe} step={0.5} onChange={setRpe} unit="" />
    </section>
  );
}

function InputTile({
  label, value, step, onChange, unit,
}: {
  label: string; value: number; step: number;
  onChange: (v: number) => void; unit: string;
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
          {unit && <span className="text-[12px] font-medium text-neutral-500">{unit}</span>}
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

function AIRestCard({ restTime }: { restTime: number; isResting: boolean; setIsResting: (v: boolean) => void }) {
  const minutes = Math.floor(restTime / 60);
  const seconds = restTime % 60;
  const maxTime = 105;
  const progress = restTime / maxTime;

  return (
    <section className="relative overflow-hidden rounded-3xl bg-neutral-900/60 p-5 backdrop-blur-xl ring-1 ring-inset ring-indigo-500/20">
      <div className="pointer-events-none absolute inset-0 overflow-hidden rounded-3xl">
        <div className="absolute -left-20 -top-20 h-40 w-40 rounded-full bg-indigo-500/10 blur-2xl" />
      </div>

      <div className="relative flex items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="relative h-[68px] w-[68px] shrink-0">
            <svg className="h-full w-full -rotate-90" viewBox="0 0 68 68">
              <circle cx="34" cy="34" r="30" stroke="white" strokeOpacity="0.08" strokeWidth="4" fill="none" />
              <circle
                cx="34" cy="34" r="30"
                stroke="url(#restGradient)" strokeWidth="4" strokeLinecap="round" fill="none"
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
              {minutes}:{seconds.toString().padStart(2, '0')}
            </p>
            <p className="text-[13px] text-neutral-400">Descanso óptimo</p>
          </div>
        </div>

        <button className="group relative grid h-14 w-14 place-items-center rounded-full transition active:scale-95">
          <div className="absolute inset-0 rounded-full bg-gradient-to-tr from-violet-600 via-indigo-500 to-cyan-500 opacity-100 transition group-active:opacity-80" />
          <div className="pointer-events-none absolute -inset-1 rounded-full bg-gradient-to-tr from-violet-600/50 to-cyan-500/50 opacity-60 blur-lg transition group-active:opacity-80" />
          <Mic className="relative z-10 h-6 w-6 text-white" strokeWidth={2.5} />
          <div className="absolute inset-0 overflow-hidden rounded-full">
            <div className="absolute left-4 top-1/2 flex -translate-y-1/2 items-center gap-[2px]">
              {[0.35, 0.7, 0.5, 0.85, 0.4, 0.65, 0.55, 0.75].map((h, i) => (
                <span
                  key={i}
                  className="w-[2px] rounded-full bg-white/90 animate-wave"
                  style={{ height: `${h * 14}px`, animationDelay: `${i * 0.1}s` }}
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

/* ============================== WORKOUT DETAIL ============================== */

const ZONES = [
  { name: 'Calentamiento', pct: 5, color: '#378ADD' },
  { name: 'Quema grasa', pct: 18, color: '#22C55E' },
  { name: 'Cardio', pct: 32, color: '#F5C84B' },
  { name: 'Anaeróbico', pct: 31, color: '#F08A3D' },
  { name: 'Pico', pct: 14, color: '#E0473A' },
];

const HR: number[] = [
  102, 108, 112, 118, 124, 128, 132, 138, 144, 148,
  158, 168, 154, 160, 170, 156, 162, 172, 158, 164,
  174, 160, 168, 156, 166, 152, 162, 150, 160, 148,
  158, 146, 156, 144, 154, 142, 150, 138, 146, 134,
  142, 132, 138, 128, 132, 124, 126, 118, 114, 108,
];

export function WorkoutDetailScreen({ id: _id }: { id: string }) {
  const { goBack } = useNav();
  return (
    <div className="min-h-screen w-full bg-[#0B0B0F] text-zinc-100">
      <div className="mx-auto w-full max-w-[440px] px-5 pb-14 pt-4">
        <div className="grid grid-cols-[auto_1fr_auto] items-center gap-3 pb-5">
          <button
            onClick={goBack}
            aria-label="Volver"
            className="grid h-9 w-9 place-items-center rounded-full bg-white/5 ring-1 ring-white/10 transition active:scale-95"
          >
            <ArrowLeft className="h-4 w-4" strokeWidth={2.25} />
          </button>
          <h1 className="text-center text-[14px] font-semibold tracking-tight text-zinc-200">
            Detalle del entrenamiento
          </h1>
          <span
            className="rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-[0.14em]"
            style={{ background: 'rgba(157,123,255,0.18)', color: '#C9B6FF' }}
          >
            Mi Band
          </span>
        </div>

        <header className="pb-6">
          <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-500">
            Fuerza · Gimnasio
          </p>
          <h2 className="mt-2 text-[28px] font-bold leading-tight tracking-tight text-white">
            Entrenamiento de pesas
          </h2>
          <p className="mt-1 text-[12px] text-zinc-500">Lun 23 jun · 07:12 — 08:02</p>
        </header>

        <StatsGrid />

        <HrChartCard />

        <ZonesCard />

        <IntensityCard />

        <ComparisonCard />
      </div>
    </div>
  );
}

function StatsGrid() {
  const stats = [
    { label: 'Duración', value: '50', unit: 'min', sub: '07:12 → 08:02' },
    { label: 'Calorías', value: '387', unit: 'kcal', sub: '7.7 kcal / min' },
    { label: 'FC media', value: '148', unit: 'bpm', sub: 'zona anaeróbica' },
    { label: 'FC máxima', value: '174', unit: 'bpm', sub: 'mín: 102 bpm' },
  ];
  return (
    <div className="grid grid-cols-2 gap-3">
      {stats.map((s) => (
        <div
          key={s.label}
          className="rounded-3xl bg-white/[0.03] p-4 ring-1 ring-white/[0.06]"
        >
          <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-zinc-500">
            {s.label}
          </p>
          <p className="mt-2 flex items-baseline gap-1 leading-none">
            <span className="text-[26px] font-bold tracking-tight text-white">
              {s.value}
            </span>
            <span className="text-[11px] text-zinc-500">{s.unit}</span>
          </p>
          <p className="mt-1.5 text-[11px] text-zinc-500">{s.sub}</p>
        </div>
      ))}
    </div>
  );
}

function HrChartCard() {
  const w = 320;
  const h = 140;
  const min = 95;
  const max = 180;
  const n = HR.length;
  const x = (i: number) => (i / (n - 1)) * w;
  const y = (v: number) => h - ((v - min) / (max - min)) * h;

  const linePath = HR.map((v, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const areaPath = `${linePath} L${w},${h} L0,${h} Z`;

  const peakIdx = HR.indexOf(Math.max(...HR));
  const minIdx = HR.indexOf(Math.min(...HR));

  return (
    <section className="mt-3 rounded-3xl bg-white/[0.03] p-5 ring-1 ring-white/[0.06]">
      <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-500">
        Frecuencia cardíaca
      </p>
      <div className="relative mt-4">
        <svg viewBox={`0 0 ${w} ${h + 8}`} className="h-40 w-full overflow-visible">
          <defs>
            <linearGradient id="hrFill" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0%" stopColor="#9D7BFF" stopOpacity="0.45" />
              <stop offset="100%" stopColor="#9D7BFF" stopOpacity="0" />
            </linearGradient>
          </defs>
          <line x1="0" x2={w} y1={y(102)} y2={y(102)} stroke="#378ADD" strokeWidth="1" strokeDasharray="3 4" opacity="0.55" />
          <line x1={x(peakIdx)} x2={x(peakIdx)} y1="0" y2={h} stroke="#D85A30" strokeWidth="1" strokeDasharray="3 4" opacity="0.55" />
          <path d={areaPath} fill="url(#hrFill)" />
          <path d={linePath} fill="none" stroke="#9D7BFF" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
          <circle cx={x(peakIdx)} cy={y(174)} r="4" fill="#D85A30" stroke="#0B0B0F" strokeWidth="2" />
          <g transform={`translate(${x(peakIdx) + 6}, ${y(174) - 10})`}>
            <rect x="0" y="-10" rx="6" ry="6" width="78" height="16" fill="#D85A30" />
            <text x="39" y="1" textAnchor="middle" fontSize="9" fontWeight="700" fill="#fff">
              ↑ 174 bpm pico
            </text>
          </g>
          <circle cx={x(minIdx)} cy={y(102)} r="4" fill="#378ADD" stroke="#0B0B0F" strokeWidth="2" />
          <g transform={`translate(${Math.min(x(minIdx) + 8, w - 80)}, ${y(102) + 6})`}>
            <rect x="0" y="0" rx="6" ry="6" width="78" height="16" fill="#378ADD" />
            <text x="39" y="11" textAnchor="middle" fontSize="9" fontWeight="700" fill="#fff">
              ↓ 102 bpm mín.
            </text>
          </g>
        </svg>
      </div>
      <div className="mt-3 flex justify-between text-[10px] font-medium uppercase tracking-wider text-zinc-500">
        <span>07:12</span>
        <span>07:37</span>
        <span>08:02</span>
      </div>
    </section>
  );
}

function ZonesCard() {
  return (
    <section className="mt-3 rounded-3xl bg-white/[0.03] p-5 ring-1 ring-white/[0.06]">
      <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-500">
        Zonas de entrenamiento
      </p>
      <div className="mt-4 flex h-3 w-full overflow-hidden rounded-full">
        {ZONES.map((z) => (
          <div key={z.name} style={{ width: `${z.pct}%`, background: z.color }} />
        ))}
      </div>
      <div className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2">
        {ZONES.map((z) => (
          <div key={z.name} className="flex items-center gap-2 text-[12px]">
            <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: z.color }} />
            <span className="flex-1 truncate text-zinc-300">{z.name}</span>
            <span className="font-semibold tabular-nums text-zinc-100">{z.pct}%</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function IntensityCard() {
  const filled = 4;
  const total = 5;
  const dotColors = ['#22C55E', '#A3D34A', '#F5C84B', '#F08A3D', '#E0473A'];
  return (
    <section className="mt-3 rounded-3xl bg-white/[0.03] p-5 ring-1 ring-white/[0.06]">
      <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-zinc-500">
        Intensidad del entreno
      </p>
      <div className="mt-3 flex items-center justify-between">
        <div>
          <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-zinc-500">
            Nivel
          </p>
          <p className="mt-1 text-[16px] font-bold tracking-tight text-white">
            Alta <span className="text-zinc-400">· 78% FC máx.</span>
          </p>
        </div>
        <div className="flex items-center gap-2">
          {Array.from({ length: total }).map((_, i) => {
            const on = i < filled;
            return (
              <span
                key={i}
                className="h-3 w-3 rounded-full"
                style={{
                  background: on ? dotColors[i] : 'transparent',
                  border: on ? 'none' : '1.5px solid rgba(255,255,255,0.18)',
                }}
              />
            );
          })}
        </div>
      </div>
    </section>
  );
}

function ComparisonCard() {
  const rows = [
    { icon: Clock, label: 'Duración', delta: '+8 min que tu media', tone: 'good' as const },
    { icon: Flame, label: 'Calorías', delta: '+42 kcal que tu media', tone: 'good' as const },
    { icon: Activity, label: 'Intensidad', delta: 'similar a tu media', tone: 'muted' as const },
  ];
  return (
    <section className="mt-3 rounded-3xl bg-white/[0.03] p-5 ring-1 ring-white/[0.06]">
      <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-500">
        Comparativa personal
      </p>
      <div className="mt-3 space-y-2">
        {rows.map(({ icon: Icon, label, delta, tone }) => (
          <div
            key={label}
            className="flex items-center gap-3 rounded-2xl bg-white/[0.03] px-3.5 py-3 ring-1 ring-white/[0.05]"
          >
            <div className="grid h-9 w-9 place-items-center rounded-full bg-white/5 text-zinc-300">
              <Icon className="h-4 w-4" strokeWidth={2.25} />
            </div>
            <p className="flex-1 text-[13px] font-medium text-zinc-200">{label}</p>
            <p
              className={
                'inline-flex items-center gap-1 text-[12px] font-semibold ' +
                (tone === 'good' ? 'text-emerald-400' : 'text-zinc-500')
              }
            >
              {tone === 'good' && <TrendingUp className="h-3.5 w-3.5" strokeWidth={2.5} />}
              {delta}
            </p>
          </div>
        ))}
      </div>
      <div className="mt-3 flex items-center gap-2 px-1 text-[11px] text-zinc-500">
        <Heart className="h-3 w-3" strokeWidth={2.25} />
        Basado en tus últimas 8 sesiones de fuerza.
      </div>
    </section>
  );
}

/* ============================== RECOVERY ============================== */

const recoveryTheme = {
  bg: '#F5F5F7', fg: '#1D1D1F', card: '#FFFFFF', surface1: '#F5F5F7', surface2: '#ECECEF',
  label: '#6E6E73', border: 'rgba(0,0,0,0.06)',
  aiFrom: '#B054F0', aiVia: '#6A5CF0', aiTo: '#46B5E8',
  glassFrom: '#F3E8FF', glassTo: '#E5F0FE',
  alertFrom: '#FFF4D6', alertTo: '#FFE3B0',
  alertText: '#8A4B10', alertIcon: '#B45309',
  radius: 24, cardShadow: '0 1px 2px rgba(0,0,0,0.04), 0 8px 24px -12px rgba(0,0,0,0.08)',
} as const;

const aiGradient = `linear-gradient(135deg, ${recoveryTheme.aiFrom} 0%, ${recoveryTheme.aiVia} 50%, ${recoveryTheme.aiTo} 100%)`;
const heroGradient = `linear-gradient(135deg, ${recoveryTheme.glassFrom}, ${recoveryTheme.glassTo})`;
const alertGradient = `linear-gradient(135deg, ${recoveryTheme.alertFrom}, ${recoveryTheme.alertTo})`;

export function RecoveryScreen() {
  const { goBack } = useNav();
  return (
    <div className="min-h-screen w-full" style={{ background: recoveryTheme.bg, color: recoveryTheme.fg }}>
      <div className="mx-auto w-full max-w-[440px]">
        <TopBar title="Recuperación IA" onBack={goBack} />
        <div className="flex flex-col" style={{ padding: '12px 20px 32px 20px', gap: 20 }}>
          <HeroGlassCard />
          <RecoveryPredictiveAlert />
          <StatPillsRow />
          <SleepStagesCard />
        </div>
      </div>
    </div>
  );
}

function HeroGlassCard() {
  return (
    <section
      className="relative overflow-hidden"
      style={{
        background: heroGradient,
        borderRadius: recoveryTheme.radius,
        padding: 24,
        boxShadow: '0 1px 2px rgba(0,0,0,0.04), 0 12px 32px -16px rgba(106,92,240,0.22)',
        border: `1px solid ${recoveryTheme.border}`,
      }}
    >
      <div className="pointer-events-none absolute -right-12 -top-12 h-44 w-44 rounded-full opacity-30 blur-3xl" style={{ background: aiGradient }} />
      <div className="relative flex items-center gap-2.5">
        <div
          className="grid h-9 w-9 place-items-center rounded-full text-white"
          style={{ background: aiGradient, boxShadow: '0 4px 14px -4px rgba(106,92,240,0.45)' }}
        >
          <Sparkles className="h-4 w-4" strokeWidth={2.5} />
        </div>
        <span className="text-[11px] font-semibold uppercase tracking-[1.4px] text-[#4B2E83]">Sueño · Esta noche</span>
      </div>
      <h1
        className="relative mt-3 text-[26px] leading-tight bg-clip-text text-transparent"
        style={{ backgroundImage: aiGradient, fontWeight: 700, letterSpacing: '-0.02em' }}
      >
        Análisis de Recuperación
      </h1>
      <p className="relative mt-2 text-[13px] leading-snug text-[#4B2E83]">
        Tu organismo necesita una jornada ligera. La IA ha recalibrado tu plan en función del descanso.
      </p>
    </section>
  );
}

function RecoveryPredictiveAlert() {
  return (
    <section
      className="relative overflow-hidden"
      style={{ background: alertGradient, borderRadius: recoveryTheme.radius, padding: 20 }}
    >
      <div className="flex items-start gap-3">
        <div
          className="grid h-9 w-9 shrink-0 place-items-center rounded-full"
          style={{ background: 'rgba(255,255,255,0.6)', color: recoveryTheme.alertIcon }}
        >
          <AlertTriangle className="h-4 w-4" strokeWidth={2.5} />
        </div>
        <div className="min-w-0">
          <p className="text-[11px] font-semibold uppercase tracking-[1.4px] text-[#8A4B10] opacity-85">Alerta predictiva · IA</p>
          <p className="mt-1.5 text-[14px] font-semibold leading-snug text-[#8A4B10]">
            Sueño profundo inferior al 15%. Se recomienda reducir la intensidad del entrenamiento (RPE 6).
          </p>
        </div>
      </div>
    </section>
  );
}

function StatPillsRow() {
  const stats = [
    { icon: Moon, label: 'Total Sleep', value: '6h 15m' },
    { icon: Sparkles, label: 'REM', value: '1h 10m' },
    { icon: Heart, label: 'Resting HR', value: '52 bpm' },
  ];
  return (
    <div className="grid grid-cols-3 gap-3">
      {stats.map(({ icon: Icon, label, value }) => (
        <div
          key={label}
          style={{ background: recoveryTheme.card, borderRadius: 18, padding: 14, boxShadow: recoveryTheme.cardShadow, border: `1px solid ${recoveryTheme.border}` }}
          className="flex flex-col gap-2"
        >
          <Icon className="h-3.5 w-3.5" style={{ color: recoveryTheme.aiVia }} strokeWidth={2} />
          <p className="text-[9px] font-semibold uppercase tracking-[1.4px] text-[#6E6E73]">{label}</p>
          <p className="text-[15px] font-bold text-[#1D1D1F]" style={{ lineHeight: 1.1, letterSpacing: '-0.01em' }}>
            {value}
          </p>
        </div>
      ))}
    </div>
  );
}

function SleepStagesCard() {
  const stages = [
    { label: 'Profundo', pct: 12, color: recoveryTheme.aiFrom },
    { label: 'REM', pct: 19, color: recoveryTheme.aiVia },
    { label: 'Ligero', pct: 54, color: recoveryTheme.aiTo },
    { label: 'Despierto', pct: 15, color: '#C7C7CC' },
  ];
  return (
    <section style={{ background: recoveryTheme.card, borderRadius: recoveryTheme.radius, padding: 20, boxShadow: recoveryTheme.cardShadow }}>
      <div className="flex items-center justify-between">
        <p className="text-[11px] font-semibold uppercase tracking-[1.4px] text-[#6E6E73]">Fases del sueño</p>
        <span className="text-[11px] text-[#6E6E73]">7h 25m en cama</span>
      </div>
      <div className="mt-4 flex h-3 w-full overflow-hidden rounded-full" style={{ background: recoveryTheme.surface2 }}>
        {stages.map((s) => (
          <div key={s.label} style={{ width: `${s.pct}%`, background: s.color }} />
        ))}
      </div>
      <ul className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2.5">
        {stages.map((s) => (
          <li key={s.label} className="flex items-center gap-2">
            <span className="h-2 w-2 rounded-full" style={{ background: s.color }} />
            <span className="text-[12px] text-[#1D1D1F]">{s.label}</span>
            <span className="ml-auto text-[12px] font-bold text-[#1D1D1F]">{s.pct}%</span>
          </li>
        ))}
      </ul>
      <div className="mt-5 flex items-center gap-2 rounded-2xl px-3 py-2.5" style={{ background: recoveryTheme.surface1 }}>
        <Activity className="h-4 w-4" style={{ color: recoveryTheme.aiVia }} strokeWidth={2.25} />
        <p className="text-[12px] text-[#1D1D1F]">
          VFC nocturna <span className="font-bold">+8%</span> vs media semanal.
        </p>
      </div>
    </section>
  );
}

/* ============================== DEVICES ============================== */

const devicesTheme = {
  bg: '#F5F5F7', fg: '#1D1D1F', card: '#FFFFFF', surface1: '#F5F5F7', surface2: '#ECECEF',
  label: '#6E6E73', border: 'rgba(0,0,0,0.06)',
  aiFrom: '#B054F0', aiVia: '#6A5CF0', aiTo: '#46B5E8',
  badgeBg: '#1D1D1F', badgeDot: '#FF6900', live: '#10B981',
  radius: 24, cardShadow: '0 1px 2px rgba(0,0,0,0.04), 0 8px 24px -12px rgba(0,0,0,0.08)',
} as const;

const devicesAiGradient = `linear-gradient(135deg, ${devicesTheme.aiFrom} 0%, ${devicesTheme.aiVia} 50%, ${devicesTheme.aiTo} 100%)`;

export function DevicesScreen() {
  const { goBack } = useNav();
  return (
    <div className="min-h-screen w-full" style={{ background: devicesTheme.bg, color: devicesTheme.fg }}>
      <div className="mx-auto w-full max-w-[440px]">
        <TopBar title="Device Sync Center" onBack={goBack} />
        <div className="flex flex-col" style={{ padding: '12px 20px 32px 20px', gap: 20 }}>
          <PrimaryDeviceCard />
          <OtherDevicesCard />
          <PrimarySyncButton />
        </div>
      </div>
    </div>
  );
}

function PrimaryDeviceCard() {
  return (
    <section style={{ background: devicesTheme.card, borderRadius: devicesTheme.radius, padding: 20, boxShadow: devicesTheme.cardShadow, border: `1px solid ${devicesTheme.border}` }}>
      <div className="flex items-start justify-between gap-3">
        <div className="flex flex-col gap-3 min-w-0">
          <span
            className="inline-flex items-center gap-1.5"
            style={{ background: devicesTheme.badgeBg, borderRadius: 999, padding: '5px 10px 5px 7px' }}
          >
            <span className="h-2 w-2 rounded-full" style={{ background: devicesTheme.badgeDot }} />
            <span className="text-[9px] font-bold uppercase tracking-wider text-white">Device</span>
          </span>
          <div>
            <h2 className="text-[22px] font-bold text-[#1D1D1F]" style={{ lineHeight: 1.1, letterSpacing: '-0.02em' }}>
              Redmi Watch 5
            </h2>
            <p className="mt-1 text-[12px] text-[#6E6E73]">
              Conectado · batería 82% · firmware 3.4.1
            </p>
          </div>
        </div>
        <div
          className="inline-flex items-center gap-2 rounded-full"
          style={{ background: 'rgba(16,185,129,0.12)', border: '1px solid rgba(16,185,129,0.35)', padding: '6px 12px 6px 8px' }}
        >
          <span className="relative grid h-3 w-3 place-items-center">
            <span className="absolute h-2 w-2 rounded-full animate-ai-pulse" style={{ background: devicesTheme.live }} />
            <span className="absolute h-2 w-2 rounded-full animate-ai-ring" style={{ background: devicesTheme.live, opacity: 0.4 }} />
          </span>
          <span className="text-[11px] font-semibold" style={{ color: devicesTheme.live }}>
            Syncing…
          </span>
        </div>
      </div>

      <div className="mt-5 grid grid-cols-3 gap-2.5">
        <DeviceMetric label="Pasos hoy" value="8 412" />
        <DeviceMetric label="HR live" value="64" suffix="bpm" />
        <DeviceMetric label="Última sync" value="hace 12s" />
      </div>
    </section>
  );
}

function DeviceMetric({ label, value, suffix }: { label: string; value: string; suffix?: string }) {
  return (
    <div style={{ background: devicesTheme.surface1, borderRadius: 14, padding: 12 }}>
      <p className="text-[9px] font-semibold uppercase tracking-[1.4px] text-[#6E6E73]">{label}</p>
      <p className="mt-1 text-[13px] font-bold text-[#1D1D1F]" style={{ lineHeight: 1.1 }}>
        {value}
        {suffix && <span className="ml-0.5 text-[10px] font-medium text-[#6E6E73]">{suffix}</span>}
      </p>
    </div>
  );
}

function OtherDevicesCard() {
  const list = [
    { icon: Smartphone, name: 'Health Connect', sub: 'Android · puente activo', status: 'Online' },
    { icon: Ring, name: 'Smart Ring', sub: 'No emparejado', status: 'Offline', muted: true },
    { icon: Watch, name: 'Mi Band 8', sub: 'Histórico importado', status: 'Sync diario' },
  ];
  return (
    <section style={{ background: devicesTheme.card, borderRadius: devicesTheme.radius, padding: 20, boxShadow: devicesTheme.cardShadow, border: `1px solid ${devicesTheme.border}` }}>
      <p className="text-[11px] font-semibold uppercase tracking-[1.4px] text-[#6E6E73]">Otros dispositivos</p>
      <ul className="mt-3 space-y-2">
        {list.map(({ icon: Icon, name, sub, status, muted }) => (
          <li
            key={name}
            className="flex items-center gap-3"
            style={{ background: devicesTheme.surface1, borderRadius: 14, padding: 12, opacity: muted ? 0.55 : 1 }}
          >
            <div
              className="grid h-9 w-9 shrink-0 place-items-center rounded-xl"
              style={{ background: devicesTheme.card, color: devicesTheme.fg, border: `1px solid ${devicesTheme.border}` }}
            >
              <Icon className="h-4 w-4" strokeWidth={2} />
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-[13px] font-semibold text-[#1D1D1F]" style={{ lineHeight: 1.1 }}>{name}</p>
              <p className="mt-0.5 text-[11px] text-[#6E6E73]">{sub}</p>
            </div>
            <span className="text-[9px] font-semibold uppercase tracking-wider" style={{ color: muted ? devicesTheme.label : devicesTheme.live }}>
              {status}
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}

function PrimarySyncButton() {
  return (
    <button
      className="group relative w-full overflow-hidden text-white transition active:scale-[0.99]"
      style={{
        background: devicesAiGradient,
        borderRadius: 18,
        padding: '16px 20px',
        boxShadow: '0 10px 28px -12px rgba(106,92,240,0.55)',
      }}
    >
      <span className="flex items-center justify-center gap-2">
        <Sparkles className="h-4 w-4" strokeWidth={2.5} />
        <span className="text-[15px] font-bold tracking-tight">Forzar Sincronización AI</span>
        <RefreshCw className="h-4 w-4 opacity-80" strokeWidth={2.25} />
      </span>
    </button>
  );
}

/* ============================== CLINIC IMPORT ============================== */

type Mode = 'menu' | 'pdf' | 'image' | 'manual';

export function ClinicImportScreen() {
  const { goBack } = useNav();
  const [mode, setMode] = useState<Mode>('menu');
  return (
    <div className="min-h-screen w-full bg-surface-2">
      <div className="relative mx-auto flex min-h-screen w-full max-w-[440px] flex-col bg-background">
        <header className="sticky top-0 z-20 glass">
          <div className="flex items-center gap-3 px-4 pb-3 pt-5">
            {mode === 'menu' ? (
              <button
                onClick={goBack}
                className="grid h-9 w-9 place-items-center rounded-full bg-surface-2 ring-1 ring-border"
                aria-label="Volver"
              >
                <ArrowLeft className="h-4 w-4" />
              </button>
            ) : (
              <button
                onClick={() => setMode('menu')}
                className="grid h-9 w-9 place-items-center rounded-full bg-surface-2 ring-1 ring-border"
                aria-label="Volver"
              >
                <ArrowLeft className="h-4 w-4" />
              </button>
            )}
            <div>
              <p className="text-[11px] font-medium uppercase tracking-[0.14em] text-muted-foreground">
                Clínica
              </p>
              <h1 className="text-[17px] font-semibold leading-tight">Importar analítica</h1>
            </div>
          </div>
        </header>

        <main className="flex-1 px-5 pb-10 pt-4">
          {mode === 'menu' && <ClinicMenu onPick={setMode} />}
          {mode === 'pdf' && <FileDrop accept="application/pdf,.pdf" title="Subir PDF" hint="Informe médico, analítica o DICOM" icon={FileText} />}
          {mode === 'image' && <FileDrop accept="image/*" title="Subir imagen" hint="Foto de la analítica o gráfica" icon={ImageIcon} capture />}
          {mode === 'manual' && <ManualForm />}
        </main>
      </div>
    </div>
  );
}

function ClinicMenu({ onPick }: { onPick: (m: Mode) => void }) {
  const opts: { key: Mode; icon: typeof FileText; title: string; sub: string }[] = [
    { key: 'pdf', icon: FileText, title: 'Subir PDF', sub: 'Informe médico, analítica, DICOM' },
    { key: 'image', icon: ImageIcon, title: 'Subir imagen', sub: 'Foto de la analítica' },
    { key: 'manual', icon: Keyboard, title: 'Introducir a mano', sub: 'Valores clave: colesterol, glucosa…' },
  ];
  return (
    <div className="space-y-3">
      <p className="px-1 text-[13px] text-muted-foreground">
        Elige cómo quieres añadir tus datos clínicos.
      </p>
      {opts.map(({ key, icon: Icon, title, sub }) => (
        <button
          key={key}
          onClick={() => onPick(key)}
          className="flex w-full items-center gap-4 rounded-[24px] bg-card p-4 text-left shadow-soft transition active:scale-[0.99]"
        >
          <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-ai-soft">
            <Icon className="h-5 w-5 text-foreground" strokeWidth={2.25} />
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-[15px] font-bold leading-tight">{title}</p>
            <p className="mt-0.5 text-[12px] text-muted-foreground">{sub}</p>
          </div>
          <ChevronRight className="h-5 w-5 text-muted-foreground" />
        </button>
      ))}
    </div>
  );
}

function FileDrop({
  accept, title, hint, icon: Icon, capture = false,
}: { accept: string; title: string; hint: string; icon: typeof FileText; capture?: boolean }) {
  const ref = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const { goBack } = useNav();
  return (
    <div className="space-y-4">
      <button
        onClick={() => ref.current?.click()}
        className="block w-full rounded-[28px] border-2 border-dashed border-border bg-card p-8 text-center shadow-soft transition hover:border-foreground/30 active:scale-[0.99]"
      >
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-ai-soft">
          <Icon className="h-6 w-6 text-foreground" strokeWidth={2.25} />
        </div>
        <p className="mt-3 text-[16px] font-bold">{title}</p>
        <p className="mt-1 text-[12px] text-muted-foreground">{hint}</p>
        <span className="mt-4 inline-flex items-center gap-2 rounded-full bg-foreground px-4 py-2 text-[12px] font-semibold text-background">
          <Upload className="h-3.5 w-3.5" />
          {capture ? 'Tomar / elegir' : 'Elegir archivo'}
        </span>
      </button>
      <input
        ref={ref}
        type="file"
        accept={accept}
        {...(capture ? { capture: 'environment' as const } : {})}
        className="hidden"
        onChange={(e) => setFile(e.target.files?.[0] ?? null)}
      />
      {file && (
        <div className="rounded-2xl bg-card p-4 shadow-soft">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
            Archivo seleccionado
          </p>
          <p className="mt-1 truncate text-[14px] font-semibold">{file.name}</p>
          <p className="text-[11px] text-muted-foreground">{(file.size / 1024).toFixed(0)} KB</p>
          <button
            onClick={goBack}
            className="mt-4 inline-flex w-full items-center justify-center rounded-2xl bg-ai-gradient px-5 py-3 text-[14px] font-semibold text-white shadow-card"
          >
            Analizar con IA
          </button>
        </div>
      )}
    </div>
  );
}

const MANUAL_FIELDS: { key: string; label: string; unit: string; placeholder: string }[] = [
  { key: 'chol', label: 'Colesterol total', unit: 'mg/dL', placeholder: '190' },
  { key: 'hdl', label: 'HDL', unit: 'mg/dL', placeholder: '55' },
  { key: 'ldl', label: 'LDL', unit: 'mg/dL', placeholder: '110' },
  { key: 'trig', label: 'Triglicéridos', unit: 'mg/dL', placeholder: '120' },
  { key: 'glu', label: 'Glucosa', unit: 'mg/dL', placeholder: '92' },
  { key: 'hba1c', label: 'HbA1c', unit: '%', placeholder: '5.3' },
  { key: 'vitd', label: 'Vitamina D', unit: 'ng/mL', placeholder: '32' },
  { key: 'fer', label: 'Ferritina', unit: 'ng/mL', placeholder: '80' },
];

function ManualForm() {
  const { goBack } = useNav();
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        goBack();
      }}
      className="space-y-3"
    >
      <div className="rounded-[24px] bg-card p-4 shadow-soft">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Valores clave
        </p>
        <div className="mt-3 grid grid-cols-2 gap-3">
          {MANUAL_FIELDS.map((f) => (
            <label key={f.key} className="block">
              <span className="text-[11px] font-medium text-muted-foreground">{f.label}</span>
              <div className="mt-1 flex items-center gap-1 rounded-xl bg-surface-1 px-3 py-2 ring-1 ring-border focus-within:ring-foreground/30">
                <input
                  inputMode="decimal"
                  placeholder={f.placeholder}
                  className="min-w-0 flex-1 bg-transparent text-[14px] font-semibold outline-none placeholder:text-muted-foreground/60"
                />
                <span className="text-[10px] text-muted-foreground">{f.unit}</span>
              </div>
            </label>
          ))}
        </div>
      </div>
      <button
        type="submit"
        className="inline-flex w-full items-center justify-center rounded-2xl bg-ai-gradient px-5 py-4 text-[15px] font-semibold text-white shadow-card"
      >
        Guardar y analizar
      </button>
    </form>
  );
}

/* ============================== ROUTINE BUILDER ============================== */

type ActivityType = 'gym' | 'cardio' | 'calistenia' | 'yoga' | 'deportes';

const ACTIVITY_COLORS: Record<ActivityType, string> = {
  gym: '#059669',
  cardio: '#2563EB',
  calistenia: '#D97706',
  yoga: '#7C3AED',
  deportes: '#EC4899',
};

const ACTIVITY_ICONS: Record<ActivityType, typeof Dumbbell> = {
  gym: Dumbbell,
  cardio: HeartPulse,
  calistenia: Bike,
  yoga: Wind,
  deportes: Trophy,
};

const DAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'] as const;

type Exercise = {
  id: string;
  name: string;
  sets?: number;
  reps?: string;
  weight?: number;
  duration?: string;
  notes?: string;
};
type RoutineDay = {
  day_of_week: (typeof DAYS)[number];
  focus: string;
  exercises: Exercise[];
};

export function RoutineBuilderScreen() {
  const { goBack, navigate } = useNav();
  const [activity, setActivity] = useState<ActivityType>('gym');
  const [routineName, setRoutineName] = useState('Mi nueva rutina');
  const [days, setDays] = useState<RoutineDay[]>(
    DAYS.map((d) => ({ day_of_week: d, focus: '', exercises: [] })),
  );
  const [editing, setEditing] = useState<{ day: string; id: string } | null>(null);

  useEffect(() => {
    try {
      const raw = sessionStorage.getItem('quickAdd:lastDay');
      if (!raw) return;
      const payload = JSON.parse(raw) as { day_of_week: string; exercises: Exercise[] };
      sessionStorage.removeItem('quickAdd:lastDay');
      setDays((prev) =>
        prev.map((d) =>
          d.day_of_week === payload.day_of_week
            ? { ...d, exercises: [...d.exercises, ...payload.exercises] }
            : d,
        ),
      );
    } catch {
      /* no-op */
    }
  }, []);

  const accent = ACTIVITY_COLORS[activity];

  const removeExercise = (dayName: string, id: string) =>
    setDays((prev) =>
      prev.map((d) =>
        d.day_of_week === dayName
          ? { ...d, exercises: d.exercises.filter((e) => e.id !== id) }
          : d,
      ),
    );

  const updateExercise = (dayName: string, id: string, patch: Partial<Exercise>) =>
    setDays((prev) =>
      prev.map((d) =>
        d.day_of_week === dayName
          ? { ...d, exercises: d.exercises.map((e) => (e.id === id ? { ...e, ...patch } : e)) }
          : d,
      ),
    );

  const updateFocus = (dayName: string, focus: string) =>
    setDays((prev) =>
      prev.map((d) => (d.day_of_week === dayName ? { ...d, focus } : d)),
    );

  return (
    <div className="min-h-screen w-full bg-[#F5F5F7] text-[#1D1D1F]">
      <div className="mx-auto w-full max-w-[440px] px-5 pb-24 pt-4">
        <div className="grid grid-cols-[auto_1fr_auto] items-center gap-3">
          <button
            onClick={goBack}
            aria-label="Volver"
            className="grid h-9 w-9 place-items-center rounded-full bg-white ring-1 ring-[rgba(0,0,0,0.06)]"
          >
            <ArrowLeft className="h-4 w-4" />
          </button>
          <h1 className="text-center text-[14px] font-semibold tracking-tight">
            Constructor de rutina
          </h1>
          <span className="w-9" />
        </div>

        <section className="mt-4 rounded-2xl border border-[rgba(0,0,0,0.06)] bg-white p-4 shadow-card">
          <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-[#6E6E73]">
            Rutina
          </p>
          <input
            value={routineName}
            onChange={(e) => setRoutineName(e.target.value)}
            className="mt-1 w-full bg-transparent text-[20px] font-bold tracking-tight outline-none"
          />
          <div className="mt-3 -mx-1 flex gap-2 overflow-x-auto pb-1 px-1 no-scrollbar">
            {(Object.keys(ACTIVITY_COLORS) as ActivityType[]).map((a) => {
              const Icon = ACTIVITY_ICONS[a];
              const active = a === activity;
              const color = ACTIVITY_COLORS[a];
              return (
                <button
                  key={a}
                  onClick={() => setActivity(a)}
                  className="flex shrink-0 items-center gap-1.5 rounded-full px-3 py-1.5 text-[12px] font-semibold capitalize transition"
                  style={{
                    background: active ? color : '#ECECEF',
                    color: active ? '#FFFFFF' : '#1D1D1F',
                    border: `1px solid ${active ? color : 'rgba(0,0,0,0.06)'}`,
                  }}
                >
                  <Icon className="h-3.5 w-3.5" />
                  {a}
                </button>
              );
            })}
          </div>
        </section>

        <section className="mt-5 space-y-3">
          {days.map((d) => (
            <div
              key={d.day_of_week}
              className="rounded-2xl border border-[rgba(0,0,0,0.06)] bg-white p-4 shadow-card"
            >
              <div className="flex items-center gap-2">
                <span
                  className="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider"
                  style={{ background: `${accent}1A`, color: accent }}
                >
                  {d.day_of_week}
                </span>
                <input
                  value={d.focus}
                  onChange={(e) => updateFocus(d.day_of_week, e.target.value)}
                  placeholder="Foco del día (ej. Pecho y tríceps)"
                  className="min-w-0 flex-1 bg-transparent text-[13px] font-semibold outline-none placeholder:font-normal"
                />
                <span className="text-[11px] tabular-nums text-[#6E6E73]">
                  {d.exercises.length}
                </span>
              </div>

              {d.exercises.length > 0 && (
                <ul className="mt-3 space-y-1.5">
                  {d.exercises.map((ex) => {
                    const isOpen = editing?.day === d.day_of_week && editing.id === ex.id;
                    return (
                      <li
                        key={ex.id}
                        className="rounded-xl border border-[rgba(0,0,0,0.06)] bg-[#ECECEF] px-3 py-2"
                      >
                        <div className="flex items-center gap-2">
                          <p className="min-w-0 flex-1 truncate text-[12.5px] font-semibold">
                            {ex.name}
                          </p>
                          <p className="text-[11px] tabular-nums text-[#6E6E73]">
                            {formatExercise(ex, activity)}
                          </p>
                          <button
                            onClick={() => setEditing(isOpen ? null : { day: d.day_of_week, id: ex.id })}
                            aria-label="Editar"
                            className="grid h-6 w-6 place-items-center rounded-full bg-white ring-1 ring-[rgba(0,0,0,0.06)]"
                          >
                            <Pencil className="h-3 w-3 text-[#6E6E73]" />
                          </button>
                          <button
                            onClick={() => removeExercise(d.day_of_week, ex.id)}
                            aria-label="Eliminar"
                            className="grid h-6 w-6 place-items-center rounded-full bg-white ring-1 ring-[rgba(0,0,0,0.06)]"
                          >
                            <Trash2 className="h-3 w-3 text-[#FF3B30]" />
                          </button>
                        </div>
                        {isOpen && (
                          <FullEditor
                            exercise={ex}
                            activity={activity}
                            onChange={(patch) => updateExercise(d.day_of_week, ex.id, patch)}
                          />
                        )}
                      </li>
                    );
                  })}
                </ul>
              )}

              <button
                onClick={() => navigate({ name: 'routine-quick-add', activity, day: d.day_of_week })}
                className="mt-3 flex w-full items-center justify-center gap-1.5 rounded-full py-2.5 text-[12.5px] font-semibold text-white transition active:scale-[0.98]"
                style={{ background: accent }}
              >
                <Zap className="h-3.5 w-3.5" strokeWidth={2.5} />
                Añadir ejercicios (rápido)
              </button>
            </div>
          ))}
        </section>
      </div>
    </div>
  );
}

function formatExercise(ex: Exercise, activity: ActivityType) {
  if (activity === 'gym') {
    const parts: string[] = [];
    if (ex.sets) parts.push(`${ex.sets}×${ex.reps ?? '?'}`);
    if (ex.weight != null) parts.push(`${ex.weight}kg`);
    return parts.join(' · ') || '—';
  }
  if (activity === 'calistenia') {
    return `${ex.sets ?? '?'}×${ex.reps ?? '?'}`;
  }
  return ex.duration ?? '—';
}

function FullEditor({
  exercise, activity, onChange,
}: {
  exercise: Exercise;
  activity: ActivityType;
  onChange: (patch: Partial<Exercise>) => void;
}) {
  const showWeight = activity === 'gym';
  const showDuration = activity === 'cardio' || activity === 'yoga' || activity === 'deportes';
  const showSetsReps = activity === 'gym' || activity === 'calistenia';
  return (
    <div className="mt-2 space-y-2 rounded-xl border border-[rgba(0,0,0,0.06)] bg-white p-3">
      {showSetsReps && (
        <div className="grid grid-cols-2 gap-2">
          <Field
            label="Series"
            value={exercise.sets?.toString() ?? ''}
            onChange={(v) => onChange({ sets: v === '' ? undefined : Number(v) })}
            type="number"
          />
          <Field
            label="Reps"
            value={exercise.reps ?? ''}
            onChange={(v) => onChange({ reps: v })}
          />
        </div>
      )}
      {showWeight && (
        <Field
          label="Peso (kg)"
          value={exercise.weight?.toString() ?? ''}
          onChange={(v) => onChange({ weight: v === '' ? undefined : Number(v) })}
          type="number"
        />
      )}
      {showDuration && (
        <Field
          label="Duración"
          value={exercise.duration ?? ''}
          onChange={(v) => onChange({ duration: v })}
        />
      )}
      <div>
        <p className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-[#6E6E73]">
          Notas
        </p>
        <textarea
          value={exercise.notes ?? ''}
          onChange={(e) => onChange({ notes: e.target.value })}
          rows={2}
          className="w-full resize-none rounded-lg border border-[rgba(0,0,0,0.06)] bg-[#ECECEF] px-2.5 py-1.5 text-[12px] outline-none"
          placeholder="Ej. RPE 8, controla la excéntrica"
        />
      </div>
    </div>
  );
}

function Field({
  label, value, onChange, type = 'text',
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: 'text' | 'number';
}) {
  return (
    <div>
      <p className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-[#6E6E73]">
        {label}
      </p>
      <input
        value={value}
        type={type}
        inputMode={type === 'number' ? 'decimal' : undefined}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg border border-[rgba(0,0,0,0.06)] bg-[#ECECEF] px-2.5 py-1.5 text-[12px] outline-none"
      />
    </div>
  );
}

/* ============================== QUICK ADD ============================== */

type MuscleGroup = 'Pecho' | 'Espalda' | 'Piernas' | 'Hombros' | 'Brazos' | 'Core' | 'Cardio';

const MUSCLE_GROUPS: MuscleGroup[] = ['Pecho', 'Espalda', 'Piernas', 'Hombros', 'Brazos', 'Core', 'Cardio'];
const REP_CHIPS = ['6-8', '8-12', '12-15', 'AMRAP'];

type CatalogItem = { nombre: string; grupo_muscular: MuscleGroup; equipamiento: string; descripcion: string };

const CATALOG: CatalogItem[] = [
  { nombre: 'Press banca', grupo_muscular: 'Pecho', equipamiento: 'Barra', descripcion: 'Fuerza pectoral' },
  { nombre: 'Press inclinado mancuerna', grupo_muscular: 'Pecho', equipamiento: 'Mancuernas', descripcion: 'Pecho superior' },
  { nombre: 'Aperturas polea', grupo_muscular: 'Pecho', equipamiento: 'Polea', descripcion: 'Aislamiento pecho' },
  { nombre: 'Fondos en paralelas', grupo_muscular: 'Pecho', equipamiento: 'Peso corporal', descripcion: 'Pecho + tríceps' },
  { nombre: 'Dominadas', grupo_muscular: 'Espalda', equipamiento: 'Barra', descripcion: 'Dorsal' },
  { nombre: 'Remo con barra', grupo_muscular: 'Espalda', equipamiento: 'Barra', descripcion: 'Grosor de espalda' },
  { nombre: 'Jalón al pecho', grupo_muscular: 'Espalda', equipamiento: 'Polea', descripcion: 'Dorsal ancho' },
  { nombre: 'Remo mancuerna', grupo_muscular: 'Espalda', equipamiento: 'Mancuernas', descripcion: 'Unilateral' },
  { nombre: 'Sentadilla', grupo_muscular: 'Piernas', equipamiento: 'Barra', descripcion: 'Cuádriceps' },
  { nombre: 'Peso muerto rumano', grupo_muscular: 'Piernas', equipamiento: 'Barra', descripcion: 'Isquios y glúteo' },
  { nombre: 'Prensa', grupo_muscular: 'Piernas', equipamiento: 'Máquina', descripcion: 'Piernas' },
  { nombre: 'Zancadas', grupo_muscular: 'Piernas', equipamiento: 'Mancuernas', descripcion: 'Unilateral pierna' },
  { nombre: 'Curl femoral', grupo_muscular: 'Piernas', equipamiento: 'Máquina', descripcion: 'Isquios' },
  { nombre: 'Press militar', grupo_muscular: 'Hombros', equipamiento: 'Barra', descripcion: 'Deltoides' },
  { nombre: 'Elevaciones laterales', grupo_muscular: 'Hombros', equipamiento: 'Mancuernas', descripcion: 'Deltoide medio' },
  { nombre: 'Face pull', grupo_muscular: 'Hombros', equipamiento: 'Polea', descripcion: 'Deltoide posterior' },
  { nombre: 'Curl bíceps barra', grupo_muscular: 'Brazos', equipamiento: 'Barra', descripcion: 'Bíceps' },
  { nombre: 'Curl martillo', grupo_muscular: 'Brazos', equipamiento: 'Mancuernas', descripcion: 'Braquial' },
  { nombre: 'Press francés', grupo_muscular: 'Brazos', equipamiento: 'Barra Z', descripcion: 'Tríceps' },
  { nombre: 'Extensión tríceps polea', grupo_muscular: 'Brazos', equipamiento: 'Polea', descripcion: 'Tríceps' },
  { nombre: 'Plancha', grupo_muscular: 'Core', equipamiento: 'Peso corporal', descripcion: 'Estabilidad' },
  { nombre: 'Crunch abdominal', grupo_muscular: 'Core', equipamiento: 'Peso corporal', descripcion: 'Abdomen' },
  { nombre: 'Rueda abdominal', grupo_muscular: 'Core', equipamiento: 'Rueda', descripcion: 'Core anti-extensión' },
  { nombre: 'Carrera continua', grupo_muscular: 'Cardio', equipamiento: 'Cinta', descripcion: 'Aeróbico' },
  { nombre: 'HIIT bicicleta', grupo_muscular: 'Cardio', equipamiento: 'Bicicleta', descripcion: 'Intervalos' },
  { nombre: 'Remo indoor', grupo_muscular: 'Cardio', equipamiento: 'Remo', descripcion: 'Cuerpo completo' },
];

function newId() {
  return Math.random().toString(36).slice(2, 10);
}

function defaultsFor(activity: ActivityType): Partial<Exercise> {
  if (activity === 'gym' || activity === 'calistenia') return { sets: 3, reps: '8-12' };
  if (activity === 'cardio') return { duration: '20 min' };
  if (activity === 'yoga') return { duration: '30 min' };
  return { duration: '45 min' };
}

export function QuickAddScreen({ activity: activityProp, day: dayProp }: { activity?: string; day?: string }) {
  const { navigate } = useNav();
  const activity = (activityProp as ActivityType) ?? 'gym';
  const day = dayProp ?? 'Lunes';
  const accent = ACTIVITY_COLORS[activity];

  const [query, setQuery] = useState('');
  const [group, setGroup] = useState<MuscleGroup | 'Todos'>('Todos');
  const [added, setAdded] = useState<Exercise[]>([]);
  const [customOpen, setCustomOpen] = useState(false);

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    return CATALOG.filter((c) => {
      if (group !== 'Todos' && c.grupo_muscular !== group) return false;
      if (!q) return true;
      return (
        c.nombre.toLowerCase().includes(q) ||
        c.grupo_muscular.toLowerCase().includes(q) ||
        c.equipamiento.toLowerCase().includes(q)
      );
    });
  }, [query, group]);

  const grouped = useMemo(() => {
    const map = new Map<MuscleGroup, CatalogItem[]>();
    for (const item of results) {
      const list = map.get(item.grupo_muscular) ?? [];
      list.push(item);
      map.set(item.grupo_muscular, list);
    }
    return Array.from(map.entries());
  }, [results]);

  const addFromCatalog = (c: CatalogItem) => {
    const base = defaultsFor(activity);
    setAdded((prev) => [...prev, { id: newId(), name: c.nombre, ...base }]);
  };

  const addCustom = (name: string) => {
    if (!name.trim()) return;
    const base = defaultsFor(activity);
    setAdded((prev) => [...prev, { id: newId(), name: name.trim(), ...base }]);
    setCustomOpen(false);
  };

  const update = (id: string, patch: Partial<Exercise>) =>
    setAdded((prev) => prev.map((e) => (e.id === id ? { ...e, ...patch } : e)));
  const remove = (id: string) =>
    setAdded((prev) => prev.filter((e) => e.id !== id));
  const duplicate = (id: string) =>
    setAdded((prev) => {
      const idx = prev.findIndex((e) => e.id === id);
      if (idx < 0) return prev;
      const copy: Exercise = { ...prev[idx]!, id: newId() };
      return [...prev.slice(0, idx + 1), copy, ...prev.slice(idx + 1)];
    });
  const move = (id: string, dir: -1 | 1) =>
    setAdded((prev) => {
      const i = prev.findIndex((e) => e.id === id);
      const j = i + dir;
      if (i < 0 || j < 0 || j >= prev.length) return prev;
      const next = prev.slice();
      [next[i], next[j]] = [next[j]!, next[i]!];
      return next;
    });

  const handleSave = () => {
    try {
      const payload = { day_of_week: day, exercises: added };
      sessionStorage.setItem('quickAdd:lastDay', JSON.stringify(payload));
    } catch {
      /* no-op */
    }
    navigate({ name: 'routine-builder' });
  };

  return (
    <div className="min-h-screen w-full bg-[#F5F5F7] text-[#1D1D1F]">
      <div className="mx-auto w-full max-w-[440px] px-5 pb-32 pt-4">
        <div className="grid grid-cols-[auto_1fr_auto] items-center gap-3">
          <button
            onClick={() => navigate({ name: 'routine-builder' })}
            aria-label="Volver"
            className="grid h-9 w-9 place-items-center rounded-full bg-white ring-1 ring-[rgba(0,0,0,0.06)]"
          >
            <ArrowLeft className="h-4 w-4" />
          </button>
          <div className="min-w-0 text-center">
            <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-[#6E6E73]">
              Añadir rápido · {activity}
            </p>
            <h1 className="mt-0.5 truncate text-[16px] font-bold tracking-tight">
              {day}
            </h1>
          </div>
          <span
            className="justify-self-end rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-[0.14em]"
            style={{ background: `${accent}1A`, color: accent }}
          >
            Rápido
          </span>
        </div>

        <div className="mt-4 flex items-center gap-2 rounded-2xl border border-[rgba(0,0,0,0.06)] bg-white px-3.5 py-3 shadow-card">
          <Search className="h-4 w-4 text-[#8E8E93]" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Busca ejercicio, grupo o equipo…"
            className="w-full bg-transparent text-[14px] outline-none placeholder:text-[#8E8E93]"
            autoFocus
          />
          {query && (
            <button
              onClick={() => setQuery('')}
              aria-label="Limpiar"
              className="grid h-6 w-6 place-items-center rounded-full bg-[#ECECEF]"
            >
              <X className="h-3 w-3 text-[#6E6E73]" />
            </button>
          )}
        </div>

        <div className="mt-3 -mx-1 flex gap-2 overflow-x-auto pb-1 px-1 no-scrollbar">
          {(['Todos', ...MUSCLE_GROUPS] as const).map((g) => {
            const active = group === g;
            return (
              <button
                key={g}
                onClick={() => setGroup(g)}
                className="shrink-0 rounded-full px-3.5 py-1.5 text-[12px] font-semibold transition"
                style={{
                  background: active ? accent : '#FFFFFF',
                  color: active ? '#FFFFFF' : '#1D1D1F',
                  border: `1px solid ${active ? accent : 'rgba(0,0,0,0.06)'}`,
                }}
              >
                {g}
              </button>
            );
          })}
        </div>

        {added.length > 0 && (
          <section className="mt-5">
            <div className="mb-2 flex items-center justify-between px-1">
              <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-[#6E6E73]">
                Ejercicios de hoy · {added.length}
              </p>
              <span
                className="rounded-full px-2 py-0.5 text-[10px] font-bold"
                style={{ background: `${accent}1A`, color: accent }}
              >
                {day}
              </span>
            </div>
            <div className="space-y-2.5">
              {added.map((ex, i) => (
                <AddedExerciseCard
                  key={ex.id}
                  exercise={ex}
                  activity={activity}
                  accent={accent}
                  index={i}
                  total={added.length}
                  onUpdate={(patch) => update(ex.id, patch)}
                  onRemove={() => remove(ex.id)}
                  onDuplicate={() => duplicate(ex.id)}
                  onMove={(dir) => move(ex.id, dir)}
                />
              ))}
            </div>
          </section>
        )}

        <section className="mt-6">
          <p className="mb-2 px-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-[#6E6E73]">
            Catálogo
          </p>
          {grouped.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-[rgba(0,0,0,0.06)] bg-white px-4 py-8 text-center">
              <p className="text-[13px] font-semibold">Sin resultados</p>
              <p className="mt-1 text-[12px] text-[#6E6E73]">
                Prueba otro término o crea uno personalizado.
              </p>
              <button
                onClick={() => setCustomOpen(true)}
                className="mt-3 rounded-full bg-[#1D1D1F] px-4 py-2 text-[12px] font-semibold text-white"
              >
                Ejercicio personalizado
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              {grouped.map(([g, items]) => (
                <div key={g}>
                  <p className="mb-1.5 px-1 text-[11px] font-semibold">{g}</p>
                  <div className="overflow-hidden rounded-2xl border border-[rgba(0,0,0,0.06)] bg-white shadow-card">
                    {items.map((c, idx) => (
                      <button
                        key={c.nombre}
                        onClick={() => addFromCatalog(c)}
                        className="flex w-full items-center gap-3 px-3.5 py-3 text-left transition active:scale-[0.99]"
                        style={{
                          borderTop: idx === 0 ? 'none' : '1px solid rgba(0,0,0,0.06)',
                        }}
                      >
                        <div
                          className="grid h-9 w-9 shrink-0 place-items-center rounded-full"
                          style={{ background: `${accent}14`, color: accent }}
                        >
                          <Plus className="h-4 w-4" strokeWidth={2.5} />
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-[13.5px] font-semibold">
                            {c.nombre}
                          </p>
                          <p className="truncate text-[11px] text-[#6E6E73]">
                            {c.equipamiento} · {c.descripcion}
                          </p>
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>

      <button
        onClick={() => setCustomOpen(true)}
        className="fixed left-1/2 z-30 flex -translate-x-1/2 items-center gap-2 rounded-full px-4 py-2.5 text-[12.5px] font-semibold text-white shadow-lg transition active:scale-95"
        style={{
          bottom: 'calc(env(safe-area-inset-bottom, 0px) + 88px)',
          background: `linear-gradient(135deg, ${accent}, ${accent}CC)`,
        }}
      >
        <Sparkles className="h-4 w-4" />
        Ejercicio personalizado
      </button>

      <div
        className="fixed inset-x-0 bottom-0 z-20 border-t backdrop-blur-xl"
        style={{
          background: 'rgba(245,245,247,0.85)',
          borderColor: 'rgba(0,0,0,0.06)',
          paddingBottom: 'env(safe-area-inset-bottom, 0px)',
        }}
      >
        <div className="mx-auto flex w-full max-w-[440px] items-center gap-3 px-5 py-3">
          <div className="min-w-0 flex-1">
            <p className="text-[11px] text-[#6E6E73]">
              {added.length === 0 ? 'Añade al menos un ejercicio' : `${added.length} ejercicio${added.length === 1 ? '' : 's'} listos`}
            </p>
            <p className="truncate text-[13px] font-semibold">
              Guardar en {day}
            </p>
          </div>
          <button
            onClick={handleSave}
            disabled={added.length === 0}
            className="flex items-center gap-1.5 rounded-full px-4 py-2.5 text-[13px] font-semibold text-white transition disabled:opacity-40"
            style={{ background: accent }}
          >
            <Check className="h-4 w-4" strokeWidth={2.75} />
            Guardar día
          </button>
        </div>
      </div>

      {customOpen && (
        <CustomExerciseSheet
          onClose={() => setCustomOpen(false)}
          onSubmit={addCustom}
          accent={accent}
          activity={activity}
        />
      )}
    </div>
  );
}

function AddedExerciseCard({
  exercise, activity, accent, index, total,
  onUpdate, onRemove, onDuplicate, onMove,
}: {
  exercise: Exercise;
  activity: ActivityType;
  accent: string;
  index: number;
  total: number;
  onUpdate: (patch: Partial<Exercise>) => void;
  onRemove: () => void;
  onDuplicate: () => void;
  onMove: (dir: -1 | 1) => void;
}) {
  const showWeight = activity === 'gym';
  const showDuration = activity === 'cardio' || activity === 'yoga' || activity === 'deportes';
  const [manualReps, setManualReps] = useState(false);

  return (
    <div className="rounded-2xl border border-[rgba(0,0,0,0.06)] bg-white p-3.5 shadow-card">
      <div className="flex items-start gap-2">
        <div className="flex flex-col items-center gap-1 pt-0.5">
          <button onClick={() => onMove(-1)} disabled={index === 0} className="disabled:opacity-30" aria-label="Subir">
            <GripVertical className="h-4 w-4 text-[#8E8E93]" />
          </button>
          <span className="text-[9px] font-bold tabular-nums text-[#6E6E73]">
            {index + 1}/{total}
          </span>
          <button onClick={() => onMove(1)} disabled={index === total - 1} className="disabled:opacity-30" aria-label="Bajar">
            <GripVertical className="h-4 w-4 rotate-180 text-[#8E8E93]" />
          </button>
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <p className="min-w-0 flex-1 truncate text-[14px] font-semibold">{exercise.name}</p>
            <button onClick={onDuplicate} aria-label="Duplicar" className="grid h-7 w-7 place-items-center rounded-full bg-[#ECECEF]">
              <Copy className="h-3.5 w-3.5 text-[#6E6E73]" />
            </button>
            <button onClick={onRemove} aria-label="Eliminar" className="grid h-7 w-7 place-items-center rounded-full bg-[#ECECEF]">
              <Trash2 className="h-3.5 w-3.5 text-[#FF3B30]" />
            </button>
          </div>

          {(activity === 'gym' || activity === 'calistenia') && (
            <div className="mt-3 flex items-center gap-3">
              <p className="w-14 text-[11px] font-semibold uppercase tracking-wide text-[#6E6E73]">Series</p>
              <div className="flex items-center gap-1 rounded-full bg-[#ECECEF] p-1">
                <button
                  onClick={() => onUpdate({ sets: Math.max(1, (exercise.sets ?? 1) - 1) })}
                  className="grid h-7 w-7 place-items-center rounded-full bg-white ring-1 ring-[rgba(0,0,0,0.06)]"
                  aria-label="Menos series"
                >
                  <Minus className="h-3.5 w-3.5" />
                </button>
                <span className="min-w-6 text-center text-[13px] font-bold tabular-nums">
                  {exercise.sets ?? 0}
                </span>
                <button
                  onClick={() => onUpdate({ sets: Math.min(10, (exercise.sets ?? 0) + 1) })}
                  className="grid h-7 w-7 place-items-center rounded-full bg-white ring-1 ring-[rgba(0,0,0,0.06)]"
                  aria-label="Más series"
                >
                  <Plus className="h-3.5 w-3.5" />
                </button>
              </div>
            </div>
          )}

          {(activity === 'gym' || activity === 'calistenia') && (
            <div className="mt-2.5 flex flex-wrap items-center gap-1.5">
              <p className="w-14 text-[11px] font-semibold uppercase tracking-wide text-[#6E6E73]">Reps</p>
              {REP_CHIPS.map((r) => {
                const active = !manualReps && exercise.reps === r;
                return (
                  <button
                    key={r}
                    onClick={() => { setManualReps(false); onUpdate({ reps: r }); }}
                    className="rounded-full px-2.5 py-1 text-[11.5px] font-semibold"
                    style={{ background: active ? accent : '#ECECEF', color: active ? '#FFFFFF' : '#1D1D1F' }}
                  >
                    {r}
                  </button>
                );
              })}
              <button
                onClick={() => setManualReps((v) => !v)}
                className="rounded-full px-2.5 py-1 text-[11.5px] font-semibold"
                style={{ background: manualReps ? accent : '#ECECEF', color: manualReps ? '#FFFFFF' : '#1D1D1F' }}
              >
                Manual
              </button>
              {manualReps && (
                <input
                  value={exercise.reps ?? ''}
                  onChange={(e) => onUpdate({ reps: e.target.value })}
                  placeholder="ej. 5x5"
                  className="ml-1 w-16 rounded-full border border-[rgba(0,0,0,0.06)] bg-[#ECECEF] px-2.5 py-1 text-[11.5px] font-semibold outline-none"
                />
              )}
            </div>
          )}

          {showWeight && (
            <div className="mt-2.5 flex items-center gap-3">
              <p className="w-14 text-[11px] font-semibold uppercase tracking-wide text-[#6E6E73]">Peso</p>
              <input
                type="number"
                inputMode="decimal"
                value={exercise.weight ?? ''}
                onChange={(e) => onUpdate({ weight: e.target.value === '' ? undefined : Number(e.target.value) })}
                placeholder="—"
                className="w-20 rounded-full border border-[rgba(0,0,0,0.06)] bg-[#ECECEF] px-3 py-1 text-[12.5px] font-semibold outline-none"
              />
              <span className="text-[11px] text-[#6E6E73]">kg</span>
            </div>
          )}

          {showDuration && (
            <div className="mt-3 flex items-center gap-3">
              <p className="w-14 text-[11px] font-semibold uppercase tracking-wide text-[#6E6E73]">Duración</p>
              <input
                value={exercise.duration ?? ''}
                onChange={(e) => onUpdate({ duration: e.target.value })}
                placeholder="ej. 20 min"
                className="w-28 rounded-full border border-[rgba(0,0,0,0.06)] bg-[#ECECEF] px-3 py-1 text-[12.5px] font-semibold outline-none"
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function CustomExerciseSheet({
  onClose, onSubmit, accent, activity,
}: {
  onClose: () => void;
  onSubmit: (name: string) => void;
  accent: string;
  activity: ActivityType;
}) {
  const [name, setName] = useState('');
  return (
    <div
      className="fixed inset-0 z-40 flex items-end justify-center"
      style={{ background: 'rgba(0,0,0,0.35)' }}
      onClick={onClose}
    >
      <div
        className="w-full max-w-[440px] rounded-t-3xl bg-[#F5F5F7] p-5"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mx-auto mb-3 h-1 w-10 rounded-full bg-[#ECECEF]" />
        <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-[#6E6E73]">
          Ejercicio personalizado · {activity}
        </p>
        <h3 className="mt-1 text-[18px] font-bold">Añade tu ejercicio</h3>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Nombre del ejercicio"
          autoFocus
          className="mt-3 w-full rounded-2xl border border-[rgba(0,0,0,0.06)] bg-white px-4 py-3 text-[14px] outline-none"
        />
        <p className="mt-2 text-[11px] text-[#6E6E73]">
          Solo <b>nombre</b> es obligatorio. El resto lo ajustas en la tarjeta.
        </p>
        <div className="mt-4 flex items-center gap-2">
          <button
            onClick={onClose}
            className="flex-1 rounded-full border border-[rgba(0,0,0,0.06)] bg-white py-3 text-[13px] font-semibold"
          >
            Cancelar
          </button>
          <button
            onClick={() => onSubmit(name)}
            disabled={!name.trim()}
            className="flex-1 rounded-full py-3 text-[13px] font-semibold text-white disabled:opacity-40"
            style={{ background: accent }}
          >
            Añadir
          </button>
        </div>
      </div>
    </div>
  );
}
