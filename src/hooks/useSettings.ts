import { useEffect } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../db/db';
import { DEFAULT_SETTINGS, type Settings } from '../db/types';

/** Réglages de l'application, rechargés automatiquement à chaque écriture. */
export function useSettings(): Settings {
  const settings = useLiveQuery(() => db.settings.get('app'), []);
  return settings ?? DEFAULT_SETTINGS;
}

/**
 * Applique le thème choisi sur l'élément racine. En mode automatique, on
 * n'écrit aucun attribut : la feuille de style suit alors la préférence
 * système via `color-scheme` et les valeurs par défaut.
 */
export function useThemeEffect(theme: Settings['theme']): void {
  useEffect(() => {
    const root = document.documentElement;
    if (theme === 'auto') {
      const prefersLight = window.matchMedia('(prefers-color-scheme: light)');
      const apply = () => {
        root.setAttribute('data-theme', prefersLight.matches ? 'light' : 'dark');
      };
      apply();
      prefersLight.addEventListener('change', apply);
      return () => prefersLight.removeEventListener('change', apply);
    }

    root.setAttribute('data-theme', theme);
    return undefined;
  }, [theme]);

  // La couleur de la barre d'état iOS suit le fond de l'application.
  useEffect(() => {
    const meta = document.querySelector('meta[name="theme-color"]');
    if (!meta) return;
    const bg = getComputedStyle(document.documentElement).getPropertyValue('--bg').trim();
    if (bg) meta.setAttribute('content', bg);
  }, [theme]);
}
