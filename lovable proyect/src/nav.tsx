import { createContext, useContext, useState, useCallback, useRef, type ReactNode } from 'react';

export type TabKey = 'home' | 'train' | 'nutrition' | 'progress' | 'health';

export type Route =
  | { name: 'tabs'; tab: TabKey }
  | { name: 'chat' }
  | { name: 'focus' }
  | { name: 'workout'; id: string }
  | { name: 'progress' }
  | { name: 'recovery' }
  | { name: 'devices' }
  | { name: 'clinic-import' }
  | { name: 'routine-builder' }
  | { name: 'routine-quick-add'; activity?: string; day?: string };

type NavContextValue = {
  route: Route;
  navigate: (route: Route) => void;
  goBack: () => void;
  setTab: (tab: TabKey) => void;
};

const NavContext = createContext<NavContextValue | null>(null);

export function NavProvider({ children }: { children: ReactNode }) {
  const [route, setRoute] = useState<Route>({ name: 'tabs', tab: 'home' });
  const historyRef = useRef<Route[]>([]);

  const navigate = useCallback((next: Route) => {
    setRoute((prev) => {
      historyRef.current = [...historyRef.current, prev];
      return next;
    });
    window.scrollTo(0, 0);
  }, []);

  const goBack = useCallback(() => {
    const h = historyRef.current;
    if (h.length === 0) {
      setRoute({ name: 'tabs', tab: 'home' });
      return;
    }
    const prev = h[h.length - 1]!;
    historyRef.current = h.slice(0, -1);
    setRoute(prev);
  }, []);

  const setTab = useCallback((tab: TabKey) => {
    setRoute({ name: 'tabs', tab });
    historyRef.current = [];
    window.scrollTo(0, 0);
  }, []);

  return (
    <NavContext.Provider value={{ route, navigate, goBack, setTab }}>
      {children}
    </NavContext.Provider>
  );
}

export function useNav() {
  const ctx = useContext(NavContext);
  if (!ctx) throw new Error('useNav must be used within NavProvider');
  return ctx;
}
