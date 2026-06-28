import { createFileRoute } from "@tanstack/react-router";
import {
  Sparkles,
  Mic,
  Play,
  Home,
  Dumbbell,
  Apple,
  Activity,
  ChevronRight,
} from "lucide-react";
import { useState } from "react";
import {
  Heart,
  Camera,
  ScanLine,
  FileText,
  Upload,
  AlertTriangle,
  Pause,
  Volume2,
  Image as ImageIcon,
  TrendingDown,
  TrendingUp,
  CircleUser,
} from "lucide-react";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Personal TrAIner — Tu entrenador con IA" },
      {
        name: "description",
        content:
          "Entrenamiento, nutrición y recuperación personalizados por IA. Diseño limpio, datos claros, resultados reales.",
      },
      { property: "og:title", content: "Personal TrAIner — Tu entrenador con IA" },
      {
        property: "og:description",
        content: "Entrenamiento, nutrición y recuperación personalizados por IA.",
      },
    ],
  }),
  component: Index,
});

function Index() {
  const [tab, setTab] = useState<TabKey>("dashboard");
  return (
    <div className="min-h-screen w-full bg-surface-2">
      <div className="relative mx-auto flex min-h-screen w-full max-w-[440px] flex-col bg-background">
        <Header />
        <main className="flex-1 px-5 pb-32 pt-2">
          <div key={tab} className="animate-fade-in space-y-5">
            {tab === "dashboard" && <DashboardScreen />}
            {tab === "coach" && <CoachScreen />}
            {tab === "nutrition" && <NutritionScreen />}
            {tab === "clinic" && <ClinicScreen />}
          </div>
        </main>
        <BottomNav active={tab} onChange={setTab} />
      </div>
    </div>
  );
}

type TabKey = "dashboard" | "coach" | "nutrition" | "clinic";

function BrandName({ className = "" }: { className?: string }) {
  return (
    <span className={`font-display font-bold tracking-tight ${className}`}>
      Personal Tr
      <span className="text-ai-gradient font-extrabold italic">AI</span>
      ner
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
          <BrandName className="block truncate text-[22px] leading-tight" />
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

/* ============================== DASHBOARD ============================== */

function DashboardScreen() {
  return (
    <>
      <PredictiveAlert />
      <QuickActions />
      <DailySummary />
      <WorkoutCard />
    </>
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
  const items = [
    { icon: Camera, label: "Escanear", sub: "Comida" },
    { icon: ScanLine, label: "Evaluar", sub: "Postura" },
    { icon: FileText, label: "Subir", sub: "Analítica" },
  ];
  return (
    <section aria-label="Acciones rápidas" className="grid grid-cols-3 gap-3">
      {items.map(({ icon: Icon, label, sub }) => (
        <button
          key={label}
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
  title,
  value,
  unit,
  sub,
  pct,
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
                <stop offset="0%" stopColor="oklch(0.72 0.18 295)" />
                <stop offset="55%" stopColor="oklch(0.7 0.19 260)" />
                <stop offset="100%" stopColor="oklch(0.78 0.17 200)" />
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

function AICard() {
  return (
    <section
      aria-label="Asistente de IA"
      className="relative overflow-hidden rounded-[28px] bg-ai-soft p-5 shadow-card"
    >
      <div className="pointer-events-none absolute -right-16 -top-16 h-56 w-56 rounded-full bg-ai-gradient opacity-30 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-20 -left-10 h-48 w-48 rounded-full bg-ai-gradient opacity-20 blur-3xl" />

      <div className="relative flex items-center gap-2">
        <div className="grid h-7 w-7 place-items-center rounded-full bg-ai-gradient text-white shadow-soft">
          <Sparkles className="h-3.5 w-3.5" strokeWidth={2.5} />
        </div>
        <span className="text-[12px] font-semibold uppercase tracking-[0.14em] text-foreground/70">
          Tu IA · ahora
        </span>
      </div>

      <p className="relative mt-3 text-[17px] font-medium leading-snug text-foreground">
        Dormiste poco hoy. He adaptado tu rutina de fuerza para priorizar la{" "}
        <span className="text-ai-gradient font-semibold">recuperación</span>.
      </p>

      <div className="relative mt-5 flex items-center justify-between">
        <button className="inline-flex items-center gap-1.5 text-[14px] font-semibold text-foreground/80 transition hover:text-foreground">
          Ver ajustes
          <ChevronRight className="h-4 w-4" strokeWidth={2.25} />
        </button>
        <button
          aria-label="Hablar con IA"
          className="inline-flex items-center gap-2 rounded-full bg-foreground px-4 py-2.5 text-[13px] font-semibold text-background shadow-card transition active:scale-95"
        >
          <Mic className="h-4 w-4" strokeWidth={2.25} />
          Hablar con IA
        </button>
      </div>
    </section>
  );
}

function BiometricGrid() {
  return (
    <section aria-label="Resumen biométrico" className="grid grid-cols-3 gap-3">
      <MetricRing label="Recuperación" sub="VFC" value="78" unit="ms" pct={0.78} />
      <MetricRing label="Proteína" sub="hoy" value="92" unit="g" pct={0.55} />
      <MetricBars label="Esfuerzo" sub="semana" value="4/5" />
    </section>
  );
}

function MetricRing({
  label,
  sub,
  value,
  unit,
  pct,
}: {
  label: string;
  sub: string;
  value: string;
  unit: string;
  pct: number;
}) {
  const r = 26;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - pct);
  return (
    <div className="rounded-2xl bg-card p-3.5 shadow-soft">
      <p className="truncate text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
        {label}
      </p>
      <div className="mt-2 grid place-items-center">
        <div className="relative h-[68px] w-[68px]">
          <svg viewBox="0 0 64 64" className="h-full w-full -rotate-90">
            <circle cx="32" cy="32" r={r} className="fill-none stroke-muted" strokeWidth="6" />
            <circle
              cx="32"
              cy="32"
              r={r}
              stroke="url(#aiRing)"
              strokeWidth="6"
              strokeLinecap="round"
              fill="none"
              strokeDasharray={c}
              strokeDashoffset={offset}
            />
            <defs>
              <linearGradient id="aiRing" x1="0" y1="0" x2="64" y2="64">
                <stop offset="0%" stopColor="oklch(0.72 0.18 295)" />
                <stop offset="55%" stopColor="oklch(0.7 0.19 260)" />
                <stop offset="100%" stopColor="oklch(0.78 0.17 200)" />
              </linearGradient>
            </defs>
          </svg>
          <div className="absolute inset-0 grid place-items-center">
            <div className="text-center leading-none">
              <span className="text-[18px] font-bold tracking-tight text-foreground">{value}</span>
              <span className="ml-0.5 text-[10px] font-medium text-muted-foreground">{unit}</span>
            </div>
          </div>
        </div>
      </div>
      <p className="mt-1 text-center text-[10px] text-muted-foreground">{sub}</p>
    </div>
  );
}

function MetricBars({ label, sub, value }: { label: string; sub: string; value: string }) {
  const bars = [0.6, 0.9, 0.4, 0.75, 0.5];
  return (
    <div className="rounded-2xl bg-card p-3.5 shadow-soft">
      <p className="truncate text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
        {label}
      </p>
      <div className="mt-2 flex h-[68px] items-end justify-between gap-1.5 px-0.5">
        {bars.map((h, i) => (
          <div
            key={i}
            className="w-2 rounded-full bg-ai-gradient"
            style={{ height: `${h * 100}%`, opacity: 0.55 + h * 0.45 }}
          />
        ))}
      </div>
      <p className="mt-1 text-center text-[10px] text-muted-foreground">
        <span className="text-[13px] font-semibold text-foreground">{value}</span>{" "}
        <span>· {sub}</span>
      </p>
    </div>
  );
}

function WorkoutCard() {
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

      <button className="mt-5 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-ai-gradient px-5 py-4 text-[15px] font-semibold text-white shadow-card transition active:scale-[0.99]">
        <Play className="h-4 w-4 fill-current" strokeWidth={0} />
        Iniciar Focus Mode
      </button>
    </section>
  );
}

/* ============================== COACH ============================== */

function CoachScreen() {
  return (
    <>
      <RAGBubble />
      <VoiceHero />
      <FocusModeCard />
    </>
  );
}

function RAGBubble() {
  return (
    <div className="relative ml-1 max-w-[88%] rounded-3xl rounded-tl-md bg-ai-soft p-4 shadow-soft">
      <div className="flex items-center gap-2">
        <div className="grid h-6 w-6 place-items-center rounded-full bg-ai-gradient text-white">
          <Sparkles className="h-3 w-3" strokeWidth={2.5} />
        </div>
        <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-foreground/70">
          Memoria contextual · RAG
        </span>
      </div>
      <p className="mt-2 text-[15px] font-medium leading-snug text-foreground">
        Hola Carlos, noto por tu voz de ayer que estás estresado.
        He ajustado tu rutina de <span className="text-ai-gradient font-semibold">fuerza</span>.
      </p>
    </div>
  );
}

function VoiceHero() {
  return (
    <section className="rounded-[32px] bg-card p-6 shadow-card">
      <div className="relative mx-auto grid h-56 w-56 place-items-center">
        <div className="absolute inset-0 rounded-full bg-ai-gradient opacity-20 blur-2xl animate-ai-pulse" />
        <div className="absolute inset-6 rounded-full bg-ai-gradient opacity-30 blur-xl" />
        <div className="relative grid h-44 w-44 place-items-center rounded-full bg-ai-gradient shadow-card">
          <div className="grid h-36 w-36 place-items-center rounded-full bg-background">
            <div className="flex h-10 items-end gap-1.5">
              {[0.4, 0.8, 0.55, 1, 0.7, 0.9, 0.45, 0.75].map((h, i) => (
                <span
                  key={i}
                  className="w-1.5 origin-bottom rounded-full bg-ai-gradient animate-wave"
                  style={{ height: `${h * 100}%`, animationDelay: `${i * 0.08}s` }}
                />
              ))}
            </div>
          </div>
        </div>
      </div>
      <p className="mt-5 text-center text-[15px] font-semibold text-foreground">
        Escuchando…
      </p>
      <p className="mt-1 text-center text-[12px] text-muted-foreground">
        Conversación full-duplex en tiempo real
      </p>
      <div className="mt-5 flex items-center justify-center gap-3">
        <button className="grid h-11 w-11 place-items-center rounded-full bg-surface-2 text-foreground/70 transition active:scale-95">
          <Volume2 className="h-4 w-4" strokeWidth={2.25} />
        </button>
        <button className="grid h-14 w-14 place-items-center rounded-full bg-foreground text-background shadow-card transition active:scale-95">
          <Pause className="h-5 w-5" strokeWidth={2.25} />
        </button>
        <button className="grid h-11 w-11 place-items-center rounded-full bg-surface-2 text-foreground/70 transition active:scale-95">
          <Mic className="h-4 w-4" strokeWidth={2.25} />
        </button>
      </div>
    </section>
  );
}

function FocusModeCard() {
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
      <button className="mt-5 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-ai-gradient px-5 py-4 text-[15px] font-semibold text-white shadow-card transition active:scale-[0.99]">
        <Camera className="h-4 w-4" strokeWidth={2.25} />
        Activar Cámara Edge AI
      </button>
    </section>
  );
}

/* ============================== NUTRITION ============================== */

function NutritionScreen() {
  return (
    <>
      <CameraViewer />
      <ScanResultCard />
    </>
  );
}

function CameraViewer() {
  return (
    <section className="relative overflow-hidden rounded-[28px] bg-foreground/95 p-0 shadow-card">
      <div className="relative aspect-[4/5] w-full bg-[radial-gradient(circle_at_50%_40%,oklch(0.3_0.05_260),oklch(0.12_0.02_260))]">
        {/* corner guides */}
        {[
          "left-5 top-5 border-l-2 border-t-2 rounded-tl-xl",
          "right-5 top-5 border-r-2 border-t-2 rounded-tr-xl",
          "left-5 bottom-5 border-l-2 border-b-2 rounded-bl-xl",
          "right-5 bottom-5 border-r-2 border-b-2 rounded-br-xl",
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

/* ============================== CLINIC ============================== */

function ClinicScreen() {
  return (
    <>
      <ClinicalImporter />
      <CompositionChart />
      <PostureMesh />
    </>
  );
}

function ClinicalImporter() {
  return (
    <button className="group block w-full rounded-[28px] border-2 border-dashed border-border bg-card p-6 text-left shadow-soft transition hover:border-foreground/30 active:scale-[0.99]">
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
  // minimal two-line trend
  const lean = [40, 42, 43, 45, 46, 48, 49];
  const fat = [28, 27, 26, 25, 24, 22, 21];
  const max = 55, min = 15;
  const w = 320, h = 110;
  const path = (arr: number[]) =>
    arr
      .map((v, i) => {
        const x = (i / (arr.length - 1)) * w;
        const y = h - ((v - min) / (max - min)) * h;
        return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
      })
      .join(" ");
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
            <stop offset="0%" stopColor="oklch(0.7 0.19 260)" stopOpacity="0.35" />
            <stop offset="100%" stopColor="oklch(0.7 0.19 260)" stopOpacity="0" />
          </linearGradient>
        </defs>
        <path d={`${path(lean)} L${w},${h} L0,${h} Z`} fill="url(#leanG)" />
        <path d={path(lean)} stroke="oklch(0.7 0.19 260)" strokeWidth="2.5" fill="none" strokeLinecap="round" />
        <path d={path(fat)} stroke="oklch(0.75 0.13 30)" strokeWidth="2.5" fill="none" strokeLinecap="round" strokeDasharray="4 4" />
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
          className={`h-24 w-24 ${muted ? "text-foreground/30" : "text-foreground/70"}`}
          strokeWidth={1.25}
        />
      </div>
      {/* mesh grid overlay */}
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

/* ============================== NAV ============================== */

function BottomNav({ active, onChange }: { active: TabKey; onChange: (k: TabKey) => void }) {
  const items: { key: TabKey; icon: typeof Home; label: string }[] = [
    { key: "dashboard", icon: Home, label: "Dashboard" },
    { key: "coach", icon: Dumbbell, label: "Entrenador" },
    { key: "nutrition", icon: Apple, label: "Nutrición" },
    { key: "clinic", icon: Activity, label: "Clínica" },
  ];
  return (
    <nav className="pointer-events-none absolute inset-x-0 bottom-0 z-30 px-4 pb-5 pt-2">
      <div className="glass pointer-events-auto flex items-center justify-around rounded-[28px] px-2 py-2 shadow-card">
        {items.map(({ key, icon: Icon, label }) => {
          const isActive = key === active;
          return (
            <button
              key={key}
              aria-label={label}
              aria-current={isActive ? "page" : undefined}
              onClick={() => onChange(key)}
              className="flex flex-1 flex-col items-center gap-1 rounded-2xl px-2 py-2 transition active:scale-95"
            >
              <Icon
                className={
                  isActive
                    ? "h-[22px] w-[22px] text-foreground"
                    : "h-[22px] w-[22px] text-muted-foreground"
                }
                strokeWidth={isActive ? 2.4 : 2}
              />
              <span
                className={
                  "text-[10px] font-semibold tracking-wide " +
                  (isActive ? "text-ai-gradient" : "text-muted-foreground")
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