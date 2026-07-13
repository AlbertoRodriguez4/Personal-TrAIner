import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, Sparkles, Watch, Smartphone, Circle as Ring, RefreshCw } from "lucide-react";

/* ─────────────── Conceptual theme tokens ─────────────── */
const theme = {
  bg: "#111318",
  fg: "#F9F9FC",
  card: "#23262F",
  surface1: "#1B1D24",
  label: "#9DA0AE",
  aiFrom: "#B054F0",
  aiVia: "#6A5CF0",
  aiTo: "#46B5E8",
  badgeBg: "#1E1E1E",
  badgeDot: "#FF6900",
  live: "#10B981",
  radius: 28,
} as const;

const aiGradient = `linear-gradient(135deg, ${theme.aiFrom} 0%, ${theme.aiVia} 50%, ${theme.aiTo} 100%)`;
const titleFont = { fontFamily: "Outfit, Inter, sans-serif", fontWeight: 800, letterSpacing: "-0.5px" } as const;
const bodyFont = { fontFamily: "Manrope, Inter, sans-serif" } as const;
const labelStyle = {
  fontSize: 11, fontWeight: 600, letterSpacing: "1.4px",
  color: theme.label, textTransform: "uppercase" as const,
  ...bodyFont,
};

export const Route = createFileRoute("/devices")({
  head: () => ({
    meta: [
      { title: "Device Sync Center — Personal TrAIner" },
      { name: "description", content: "Sincroniza tus wearables (Redmi Watch, Mi Band, Health Connect) con la IA." },
    ],
  }),
  component: DevicesScreen,
});

function DevicesScreen() {
  return (
    <div className="min-h-screen w-full" style={{ background: theme.bg, color: theme.fg, ...bodyFont }}>
      <div className="mx-auto w-full max-w-[440px]">
        <TopBar title="Device Sync Center" />
        <div className="flex flex-col" style={{ padding: "12px 20px 32px 20px", gap: 20 }}>
          <PrimaryDeviceCard />
          <OtherDevicesCard />
          <PrimarySyncButton />
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

function DeviceBadge() {
  return (
    <span
      className="inline-flex items-center gap-1.5"
      style={{
        background: theme.badgeBg,
        borderRadius: 999,
        padding: "5px 10px 5px 7px",
      }}
    >
      <span className="h-2 w-2 rounded-full" style={{ background: theme.badgeDot }} />
      <span style={{ ...labelStyle, fontSize: 9, color: theme.fg }}>Device</span>
    </span>
  );
}

function LiveSyncPill() {
  return (
    <div
      className="inline-flex items-center gap-2 rounded-full"
      style={{
        background: "rgba(16,185,129,0.12)",
        border: `1px solid rgba(16,185,129,0.35)`,
        padding: "6px 12px 6px 8px",
      }}
    >
      <span className="relative grid h-3 w-3 place-items-center">
        <span className="absolute h-2 w-2 rounded-full animate-ai-pulse" style={{ background: theme.live }} />
        <span className="absolute h-2 w-2 rounded-full animate-ai-ring" style={{ background: theme.live, opacity: 0.4 }} />
      </span>
      <span style={{ fontSize: 11, fontWeight: 600, color: theme.live, ...bodyFont }}>
        Syncing data from Health Connect…
      </span>
    </div>
  );
}

function PrimaryDeviceCard() {
  return (
    <section style={{ background: theme.card, borderRadius: theme.radius, padding: 20 }}>
      <div className="flex items-start justify-between gap-3">
        <div className="flex flex-col gap-3 min-w-0">
          <DeviceBadge />
          <div>
            <h2 style={{ ...titleFont, fontSize: 22, color: theme.fg, lineHeight: 1.1 }}>
              Redmi Watch 5
            </h2>
            <p className="mt-1" style={{ fontSize: 12, color: theme.label, ...bodyFont }}>
              Conectado · batería 82% · firmware 3.4.1
            </p>
          </div>
        </div>
        <LiveSyncPill />
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
    <div style={{ background: theme.surface1, borderRadius: 16, padding: 12 }}>
      <p style={labelStyle}>{label}</p>
      <p className="mt-1" style={{ fontSize: 13, fontWeight: 700, color: theme.fg, ...bodyFont, lineHeight: 1.1 }}>
        {value}
        {suffix && <span style={{ marginLeft: 3, fontSize: 10, color: theme.label, fontWeight: 500 }}>{suffix}</span>}
      </p>
    </div>
  );
}

function OtherDevicesCard() {
  const list = [
    { icon: Smartphone, name: "Health Connect", sub: "Android · puente activo", status: "Online" },
    { icon: Ring, name: "Smart Ring", sub: "No emparejado", status: "Offline", muted: true },
    { icon: Watch, name: "Mi Band 8", sub: "Histórico importado", status: "Sync diario" },
  ];
  return (
    <section style={{ background: theme.card, borderRadius: theme.radius, padding: 20 }}>
      <p style={labelStyle}>Otros dispositivos</p>
      <ul className="mt-3 space-y-2">
        {list.map(({ icon: Icon, name, sub, status, muted }) => (
          <li
            key={name}
            className="flex items-center gap-3"
            style={{ background: theme.surface1, borderRadius: 16, padding: 12, opacity: muted ? 0.55 : 1 }}
          >
            <div
              className="grid h-9 w-9 shrink-0 place-items-center rounded-xl"
              style={{ background: "rgba(255,255,255,0.04)", color: theme.fg }}
            >
              <Icon className="h-4 w-4" strokeWidth={2} />
            </div>
            <div className="min-w-0 flex-1">
              <p style={{ fontSize: 13, fontWeight: 600, color: theme.fg, ...bodyFont, lineHeight: 1.1 }}>{name}</p>
              <p className="mt-0.5" style={{ fontSize: 11, color: theme.label, ...bodyFont }}>{sub}</p>
            </div>
            <span style={{ ...labelStyle, fontSize: 9, color: muted ? theme.label : theme.live }}>
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
        background: aiGradient,
        borderRadius: 18,
        padding: "16px 20px",
        boxShadow: "0 10px 28px -12px rgba(106,92,240,0.55)",
      }}
    >
      <span className="flex items-center justify-center gap-2">
        <Sparkles className="h-4 w-4" strokeWidth={2.5} />
        <span style={{ ...titleFont, fontSize: 15, letterSpacing: 0 }}>Forzar Sincronización AI</span>
        <RefreshCw className="h-4 w-4 opacity-80" strokeWidth={2.25} />
      </span>
    </button>
  );
}