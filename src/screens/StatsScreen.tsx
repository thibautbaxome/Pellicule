import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../db/db';
import { useCamerasById, useFilmStocksById, useLensesById, useRolls } from '../hooks/useData';
import { useSettings } from '../hooks/useSettings';
import { EmptyState, KeyValue, ScreenHeader, Section } from '../components/ui';
import { IconChart } from '../components/icons';
import { formatAperture } from '../lib/exposure';
import { formatMoney, plural } from '../lib/format';

/** Barre de répartition, avec la valeur en clair à droite. */
function Distribution({
  entries,
  total,
  unit,
}: {
  entries: [string, number][];
  total: number;
  unit?: string;
}) {
  if (entries.length === 0) return <p className="dim">Pas encore de données.</p>;

  return (
    <div className="card">
      {entries.map(([label, count]) => (
        <div key={label} style={{ marginBottom: 11 }}>
          <div className="card-row" style={{ marginBottom: 4 }}>
            <span style={{ fontSize: '0.9rem' }}>{label}</span>
            <span className="mono dim" style={{ fontSize: '0.84rem' }}>
              {count}
              {unit ? ` ${unit}` : ''} · {Math.round((count / total) * 100)} %
            </span>
          </div>
          <div className="gauge" style={{ margin: 0 }}>
            <div className="gauge-fill" style={{ width: `${(count / total) * 100}%` }} />
          </div>
        </div>
      ))}
    </div>
  );
}

/** Compte les occurrences et rend les `limit` premières, par ordre décroissant. */
function topEntries(counts: Record<string, number>, limit = 6): [string, number][] {
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit);
}

export default function StatsScreen() {
  const rolls = useRolls();
  const films = useFilmStocksById();
  const cameras = useCamerasById();
  const lenses = useLensesById();
  const settings = useSettings();
  const frames = useLiveQuery(() => db.frames.toArray(), []) ?? [];

  if (rolls.length === 0) {
    return (
      <main className="screen">
        <ScreenHeader title="Statistiques" back={{ to: '/', label: 'Rouleaux' }} />
        <EmptyState icon={<IconChart size={30} />} title="Rien à compter pour l’instant">
          <p className="dim">Les statistiques apparaîtront dès votre premier rouleau.</p>
        </EmptyState>
      </main>
    );
  }

  const rollById = new Map(rolls.map((roll) => [roll.id, roll]));

  const totalCost = rolls.reduce(
    (sum, roll) => sum + Object.values(roll.costs ?? {}).reduce<number>((s, v) => s + (v ?? 0), 0),
    0,
  );

  const filmCounts: Record<string, number> = {};
  const cameraCounts: Record<string, number> = {};
  const lensCounts: Record<string, number> = {};
  const focalCounts: Record<string, number> = {};
  const apertureCounts: Record<string, number> = {};
  const shutterCounts: Record<string, number> = {};

  for (const roll of rolls) {
    const film = films[roll.filmStockId];
    const key = film ? `${film.brand} ${film.name}` : 'Pellicule inconnue';
    filmCounts[key] = (filmCounts[key] ?? 0) + 1;
  }

  for (const frame of frames) {
    const roll = rollById.get(frame.rollId);
    if (roll) {
      const cameraName = cameras[roll.cameraId]?.name ?? 'Boîtier inconnu';
      cameraCounts[cameraName] = (cameraCounts[cameraName] ?? 0) + 1;
    }

    if (frame.lensId) {
      const lens = lenses[frame.lensId];
      const lensName = lens?.name ?? 'Objectif inconnu';
      lensCounts[lensName] = (lensCounts[lensName] ?? 0) + 1;

      // La focale d'un zoom n'est connue que si elle a été saisie ; celle
      // d'une focale fixe se déduit de l'objectif.
      const focal = frame.focal ?? (lens && lens.focalMin === lens.focalMax ? lens.focalMin : undefined);
      if (focal) focalCounts[`${focal} mm`] = (focalCounts[`${focal} mm`] ?? 0) + 1;
    }

    if (frame.aperture) {
      const key = formatAperture(frame.aperture);
      apertureCounts[key] = (apertureCounts[key] ?? 0) + 1;
    }
    if (frame.shutter) {
      shutterCounts[frame.shutter] = (shutterCounts[frame.shutter] ?? 0) + 1;
    }
  }

  const developed = rolls.filter((roll) =>
    ['developed', 'scanned', 'archived'].includes(roll.status),
  ).length;
  const keepers = frames.filter((frame) => frame.status === 'keep' || frame.status === 'printed').length;
  const rated = frames.filter((frame) => (frame.rating ?? 0) > 0);
  const averageRating =
    rated.length > 0 ? rated.reduce((sum, frame) => sum + (frame.rating ?? 0), 0) / rated.length : 0;

  return (
    <main className="screen">
      <ScreenHeader
        eyebrow="Bilan"
        title="Statistiques"
        subtitle={`${plural(rolls.length, 'rouleau', 'rouleaux')} · ${plural(frames.length, 'vue')}`}
        back={{ to: '/', label: 'Rouleaux' }}
      />

      <Section title="Vue d’ensemble">
        <div className="card">
          <KeyValue label="Rouleaux chargés">{rolls.length}</KeyValue>
          <KeyValue label="Rouleaux développés">{developed}</KeyValue>
          <KeyValue label="Vues enregistrées">{frames.length}</KeyValue>
          {frames.length > 0 && (
            <KeyValue label="Vues par rouleau">
              {(frames.length / rolls.length).toLocaleString('fr-FR', {
                maximumFractionDigits: 1,
              })}
            </KeyValue>
          )}
          {keepers > 0 && (
            <KeyValue label="Vues retenues">
              {keepers} ({Math.round((keepers / frames.length) * 100)} %)
            </KeyValue>
          )}
          {averageRating > 0 && (
            <KeyValue label="Note moyenne">
              {averageRating.toLocaleString('fr-FR', { maximumFractionDigits: 1 })} / 5
            </KeyValue>
          )}
        </div>
      </Section>

      {totalCost > 0 && (
        <Section title="Coûts">
          <div className="card">
            <KeyValue label="Total engagé">{formatMoney(totalCost, settings.currency)}</KeyValue>
            <KeyValue label="Par rouleau">
              {formatMoney(totalCost / rolls.length, settings.currency)}
            </KeyValue>
            {frames.length > 0 && (
              <KeyValue label="Par vue">
                {formatMoney(totalCost / frames.length, settings.currency)}
              </KeyValue>
            )}
            {keepers > 0 && (
              <KeyValue label="Par vue retenue">
                {formatMoney(totalCost / keepers, settings.currency)}
              </KeyValue>
            )}
          </div>
        </Section>
      )}

      <Section title="Pellicules">
        <Distribution entries={topEntries(filmCounts)} total={rolls.length} unit="rlx" />
      </Section>

      {Object.keys(cameraCounts).length > 1 && (
        <Section title="Boîtiers">
          <Distribution entries={topEntries(cameraCounts)} total={frames.length} />
        </Section>
      )}

      {Object.keys(focalCounts).length > 0 && (
        <Section title="Focales">
          <Distribution
            entries={topEntries(focalCounts)}
            total={Object.values(focalCounts).reduce((sum, count) => sum + count, 0)}
          />
        </Section>
      )}

      {Object.keys(lensCounts).length > 1 && (
        <Section title="Objectifs">
          <Distribution
            entries={topEntries(lensCounts)}
            total={Object.values(lensCounts).reduce((sum, count) => sum + count, 0)}
          />
        </Section>
      )}

      {Object.keys(apertureCounts).length > 0 && (
        <Section title="Ouvertures">
          <Distribution
            entries={topEntries(apertureCounts, 8)}
            total={Object.values(apertureCounts).reduce((sum, count) => sum + count, 0)}
          />
        </Section>
      )}

      {Object.keys(shutterCounts).length > 0 && (
        <Section title="Vitesses">
          <Distribution
            entries={topEntries(shutterCounts, 8)}
            total={Object.values(shutterCounts).reduce((sum, count) => sum + count, 0)}
          />
        </Section>
      )}
    </main>
  );
}
