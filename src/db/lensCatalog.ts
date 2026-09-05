/**
 * Banque d'objectifs 24×36.
 *
 * Même principe que la banque de boîtiers : une référence pour préremplir la
 * saisie, filtrée par la monture du matériel déjà déclaré. On y trouve les
 * optiques que l'on croise réellement en occasion, pas un inventaire
 * exhaustif — l'ajout manuel reste possible pour tout le reste.
 */

import { normalise } from './cameraCatalog';

export interface CatalogLens {
  brand: string;
  name: string;
  mount: string;
  focalMin: number;
  /** Égale à `focalMin` pour une focale fixe. */
  focalMax: number;
  maxAperture: number;
  minAperture: number;
  /** Diamètre de filtre en mm. */
  filterThread?: number;
  notes?: string;
}

export const LENS_CATALOG: CatalogLens[] = [
  // ---------------------------------------------------------------------------
  // Minolta SR (MC / MD)
  // ---------------------------------------------------------------------------
  { brand: 'Minolta', name: 'MD 50mm f/1.7', mount: 'Minolta SR', focalMin: 50, focalMax: 50, maxAperture: 1.7, minAperture: 16, filterThread: 49, notes: 'L’objectif livré avec la plupart des X-300 et X-700.' },
  { brand: 'Minolta', name: 'MD 50mm f/1.4', mount: 'Minolta SR', focalMin: 50, focalMax: 50, maxAperture: 1.4, minAperture: 16, filterThread: 49 },
  { brand: 'Minolta', name: 'MD 50mm f/2', mount: 'Minolta SR', focalMin: 50, focalMax: 50, maxAperture: 2, minAperture: 16, filterThread: 49 },
  { brand: 'Minolta', name: 'MD 28mm f/2.8', mount: 'Minolta SR', focalMin: 28, focalMax: 28, maxAperture: 2.8, minAperture: 22, filterThread: 49 },
  { brand: 'Minolta', name: 'MD 35mm f/2.8', mount: 'Minolta SR', focalMin: 35, focalMax: 35, maxAperture: 2.8, minAperture: 22, filterThread: 49 },
  { brand: 'Minolta', name: 'MD 85mm f/2', mount: 'Minolta SR', focalMin: 85, focalMax: 85, maxAperture: 2, minAperture: 22, filterThread: 55 },
  { brand: 'Minolta', name: 'MD 135mm f/2.8', mount: 'Minolta SR', focalMin: 135, focalMax: 135, maxAperture: 2.8, minAperture: 32, filterThread: 55 },
  { brand: 'Minolta', name: 'MD 100mm f/2.5', mount: 'Minolta SR', focalMin: 100, focalMax: 100, maxAperture: 2.5, minAperture: 22, filterThread: 49 },
  { brand: 'Minolta', name: 'MD Zoom 35-70mm f/3.5', mount: 'Minolta SR', focalMin: 35, focalMax: 70, maxAperture: 3.5, minAperture: 22, filterThread: 55 },
  { brand: 'Minolta', name: 'MD Zoom 70-210mm f/4', mount: 'Minolta SR', focalMin: 70, focalMax: 210, maxAperture: 4, minAperture: 32, filterThread: 55 },
  { brand: 'Minolta', name: 'MC Rokkor-PG 58mm f/1.2', mount: 'Minolta SR', focalMin: 58, focalMax: 58, maxAperture: 1.2, minAperture: 16, filterThread: 55 },
  { brand: 'Minolta', name: 'MD 24mm f/2.8', mount: 'Minolta SR', focalMin: 24, focalMax: 24, maxAperture: 2.8, minAperture: 22, filterThread: 55 },

  // ---------------------------------------------------------------------------
  // Canon FD
  // ---------------------------------------------------------------------------
  { brand: 'Canon', name: 'FD 50mm f/1.8', mount: 'Canon FD', focalMin: 50, focalMax: 50, maxAperture: 1.8, minAperture: 22, filterThread: 52 },
  { brand: 'Canon', name: 'FD 50mm f/1.4', mount: 'Canon FD', focalMin: 50, focalMax: 50, maxAperture: 1.4, minAperture: 22, filterThread: 52 },
  { brand: 'Canon', name: 'FD 28mm f/2.8', mount: 'Canon FD', focalMin: 28, focalMax: 28, maxAperture: 2.8, minAperture: 22, filterThread: 52 },
  { brand: 'Canon', name: 'FD 35mm f/2', mount: 'Canon FD', focalMin: 35, focalMax: 35, maxAperture: 2, minAperture: 22, filterThread: 52 },
  { brand: 'Canon', name: 'FD 85mm f/1.8', mount: 'Canon FD', focalMin: 85, focalMax: 85, maxAperture: 1.8, minAperture: 22, filterThread: 55 },
  { brand: 'Canon', name: 'FD 135mm f/2.8', mount: 'Canon FD', focalMin: 135, focalMax: 135, maxAperture: 2.8, minAperture: 32, filterThread: 52 },
  { brand: 'Canon', name: 'FD 100mm f/2.8', mount: 'Canon FD', focalMin: 100, focalMax: 100, maxAperture: 2.8, minAperture: 32, filterThread: 55 },
  { brand: 'Canon', name: 'FD 24mm f/2.8', mount: 'Canon FD', focalMin: 24, focalMax: 24, maxAperture: 2.8, minAperture: 22, filterThread: 55 },
  { brand: 'Canon', name: 'FD 35-70mm f/3.5-4.5', mount: 'Canon FD', focalMin: 35, focalMax: 70, maxAperture: 3.5, minAperture: 22, filterThread: 52 },
  { brand: 'Canon', name: 'FD 70-210mm f/4', mount: 'Canon FD', focalMin: 70, focalMax: 210, maxAperture: 4, minAperture: 32, filterThread: 58 },

  // ---------------------------------------------------------------------------
  // Nikon F
  // ---------------------------------------------------------------------------
  { brand: 'Nikon', name: 'Nikkor 50mm f/1.8 AI-S', mount: 'Nikon F', focalMin: 50, focalMax: 50, maxAperture: 1.8, minAperture: 22, filterThread: 52 },
  { brand: 'Nikon', name: 'Nikkor 50mm f/1.4 AI-S', mount: 'Nikon F', focalMin: 50, focalMax: 50, maxAperture: 1.4, minAperture: 16, filterThread: 52 },
  { brand: 'Nikon', name: 'Nikkor 35mm f/2 AI-S', mount: 'Nikon F', focalMin: 35, focalMax: 35, maxAperture: 2, minAperture: 22, filterThread: 52 },
  { brand: 'Nikon', name: 'Nikkor 28mm f/2.8 AI-S', mount: 'Nikon F', focalMin: 28, focalMax: 28, maxAperture: 2.8, minAperture: 22, filterThread: 52 },
  { brand: 'Nikon', name: 'Nikkor 85mm f/2 AI-S', mount: 'Nikon F', focalMin: 85, focalMax: 85, maxAperture: 2, minAperture: 22, filterThread: 52 },
  { brand: 'Nikon', name: 'Nikkor 105mm f/2.5 AI-S', mount: 'Nikon F', focalMin: 105, focalMax: 105, maxAperture: 2.5, minAperture: 32, filterThread: 52, notes: 'L’objectif à portraits de Nikon, réputé depuis les années 1970.' },
  { brand: 'Nikon', name: 'Nikkor 135mm f/2.8 AI-S', mount: 'Nikon F', focalMin: 135, focalMax: 135, maxAperture: 2.8, minAperture: 32, filterThread: 52 },
  { brand: 'Nikon', name: 'Nikkor 24mm f/2.8 AI-S', mount: 'Nikon F', focalMin: 24, focalMax: 24, maxAperture: 2.8, minAperture: 22, filterThread: 52 },
  { brand: 'Nikon', name: 'AF Nikkor 50mm f/1.8D', mount: 'Nikon F', focalMin: 50, focalMax: 50, maxAperture: 1.8, minAperture: 22, filterThread: 52 },
  { brand: 'Nikon', name: 'AF Nikkor 35-70mm f/3.3-4.5', mount: 'Nikon F', focalMin: 35, focalMax: 70, maxAperture: 3.3, minAperture: 22, filterThread: 52 },
  { brand: 'Nikon', name: 'Series E 50mm f/1.8', mount: 'Nikon F', focalMin: 50, focalMax: 50, maxAperture: 1.8, minAperture: 22, filterThread: 52 },

  // ---------------------------------------------------------------------------
  // Pentax K
  // ---------------------------------------------------------------------------
  { brand: 'Pentax', name: 'SMC Pentax-M 50mm f/1.7', mount: 'Pentax K', focalMin: 50, focalMax: 50, maxAperture: 1.7, minAperture: 22, filterThread: 49 },
  { brand: 'Pentax', name: 'SMC Pentax-M 50mm f/2', mount: 'Pentax K', focalMin: 50, focalMax: 50, maxAperture: 2, minAperture: 22, filterThread: 49 },
  { brand: 'Pentax', name: 'SMC Pentax-M 28mm f/2.8', mount: 'Pentax K', focalMin: 28, focalMax: 28, maxAperture: 2.8, minAperture: 22, filterThread: 49 },
  { brand: 'Pentax', name: 'SMC Pentax-M 35mm f/2.8', mount: 'Pentax K', focalMin: 35, focalMax: 35, maxAperture: 2.8, minAperture: 22, filterThread: 49 },
  { brand: 'Pentax', name: 'SMC Pentax-M 135mm f/3.5', mount: 'Pentax K', focalMin: 135, focalMax: 135, maxAperture: 3.5, minAperture: 32, filterThread: 49 },
  { brand: 'Pentax', name: 'SMC Pentax-A 50mm f/1.4', mount: 'Pentax K', focalMin: 50, focalMax: 50, maxAperture: 1.4, minAperture: 22, filterThread: 49 },

  // ---------------------------------------------------------------------------
  // M42 à vis
  // ---------------------------------------------------------------------------
  { brand: 'Pentax', name: 'Super-Takumar 50mm f/1.4', mount: 'M42', focalMin: 50, focalMax: 50, maxAperture: 1.4, minAperture: 16, filterThread: 49, notes: 'Les premières séries jaunissent avec le temps, à cause du thorium du verre.' },
  { brand: 'Pentax', name: 'Super-Takumar 55mm f/1.8', mount: 'M42', focalMin: 55, focalMax: 55, maxAperture: 1.8, minAperture: 16, filterThread: 49 },
  { brand: 'Pentax', name: 'Super-Takumar 35mm f/3.5', mount: 'M42', focalMin: 35, focalMax: 35, maxAperture: 3.5, minAperture: 16, filterThread: 49 },
  { brand: 'Carl Zeiss Jena', name: 'Tessar 50mm f/2.8', mount: 'M42', focalMin: 50, focalMax: 50, maxAperture: 2.8, minAperture: 22, filterThread: 49 },
  { brand: 'Carl Zeiss Jena', name: 'Pancolar 50mm f/1.8', mount: 'M42', focalMin: 50, focalMax: 50, maxAperture: 1.8, minAperture: 22, filterThread: 49 },
  { brand: 'Carl Zeiss Jena', name: 'Flektogon 35mm f/2.4', mount: 'M42', focalMin: 35, focalMax: 35, maxAperture: 2.4, minAperture: 22, filterThread: 49, notes: 'Mise au point très rapprochée pour un grand angle de cette époque.' },
  { brand: 'Helios', name: '44-2 58mm f/2', mount: 'M42', focalMin: 58, focalMax: 58, maxAperture: 2, minAperture: 16, filterThread: 49, notes: 'Le fameux flou tourbillonnant à pleine ouverture.' },
  { brand: 'Industar', name: '61 L/Z 50mm f/2.8', mount: 'M42', focalMin: 50, focalMax: 50, maxAperture: 2.8, minAperture: 16, filterThread: 49 },

  // ---------------------------------------------------------------------------
  // Olympus OM
  // ---------------------------------------------------------------------------
  { brand: 'Olympus', name: 'Zuiko 50mm f/1.8', mount: 'Olympus OM', focalMin: 50, focalMax: 50, maxAperture: 1.8, minAperture: 16, filterThread: 49 },
  { brand: 'Olympus', name: 'Zuiko 50mm f/1.4', mount: 'Olympus OM', focalMin: 50, focalMax: 50, maxAperture: 1.4, minAperture: 16, filterThread: 49 },
  { brand: 'Olympus', name: 'Zuiko 28mm f/2.8', mount: 'Olympus OM', focalMin: 28, focalMax: 28, maxAperture: 2.8, minAperture: 22, filterThread: 49 },
  { brand: 'Olympus', name: 'Zuiko 35mm f/2.8', mount: 'Olympus OM', focalMin: 35, focalMax: 35, maxAperture: 2.8, minAperture: 16, filterThread: 49 },
  { brand: 'Olympus', name: 'Zuiko 85mm f/2', mount: 'Olympus OM', focalMin: 85, focalMax: 85, maxAperture: 2, minAperture: 16, filterThread: 49 },
  { brand: 'Olympus', name: 'Zuiko 135mm f/3.5', mount: 'Olympus OM', focalMin: 135, focalMax: 135, maxAperture: 3.5, minAperture: 22, filterThread: 49 },

  // ---------------------------------------------------------------------------
  // Contax / Yashica
  // ---------------------------------------------------------------------------
  { brand: 'Carl Zeiss', name: 'Planar T* 50mm f/1.7', mount: 'Contax/Yashica', focalMin: 50, focalMax: 50, maxAperture: 1.7, minAperture: 22, filterThread: 55 },
  { brand: 'Carl Zeiss', name: 'Planar T* 50mm f/1.4', mount: 'Contax/Yashica', focalMin: 50, focalMax: 50, maxAperture: 1.4, minAperture: 16, filterThread: 55 },
  { brand: 'Carl Zeiss', name: 'Distagon T* 28mm f/2.8', mount: 'Contax/Yashica', focalMin: 28, focalMax: 28, maxAperture: 2.8, minAperture: 22, filterThread: 55 },
  { brand: 'Carl Zeiss', name: 'Distagon T* 35mm f/2.8', mount: 'Contax/Yashica', focalMin: 35, focalMax: 35, maxAperture: 2.8, minAperture: 22, filterThread: 55 },
  { brand: 'Carl Zeiss', name: 'Sonnar T* 85mm f/2.8', mount: 'Contax/Yashica', focalMin: 85, focalMax: 85, maxAperture: 2.8, minAperture: 22, filterThread: 55 },
  { brand: 'Yashica', name: 'ML 50mm f/1.9', mount: 'Contax/Yashica', focalMin: 50, focalMax: 50, maxAperture: 1.9, minAperture: 16, filterThread: 52 },

  // ---------------------------------------------------------------------------
  // Leica M
  // ---------------------------------------------------------------------------
  { brand: 'Leica', name: 'Summicron-M 35mm f/2', mount: 'Leica M', focalMin: 35, focalMax: 35, maxAperture: 2, minAperture: 16, filterThread: 39 },
  { brand: 'Leica', name: 'Summicron-M 50mm f/2', mount: 'Leica M', focalMin: 50, focalMax: 50, maxAperture: 2, minAperture: 16, filterThread: 39 },
  { brand: 'Leica', name: 'Summilux-M 35mm f/1.4', mount: 'Leica M', focalMin: 35, focalMax: 35, maxAperture: 1.4, minAperture: 16, filterThread: 46 },
  { brand: 'Leica', name: 'Elmarit-M 28mm f/2.8', mount: 'Leica M', focalMin: 28, focalMax: 28, maxAperture: 2.8, minAperture: 22, filterThread: 46 },
  { brand: 'Leica', name: 'Elmar-M 50mm f/2.8', mount: 'Leica M', focalMin: 50, focalMax: 50, maxAperture: 2.8, minAperture: 16, filterThread: 39 },
  { brand: 'Voigtländer', name: 'Nokton 40mm f/1.4', mount: 'Leica M', focalMin: 40, focalMax: 40, maxAperture: 1.4, minAperture: 16, filterThread: 43 },
  { brand: 'Voigtländer', name: 'Color-Skopar 35mm f/2.5', mount: 'Leica M', focalMin: 35, focalMax: 35, maxAperture: 2.5, minAperture: 22, filterThread: 39 },

  // ---------------------------------------------------------------------------
  // Autofocus : Canon EF, Minolta A, Pentax KAF
  // ---------------------------------------------------------------------------
  { brand: 'Canon', name: 'EF 50mm f/1.8 II', mount: 'Canon EF', focalMin: 50, focalMax: 50, maxAperture: 1.8, minAperture: 22, filterThread: 52 },
  { brand: 'Canon', name: 'EF 50mm f/1.4 USM', mount: 'Canon EF', focalMin: 50, focalMax: 50, maxAperture: 1.4, minAperture: 22, filterThread: 58 },
  { brand: 'Canon', name: 'EF 28-105mm f/3.5-4.5 USM', mount: 'Canon EF', focalMin: 28, focalMax: 105, maxAperture: 3.5, minAperture: 22, filterThread: 58 },
  { brand: 'Canon', name: 'EF 24-105mm f/4L IS USM', mount: 'Canon EF', focalMin: 24, focalMax: 105, maxAperture: 4, minAperture: 22, filterThread: 77 },
  { brand: 'Minolta', name: 'AF 50mm f/1.7', mount: 'Minolta A', focalMin: 50, focalMax: 50, maxAperture: 1.7, minAperture: 22, filterThread: 49 },
  { brand: 'Minolta', name: 'AF 28-85mm f/3.5-4.5', mount: 'Minolta A', focalMin: 28, focalMax: 85, maxAperture: 3.5, minAperture: 22, filterThread: 55 },
  { brand: 'Pentax', name: 'SMC FA 50mm f/1.4', mount: 'Pentax KAF', focalMin: 50, focalMax: 50, maxAperture: 1.4, minAperture: 22, filterThread: 49 },
  { brand: 'Pentax', name: 'SMC FA 43mm f/1.9 Limited', mount: 'Pentax KAF', focalMin: 43, focalMax: 43, maxAperture: 1.9, minAperture: 22, filterThread: 49 },
];

/** Recherche par marque, nom ou monture, insensible à la casse et aux accents. */
export function searchLenses(query: string, mount?: string, limit = 24): CatalogLens[] {
  const terms = normalise(query).split(/\s+/).filter(Boolean);
  const pool = mount ? LENS_CATALOG.filter((lens) => lens.mount === mount) : LENS_CATALOG;

  // Sans recherche mais avec une monture connue, on propose d'emblée ce qui
  // s'y monte : c'est le cas le plus fréquent.
  if (terms.length === 0) return mount ? pool.slice(0, limit) : [];

  return pool
    .filter((lens) => {
      const haystack = normalise(`${lens.brand} ${lens.name} ${lens.mount}`);
      return terms.every((term) => haystack.includes(term));
    })
    .slice(0, limit);
}
