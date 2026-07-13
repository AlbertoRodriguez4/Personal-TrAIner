import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { ArrowLeft, FileText, Image as ImageIcon, Keyboard, ChevronRight, Upload } from "lucide-react";
import { useRef, useState } from "react";

export const Route = createFileRoute("/clinic/import")({
  head: () => ({ meta: [{ title: "Importar analítica — Personal TrAIner" }] }),
  component: ClinicImport,
});

type Mode = "menu" | "pdf" | "image" | "manual";

function ClinicImport() {
  const [mode, setMode] = useState<Mode>("menu");
  return (
    <div className="min-h-screen w-full bg-surface-2">
      <div className="relative mx-auto flex min-h-screen w-full max-w-[440px] flex-col bg-background">
        <header className="sticky top-0 z-20 glass">
          <div className="flex items-center gap-3 px-4 pb-3 pt-5">
            {mode === "menu" ? (
              <Link
                to="/"
                className="grid h-9 w-9 place-items-center rounded-full bg-surface-2 ring-1 ring-border"
                aria-label="Volver"
              >
                <ArrowLeft className="h-4 w-4" />
              </Link>
            ) : (
              <button
                onClick={() => setMode("menu")}
                className="grid h-9 w-9 place-items-center rounded-full bg-surface-2 ring-1 ring-border"
                aria-label="Volver"
              >
                <ArrowLeft className="h-4 w-4" />
              </button>
            )}
            <div>
              <p className="text-[11px] font-medium uppercase tracking-[0.14em] text-muted-foreground">
                Clínica
              </p>
              <h1 className="text-[17px] font-semibold leading-tight">Importar analítica</h1>
            </div>
          </div>
        </header>

        <main className="flex-1 px-5 pb-10 pt-4">
          {mode === "menu" && <Menu onPick={setMode} />}
          {mode === "pdf" && <FileDrop accept="application/pdf,.pdf" title="Subir PDF" hint="Informe médico, analítica o DICOM" icon={FileText} />}
          {mode === "image" && <FileDrop accept="image/*" title="Subir imagen" hint="Foto de la analítica o gráfica" icon={ImageIcon} capture />}
          {mode === "manual" && <ManualForm />}
        </main>
      </div>
    </div>
  );
}

function Menu({ onPick }: { onPick: (m: Mode) => void }) {
  const opts: { key: Mode; icon: typeof FileText; title: string; sub: string }[] = [
    { key: "pdf", icon: FileText, title: "Subir PDF", sub: "Informe médico, analítica, DICOM" },
    { key: "image", icon: ImageIcon, title: "Subir imagen", sub: "Foto de la analítica" },
    { key: "manual", icon: Keyboard, title: "Introducir a mano", sub: "Valores clave: colesterol, glucosa…" },
  ];
  return (
    <div className="space-y-3">
      <p className="px-1 text-[13px] text-muted-foreground">
        Elige cómo quieres añadir tus datos clínicos.
      </p>
      {opts.map(({ key, icon: Icon, title, sub }) => (
        <button
          key={key}
          onClick={() => onPick(key)}
          className="flex w-full items-center gap-4 rounded-[24px] bg-card p-4 text-left shadow-soft transition active:scale-[0.99]"
        >
          <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-ai-soft">
            <Icon className="h-5 w-5 text-foreground" strokeWidth={2.25} />
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-[15px] font-bold leading-tight">{title}</p>
            <p className="mt-0.5 text-[12px] text-muted-foreground">{sub}</p>
          </div>
          <ChevronRight className="h-5 w-5 text-muted-foreground" />
        </button>
      ))}
    </div>
  );
}

function FileDrop({
  accept, title, hint, icon: Icon, capture = false,
}: { accept: string; title: string; hint: string; icon: typeof FileText; capture?: boolean }) {
  const ref = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const navigate = useNavigate();
  return (
    <div className="space-y-4">
      <button
        onClick={() => ref.current?.click()}
        className="block w-full rounded-[28px] border-2 border-dashed border-border bg-card p-8 text-center shadow-soft transition hover:border-foreground/30 active:scale-[0.99]"
      >
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-ai-soft">
          <Icon className="h-6 w-6 text-foreground" strokeWidth={2.25} />
        </div>
        <p className="mt-3 text-[16px] font-bold">{title}</p>
        <p className="mt-1 text-[12px] text-muted-foreground">{hint}</p>
        <span className="mt-4 inline-flex items-center gap-2 rounded-full bg-foreground px-4 py-2 text-[12px] font-semibold text-background">
          <Upload className="h-3.5 w-3.5" />
          {capture ? "Tomar / elegir" : "Elegir archivo"}
        </span>
      </button>
      <input
        ref={ref}
        type="file"
        accept={accept}
        {...(capture ? { capture: "environment" as const } : {})}
        className="hidden"
        onChange={(e) => setFile(e.target.files?.[0] ?? null)}
      />
      {file && (
        <div className="rounded-2xl bg-card p-4 shadow-soft">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
            Archivo seleccionado
          </p>
          <p className="mt-1 truncate text-[14px] font-semibold">{file.name}</p>
          <p className="text-[11px] text-muted-foreground">{(file.size / 1024).toFixed(0)} KB</p>
          <button
            onClick={() => navigate({ to: "/" })}
            className="mt-4 inline-flex w-full items-center justify-center rounded-2xl bg-ai-gradient px-5 py-3 text-[14px] font-semibold text-white shadow-card"
          >
            Analizar con IA
          </button>
        </div>
      )}
    </div>
  );
}

const MANUAL_FIELDS: { key: string; label: string; unit: string; placeholder: string }[] = [
  { key: "chol", label: "Colesterol total", unit: "mg/dL", placeholder: "190" },
  { key: "hdl", label: "HDL", unit: "mg/dL", placeholder: "55" },
  { key: "ldl", label: "LDL", unit: "mg/dL", placeholder: "110" },
  { key: "trig", label: "Triglicéridos", unit: "mg/dL", placeholder: "120" },
  { key: "glu", label: "Glucosa", unit: "mg/dL", placeholder: "92" },
  { key: "hba1c", label: "HbA1c", unit: "%", placeholder: "5.3" },
  { key: "vitd", label: "Vitamina D", unit: "ng/mL", placeholder: "32" },
  { key: "fer", label: "Ferritina", unit: "ng/mL", placeholder: "80" },
];

function ManualForm() {
  const navigate = useNavigate();
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        navigate({ to: "/" });
      }}
      className="space-y-3"
    >
      <div className="rounded-[24px] bg-card p-4 shadow-soft">
        <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Valores clave
        </p>
        <div className="mt-3 grid grid-cols-2 gap-3">
          {MANUAL_FIELDS.map((f) => (
            <label key={f.key} className="block">
              <span className="text-[11px] font-medium text-muted-foreground">{f.label}</span>
              <div className="mt-1 flex items-center gap-1 rounded-xl bg-surface-1 px-3 py-2 ring-1 ring-border focus-within:ring-foreground/30">
                <input
                  inputMode="decimal"
                  placeholder={f.placeholder}
                  className="min-w-0 flex-1 bg-transparent text-[14px] font-semibold outline-none placeholder:text-muted-foreground/60"
                />
                <span className="text-[10px] text-muted-foreground">{f.unit}</span>
              </div>
            </label>
          ))}
        </div>
      </div>
      <button
        type="submit"
        className="inline-flex w-full items-center justify-center rounded-2xl bg-ai-gradient px-5 py-4 text-[15px] font-semibold text-white shadow-card"
      >
        Guardar y analizar
      </button>
    </form>
  );
}