import { Link } from 'react-router-dom';
import {
  useCamerasById,
  useFilmStocksById,
  useFrameCounts,
  useRolls,
} from '../hooks/useData';
import { EmptyState, ScreenHeader, Section } from '../components/ui';
import { ROLL_STATUS_LABELS, isRollOpen, type Roll, type RollStatus } from '../db/types';
import { pushPullLabel } from '../lib/exposure';
import { formatRelative, plural } from '../lib/format';

/** Regroupement des rouleaux en trois piles, dans l'ordre où l'on s'en occupe. */
const GROUPS: { title: string; statuses: RollStatus[] }[] = [
  { title: 'Dans le boîtier', statuses: ['loaded', 'shooting'] },
  { title: 'En traitement', statuses: ['finished', 'at_lab', 'developed'] },
  { title: 'Terminés', statuses: ['scanned', 'archived'] },
];

const STATUS_BADGE: Partial<Record<RollStatus, string>> = {
  loaded: 'badge--info',
  shooting: 'badge--accent',
  finished: 'badge--info',
  at_lab: 'badge--info',
  developed: 'badge--success',
  scanned: 'badge--success',
};

export default function RollsScreen() {
  const rolls = useRolls();
  const films = useFilmStocksById();
  const cameras = useCamerasById();
  const counts = useFrameCounts();

  const shotTotal = Object.values(counts).reduce((sum, count) => sum + count, 0);

  return (
    <main className="screen">
      <ScreenHeader
        title="Pellicule"
        subtitle={
          rolls.length > 0
            ? `${plural(rolls.length, 'rouleau', 'rouleaux')} · ${plural(shotTotal, 'vue')}`
            : 'Carnet de prise de vue argentique'
        }
        action={
          <Link className="btn btn--sm btn--ghost" to="/stats">
            Stats
          </Link>
        }
      />

      {rolls.length === 0 ? (
        <EmptyState icon="🎞" title="Aucun rouleau pour l’instant">
          <p className="dim" style={{ maxWidth: 320, margin: '0 auto 18px' }}>
            Commencez par déclarer le boîtier et la pellicule que vous venez de charger.
            Chaque déclenchement s’enregistrera ensuite en deux gestes.
          </p>
          <Link className="btn btn--primary" to="/rolls/new">
            Charger un rouleau
          </Link>
        </EmptyState>
      ) : (
        GROUPS.map((group) => {
          const groupRolls = rolls.filter((roll) => group.statuses.includes(roll.status));
          if (groupRolls.length === 0) return null;

          return (
            <Section key={group.title} title={group.title}>
              <div className="list">
                {groupRolls.map((roll) => (
                  <RollCard
                    key={roll.id}
                    roll={roll}
                    filmLabel={
                      films[roll.filmStockId]
                        ? `${films[roll.filmStockId].brand} ${films[roll.filmStockId].name}`
                        : 'Pellicule inconnue'
                    }
                    boxIso={films[roll.filmStockId]?.iso ?? roll.shotIso}
                    cameraLabel={cameras[roll.cameraId]?.name ?? 'Boîtier inconnu'}
                    shotCount={counts[roll.id] ?? 0}
                  />
                ))}
              </div>
            </Section>
          );
        })
      )}

      <Link className="btn btn--primary fab" to="/rolls/new">
        + Rouleau
      </Link>
    </main>
  );
}

function RollCard({
  roll,
  filmLabel,
  boxIso,
  cameraLabel,
  shotCount,
}: {
  roll: Roll;
  filmLabel: string;
  boxIso: number;
  cameraLabel: string;
  shotCount: number;
}) {
  const push = pushPullLabel(roll.shotIso, boxIso);
  const open = isRollOpen(roll.status);
  const progress = Math.min(100, (shotCount / Math.max(1, roll.exposures)) * 100);

  return (
    <Link className="card" to={`/rolls/${roll.id}`}>
      <div className="card-row">
        <div style={{ minWidth: 0 }}>
          <p className="card-title">{roll.label || filmLabel}</p>
          <p className="card-meta">
            {roll.label ? `${filmLabel} · ` : ''}
            {cameraLabel}
          </p>
        </div>
        <span className={`badge ${STATUS_BADGE[roll.status] ?? ''}`}>
          {ROLL_STATUS_LABELS[roll.status]}
        </span>
      </div>

      {open && (
        <div className="gauge" aria-hidden="true">
          <div className="gauge-fill" style={{ width: `${progress}%` }} />
        </div>
      )}

      <div className="card-row" style={{ marginTop: open ? 2 : 9 }}>
        <span className="card-meta mono">
          {shotCount}/{roll.exposures} vues · {roll.shotIso} ISO
          {push ? ` · ${push}` : ''}
        </span>
        <span className="card-meta">{formatRelative(roll.loadedAt)}</span>
      </div>
    </Link>
  );
}
