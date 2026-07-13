import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import {
  ArrowLeft,
  Search,
  Plus,
  Minus,
  Copy,
  GripVertical,
  Trash2,
  Sparkles,
  X,
  Check,
} from "lucide-react";

export const Route = createFileRoute("/routine/quick-add")({
  validateSearch: (search: Record<string, unknown>) => ({
    activity: (search.activity as ActivityType | undefined) ?? "gym",
    day: (search.day as string | undefined) ?? "Lunes",
  }),
  head: () => ({
    meta: [
      { title: "Añadir ejercicios rápido — Personal TrAIner" },
      {
        name: "description",
        content:
          "Modo rápido para añadir ejercicios a un día de rutina: catálogo con autocompletado, chips y steppers.",
      },
    ],
  }),
  component: QuickAddExercisePage,
});

/* ---------- Design tokens (Apple-like light) ---------- */
const theme = {
  bg: "#F5F5F7",
  card: "#FFFFFF",
  surface: "#ECECEF",
  border: "rgba(0,0,0,0.06)",
  text: "#1D1D1F",
  muted: "#6E6E73",
  faint: "#8E8E93",
  radius: 22,
  cardShadow:
    "0 1px 2px rgba(0,0,0,0.04), 0 8px 24px -12px rgba(0,0,0,0.08)",
  titleFont:
    "Outfit, Inter, -apple-system, 'SF Pro Display', system-ui, sans-serif",
  bodyFont:
    "Manrope, Inter, -apple-system, 'SF Pro Text', system-ui, sans-serif",
};

const ACTIVITY_COLORS: Record<ActivityType, string> = {
  gym: "#059669",
  cardio: "#2563EB",
  calistenia: "#D97706",
  yoga: "#7C3AED",
  deportes: "#EC4899",
};

type ActivityType = "gym" | "cardio" | "calistenia" | "yoga" | "deportes";

/* ---------- Domain types (names match backend contract) ---------- */
type Exercise = {
  id: string; // local UI id
  name: string;
  sets?: number;
  reps?: string;
  weight?: number;
  duration?: string;
  notes?: string;
};

type CatalogItem = {
  nombre: string;
  grupo_muscular: MuscleGroup;
  equipamiento: string;
  descripcion: string;
};

type MuscleGroup =
  | "Pecho"
  | "Espalda"
  | "Piernas"
  | "Hombros"
  | "Brazos"
  | "Core"
  | "Cardio";

const MUSCLE_GROUPS: MuscleGroup[] = [
  "Pecho",
  "Espalda",
  "Piernas",
  "Hombros",
  "Brazos",
  "Core",
  "Cardio",
];

const REP_CHIPS = ["6-8", "8-12", "12-15", "AMRAP"];

/* ---------- Mock catalog ---------- */
const CATALOG: CatalogItem[] = [
  { nombre: "Press banca", grupo_muscular: "Pecho", equipamiento: "Barra", descripcion: "Fuerza pectoral" },
  { nombre: "Press inclinado mancuerna", grupo_muscular: "Pecho", equipamiento: "Mancuernas", descripcion: "Pecho superior" },
  { nombre: "Aperturas polea", grupo_muscular: "Pecho", equipamiento: "Polea", descripcion: "Aislamiento pecho" },
  { nombre: "Fondos en paralelas", grupo_muscular: "Pecho", equipamiento: "Peso corporal", descripcion: "Pecho + tríceps" },
  { nombre: "Dominadas", grupo_muscular: "Espalda", equipamiento: "Barra", descripcion: "Dorsal" },
  { nombre: "Remo con barra", grupo_muscular: "Espalda", equipamiento: "Barra", descripcion: "Grosor de espalda" },
  { nombre: "Jalón al pecho", grupo_muscular: "Espalda", equipamiento: "Polea", descripcion: "Dorsal ancho" },
  { nombre: "Remo mancuerna", grupo_muscular: "Espalda", equipamiento: "Mancuernas", descripcion: "Unilateral" },
  { nombre: "Sentadilla", grupo_muscular: "Piernas", equipamiento: "Barra", descripcion: "Cuádriceps" },
  { nombre: "Peso muerto rumano", grupo_muscular: "Piernas", equipamiento: "Barra", descripcion: "Isquios y glúteo" },
  { nombre: "Prensa", grupo_muscular: "Piernas", equipamiento: "Máquina", descripcion: "Piernas" },
  { nombre: "Zancadas", grupo_muscular: "Piernas", equipamiento: "Mancuernas", descripcion: "Unilateral pierna" },
  { nombre: "Curl femoral", grupo_muscular: "Piernas", equipamiento: "Máquina", descripcion: "Isquios" },
  { nombre: "Press militar", grupo_muscular: "Hombros", equipamiento: "Barra", descripcion: "Deltoides" },
  { nombre: "Elevaciones laterales", grupo_muscular: "Hombros", equipamiento: "Mancuernas", descripcion: "Deltoide medio" },
  { nombre: "Face pull", grupo_muscular: "Hombros", equipamiento: "Polea", descripcion: "Deltoide posterior" },
  { nombre: "Curl bíceps barra", grupo_muscular: "Brazos", equipamiento: "Barra", descripcion: "Bíceps" },
  { nombre: "Curl martillo", grupo_muscular: "Brazos", equipamiento: "Mancuernas", descripcion: "Braquial" },
  { nombre: "Press francés", grupo_muscular: "Brazos", equipamiento: "Barra Z", descripcion: "Tríceps" },
  { nombre: "Extensión tríceps polea", grupo_muscular: "Brazos", equipamiento: "Polea", descripcion: "Tríceps" },
  { nombre: "Plancha", grupo_muscular: "Core", equipamiento: "Peso corporal", descripcion: "Estabilidad" },
  { nombre: "Crunch abdominal", grupo_muscular: "Core", equipamiento: "Peso corporal", descripcion: "Abdomen" },
  { nombre: "Rueda abdominal", grupo_muscular: "Core", equipamiento: "Rueda", descripcion: "Core anti-extensión" },
  { nombre: "Carrera continua", grupo_muscular: "Cardio", equipamiento: "Cinta", descripcion: "Aeróbico" },
  { nombre: "HIIT bicicleta", grupo_muscular: "Cardio", equipamiento: "Bicicleta", descripcion: "Intervalos" },
  { nombre: "Remo indoor", grupo_muscular: "Cardio", equipamiento: "Remo", descripcion: "Cuerpo completo" },
];

function newId() {
  return Math.random().toString(36).slice(2, 10);
}

function defaultsFor(activity: ActivityType): Partial<Exercise> {
  if (activity === "gym" || activity === "calistenia") {
    return { sets: 3, reps: "8-12" };
  }
  if (activity === "cardio") return { duration: "20 min" };
  if (activity === "yoga") return { duration: "30 min" };
  return { duration: "45 min" };
}

function QuickAddExercisePage() {
  const navigate = useNavigate();
  const search = Route.useSearch() as { activity?: ActivityType; day?: string };
  const activity: ActivityType = search.activity ?? "gym";
  const day = search.day ?? "Lunes";
  const accent = ACTIVITY_COLORS[activity];

  const [query, setQuery] = useState("");
  const [group, setGroup] = useState<MuscleGroup | "Todos">("Todos");
  const [added, setAdded] = useState<Exercise[]>([]);
  const [customOpen, setCustomOpen] = useState(false);

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    return CATALOG.filter((c) => {
      if (group !== "Todos" && c.grupo_muscular !== group) return false;
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
    setAdded((prev) => [
      ...prev,
      { id: newId(), name: c.nombre, ...base },
    ]);
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
    // Persist to sessionStorage so RoutineBuilder can pick it up.
    try {
      const payload = { day_of_week: day, exercises: added };
      sessionStorage.setItem("quickAdd:lastDay", JSON.stringify(payload));
    } catch {
      /* no-op */
    }
    void navigate({ to: "/routine/builder" });
  };

  return (
    <div
      className="min-h-screen w-full"
      style={{
        background: theme.bg,
        color: theme.text,
        fontFamily: theme.bodyFont,
      }}
    >
      <div className="mx-auto w-full max-w-[440px] px-5 pb-32 pt-4">
        <TopBar day={day} activity={activity} accent={accent} />

        {/* Search */}
        <div
          className="mt-4 flex items-center gap-2 rounded-2xl px-3.5 py-3"
          style={{
            background: theme.card,
            border: `1px solid ${theme.border}`,
            boxShadow: theme.cardShadow,
          }}
        >
          <Search className="h-4 w-4" style={{ color: theme.faint }} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Busca ejercicio, grupo o equipo…"
            className="w-full bg-transparent text-[14px] outline-none placeholder:text-[#8E8E93]"
            style={{ color: theme.text }}
            autoFocus
          />
          {query && (
            <button
              onClick={() => setQuery("")}
              aria-label="Limpiar"
              className="grid h-6 w-6 place-items-center rounded-full"
              style={{ background: theme.surface }}
            >
              <X className="h-3 w-3" style={{ color: theme.muted }} />
            </button>
          )}
        </div>

        {/* Group chips */}
        <div className="mt-3 -mx-1 flex gap-2 overflow-x-auto pb-1 px-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {(["Todos", ...MUSCLE_GROUPS] as const).map((g) => {
            const active = group === g;
            return (
              <button
                key={g}
                onClick={() => setGroup(g)}
                className="shrink-0 rounded-full px-3.5 py-1.5 text-[12px] font-semibold transition"
                style={{
                  background: active ? accent : theme.card,
                  color: active ? "#FFFFFF" : theme.text,
                  border: `1px solid ${active ? accent : theme.border}`,
                }}
              >
                {g}
              </button>
            );
          })}
        </div>

        {/* Added list */}
        {added.length > 0 && (
          <section className="mt-5">
            <div className="mb-2 flex items-center justify-between px-1">
              <p
                className="text-[10px] font-semibold uppercase tracking-[0.16em]"
                style={{ color: theme.muted }}
              >
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

        {/* Catalog results */}
        <section className="mt-6">
          <p
            className="mb-2 px-1 text-[10px] font-semibold uppercase tracking-[0.16em]"
            style={{ color: theme.muted }}
          >
            Catálogo
          </p>
          {grouped.length === 0 ? (
            <EmptyState onCustom={() => setCustomOpen(true)} />
          ) : (
            <div className="space-y-4">
              {grouped.map(([g, items]) => (
                <div key={g}>
                  <p
                    className="mb-1.5 px-1 text-[11px] font-semibold"
                    style={{ color: theme.text, fontFamily: theme.titleFont }}
                  >
                    {g}
                  </p>
                  <div
                    className="overflow-hidden rounded-2xl"
                    style={{
                      background: theme.card,
                      border: `1px solid ${theme.border}`,
                      boxShadow: theme.cardShadow,
                    }}
                  >
                    {items.map((c, idx) => (
                      <button
                        key={c.nombre}
                        onClick={() => addFromCatalog(c)}
                        className="flex w-full items-center gap-3 px-3.5 py-3 text-left transition active:scale-[0.99]"
                        style={{
                          borderTop:
                            idx === 0
                              ? "none"
                              : `1px solid ${theme.border}`,
                        }}
                      >
                        <div
                          className="grid h-9 w-9 shrink-0 place-items-center rounded-full"
                          style={{ background: `${accent}14`, color: accent }}
                        >
                          <Plus className="h-4 w-4" strokeWidth={2.5} />
                        </div>
                        <div className="min-w-0 flex-1">
                          <p
                            className="truncate text-[13.5px] font-semibold"
                            style={{ color: theme.text }}
                          >
                            {c.nombre}
                          </p>
                          <p
                            className="truncate text-[11px]"
                            style={{ color: theme.muted }}
                          >
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

      {/* Floating custom button */}
      <button
        onClick={() => setCustomOpen(true)}
        className="fixed left-1/2 z-30 flex -translate-x-1/2 items-center gap-2 rounded-full px-4 py-2.5 text-[12.5px] font-semibold text-white shadow-lg transition active:scale-95"
        style={{
          bottom: "calc(env(safe-area-inset-bottom, 0px) + 88px)",
          background: `linear-gradient(135deg, ${accent}, ${accent}CC)`,
        }}
      >
        <Sparkles className="h-4 w-4" />
        Ejercicio personalizado
      </button>

      {/* Sticky save bar */}
      <div
        className="fixed inset-x-0 bottom-0 z-20 border-t backdrop-blur-xl"
        style={{
          background: "rgba(245,245,247,0.85)",
          borderColor: theme.border,
          paddingBottom: "env(safe-area-inset-bottom, 0px)",
        }}
      >
        <div className="mx-auto flex w-full max-w-[440px] items-center gap-3 px-5 py-3">
          <div className="min-w-0 flex-1">
            <p className="text-[11px]" style={{ color: theme.muted }}>
              {added.length === 0
                ? "Añade al menos un ejercicio"
                : `${added.length} ejercicio${added.length === 1 ? "" : "s"} listos`}
            </p>
            <p
              className="truncate text-[13px] font-semibold"
              style={{ color: theme.text }}
            >
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

function TopBar({
  day,
  activity,
  accent,
}: {
  day: string;
  activity: ActivityType;
  accent: string;
}) {
  return (
    <div className="grid grid-cols-[auto_1fr_auto] items-center gap-3">
      <Link
        to="/routine/builder"
        aria-label="Volver"
        className="grid h-9 w-9 place-items-center rounded-full"
        style={{ background: theme.card, border: `1px solid ${theme.border}` }}
      >
        <ArrowLeft className="h-4 w-4" style={{ color: theme.text }} />
      </Link>
      <div className="min-w-0 text-center">
        <p
          className="text-[10px] font-semibold uppercase tracking-[0.18em]"
          style={{ color: theme.muted }}
        >
          Añadir rápido · {activity}
        </p>
        <h1
          className="mt-0.5 truncate text-[16px] font-bold tracking-tight"
          style={{ color: theme.text, fontFamily: theme.titleFont }}
        >
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
  );
}

function AddedExerciseCard({
  exercise,
  activity,
  accent,
  index,
  total,
  onUpdate,
  onRemove,
  onDuplicate,
  onMove,
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
  const showWeight = activity === "gym";
  const showDuration =
    activity === "cardio" || activity === "yoga" || activity === "deportes";
  const [manualReps, setManualReps] = useState(false);

  return (
    <div
      className="rounded-2xl p-3.5"
      style={{
        background: theme.card,
        border: `1px solid ${theme.border}`,
        boxShadow: theme.cardShadow,
      }}
    >
      <div className="flex items-start gap-2">
        <div className="flex flex-col items-center gap-1 pt-0.5">
          <button
            onClick={() => onMove(-1)}
            disabled={index === 0}
            className="disabled:opacity-30"
            aria-label="Subir"
          >
            <GripVertical
              className="h-4 w-4"
              style={{ color: theme.faint }}
            />
          </button>
          <span
            className="text-[9px] font-bold tabular-nums"
            style={{ color: theme.muted }}
          >
            {index + 1}/{total}
          </span>
          <button
            onClick={() => onMove(1)}
            disabled={index === total - 1}
            className="disabled:opacity-30"
            aria-label="Bajar"
          >
            <GripVertical
              className="h-4 w-4 rotate-180"
              style={{ color: theme.faint }}
            />
          </button>
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <p
              className="min-w-0 flex-1 truncate text-[14px] font-semibold"
              style={{ color: theme.text, fontFamily: theme.titleFont }}
            >
              {exercise.name}
            </p>
            <button
              onClick={onDuplicate}
              aria-label="Duplicar"
              className="grid h-7 w-7 place-items-center rounded-full"
              style={{ background: theme.surface }}
            >
              <Copy className="h-3.5 w-3.5" style={{ color: theme.muted }} />
            </button>
            <button
              onClick={onRemove}
              aria-label="Eliminar"
              className="grid h-7 w-7 place-items-center rounded-full"
              style={{ background: theme.surface }}
            >
              <Trash2 className="h-3.5 w-3.5" style={{ color: "#FF3B30" }} />
            </button>
          </div>

          {/* Sets stepper (only gym/calistenia) */}
          {(activity === "gym" || activity === "calistenia") && (
            <div className="mt-3 flex items-center gap-3">
              <p
                className="w-14 text-[11px] font-semibold uppercase tracking-wide"
                style={{ color: theme.muted }}
              >
                Series
              </p>
              <div
                className="flex items-center gap-1 rounded-full p-1"
                style={{ background: theme.surface }}
              >
                <button
                  onClick={() =>
                    onUpdate({ sets: Math.max(1, (exercise.sets ?? 1) - 1) })
                  }
                  className="grid h-7 w-7 place-items-center rounded-full bg-white"
                  style={{ border: `1px solid ${theme.border}` }}
                  aria-label="Menos series"
                >
                  <Minus className="h-3.5 w-3.5" style={{ color: theme.text }} />
                </button>
                <span
                  className="min-w-6 text-center text-[13px] font-bold tabular-nums"
                  style={{ color: theme.text }}
                >
                  {exercise.sets ?? 0}
                </span>
                <button
                  onClick={() =>
                    onUpdate({ sets: Math.min(10, (exercise.sets ?? 0) + 1) })
                  }
                  className="grid h-7 w-7 place-items-center rounded-full bg-white"
                  style={{ border: `1px solid ${theme.border}` }}
                  aria-label="Más series"
                >
                  <Plus className="h-3.5 w-3.5" style={{ color: theme.text }} />
                </button>
              </div>
            </div>
          )}

          {/* Reps chips */}
          {(activity === "gym" || activity === "calistenia") && (
            <div className="mt-2.5 flex flex-wrap items-center gap-1.5">
              <p
                className="w-14 text-[11px] font-semibold uppercase tracking-wide"
                style={{ color: theme.muted }}
              >
                Reps
              </p>
              {REP_CHIPS.map((r) => {
                const active = !manualReps && exercise.reps === r;
                return (
                  <button
                    key={r}
                    onClick={() => {
                      setManualReps(false);
                      onUpdate({ reps: r });
                    }}
                    className="rounded-full px-2.5 py-1 text-[11.5px] font-semibold"
                    style={{
                      background: active ? accent : theme.surface,
                      color: active ? "#FFFFFF" : theme.text,
                    }}
                  >
                    {r}
                  </button>
                );
              })}
              <button
                onClick={() => setManualReps((v) => !v)}
                className="rounded-full px-2.5 py-1 text-[11.5px] font-semibold"
                style={{
                  background: manualReps ? accent : theme.surface,
                  color: manualReps ? "#FFFFFF" : theme.text,
                }}
              >
                Manual
              </button>
              {manualReps && (
                <input
                  value={exercise.reps ?? ""}
                  onChange={(e) => onUpdate({ reps: e.target.value })}
                  placeholder="ej. 5x5"
                  className="ml-1 w-16 rounded-full px-2.5 py-1 text-[11.5px] font-semibold outline-none"
                  style={{
                    background: theme.surface,
                    color: theme.text,
                    border: `1px solid ${theme.border}`,
                  }}
                />
              )}
            </div>
          )}

          {/* Weight (gym only) */}
          {showWeight && (
            <div className="mt-2.5 flex items-center gap-3">
              <p
                className="w-14 text-[11px] font-semibold uppercase tracking-wide"
                style={{ color: theme.muted }}
              >
                Peso
              </p>
              <input
                type="number"
                inputMode="decimal"
                value={exercise.weight ?? ""}
                onChange={(e) =>
                  onUpdate({
                    weight:
                      e.target.value === ""
                        ? undefined
                        : Number(e.target.value),
                  })
                }
                placeholder="—"
                className="w-20 rounded-full px-3 py-1 text-[12.5px] font-semibold outline-none"
                style={{
                  background: theme.surface,
                  color: theme.text,
                  border: `1px solid ${theme.border}`,
                }}
              />
              <span className="text-[11px]" style={{ color: theme.muted }}>
                kg
              </span>
            </div>
          )}

          {/* Duration (cardio / yoga / deportes) */}
          {showDuration && (
            <div className="mt-3 flex items-center gap-3">
              <p
                className="w-14 text-[11px] font-semibold uppercase tracking-wide"
                style={{ color: theme.muted }}
              >
                Duración
              </p>
              <input
                value={exercise.duration ?? ""}
                onChange={(e) => onUpdate({ duration: e.target.value })}
                placeholder="ej. 20 min"
                className="w-28 rounded-full px-3 py-1 text-[12.5px] font-semibold outline-none"
                style={{
                  background: theme.surface,
                  color: theme.text,
                  border: `1px solid ${theme.border}`,
                }}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function EmptyState({ onCustom }: { onCustom: () => void }) {
  return (
    <div
      className="rounded-2xl px-4 py-8 text-center"
      style={{
        background: theme.card,
        border: `1px dashed ${theme.border}`,
      }}
    >
      <p className="text-[13px] font-semibold" style={{ color: theme.text }}>
        Sin resultados
      </p>
      <p className="mt-1 text-[12px]" style={{ color: theme.muted }}>
        Prueba otro término o crea uno personalizado.
      </p>
      <button
        onClick={onCustom}
        className="mt-3 rounded-full px-4 py-2 text-[12px] font-semibold"
        style={{ background: theme.text, color: "#FFFFFF" }}
      >
        Ejercicio personalizado
      </button>
    </div>
  );
}

function CustomExerciseSheet({
  onClose,
  onSubmit,
  accent,
  activity,
}: {
  onClose: () => void;
  onSubmit: (name: string) => void;
  accent: string;
  activity: ActivityType;
}) {
  const [name, setName] = useState("");
  return (
    <div
      className="fixed inset-0 z-40 flex items-end justify-center"
      style={{ background: "rgba(0,0,0,0.35)" }}
      onClick={onClose}
    >
      <div
        className="w-full max-w-[440px] rounded-t-3xl p-5"
        style={{ background: theme.bg }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mx-auto mb-3 h-1 w-10 rounded-full" style={{ background: theme.surface }} />
        <p
          className="text-[10px] font-semibold uppercase tracking-[0.18em]"
          style={{ color: theme.muted }}
        >
          Ejercicio personalizado · {activity}
        </p>
        <h3
          className="mt-1 text-[18px] font-bold"
          style={{ color: theme.text, fontFamily: theme.titleFont }}
        >
          Añade tu ejercicio
        </h3>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Nombre del ejercicio"
          autoFocus
          className="mt-3 w-full rounded-2xl px-4 py-3 text-[14px] outline-none"
          style={{
            background: theme.card,
            color: theme.text,
            border: `1px solid ${theme.border}`,
          }}
        />
        <p className="mt-2 text-[11px]" style={{ color: theme.muted }}>
          Solo <b>nombre</b> es obligatorio. El resto lo ajustas en la tarjeta.
        </p>
        <div className="mt-4 flex items-center gap-2">
          <button
            onClick={onClose}
            className="flex-1 rounded-full py-3 text-[13px] font-semibold"
            style={{
              background: theme.card,
              color: theme.text,
              border: `1px solid ${theme.border}`,
            }}
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