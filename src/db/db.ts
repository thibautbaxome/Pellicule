import Dexie, { type EntityTable } from 'dexie';
import type {
  Attachment,
  Camera,
  FilmStock,
  Frame,
  ID,
  Lens,
  Roll,
  Settings,
} from './types';
import { DEFAULT_SETTINGS } from './types';
import { FILM_CATALOG } from './filmCatalog';

/**
 * Base locale de Pellicule.
 *
 * Une seule base IndexedDB, ouverte pour toute la durée de vie de l'onglet.
 * Les index déclarés ci-dessous sont ceux dont les écrans se servent pour
 * trier ou filtrer sans charger toute une table en mémoire.
 */
class PelliculeDB extends Dexie {
  cameras!: EntityTable<Camera, 'id'>;
  lenses!: EntityTable<Lens, 'id'>;
  filmStocks!: EntityTable<FilmStock, 'id'>;
  rolls!: EntityTable<Roll, 'id'>;
  frames!: EntityTable<Frame, 'id'>;
  attachments!: EntityTable<Attachment, 'id'>;
  settings!: EntityTable<Settings, 'id'>;

  constructor() {
    super('pellicule');
    this.version(1).stores({
      cameras: 'id, name, archived',
      lenses: 'id, name, archived',
      filmStocks: 'id, brand, name, iso, type, isCustom',
      rolls: 'id, status, loadedAt, cameraId, filmStockId',
      // L'index composé [rollId+number] garantit l'ordre des vues d'un
      // rouleau et sert à détecter les doublons de numéro.
      frames: 'id, rollId, [rollId+number], shotAt, status',
      attachments: 'id',
      settings: 'id',
    });
  }
}

export const db = new PelliculeDB();

export const newId = (): ID =>
  typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

export const now = (): string => new Date().toISOString();

/**
 * Prépare la base au premier lancement : réglages par défaut et catalogue de
 * pellicules. Les films livrés portent un identifiant stable, donc on
 * n'ajoute que ceux qui manquent — une pellicule que l'utilisateur a
 * modifiée ou supprimée n'est jamais réécrite par une mise à jour de l'app.
 */
export async function initDatabase(): Promise<void> {
  await db.transaction('rw', db.settings, db.filmStocks, async () => {
    const settings = await db.settings.get('app');
    if (!settings) {
      await db.settings.put({ ...DEFAULT_SETTINGS, updatedAt: now() });
    }

    const existing = new Set(await db.filmStocks.toCollection().primaryKeys());
    const missing = FILM_CATALOG.filter((film) => !existing.has(film.id)).map((film) => ({
      ...film,
      isCustom: false,
      createdAt: now(),
      updatedAt: now(),
    }));
    if (missing.length > 0) {
      await db.filmStocks.bulkPut(missing);
    }
  });
}

export async function getSettings(): Promise<Settings> {
  return (await db.settings.get('app')) ?? { ...DEFAULT_SETTINGS };
}

export async function updateSettings(patch: Partial<Settings>): Promise<void> {
  const current = await getSettings();
  await db.settings.put({ ...current, ...patch, id: 'app', updatedAt: now() });
}
