/**
 * Facteurs de filtre.
 *
 * Un filtre absorbe une partie de la lumière : le « facteur » est le
 * multiplicateur de temps de pose qu'il impose, et son équivalent en IL vaut
 * log2 de ce facteur. Un filtre orange de facteur 4 coûte donc deux
 * diaphragmes.
 *
 * Les valeurs des filtres colorés valent pour la lumière du jour et pour un
 * film panchromatique ; sous éclairage tungstène, riche en rouge, un filtre
 * rouge coûte moins cher et un bleu davantage.
 */

export interface FilterPreset {
  id: string;
  name: string;
  /** Multiplicateur du temps de pose. */
  factor: number;
  category: 'bw' | 'nd' | 'color' | 'other';
  effect?: string;
}

export const FILTER_PRESETS: FilterPreset[] = [
  // Filtres colorés pour le noir et blanc : ils éclaircissent leur propre
  // couleur et assombrissent la complémentaire.
  { id: 'yellow-8', name: 'Jaune n°8', factor: 2, category: 'bw', effect: 'Assombrit légèrement le ciel, rend les nuages lisibles.' },
  { id: 'yellow-green-11', name: 'Jaune-vert n°11', factor: 4, category: 'bw', effect: 'Carnations plus naturelles, feuillages éclaircis.' },
  { id: 'orange-16', name: 'Orange n°16', factor: 4, category: 'bw', effect: 'Ciel nettement plus sombre, brume atténuée.' },
  { id: 'red-25', name: 'Rouge n°25', factor: 8, category: 'bw', effect: 'Ciel presque noir, contraste théâtral.' },
  { id: 'green-58', name: 'Vert n°58', factor: 8, category: 'bw', effect: 'Sépare les verts du feuillage.' },
  { id: 'blue-47', name: 'Bleu n°47', factor: 8, category: 'bw', effect: 'Accentue la brume atmosphérique.' },

  // Densités neutres : pour poser long ou ouvrir grand en plein jour.
  { id: 'nd-2', name: 'ND2 (0,3)', factor: 2, category: 'nd', effect: '1 IL' },
  { id: 'nd-4', name: 'ND4 (0,6)', factor: 4, category: 'nd', effect: '2 IL' },
  { id: 'nd-8', name: 'ND8 (0,9)', factor: 8, category: 'nd', effect: '3 IL' },
  { id: 'nd-16', name: 'ND16 (1,2)', factor: 16, category: 'nd', effect: '4 IL' },
  { id: 'nd-64', name: 'ND64 (1,8)', factor: 64, category: 'nd', effect: '6 IL' },
  { id: 'nd-1000', name: 'ND1000 (3,0)', factor: 1000, category: 'nd', effect: '10 IL' },

  // Conversion et effets.
  { id: 'polarizer', name: 'Polarisant', factor: 3, category: 'other', effect: 'Supprime les reflets, sature le ciel. Entre 1,5 et 2 IL selon l’orientation.' },
  { id: 'uv', name: 'UV / Skylight', factor: 1, category: 'other', effect: 'Aucune correction, sert surtout de protection frontale.' },
  { id: '85b', name: '85B (tungstène → jour)', factor: 2, category: 'color', effect: 'Pour exposer un film tungstène en plein jour.' },
  { id: '80a', name: '80A (jour → tungstène)', factor: 4, category: 'color', effect: 'Pour exposer un film lumière du jour sous ampoule.' },
  { id: 'r72', name: 'Infrarouge R72', factor: 32, category: 'other', effect: 'Coupe le visible. Le facteur varie beaucoup selon le film, à tester.' },
];

/** Convertit un facteur de filtre en diaphragmes. */
export const factorToStops = (factor: number): number =>
  Number.isFinite(factor) && factor > 0 ? Math.log2(factor) : 0;

/** Convertit des diaphragmes en facteur de filtre. */
export const stopsToFactor = (stops: number): number => Math.pow(2, stops);

/** Facteur cumulé de plusieurs filtres empilés : les IL s'additionnent. */
export const combinedStops = (factors: number[]): number =>
  factors.reduce((total, factor) => total + factorToStops(factor), 0);
