import { useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowLeft, Play, Pause, Check, RotateCcw, Heart, Flame, Clock,
  ChevronRight, Dumbbell, AlertTriangle, CheckCircle2,
} from 'lucide-react';
import { useNav } from './nav';

/* ============================== DATA ============================== */

export type SessionExercise = {
  name: string;
  sets: number;
  reps: string;
  weight?: number;
};

type RoutineDay = { focus: string; tag: string; exercises: SessionExercise[] };

const WEEK: Record<number, RoutineDay> = {
  1: {
    focus: 'Día de pierna',
    tag: 'Fuerza · Tren inferior',
    exercises: [
      { name: 'Sentadilla trasera', sets: 4, reps: '6-8', weight: 90 },
      { name: 'Prensa 45°', sets: 4, reps: '10-12', weight: 160 },
      { name: 'Peso muerto rumano', sets: 3, reps: '8-10', weight: 70 },
      { name: 'Extensión de cuádriceps', sets: 3, reps: '12-15', weight: 45 },
      { name: 'Elevación de gemelos', sets: 4, reps: '15-20', weight: 60 },
    ],
  },
  2: {
    focus: 'Día de empuje',
    tag: 'Hipertrofia · Pecho, hombro, tríceps',
    exercises: [
      { name: 'Press banca', sets: 4, reps: '6-8', weight: 70 },
      { name: 'Press inclinado mancuernas', sets: 4, reps: '8-10', weight: 24 },
      { name: 'Press militar', sets: 3, reps: '8-10', weight: 40 },
      { name: 'Elevaciones laterales', sets: 4, reps: '12-15', weight: 10 },
      { name: 'Fondos en paralelas', sets: 3, reps: 'AMRAP' },
    ],
  },
  3: {
    focus: 'Día de tirón',
    tag: 'Hipertrofia · Espalda y bíceps',
    exercises: [
      { name: 'Dominadas lastradas', sets: 4, reps: '6-8', weight: 10 },
      { name: 'Remo con barra', sets: 4, reps: '8-10', weight: 60 },
      { name: 'Jalón al pecho', sets: 3, reps: '10-12', weight: 55 },
      { name: 'Curl con barra Z', sets: 3, reps: '10-12', weight: 25 },
      { name: 'Face pull', sets: 3, reps: '15' },
    ],
  },
  4: {
    focus: 'Día de cardio + core',
    tag: 'Resistencia · Zona 2',
    exercises: [
      { name: 'Cinta zona 2', sets: 1, reps: '30 min' },
      { name: 'Plancha frontal', sets: 3, reps: '60 s' },
      { name: 'Rueda abdominal', sets: 3, reps: '10-12' },
      { name: 'Elevación de piernas', sets: 3, reps: '12-15' },
    ],
  },
  5: {
    focus: 'Día de pierna',
    tag: 'Fuerza · Tren inferior',
    exercises: [
      { name: 'Peso muerto convencional', sets: 4, reps: '4-6', weight: 120 },
      { name: 'Zancadas búlgaras', sets: 3, reps: '10 / pierna', weight: 20 },
      { name: 'Curl femoral', sets: 4, reps: '12-15', weight: 40 },
      { name: 'Hip thrust', sets: 3, reps: '10-12', weight: 90 },
    ],
  },
  6: {
    focus: 'Día full body',
    tag: 'Mixto · Cuerpo completo',
    exercises: [
      { name: 'Kettlebell swing', sets: 4, reps: '15', weight: 24 },
      { name: 'Remo con mancuerna', sets: 3, reps: '10-12', weight: 28 },
      { name: 'Press militar mancuernas', sets: 3, reps: '10', weight: 18 },
      { name: 'Sentadilla goblet', sets: 3, reps: '12', weight: 30 },
    ],
  },
  0: {
    focus: 'Día de movilidad',
    tag: 'Recuperación activa',
    exercises: [
      { name: 'Movilidad de cadera', sets: 2, reps: '8 min' },
      { name: 'Movilidad torácica', sets: 2, reps: '6 min' },
      { name: 'Caminata suave', sets: 1, reps: '25 min' },
    ],
  },
};

const DAY_NAMES = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

export function getTodayRoutine() {
  const d = new Date();
  const day = WEEK[d.getDay()]!;
  return { dayName: DAY_NAMES[d.getDay()]!, ...day };
}

/* ============================== INTENSITY ============================== */

const HR_MAX = 190;

type Band = { label: string; hint: string; color: string; bg: string; text: string };

function bandFor(pct: number): Band {
  if (pct < 60)
    return { label: 'Ligero', hint: 'Muy lejos del fallo · puedes subir carga', color: '#378ADD', bg: 'bg-sky-50', text: 'text-sky-700' };
  if (pct < 72)
    return { label: 'Moderado', hint: 'Trabajo cómodo · 4+ reps en reserva', color: '#22C55E', bg: 'bg-emerald-50', text: 'text-emerald-700' };
  if (pct < 82)
    return { label: 'Intenso', hint: 'Estímulo óptimo · 2-3 reps en reserva', color: '#F5C84B', bg: 'bg-amber-50', text: 'text-amber-700' };
  if (pct < 91)
    return { label: 'Cerca del fallo', hint: '1-2 reps en reserva · mantén la técnica', color: '#F08A3D', bg: 'bg-orange-50', text: 'text-orange-700' };
  return { label: 'Fallo muscular', hint: 'Sin reps en reserva · descansa más', color: '#E0473A', bg: 'bg-red-50', text: 'text-red-700' };
}

/* ============================== SCREEN ============================== */

export function SessionScreen() {
  const { goBack } = useNav();
  const routine = useMemo(getTodayRoutine, []);

  const [running, setRunning] = useState(true);
  const [seconds, setSeconds] = useState(0);
  const [hr, setHr] = useState(118);
  const [history, setHistory] = useState<number[]>(() => Array.from({ length: 60 }, () => 118));
  const [current, setCurrent] = useState(0);
  const [done, setDone] = useState<boolean[]>(() => routine.exercises.map(() => false));

  /* clock */
  useEffect(() => {
    if (!running) return;
    const t = setInterval(() => setSeconds((s) => s + 1), 1000);
    return () => clearInterval(t);
  }, [running]);

  /* simulated heart rate */
  useEffect(() => {
    const t = setInterval(() => {
      setHr((prev) => {
        const target = running ? 150 + Math.sin(Date.now() / 9000) * 22 : 105;
        const next = prev + (target - prev) * 0.12 + (Math.random() - 0.5) * 4;
        const v = Math.round(Math.min(188, Math.max(90, next)));
        setHistory((h) => [...h.slice(1), v]);
        return v;
      });
    }, 1000);
    return () => clearInterval(t);
  }, [running]);

  const pct = Math.round((hr / HR_MAX) * 100);
  const band = bandFor(pct);
  const completed = done.filter(Boolean).length;
  const total = routine.exercises.length;
  const finished = completed === total;

  const completeExercise = (i: number) => {
    setDone((d) => {
      const next = [...d];
      next[i] = !next[i];
      return next;
    });
    setCurrent((c) => (i === c && c < total - 1 ? c + 1 : c));
  };

  const mm = String(Math.floor(seconds / 60)).padStart(2, '0');
  const ss = String(seconds % 60).padStart(2, '0');

  return (
    <div className="min-h-screen w-full bg-surface-2">
      <div className="mx-auto w-full max-w-[440px] bg-background px-5 pb-32 pt-6">
        <div className="flex items-center gap-3">
          <button
            onClick={goBack}
            aria-label="Volver"
            className="grid h-9 w-9 place-items-center rounded-full bg-surface-1 ring-1 ring-border transition active:scale-95"
          >
            <ArrowLeft className="h-4 w-4" strokeWidth={2.25} />
          </button>
          <div className="min-w-0">
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
              {routine.dayName} · sesión en vivo
            </p>
            <h1 className="truncate text-[19px] font-bold tracking-tight text-foreground">
              {routine.focus}
            </h1>
          </div>
          <span
            className={`ml-auto shrink-0 rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider ${running ? 'bg-emerald-50 text-emerald-700' : 'bg-surface-1 text-muted-foreground'}`}
          >
            {running ? 'En curso' : 'En pausa'}
          </span>
        </div>

        {/* timer + quick stats */}
        <section className="mt-5 rounded-[28px] bg-card p-5 shadow-card">
          <div className="flex items-end justify-between">
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
                Tiempo de sesión
              </p>
              <p className="mt-1 text-[44px] font-bold leading-none tabular-nums tracking-tight text-foreground">
                {mm}:{ss}
              </p>
            </div>
            <div className="text-right">
              <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
                Progreso
              </p>
              <p className="mt-1 text-[18px] font-bold tabular-nums text-foreground">
                {completed}/{total}
              </p>
            </div>
          </div>

          <div className="mt-4 h-2 w-full overflow-hidden rounded-full bg-surface-1">
            <div
              className="h-full rounded-full bg-ai-gradient transition-all duration-500"
              style={{ width: `${(completed / total) * 100}%` }}
            />
          </div>

          <div className="mt-4 grid grid-cols-3 gap-2">
            <MiniStat icon={Heart} label="FC" value={`${hr}`} unit="bpm" />
            <MiniStat icon={Flame} label="Kcal" value={`${Math.round(seconds * 0.13 + completed * 22)}`} unit="" />
            <MiniStat icon={Clock} label="Descanso" value={running ? '90' : '—'} unit="s" />
          </div>

          <div className="mt-4 grid grid-cols-[1fr_auto] gap-2">
            <button
              onClick={() => setRunning((r) => !r)}
              className="inline-flex items-center justify-center gap-2 rounded-2xl bg-ai-gradient px-5 py-3.5 text-[15px] font-semibold text-white shadow-card transition active:scale-[0.99]"
            >
              {running ? <Pause className="h-4 w-4" strokeWidth={2.5} /> : <Play className="h-4 w-4 fill-current" strokeWidth={0} />}
              {running ? 'Pausar sesión' : 'Reanudar sesión'}
            </button>
            <button
              onClick={() => {
                setSeconds(0);
                setDone(routine.exercises.map(() => false));
                setCurrent(0);
                setRunning(true);
              }}
              aria-label="Reiniciar"
              className="grid h-full w-14 place-items-center rounded-2xl bg-surface-1 text-muted-foreground ring-1 ring-border transition active:scale-95"
            >
              <RotateCcw className="h-4 w-4" strokeWidth={2.25} />
            </button>
          </div>
        </section>

        {/* heart rate + intensity */}
        <section className="mt-4 rounded-[28px] bg-card p-5 shadow-card">
          <div className="flex items-center justify-between">
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
              Ritmo cardíaco en vivo
            </p>
            <span className={`rounded-full px-2.5 py-1 text-[10px] font-bold ${band.bg} ${band.text}`}>
              {band.label}
            </span>
          </div>

          <div className="mt-2 flex items-baseline gap-2">
            <span className="text-[38px] font-bold leading-none tabular-nums tracking-tight text-foreground">{hr}</span>
            <span className="text-[13px] text-muted-foreground">bpm · {pct}% FC máx.</span>
          </div>

          <HrLive data={history} color={band.color} />

          <IntensityScale pct={pct} />

          <div className={`mt-4 flex items-start gap-2.5 rounded-2xl px-3.5 py-3 ${band.bg}`}>
            {pct >= 91 ? (
              <AlertTriangle className={`mt-0.5 h-4 w-4 shrink-0 ${band.text}`} strokeWidth={2.25} />
            ) : (
              <CheckCircle2 className={`mt-0.5 h-4 w-4 shrink-0 ${band.text}`} strokeWidth={2.25} />
            )}
            <p className={`text-[12.5px] font-medium leading-snug ${band.text}`}>{band.hint}</p>
          </div>
        </section>

        {/* exercises */}
        <section className="mt-4 rounded-[28px] bg-card p-5 shadow-card">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Ejercicios · {routine.tag}
          </p>

          <div className="mt-3 space-y-2">
            {routine.exercises.map((ex, i) => {
              const isDone = done[i];
              const isCurrent = i === current && !isDone;
              return (
                <div
                  key={ex.name}
                  className={`rounded-2xl p-3.5 transition ${
                    isCurrent ? 'bg-ai-soft ring-1 ring-border' : 'bg-surface-1'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={`grid h-9 w-9 shrink-0 place-items-center rounded-xl ${
                        isDone ? 'bg-emerald-100 text-emerald-600' : 'bg-card text-foreground/70 shadow-soft'
                      }`}
                    >
                      {isDone ? <Check className="h-4 w-4" strokeWidth={2.75} /> : <Dumbbell className="h-4 w-4" strokeWidth={2.25} />}
                    </div>
                    <div className="min-w-0 flex-1 leading-tight">
                      <p className={`truncate text-[14px] font-semibold ${isDone ? 'text-muted-foreground line-through' : 'text-foreground'}`}>
                        {ex.name}
                      </p>
                      <p className="truncate text-[11.5px] text-muted-foreground">
                        {ex.sets} × {ex.reps}
                        {ex.weight ? ` · ${ex.weight} kg` : ''}
                      </p>
                    </div>
                    {isCurrent && (
                      <span className="shrink-0 rounded-full bg-card px-2 py-1 text-[10px] font-bold uppercase tracking-wider text-foreground shadow-soft">
                        Actual
                      </span>
                    )}
                  </div>

                  <div className="mt-3 grid grid-cols-[1fr_auto] gap-2">
                    <button
                      onClick={() => completeExercise(i)}
                      className={`inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-[13px] font-semibold transition active:scale-[0.99] ${
                        isDone
                          ? 'bg-card text-muted-foreground shadow-soft'
                          : 'bg-foreground text-background'
                      }`}
                    >
                      <Check className="h-3.5 w-3.5" strokeWidth={2.75} />
                      {isDone ? 'Marcar pendiente' : 'Completar ejercicio'}
                    </button>
                    <button
                      onClick={() => setCurrent(i)}
                      aria-label="Ir a este ejercicio"
                      className="grid w-11 place-items-center rounded-xl bg-card text-muted-foreground shadow-soft transition active:scale-95"
                    >
                      <ChevronRight className="h-4 w-4" strokeWidth={2.25} />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </section>

        <button
          onClick={goBack}
          disabled={!finished}
          className={`mt-4 inline-flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-[15px] font-semibold transition active:scale-[0.99] ${
            finished ? 'bg-ai-gradient text-white shadow-card' : 'bg-surface-1 text-muted-foreground'
          }`}
        >
          <CheckCircle2 className="h-4 w-4" strokeWidth={2.25} />
          {finished ? 'Finalizar entrenamiento' : `Faltan ${total - completed} ejercicios`}
        </button>
      </div>
    </div>
  );
}

function MiniStat({
  icon: Icon, label, value, unit,
}: { icon: typeof Heart; label: string; value: string; unit: string }) {
  return (
    <div className="rounded-2xl bg-surface-1 p-3">
      <div className="flex items-center gap-1.5 text-muted-foreground">
        <Icon className="h-3 w-3" strokeWidth={2.25} />
        <span className="text-[10px] font-semibold uppercase tracking-wider">{label}</span>
      </div>
      <p className="mt-1 flex items-baseline gap-1">
        <span className="text-[18px] font-bold tabular-nums tracking-tight text-foreground">{value}</span>
        <span className="text-[10px] text-muted-foreground">{unit}</span>
      </p>
    </div>
  );
}

function HrLive({ data, color }: { data: number[]; color: string }) {
  const ref = useRef<HTMLDivElement>(null);
  const w = 320;
  const h = 110;
  const min = 85;
  const max = 195;
  const x = (i: number) => (i / (data.length - 1)) * w;
  const y = (v: number) => h - ((v - min) / (max - min)) * h;
  const line = data.map((v, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const area = `${line} L${w},${h} L0,${h} Z`;

  return (
    <div ref={ref} className="mt-3">
      <svg viewBox={`0 0 ${w} ${h}`} className="h-28 w-full">
        <defs>
          <linearGradient id="hrLiveFill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.28" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        {[60, 72, 82, 91].map((p) => {
          const v = (p / 100) * HR_MAX;
          return (
            <line
              key={p}
              x1="0" x2={w} y1={y(v)} y2={y(v)}
              stroke="currentColor" className="text-border"
              strokeWidth="1" strokeDasharray="3 5"
            />
          );
        })}
        <path d={area} fill="url(#hrLiveFill)" />
        <path d={line} fill="none" stroke={color} strokeWidth="2.5" strokeLinejoin="round" strokeLinecap="round" />
        <circle cx={x(data.length - 1)} cy={y(data[data.length - 1]!)} r="4" fill={color} />
      </svg>
    </div>
  );
}

function IntensityScale({ pct }: { pct: number }) {
  const segments = [
    { label: 'Ligero', color: '#378ADD', to: 60 },
    { label: 'Moderado', color: '#22C55E', to: 72 },
    { label: 'Intenso', color: '#F5C84B', to: 82 },
    { label: 'Cerca fallo', color: '#F08A3D', to: 91 },
    { label: 'Fallo', color: '#E0473A', to: 100 },
  ];
  const clamped = Math.min(100, Math.max(45, pct));
  const posPct = ((clamped - 45) / 55) * 100;

  return (
    <div className="mt-4">
      <div className="relative">
        <div className="flex h-3 w-full overflow-hidden rounded-full">
          {segments.map((s, i) => {
            const from = i === 0 ? 45 : segments[i - 1]!.to;
            return (
              <div key={s.label} style={{ width: `${((s.to - from) / 55) * 100}%`, background: s.color }} />
            );
          })}
        </div>
        <div
          className="absolute -top-1 h-5 w-[3px] rounded-full bg-foreground shadow-soft transition-all duration-500"
          style={{ left: `calc(${posPct}% - 1.5px)` }}
        />
      </div>
      <div className="mt-2 flex justify-between text-[9.5px] font-semibold uppercase tracking-wide text-muted-foreground">
        {segments.map((s) => (
          <span key={s.label}>{s.label}</span>
        ))}
      </div>
    </div>
  );
}
