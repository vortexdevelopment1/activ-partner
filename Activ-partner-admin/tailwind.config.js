/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          50:  '#ecfdf8',
          100: '#d1faef',
          200: '#a7f3df',
          300: '#6ee7c8',
          400: '#34d3aa',
          500: '#16b58e',
          600: '#0d9275',
          700: '#0f755f',
          800: '#115e4f',
          900: '#124e43',
        },
        surface: '#f5f7f6',
      },
    },
  },
  plugins: [],
}
