/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          50:  '#f6f1fd',
          100: '#efdefb',
          200: '#dfbdf7',
          300: '#cc96f1',
          400: '#b866e9',
          500: '#9d38eb',
          600: '#8524cc',
          700: '#721eae',
          800: '#601d8d',
          900: '#4f1d72',
        },
        brand: {
          lime: '#daff50',
          cream: '#fdf6de',
          ink: '#000000',
          top: '#fdfff5',
          bottom: '#e9f3c2',
        },
        surface: '#fdfff5',
      },
    },
  },
  plugins: [],
}
