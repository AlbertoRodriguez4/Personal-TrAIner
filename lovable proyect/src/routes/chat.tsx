import { createFileRoute, Link } from "@tanstack/react-router";
import { useChat } from "@ai-sdk/react";
import { DefaultChatTransport, type UIMessage } from "ai";
import { useEffect, useRef, useState } from "react";
import { ArrowLeft, ArrowUp, Sparkles, Paperclip, X } from "lucide-react";
import logoAsset from "@/assets/traainer-logo.jpg.asset.json";

export const Route = createFileRoute("/chat")({
  head: () => ({
    meta: [{ title: "AI Coach — Personal TrAIner" }],
  }),
  component: ChatScreen,
});

const SUGGESTIONS = [
  "¿Cómo voy de recuperación hoy?",
  "Plan de comida alta en proteína",
  "Rutina rápida de 20 min",
  "Interpreta mi última FC media",
];

function ChatScreen() {
  const [input, setInput] = useState("");
  const [files, setFiles] = useState<File[]>([]);
  const [previews, setPreviews] = useState<string[]>([]);
  const { messages, sendMessage, status } = useChat({
    transport: new DefaultChatTransport({ api: "/api/chat" }),
  });
  const taRef = useRef<HTMLTextAreaElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    taRef.current?.focus();
  }, []);
  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, status]);

  const isLoading = status === "submitted" || status === "streaming";

  const addFiles = (list: FileList | null) => {
    if (!list) return;
    const imgs = Array.from(list).filter((f) => f.type.startsWith("image/"));
    if (!imgs.length) return;
    setFiles((prev) => [...prev, ...imgs]);
    imgs.forEach((f) => {
      const url = URL.createObjectURL(f);
      setPreviews((prev) => [...prev, url]);
    });
  };

  const removeFile = (i: number) => {
    setPreviews((prev) => {
      URL.revokeObjectURL(prev[i]);
      return prev.filter((_, idx) => idx !== i);
    });
    setFiles((prev) => prev.filter((_, idx) => idx !== i));
  };

  const submit = (text: string) => {
    const t = text.trim();
    if ((!t && files.length === 0) || isLoading) return;
    const dt = new DataTransfer();
    files.forEach((f) => dt.items.add(f));
    void sendMessage({ text: t || "¿Qué ves en esta imagen?", files: dt.files });
    setInput("");
    previews.forEach((p) => URL.revokeObjectURL(p));
    setFiles([]);
    setPreviews([]);
    requestAnimationFrame(() => taRef.current?.focus());
  };

  return (
    <div className="min-h-screen w-full bg-surface-2">
      <div className="relative mx-auto flex min-h-screen w-full max-w-[440px] flex-col bg-background">
        <header className="sticky top-0 z-20 glass">
          <div className="flex items-center gap-3 px-4 pb-3 pt-5">
            <Link
              to="/"
              className="flex h-9 w-9 items-center justify-center rounded-full bg-surface-2 text-foreground/80 ring-1 ring-border"
              aria-label="Volver"
            >
              <ArrowLeft className="h-4 w-4" />
            </Link>
            <div className="flex min-w-0 flex-1 items-center gap-2">
              <img
                src={logoAsset.url}
                alt=""
                className="h-8 w-8 rounded-lg object-cover ring-1 ring-border"
              />
              <div className="min-w-0">
                <p className="truncate text-[15px] font-semibold leading-tight">AI Coach</p>
                <p className="flex items-center gap-1 text-[11px] text-muted-foreground">
                  <span className="inline-block h-1.5 w-1.5 rounded-full bg-emerald-500" />
                  En línea · contexto de tus datos
                </p>
              </div>
            </div>
          </div>
        </header>

        <main className="flex-1 px-4 pb-40 pt-4">
          {messages.length === 0 ? (
            <EmptyState onPick={submit} />
          ) : (
            <div className="space-y-4">
              {messages.map((m) => (
                <MessageBubble key={m.id} message={m} />
              ))}
              {status === "submitted" && <TypingIndicator />}
            </div>
          )}
          <div ref={endRef} />
        </main>

        <div className="fixed bottom-0 left-1/2 z-30 w-full max-w-[440px] -translate-x-1/2 px-4 pb-5 pt-3 [background:linear-gradient(to_top,hsl(var(--background))_60%,transparent)]">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              submit(input);
            }}
            className="glass rounded-[24px] p-2 pl-2 shadow-card ring-1 ring-border"
          >
            {previews.length > 0 && (
              <div className="flex flex-wrap gap-2 px-2 pb-2 pt-1">
                {previews.map((src, i) => (
                  <div key={src} className="relative h-16 w-16 overflow-hidden rounded-xl ring-1 ring-border">
                    <img src={src} alt="" className="h-full w-full object-cover" />
                    <button
                      type="button"
                      onClick={() => removeFile(i)}
                      className="absolute right-0.5 top-0.5 grid h-5 w-5 place-items-center rounded-full bg-black/60 text-white"
                      aria-label="Quitar imagen"
                    >
                      <X className="h-3 w-3" />
                    </button>
                  </div>
                ))}
              </div>
            )}
            <div className="flex items-end gap-1.5">
              <input
                ref={fileRef}
                type="file"
                accept="image/*"
                multiple
                className="hidden"
                onChange={(e) => {
                  addFiles(e.target.files);
                  e.target.value = "";
                }}
              />
              <button
                type="button"
                onClick={() => fileRef.current?.click()}
                className="grid h-10 w-10 shrink-0 place-items-center rounded-full text-muted-foreground transition hover:bg-surface-2 hover:text-foreground"
                aria-label="Adjuntar imagen"
              >
                <Paperclip className="h-[18px] w-[18px]" />
              </button>
              <textarea
              ref={taRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  submit(input);
                }
              }}
              placeholder="Pregunta a tu AI Coach…"
              rows={1}
              className="max-h-32 flex-1 resize-none bg-transparent py-2 text-[15px] leading-snug outline-none placeholder:text-muted-foreground"
              />
            <button
              type="submit"
              disabled={(!input.trim() && files.length === 0) || isLoading}
              className="bg-ai-gradient flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-white shadow-soft transition-opacity disabled:opacity-40"
              aria-label="Enviar"
            >
              <ArrowUp className="h-4 w-4" />
            </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}

function MessageBubble({ message }: { message: UIMessage }) {
  const text = message.parts
    .map((p) => (p.type === "text" ? p.text : ""))
    .join("");
  const images = message.parts.flatMap((p) => {
    if (p.type === "file" && typeof p.mediaType === "string" && p.mediaType.startsWith("image/")) {
      return [p.url];
    }
    return [];
  });
  const isUser = message.role === "user";
  return (
    <div className={`flex ${isUser ? "justify-end" : "justify-start"}`}>
      <div className={isUser ? "flex max-w-[82%] flex-col items-end gap-1.5" : "max-w-[88%]"}>
        {images.length > 0 && (
          <div className="flex flex-wrap justify-end gap-1.5">
            {images.map((src, i) => (
              <img
                key={i}
                src={src}
                alt=""
                className="max-h-56 max-w-[180px] rounded-2xl object-cover ring-1 ring-border"
              />
            ))}
          </div>
        )}
        {text && (
          <div
            className={
              isUser
                ? "rounded-[22px] rounded-br-md bg-primary px-4 py-2.5 text-[15px] leading-relaxed text-primary-foreground shadow-soft"
                : "whitespace-pre-wrap text-[15px] leading-relaxed text-foreground"
            }
          >
            {text}
          </div>
        )}
      </div>
    </div>
  );
}

function TypingIndicator() {
  return (
    <div className="flex items-center gap-1.5 px-1 text-muted-foreground">
      <span className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground/60 [animation-delay:-0.2s]" />
      <span className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground/60 [animation-delay:-0.1s]" />
      <span className="h-2 w-2 animate-bounce rounded-full bg-muted-foreground/60" />
    </div>
  );
}

function EmptyState({ onPick }: { onPick: (t: string) => void }) {
  return (
    <div className="flex flex-col items-center pt-10 text-center">
      <div className="bg-ai-gradient mb-4 flex h-16 w-16 items-center justify-center rounded-2xl shadow-soft">
        <Sparkles className="h-7 w-7 text-white" />
      </div>
      <h1 className="text-[22px] font-semibold tracking-tight">¿En qué te ayudo hoy?</h1>
      <p className="mt-1 max-w-[300px] text-sm text-muted-foreground">
        Tu coach personal con acceso a tus métricas, entrenamientos y nutrición.
      </p>
      <div className="mt-6 grid w-full grid-cols-1 gap-2">
        {SUGGESTIONS.map((s) => (
          <button
            key={s}
            onClick={() => onPick(s)}
            className="rounded-2xl bg-surface-2 px-4 py-3 text-left text-sm text-foreground/90 ring-1 ring-border transition-colors hover:bg-surface-1"
          >
            {s}
          </button>
        ))}
      </div>
    </div>
  );
}