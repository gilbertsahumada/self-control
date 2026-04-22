const OWNER = 'gilbertsahumada'
const REPO = 'self-control'

const STEPS = [
  {
    prompt: 'open MonkMode.dmg',
    output: 'drag MonkMode.app into /Applications',
  },
  {
    prompt: 'xattr -cr /Applications/MonkMode.app',
    output: 'strip quarantine (ad-hoc signed binary) — one time',
  },
  {
    prompt: 'open -a MonkMode',
    output: 'pick targets, set duration, execute lockdown',
  },
]

export function InstallSteps() {
  return (
    <section className="border border-phosphor-muted bg-surface/50 px-6 py-8 sm:px-10">
      <h2 className="flex items-center gap-2 text-xs text-phosphor-dim">
        <span>──</span>
        <span className="tracking-wider">[ INSTALL ]</span>
        <span className="flex-1 border-t border-phosphor-muted" />
      </h2>

      <div className="mt-6 space-y-3 text-xs sm:text-sm">
        {STEPS.map((s, i) => (
          <div key={s.prompt} className="border-l-2 border-phosphor-muted pl-4">
            <div className="flex items-baseline gap-2">
              <span className="text-phosphor-muted">{String(i + 1).padStart(2, '0')}.</span>
              <span className="text-phosphor-dim">$</span>
              <code className="text-phosphor">{s.prompt}</code>
            </div>
            <p className="mt-1 pl-7 text-[11px] text-phosphor-muted sm:text-xs">
              <span className="text-phosphor-muted">// </span>
              {s.output}
            </p>
          </div>
        ))}
      </div>

      <div className="mt-8 flex flex-wrap gap-5 border-t border-phosphor-muted pt-5 text-xs">
        <a
          className="text-phosphor-dim transition-colors hover:text-phosphor"
          href={`https://github.com/${OWNER}/${REPO}`}
          target="_blank"
          rel="noreferrer"
        >
          [source]
        </a>
        <a
          className="text-phosphor-dim transition-colors hover:text-phosphor"
          href={`https://github.com/${OWNER}/${REPO}/releases`}
          target="_blank"
          rel="noreferrer"
        >
          [releases]
        </a>
        <a
          className="text-phosphor-dim transition-colors hover:text-phosphor"
          href={`https://github.com/${OWNER}/${REPO}/blob/main/TROUBLESHOOTING.md`}
          target="_blank"
          rel="noreferrer"
        >
          [troubleshooting]
        </a>
      </div>
    </section>
  )
}
