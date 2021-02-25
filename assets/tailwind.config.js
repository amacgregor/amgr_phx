const defaultTheme = require('tailwindcss/defaultTheme')
const colors = require('tailwindcss/colors')

module.exports = {
  darkMode: false,
  purge: [
    "../lib/amgr_web/live/**/*.ex",
    "../lib/amgr_web/live/**/*.leex",
    "../lib/amgr_web/templates/**/*.eex",
    "../lib/amgr_web/templates/**/*.leex",
    "../lib/amgr_web/views/**/*.ex",
    "../lib/amgr_web/components/**/*.ex",
    "./js/**/*.js"
  ],
  theme: {
    screens: {
      sm: "640px",
      md: "768px",
      lg: "1024px",
      "dark": {"raw": "(prefers-color-scheme: dark)"}
    },
    extend: {
      fontFamily: {
        sans: ['Inter var', 'Inter', ...defaultTheme.fontFamily.sans],
        mono: ['Fira Code VF', 'Fira Code', ...defaultTheme.fontFamily.mono]
      },
      colors: {
        brand: colors.violet,
        accent: colors.coolGray
      },
      screens: {
        'print': {'raw': 'print'}
      },
      typography: (theme) => ({
        DEFAULT: {
          css: {
            'a': {
              color: theme('colors.brand.700'),
              textDecoration: 'none',
              transition: "colors",
              transitionDuration: "150ms",
              transitionProperty: "border-color, color",
              transitionTimingFunction: "cubic-bezier(0.4, 0, 0.2, 1)",
              borderBottomColor: theme('colors.accent.500'),
              borderBottomWidth: 1,
              "&:hover": {
                color: theme('colors.brand.500'),
                borderBottomColor: theme('colors.accent.400'),
              }
            },
            'blockquote': {
              borderLeftColor: theme('colors.purple.500'),
            },
            'code': {
              color: null,
              fontWeight: null,
            },
            'code::before': {content: null},
            'code::after': {content: null},
            'pre': {
              color: null,
              backgroundColor: null,
            },
            'pre code': {
              backgroundColor: null,
              color: null,
              fontSize: null,
              fontFamily: null,
              lineHeight: null,
            },
            'pre code::before': {content: ''},
            'pre code::after': {content: ''},
          },
        },
        print: {
          css: {
            color: theme('colors.black'),
            h1: { color: theme('colors.black') },
            h2: { color: theme('colors.black') },
            h3: { color: theme('colors.black') },
            h4: { color: theme('colors.black') },
            h5: { color: theme('colors.black') },
            h6: { color: theme('colors.black') }
          }
        },
        dark: {
          css: {
            'blockquote': {
              color: theme('colors.gray.400'),
            },
            'pre': {
              backgroundColor: '#272822',
            },
            'pre code': {
              backgroundColor: null,
              color: null,
              fontSize: null,
              fontFamily: null,
              lineHeight: null,
            },
            color: theme('colors.gray.300'),
            h1: {
              color: theme('colors.gray.300'),
            },
            h2: {
              color: theme('colors.gray.300'),
            },
            h3: {
              color: theme('colors.gray.300'),
            },
            h4: {
              color: theme('colors.gray.300'),
            },
            h5: {
              color: theme('colors.gray.300'),
            },
            h6: {
              color: theme('colors.gray.300'),
            },
            figcaption: {
              color: theme('colors.gray.500'),
            },
            'thead': {
              color: theme('colors.gray.300')
            }
          }
        },
      }),
    },
  },
  variants: {
    borderWidth: ['responsive', 'last']
  },
  plugins: [
    require('@tailwindcss/typography')
  ],
};
