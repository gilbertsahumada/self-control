import { useEffect, useMemo, useState } from 'react'
import { motion } from 'framer-motion'
import { ArrowDownToLine, Lock, Shield, Timer, Zap } from 'lucide-react'

import { Badge } from './components/ui/badge'
import { Button } from './components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './components/ui/card'
import { Separator } from './components/ui/separator'

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

  const featureCards = useMemo(
    () => [
      {
        title: 'Unstoppable Sessions',
        icon: Lock,
        description: 'Once a block starts, there is no stop button. You stay focused until time runs out.',
      },
      {
        title: 'Dual-Layer Blocking',
        icon: Shield,
        description: 'Combines /etc/hosts and macOS firewall rules for stronger website blocking.',
      },
      {
        title: 'Enforced Every Minute',
        icon: Timer,
        description: 'A background enforcer reapplies protection if files are changed manually.',
      },
      {
        title: 'Fast and Native',
        icon: Zap,
        description: 'Built in SwiftUI for macOS with lightweight behavior and adaptive updates.',
      },
    ],
    []
  )

  return (
    <div className="relative overflow-hidden">
      <div className="absolute inset-0 -z-10 bg-[radial-gradient(circle_at_20%_20%,rgba(99,102,241,0.28),transparent_35%),radial-gradient(circle_at_80%_10%,rgba(76,29,149,0.24),transparent_30%),linear-gradient(180deg,#090b17_0%,#05070f_60%,#04050a_100%)]" />

      <main className="mx-auto flex w-full max-w-6xl flex-col gap-16 px-6 pb-20 pt-10 sm:px-10">
        <motion.section
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.45 }}
          className="rounded-2xl border border-border/70 bg-card/80 p-8 backdrop-blur"
        >
          <Badge variant="secondary" className="mb-4 w-fit">
            macOS only · Dark focus mode
          </Badge>
          <h1 className="text-4xl font-semibold tracking-tight text-foreground sm:text-6xl">SelfControl</h1>
          <p className="mt-4 max-w-2xl text-lg text-muted-foreground">
            Block distracting websites and protect deep work. Download the latest DMG and install in minutes.
          </p>

          <div className="mt-8 flex flex-wrap items-center gap-4">
            <a href={release.downloadUrl} target="_blank" rel="noreferrer">
              <Button size="lg">
                <ArrowDownToLine className="mr-2 h-4 w-4" />
                Download for macOS
              </Button>
            </a>
            <Badge variant="secondary" className="px-3 py-1 text-sm">
              {release.loading ? 'Checking release…' : `Latest: ${release.version}`}
            </Badge>
          </div>

          <motion.div
            initial={{ opacity: 0, scale: 0.98 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.2, duration: 0.45 }}
            className="mt-8 rounded-xl border border-border bg-gradient-to-b from-indigo-500/10 to-indigo-950/10 p-6"
          >
            <div className="rounded-lg border border-border/80 bg-black/30 p-6">
              <p className="mb-3 text-xs uppercase tracking-wider text-muted-foreground">App Preview</p>
              <div className="h-56 rounded-md border border-dashed border-indigo-400/40 bg-[linear-gradient(120deg,rgba(79,70,229,0.15),rgba(49,46,129,0.35))] p-6 sm:h-72">
                <div className="h-full w-full rounded border border-indigo-300/20 bg-slate-950/40" />
              </div>
              <p className="mt-3 text-sm text-muted-foreground">Placeholder mockup (replace with your screenshot later).</p>
            </div>
          </motion.div>
        </motion.section>

        <section>
          <h2 className="text-2xl font-semibold sm:text-3xl">Why people use it</h2>
          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            {featureCards.map((feature, index) => (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, y: 18 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, amount: 0.2 }}
                transition={{ duration: 0.35, delay: index * 0.07 }}
              >
                <Card className="h-full bg-card/80">
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2 text-lg">
                      <feature.icon className="h-5 w-5 text-indigo-300" />
                      {feature.title}
                    </CardTitle>
                    <CardDescription>{feature.description}</CardDescription>
                  </CardHeader>
                </Card>
              </motion.div>
            ))}
          </div>
        </section>

        <section className="grid gap-6 rounded-2xl border border-border/70 bg-card/80 p-8 sm:grid-cols-2">
          <Card className="border-none bg-transparent shadow-none">
            <CardHeader className="p-0">
              <CardTitle>Install in 2 steps</CardTitle>
              <CardDescription>Everything stays simple and native.</CardDescription>
            </CardHeader>
            <CardContent className="mt-4 space-y-3 p-0 text-sm text-muted-foreground">
              <p>1. Download the latest DMG from the button above.</p>
              <p>2. Open DMG and drag SelfControl.app to Applications.</p>
              <p>3. Launch and start your first focused session.</p>
            </CardContent>
          </Card>

          <Card className="border-border/80 bg-slate-950/50">
            <CardHeader>
              <CardTitle>Open Source</CardTitle>
              <CardDescription>Inspect the code, suggest improvements, and track releases.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3 text-sm">
              <a className="text-indigo-300 hover:text-indigo-200" href={`https://github.com/${OWNER}/${REPO}`}>
                github.com/{OWNER}/{REPO}
              </a>
              <Separator />
              <a className="text-indigo-300 hover:text-indigo-200" href={`https://github.com/${OWNER}/${REPO}/releases`}>
                View all releases
              </a>
            </CardContent>
          </Card>
        </section>
      </main>
    </div>
  )
}

export default App
