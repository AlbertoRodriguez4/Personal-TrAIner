import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { Mail, Lock, User, ArrowRight, Apple as AppleIcon } from "lucide-react";
import logoAsset from "@/assets/traainer-logo.jpg.asset.json";

export const Route = createFileRoute("/auth")({
  head: () => ({
    meta: [
      { title: "Acceder · Personal TrAIner" },
      { name: "description", content: "Inicia sesión o crea tu cuenta en Personal TrAIner." },
    ],
  }),
  component: AuthScreen,
});

type Mode = "login" | "register";

function AuthScreen() {
  const [mode, setMode] = useState<Mode>("login");
  const navigate = useNavigate();

  return (
    <div className="min-h-screen w-full bg-surface-2">
      <div className="relative mx-auto flex min-h-screen w-full max-w-[440px] flex-col bg-background px-6 pb-10 pt-14">
        {/* Ambient gradient */}
        <div className="pointer-events-none absolute -top-20 left-1/2 h-72 w-72 -translate-x-1/2 rounded-full bg-ai-gradient opacity-20 blur-3xl" />

        <header className="relative flex flex-col items-center text-center">
          <img
            src={logoAsset.url}
            alt="Personal TrAIner"
            className="h-16 w-16 rounded-2xl object-cover shadow-card ring-1 ring-border"
          />
          <h1 className="mt-5 text-[26px] font-bold leading-tight tracking-tight">
            {mode === "login" ? "Bienvenido de nuevo" : "Crea tu cuenta"}
          </h1>
          <p className="mt-1.5 text-[13px] text-muted-foreground">
            {mode === "login"
              ? "Tu IA personal te está esperando."
              : "Empieza a entrenar con inteligencia."}
          </p>
        </header>

        <div className="relative mt-7 inline-flex w-full rounded-full bg-surface-1 p-1 ring-1 ring-border">
          {(["login", "register"] as Mode[]).map((m) => {
            const active = m === mode;
            return (
              <button
                key={m}
                onClick={() => setMode(m)}
                className={
                  "flex-1 rounded-full py-2 text-[13px] font-semibold transition " +
                  (active
                    ? "bg-background text-foreground shadow-soft"
                    : "text-muted-foreground")
                }
              >
                {m === "login" ? "Iniciar sesión" : "Registrarse"}
              </button>
            );
          })}
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            navigate({ to: "/" });
          }}
          className="relative mt-6 space-y-3"
        >
          {mode === "register" && (
            <Field icon={User} type="text" placeholder="Nombre" autoComplete="name" />
          )}
          <Field icon={Mail} type="email" placeholder="Correo electrónico" autoComplete="email" />
          <Field
            icon={Lock}
            type="password"
            placeholder="Contraseña"
            autoComplete={mode === "login" ? "current-password" : "new-password"}
          />

          {mode === "login" && (
            <div className="flex justify-end pt-0.5">
              <button type="button" className="text-[12px] font-medium text-muted-foreground">
                ¿Olvidaste tu contraseña?
              </button>
            </div>
          )}

          <button
            type="submit"
            className="mt-2 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-ai-gradient px-5 py-4 text-[15px] font-semibold text-white shadow-card transition active:scale-[0.99]"
          >
            {mode === "login" ? "Entrar" : "Crear cuenta"}
            <ArrowRight className="h-4 w-4" strokeWidth={2.4} />
          </button>
        </form>

        <div className="relative my-6 flex items-center gap-3">
          <div className="h-px flex-1 bg-border" />
          <span className="text-[11px] uppercase tracking-wider text-muted-foreground">o continúa con</span>
          <div className="h-px flex-1 bg-border" />
        </div>

        <div className="relative grid grid-cols-2 gap-3">
          <SocialButton label="Apple" icon={<AppleIcon className="h-4 w-4" />} />
          <SocialButton
            label="Google"
            icon={
              <svg viewBox="0 0 24 24" className="h-4 w-4">
                <path fill="#EA4335" d="M12 10.2v3.9h5.5c-.24 1.4-1.7 4.1-5.5 4.1-3.3 0-6-2.7-6-6.2s2.7-6.2 6-6.2c1.9 0 3.1.8 3.8 1.5l2.6-2.5C16.8 3.1 14.6 2 12 2 6.9 2 2.8 6.1 2.8 11.2S6.9 20.4 12 20.4c6.9 0 9.4-4.8 9.4-7.3 0-.5-.1-.9-.1-1.3H12z"/>
              </svg>
            }
          />
        </div>

        <p className="relative mt-8 text-center text-[12px] text-muted-foreground">
          {mode === "login" ? "¿Aún no tienes cuenta? " : "¿Ya tienes cuenta? "}
          <button
            onClick={() => setMode(mode === "login" ? "register" : "login")}
            className="font-semibold text-foreground"
          >
            {mode === "login" ? "Regístrate" : "Inicia sesión"}
          </button>
        </p>

        <div className="relative mt-3 flex items-center justify-center gap-3 text-[11px] uppercase tracking-[0.14em] text-muted-foreground">
          <Link to="/">Volver</Link>
          <span className="opacity-40">·</span>
          <Link to="/onboarding" className="text-foreground">Ver tour</Link>
        </div>
      </div>
    </div>
  );
}

function Field({
  icon: Icon,
  ...props
}: { icon: typeof Mail } & React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <label className="flex items-center gap-3 rounded-2xl bg-surface-1 px-4 py-3.5 ring-1 ring-border focus-within:ring-2 focus-within:ring-foreground/40">
      <Icon className="h-4 w-4 text-muted-foreground" strokeWidth={2.25} />
      <input
        {...props}
        className="w-full bg-transparent text-[14px] font-medium text-foreground placeholder:text-muted-foreground focus:outline-none"
      />
    </label>
  );
}

function SocialButton({ label, icon }: { label: string; icon: React.ReactNode }) {
  return (
    <button
      type="button"
      className="inline-flex items-center justify-center gap-2 rounded-2xl bg-card px-4 py-3 text-[13px] font-semibold text-foreground shadow-soft ring-1 ring-border transition active:scale-[0.98]"
    >
      {icon}
      {label}
    </button>
  );
}