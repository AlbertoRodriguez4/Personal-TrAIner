import { NavProvider, useNav } from './nav';
import {
  Header, BottomNav, HomeScreen, TrainScreen, NutritionScreen, HealthScreen,
} from './screens';
import { ProgressScreen } from './progress';
import {
  ChatScreen, FocusScreen, WorkoutDetailScreen, RecoveryScreen, DevicesScreen,
  ClinicImportScreen, RoutineBuilderScreen, QuickAddScreen,
} from './deep-screens';

function AppContent() {
  const { route, setTab } = useNav();

  if (route.name !== 'tabs') {
    return (
      <>
        {route.name === 'chat' && <ChatScreen />}
        {route.name === 'focus' && <FocusScreen />}
        {route.name === 'workout' && <WorkoutDetailScreen id={route.id} />}
        {route.name === 'progress' && <ProgressScreen />}
        {route.name === 'recovery' && <RecoveryScreen />}
        {route.name === 'devices' && <DevicesScreen />}
        {route.name === 'clinic-import' && <ClinicImportScreen />}
        {route.name === 'routine-builder' && <RoutineBuilderScreen />}
        {route.name === 'routine-quick-add' && (
          <QuickAddScreen activity={route.activity} day={route.day} />
        )}
      </>
    );
  }

  return (
    <div className="min-h-screen w-full bg-surface-2">
      <div className="relative mx-auto flex min-h-screen w-full max-w-[440px] flex-col bg-background">
        <Header />
        <main className="flex-1 px-5 pb-32 pt-2">
          <div key={route.tab} className="animate-fade-in space-y-5">
            {route.tab === 'home' && <HomeScreen />}
            {route.tab === 'train' && <TrainScreen />}
            {route.tab === 'nutrition' && <NutritionScreen />}
            {route.tab === 'progress' && <ProgressScreen />}
            {route.tab === 'health' && <HealthScreen />}
          </div>
        </main>
        <BottomNav active={route.tab} onChange={setTab} />
      </div>
    </div>
  );
}

export default function App() {
  return (
    <NavProvider>
      <AppContent />
    </NavProvider>
  );
}
