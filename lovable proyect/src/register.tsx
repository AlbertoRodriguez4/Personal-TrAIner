import { useState } from 'react';
import {
  ArrowLeft, ArrowRight, Check, User, Ruler, Target, Dumbbell,
  HeartPulse, Mail, Lock, Sparkles,
} from 'lucide-react';
import { useNav } from './nav';

type Data = {
  email: string; password: string;
  name: string; birthDate: string; gender: string;
  heightCm: string; weightKg: string; bodyFat: string;
  goal: string; level: string; daysPerWeek: number;
  activities: string[];
  restingHr: string; sleepHours: string; injuries: string;
};

const EMPTY: Data = {
  email: '', password: '',
  name: '', birthDate: '', gender: '',
  heightCm: '', weightKg: '', bodyFat: '',
  goal: '', level: '', daysPerWeek: 4,
  activities: [],
  restingHr: '', sleepHours: '', injuries: '',
};

const STEPS = [
  { key: 'account', label: 'Cuenta', icon: Mail },
  { key: 'profile', label: 'Perfil', icon: User },
  { key: 'body', label: 'Cuerpo', icon: Ruler },
  { key: 'goal', label: 'Objetivo', icon: Target },
  { key: 'training', label: 'Entreno', icon: Dumbbell },
  { key: 'health', label: 'Salud', icon: HeartPulse },
] as const;

export function RegisterScreen() {
  const { goBack, setTab } = useNav();
  const [step, setStep] = useState(0);
  const [data, setData] = useState<Data>(EMPTY);
  const [finished, setFinished] = useState(false);

  const set = <K extends keyof Data>(k: K, v: Data[K]) => setData((d) => ({ ...d, [k]: v }));

  const valid = (() => {
    switch (STEPS[step]!.key) {
      case 'account': return data.email.includes('@') && data.password.length >= 6;
      case 'profile': return data.name.trim().length > 1 && !!data.birthDate && !!data.gender;
      case 'body': return !!data.heightCm && !!data.weightKg;
      case 'goal': return !!data.goal;
      case 'training': return !!data.level && data.activities.length > 0;
      default: return true;
    }
  })();

  const next = () => (step < STEPS.length - 1 ? setStep(step + 1) : setFinished(true));
  const back = () => (step === 0 ? goBack() : setStep(step - 1));

  if (finished) {
    return (
      <div className="min-h-screen w-full bg-surface-2">
        <div className="mx-auto flex min-h-screen w-full max-w-[440px] flex-col items-center justify-center bg-background px-6 text-center">
          <div className="grid h-16 w-16 place-items-center rounded-3xl bg-ai-gradient text-white shadow-card">
            <Sparkles className="h-7 w-7" strokeWidth={2.25} />
          </div>
          <h1 className="mt-5 text-[26px] font-bold tracking-tight text-foreground">
            Perfil completo, {data.name.split(' ')[0] || 'atleta'}
          </h1>
          <p className="mt-2 text-[14px] leading-relaxed text-muted-foreground">
            Ya tenemos todo lo necesario para que Pulso adapte tus rutinas, tu recuperación y tu nutrición.
          </p>
          <button
            onClick={() => setTab('home')}
            className="mt-7 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-ai-gradient px-5 py-4 text-[15px] font-semibold text-white shadow-card transition active:scale-[0.99]"
          >
            Entrar a Personal TrAIner
          </button>
        </div>
      </div>
    );
  }

  const Icon = STEPS[step]!.icon;

  return (
    <div className="min-h-screen w-full bg-surface-2">
      <div className="mx-auto w-full max-w-[440px] bg-background px-5 pb-10 pt-6">
        <div className="flex items-center gap-3">
          <button
            onClick={back}
            aria-label="Atrás"
            className="grid h-9 w-9 place-items-center rounded-full bg-surface-1 ring-1 ring-border transition active:scale-95"
          >
            <ArrowLeft className="h-4 w-4" strokeWidth={2.25} />
          </button>
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
              Registro · paso {step + 1} de {STEPS.length}
            </p>
            <h1 className="text-[19px] font-bold tracking-tight text-foreground">{STEPS[step]!.label}</h1>
          </div>
        </div>

        {/* stepper */}
        <div className="mt-5 flex items-center gap-1.5">
          {STEPS.map((s, i) => (
            <div
              key={s.key}
              className={`h-1.5 flex-1 rounded-full transition-all ${
                i < step ? 'bg-foreground/70' : i === step ? 'bg-ai-gradient' : 'bg-surface-1'
              }`}
            />
          ))}
        </div>

        <section key={step} className="animate-fade-in mt-5 rounded-[28px] bg-card p-5 shadow-card">
          <div className="flex items-center gap-3">
            <div className="grid h-10 w-10 place-items-center rounded-2xl bg-ai-soft text-foreground">
              <Icon className="h-4.5 w-4.5 h-[18px] w-[18px]" strokeWidth={2.25} />
            </div>
            <p className="text-[14px] font-semibold text-foreground">{stepTitle(STEPS[step]!.key)}</p>
          </div>

          <div className="mt-4 space-y-4">
            {STEPS[step]!.key === 'account' && (
              <>
                <Field label="Email" icon={Mail} value={data.email} onChange={(v) => set('email', v)} type="email" placeholder="carlos@email.com" />
                <Field label="Contraseña" icon={Lock} value={data.password} onChange={(v) => set('password', v)} type="password" placeholder="Mínimo 6 caracteres" />
              </>
            )}

            {STEPS[step]!.key === 'profile' && (
              <>
                <Field label="Nombre completo" value={data.name} onChange={(v) => set('name', v)} placeholder="Carlos Pérez" />
                <Field label="Fecha de nacimiento" value={data.birthDate} onChange={(v) => set('birthDate', v)} type="date" />
                <Chips label="Sexo" options={['Hombre', 'Mujer', 'Prefiero no decirlo']} value={data.gender} onChange={(v) => set('gender', v)} />
              </>
            )}

            {STEPS[step]!.key === 'body' && (
              <>
                <div className="grid grid-cols-2 gap-3">
                  <Field label="Altura (cm)" value={data.heightCm} onChange={(v) => set('heightCm', v)} type="number" placeholder="178" />
                  <Field label="Peso (kg)" value={data.weightKg} onChange={(v) => set('weightKg', v)} type="number" placeholder="76" />
                </div>
                <Field label="% Grasa corporal (opcional)" value={data.bodyFat} onChange={(v) => set('bodyFat', v)} type="number" placeholder="16" />
              </>
            )}

            {STEPS[step]!.key === 'goal' && (
              <Chips
                label="¿Cuál es tu objetivo principal?"
                options={['Ganar músculo', 'Perder grasa', 'Ganar fuerza', 'Rendimiento', 'Salud general']}
                value={data.goal}
                onChange={(v) => set('goal', v)}
                stacked
              />
            )}

            {STEPS[step]!.key === 'training' && (
              <>
                <Chips label="Nivel" options={['Principiante', 'Intermedio', 'Avanzado']} value={data.level} onChange={(v) => set('level', v)} />
                <MultiChips
                  label="Actividades"
                  options={['Gym', 'Cardio', 'Calistenia', 'Yoga', 'Deportes']}
                  values={data.activities}
                  onChange={(v) => set('activities', v)}
                />
                <div>
                  <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
                    Días por semana · {data.daysPerWeek}
                  </p>
                  <input
                    type="range" min={1} max={7} value={data.daysPerWeek}
                    onChange={(e) => set('daysPerWeek', Number(e.target.value))}
                    className="mt-3 w-full accent-foreground"
                  />
                </div>
              </>
            )}

            {STEPS[step]!.key === 'health' && (
              <>
                <div className="grid grid-cols-2 gap-3">
                  <Field label="FC en reposo" value={data.restingHr} onChange={(v) => set('restingHr', v)} type="number" placeholder="58" />
                  <Field label="Horas de sueño" value={data.sleepHours} onChange={(v) => set('sleepHours', v)} type="number" placeholder="7" />
                </div>
                <Field label="Lesiones o limitaciones (opcional)" value={data.injuries} onChange={(v) => set('injuries', v)} placeholder="Molestia lumbar" />
              </>
            )}
          </div>
        </section>

        <button
          onClick={next}
          disabled={!valid}
          className={`mt-4 inline-flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-[15px] font-semibold transition active:scale-[0.99] ${
            valid ? 'bg-ai-gradient text-white shadow-card' : 'bg-surface-1 text-muted-foreground'
          }`}
        >
          {step === STEPS.length - 1 ? <Check className="h-4 w-4" strokeWidth={2.5} /> : <ArrowRight className="h-4 w-4" strokeWidth={2.5} />}
          {step === STEPS.length - 1 ? 'Completar registro' : 'Continuar'}
        </button>
      </div>
    </div>
  );
}

function stepTitle(key: string) {
  switch (key) {
    case 'account': return 'Crea tu cuenta';
    case 'profile': return 'Cuéntanos quién eres';
    case 'body': return 'Tus medidas actuales';
    case 'goal': return 'Tu objetivo';
    case 'training': return 'Tu forma de entrenar';
    default: return 'Salud y recuperación';
  }
}

function Field({
  label, value, onChange, type = 'text', placeholder, icon: Icon,
}: {
  label: string; value: string; onChange: (v: string) => void;
  type?: string; placeholder?: string; icon?: typeof Mail;
}) {
  return (
    <label className="block">
      <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">{label}</span>
      <div className="mt-2 flex items-center gap-2 rounded-2xl bg-surface-1 px-3.5 py-3 ring-1 ring-border focus-within:ring-foreground/25">
        {Icon && <Icon className="h-4 w-4 shrink-0 text-muted-foreground" strokeWidth={2.25} />}
        <input
          type={type}
          value={value}
          placeholder={placeholder}
          onChange={(e) => onChange(e.target.value)}
          className="w-full bg-transparent text-[15px] text-foreground outline-none placeholder:text-muted-foreground/70"
        />
      </div>
    </label>
  );
}

function Chips({
  label, options, value, onChange, stacked = false,
}: { label: string; options: string[]; value: string; onChange: (v: string) => void; stacked?: boolean }) {
  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">{label}</p>
      <div className={`mt-2.5 ${stacked ? 'grid grid-cols-1 gap-2' : 'flex flex-wrap gap-2'}`}>
        {options.map((o) => {
          const active = o === value;
          return (
            <button
              key={o}
              onClick={() => onChange(o)}
              className={`rounded-2xl px-4 py-3 text-[13.5px] font-semibold transition active:scale-[0.98] ${
                active ? 'bg-foreground text-background' : 'bg-surface-1 text-foreground ring-1 ring-border'
              } ${stacked ? 'text-left' : ''}`}
            >
              {o}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function MultiChips({
  label, options, values, onChange,
}: { label: string; options: string[]; values: string[]; onChange: (v: string[]) => void }) {
  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">{label}</p>
      <div className="mt-2.5 flex flex-wrap gap-2">
        {options.map((o) => {
          const active = values.includes(o);
          return (
            <button
              key={o}
              onClick={() => onChange(active ? values.filter((v) => v !== o) : [...values, o])}
              className={`inline-flex items-center gap-1.5 rounded-2xl px-4 py-3 text-[13.5px] font-semibold transition active:scale-[0.98] ${
                active ? 'bg-foreground text-background' : 'bg-surface-1 text-foreground ring-1 ring-border'
              }`}
            >
              {active && <Check className="h-3.5 w-3.5" strokeWidth={3} />}
              {o}
            </button>
          );
        })}
      </div>
    </div>
  );
}
