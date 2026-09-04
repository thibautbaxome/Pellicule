/**
 * Sauvegarde et restauration complètes.
 *
 * L'application n'ayant aucun serveur, la sauvegarde est le seul filet : un
 * fichier JSON unique, à déposer dans iCloud Drive depuis la feuille de
 * partage d'iOS. Le format est délibérément lisible et versionné, pour rester
 * réimportable dans plusieurs années même si le modèle de données évolue.
 */

import { db, now } from '../db/db';
import type {
  Attachment,
  Camera,
  FilmStock,
  Frame,
  Lens,
  Roll,
  Settings,
} from '../db/types';

export const BACKUP_FORMAT_VERSION = 1;

export interface BackupFile {
  format: 'pellicule-backup';
  version: number;
  exportedAt: string;
  /** Photos de repérage encodées en base64, absentes des sauvegardes légères. */
  includesPhotos: boolean;
  data: {
    cameras: Camera[];
    lenses: Lens[];
    filmStocks: FilmStock[];
    rolls: Roll[];
    frames: Frame[];
    settings: Settings[];
    attachments: SerializedAttachment[];
  };
}

interface SerializedAttachment extends Omit<Attachment, 'blob'> {
  /** Contenu de l'image, encodé en base64 sans préfixe de type. */
  base64: string;
}

async function blobToBase64(blob: Blob): Promise<string> {
  const buffer = new Uint8Array(await blob.arrayBuffer());
  // Le découpage en tranches évite de dépasser la taille d'appel maximale de
  // String.fromCharCode sur une image de plusieurs centaines de kilo-octets.
  let binary = '';
  const chunkSize = 0x8000;
  for (let offset = 0; offset < buffer.length; offset += chunkSize) {
    binary += String.fromCharCode(...buffer.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}

function base64ToBlob(base64: string, mime: string): Blob {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return new Blob([bytes], { type: mime });
}

export async function createBackup(includePhotos: boolean): Promise<BackupFile> {
  const [cameras, lenses, filmStocks, rolls, frames, settings, attachments] = await Promise.all([
    db.cameras.toArray(),
    db.lenses.toArray(),
    db.filmStocks.toArray(),
    db.rolls.toArray(),
    db.frames.toArray(),
    db.settings.toArray(),
    includePhotos ? db.attachments.toArray() : Promise.resolve([]),
  ]);

  const serializedAttachments: SerializedAttachment[] = await Promise.all(
    attachments.map(async ({ blob, ...rest }) => ({
      ...rest,
      base64: await blobToBase64(blob),
    })),
  );

  return {
    format: 'pellicule-backup',
    version: BACKUP_FORMAT_VERSION,
    exportedAt: now(),
    includesPhotos: includePhotos,
    data: {
      cameras,
      lenses,
      filmStocks,
      rolls,
      frames,
      settings,
      attachments: serializedAttachments,
    },
  };
}

export interface RestoreReport {
  cameras: number;
  lenses: number;
  filmStocks: number;
  rolls: number;
  frames: number;
  attachments: number;
}

/**
 * Restaure une sauvegarde.
 *
 * En mode `replace`, la base est vidée au préalable. En mode `merge`, les
 * enregistrements existants portant le même identifiant sont écrasés par ceux
 * du fichier et les autres sont conservés — ce qui permet de récupérer un
 * rouleau perdu sans perdre le travail fait depuis.
 */
export async function restoreBackup(
  backup: BackupFile,
  mode: 'replace' | 'merge',
): Promise<RestoreReport> {
  if (backup.format !== 'pellicule-backup') {
    throw new Error('Ce fichier n’est pas une sauvegarde Pellicule.');
  }
  if (backup.version > BACKUP_FORMAT_VERSION) {
    throw new Error(
      'Cette sauvegarde provient d’une version plus récente de l’application. ' +
        'Mettez l’application à jour avant de la restaurer.',
    );
  }

  const { data } = backup;
  const attachments: Attachment[] = data.attachments.map(({ base64, ...rest }) => ({
    ...rest,
    blob: base64ToBlob(base64, rest.mime),
  }));

  await db.transaction(
    'rw',
    [db.cameras, db.lenses, db.filmStocks, db.rolls, db.frames, db.attachments, db.settings],
    async () => {
      if (mode === 'replace') {
        await Promise.all([
          db.cameras.clear(),
          db.lenses.clear(),
          db.filmStocks.clear(),
          db.rolls.clear(),
          db.frames.clear(),
          db.attachments.clear(),
        ]);
      }

      await db.cameras.bulkPut(data.cameras);
      await db.lenses.bulkPut(data.lenses);
      await db.filmStocks.bulkPut(data.filmStocks);
      await db.rolls.bulkPut(data.rolls);
      await db.frames.bulkPut(data.frames);
      if (attachments.length > 0) await db.attachments.bulkPut(attachments);
      // Les réglages ne sont repris qu'en restauration complète : après une
      // fusion, mieux vaut garder ceux de l'appareil courant.
      if (mode === 'replace' && data.settings.length > 0) {
        await db.settings.bulkPut(data.settings);
      }
    },
  );

  return {
    cameras: data.cameras.length,
    lenses: data.lenses.length,
    filmStocks: data.filmStocks.length,
    rolls: data.rolls.length,
    frames: data.frames.length,
    attachments: attachments.length,
  };
}

/**
 * Propose un fichier au partage ou au téléchargement.
 *
 * Sur iOS, la feuille de partage native est le seul chemin praticable vers
 * Fichiers et iCloud Drive ; le téléchargement classique n'existe qu'en repli
 * pour les navigateurs de bureau.
 */
export async function shareOrDownload(
  filename: string,
  content: string,
  mime: string,
): Promise<'shared' | 'downloaded'> {
  const file = new File([content], filename, { type: mime });

  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: filename });
      return 'shared';
    } catch (error) {
      // Un partage annulé par l'utilisateur ne doit pas déclencher le repli.
      if (error instanceof DOMException && error.name === 'AbortError') return 'shared';
    }
  }

  const url = URL.createObjectURL(new Blob([content], { type: mime }));
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  // Laisser au navigateur le temps d'amorcer le téléchargement.
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
  return 'downloaded';
}

/** Nom de fichier horodaté, trié chronologiquement dans un dossier. */
export function timestampedName(prefix: string, extension: string): string {
  const stamp = new Date().toISOString().slice(0, 16).replace(/[:T]/g, '-');
  return `${prefix}-${stamp}.${extension}`;
}
