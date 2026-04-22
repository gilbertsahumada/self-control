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
        mono: ['Menlo', 'Monaco', 'Courier New', 'monospace'],
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
    },
  },
  plugins: [],
}
