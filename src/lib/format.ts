/** Formatage des dates, montants et libellés, en français. */

const dateFormatter = new Intl.DateTimeFormat('fr-FR', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
});

const dateTimeFormatter = new Intl.DateTimeFormat('fr-FR', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
});

const timeFormatter = new Intl.DateTimeFormat('fr-FR', {
  hour: '2-digit',
  minute: '2-digit',
});

export const formatDate = (iso?: string): string =>
  iso ? dateFormatter.format(new Date(iso)) : '—';

export const formatDateTime = (iso?: string): string =>
  iso ? dateTimeFormatter.format(new Date(iso)) : '—';

export const formatTime = (iso?: string): string =>
  iso ? timeFormatter.format(new Date(iso)) : '—';

export function formatMoney(amount: number | undefined, currency = 'EUR'): string {
  if (amount == null || !Number.isFinite(amount)) return '—';
  return new Intl.NumberFormat('fr-FR', {
    style: 'currency',
    currency,
    maximumFractionDigits: 2,
  }).format(amount);
}

/** Écart relatif à maintenant : « aujourd'hui », « il y a 3 jours ». */
export function formatRelative(iso?: string): string {
  if (!iso) return '—';
  const days = Math.floor((Date.now() - new Date(iso).getTime()) / 86_400_000);
  if (days <= 0) return "aujourd'hui";
  if (days === 1) return 'hier';
  if (days < 31) return `il y a ${days} jours`;
  const months = Math.floor(days / 30);
  if (months < 12) return `il y a ${months} mois`;
  const years = Math.floor(days / 365);
  return years === 1 ? 'il y a un an' : `il y a ${years} ans`;
}

/**
 * Convertit une date ISO en valeur pour un `<input type="datetime-local">`,
 * qui attend l'heure locale sans fuseau.
 */
export function toLocalInputValue(iso: string): string {
  const date = new Date(iso);
  const offsetMs = date.getTimezoneOffset() * 60_000;
  return new Date(date.getTime() - offsetMs).toISOString().slice(0, 16);
}

/** Opération inverse de `toLocalInputValue`. */
export function fromLocalInputValue(value: string): string {
  return value ? new Date(value).toISOString() : new Date().toISOString();
}

/** Accorde un nom au pluriel : `plural(3, 'vue')` donne « 3 vues ». */
export const plural = (count: number, singular: string, plural = `${singular}s`): string =>
  `${count} ${count > 1 ? plural : singular}`;
