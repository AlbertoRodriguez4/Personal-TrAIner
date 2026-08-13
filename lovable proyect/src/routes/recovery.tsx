import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, Sparkles, AlertTriangle, Moon, Heart, Activity } from "lucide-react";

/* ─────────────── Apple-style light tokens ─────────────── */
const theme = {
  bg: "#F5F5F7",
  fg: "#1D1D1F",
  card: "#FFFFFF",
  surface1: "#F5F5F7",
  surface2: "#ECECEF",
  label: "#6E6E73",
  border: "rgba(0,0,0,0.06)",
  aiFrom: "#B054F0",
  aiVia: "#6A5CF0",
  aiTo: "#46B5E8",
  glassFrom: "#F3E8FF",
  glassTo: "#E5F0FE",
  alertFrom: "#FFF4D6",
  alertTo: "#FFE3B0",
  alertText: "#8A4B10",
  alertIcon: "#B45309",
  radius: 24,
  cardShadow: "0 1px 2px rgba(0,0,0,0.04), 0 8px 24px -12px rgba(0,0,0,0.08)",
} as const;

const aiGradient = `linear-gradient(135deg, ${theme.aiFrom} 0%, ${theme.aiVia} 50%, ${theme.aiTo} 100%)`;
const heroGradient = `linear-gradient(135deg, ${theme.glassFrom}, ${theme.glassTo})`;
const alertGradient = `linear-gradient(135deg, ${theme.alertFrom}, ${theme.alertTo})`;

const titleFont = { fontFamily: "Inter, -apple-system, 'SF Pro Display', sans-serif", fontWeight: 700, letterSpacing: "-0.02em" } as const;
const bodyFont = { fontFamily: "Inter, -apple-system, 'SF Pro Text', sans-serif" } as const;
const labelStyle = {
  fontSize: 11, fontWeight: 600, letterSpacing: "1.4px",
  color: theme.label, textTransform: "uppercase" as const,
  ...bodyFont,
};

export const Route = createFileRoute("/recovery")({
  head: () => ({
    meta: [
      { title: "Recuperación & Sueño IA — Personal TrAIner" },
      { name: "description", content: "Análisis nocturno de sueño profundo, REM y recuperación con IA predictiva." },
    ],
  }),
  component: RecoveryScreen,
});

function RecoveryScreen() {
  return (
    <div className="min-h-screen w-full" style={{ background: theme.bg, color: theme.fg, ...bodyFont }}>
      <div className="mx-auto w-full max-w-[440px]">
        <TopBar title="Recuperación IA" />

        {/* SingleChildScrollView + Column → padding fromLTRB(20,12,20,32) */}
        <div className="flex flex-col" style={{ padding: "12px 20px 32px 20px", gap: 20 }}>
          {/* 1. Hero glass card with soft gradient */}
          <HeroGlassCard />

          {/* 2. AI predictive alert */}
          <PredictiveAlert />

          {/* 3. Row of 3 stat pills */}
          <StatPillsRow />

          <SleepStagesCard />
        </div>
      </div>
    </div>
  );
}

function TopBar({ title }: { title: string }) {
  return (
    <div className="flex items-center gap-3 px-5 pt-6 pb-2">
      <Link
        to="/"
        className="grid h-10 w-10 place-items-center rounded-full transition active:scale-95"
        style={{ background: theme.surface1, color: theme.fg }}
        aria-label="Volver"
      >
        <ArrowLeft className="h-4 w-4" />
      </Link>
      <span style={labelStyle}>{title}</span>
    </div>
  );
}

function HeroGlassCard() {
  return (
    <section
      className="relative overflow-hidden"
      style={{
        background: heroGradient,
        borderRadius: theme.radius,
        padding: 24,
        boxShadow: "0 1px 2px rgba(0,0,0,0.04), 0 12px 32px -16px rgba(106,92,240,0.22)",
        border: `1px solid ${theme.border}`,
      }}
    >
      <div className="pointer-events-none absolute -right-12 -top-12 h-44 w-44 rounded-full opacity-30 blur-3xl" style={{ background: aiGradient }} />
      <div className="relative flex items-center gap-2.5">
        <div
          className="grid h-9 w-9 place-items-center rounded-full text-white"
          style={{ background: aiGradient, boxShadow: "0 4px 14px -4px rgba(106,92,240,0.45)" }}
        >
          <Sparkles className="h-4 w-4" strokeWidth={2.5} />
        </div>
        <span style={{ ...labelStyle, color: "#4B2E83" }}>Sueño · Esta noche</span>
      </div>
      <h1
        className="relative mt-3 text-[26px] leading-tight bg-clip-text text-transparent"
        style={{ ...titleFont, backgroundImage: aiGradient }}
      >
        Análisis de Recuperación
      </h1>
      <p className="relative mt-2 text-[13px] leading-snug" style={{ color: "#4B2E83", ...bodyFont }}>
        Tu organismo necesita una jornada ligera. La IA ha recalibrado tu plan en función del descanso.
      </p>
    </section>
  );
}

function PredictiveAlert() {
  return (
    <section
      className="relative overflow-hidden"
      style={{
        background: alertGradient,
        borderRadius: theme.radius,
        padding: 20,
      }}
    >
      <div className="flex items-start gap-3">
        <div
          className="grid h-9 w-9 shrink-0 place-items-center rounded-full"
          style={{ background: "rgba(255,255,255,0.6)", color: theme.alertIcon }}
        >
          <AlertTriangle className="h-4 w-4" strokeWidth={2.5} />
        </div>
        <div className="min-w-0">
          <p style={{ ...labelStyle, color: theme.alertText, opacity: 0.85 }}>Alerta predictiva · IA</p>
          <p className="mt-1.5 text-[14px] font-semibold leading-snug" style={{ color: theme.alertText, ...bodyFont }}>
            Sueño profundo inferior al 15%. Se recomienda reducir la intensidad del entrenamiento (RPE 6).
          </p>
        </div>
      </div>
    </section>
  );
}

function StatPillsRow() {
  const stats = [
    { icon: Moon, label: "Total Sleep", value: "6h 15m" },
    { icon: Sparkles, label: "REM", value: "1h 10m" },
    { icon: Heart, label: "Resting HR", value: "52 bpm" },
  ];
  return (
    <div className="grid grid-cols-3 gap-3">
      {stats.map(({ icon: Icon, label, value }) => (
        <div
          key={label}
          style={{ background: theme.card, borderRadius: 18, padding: 14, boxShadow: theme.cardShadow, border: `1px solid ${theme.border}` }}
          className="flex flex-col gap-2"
        >
          <Icon className="h-3.5 w-3.5" style={{ color: theme.aiVia }} strokeWidth={2} />
          <p style={{ ...labelStyle, fontSize: 9 }}>{label}</p>
          <p style={{ fontSize: 15, fontWeight: 700, color: theme.fg, ...bodyFont, lineHeight: 1.1, letterSpacing: "-0.01em" }}>
            {value}
          </p>
        </div>
      ))}
    </div>
  );
}

function SleepStagesCard() {
  const stages = [
    { label: "Profundo", pct: 12, color: theme.aiFrom },
    { label: "REM", pct: 19, color: theme.aiVia },
    { label: "Ligero", pct: 54, color: theme.aiTo },
    { label: "Despierto", pct: 15, color: "#C7C7CC" },
  ];
  return (
    <section style={{ background: theme.card, borderRadius: theme.radius, padding: 20, boxShadow: theme.cardShadow }}>
      <div className="flex items-center justify-between">
        <p style={labelStyle}>Fases del sueño</p>
        <span style={{ fontSize: 11, color: theme.label, ...bodyFont }}>7h 25m en cama</span>
      </div>
      <div className="mt-4 flex h-3 w-full overflow-hidden rounded-full" style={{ background: theme.surface2 }}>
        {stages.map((s) => (
          <div key={s.label} style={{ width: `${s.pct}%`, background: s.color }} />
        ))}
      </div>
      <ul className="mt-4 grid grid-cols-2 gap-x-4 gap-y-2.5">
        {stages.map((s) => (
          <li key={s.label} className="flex items-center gap-2">
            <span className="h-2 w-2 rounded-full" style={{ background: s.color }} />
            <span style={{ fontSize: 12, color: theme.fg, ...bodyFont }}>{s.label}</span>
            <span className="ml-auto" style={{ fontSize: 12, fontWeight: 700, color: theme.fg, ...bodyFont }}>
              {s.pct}%
            </span>
          </li>
        ))}
      </ul>
      <div
        className="mt-5 flex items-center gap-2 rounded-2xl px-3 py-2.5"
        style={{ background: theme.surface1 }}
      >
        <Activity className="h-4 w-4" style={{ color: theme.aiVia }} strokeWidth={2.25} />
        <p style={{ fontSize: 12, color: theme.fg, ...bodyFont }}>
          VFC nocturna <span style={{ fontWeight: 700 }}>+8%</span> vs media semanal.
        </p>
      </div>
    </section>
  );
}