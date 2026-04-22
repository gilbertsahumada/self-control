export function Scanlines() {
  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-0 z-50 mix-blend-multiply"
      style={{
        backgroundImage:
          'repeating-linear-gradient(0deg, rgba(0,0,0,0.18) 0px, rgba(0,0,0,0.18) 1px, transparent 1px, transparent 5px)',
      }}
    />
  )
}

export function Vignette() {
  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-0 z-40"
      style={{
        background:
          'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.55) 100%)',
      }}
    />
  )
}

export function CRTFlicker() {
  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-0 z-50 animate-crt-flicker bg-black/[0.02]"
    />
  )
}
