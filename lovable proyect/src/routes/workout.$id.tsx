import { createFileRoute, Link } from "@tanstack/react-router";
import {
  ArrowLeft,
  Clock,
  Flame,
  Heart,
  Activity,
  TrendingUp,
} from "lucide-react";

export const Route = createFileRoute("/workout/$id")({
  head: () => ({
    meta: [
      { title: "Detalle del entrenamiento — Personal TrAIner" },
      {
        name: "description",
        content:
          "Detalle completo de tu entrenamiento Mi Band: frecuencia cardíaca, zonas, intensidad y comparativa personal.",
      },
    ],
  }),
  component: WorkoutDetail,
});

/* Zone colors (low → high) */
const ZONES = [
  { name: "Calentamiento", pct: 5, color: "#378ADD" },
  { name: "Quema grasa", pct: 18, color: "#22C55E" },
  { name: "Cardio", pct: 32, color: "#F5C84B" },
  { name: "Anaeróbico", pct: 31, color: "#F08A3D" },
  { name: "Pico", pct: 14, color: "#E0473A" },
];

/* Simulated HR series (50 min gym session: warm-up, sets/rest, cooldown) */
const HR: number[] = [
  102, 108, 112, 118, 124, 128, 132, 138, 144, 148, // warm-up rise
  158, 168, 154, 160, 170, 156, 162, 172, 158, 164, // sets / rest spikes
  174, 160, 168, 156, 166, 152, 162, 150, 160, 148, // peak + recovery
  158, 146, 156, 144, 154, 142, 150, 138, 146, 134, // descending sets
  142, 132, 138, 128, 132, 124, 126, 118, 114, 108, // cooldown
];

function WorkoutDetail() {
  return (
    <div className="min-h-screen w-full bg-[#0B0B0F] text-zinc-100">
      <div className="mx-auto w-full max-w-[440px] px-5 pb-14 pt-4">
        <TopBar />
        <HeroHeader />
        <StatsGrid />
        <HrChartCard />
        <ZonesCard />
        <IntensityCard />
        <ComparisonCard />
      </div>
    </div>
  );
}

function TopBar() {
  return (
    <div className="grid grid-cols-[auto_1fr_auto] items-center gap-3 pb-5">
      <Link
        to="/"
        aria-label="Volver"
        className="grid h-9 w-9 place-items-center rounded-full bg-white/5 ring-1 ring-white/10 transition active:scale-95"
      >
        <ArrowLeft className="h-4 w-4" strokeWidth={2.25} />
      </Link>
      <h1 className="text-center text-[14px] font-semibold tracking-tight text-zinc-200">
        Detalle del entrenamiento
      </h1>
      <span
        className="rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-[0.14em] text-white"
        style={{ background: "rgba(157,123,255,0.18)", color: "#C9B6FF" }}
      >
        Mi Band
      </span>
    </div>
  );
}

function HeroHeader() {
  return (
    <header className="pb-6">
      <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-500">
        Fuerza · Gimnasio
      </p>
      <h2 className="mt-2 text-[28px] font-bold leading-tight tracking-tight text-white">
        Entrenamiento de pesas
      </h2>
      <p className="mt-1 text-[12px] text-zinc-500">Lun 23 jun · 07:12 — 08:02</p>
    </header>
  );
}

function Card({
  label,
  children,
  className = "",
}: { label?: string; children: React.ReactNode; className?: string }) {
  return (
    <section
      className={`rounded-3xl bg-white/[0.03] p-5 ring-1 ring-white/[0.06] ${className}`}
    >
      {label && (
        <p className="text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-500">
          {label}
        </p>
      )}
      {children}
    </section>
  );
}

function StatsGrid() {
  const stats = [
    { label: "Duración", value: "50", unit: "min", sub: "07:12 → 08:02" },
    { label: "Calorías", value: "387", unit: "kcal", sub: "7.7 kcal / min" },
    { label: "FC media", value: "148", unit: "bpm", sub: "zona anaeróbica" },
    { label: "FC máxima", value: "174", unit: "bpm", sub: "mín: 102 bpm" },
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

  const linePath = HR.map((v, i) => `${i === 0 ? "M" : "L"}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ");
  const areaPath = `${linePath} L${w},${h} L0,${h} Z`;

  const peakIdx = HR.indexOf(Math.max(...HR));
  const minIdx = HR.indexOf(Math.min(...HR));

  return (
    <Card label="Frecuencia cardíaca" className="mt-3">
      <div className="relative mt-4">
        <svg viewBox={`0 0 ${w} ${h + 8}`} className="h-40 w-full overflow-visible">
          <defs>
            <linearGradient id="hrFill" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0%" stopColor="#9D7BFF" stopOpacity="0.45" />
              <stop offset="100%" stopColor="#9D7BFF" stopOpacity="0" />
            </linearGradient>
          </defs>

          {/* min dashed horizontal */}
          <line
            x1="0" x2={w} y1={y(102)} y2={y(102)}
            stroke="#378ADD" strokeWidth="1" strokeDasharray="3 4" opacity="0.55"
          />
          {/* peak dashed vertical */}
          <line
            x1={x(peakIdx)} x2={x(peakIdx)} y1="0" y2={h}
            stroke="#D85A30" strokeWidth="1" strokeDasharray="3 4" opacity="0.55"
          />

          <path d={areaPath} fill="url(#hrFill)" />
          <path d={linePath} fill="none" stroke="#9D7BFF" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />

          {/* peak dot + label */}
          <circle cx={x(peakIdx)} cy={y(174)} r="4" fill="#D85A30" stroke="#0B0B0F" strokeWidth="2" />
          <g transform={`translate(${x(peakIdx) + 6}, ${y(174) - 10})`}>
            <rect x="0" y="-10" rx="6" ry="6" width="78" height="16" fill="#D85A30" />
            <text x="39" y="1" textAnchor="middle" fontSize="9" fontWeight="700" fill="#fff">
              ↑ 174 bpm pico
            </text>
          </g>

          {/* min dot + label */}
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
    </Card>
  );
}

function ZonesCard() {
  return (
    <Card label="Zonas de entrenamiento" className="mt-3">
      <div className="mt-4 flex h-3 w-full overflow-hidden rounded-full">
        {ZONES.map((z) => (
          <div key={z.name} style={{ width: `${z.pct}%`, background: z.color }} />
        ))}
      </div>
      <div className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2">
        {ZONES.map((z) => (
          <div key={z.name} className="flex items-center gap-2 text-[12px]">
            <span
              className="h-2.5 w-2.5 shrink-0 rounded-full"
              style={{ background: z.color }}
            />
            <span className="flex-1 truncate text-zinc-300">{z.name}</span>
            <span className="font-semibold tabular-nums text-zinc-100">{z.pct}%</span>
          </div>
        ))}
      </div>
    </Card>
  );
}

function IntensityCard() {
  const filled = 4;
  const total = 5;
  // gradient green→red across the 5 dots
  const dotColors = ["#22C55E", "#A3D34A", "#F5C84B", "#F08A3D", "#E0473A"];
  return (
    <Card label="Intensidad del entreno" className="mt-3">
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
                  background: on ? dotColors[i] : "transparent",
                  border: on ? "none" : "1.5px solid rgba(255,255,255,0.18)",
                }}
              />
            );
          })}
        </div>
      </div>
    </Card>
  );
}

function ComparisonCard() {
  const rows = [
    { icon: Clock, label: "Duración", delta: "+8 min que tu media", tone: "good" as const },
    { icon: Flame, label: "Calorías", delta: "+42 kcal que tu media", tone: "good" as const },
    { icon: Activity, label: "Intensidad", delta: "similar a tu media", tone: "muted" as const },
  ];
  return (
    <Card label="Comparativa personal" className="mt-3">
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
                "inline-flex items-center gap-1 text-[12px] font-semibold " +
                (tone === "good" ? "text-emerald-400" : "text-zinc-500")
              }
            >
              {tone === "good" && <TrendingUp className="h-3.5 w-3.5" strokeWidth={2.5} />}
              {delta}
            </p>
          </div>
        ))}
      </div>
      <div className="mt-3 flex items-center gap-2 px-1 text-[11px] text-zinc-500">
        <Heart className="h-3 w-3" strokeWidth={2.25} />
        Basado en tus últimas 8 sesiones de fuerza.
      </div>
    </Card>
  );
}