/**
 * Export des métadonnées vers les scans.
 *
 * Un scan de laboratoire arrive nu : aucune date de prise de vue, aucun
 * boîtier, aucun réglage. Ce module reconstitue ces informations à partir du
 * carnet et les met sous une forme qu'exiftool sait appliquer en une commande,
 * de sorte que les fichiers finaux se comportent comme des photos numériques
 * dans n'importe quelle photothèque.
 */

import type { Camera, FilmStock, Frame, Lens, Roll } from '../db/types';
import { shutterToSeconds } from './exposure';

export interface ExportContext {
  roll: Roll;
  frames: Frame[];
  film?: FilmStock;
  camera?: Camera;
  lenses: Record<string, Lens>;
}

/**
 * Motif de nom de fichier. Les jetons reconnus :
 *   {n}    numéro de vue brut          → 7
 *   {nn}   numéro sur deux chiffres    → 07
 *   {nnn}  numéro sur trois chiffres   → 007
 *   {roll} référence d'archive du rouleau, à défaut son libellé
 */
export const DEFAULT_FILENAME_PATTERN = '{roll}-{nn}.jpg';

export function resolveFilename(pattern: string, roll: Roll, frame: Frame): string {
  const rollToken = slugify(roll.archiveRef || roll.label || 'rouleau');
  return pattern
    .replace(/\{roll\}/g, rollToken)
    .replace(/\{nnn\}/g, String(frame.number).padStart(3, '0'))
    .replace(/\{nn\}/g, String(frame.number).padStart(2, '0'))
    .replace(/\{n\}/g, String(frame.number));
}

function slugify(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40) || 'rouleau';
}

/** Date au format attendu par EXIF : « 2026:04:18 17:32:04 ». */
function exifDate(iso: string): string {
  const date = new Date(iso);
  const pad = (value: number) => String(value).padStart(2, '0');
  return (
    `${date.getFullYear()}:${pad(date.getMonth() + 1)}:${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

/**
 * Commentaire lisible reprenant ce qu'aucune balise standard ne sait porter :
 * l'émulsion, la sensibilité employée et le développement.
 */
function buildUserComment(context: ExportContext, frame: Frame): string {
  const { roll, film } = context;
  const parts: string[] = [];

  if (film) {
    parts.push(`Film: ${film.brand} ${film.name} (${film.iso} ISO)`);
    if (roll.shotIso !== film.iso) parts.push(`Exposée à ${roll.shotIso} ISO`);
  }
  if (roll.archiveRef) parts.push(`Rouleau: ${roll.archiveRef}`);
  parts.push(`Vue: ${frame.number}`);

  const development = roll.development;
  if (development?.self && development.developer) {
    const details = [development.developer, development.dilution].filter(Boolean).join(' ');
    const time = development.timeSec
      ? `${Math.floor(development.timeSec / 60)}:${String(development.timeSec % 60).padStart(2, '0')}`
      : null;
    parts.push(
      `Dév: ${details}${time ? ` ${time}` : ''}${development.tempC ? ` à ${development.tempC}°C` : ''}`,
    );
  } else if (roll.lab) {
    parts.push(`Labo: ${roll.lab}`);
  }

  if (frame.filter) parts.push(`Filtre: ${frame.filter.name}`);
  if (frame.meteringNote) parts.push(`Mesure: ${frame.meteringNote}`);
  if (frame.notes) parts.push(frame.notes);

  return parts.join(' · ');
}

/** Une ligne de métadonnées, prête pour le CSV ou le script. */
export type MetadataRow = Record<string, string>;

/**
 * Colonnes produites, dans l'ordre. `SourceFile` doit rester en tête :
 * c'est la clé qu'exiftool utilise pour retrouver le fichier à modifier.
 */
export const EXPORT_COLUMNS = [
  'SourceFile',
  'Make',
  'Model',
  'LensModel',
  'FocalLength',
  'FNumber',
  'ExposureTime',
  'ISO',
  'DateTimeOriginal',
  'CreateDate',
  'ExposureCompensation',
  'Flash',
  'SubjectDistance',
  'ImageDescription',
  'Description',
  'Keywords',
  'UserComment',
  'GPSLatitude',
  'GPSLatitudeRef',
  'GPSLongitude',
  'GPSLongitudeRef',
  'GPSAltitude',
];

export function buildMetadataRow(
  context: ExportContext,
  frame: Frame,
  pattern: string,
): MetadataRow {
  const { roll, film, camera, lenses } = context;
  const lens = frame.lensId ? lenses[frame.lensId] : undefined;
  const focal = frame.focal ?? (lens && lens.focalMin === lens.focalMax ? lens.focalMin : undefined);
  const seconds = shutterToSeconds(frame.shutter);

  const keywords = [
    ...frame.tags,
    film ? `${film.brand} ${film.name}` : null,
    camera?.name,
    film?.type === 'bw' ? 'noir et blanc' : null,
    'argentique',
  ].filter((value): value is string => Boolean(value));

  const row: MetadataRow = {
    SourceFile: resolveFilename(pattern, roll, frame),
    // Le nom du boîtier tient lieu de modèle quand la marque n'est pas
    // renseignée séparément : c'est ce qui s'affiche dans les photothèques.
    Make: camera?.make ?? camera?.name?.split(' ')[0] ?? '',
    Model: camera?.model ?? camera?.name ?? '',
    LensModel: lens?.name ?? '',
    FocalLength: focal ? `${focal}` : '',
    FNumber: frame.aperture ? String(frame.aperture) : '',
    // exiftool accepte aussi bien « 1/125 » que la valeur décimale.
    ExposureTime: frame.shutter && seconds ? frame.shutter : '',
    ISO: String(roll.shotIso),
    DateTimeOriginal: exifDate(frame.shotAt),
    CreateDate: exifDate(frame.shotAt),
    ExposureCompensation: frame.exposureComp != null ? String(frame.exposureComp) : '',
    Flash: frame.flash ? 'Fired' : 'No Flash',
    SubjectDistance: frame.focusDistance ? `${frame.focusDistance}` : '',
    ImageDescription: frame.subject ?? '',
    Description: frame.subject ?? '',
    Keywords: keywords.join(', '),
    UserComment: buildUserComment(context, frame),
    GPSLatitude: frame.location ? String(Math.abs(frame.location.lat)) : '',
    GPSLatitudeRef: frame.location ? (frame.location.lat >= 0 ? 'N' : 'S') : '',
    GPSLongitude: frame.location ? String(Math.abs(frame.location.lon)) : '',
    GPSLongitudeRef: frame.location ? (frame.location.lon >= 0 ? 'E' : 'W') : '',
    GPSAltitude: frame.location?.altitude != null ? String(Math.round(frame.location.altitude)) : '',
  };

  return row;
}

// ---------------------------------------------------------------------------
// Rendus
// ---------------------------------------------------------------------------

const escapeCsv = (value: string): string =>
  /[",\n\r]/.test(value) ? `"${value.replace(/"/g, '""')}"` : value;

export function toCsv(rows: MetadataRow[], columns = EXPORT_COLUMNS): string {
  const header = columns.join(',');
  const lines = rows.map((row) => columns.map((column) => escapeCsv(row[column] ?? '')).join(','));
  return [header, ...lines].join('\n');
}

/** Échappement pour une chaîne entre apostrophes simples en shell POSIX. */
const escapeShell = (value: string): string => `'${value.replace(/'/g, `'\\''`)}'`;

/**
 * Script shell appliquant les métadonnées vue par vue. Plus verbeux que le
 * CSV, mais lisible et modifiable : on peut y corriger un nom de fichier à la
 * main avant de le lancer.
 */
export function toExiftoolScript(rows: MetadataRow[], rollTitle: string): string {
  const header = [
    '#!/bin/sh',
    '#',
    `# Métadonnées argentiques — ${rollTitle}`,
    `# Généré par Pellicule le ${new Date().toLocaleString('fr-FR')}`,
    '#',
    '# Placez ce script dans le dossier contenant vos scans, vérifiez que les noms',
    '# de fichiers correspondent, puis lancez-le :',
    '#',
    '#     sh metadonnees.sh',
    '#',
    '# exiftool conserve une copie de chaque original sous le suffixe _original.',
    '# Une fois le résultat vérifié, ces copies peuvent être supprimées.',
    '',
    'set -e',
    '',
    'if ! command -v exiftool > /dev/null 2>&1; then',
    '  echo "exiftool est introuvable. Installez-le : brew install exiftool" >&2',
    '  exit 1',
    'fi',
    '',
  ].join('\n');

  const commands = rows.map((row) => {
    const file = row.SourceFile;
    const args = EXPORT_COLUMNS.filter((column) => column !== 'SourceFile')
      .filter((column) => row[column])
      .map((column) => `  -${column}=${escapeShell(row[column])}`);

    return [
      `if [ -f ${escapeShell(file)} ]; then`,
      `  exiftool -overwrite_original_in_place \\`,
      `${args.join(' \\\n')} \\`,
      `    ${escapeShell(file)}`,
      'else',
      `  echo "Fichier absent, ignoré : ${file}" >&2`,
      'fi',
    ].join('\n');
  });

  return `${header}\n${commands.join('\n\n')}\n\necho "Terminé."\n`;
}

/**
 * Export tabulaire lisible dans un tableur, pour relire un rouleau ou le
 * comparer à ses planches contact. Distinct du CSV exiftool, dont les
 * en-têtes sont contraints.
 */
export function toReadableCsv(context: ExportContext): string {
  const { roll, frames, film, camera, lenses } = context;
  const columns = [
    'Vue',
    'Date',
    'Heure',
    'Vitesse',
    'Ouverture',
    'Objectif',
    'Focale',
    'Correction',
    'Filtre',
    'Flash',
    'Distance',
    'Lumière',
    'Sujet',
    'Mots-clés',
    'Notes',
    'Latitude',
    'Longitude',
    'Statut',
    'Note',
  ];

  const lines = frames.map((frame) => {
    const date = new Date(frame.shotAt);
    const lens = frame.lensId ? lenses[frame.lensId] : undefined;
    return [
      String(frame.number),
      date.toLocaleDateString('fr-FR'),
      date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }),
      frame.shutter ?? '',
      frame.aperture ? `f/${frame.aperture}` : '',
      lens?.name ?? '',
      frame.focal ? `${frame.focal} mm` : '',
      frame.exposureComp ? `${frame.exposureComp > 0 ? '+' : ''}${frame.exposureComp}` : '',
      frame.filter?.name ?? '',
      frame.flash ? 'oui' : '',
      frame.focusDistance ? `${frame.focusDistance} m` : '',
      frame.lightNote ?? '',
      frame.subject ?? '',
      frame.tags.join(' '),
      frame.notes ?? '',
      frame.location ? frame.location.lat.toFixed(6) : '',
      frame.location ? frame.location.lon.toFixed(6) : '',
      frame.status,
      frame.rating ? String(frame.rating) : '',
    ]
      .map(escapeCsv)
      .join(',');
  });

  const preamble = [
    `# ${roll.label || (film ? `${film.brand} ${film.name}` : 'Rouleau')}`,
    `# ${film ? `${film.brand} ${film.name} — ${film.iso} ISO` : ''} exposée à ${roll.shotIso} ISO`,
    `# Boîtier : ${camera?.name ?? '—'}`,
    `# Chargée le ${new Date(roll.loadedAt).toLocaleDateString('fr-FR')}`,
    '',
  ].join('\n');

  return `${preamble}${columns.join(',')}\n${lines.join('\n')}\n`;
}
