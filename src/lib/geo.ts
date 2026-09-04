import type { GeoLocation } from '../db/types';

/**
 * Accès à la géolocalisation.
 *
 * Sur iOS, l'autorisation est demandée au premier appel et vaut pour tout le
 * site. Le repli sur une position moins précise mais immédiate est volontaire :
 * en prise de vue, savoir qu'on était à cinquante mètres près suffit largement,
 * et attendre le GPS ferait rater la lumière.
 */

export interface GeoResult {
  location?: GeoLocation;
  error?: string;
}

const ERRORS: Record<number, string> = {
  1: 'Localisation refusée. Autorisez-la dans Réglages › Safari › Position.',
  2: 'Position indisponible pour le moment.',
  3: 'La localisation a mis trop de temps à répondre.',
};

export function isGeolocationAvailable(): boolean {
  return typeof navigator !== 'undefined' && 'geolocation' in navigator;
}

export function getCurrentLocation(timeoutMs = 8000): Promise<GeoResult> {
  if (!isGeolocationAvailable()) {
    return Promise.resolve({ error: 'Localisation non disponible sur cet appareil.' });
  }

  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude, accuracy, altitude } = position.coords;
        resolve({
          location: {
            lat: latitude,
            lon: longitude,
            accuracy: accuracy ?? undefined,
            altitude: altitude ?? undefined,
          },
        });
      },
      (error) => resolve({ error: ERRORS[error.code] ?? 'Localisation impossible.' }),
      {
        enableHighAccuracy: true,
        timeout: timeoutMs,
        // Une position vieille d'une minute reste bonne : on ne se déplace pas
        // de cent mètres entre deux déclenchements.
        maximumAge: 60_000,
      },
    );
  });
}

/** Coordonnées en degrés décimaux, précision suffisante au mètre près. */
export function formatCoordinates(location: GeoLocation): string {
  return `${location.lat.toFixed(5)}, ${location.lon.toFixed(5)}`;
}

/**
 * Lien vers Plans (Apple) : sur iPhone, `maps.apple.com` ouvre directement
 * l'application native.
 */
export function mapsUrl(location: GeoLocation): string {
  return `https://maps.apple.com/?ll=${location.lat},${location.lon}&q=${encodeURIComponent(
    location.label ?? 'Prise de vue',
  )}`;
}

/**
 * Conversion en degrés/minutes/secondes, la forme attendue par les balises
 * EXIF GPS.
 */
export function toDMS(decimal: number): { degrees: number; minutes: number; seconds: number } {
  const absolute = Math.abs(decimal);
  const degrees = Math.floor(absolute);
  const minutesFloat = (absolute - degrees) * 60;
  const minutes = Math.floor(minutesFloat);
  const seconds = Math.round((minutesFloat - minutes) * 60 * 100) / 100;
  return { degrees, minutes, seconds };
}
