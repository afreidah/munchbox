/** @type {import('tailwindcss').Config} */

// Catppuccin Mocha color palette
// https://catppuccin.com/palette
const catppuccin = {
  mocha: {
    rosewater: '#f5e0dc',
    flamingo: '#f2cdcd',
    pink: '#f5c2e7',
    mauve: '#cba6f7',
    red: '#f38ba8',
    maroon: '#eba0ac',
    peach: '#fab387',
    yellow: '#f9e2af',
    green: '#a6e3a1',
    teal: '#94e2d5',
    sky: '#89dceb',
    sapphire: '#74c7ec',
    blue: '#89b4fa',
    lavender: '#b4befe',
    text: '#cdd6f4',
    subtext1: '#bac2de',
    subtext0: '#a6adc8',
    overlay2: '#9399b2',
    overlay1: '#7f849c',
    overlay0: '#6c7086',
    surface2: '#585b70',
    surface1: '#45475a',
    surface0: '#313244',
    base: '#1e1e2e',
    mantle: '#181825',
    crust: '#11111b',
  }
}

module.exports = {
  content: ['content/**/*.md', 'layouts/**/*.html'],
  theme: {
    extend: {
      colors: {
        // Primary accent color (using mauve/lavender for a nice purple-blue)
        primary: {
          50: catppuccin.mocha.lavender,
          100: catppuccin.mocha.lavender,
          200: catppuccin.mocha.lavender,
          300: catppuccin.mocha.blue,
          400: catppuccin.mocha.blue,
          500: catppuccin.mocha.mauve,
          600: catppuccin.mocha.mauve,
          700: catppuccin.mocha.surface2,
          800: catppuccin.mocha.surface1,
          900: catppuccin.mocha.surface0,
        },
        // Secondary colors (surfaces and backgrounds)
        secondary: {
          50: catppuccin.mocha.text,
          100: catppuccin.mocha.subtext1,
          200: catppuccin.mocha.overlay2,
          300: catppuccin.mocha.overlay1,
          400: catppuccin.mocha.overlay0,
          500: catppuccin.mocha.surface2,
          600: catppuccin.mocha.surface1,
          700: catppuccin.mocha.base,
          800: catppuccin.mocha.mantle,
          900: catppuccin.mocha.crust,
        },
        // Highlight color (using peach for warm accent)
        highlight: {
          50: catppuccin.mocha.rosewater,
          100: catppuccin.mocha.flamingo,
          200: catppuccin.mocha.pink,
          300: catppuccin.mocha.maroon,
          400: catppuccin.mocha.peach,
          500: catppuccin.mocha.peach,
          600: catppuccin.mocha.red,
          700: catppuccin.mocha.red,
          800: catppuccin.mocha.maroon,
          900: catppuccin.mocha.maroon,
        },
        // Expose all catppuccin colors directly
        ctp: catppuccin.mocha,
      },
    },
  },
  plugins: [],
}
