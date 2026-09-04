import { useEffect, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../db/db';
import type { Camera, FilmStock, Frame, Lens, Roll } from '../db/types';

/** Index par identifiant, pour retrouver un objet lié sans requête ciblée. */
export type ById<T> = Record<string, T>;

const indexById = <T extends { id: string }>(items: T[] | undefined): ById<T> =>
  Object.fromEntries((items ?? []).map((item) => [item.id, item]));

export function useCameras(includeArchived = false): Camera[] {
  return (
    useLiveQuery(async () => {
      const all = await db.cameras.orderBy('name').toArray();
      return includeArchived ? all : all.filter((camera) => !camera.archived);
    }, [includeArchived]) ?? []
  );
}

export function useLenses(includeArchived = false): Lens[] {
  return (
    useLiveQuery(async () => {
      const all = await db.lenses.orderBy('name').toArray();
      return includeArchived ? all : all.filter((lens) => !lens.archived);
    }, [includeArchived]) ?? []
  );
}

export function useFilmStocks(): FilmStock[] {
  return (
    useLiveQuery(async () => {
      const all = await db.filmStocks.toArray();
      return all.sort(
        (a, b) => a.brand.localeCompare(b.brand, 'fr') || a.name.localeCompare(b.name, 'fr'),
      );
    }, []) ?? []
  );
}

export function useCamerasById(): ById<Camera> {
  return indexById(useLiveQuery(() => db.cameras.toArray(), []));
}

export function useLensesById(): ById<Lens> {
  return indexById(useLiveQuery(() => db.lenses.toArray(), []));
}

export function useFilmStocksById(): ById<FilmStock> {
  return indexById(useLiveQuery(() => db.filmStocks.toArray(), []));
}

export function useRoll(rollId: string | undefined): Roll | undefined {
  return useLiveQuery(
    () => (rollId ? db.rolls.get(rollId) : undefined),
    [rollId],
  );
}

/** Vues d'un rouleau, triées par numéro croissant. */
export function useFrames(rollId: string | undefined): Frame[] {
  return (
    useLiveQuery(async () => {
      if (!rollId) return [];
      const frames = await db.frames.where('rollId').equals(rollId).toArray();
      return frames.sort((a, b) => a.number - b.number);
    }, [rollId]) ?? []
  );
}

export function useFrame(frameId: string | undefined): Frame | undefined {
  return useLiveQuery(
    () => (frameId && frameId !== 'new' ? db.frames.get(frameId) : undefined),
    [frameId],
  );
}

/** Tous les rouleaux, du plus récemment chargé au plus ancien. */
export function useRolls(): Roll[] {
  return (
    useLiveQuery(async () => {
      const rolls = await db.rolls.toArray();
      return rolls.sort((a, b) => b.loadedAt.localeCompare(a.loadedAt));
    }, []) ?? []
  );
}

/** Nombre de vues enregistrées par rouleau, indexé par identifiant de rouleau. */
export function useFrameCounts(): Record<string, number> {
  return (
    useLiveQuery(async () => {
      const counts: Record<string, number> = {};
      await db.frames.each((frame) => {
        counts[frame.rollId] = (counts[frame.rollId] ?? 0) + 1;
      });
      return counts;
    }, []) ?? {}
  );
}

/**
 * Lit une pièce jointe et rend une URL d'objet utilisable dans un `<img>`.
 * L'URL est révoquée dès que le blob change ou que le composant disparaît,
 * sans quoi chaque rendu fuirait une image entière en mémoire.
 */
export function useAttachmentUrl(attachmentId: string | undefined): string | undefined {
  const blob = useLiveQuery(
    async () => (attachmentId ? (await db.attachments.get(attachmentId))?.blob : undefined),
    [attachmentId],
  );
  const [url, setUrl] = useState<string>();

  useEffect(() => {
    if (!blob) {
      setUrl(undefined);
      return undefined;
    }
    const objectUrl = URL.createObjectURL(blob);
    setUrl(objectUrl);
    return () => URL.revokeObjectURL(objectUrl);
  }, [blob]);

  return url;
}
