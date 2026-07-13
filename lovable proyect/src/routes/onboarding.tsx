import { createFileRoute, useNavigate, Link } from "@tanstack/react-router";
import { useState } from "react";
import {
  Bluetooth,
  HeartPulse,
  Activity,
  Moon,
  Footprints,
  Flame,
  Sparkles,
  ShieldCheck,
  Brain,
  ArrowRight,
  Check,
} from "lucide-react";
import logoAsset from "@/assets/traainer-logo.jpg.asset.json";

export const Route = createFileRoute("/onboarding")({
  head: () => ({
    meta: [
      { title: "Bienvenido · Personal TrAIner" },
      {
        name: "description",
        content:
          "Descubre cómo Personal TrAIner conecta tus dispositivos, sincroniza tu salud y adapta tu entrenamiento con IA.",
      },
    ],
  }),
  component: OnboardingScreen,
});

type Step = {
  eyebrow: string;
  title: React.ReactNode;
  body: string;
  accent: string; // tailwind gradient stops via inline style
  visual: React.ReactNode;
  bullets: { icon: React.ComponentType<{ className?: string }>; label: string }[];
};

const STEPS: Step[] = [
  {
    eyebrow: "01 · Dispositivos",
    title: (
      <>
        Tu cuerpo, <span className="text-[#22D3EE]">en vivo</span>.
      </>
    ),
    body:
      "Conecta por Bluetooth tu banda de frecuencia cardíaca o smartwatch (Xiaomi, Redmi, Polar, Garmin…) para leer tu biometría en tiempo real durante cada entrenamiento.",
    accent: "linear-gradient(135deg, #22D3EE 0%, #6366F1 100%)",
    visual: <DeviceVisual />,
    bullets: [
      { icon: Bluetooth, label: "Emparejado seguro BLE" },
      { icon: HeartPulse, label: "FC en directo · latido a latido" },
      { icon: Activity, label: "Zonas de esfuerzo dinámicas" },
    ],
  },
  {
    eyebrow: "02 · Health Connect",
    title: (
      <>
        Tu historial es el <span className="text-[#A3E635]">combustible</span>.
      </>
    ),
    body:
      "Sincronizamos pasos, entrenamientos, calorías, distancia y sueño desde Health Connect. Un único hilo de datos que alimenta a tu IA para entender tu forma real.",
    accent: "linear-gradient(135deg, #A3E635 0%, #10B981 100%)",
    visual: <HealthVisual />,
    bullets: [
      { icon: Footprints, label: "Pasos · distancia · cardio" },
      { icon: Flame, label: "Calorías activas y basales" },
      { icon: Moon, label: "Fases y calidad del sueño" },
    ],
  },
  {
    eyebrow: "03 · IA Personal",
    title: (
      <>
        Un coach que <span className="text-[#C084FC]">te entiende</span>.
      </>
    ),
    body:
      "Con tus datos históricos y en tiempo real, la IA ajusta rutinas, evalúa recuperación y protege tu salud. Nada sale de tu bóveda cifrada sin tu permiso.",
    accent: "linear-gradient(135deg, #C084FC 0%, #F0ABFC 60%, #22D3EE 100%)",
    visual: <AIVisual />,
    bullets: [
      { icon: Brain, label: "Rutinas adaptativas diarias" },
      { icon: Sparkles, label: "Recuperación y RPE inteligentes" },
      { icon: ShieldCheck, label: "Privacidad cifrada · tú mandas" },
    ],
  },
];

function OnboardingScreen() {
  const [step, setStep] = useState(0);
  const navigate = useNavigate();
  const s = STEPS[step];
  const isLast = step === STEPS.length - 1;

  return (
    <div className="min-h-screen w-full bg-[#F5F5F7] text-[#1D1D1F]">
      {/* Ambient light */}
      <div className="pointer-events-none fixed inset-0 overflow-hidden">
        <div
          className="absolute -top-40 left-1/2 h-[520px] w-[520px] -translate-x-1/2 rounded-full opacity-40 blur-[120px] transition-all duration-700"
          style={{ background: s.accent }}
        />
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_120%,rgba(0,0,0,0.05),transparent_60%)]" />
        <div
          className="absolute inset-0 opacity-[0.05]"
          style={{
            backgroundImage:
              "linear-gradient(rgba(0,0,0,.5) 1px,transparent 1px),linear-gradient(90deg,rgba(0,0,0,.5) 1px,transparent 1px)",
            backgroundSize: "44px 44px",
          }}
        />
      </div>

      <div className="relative mx-auto flex min-h-screen w-full max-w-[440px] flex-col px-6 pb-8 pt-12">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <img
              src={logoAsset.url}
              alt=""
              className="h-8 w-8 rounded-xl object-cover ring-1 ring-black/[0.08]"
            />
            <span className="text-[13px] font-semibold tracking-tight">
              Personal Tr<span className="text-ai-gradient">AI</span>ner
            </span>
          </div>
          <Link
            to="/auth"
            className="text-[11px] font-medium uppercase tracking-[0.14em] text-[#6E6E73] transition hover:text-[#1D1D1F]"
          >
            Saltar
          </Link>
        </div>

        {/* Progress dots */}
        <div className="mt-8 flex items-center gap-2">
          {STEPS.map((_, i) => {
            const active = i === step;
            const done = i < step;
            return (
              <button
                key={i}
                onClick={() => setStep(i)}
                className="group h-1.5 flex-1 overflow-hidden rounded-full bg-black/[0.06]"
                aria-label={`Paso ${i + 1}`}
              >
                <span
                  className="block h-full rounded-full transition-all duration-500"
                  style={{
                    width: active || done ? "100%" : "0%",
                    background: STEPS[i].accent,
                  }}
                />
              </button>
            );
          })}
        </div>

        {/* Content */}
        <div key={step} className="mt-6 flex-1 animate-fade-in">
          {/* Visual card */}
          <div className="relative overflow-hidden rounded-[32px] border border-black/[0.06] bg-white p-6 backdrop-blur-xl">
            <div
              className="pointer-events-none absolute -right-16 -top-16 h-48 w-48 rounded-full opacity-50 blur-3xl"
              style={{ background: s.accent }}
            />
            <div className="relative flex h-52 items-center justify-center">
              {s.visual}
            </div>
          </div>

          <p className="mt-7 text-[11px] font-semibold uppercase tracking-[0.22em] text-[#6E6E73]">
            {s.eyebrow}
          </p>
          <h1 className="mt-3 text-[30px] font-bold leading-[1.1] tracking-tight">
            {s.title}
          </h1>
          <p className="mt-3 text-[14.5px] leading-relaxed text-[#3A3A3C]">{s.body}</p>

          <ul className="mt-6 space-y-2.5">
            {s.bullets.map(({ icon: Icon, label }) => (
              <li
                key={label}
                className="flex items-center gap-3 rounded-2xl border border-black/[0.06] bg-white px-4 py-3"
              >
                <span
                  className="flex h-8 w-8 items-center justify-center rounded-xl"
                  style={{ background: s.accent }}
                >
                  <Icon className="h-4 w-4 text-black/80" />
                </span>
                <span className="text-[13.5px] font-medium text-[#1D1D1F]">{label}</span>
                <Check className="ml-auto h-4 w-4 text-[#1D1D1F]/30" strokeWidth={2.5} />
              </li>
            ))}
          </ul>
        </div>

        {/* Footer CTA */}
        <div className="mt-8 space-y-3">
          <button
            onClick={() => {
              if (isLast) navigate({ to: "/auth" });
              else setStep(step + 1);
            }}
            className="group relative inline-flex w-full items-center justify-center gap-2 overflow-hidden rounded-2xl px-6 py-4 text-[15px] font-semibold text-black transition active:scale-[0.99]"
            style={{ background: s.accent }}
          >
            <span className="absolute inset-0 bg-white opacity-0 transition group-hover:opacity-100" />
            <span className="relative">
              {isLast ? "Empezar a sincronizar" : "Continuar"}
            </span>
            <ArrowRight className="relative h-4 w-4" strokeWidth={2.6} />
          </button>

          {step > 0 ? (
            <button
              onClick={() => setStep(step - 1)}
              className="w-full text-center text-[12px] font-medium text-[#6E6E73] transition hover:text-[#1D1D1F]"
            >
              Atrás
            </button>
          ) : (
            <p className="text-center text-[11px] text-[#8E8E93]">
              Al continuar aceptas nuestros{" "}
              <span className="text-[#3A3A3C] underline underline-offset-2">Términos</span> y{" "}
              <span className="text-[#3A3A3C] underline underline-offset-2">Privacidad</span>.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

/* ────────────────────────────  VISUALS  ──────────────────────────── */

function DeviceVisual() {
  return (
    <div className="relative flex h-full w-full items-center justify-center">
      {/* Radar rings */}
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          className="absolute rounded-full border border-cyan-300/25"
          style={{
            width: 80 + i * 60,
            height: 80 + i * 60,
            animation: `ai-ring 2.6s ${i * 0.6}s ease-out infinite`,
          }}
        />
      ))}

      {/* Watch */}
      <div className="relative flex h-28 w-20 flex-col items-center justify-center rounded-[22px] border border-black/[0.08] bg-gradient-to-b from-white/10 to-white/[0.02] shadow-2xl backdrop-blur-md">
        <div className="absolute -top-1.5 h-2 w-8 rounded-t-md bg-black/[0.12]" />
        <div className="absolute -bottom-1.5 h-2 w-8 rounded-b-md bg-black/[0.12]" />
        <HeartPulse className="h-6 w-6 text-[#22D3EE] animate-ai-pulse" />
        <span className="mt-1 text-[10px] font-semibold tabular-nums text-[#1D1D1F]">
          142
        </span>
        <span className="text-[8px] uppercase tracking-widest text-[#8E8E93]">bpm</span>
      </div>

      {/* Floating chip */}
      <div className="absolute right-2 top-4 flex items-center gap-1.5 rounded-full border border-cyan-300/30 bg-cyan-300/10 px-2.5 py-1 backdrop-blur">
        <Bluetooth className="h-3 w-3 text-cyan-200" />
        <span className="text-[10px] font-semibold text-cyan-100">Live</span>
      </div>
      <div className="absolute bottom-3 left-2 rounded-full border border-black/[0.08] bg-white px-2.5 py-1 text-[10px] font-medium text-[#3A3A3C] backdrop-blur">
        Redmi Watch 5
      </div>
    </div>
  );
}

function HealthVisual() {
  const items = [
    { icon: Footprints, label: "8 420", sub: "pasos" },
    { icon: Flame, label: "612", sub: "kcal" },
    { icon: Activity, label: "42′", sub: "cardio" },
    { icon: Moon, label: "7h 12", sub: "sueño" },
  ];
  return (
    <div className="grid w-full grid-cols-2 gap-3">
      {items.map(({ icon: Icon, label, sub }, i) => (
        <div
          key={label}
          className="relative overflow-hidden rounded-2xl border border-black/[0.06] bg-white p-3 backdrop-blur"
          style={{ animation: `fade-in 0.5s ${i * 0.08}s both` }}
        >
          <div className="flex items-center justify-between">
            <Icon className="h-4 w-4 text-[#A3E635]" />
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 shadow-[0_0_8px_#34d399]" />
          </div>
          <div className="mt-2 text-[15px] font-bold tabular-nums text-[#1D1D1F]">
            {label}
          </div>
          <div className="text-[10px] uppercase tracking-wider text-[#6E6E73]">{sub}</div>
        </div>
      ))}
    </div>
  );
}

function AIVisual() {
  return (
    <div className="relative flex h-full w-full items-center justify-center">
      {/* Orbits */}
      {[70, 105, 140].map((r, i) => (
        <span
          key={r}
          className="absolute rounded-full border border-black/[0.06]"
          style={{ width: r * 2, height: r * 2 }}
        >
          <span
            className="absolute h-2 w-2 rounded-full shadow-[0_0_12px_currentColor]"
            style={{
              top: -4,
              left: "50%",
              color: ["#22D3EE", "#A78BFA", "#F0ABFC"][i],
              background: "currentColor",
              transformOrigin: `0 ${r}px`,
              animation: `spin ${8 + i * 3}s linear infinite`,
            }}
          />
        </span>
      ))}
      {/* Core */}
      <div className="relative flex h-20 w-20 items-center justify-center rounded-full bg-ai-gradient shadow-[0_0_60px_rgba(192,132,252,0.55)]">
        <div className="absolute inset-1 rounded-full bg-[#F5F5F7]/60 backdrop-blur" />
        <Sparkles className="relative h-7 w-7 text-[#1D1D1F]" />
      </div>
    </div>
  );
}