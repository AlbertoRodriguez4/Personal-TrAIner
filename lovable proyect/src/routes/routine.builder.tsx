import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import {
  ArrowLeft,
  Plus,
  Dumbbell,
  Bike,
  HeartPulse,
  Wind,
  Trophy,
  Pencil,
  Trash2,
  ChevronRight,
  Zap,
} from "lucide-react";

export const Route = createFileRoute("/routine/builder")({
  head: () => ({
    meta: [
      { title: "Constructor de rutina — Personal TrAIner" },
      {
        name: "description",
        content:
          "Crea rutinas semanales por días. Añade ejercicios con el modo rápido o edítalos con el formulario completo.",
      },
    ],
  }),
  component: RoutineBuilderPage,
});

const theme = {
  bg: "#F5F5F7",
  card: "#FFFFFF",
  surface: "#ECECEF",
  border: "rgba(0,0,0,0.06)",
  text: "#1D1D1F",
  muted: "#6E6E73",
  faint: "#8E8E93",
  cardShadow:
    "0 1px 2px rgba(0,0,0,0.04), 0 8px 24px -12px rgba(0,0,0,0.08)",
  titleFont:
    "Outfit, Inter, -apple-system, 'SF Pro Display', system-ui, sans-serif",
  bodyFont:
    "Manrope, Inter, -apple-system, 'SF Pro Text', system-ui, sans-serif",
};

type ActivityType = "gym" | "cardio" | "calistenia" | "yoga" | "deportes";

const ACTIVITY_COLORS: Record<ActivityType, string> = {
  gym: "#059669",
  cardio: "#2563EB",
  calistenia: "#D97706",
  yoga: "#7C3AED",
  deportes: "#EC4899",
};

const ACTIVITY_ICONS: Record<ActivityType, typeof Dumbbell> = {
  gym: Dumbbell,
  cardio: HeartPulse,
  calistenia: Bike,
  yoga: Wind,
  deportes: Trophy,
};

const DAYS = [
  "Lunes",
  "Martes",
  "Miércoles",
  "Jueves",
  "Viernes",
  "Sábado",
  "Domingo",
] as const;

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

function RoutineBuilderPage() {
  const navigate = useNavigate();
  const [activity, setActivity] = useState<ActivityType>("gym");
  const [routineName, setRoutineName] = useState("Mi nueva rutina");
  const [days, setDays] = useState<RoutineDay[]>(
    DAYS.map((d) => ({ day_of_week: d, focus: "", exercises: [] })),
  );
  const [editing, setEditing] = useState<{ day: string; id: string } | null>(
    null,
  );

  // Merge exercises coming back from QuickAdd via sessionStorage
  useEffect(() => {
    try {
      const raw = sessionStorage.getItem("quickAdd:lastDay");
      if (!raw) return;
      const payload = JSON.parse(raw) as {
        day_of_week: string;
        exercises: Exercise[];
      };
      sessionStorage.removeItem("quickAdd:lastDay");
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

  const updateExercise = (
    dayName: string,
    id: string,
    patch: Partial<Exercise>,
  ) =>
    setDays((prev) =>
      prev.map((d) =>
        d.day_of_week === dayName
          ? {
              ...d,
              exercises: d.exercises.map((e) =>
                e.id === id ? { ...e, ...patch } : e,
              ),
            }
          : d,
      ),
    );

  const updateFocus = (dayName: string, focus: string) =>
    setDays((prev) =>
      prev.map((d) => (d.day_of_week === dayName ? { ...d, focus } : d)),
    );

  return (
    <div
      className="min-h-screen w-full"
      style={{ background: theme.bg, color: theme.text, fontFamily: theme.bodyFont }}
    >
      <div className="mx-auto w-full max-w-[440px] px-5 pb-24 pt-4">
        <TopBar />

        {/* Routine header */}
        <section
          className="mt-4 rounded-2xl p-4"
          style={{
            background: theme.card,
            border: `1px solid ${theme.border}`,
            boxShadow: theme.cardShadow,
          }}
        >
          <p
            className="text-[10px] font-semibold uppercase tracking-[0.18em]"
            style={{ color: theme.muted }}
          >
            Rutina
          </p>
          <input
            value={routineName}
            onChange={(e) => setRoutineName(e.target.value)}
            className="mt-1 w-full bg-transparent text-[20px] font-bold tracking-tight outline-none"
            style={{ color: theme.text, fontFamily: theme.titleFont }}
          />
          <div className="mt-3 -mx-1 flex gap-2 overflow-x-auto pb-1 px-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
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
                    background: active ? color : theme.surface,
                    color: active ? "#FFFFFF" : theme.text,
                    border: `1px solid ${active ? color : theme.border}`,
                  }}
                >
                  <Icon className="h-3.5 w-3.5" />
                  {a}
                </button>
              );
            })}
          </div>
        </section>

        {/* Days */}
        <section className="mt-5 space-y-3">
          {days.map((d) => (
            <div
              key={d.day_of_week}
              className="rounded-2xl p-4"
              style={{
                background: theme.card,
                border: `1px solid ${theme.border}`,
                boxShadow: theme.cardShadow,
              }}
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
                  style={{ color: theme.text }}
                />
                <span
                  className="text-[11px] tabular-nums"
                  style={{ color: theme.muted }}
                >
                  {d.exercises.length}
                </span>
              </div>

              {d.exercises.length > 0 && (
                <ul className="mt-3 space-y-1.5">
                  {d.exercises.map((ex) => {
                    const isOpen =
                      editing?.day === d.day_of_week && editing.id === ex.id;
                    return (
                      <li
                        key={ex.id}
                        className="rounded-xl px-3 py-2"
                        style={{
                          background: theme.surface,
                          border: `1px solid ${theme.border}`,
                        }}
                      >
                        <div className="flex items-center gap-2">
                          <p
                            className="min-w-0 flex-1 truncate text-[12.5px] font-semibold"
                            style={{ color: theme.text }}
                          >
                            {ex.name}
                          </p>
                          <p
                            className="text-[11px] tabular-nums"
                            style={{ color: theme.muted }}
                          >
                            {formatExercise(ex, activity)}
                          </p>
                          <button
                            onClick={() =>
                              setEditing(
                                isOpen
                                  ? null
                                  : { day: d.day_of_week, id: ex.id },
                              )
                            }
                            aria-label="Editar"
                            className="grid h-6 w-6 place-items-center rounded-full bg-white"
                            style={{ border: `1px solid ${theme.border}` }}
                          >
                            <Pencil className="h-3 w-3" style={{ color: theme.muted }} />
                          </button>
                          <button
                            onClick={() =>
                              removeExercise(d.day_of_week, ex.id)
                            }
                            aria-label="Eliminar"
                            className="grid h-6 w-6 place-items-center rounded-full bg-white"
                            style={{ border: `1px solid ${theme.border}` }}
                          >
                            <Trash2 className="h-3 w-3" style={{ color: "#FF3B30" }} />
                          </button>
                        </div>
                        {isOpen && (
                          <FullEditor
                            exercise={ex}
                            activity={activity}
                            onChange={(patch) =>
                              updateExercise(d.day_of_week, ex.id, patch)
                            }
                          />
                        )}
                      </li>
                    );
                  })}
                </ul>
              )}

              <button
                onClick={() =>
                  void navigate({
                    to: "/routine/quick-add",
                    search: { activity, day: d.day_of_week },
                  })
                }
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

function TopBar() {
  return (
    <div className="grid grid-cols-[auto_1fr_auto] items-center gap-3">
      <Link
        to="/"
        aria-label="Volver"
        className="grid h-9 w-9 place-items-center rounded-full"
        style={{ background: theme.card, border: `1px solid ${theme.border}` }}
      >
        <ArrowLeft className="h-4 w-4" style={{ color: theme.text }} />
      </Link>
      <h1
        className="text-center text-[14px] font-semibold tracking-tight"
        style={{ color: theme.text }}
      >
        Constructor de rutina
      </h1>
      <span className="w-9" />
    </div>
  );
}

function formatExercise(ex: Exercise, activity: ActivityType) {
  if (activity === "gym") {
    const parts: string[] = [];
    if (ex.sets) parts.push(`${ex.sets}×${ex.reps ?? "?"}`);
    if (ex.weight != null) parts.push(`${ex.weight}kg`);
    return parts.join(" · ") || "—";
  }
  if (activity === "calistenia") {
    return `${ex.sets ?? "?"}×${ex.reps ?? "?"}`;
  }
  return ex.duration ?? "—";
}

function FullEditor({
  exercise,
  activity,
  onChange,
}: {
  exercise: Exercise;
  activity: ActivityType;
  onChange: (patch: Partial<Exercise>) => void;
}) {
  const showWeight = activity === "gym";
  const showDuration =
    activity === "cardio" || activity === "yoga" || activity === "deportes";
  const showSetsReps = activity === "gym" || activity === "calistenia";
  return (
    <div
      className="mt-2 space-y-2 rounded-xl bg-white p-3"
      style={{ border: `1px solid ${theme.border}` }}
    >
      {showSetsReps && (
        <div className="grid grid-cols-2 gap-2">
          <Field
            label="Series"
            value={exercise.sets?.toString() ?? ""}
            onChange={(v) =>
              onChange({ sets: v === "" ? undefined : Number(v) })
            }
            type="number"
          />
          <Field
            label="Reps"
            value={exercise.reps ?? ""}
            onChange={(v) => onChange({ reps: v })}
          />
        </div>
      )}
      {showWeight && (
        <Field
          label="Peso (kg)"
          value={exercise.weight?.toString() ?? ""}
          onChange={(v) =>
            onChange({ weight: v === "" ? undefined : Number(v) })
          }
          type="number"
        />
      )}
      {showDuration && (
        <Field
          label="Duración"
          value={exercise.duration ?? ""}
          onChange={(v) => onChange({ duration: v })}
        />
      )}
      <div>
        <p
          className="mb-1 text-[10px] font-semibold uppercase tracking-wider"
          style={{ color: theme.muted }}
        >
          Notas
        </p>
        <textarea
          value={exercise.notes ?? ""}
          onChange={(e) => onChange({ notes: e.target.value })}
          rows={2}
          className="w-full resize-none rounded-lg px-2.5 py-1.5 text-[12px] outline-none"
          style={{
            background: theme.surface,
            color: theme.text,
            border: `1px solid ${theme.border}`,
          }}
          placeholder="Ej. RPE 8, controla la excéntrica"
        />
      </div>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
  type = "text",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: "text" | "number";
}) {
  return (
    <div>
      <p
        className="mb-1 text-[10px] font-semibold uppercase tracking-wider"
        style={{ color: theme.muted }}
      >
        {label}
      </p>
      <input
        value={value}
        type={type}
        inputMode={type === "number" ? "decimal" : undefined}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg px-2.5 py-1.5 text-[12px] outline-none"
        style={{
          background: theme.surface,
          color: theme.text,
          border: `1px solid ${theme.border}`,
        }}
      />
    </div>
  );
}

// Keep unused imports referenced to satisfy tsgo strictness in some configs
const _unused = { Plus, ChevronRight };
void _unused;