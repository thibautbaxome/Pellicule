import { Link } from 'react-router-dom';
import {
  useCamerasById,
  useFilmStocksById,
  useFrameCounts,
  useRolls,
} from '../hooks/useData';
import { EmptyState, ScreenHeader, Section } from '../components/ui';
import { IconChart, IconFilm, IconPlus } from '../components/icons';
import {
  ROLL_STATUS_LABELS,
  isRollOpen,
  type FilmType,
  type Roll,
  type RollStatus,
} from '../db/types';
import { pushPullLabel } from '../lib/exposure';
import { formatRelative, plural } from '../lib/format';

/** Regroupement des rouleaux en trois piles, dans l'ordre où l'on s'en occupe. */
const GROUPS: { title: string; statuses: RollStatus[] }[] = [
  { title: 'Dans le boîtier', statuses: ['loaded', 'shooting'] },
  { title: 'En traitement', statuses: ['finished', 'at_lab', 'developed'] },
  { title: 'Terminés', statuses: ['scanned', 'archived'] },
];

/**
 * Liseré de la carte, par type d'émulsion : argenté pour le noir et blanc,
 * ambre pour le négatif couleur, vert d'eau pour la diapositive. On reconnaît
 * la nature d'un rouleau avant même d'avoir lu son nom.
 */
const FILM_HUE: Record<FilmType, string> = {
  bw: 'var(--text-dim)',
  color_neg: 'var(--accent)',
  slide: 'var(--ok)',
};

const STATUS_BADGE: Partial<Record<RollStatus, string>> = {
  shooting: 'badge--accent',
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
        eyebrow="Carnet argentique · 135"
        title="Pellicule"
        subtitle={
          rolls.length > 0
            ? `${plural(rolls.length, 'rouleau', 'rouleaux')} · ${plural(shotTotal, 'vue')}`
            : undefined
        }
        action={
          rolls.length > 0 ? (
            <Link className="btn btn--sm btn--ghost" to="/stats" aria-label="Statistiques">
              <IconChart size={18} />
            </Link>
          ) : undefined
        }
      />

      {rolls.length === 0 ? (
        <EmptyState icon={<IconFilm size={34} />} title="Aucun rouleau chargé">
          <p style={{ maxWidth: 330, margin: '0 auto 22px', fontSize: '0.88rem' }}>
            Déclarez le boîtier et la pellicule que vous venez de charger. Chaque
            déclenchement s’enregistrera ensuite en deux gestes.
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
                {groupRolls.map((roll) => {
                  const film = films[roll.filmStockId];
                  return (
                    <RollCard
                      key={roll.id}
                      roll={roll}
                      filmLabel={film ? `${film.brand} ${film.name}` : 'Pellicule inconnue'}
                      filmType={film?.type ?? 'bw'}
                      boxIso={film?.iso ?? roll.shotIso}
                      cameraLabel={cameras[roll.cameraId]?.name ?? 'Boîtier inconnu'}
                      shotCount={counts[roll.id] ?? 0}
                    />
                  );
                })}
              </div>
            </Section>
          );
        })
      )}

      {rolls.length > 0 && (
        <Link className="btn btn--primary fab" to="/rolls/new">
          <IconPlus size={18} />
          Rouleau
        </Link>
      )}
    </main>
  );
}

function RollCard({
  roll,
  filmLabel,
  filmType,
  boxIso,
  cameraLabel,
  shotCount,
}: {
  roll: Roll;
  filmLabel: string;
  filmType: FilmType;
  boxIso: number;
  cameraLabel: string;
  shotCount: number;
}) {
  const push = pushPullLabel(roll.shotIso, boxIso);
  const open = isRollOpen(roll.status);
  const progress = Math.min(100, (shotCount / Math.max(1, roll.exposures)) * 100);

  return (
    <Link
      className="roll"
      to={`/rolls/${roll.id}`}
      style={{ ['--roll-hue' as string]: FILM_HUE[filmType] }}
    >
      <div className="roll-body">
        <div className="roll-head">
          <div style={{ minWidth: 0 }}>
            <p className="roll-name">{roll.label || filmLabel}</p>
            <p className="roll-film">
              {roll.label ? `${filmLabel} · ` : ''}
              {cameraLabel}
            </p>
          </div>
          <div className="roll-counter">
            <b>{String(shotCount).padStart(2, '0')}</b>
            <span>/{roll.exposures}</span>
          </div>
        </div>

        {open && (
          <div className="gauge" aria-hidden="true">
            <div className="gauge-fill" style={{ width: `${progress}%` }} />
          </div>
        )}

        <div className="roll-foot">
          <span>
            ISO {roll.shotIso}
            {push ? ` · ${push}` : ''} · {formatRelative(roll.loadedAt)}
          </span>
          <span className={`badge ${STATUS_BADGE[roll.status] ?? ''}`}>
            {ROLL_STATUS_LABELS[roll.status]}
          </span>
        </div>
      </div>
    </Link>
  );
}
