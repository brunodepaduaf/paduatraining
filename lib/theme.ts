export const palette = {
  light: {
    background: '#F8F4F6', surface: '#FFFBFD', surfaceElevated: '#F0E9ED', border: '#D8CCD2',
    textPrimary: '#2D252A', textSecondary: '#6C5E66', brand: '#9E365F', brandStrong: '#B84D78',
    success: '#39795D', warning: '#9A651F', danger: '#B84250', info: '#4E719C'
  },
  dark: {
    background: '#191719', surface: '#242125', surfaceElevated: '#302B30', border: '#494149',
    textPrimary: '#F3EEF1', textSecondary: '#C8BEC4', brand: '#B95078', brandStrong: '#D36B94',
    success: '#5EA887', warning: '#D49A57', danger: '#D96E78', info: '#83A9D5'
  }
} as const;

export const space = { xxs: 4, xs: 8, sm: 12, md: 16, lg: 24, xl: 32, xxl: 48 } as const;
export const radius = { control: 12, surface: 16, round: 999 } as const;
