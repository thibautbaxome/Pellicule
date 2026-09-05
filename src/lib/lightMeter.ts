/**
 * Mesure de lumière par la caméra du téléphone.
 *
 * Une mise au point honnête s'impose. Un navigateur ne donne pas accès à la
 * luminance absolue d'une scène : la caméra corrige son exposition en
 * permanence, si bien que la luminosité moyenne d'une image reste à peu près
 * constante quelle que soit la lumière réelle. Mesurer la clarté des pixels ne
 * mesure donc rien du tout.
 *
 * La seule voie exacte consiste à lire les réglages que la caméra a elle-même
 * choisis — temps de pose et sensibilité — et à remonter à l'indice de
 * lumination. C'est ce que fait ce module. Ces valeurs sont exposées par
 * Chrome sur Android, mais WebKit ne les publie pas : sur iPhone, la mesure
 * est donc indisponible, et l'application le dit plutôt que d'afficher un
 * chiffre inventé.
 *
 * L'estimation par la scène reste, elle, parfaitement fiable — c'est ainsi
 * qu'on a exposé pendant un siècle.
 */

/** Ouverture supposée de l'objectif du téléphone, faute d'être publiée. */
const ASSUMED_PHONE_APERTURE = 1.8;

export type MeterAvailability = 'ready' | 'unsupported' | 'denied' | 'no-exposure-data';

export interface MeterReading {
  /** Indice de lumination ramené à 100 ISO. */
  ev100: number;
  /** Temps de pose retenu par la caméra, en secondes. */
  exposureTime: number;
  /** Sensibilité retenue par la caméra. */
  iso: number;
}

export interface MeterSession {
  /** Prend une mesure sur l'état courant de la caméra. */
  read: () => MeterReading | null;
  stop: () => void;
  /** Flux à raccorder à un élément vidéo pour viser. */
  stream: MediaStream;
}

export function isMeterPossible(): boolean {
  return typeof navigator !== 'undefined' && Boolean(navigator.mediaDevices?.getUserMedia);
}

/**
 * Ouvre la caméra arrière et vérifie que les réglages d'exposition sont
 * lisibles. Rend un code d'échec explicite plutôt qu'une exception, pour que
 * l'interface puisse expliquer ce qui manque.
 */
export async function startMeter(): Promise<
  { status: 'ready'; session: MeterSession } | { status: Exclude<MeterAvailability, 'ready'> }
> {
  if (!isMeterPossible()) return { status: 'unsupported' };

  let stream: MediaStream;
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: 'environment' } },
      audio: false,
    });
  } catch (error) {
    const denied = error instanceof DOMException && error.name === 'NotAllowedError';
    return { status: denied ? 'denied' : 'unsupported' };
  }

  const [track] = stream.getVideoTracks();
  if (!track) {
    stream.getTracks().forEach((item) => item.stop());
    return { status: 'unsupported' };
  }

  // La caméra a besoin de quelques images pour stabiliser son exposition avant
  // que ses réglages veuillent dire quelque chose.
  await new Promise((resolve) => setTimeout(resolve, 700));

  const settings = track.getSettings() as MediaTrackSettings & {
    exposureTime?: number;
    iso?: number;
  };

  if (settings.exposureTime == null || settings.iso == null) {
    stream.getTracks().forEach((item) => item.stop());
    return { status: 'no-exposure-data' };
  }

  return {
    status: 'ready',
    session: {
      stream,
      read: () => {
        const current = track.getSettings() as MediaTrackSettings & {
          exposureTime?: number;
          iso?: number;
        };
        if (current.exposureTime == null || current.iso == null) return null;

        // La spécification exprime le temps de pose en centaines de
        // microsecondes ; on revient aux secondes.
        const exposureTime = current.exposureTime / 10_000;
        return {
          exposureTime,
          iso: current.iso,
          ev100: evFromExposure(exposureTime, current.iso, ASSUMED_PHONE_APERTURE),
        };
      },
      stop: () => stream.getTracks().forEach((item) => item.stop()),
    },
  };
}

/**
 * Indice de lumination à 100 ISO déduit d'un triplet d'exposition.
 * EV = log2(N² / t) corrigé de l'écart de sensibilité.
 */
export function evFromExposure(seconds: number, iso: number, aperture: number): number {
  if (seconds <= 0 || iso <= 0) return 0;
  return Math.log2((aperture * aperture) / seconds) - Math.log2(iso / 100);
}

export const METER_STATUS_MESSAGES: Record<Exclude<MeterAvailability, 'ready'>, string> = {
  unsupported: 'Cet appareil ne donne pas accès à sa caméra depuis le navigateur.',
  denied:
    'Accès à la caméra refusé. Autorisez-le dans Réglages › Safari › Appareil photo, puis réessayez.',
  'no-exposure-data':
    'Safari ne communique pas les réglages d’exposition de la caméra : la mesure ' +
    'automatique est impossible sur iPhone. Estimez la lumière par la scène — c’est ' +
    'la méthode qu’on utilise depuis toujours, et elle est fiable.',
};
