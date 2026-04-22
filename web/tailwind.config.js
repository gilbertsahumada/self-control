/** @type {import('tailwindcss').Config} */
export default {
  darkMode: ['class'],
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        background: 'hsl(var(--background))',
        surface: 'hsl(var(--surface))',
        foreground: 'hsl(var(--foreground))',
        phosphor: {
          DEFAULT: 'hsl(var(--phosphor))',
          dim: 'hsl(var(--phosphor-dim))',
          muted: 'hsl(var(--phosphor-muted))',
        },
        amber: {
          DEFAULT: 'hsl(var(--amber))',
        },
        danger: {
          DEFAULT: 'hsl(var(--danger))',
        },
        border: 'hsl(var(--border))',
      },
      fontFamily: {
        mono: ['"JetBrains Mono"', 'Menlo', 'Monaco', 'Courier New', 'monospace'],
      },
      borderRadius: {
        none: '0',
        sm: '0',
        md: '0',
        lg: '0',
      },
      boxShadow: {
        phosphor: '0 0 20px rgba(115, 255, 140, 0.35)',
        phosphorSoft: '0 0 8px rgba(115, 255, 140, 0.2)',
      },
      keyframes: {
        'crt-flicker': {
          '0%, 100%': { opacity: '0.3' },
          '50%': { opacity: '0.9' },
        },
        blink: {
          '0%, 49%': { opacity: '1' },
          '50%, 100%': { opacity: '0' },
        },
      },
      animation: {
        'crt-flicker': 'crt-flicker 0.3s ease-in-out infinite',
        blink: 'blink 1.1s step-end infinite',
      },
    },
  },
  plugins: [],
}
