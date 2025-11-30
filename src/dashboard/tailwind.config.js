/** @type {import('tailwindcss').Config} */

const colors = require('tailwindcss/colors')

module.exports = {
  content: ['content/**/*.md', 'layouts/**/*.html'],
  //darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: colors.indigo,
        secondary: colors.slate,
        highlight: colors.red,
      },
    },
  },
  plugins: [],
}
