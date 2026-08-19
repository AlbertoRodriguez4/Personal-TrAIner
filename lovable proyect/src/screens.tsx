import { useRef, useState } from 'react';
import {
  Sparkles, Play, Home, Dumbbell, Apple, Activity, ChevronRight,
  Heart, Camera, ScanLine, FileText, Upload, AlertTriangle,
  Image as ImageIcon, TrendingDown, TrendingUp, CircleUser,
  Zap, Plus,
  Droplets, Pill, Minus, X, Check, MessageSquare, Moon, LineChart,
} from 'lucide-react';
import { useNav, type TabKey } from './nav';

/* ============================== SHARED ============================== */

function BrandName({ className = '' }: { className?: string }) {
  return (
    <span className={`font-display font-bold tracking-tight ${className}`}>
      Personal Tr<span className="text-ai-gradient font-extrabold italic">AI</span>ner
    </span>
  );
}

function Header() {
  return (
    <header className="sticky top-0 z-20 glass">
      <div className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 px-5 pb-3 pt-5">
        <div className="min-w-0">
          <p className="text-[11px] font-medium uppercase tracking-[0.14em] text-muted-foreground">
            Jueves · 25 jun
          </p>
          <div className="flex items-center gap-2">
            <div className="grid h-7 w-7 place-items-center rounded-lg bg-ai-gradient text-white text-[11px] font-bold">
              PT
            </div>
            <BrandName className="block truncate text-[22px] leading-tight" />
          </div>
        </div>
        <LiveSync />
      </div>
    </header>
  );
}

function LiveSync() {
  return (
    <div className="flex shrink-0 items-center gap-2 rounded-full bg-surface-1 px-3 py-1.5 ring-1 ring-border">
      <span className="relative grid h-4 w-4 place-items-center">
        <span className="absolute h-2 w-2 rounded-full bg-emerald-500 animate-ai-pulse" />
        <span className="absolute h-2 w-2 rounded-full bg-emerald-500/40 animate-ai-ring" />
      </span>
      <Heart className="h-3.5 w-3.5 text-foreground/70" strokeWidth={2.25} />
      <span className="text-[12px] font-semibold tabular-nums text-foreground">
        64<span className="ml-0.5 text-[10px] font-medium text-muted-foreground">bpm</span>
      </span>
    </div>
  );
}

function SectionLink({
  to, icon: Icon, title, sub,
}: { to: Parameters<ReturnType<typeof useNav>['navigate']>[0]; icon: typeof Home; title: string; sub: string }) {
  const { navigate } = useNav();
  return (
    <button
      onClick={() => navigate(to)}
      className="group flex items-center gap-3 rounded-2xl bg-card p-3.5 shadow-soft transition active:scale-[0.98] text-left"
    >
      <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-ai-gradient text-white">
        <Icon className="h-4 w-4" strokeWidth={2.25} />
      </div>
      <div className="min-w-0 leading-tight">
        <p className="truncate text-[13px] font-semibold text-foreground">{title}</p>
        <p className="truncate text-[11px] text-muted-foreground">{sub}</p>
      </div>
      <ChevronRight className="ml-auto h-4 w-4 text-muted-foreground transition group-hover:translate-x-0.5" />
    </button>
  );
}

/* ============================== INICIO ============================== */

export function HomeScreen() {
  return (
    <>
      <AICoachCTA />
      <PredictiveAlert />
      <NewSectionsRow />
      <QuickActions />
      <DailySummary />
      <HydrationMini />
      <XiaomiLastWorkout />
      <WorkoutCard />
    </>
  );
}

function NewSectionsRow() {
  const items = [
    { to: { name: 'routine-builder' as const }, icon: Dumbbell, title: 'Rutinas', sub: 'Constructor rápido' },
  ];
  return (
    <section aria-label="Accesos avanzados" className="grid grid-cols-1 gap-3">
      {items.map(({ to, icon, title, sub }) => (
        <SectionLink key={title} to={to} icon={icon} title={title} sub={sub} />
      ))}
    </section>
  );
}

function AICoachCTA() {
  const { navigate } = useNav();
  const modules = [
    { icon: Dumbbell, label: 'Crear rutina' },
    { icon: Moon, label: 'Sueño' },
    { icon: Apple, label: 'Nutrición' },
    { icon: LineChart, label: 'Progreso' },
  ];
  return (
    <section
      aria-label="Pulso, tu entrenador IA"
      className="bg-ai-gradient relative overflow-hidden rounded-[34px] p-5 text-white shadow-card"
    >
      <span
        aria-hidden
        className="pointer-events-none absolute -right-10 -top-14 h-44 w-44 rounded-full bg-white/20 blur-2xl"
      />
      <span
        aria-hidden
        className="pointer-events-none absolute -bottom-16 -left-10 h-40 w-40 rounded-full bg-white/10 blur-2xl"
      />
      <div className="relative">
        <div className="flex items-center justify-between gap-3">
          <div className="flex min-w-0 items-center gap-3">
            <div className="relative grid h-14 w-14 shrink-0 place-items-center rounded-[20px] bg-white/20 backdrop-blur-xl">
              <span aria-hidden className="absolute inset-0 rounded-[20px] bg-white/10 animate-ai-pulse" />
              <Sparkles className="relative h-7 w-7" />
              <span className="absolute -right-0.5 -top-0.5 h-3.5 w-3.5 rounded-full border-2 border-white/80 bg-emerald-400" />
            </div>
            <div className="min-w-0">
              <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-white/75">
                Pulso · AI Coach
              </p>
              <p className="text-[24px] font-bold leading-tight tracking-tight">
                Tu entrenador IA
              </p>
            </div>
          </div>
          <span className="shrink-0 rounded-full bg-white/20 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wide backdrop-blur-xl">
            En línea
          </span>
        </div>

        <p className="mt-3 text-[13px] leading-snug text-white/85">
          Crea y edita rutinas, interpreta tu sueño y ajusta tus macros. Pulso lee tus datos reales y actúa por ti.
        </p>

        <div className="mt-4 grid grid-cols-4 gap-2">
          {modules.map(({ icon: Icon, label }) => (
            <button
              key={label}
              onClick={() => navigate({ name: 'chat' })}
              className="flex flex-col items-center gap-1.5 rounded-2xl bg-white/15 px-1 py-3 text-center backdrop-blur-xl transition active:scale-95 hover:bg-white/25"
            >
              <Icon className="h-4 w-4" strokeWidth={2.25} />
              <span className="text-[10px] font-semibold leading-tight">{label}</span>
            </button>
          ))}
        </div>

        <button
          onClick={() => navigate({ name: 'chat' })}
          className="mt-3 flex w-full items-center justify-between gap-3 rounded-full bg-white px-4 py-3 text-left shadow-soft transition active:scale-[0.98]"
          aria-label="Abrir chat con Pulso"
        >
          <span className="flex items-center gap-2 text-[14px] font-semibold text-foreground/50">
            <MessageSquare className="h-4 w-4 text-foreground/40" />
            Escribe a Pulso…
          </span>
          <span className="bg-ai-gradient grid h-8 w-8 place-items-center rounded-full text-white">
            <ChevronRight className="h-4 w-4" strokeWidth={2.5} />
          </span>
        </button>
      </div>
    </section>
  );
}

function PredictiveAlert() {
  return (
    <section
      aria-label="Alerta predictiva"
      className="relative overflow-hidden rounded-[28px] bg-warn-soft p-4 shadow-card"
    >
      <div className="flex items-start gap-3">
        <div className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-white/70 text-orange-600 shadow-soft">
          <AlertTriangle className="h-4 w-4" strokeWidth={2.4} />
        </div>
        <div className="min-w-0">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-orange-700/80">
            Alerta · Transformer IA
          </p>
          <p className="mt-1 text-[14px] font-medium leading-snug text-foreground">
            Patrones de <span className="font-semibold">VFC</span> indican fatiga sistémica.
            Carga de hoy <span className="font-semibold">reducida un 20%</span>.
          </p>
        </div>
      </div>
    </section>
  );
}

function QuickActions() {
  const { setTab } = useNav();
  const { navigate } = useNav();
  const items = [
    { icon: Camera, label: 'Escanear', sub: 'Comida', action: () => setTab('nutrition') },
    { icon: ScanLine, label: 'Evaluar', sub: 'Postura', action: () => setTab('health') },
    { icon: FileText, label: 'Subir', sub: 'Analítica', action: () => navigate({ name: 'clinic-import' }) },
  ];
  return (
    <section aria-label="Acciones rápidas" className="grid grid-cols-3 gap-3">
      {items.map(({ icon: Icon, label, sub, action }) => (
        <button
          key={label}
          onClick={action}
          className="group flex flex-col items-start gap-3 rounded-2xl bg-card p-3.5 text-left shadow-soft transition active:scale-[0.97]"
        >
          <div className="grid h-9 w-9 place-items-center rounded-xl bg-ai-soft">
            <Icon className="h-4 w-4 text-foreground" strokeWidth={2.25} />
          </div>
          <div className="leading-tight">
            <p className="text-[13px] font-semibold text-foreground">{label}</p>
            <p className="text-[11px] text-muted-foreground">{sub}</p>
          </div>
        </button>
      ))}
    </section>
  );
}

function DailySummary() {
  return (
    <section aria-label="Resumen diario" className="grid grid-cols-2 gap-3">
      <SummaryRing title="Carga física" value="72" unit="%" sub="óptima" pct={0.72} />
      <SummaryRing title="Macros" value="1.8" unit="k" sub="kcal · 2.4k" pct={0.62} />
    </section>
  );
}

function SummaryRing({
  title, value, unit, sub, pct,
}: { title: string; value: string; unit: string; sub: string; pct: number }) {
  const r = 30;
  const c = 2 * Math.PI * r;
  return (
    <div className="rounded-2xl bg-card p-4 shadow-soft">
      <p className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
        {title}
      </p>
      <div className="mt-2 flex items-center gap-3">
        <div className="relative h-[72px] w-[72px]">
          <svg viewBox="0 0 72 72" className="h-full w-full -rotate-90">
            <circle cx="36" cy="36" r={r} className="fill-none stroke-muted" strokeWidth="6" />
            <circle
              cx="36" cy="36" r={r}
              stroke="url(#aiRing)" strokeWidth="6" strokeLinecap="round" fill="none"
              strokeDasharray={c} strokeDashoffset={c * (1 - pct)}
            />
            <defs>
              <linearGradient id="aiRing" x1="0" y1="0" x2="72" y2="72">
                <stop offset="0%" stopColor="#b054f0" />
                <stop offset="55%" stopColor="#6a5cf0" />
                <stop offset="100%" stopColor="#46b5e8" />
              </linearGradient>
            </defs>
          </svg>
          <div className="absolute inset-0 grid place-items-center">
            <div className="text-center leading-none">
              <span className="text-[16px] font-bold tracking-tight">{value}</span>
              <span className="ml-0.5 text-[10px] text-muted-foreground">{unit}</span>
            </div>
          </div>
        </div>
        <p className="text-[12px] text-muted-foreground">{sub}</p>
      </div>
    </div>
  );
}

function WorkoutCard() {
  const { navigate } = useNav();
  return (
    <section aria-label="Entrenamiento de hoy" className="rounded-[28px] bg-card p-5 shadow-card">
      <div className="flex items-center justify-between">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Día 4 · Hoy
        </p>
        <span className="rounded-full bg-surface-2 px-2.5 py-1 text-[10px] font-semibold text-muted-foreground">
          52 min
        </span>
      </div>

      <h2 className="mt-2 text-[24px] font-bold leading-tight tracking-tight text-foreground">
        Hipertrofia
        <br />
        <span className="text-muted-foreground">Tren Superior</span>
      </h2>

      <div className="mt-4 flex items-center gap-4 text-[12px] text-muted-foreground">
        <span>
          <span className="font-semibold text-foreground">8</span> ejercicios
        </span>
        <span className="h-1 w-1 rounded-full bg-border" />
        <span>
          <span className="font-semibold text-foreground">22</span> series
        </span>
        <span className="h-1 w-1 rounded-full bg-border" />
        <span className="inline-flex items-center gap-1">
          <Sparkles className="h-3 w-3 text-foreground/60" />
          IA
        </span>
      </div>

      <button
        onClick={() => navigate({ name: 'focus' })}
        className="mt-5 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-ai-gradient px-5 py-4 text-[15px] font-semibold text-white shadow-card transition active:scale-[0.99]"
      >
        <Play className="h-4 w-4 fill-current" strokeWidth={0} />
        Iniciar Focus Mode
      </button>
    </section>
  );
}

/* ============================== ENTRENAR ============================== */

export function TrainScreen() {
  return (
    <>
      <WorkoutSummary />
      <XiaomiWorkouts />
      <FocusModeCard />
      <RoutineLinks />
    </>
  );
}

function WorkoutSummary() {
  const metrics = [
    { label: 'Frecuencia cardíaca', value: '142', unit: 'bpm', sub: 'media' },
    { label: 'Duración', value: '52', unit: 'min', sub: 'activo' },
    { label: 'Calorías', value: '384', unit: 'kcal', sub: 'quemadas' },
    { label: 'Volumen', value: '4.2', unit: 't', sub: 'carga total' },
  ];

  const conclusions = [
    { icon: TrendingUp, text: 'Tu rendimiento mejoró un 12% respecto a la semana pasada', positive: true },
    { icon: Heart, text: 'Recuperación cardíaca excelente: 45 bpm en 2 minutos', positive: true },
    { icon: Activity, text: 'Zona cardiovascular óptima durante el 78% del entrenamiento', positive: true },
    { icon: AlertTriangle, text: 'Fatiga detectada en el último series de press militar', positive: false },
  ];

  return (
    <section className="rounded-[28px] bg-card p-5 shadow-card">
      <div className="flex items-center justify-between">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Resumen de hoy
        </p>
        <span className="rounded-full bg-emerald-50 px-2.5 py-1 text-[10px] font-semibold text-emerald-700">
          Completado
        </span>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-3">
        {metrics.map(({ label, value, unit, sub }) => (
          <div key={label} className="rounded-2xl bg-surface-1 p-3">
            <p className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
              {label}
            </p>
            <div className="mt-1 flex items-baseline gap-1">
              <span className="text-[22px] font-bold tracking-tight text-foreground">{value}</span>
              <span className="text-[11px] text-muted-foreground">{unit}</span>
            </div>
            <p className="text-[10px] text-muted-foreground">{sub}</p>
          </div>
        ))}
      </div>

      <div className="mt-5">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Conclusiones IA
        </p>
        <div className="mt-3 space-y-2">
          {conclusions.map(({ icon: Icon, text, positive }, i) => (
            <div
              key={i}
              className="flex items-start gap-2.5 rounded-xl bg-surface-1 px-3 py-2.5"
            >
              <div
                className={`grid h-5 w-5 shrink-0 place-items-center rounded-full ${
                  positive ? 'bg-emerald-100 text-emerald-600' : 'bg-orange-100 text-orange-600'
                }`}
              >
                <Icon className="h-3 w-3" strokeWidth={2.25} />
              </div>
              <p className="text-[13px] leading-snug text-foreground">{text}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function FocusModeCard() {
  const { navigate } = useNav();
  return (
    <section className="rounded-[28px] bg-card p-5 shadow-card">
      <div className="flex items-center justify-between">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Modo Focus · Ejercicio 3 / 8
        </p>
        <span className="rounded-full bg-ai-soft px-2.5 py-1 text-[10px] font-semibold text-foreground">
          Edge AI
        </span>
      </div>
      <h3 className="mt-2 text-[22px] font-bold leading-tight tracking-tight">
        Press Inclinado
        <span className="ml-2 text-muted-foreground">· Mancuernas</span>
      </h3>
      <div className="mt-3 flex items-center gap-5 text-[13px] text-muted-foreground">
        <span><span className="text-[18px] font-bold text-foreground">4</span> series</span>
        <span><span className="text-[18px] font-bold text-foreground">8–10</span> reps</span>
        <span><span className="text-[18px] font-bold text-foreground">22kg</span></span>
      </div>
      <button
        onClick={() => navigate({ name: 'focus' })}
        className="mt-5 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-ai-gradient px-5 py-4 text-[15px] font-semibold text-white shadow-card transition active:scale-[0.99]"
      >
        <Camera className="h-4 w-4" strokeWidth={2.25} />
        Activar Cámara Edge AI
      </button>
    </section>
  );
}

function RoutineLinks() {
  const { navigate } = useNav();
  return (
    <section className="grid grid-cols-1 gap-3">
      <button
        onClick={() => navigate({ name: 'routine-builder' })}
        className="group flex items-center gap-3 rounded-2xl bg-card p-3.5 shadow-soft transition active:scale-[0.98] text-left"
      >
        <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-ai-gradient text-white">
          <Dumbbell className="h-4 w-4" strokeWidth={2.25} />
        </div>
        <div className="min-w-0 leading-tight">
          <p className="truncate text-[13px] font-semibold text-foreground">Constructor de rutinas</p>
          <p className="truncate text-[11px] text-muted-foreground">Crea tu rutina semanal</p>
        </div>
        <ChevronRight className="ml-auto h-4 w-4 text-muted-foreground transition group-hover:translate-x-0.5" />
      </button>
      <button
        onClick={() => navigate({ name: 'routine-quick-add', activity: 'gym', day: 'Lunes' })}
        className="group flex items-center gap-3 rounded-2xl bg-card p-3.5 shadow-soft transition active:scale-[0.98] text-left"
      >
        <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-ai-soft text-foreground">
          <Zap className="h-4 w-4" strokeWidth={2.25} />
        </div>
        <div className="min-w-0 leading-tight">
          <p className="truncate text-[13px] font-semibold text-foreground">Añadir ejercicios rápido</p>
          <p className="truncate text-[11px] text-muted-foreground">Catálogo con autocompletado</p>
        </div>
        <ChevronRight className="ml-auto h-4 w-4 text-muted-foreground transition group-hover:translate-x-0.5" />
      </button>
    </section>
  );
}

/* ============================== NUTRICIÓN ============================== */

const MACROS_DATA = [
  { key: 'kcal', label: 'Calorías', consumed: 1820, goal: 2400, unit: 'kcal', color: '#6a5cf0' },
  { key: 'protein', label: 'Proteína', consumed: 92, goal: 160, unit: 'g', color: '#b054f0' },
  { key: 'carbs', label: 'Carbohidratos', consumed: 178, goal: 260, unit: 'g', color: '#46b5e8' },
  { key: 'fat', label: 'Grasas', consumed: 48, goal: 75, unit: 'g', color: '#d97706' },
];

export function NutritionScreen() {
  const { setTab } = useNav();
  return (
    <>
      <MacrosOverview />
      <HydrationCard />
      <SupplementsCard />
      <CameraViewer />
      <ScanResultCard />
      <button
        onClick={() => setTab('progress')}
        className="flex w-full items-center justify-center gap-2 rounded-2xl bg-card p-4 text-[14px] font-semibold text-foreground shadow-soft transition active:scale-[0.99]"
      >
        <TrendingUp className="h-4 w-4" strokeWidth={2.25} />
        Ver calendario de nutrición completo
        <ChevronRight className="h-4 w-4 text-muted-foreground" />
      </button>
    </>
  );
}

function MacrosOverview() {
  return (
    <section aria-label="Macronutrientes diarios" className="space-y-3">
      <div className="rounded-[28px] bg-card p-5 shadow-card">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
              Hoy · Jueves 25 jun
            </p>
            <h2 className="mt-1 text-[22px] font-bold tracking-tight">
              Tus macros
            </h2>
          </div>
          <KcalDial consumed={MACROS_DATA[0].consumed} goal={MACROS_DATA[0].goal} />
        </div>
        <div className="mt-5 space-y-3">
          {MACROS_DATA.slice(1).map(({ key, ...m }) => (
            <MacroRow key={key} {...m} />
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------- AGUA Y SUPLEMENTOS ------------------- */

type Supplement = { id: string; name: string; dose: string; taken: boolean };

const GLASS_ML = 250;
const WATER_GOAL_ML = 2500;

function readStore<T>(key: string, fallback: T): T {
  if (typeof window === 'undefined') return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

function useWater() {
  const [ml, setMl] = useState<number>(() => readStore('pt-water-ml', 1000));
  const update = (next: number) => {
    const clamped = Math.max(0, Math.min(next, WATER_GOAL_ML * 2));
    setMl(clamped);
    try {
      window.localStorage.setItem('pt-water-ml', JSON.stringify(clamped));
    } catch { /* almacenamiento no disponible */ }
  };
  return { ml, update };
}

const DEFAULT_SUPPLEMENTS: Supplement[] = [
  { id: 's1', name: 'Creatina monohidrato', dose: '5 g', taken: true },
  { id: 's2', name: 'Vitamina D3', dose: '2000 UI', taken: false },
  { id: 's3', name: 'Omega 3', dose: '1 cápsula', taken: false },
];

function useSupplements() {
  const [items, setItems] = useState<Supplement[]>(() =>
    readStore('pt-supplements', DEFAULT_SUPPLEMENTS),
  );
  const persist = (next: Supplement[]) => {
    setItems(next);
    try {
      window.localStorage.setItem('pt-supplements', JSON.stringify(next));
    } catch { /* almacenamiento no disponible */ }
  };
  return { items, persist };
}

function HydrationCard() {
  const { ml, update } = useWater();
  const pct = Math.min(ml / WATER_GOAL_ML, 1);
  const glasses = Math.round(WATER_GOAL_ML / GLASS_ML);
  const filled = Math.round(ml / GLASS_ML);
  return (
    <section aria-label="Hidratación" className="rounded-[28px] bg-card p-5 shadow-card">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Hidratación
          </p>
          <div className="mt-1 flex items-baseline gap-1">
            <span className="text-[28px] font-bold tracking-tight">{(ml / 1000).toFixed(2)}</span>
            <span className="text-[13px] text-muted-foreground">/ {(WATER_GOAL_ML / 1000).toFixed(1)} L</span>
          </div>
          <p className="text-[12px] text-muted-foreground">
            Faltan {Math.max(WATER_GOAL_ML - ml, 0)} ml · vaso de {GLASS_ML} ml
          </p>
        </div>
        <div className="grid h-11 w-11 place-items-center rounded-2xl bg-sky-50 text-sky-600">
          <Droplets className="h-5 w-5" strokeWidth={2.25} />
        </div>
      </div>

      <div className="mt-4 h-2.5 w-full overflow-hidden rounded-full bg-muted">
        <div
          className="h-full rounded-full bg-[linear-gradient(90deg,#46b5e8,#6a5cf0)] transition-all"
          style={{ width: `${pct * 100}%` }}
        />
      </div>

      <div className="mt-4 flex flex-wrap gap-1.5">
        {Array.from({ length: glasses }).map((_, i) => (
          <button
            key={i}
            aria-label={`Marcar ${i + 1} vasos`}
            onClick={() => update((i + 1) * GLASS_ML)}
            className={`h-8 w-6 rounded-md ring-1 transition active:scale-95 ${
              i < filled ? 'bg-sky-400/80 ring-sky-500/40' : 'bg-surface-1 ring-border'
            }`}
          />
        ))}
      </div>

      <div className="mt-4 flex items-center gap-2">
        <button
          onClick={() => update(ml - GLASS_ML)}
          className="grid h-10 w-10 place-items-center rounded-full bg-surface-1 text-foreground ring-1 ring-border transition active:scale-95"
          aria-label="Quitar vaso"
        >
          <Minus className="h-4 w-4" />
        </button>
        <button
          onClick={() => update(ml + GLASS_ML)}
          className="flex flex-1 items-center justify-center gap-2 rounded-full bg-ai-gradient px-4 py-3 text-[14px] font-semibold text-white shadow-soft transition active:scale-[0.99]"
        >
          <Plus className="h-4 w-4" strokeWidth={2.5} />
          Añadir vaso
        </button>
        <button
          onClick={() => update(ml + 500)}
          className="rounded-full bg-surface-1 px-4 py-3 text-[13px] font-semibold text-foreground ring-1 ring-border transition active:scale-95"
        >
          +500 ml
        </button>
      </div>
    </section>
  );
}

function SupplementsCard() {
  const { items, persist } = useSupplements();
  const [adding, setAdding] = useState(false);
  const [name, setName] = useState('');
  const [dose, setDose] = useState('');
  const done = items.filter((s) => s.taken).length;

  const add = () => {
    const n = name.trim();
    if (!n) return;
    persist([...items, { id: `s${Date.now()}`, name: n, dose: dose.trim() || '1 dosis', taken: false }]);
    setName('');
    setDose('');
    setAdding(false);
  };

  return (
    <section aria-label="Suplementos" className="rounded-[28px] bg-card p-5 shadow-card">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Suplementos de hoy
          </p>
          <h2 className="mt-1 text-[20px] font-bold tracking-tight">
            {done}/{items.length} tomados
          </h2>
        </div>
        <div className="grid h-11 w-11 place-items-center rounded-2xl bg-ai-soft text-foreground">
          <Pill className="h-5 w-5" strokeWidth={2.25} />
        </div>
      </div>

      <div className="mt-4 space-y-2">
        {items.map((s) => (
          <div key={s.id} className="flex items-center gap-3 rounded-2xl bg-surface-1 px-3 py-2.5">
            <button
              onClick={() =>
                persist(items.map((it) => (it.id === s.id ? { ...it, taken: !it.taken } : it)))
              }
              aria-label={s.taken ? `Desmarcar ${s.name}` : `Marcar ${s.name}`}
              className={`grid h-7 w-7 shrink-0 place-items-center rounded-full transition active:scale-95 ${
                s.taken ? 'bg-ai-gradient text-white' : 'bg-card text-muted-foreground ring-1 ring-border'
              }`}
            >
              <Check className="h-3.5 w-3.5" strokeWidth={3} />
            </button>
            <div className="min-w-0 flex-1 leading-tight">
              <p className={`truncate text-[14px] font-semibold ${s.taken ? 'text-muted-foreground line-through' : 'text-foreground'}`}>
                {s.name}
              </p>
              <p className="text-[11px] text-muted-foreground">{s.dose}</p>
            </div>
            <button
              onClick={() => persist(items.filter((it) => it.id !== s.id))}
              aria-label={`Eliminar ${s.name}`}
              className="grid h-7 w-7 place-items-center rounded-full text-muted-foreground transition hover:bg-card active:scale-95"
            >
              <X className="h-3.5 w-3.5" />
            </button>
          </div>
        ))}
        {items.length === 0 && (
          <p className="rounded-2xl bg-surface-1 px-3 py-4 text-center text-[13px] text-muted-foreground">
            Aún no has añadido suplementos.
          </p>
        )}
      </div>

      {adding ? (
        <div className="mt-3 space-y-2 rounded-2xl bg-surface-1 p-3">
          <input
            autoFocus
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Nombre (ej. Creatina)"
            className="w-full rounded-xl bg-card px-3 py-2.5 text-[14px] outline-none ring-1 ring-border placeholder:text-muted-foreground"
          />
          <input
            value={dose}
            onChange={(e) => setDose(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && add()}
            placeholder="Dosis (ej. 5 g)"
            className="w-full rounded-xl bg-card px-3 py-2.5 text-[14px] outline-none ring-1 ring-border placeholder:text-muted-foreground"
          />
          <div className="flex gap-2">
            <button
              onClick={add}
              className="flex-1 rounded-full bg-ai-gradient px-4 py-2.5 text-[13px] font-semibold text-white shadow-soft transition active:scale-95"
            >
              Guardar
            </button>
            <button
              onClick={() => setAdding(false)}
              className="rounded-full bg-card px-4 py-2.5 text-[13px] font-semibold text-foreground ring-1 ring-border transition active:scale-95"
            >
              Cancelar
            </button>
          </div>
        </div>
      ) : (
        <button
          onClick={() => setAdding(true)}
          className="mt-3 flex w-full items-center justify-center gap-2 rounded-2xl bg-surface-1 px-4 py-3 text-[14px] font-semibold text-foreground ring-1 ring-border transition active:scale-[0.99]"
        >
          <Plus className="h-4 w-4" strokeWidth={2.5} />
          Añadir suplemento
        </button>
      )}
    </section>
  );
}

function HydrationMini() {
  const { ml, update } = useWater();
  const { items } = useSupplements();
  const { setTab } = useNav();
  const pct = Math.min(ml / WATER_GOAL_ML, 1);
  const done = items.filter((s) => s.taken).length;
  return (
    <section aria-label="Agua y suplementos" className="grid grid-cols-2 gap-3">
      <div className="rounded-2xl bg-card p-4 shadow-soft">
        <div className="flex items-center justify-between">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">Agua</p>
          <Droplets className="h-4 w-4 text-sky-500" strokeWidth={2.25} />
        </div>
        <p className="mt-1.5 text-[20px] font-bold tracking-tight">
          {(ml / 1000).toFixed(2)}
          <span className="ml-1 text-[11px] font-medium text-muted-foreground">/ 2.5 L</span>
        </p>
        <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-muted">
          <div className="h-full rounded-full bg-[linear-gradient(90deg,#46b5e8,#6a5cf0)]" style={{ width: `${pct * 100}%` }} />
        </div>
        <button
          onClick={() => update(ml + GLASS_ML)}
          className="mt-3 flex w-full items-center justify-center gap-1 rounded-full bg-surface-1 py-2 text-[12px] font-semibold text-foreground ring-1 ring-border transition active:scale-95"
        >
          <Plus className="h-3.5 w-3.5" strokeWidth={2.5} /> Vaso
        </button>
      </div>
      <button
        onClick={() => setTab('nutrition')}
        className="rounded-2xl bg-card p-4 text-left shadow-soft transition active:scale-[0.98]"
      >
        <div className="flex items-center justify-between">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">Suplementos</p>
          <Pill className="h-4 w-4 text-foreground/70" strokeWidth={2.25} />
        </div>
        <p className="mt-1.5 text-[20px] font-bold tracking-tight">
          {done}
          <span className="ml-1 text-[11px] font-medium text-muted-foreground">/ {items.length} hoy</span>
        </p>
        <div className="mt-2 space-y-1">
          {items.slice(0, 2).map((s) => (
            <p key={s.id} className="truncate text-[11px] text-muted-foreground">
              {s.taken ? '✓' : '·'} {s.name}
            </p>
          ))}
        </div>
        <span className="mt-3 inline-flex items-center gap-1 text-[12px] font-semibold text-ai-gradient">
          Gestionar <ChevronRight className="h-3.5 w-3.5 text-muted-foreground" />
        </span>
      </button>
    </section>
  );
}

function KcalDial({ consumed, goal }: { consumed: number; goal: number }) {
  const r = 30;
  const c = 2 * Math.PI * r;
  const pct = Math.min(consumed / goal, 1);
  const remaining = Math.max(goal - consumed, 0);
  return (
    <div className="relative h-[88px] w-[88px]">
      <svg viewBox="0 0 72 72" className="h-full w-full -rotate-90">
        <circle cx="36" cy="36" r={r} className="fill-none stroke-muted" strokeWidth="7" />
        <circle
          cx="36" cy="36" r={r}
          stroke="url(#aiRing)" strokeWidth="7" strokeLinecap="round" fill="none"
          strokeDasharray={c} strokeDashoffset={c * (1 - pct)}
        />
      </svg>
      <div className="absolute inset-0 grid place-items-center text-center leading-none">
        <div>
          <p className="text-[15px] font-bold tracking-tight">{remaining}</p>
          <p className="text-[9px] font-medium uppercase tracking-wider text-muted-foreground">restan</p>
        </div>
      </div>
    </div>
  );
}

function MacroRow({
  label, consumed, goal, unit, color,
}: { label: string; consumed: number; goal: number; unit: string; color: string }) {
  const pct = Math.min(consumed / goal, 1);
  const remaining = Math.max(goal - consumed, 0);
  return (
    <div>
      <div className="flex items-baseline justify-between">
        <p className="text-[13px] font-semibold text-foreground">{label}</p>
        <p className="text-[12px] tabular-nums text-muted-foreground">
          <span className="font-semibold text-foreground">{consumed}</span>
          {' / '}{goal}{unit}
          <span className="ml-2 text-[11px] text-muted-foreground">· faltan {remaining}{unit}</span>
        </p>
      </div>
      <div className="mt-1.5 h-2 w-full overflow-hidden rounded-full bg-muted">
        <div className="h-full rounded-full" style={{ width: `${pct * 100}%`, background: color }} />
      </div>
    </div>
  );
}

function CameraViewer() {
  return (
    <section className="relative overflow-hidden rounded-[28px] bg-foreground/95 p-0 shadow-card">
      <div className="relative aspect-[4/5] w-full bg-[radial-gradient(circle_at_50%_40%,oklch(0.3_0.05_260),oklch(0.12_0.02_260))]">
        {[
          'left-5 top-5 border-l-2 border-t-2 rounded-tl-xl',
          'right-5 top-5 border-r-2 border-t-2 rounded-tr-xl',
          'left-5 bottom-5 border-l-2 border-b-2 rounded-bl-xl',
          'right-5 bottom-5 border-r-2 border-b-2 rounded-br-xl',
        ].map((cls, i) => (
          <span key={i} className={`absolute h-10 w-10 border-white/80 ${cls}`} />
        ))}
        <div className="absolute inset-x-0 top-1/2 h-px bg-ai-gradient opacity-80" />
        <div className="absolute inset-0 grid place-items-center text-center">
          <div className="space-y-2">
            <div className="mx-auto grid h-12 w-12 place-items-center rounded-full bg-white/10 backdrop-blur-md">
              <Camera className="h-5 w-5 text-white" strokeWidth={2} />
            </div>
            <p className="text-[15px] font-semibold text-white">Fotografía tu comida</p>
            <p className="text-[12px] text-white/60">Visión MLLM · sin inputs manuales</p>
          </div>
        </div>
        <button className="absolute bottom-5 left-1/2 grid h-14 w-14 -translate-x-1/2 place-items-center rounded-full bg-white ring-4 ring-white/30 transition active:scale-95">
          <span className="h-10 w-10 rounded-full bg-ai-gradient" />
        </button>
      </div>
    </section>
  );
}

function ScanResultCard() {
  return (
    <section className="rounded-[28px] bg-card p-4 shadow-card">
      <div className="flex items-center gap-3">
        <div className="grid h-16 w-16 shrink-0 place-items-center rounded-2xl bg-ai-soft">
          <ImageIcon className="h-5 w-5 text-foreground/70" strokeWidth={2} />
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Escaneo · hace 2 h
          </p>
          <h3 className="truncate text-[16px] font-bold leading-tight">
            Salmón, quinoa y aguacate
          </h3>
          <div className="mt-1 inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-semibold text-emerald-700">
            NOVA 1 · No procesado
          </div>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-3 gap-2">
        <MacroChip label="Proteína" value="38g" pct={0.7} />
        <MacroChip label="Carbos" value="42g" pct={0.5} />
        <MacroChip label="Grasas" value="18g" pct={0.4} />
      </div>
    </section>
  );
}

function MacroChip({ label, value, pct }: { label: string; value: string; pct: number }) {
  return (
    <div className="rounded-2xl bg-surface-1 p-3">
      <p className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
        {label}
      </p>
      <p className="mt-1 text-[15px] font-bold tracking-tight">{value}</p>
      <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-muted">
        <div className="h-full bg-ai-gradient" style={{ width: `${pct * 100}%` }} />
      </div>
    </div>
  );
}

/* ============================== XIAOMI ============================== */

type XiaomiSession = {
  id: string;
  type: string;
  when: string;
  duration: string;
  hrAvg: number;
  hrMax: number;
  kcal: number;
  distance?: string;
};

const XIAOMI_SESSIONS: XiaomiSession[] = [
  { id: '1', type: 'Carrera al aire libre', when: 'Hoy · 07:12', duration: '38 min', hrAvg: 152, hrMax: 174, kcal: 412, distance: '6.4 km' },
  { id: '2', type: 'Fuerza · Tren superior', when: 'Ayer · 19:40', duration: '52 min', hrAvg: 128, hrMax: 162, kcal: 384 },
  { id: '3', type: 'Bicicleta', when: 'Mar · 18:05', duration: '1 h 12', hrAvg: 138, hrMax: 168, kcal: 612, distance: '24.8 km' },
  { id: '4', type: 'Yoga', when: 'Lun · 08:30', duration: '30 min', hrAvg: 92, hrMax: 110, kcal: 128 },
];

function XiaomiBadge() {
  return (
    <span className="inline-flex items-center gap-1 rounded-full bg-foreground/90 px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider text-background">
      <span className="h-1.5 w-1.5 rounded-full bg-orange-400" />
      Xiaomi
    </span>
  );
}

function XiaomiLastWorkout() {
  const s = XIAOMI_SESSIONS[0];
  return (
    <section aria-label="Último entrenamiento Xiaomi" className="rounded-[28px] bg-card p-5 shadow-card">
      <div className="flex items-center justify-between">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Última actividad
        </p>
        <XiaomiBadge />
      </div>
      <h3 className="mt-2 text-[18px] font-bold leading-tight tracking-tight">{s.type}</h3>
      <p className="text-[12px] text-muted-foreground">{s.when}</p>
      <div className="mt-4 grid grid-cols-4 gap-2">
        <MiniStat value={s.duration} label="duración" />
        <MiniStat value={`${s.hrAvg}`} label="bpm med" />
        <MiniStat value={`${s.kcal}`} label="kcal" />
        <MiniStat value={s.distance ?? `${s.hrMax}`} label={s.distance ? 'dist.' : 'bpm máx'} />
      </div>
    </section>
  );
}

function MiniStat({ value, label }: { value: string; label: string }) {
  return (
    <div className="rounded-xl bg-surface-1 px-2 py-2 text-center">
      <p className="text-[13px] font-bold tracking-tight text-foreground">{value}</p>
      <p className="text-[9px] uppercase tracking-wider text-muted-foreground">{label}</p>
    </div>
  );
}

function XiaomiWorkouts() {
  const { navigate } = useNav();
  return (
    <section aria-label="Historial Xiaomi" className="rounded-[28px] bg-card p-5 shadow-card">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Registros · Mi Band
          </p>
          <h3 className="mt-1 text-[18px] font-bold tracking-tight">Entrenamientos Xiaomi</h3>
        </div>
        <XiaomiBadge />
      </div>
      <ul className="mt-4 divide-y divide-border/60">
        {XIAOMI_SESSIONS.map((s) => (
          <li key={s.id}>
            <button
              onClick={() => navigate({ name: 'workout', id: s.id })}
              className="flex w-full items-center gap-3 py-3 transition active:scale-[0.99] text-left"
            >
              <div className="grid h-10 w-10 shrink-0 place-items-center rounded-2xl bg-ai-soft">
                <Heart className="h-4 w-4 text-foreground/70" strokeWidth={2.25} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-[14px] font-semibold leading-tight text-foreground">
                  {s.type}
                </p>
                <p className="text-[11px] text-muted-foreground">
                  {s.when} · {s.duration}
                  {s.distance ? ` · ${s.distance}` : ''}
                </p>
              </div>
              <div className="flex items-center gap-2">
                <div className="text-right leading-tight">
                  <p className="text-[13px] font-bold tabular-nums text-foreground">{s.hrAvg}<span className="text-[10px] font-medium text-muted-foreground">bpm</span></p>
                  <p className="text-[10px] text-muted-foreground">{s.kcal} kcal</p>
                </div>
                <ChevronRight className="h-4 w-4 text-muted-foreground" strokeWidth={2.25} />
              </div>
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}

/* ============================== SALUD ============================== */

export function HealthScreen() {
  return (
    <>
      <ClinicalImporter />
      <CompositionChart />
      <PostureMesh />
      <HealthLinks />
    </>
  );
}

function HealthLinks() {
  const { navigate } = useNav();
  const items = [
    { to: { name: 'recovery' as const }, icon: Heart, title: 'Recuperación', sub: 'Sueño & VFC IA' },
    { to: { name: 'devices' as const }, icon: Activity, title: 'Dispositivos', sub: 'Sync Center' },
  ];
  return (
    <section aria-label="Accesos de salud" className="grid grid-cols-2 gap-3">
      {items.map(({ to, icon: Icon, title, sub }) => (
        <button
          key={title}
          onClick={() => navigate(to)}
          className="group flex items-center gap-3 rounded-2xl bg-card p-3.5 shadow-soft transition active:scale-[0.98] text-left"
        >
          <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-ai-gradient text-white">
            <Icon className="h-4 w-4" strokeWidth={2.25} />
          </div>
          <div className="min-w-0 leading-tight">
            <p className="truncate text-[13px] font-semibold text-foreground">{title}</p>
            <p className="truncate text-[11px] text-muted-foreground">{sub}</p>
          </div>
        </button>
      ))}
    </section>
  );
}

function ClinicalImporter() {
  const { navigate } = useNav();
  return (
    <button
      onClick={() => navigate({ name: 'clinic-import' })}
      className="group block w-full rounded-[28px] border-2 border-dashed border-border bg-card p-6 text-left shadow-soft transition hover:border-foreground/30 active:scale-[0.99]"
    >
      <div className="flex items-center gap-4">
        <div className="grid h-12 w-12 place-items-center rounded-2xl bg-ai-soft">
          <Upload className="h-5 w-5 text-foreground" strokeWidth={2.25} />
        </div>
        <div className="min-w-0">
          <p className="text-[15px] font-bold leading-tight">Importar archivo clínico</p>
          <p className="mt-0.5 text-[12px] text-muted-foreground">
            PDF médico, analítica o <span className="font-semibold">DICOM (DEXA)</span>
          </p>
        </div>
      </div>
    </button>
  );
}

function CompositionChart() {
  const lean = [40, 42, 43, 45, 46, 48, 49];
  const fat = [28, 27, 26, 25, 24, 22, 21];
  const max = 55, min = 15;
  const w = 320, h = 110;
  const path = (arr: number[]) =>
    arr
      .map((v, i) => {
        const x = (i / (arr.length - 1)) * w;
        const y = h - ((v - min) / (max - min)) * h;
        return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join(' ');
  return (
    <section className="rounded-[28px] bg-card p-5 shadow-card">
      <div className="flex items-end justify-between">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Composición · 6 meses
          </p>
          <h3 className="mt-1 text-[18px] font-bold tracking-tight">
            Grasa visceral <span className="text-muted-foreground">vs.</span> masa magra
          </h3>
        </div>
      </div>
      <svg viewBox={`0 0 ${w} ${h}`} className="mt-4 h-28 w-full">
        <defs>
          <linearGradient id="leanG" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#6a5cf0" stopOpacity="0.35" />
            <stop offset="100%" stopColor="#6a5cf0" stopOpacity="0" />
          </linearGradient>
        </defs>
        <path d={`${path(lean)} L${w},${h} L0,${h} Z`} fill="url(#leanG)" />
        <path d={path(lean)} stroke="#6a5cf0" strokeWidth="2.5" fill="none" strokeLinecap="round" />
        <path d={path(fat)} stroke="#d97706" strokeWidth="2.5" fill="none" strokeLinecap="round" strokeDasharray="4 4" />
      </svg>
      <div className="mt-3 flex items-center justify-between text-[12px]">
        <span className="inline-flex items-center gap-2 text-foreground">
          <span className="h-2 w-2 rounded-full bg-ai-gradient" />
          Masa magra
          <TrendingUp className="h-3.5 w-3.5 text-emerald-600" />
        </span>
        <span className="inline-flex items-center gap-2 text-muted-foreground">
          <span className="h-2 w-2 rounded-full bg-orange-400" />
          Grasa visceral
          <TrendingDown className="h-3.5 w-3.5 text-emerald-600" />
        </span>
      </div>
    </section>
  );
}

function PostureMesh() {
  const captures = [
    { id: 'c4', label: 'Hoy', date: '25 jun', tilt: -1, current: true },
    { id: 'c3', label: 'May', date: '10 may', tilt: -3 },
    { id: 'c2', label: 'Mar', date: '02 mar', tilt: -5 },
    { id: 'c1', label: 'Ene', date: '14 ene', tilt: -8, muted: true },
  ];
  const camRef = useRef<HTMLInputElement>(null);
  return (
    <section className="rounded-[28px] bg-card p-5 shadow-card">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Postura 3D · histórico
          </p>
          <h3 className="mt-1 text-[18px] font-bold tracking-tight">Asimetría corregida</h3>
        </div>
        <span className="rounded-full bg-emerald-50 px-2.5 py-1 text-[10px] font-semibold text-emerald-700">
          −38%
        </span>
      </div>
      <div className="mt-4 grid grid-cols-2 gap-3">
        <MeshFigure label="Ene" tilt={-8} muted />
        <MeshFigure label="Hoy" tilt={-1} />
      </div>

      <button
        onClick={() => camRef.current?.click()}
        className="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-ai-gradient px-5 py-3.5 text-[14px] font-semibold text-white shadow-card transition active:scale-[0.99]"
      >
        <Camera className="h-4 w-4" strokeWidth={2.25} />
        Tomar nueva imagen
      </button>
      <input
        ref={camRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="hidden"
      />

      <div className="mt-5">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Calendario de capturas
        </p>
        <ul className="mt-3 space-y-2">
          {captures.map((c) => (
            <li
              key={c.id}
              className="flex items-center gap-3 rounded-2xl bg-surface-1 px-3 py-2.5"
            >
              <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-card text-center leading-none ring-1 ring-border">
                <div>
                  <p className="text-[10px] font-semibold uppercase text-muted-foreground">
                    {c.date.split(' ')[1]}
                  </p>
                  <p className="text-[13px] font-bold text-foreground">
                    {c.date.split(' ')[0]}
                  </p>
                </div>
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-[13px] font-semibold leading-tight">
                  Captura {c.label}
                </p>
                <p className="text-[11px] text-muted-foreground">
                  Inclinación {c.tilt}° · malla 3D
                </p>
              </div>
              {c.current ? (
                <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-semibold text-emerald-700">
                  Actual
                </span>
              ) : (
                <ChevronRight className="h-4 w-4 text-muted-foreground" />
              )}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

function MeshFigure({ label, tilt, muted = false }: { label: string; tilt: number; muted?: boolean }) {
  return (
    <div className="relative aspect-[3/4] overflow-hidden rounded-2xl bg-[radial-gradient(circle_at_50%_30%,oklch(0.97_0.01_260),oklch(0.92_0.02_260))]">
      <div
        className="absolute inset-0 grid place-items-center"
        style={{ transform: `rotate(${tilt}deg)` }}
      >
        <CircleUser
          className={`h-24 w-24 ${muted ? 'text-foreground/30' : 'text-foreground/70'}`}
          strokeWidth={1.25}
        />
      </div>
      <svg className="absolute inset-0 h-full w-full opacity-30" viewBox="0 0 100 100" preserveAspectRatio="none">
        {Array.from({ length: 8 }).map((_, i) => (
          <line key={`h${i}`} x1="0" x2="100" y1={i * 14} y2={i * 14} stroke="currentColor" strokeWidth="0.2" />
        ))}
        {Array.from({ length: 7 }).map((_, i) => (
          <line key={`v${i}`} y1="0" y2="100" x1={i * 16} x2={i * 16} stroke="currentColor" strokeWidth="0.2" />
        ))}
      </svg>
      <span className="absolute bottom-2 left-2 rounded-full bg-white/85 px-2 py-0.5 text-[10px] font-semibold text-foreground shadow-soft">
        {label}
      </span>
    </div>
  );
}

/* ============================== BOTTOM NAV ============================== */

export function BottomNav({ active, onChange }: { active: TabKey; onChange: (k: TabKey) => void }) {
  const { navigate } = useNav();
  const items: { key: TabKey; icon: typeof Home; label: string }[] = [
    { key: 'home', icon: Home, label: 'Inicio' },
    { key: 'train', icon: Dumbbell, label: 'Entrenar' },
    { key: 'nutrition', icon: Apple, label: 'Nutrición' },
    { key: 'progress', icon: TrendingUp, label: 'Progreso' },
    { key: 'health', icon: Activity, label: 'Salud' },
  ];
  return (
    <nav className="pointer-events-none absolute inset-x-0 bottom-0 z-30 px-4 pb-5 pt-2">
      <div className="mb-3 flex justify-end">
        <button
          onClick={() => navigate({ name: 'chat' })}
          aria-label="Hablar con Pulso"
          className="bg-ai-gradient pointer-events-auto inline-flex items-center gap-2 rounded-full px-4 py-3 text-white shadow-card transition active:scale-95"
        >
          <Sparkles className="h-[18px] w-[18px]" />
          <span className="text-[13px] font-semibold">Pulso</span>
        </button>
      </div>
      <div className="glass pointer-events-auto flex items-center justify-around rounded-[28px] px-2 py-2 shadow-card">
        {items.map(({ key, icon: Icon, label }) => {
          const isActive = key === active;
          return (
            <button
              key={key}
              aria-label={label}
              aria-current={isActive ? 'page' : undefined}
              onClick={() => onChange(key)}
              className="flex flex-1 flex-col items-center gap-1 rounded-2xl px-2 py-2 transition active:scale-95"
            >
              <Icon
                className={isActive ? 'h-[22px] w-[22px] text-foreground' : 'h-[22px] w-[22px] text-muted-foreground'}
                strokeWidth={isActive ? 2.4 : 2}
              />
              <span
                className={
                  'text-[10px] font-semibold tracking-wide ' +
                  (isActive ? 'text-ai-gradient' : 'text-muted-foreground')
                }
              >
                {label}
              </span>
            </button>
          );
        })}
      </div>
    </nav>
  );
}

export { Header, Plus };
