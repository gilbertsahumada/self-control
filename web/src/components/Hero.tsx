import { useEffect, useState } from 'react'

const OWNER = 'gilbertsahumada'
const REPO = 'self-control'
const API_URL = `https://api.github.com/repos/${OWNER}/${REPO}/releases/latest`
const FALLBACK_VERSION = 'v1.0.0'
const FALLBACK_DMG = `https://github.com/${OWNER}/${REPO}/releases/latest`

const BANNER = ` ███   ███  ██████  ███    ██ ██   ██ ███   ███  ██████  ██████  ███████
 ████ ████ ██    ██ ████   ██ ██  ██  ████ ████ ██    ██ ██   ██ ██
 ██ ███ ██ ██    ██ ██ ██  ██ █████   ██ ███ ██ ██    ██ ██   ██ █████
 ██  █  ██ ██    ██ ██  ██ ██ ██  ██  ██  █  ██ ██    ██ ██   ██ ██
 ██     ██  ██████  ██   ████ ██   ██ ██     ██  ██████  ██████  ███████`

type ReleaseState = {
  version: string
  downloadUrl: string
  loading: boolean
}

export function Hero() {
  const [release, setRelease] = useState<ReleaseState>({
    version: FALLBACK_VERSION,
    downloadUrl: FALLBACK_DMG,
    loading: true,
  })

  useEffect(() => {
    const run = async () => {
      try {
        const res = await fetch(API_URL)
        if (!res.ok) throw new Error('release lookup failed')
        const data = await res.json()
        const dmg = (data.assets as Array<{ name: string; browser_download_url: string }>).find((a) =>
          a.name.endsWith('.dmg'),
        )
        setRelease({
          version: data.tag_name ?? FALLBACK_VERSION,
          downloadUrl: dmg?.browser_download_url ?? FALLBACK_DMG,
          loading: false,
        })
      } catch {
        setRelease({
          version: FALLBACK_VERSION,
          downloadUrl: FALLBACK_DMG,
          loading: false,
        })
      }
    }
    void run()
  }, [])

  return (
    <section className="border border-phosphor-muted bg-surface/60 px-6 py-8 sm:px-10 sm:py-10">
      <div className="flex items-center gap-1 text-xs text-phosphor-dim">
        <span>user@mac:~$</span>
        <span className="text-phosphor">monkmode --install</span>
        <span className="inline-block h-3 w-2 animate-blink bg-phosphor" />
      </div>

      <pre
        aria-label="MONKMODE"
        className="mt-6 overflow-x-auto text-[6px] leading-[7px] sm:text-[9px] sm:leading-[10px]"
        style={{
          background:
            'linear-gradient(180deg, hsl(120 40% 82%) 0%, hsl(130 55% 70%) 40%, hsl(150 45% 58%) 80%, hsl(160 40% 42%) 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
        }}
      >
        {BANNER}
      </pre>

      <p className="mt-6 max-w-xl text-sm leading-relaxed text-foreground">
        <span className="text-phosphor-muted">// </span>
        strict macOS website blocker for deep work. once the timer starts there
        is no abort — until it expires.
      </p>

      <div className="mt-8 flex flex-wrap items-center gap-3">
        <a
          href={release.downloadUrl}
          target="_blank"
          rel="noreferrer"
          className="group inline-flex items-center gap-2 bg-phosphor px-5 py-3 text-sm font-bold text-background transition-colors hover:bg-phosphor-dim"
        >
          <span>{'>>'}</span>
          <span>DOWNLOAD.dmg</span>
          <span>{'<<'}</span>
        </a>
        <div className="inline-flex items-center gap-2 border border-phosphor-muted px-3 py-3 text-xs text-phosphor-dim">
          <span className="inline-block h-2 w-2 bg-phosphor" />
          {release.loading ? 'checking release...' : `latest: ${release.version}`}
        </div>
      </div>

      <div className="mt-6 flex flex-wrap gap-4 text-[11px] text-phosphor-muted">
        <span>// macOS 13+</span>
        <span>// native SwiftUI</span>
        <span>// zero telemetry</span>
      </div>
    </section>
  )
}
