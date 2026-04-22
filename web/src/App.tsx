import { CRTFlicker, Scanlines, Vignette } from './components/CRTOverlay'
import { Features } from './components/Features'
import { Hero } from './components/Hero'
import { InstallSteps } from './components/InstallSteps'

function App() {
  return (
    <div className="relative min-h-screen overflow-x-hidden font-mono">
      <div className="absolute inset-0 -z-10 bg-background" />

      <main className="mx-auto flex w-full max-w-3xl flex-col gap-6 px-5 pb-20 pt-12 sm:px-8 sm:pt-16">
        <StatusBar phase="READY" />
        <Hero />
        <Features />
        <InstallSteps />
        <Footer />
      </main>

      <Scanlines />
      <Vignette />
      <CRTFlicker />
    </div>
  )
}

function StatusBar({ phase }: { phase: string }) {
  return (
    <div className="flex items-center gap-0 border border-phosphor-muted bg-surface/70 text-[11px]">
      <span className="bg-phosphor px-2 py-1 font-bold text-background">{phase}</span>
      <span className="px-2 py-1 text-phosphor-dim">mac-os-13+</span>
      <span className="px-2 py-1 text-phosphor-muted">native swiftui</span>
      <span className="flex-1" />
      <span className="px-2 py-1 text-phosphor-muted">tty0</span>
    </div>
  )
}

function Footer() {
  return (
    <footer className="pt-4 text-center text-[11px] text-phosphor-muted">
      // {new Date().getFullYear()} · monkmode · distraction suppressor · no abort. no override. timer is law.
    </footer>
  )
}

export default App
