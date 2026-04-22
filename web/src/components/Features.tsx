const FEATURES = [
  {
    id: '01',
    title: 'NO_ABORT_MODE',
    description:
      'lockdown cannot be stopped once initiated. timer is law. no override flags, no sudo escape.',
  },
  {
    id: '02',
    title: 'DUAL_LAYER_BLOCK',
    description:
      '/etc/hosts + macOS pf firewall. dns-over-https providers blocked so browsers cannot route around it.',
  },
  {
    id: '03',
    title: 'NATIVE_LIGHTWEIGHT',
    description:
      'pure SwiftUI app. no Electron, no menubar, no network calls. runs in ~30MB, enforces on a 60s daemon.',
  },
  {
    id: '04',
    title: 'SELF_HEAL',
    description:
      'secondary launchd job fires at expiry as a redundancy. app also ships a recovery path for stale state.',
  },
]

export function Features() {
  return (
    <section className="border border-phosphor-muted bg-surface/50 px-6 py-8 sm:px-10">
      <h2 className="flex items-center gap-2 text-xs text-phosphor-dim">
        <span>──</span>
        <span className="tracking-wider">[ FEATURES ]</span>
        <span className="flex-1 border-t border-phosphor-muted" />
      </h2>

      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        {FEATURES.map((f) => (
          <article
            key={f.id}
            className="border border-phosphor-muted bg-background/60 p-4 transition-colors hover:border-phosphor"
          >
            <header className="flex items-baseline gap-2">
              <span className="text-xs text-phosphor-muted">{f.id}.</span>
              <h3 className="text-sm font-bold tracking-wider text-phosphor">{f.title}</h3>
            </header>
            <p className="mt-2 text-xs leading-relaxed text-phosphor-dim">{f.description}</p>
          </article>
        ))}
      </div>
    </section>
  )
}
