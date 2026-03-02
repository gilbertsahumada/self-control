import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { ArrowDownToLine, Lock, Shield, Zap } from 'lucide-react'

import { Badge } from './components/ui/badge'
import { Button } from './components/ui/button'
import { Separator } from './components/ui/separator'
import logoSvg from './assets/logo.svg'

const OWNER = 'gilbertsahumada'
const REPO = 'self-control'
const API_URL = `https://api.github.com/repos/${OWNER}/${REPO}/releases/latest`
const FALLBACK_VERSION = 'v1.0.0'
const FALLBACK_DMG = `https://github.com/${OWNER}/${REPO}/releases/latest`

type ReleaseState = {
  version: string
  downloadUrl: string
  loading: boolean
}

const FEATURES = [
  {
    title: 'Unstoppable Sessions',
    description: 'No stop button once the block starts. Focus stays protected until your timer ends.',
    icon: Lock,
  },
  {
    title: 'Dual-Layer Blocking',
    description: 'Combines /etc/hosts and macOS firewall for stronger and harder-to-bypass blocking.',
    icon: Shield,
  },
  {
    title: 'Native and Lightweight',
    description: 'Built in SwiftUI for macOS with minimal overhead and a clean native experience.',
    icon: Zap,
  },
]

function App() {
  const [release, setRelease] = useState<ReleaseState>({
    version: FALLBACK_VERSION,
    downloadUrl: FALLBACK_DMG,
    loading: true,
  })

  useEffect(() => {
    const fetchRelease = async () => {
      try {
        const response = await fetch(API_URL)
        if (!response.ok) throw new Error('release lookup failed')
        const data = await response.json()
        const dmgAsset = (data.assets as Array<{ name: string; browser_download_url: string }>).find((asset) =>
          asset.name.endsWith('.dmg')
        )

        setRelease({
          version: data.tag_name ?? FALLBACK_VERSION,
          downloadUrl: dmgAsset?.browser_download_url ?? FALLBACK_DMG,
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

    void fetchRelease()
  }, [])

  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_50%_-20%,rgba(91,108,255,0.20),transparent_45%),linear-gradient(180deg,#0b1020_0%,#080c18_100%)]" />

      <main className="mx-auto flex w-full max-w-3xl flex-col px-6 pb-16 pt-16 sm:px-8">
        <motion.section
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.3 }}
          className="rounded-2xl border border-border/70 bg-card/60 p-7"
        >
          <Badge variant="secondary" className="mb-5 w-fit">
            macOS · Focus-first
          </Badge>

          <div className="flex items-center gap-4">
            <img src={logoSvg} alt="SelfControl logo" className="h-12 w-12 sm:h-14 sm:w-14" />
            <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">SelfControl</h1>
          </div>
          <p className="mt-4 max-w-xl text-base text-muted-foreground">
            A strict website blocker for deep work. Download the latest DMG and start a protected focus session.
          </p>

          <div className="mt-7 flex flex-wrap items-center gap-3">
            <a href={release.downloadUrl} target="_blank" rel="noreferrer">
              <Button size="lg">
                <ArrowDownToLine className="mr-2 h-4 w-4" />
                Download .dmg
              </Button>
            </a>
            <Badge variant="secondary" className="px-3 py-1 text-sm">
              {release.loading ? 'Checking release...' : `Latest: ${release.version}`}
            </Badge>
          </div>

          <p className="mt-4 text-sm text-muted-foreground">
            Screenshot coming soon.
          </p>
        </motion.section>

        <section className="mt-8 rounded-2xl border border-border/70 bg-card/50 p-7">
          <h2 className="text-lg font-semibold">Why it works</h2>
          <div className="mt-4 grid gap-3">
            {FEATURES.map((feature) => (
              <div key={feature.title} className="rounded-lg border border-border/80 bg-background/40 p-4">
                <div className="mb-1 flex items-center gap-2 text-sm font-medium">
                  <feature.icon className="h-4 w-4 text-indigo-300" />
                  {feature.title}
                </div>
                <p className="text-sm text-muted-foreground">{feature.description}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="mt-8 rounded-2xl border border-border/70 bg-card/50 p-7">
          <h3 className="text-lg font-semibold">Install in 3 steps</h3>
          <ol className="mt-3 space-y-2 text-sm text-muted-foreground">
            <li className="flex gap-2">
              <span className="font-medium text-foreground">1.</span>
              Download the DMG, open it, and drag SelfControl to Applications.
            </li>
            <li className="flex gap-2">
              <span className="font-medium text-foreground">2.</span>
              <span>
                Open Terminal and run:
                <code className="ml-1 rounded bg-background/80 px-2 py-0.5 text-xs text-indigo-300">
                  xattr -cr /Applications/SelfControl.app
                </code>
              </span>
            </li>
            <li className="flex gap-2">
              <span className="font-medium text-foreground">3.</span>
              Open SelfControl from Applications. You only need step 2 once.
            </li>
          </ol>
          <Separator className="my-5" />
          <div className="flex flex-wrap gap-5 text-sm">
            <a className="text-indigo-300 hover:text-indigo-200" href={`https://github.com/${OWNER}/${REPO}`}>
              github.com/{OWNER}/{REPO}
            </a>
            <a className="text-indigo-300 hover:text-indigo-200" href={`https://github.com/${OWNER}/${REPO}/releases`}>
              View all releases
            </a>
          </div>
        </section>
      </main>
    </div>
  )
}

export default App
