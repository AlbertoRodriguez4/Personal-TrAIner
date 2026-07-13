import { useMemo, useState } from 'react';
import {
  Apple, Dumbbell, TrendingUp, X, Footprints, Utensils, Flame,
  ChevronLeft, ChevronRight,
} from 'lucide-react';

const theme = {
  bg: '#F5F5F7',
  fg: '#1D1D1F',
  card: '#FFFFFF',
  surface1: '#F5F5F7',
  surface2: '#ECECEF',
  label: '#6E6E73',
  border: 'rgba(0,0,0,0.06)',
  blue: '#0A84FF',
  blueSoft: '#5AC8FA',
  green: '#30D158',
  red: '#FF3B30',
  orange: '#FF9F0A',
  gray: '#E5E5EA',
  radius: 22,
  cardShadow: '0 1px 2px rgba(0,0,0,0.04), 0 8px 24px -12px rgba(0,0,0,0.08)',
} as const;

const titleFont = { fontFamily: 'Outfit, Inter, -apple-system, sans-serif', fontWeight: 700, letterSpacing: '-0.02em' } as const;
const bodyFont = { fontFamily: 'Manrope, Inter, -apple-system, sans-serif' } as const;
const labelStyle = {
  fontSize: 11,
  fontWeight: 600,
  letterSpacing: '1.4px',
  color: theme.label,
  textTransform: 'uppercase' as const,
  ...bodyFont,
};

type Tab = 'nutrition' | 'training' | 'insights';

export function ProgressScreen({ initialTab = 'nutrition' }: { initialTab?: Tab }) {
  const [tab, setTab] = useState<Tab>(initialTab);
  return (
    <div className="min-h-screen w-full" style={{ background: theme.bg, color: theme.fg, ...bodyFont }}>
      <div className="mx-auto w-full max-w-[440px]">
        <div className="px-5 pt-6 pb-2">
          <p style={{ ...labelStyle, fontSize: 13 }}>Progreso · Junio 2026</p>
        </div>
        <Tabs value={tab} onChange={setTab} />
        <div className="flex flex-col" style={{ padding: '12px 20px 40px 20px', gap: 20 }}>
          {tab === 'nutrition' && <NutritionCalendar />}
          {tab === 'training' && <TrainingCalendar />}
          {tab === 'insights' && <UnifiedInsights />}
        </div>
      </div>
    </div>
  );
}

function Tabs({ value, onChange }: { value: Tab; onChange: (t: Tab) => void }) {
  const items: { key: Tab; label: string; Icon: typeof Apple }[] = [
    { key: 'nutrition', label: 'Nutrición', Icon: Apple },
    { key: 'training', label: 'Entrenos', Icon: Dumbbell },
    { key: 'insights', label: 'Insights', Icon: TrendingUp },
  ];
  return (
    <div className="mx-5 mt-2 grid grid-cols-3 gap-1 rounded-2xl p-1" style={{ background: theme.surface1 }}>
      {items.map(({ key, label, Icon }) => {
        const active = value === key;
        return (
          <button
            key={key}
            onClick={() => onChange(key)}
            className="flex items-center justify-center gap-1.5 rounded-xl py-2 transition"
            style={{
              background: active ? theme.surface2 : 'transparent',
              color: active ? theme.fg : theme.label,
            }}
          >
            <Icon className="h-3.5 w-3.5" strokeWidth={2.25} />
            <span style={{ fontSize: 12, fontWeight: 600 }}>{label}</span>
          </button>
        );
      })}
    </div>
  );
}

type DayCell = { day: number; status: 'done' | 'over' | 'future' | 'rest' };

function buildJune2026(kind: 'nutrition' | 'training'): DayCell[] {
  const cells: DayCell[] = [];
  for (let d = 1; d <= 30; d++) {
    if (kind === 'nutrition') {
      let status: DayCell['status'] = 'future';
      if (d < 25) status = ([3, 9, 14, 21].includes(d) ? 'over' : 'done');
      cells.push({ day: d, status });
    } else {
      let status: DayCell['status'] = 'future';
      if (d < 25) {
        if ([1, 3, 5, 8, 10, 12, 15, 17, 19, 22].includes(d)) status = 'done';
        else status = 'rest';
      } else {
        if ([26, 29].includes(d)) status = 'over';
        else status = 'future';
      }
      cells.push({ day: d, status });
    }
  }
  return cells;
}

function MonthHeader({ title }: { title: string }) {
  return (
    <div className="flex items-center justify-between">
      <button className="grid h-8 w-8 place-items-center rounded-full" style={{ background: theme.surface1, color: theme.label }}>
        <ChevronLeft className="h-4 w-4" />
      </button>
      <p style={{ ...titleFont, fontSize: 16, color: theme.fg }}>{title}</p>
      <button className="grid h-8 w-8 place-items-center rounded-full" style={{ background: theme.surface1, color: theme.label }}>
        <ChevronRight className="h-4 w-4" />
      </button>
    </div>
  );
}

function Weekdays() {
  return (
    <div className="grid grid-cols-7 gap-1.5">
      {['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((d) => (
        <span key={d} className="text-center" style={{ ...labelStyle, fontSize: 10 }}>
          {d}
        </span>
      ))}
    </div>
  );
}

function NutritionCalendar() {
  const days = useMemo(() => buildJune2026('nutrition'), []);
  const [openDay, setOpenDay] = useState<number | null>(null);

  return (
    <>
      <section style={{ background: theme.card, borderRadius: theme.radius, padding: 18, boxShadow: theme.cardShadow, border: `1px solid ${theme.border}` }}>
        <MonthHeader title="Junio 2026" />
        <div className="mt-4">
          <Weekdays />
          <div className="mt-2 grid grid-cols-7 gap-1.5">
            {days.map((c) => (
              <button
                key={c.day}
                onClick={() => c.status !== 'future' && setOpenDay(c.day)}
                className="aspect-square"
                aria-label={`Día ${c.day}`}
              >
                <NutritionRing day={c.day} status={c.status} highlight={c.day === 15} />
              </button>
            ))}
          </div>
        </div>
        <Legend
          items={[
            { color: theme.green, label: 'Objetivo' },
            { color: theme.red, label: 'Exceso' },
            { color: theme.gray, label: 'Futuro' },
          ]}
        />
      </section>

      <MonthlySummary
        items={[
          { label: 'Días en objetivo', value: '18' },
          { label: 'Excesos', value: '4' },
          { label: 'Media kcal', value: '2 040' },
        ]}
      />

      {openDay !== null && <DailySheet day={openDay} onClose={() => setOpenDay(null)} />}
    </>
  );
}

function NutritionRing({ day, status, highlight }: { day: number; status: DayCell['status']; highlight?: boolean }) {
  const colorMap = { done: theme.green, over: theme.red, future: theme.gray, rest: theme.gray };
  const color = colorMap[status];
  const pct = status === 'done' ? 0.92 : status === 'over' ? 1 : 0;
  const r = 16;
  const c = 2 * Math.PI * r;
  return (
    <div className="relative grid h-full w-full place-items-center">
      <svg viewBox="0 0 40 40" className="h-full w-full -rotate-90">
        <circle cx="20" cy="20" r={r} stroke={theme.surface2} strokeWidth="3" fill="none" />
        {pct > 0 && (
          <circle
            cx="20" cy="20" r={r}
            stroke={color} strokeWidth="3" fill="none"
            strokeDasharray={c} strokeDashoffset={c * (1 - pct)}
            strokeLinecap="round"
          />
        )}
      </svg>
      <span
        className="absolute"
        style={{
          fontSize: 11,
          fontWeight: 700,
          color: status === 'future' ? theme.label : theme.fg,
          ...bodyFont,
        }}
      >
        {day}
      </span>
      {highlight && (
        <span
          className="absolute -bottom-0.5 h-1 w-1 rounded-full"
          style={{ background: theme.blue, boxShadow: `0 0 6px ${theme.blue}` }}
        />
      )}
    </div>
  );
}

function Legend({ items }: { items: { color: string; label: string }[] }) {
  return (
    <div className="mt-4 flex flex-wrap items-center gap-x-4 gap-y-2">
      {items.map((i) => (
        <span key={i.label} className="flex items-center gap-1.5" style={{ fontSize: 11, color: theme.label, ...bodyFont }}>
          <span className="h-2 w-2 rounded-full" style={{ background: i.color }} />
          {i.label}
        </span>
      ))}
    </div>
  );
}

function MonthlySummary({ items }: { items: { label: string; value: string }[] }) {
  return (
    <section className="grid grid-cols-3 gap-3">
      {items.map((i) => (
        <div key={i.label} style={{ background: theme.card, borderRadius: 18, padding: 14, boxShadow: theme.cardShadow, border: `1px solid ${theme.border}` }}>
          <p style={{ ...labelStyle, fontSize: 9 }}>{i.label}</p>
          <p className="mt-1.5" style={{ ...titleFont, fontSize: 18, color: theme.fg }}>
            {i.value}
          </p>
        </div>
      ))}
    </section>
  );
}

function DailySheet({ day, onClose }: { day: number; onClose: () => void }) {
  const macros = [
    { name: 'Proteína', value: 142, goal: 150, color: theme.blue, unit: 'g' },
    { name: 'Carbs', value: 268, goal: 240, color: theme.orange, unit: 'g' },
    { name: 'Grasas', value: 68, goal: 65, color: theme.green, unit: 'g' },
  ];
  const meals = [
    { name: 'Desayuno', kcal: 480, items: 'Avena · plátano · café' },
    { name: 'Comida', kcal: 820, items: 'Pollo · arroz · ensalada' },
    { name: 'Snack', kcal: 220, items: 'Yogur griego · nueces' },
    { name: 'Cena', kcal: 580, items: 'Salmón · brócoli · patata' },
  ];

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center"
      style={{ background: 'rgba(0,0,0,0.55)' }}
      onClick={onClose}
    >
      <div
        className="w-full max-w-[440px] slide-in-from-bottom"
        onClick={(e) => e.stopPropagation()}
        style={{
          background: theme.card,
          borderTopLeftRadius: 28,
          borderTopRightRadius: 28,
          padding: '14px 20px 28px 20px',
          maxHeight: '85vh',
          overflow: 'auto',
        }}
      >
        <div className="mx-auto h-1 w-10 rounded-full" style={{ background: theme.surface2 }} />
        <div className="mt-4 flex items-start justify-between">
          <div>
            <p style={labelStyle}>Resumen diario</p>
            <h2 className="mt-1" style={{ ...titleFont, fontSize: 22, color: theme.fg }}>
              {day} de junio, 2026
            </h2>
          </div>
          <button
            onClick={onClose}
            className="grid h-9 w-9 place-items-center rounded-full"
            style={{ background: theme.surface1, color: theme.label }}
            aria-label="Cerrar"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="mt-5 flex items-center gap-4 rounded-2xl p-4" style={{ background: theme.surface1 }}>
          <div className="relative grid h-20 w-20 place-items-center">
            <svg viewBox="0 0 40 40" className="h-full w-full -rotate-90">
              <circle cx="20" cy="20" r="17" stroke={theme.surface2} strokeWidth="3.5" fill="none" />
              <circle cx="20" cy="20" r="17" stroke={theme.red} strokeWidth="3.5" fill="none"
                strokeDasharray={2 * Math.PI * 17} strokeDashoffset={0} strokeLinecap="round" />
            </svg>
            <Flame className="absolute h-5 w-5" style={{ color: theme.red }} />
          </div>
          <div className="min-w-0">
            <p style={labelStyle}>Calorías</p>
            <p className="mt-1" style={{ ...titleFont, fontSize: 22, color: theme.fg, lineHeight: 1 }}>
              2 100 <span style={{ fontSize: 13, color: theme.label, fontWeight: 600 }}>/ 2 000 kcal</span>
            </p>
            <p className="mt-1" style={{ fontSize: 12, color: theme.red, ...bodyFont }}>
              +100 kcal sobre el objetivo
            </p>
          </div>
        </div>

        <p className="mt-6" style={labelStyle}>Macros</p>
        <ul className="mt-3 space-y-3">
          {macros.map((m) => {
            const pct = Math.min(120, Math.round((m.value / m.goal) * 100));
            const over = m.value > m.goal;
            return (
              <li key={m.name}>
                <div className="flex items-baseline justify-between">
                  <span style={{ fontSize: 13, fontWeight: 600, color: theme.fg, ...bodyFont }}>{m.name}</span>
                  <span style={{ fontSize: 12, color: over ? theme.red : theme.label, ...bodyFont }}>
                    {m.value}/{m.goal}{m.unit}
                  </span>
                </div>
                <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full" style={{ background: theme.surface2 }}>
                  <div className="h-full rounded-full" style={{ width: `${Math.min(100, pct)}%`, background: m.color }} />
                </div>
              </li>
            );
          })}
        </ul>

        <p className="mt-6" style={labelStyle}>Comidas</p>
        <ul className="mt-3 space-y-2">
          {meals.map((meal) => (
            <li key={meal.name} className="flex items-center gap-3 rounded-2xl p-3" style={{ background: theme.surface1 }}>
              <div className="grid h-9 w-9 shrink-0 place-items-center rounded-xl" style={{ background: theme.surface2, color: theme.blueSoft }}>
                <Utensils className="h-4 w-4" strokeWidth={2.25} />
              </div>
              <div className="min-w-0 flex-1">
                <p style={{ fontSize: 13, fontWeight: 600, color: theme.fg, ...bodyFont, lineHeight: 1.1 }}>
                  {meal.name}
                </p>
                <p className="mt-0.5 truncate" style={{ fontSize: 11, color: theme.label, ...bodyFont }}>
                  {meal.items}
                </p>
              </div>
              <span style={{ ...titleFont, fontSize: 14, color: theme.fg }}>{meal.kcal}<span style={{ fontSize: 10, color: theme.label, fontWeight: 600 }}> kcal</span></span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

function TrainingCalendar() {
  const days = useMemo(() => buildJune2026('training'), []);
  const iconFor = (d: number) => {
    if ([1, 8, 15, 22, 29].includes(d)) return Dumbbell;
    if ([3, 10, 17].includes(d)) return Footprints;
    if ([5, 12, 19, 26].includes(d)) return Dumbbell;
    return null;
  };

  return (
    <>
      <section style={{ background: theme.card, borderRadius: theme.radius, padding: 18, boxShadow: theme.cardShadow, border: `1px solid ${theme.border}` }}>
        <MonthHeader title="Junio 2026" />
        <div className="mt-4">
          <Weekdays />
          <div className="mt-2 grid grid-cols-7 gap-1.5">
            {days.map((c) => {
              const Icon = iconFor(c.day);
              const dot = c.status === 'done' ? theme.blue : c.status === 'over' ? theme.orange : null;
              return (
                <div
                  key={c.day}
                  className="relative aspect-square rounded-xl"
                  style={{ background: theme.surface1, border: `1px solid ${theme.border}` }}
                >
                  <span
                    className="absolute left-1.5 top-1"
                    style={{ fontSize: 10, fontWeight: 600, color: c.status === 'future' ? theme.label : theme.fg, ...bodyFont }}
                  >
                    {c.day}
                  </span>
                  {Icon && (
                    <Icon
                      className="absolute bottom-1.5 right-1.5 h-3 w-3"
                      style={{ color: c.status === 'done' ? theme.blueSoft : theme.label }}
                      strokeWidth={2.25}
                    />
                  )}
                  {dot && (
                    <span
                      className="absolute bottom-1 left-1 h-1.5 w-1.5 rounded-full"
                      style={{ background: dot, boxShadow: `0 0 6px ${dot}` }}
                    />
                  )}
                </div>
              );
            })}
          </div>
        </div>
        <Legend
          items={[
            { color: theme.blue, label: 'Completado' },
            { color: theme.orange, label: 'Programado' },
            { color: theme.gray, label: 'Descanso' },
          ]}
        />
      </section>

      <WeeklyVolumeChart />
    </>
  );
}

function WeeklyVolumeChart() {
  const weeks = [
    { label: 'S1', tonnage: 8.4 },
    { label: 'S2', tonnage: 10.2 },
    { label: 'S3', tonnage: 9.6 },
    { label: 'S4', tonnage: 12.1 },
  ];
  const max = Math.max(...weeks.map((w) => w.tonnage));
  return (
    <section style={{ background: theme.card, borderRadius: theme.radius, padding: 18, boxShadow: theme.cardShadow, border: `1px solid ${theme.border}` }}>
      <div className="flex items-baseline justify-between">
        <p style={labelStyle}>Volumen semanal · Tonelaje</p>
        <span style={{ fontSize: 11, color: theme.green, fontWeight: 600 }}>+18% vs mes anterior</span>
      </div>
      <div className="mt-5 flex h-36 items-end justify-between gap-3">
        {weeks.map((w, i) => {
          const h = (w.tonnage / max) * 100;
          const isPeak = i === weeks.length - 1;
          return (
            <div key={w.label} className="flex flex-1 flex-col items-center gap-2">
              <span style={{ fontSize: 11, fontWeight: 700, color: isPeak ? theme.green : theme.fg, ...bodyFont }}>
                {w.tonnage}t
              </span>
              <div
                className="w-full rounded-t-lg"
                style={{
                  height: `${h}%`,
                  background: isPeak
                    ? `linear-gradient(180deg, ${theme.green}, ${theme.blue})`
                    : `linear-gradient(180deg, ${theme.blueSoft}, ${theme.blue})`,
                  opacity: isPeak ? 1 : 0.7,
                }}
              />
              <span style={{ ...labelStyle, fontSize: 9 }}>{w.label}</span>
            </div>
          );
        })}
      </div>
    </section>
  );
}

function UnifiedInsights() {
  return (
    <>
      <section style={{ background: theme.card, borderRadius: theme.radius, padding: 18, boxShadow: theme.cardShadow, border: `1px solid ${theme.border}` }}>
        <div className="flex items-baseline justify-between">
          <p style={labelStyle}>Entrenamientos completados</p>
          <span style={{ fontSize: 11, color: theme.label }}>últimas 8 semanas</span>
        </div>
        <TrainingBars />

        <div className="my-5 h-px w-full" style={{ background: theme.border }} />

        <p style={labelStyle}>Calorías vs plan · Grasa corporal</p>
        <DualLineChart />
        <ChartLegend />
      </section>

      <CorrelationPanel />
    </>
  );
}

function TrainingBars() {
  const data = [3, 4, 4, 5, 3, 5, 4, 6];
  const max = 6;
  return (
    <div className="mt-4 flex h-24 items-end justify-between gap-2">
      {data.map((v, i) => {
        const h = (v / max) * 100;
        return (
          <div key={i} className="flex flex-1 flex-col items-center gap-1.5">
            <div
              className="w-full rounded-md"
              style={{
                height: `${h}%`,
                background: i === data.length - 1
                  ? `linear-gradient(180deg, ${theme.green}, ${theme.blue})`
                  : theme.blue,
                opacity: i === data.length - 1 ? 1 : 0.55,
              }}
            />
            <span style={{ fontSize: 9, color: theme.label, ...bodyFont }}>S{i + 1}</span>
          </div>
        );
      })}
    </div>
  );
}

function DualLineChart() {
  const cals = [2100, 1980, 2050, 2200, 1950, 2400, 2100, 1900, 2000, 2150, 2080, 2300, 1980, 2020];
  const fat = [22.1, 22.0, 22.0, 21.9, 21.9, 21.8, 21.8, 21.7, 21.6, 21.6, 21.5, 21.5, 21.4, 21.3];
  const plan = 2000;
  const W = 320;
  const H = 130;
  const pad = { l: 8, r: 8, t: 10, b: 10 };
  const innerW = W - pad.l - pad.r;
  const innerH = H - pad.t - pad.b;
  const xStep = innerW / (cals.length - 1);

  const calMin = 1800, calMax = 2500;
  const fatMin = 21.0, fatMax = 22.5;

  const calY = (v: number) => pad.t + innerH - ((v - calMin) / (calMax - calMin)) * innerH;
  const fatY = (v: number) => pad.t + innerH - ((v - fatMin) / (fatMax - fatMin)) * innerH;

  const calPath = cals.map((v, i) => `${i === 0 ? 'M' : 'L'} ${pad.l + i * xStep} ${calY(v)}`).join(' ');
  const fatPath = fat.map((v, i) => `${i === 0 ? 'M' : 'L'} ${pad.l + i * xStep} ${fatY(v)}`).join(' ');
  const planY = calY(plan);

  return (
    <div className="mt-3">
      <svg viewBox={`0 0 ${W} ${H}`} className="h-36 w-full">
        <line x1={pad.l} y1={planY} x2={W - pad.r} y2={planY} stroke={theme.label} strokeDasharray="3 4" strokeWidth="1" opacity="0.5" />
        <text x={W - pad.r} y={planY - 4} textAnchor="end" fontSize="9" fill={theme.label}>
          plan {plan}
        </text>
        <path d={calPath} stroke={theme.orange} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
        <path d={fatPath} stroke={theme.green} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" />
        {cals.map((v, i) => (
          <circle key={`c${i}`} cx={pad.l + i * xStep} cy={calY(v)} r="1.5" fill={theme.orange} />
        ))}
        {fat.map((v, i) => (
          <circle key={`f${i}`} cx={pad.l + i * xStep} cy={fatY(v)} r="1.5" fill={theme.green} />
        ))}
      </svg>
    </div>
  );
}

function ChartLegend() {
  const items = [
    { color: theme.orange, label: 'Calorías diarias' },
    { color: theme.green, label: '% Grasa corporal' },
    { color: theme.label, label: 'Plan', dashed: true },
  ];
  return (
    <div className="mt-3 flex flex-wrap gap-x-4 gap-y-2">
      {items.map((i) => (
        <span key={i.label} className="flex items-center gap-1.5" style={{ fontSize: 11, color: theme.label, ...bodyFont }}>
          <span
            className="h-0.5 w-4 rounded"
            style={{
              background: i.dashed ? 'transparent' : i.color,
              borderTop: i.dashed ? `1.5px dashed ${i.color}` : undefined,
            }}
          />
          {i.label}
        </span>
      ))}
    </div>
  );
}

function CorrelationPanel() {
  const correlations = [
    {
      title: 'Descanso → recuperación',
      body: 'Día de descanso (Lun) → HR más baja en Martes (Entreno).',
      delta: '-6 bpm',
      color: theme.green,
    },
    {
      title: 'Exceso calórico → rendimiento',
      body: 'Cenas >800 kcal el día previo correlacionan con +4% tonelaje al día siguiente.',
      delta: '+4%',
      color: theme.blueSoft,
    },
    {
      title: 'Sueño profundo → grasa',
      body: 'Semanas con >1h sueño profundo medio: -0.3% grasa corporal.',
      delta: '-0.3%',
      color: theme.green,
    },
  ];
  return (
    <section style={{ background: theme.card, borderRadius: theme.radius, padding: 18, boxShadow: theme.cardShadow, border: `1px solid ${theme.border}` }}>
      <p style={labelStyle}>Correlaciones IA</p>
      <ul className="mt-4 space-y-2.5">
        {correlations.map((c) => (
          <li key={c.title} className="flex items-start gap-3 rounded-2xl p-3" style={{ background: theme.surface1 }}>
            <div className="grid h-9 w-9 shrink-0 place-items-center rounded-xl" style={{ background: theme.surface2, color: c.color }}>
              <TrendingUp className="h-4 w-4" strokeWidth={2.25} />
            </div>
            <div className="min-w-0 flex-1">
              <p style={{ fontSize: 12, fontWeight: 700, color: theme.fg, ...bodyFont, lineHeight: 1.1 }}>
                {c.title}
              </p>
              <p className="mt-1" style={{ fontSize: 11, color: theme.label, ...bodyFont, lineHeight: 1.4 }}>
                {c.body}
              </p>
            </div>
            <span style={{ ...titleFont, fontSize: 13, color: c.color }}>{c.delta}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
