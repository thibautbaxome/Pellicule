/**
 * Traitement des photos de repérage.
 *
 * Ces clichés servent à se rappeler un cadrage ou une lumière, pas à être
 * tirés : on les réduit fortement avant de les stocker. Une photo d'iPhone
 * brute pèse 3 à 5 Mo, la version réduite une centaine de kilo-octets — ce
 * qui compte quand des centaines de vues s'accumulent dans IndexedDB.
 */

/** Côté le plus long, en pixels, après réduction. */
const MAX_DIMENSION = 1280;
const JPEG_QUALITY = 0.72;

export interface ProcessedImage {
  blob: Blob;
  width: number;
  height: number;
}

export async function shrinkImage(file: File): Promise<ProcessedImage> {
  const bitmap = await createImageBitmap(file);
  const scale = Math.min(1, MAX_DIMENSION / Math.max(bitmap.width, bitmap.height));
  const width = Math.round(bitmap.width * scale);
  const height = Math.round(bitmap.height * scale);

  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('Contexte de dessin indisponible');
  context.drawImage(bitmap, 0, 0, width, height);
  bitmap.close();

  const blob = await new Promise<Blob | null>((resolve) =>
    canvas.toBlob(resolve, 'image/jpeg', JPEG_QUALITY),
  );
  if (!blob) throw new Error('Compression de l’image impossible');

  return { blob, width, height };
}

/** Taille lisible d'un nombre d'octets : « 1,4 Mo ». */
export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} o`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} ko`;
  return `${(bytes / (1024 * 1024)).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} Mo`;
}

/**
 * Espace occupé et disponible, tels que le navigateur veut bien les estimer.
 * Safari renvoie des valeurs approximatives, suffisantes pour prévenir avant
 * la saturation.
 */
export async function storageEstimate(): Promise<{ usage: number; quota: number } | null> {
  if (!navigator.storage?.estimate) return null;
  const { usage = 0, quota = 0 } = await navigator.storage.estimate();
  return { usage, quota };
}

/**
 * Demande au navigateur de rendre le stockage persistant, pour qu'iOS ne
 * purge pas la base au bout de quelques semaines sans ouvrir l'application.
 * Accordé sans invite lorsque l'application est installée sur l'écran
 * d'accueil.
 */
export async function requestPersistentStorage(): Promise<boolean> {
  if (!navigator.storage?.persist) return false;
  if (await navigator.storage.persisted()) return true;
  return navigator.storage.persist();
}
