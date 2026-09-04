import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { db, now } from '../db/db';
import {
  useAttachmentUrl,
  useCamerasById,
  useFilmStocksById,
  useFrames,
  useRoll,
} from '../hooks/useData';
import { useSettings } from '../hooks/useSettings';
import { EmptyState, Field, KeyValue, Note, ScreenHeader, Section } from '../components/ui';
import { IconExport, IconFilm, IconFlask, IconPin, IconPlus, IconTrash } from '../components/icons';
import {
  ROLL_STATUSES,
  ROLL_STATUS_LABELS,
  isRollOpen,
  type Frame,
  type RollStatus,
} from '../db/types';
import { formatAperture, pushPullLabel } from '../lib/exposure';
import { formatDate, formatMoney, plural } from '../lib/format';

export default function RollScreen() {
  const { rollId } = useParams();
  const navigate = useNavigate();
  const roll = useRoll(rollId);
  const frames = useFrames(rollId);
  const films = useFilmStocksById();
  const cameras = useCamerasById();
  const settings = useSettings();
  const [showDetails, setShowDetails] = useState(false);

  if (!roll) {
    return (
      <main className="screen">
        <ScreenHeader title="Rouleau introuvable" back={{ to: '/', label: 'Rouleaux' }} />
      </main>
    );
  }

  const film = films[roll.filmStockId];
  const camera = cameras[roll.cameraId];
  const filmLabel = film ? `${film.brand} ${film.name}` : 'Pellicule inconnue';
  const push = film ? pushPullLabel(roll.shotIso, film.iso) : null;
  const open = isRollOpen(roll.status);

  const byNumber = new Map(frames.map((frame) => [frame.number, frame]));
  const nextNumber = findNextFreeNumber(byNumber, roll.exposures);
  const totalCost = Object.values(roll.costs ?? {}).reduce<number>(
    (sum, value) => sum + (value ?? 0),
    0,
  );

  const statusIndex = ROLL_STATUSES.indexOf(roll.status);
  const nextStatus: RollStatus | undefined = ROLL_STATUSES[statusIndex + 1];

  async function advanceStatus(status: RollStatus) {
    if (!roll) return;
    await db.rolls.update(roll.id, {
      status,
      // Terminer le rouleau fige la date : c'est elle qui compte pour le labo.
      ...(status === 'finished' && !roll.finishedAt ? { finishedAt: now() } : {}),
      updatedAt: now(),
    });
  }

  async function deleteRoll() {
    if (!roll) return;
    const message =
      `Supprimer ce rouleau et ses ${plural(frames.length, 'vue')} ? ` +
      `Cette action est définitive.`;
    if (!window.confirm(message)) return;

    await db.transaction('rw', db.rolls, db.frames, db.attachments, async () => {
      const attachmentIds = frames
        .map((frame) => frame.refPhotoId)
        .filter((id): id is string => Boolean(id));
      if (attachmentIds.length > 0) await db.attachments.bulkDelete(attachmentIds);
      await db.frames.where('rollId').equals(roll.id).delete();
      await db.rolls.delete(roll.id);
    });
    navigate('/', { replace: true });
  }

  return (
    <main className="screen">
      <ScreenHeader
        title={roll.label || filmLabel}
        subtitle={
          <>
            {roll.label ? `${filmLabel} · ` : ''}
            {camera?.name ?? 'Boîtier inconnu'} · {roll.shotIso} ISO
            {push ? ` · ${push}` : ''}
          </>
        }
        back={{ to: '/', label: 'Rouleaux' }}
      />

      <div className="badge-row" style={{ marginBottom: 14 }}>
        <span className="badge badge--accent">{ROLL_STATUS_LABELS[roll.status]}</span>
        <span className="badge">
          {frames.length}/{roll.exposures} vues
        </span>
        {film && <span className="badge">{film.process}</span>}
        <span className="badge">Chargé le {formatDate(roll.loadedAt)}</span>
      </div>

      {open && nextNumber !== null && (
        <Link
          className="btn btn--primary btn--block"
          to={`/rolls/${roll.id}/frames/new`}
          style={{ marginBottom: 26 }}
        >
          <IconPlus size={18} />
          Vue n° {nextNumber}
        </Link>
      )}

      {open && nextNumber === null && (
        <Note>
          Les {roll.exposures} poses prévues sont enregistrées. Rembobinez le film, puis
          marquez le rouleau comme terminé.
        </Note>
      )}

      <Section title="Vues">
        {frames.length === 0 && !open ? (
          <EmptyState icon={<IconFilm size={30} />} title="Aucune vue enregistrée" />
        ) : (
          <div className="frame-grid">
            {Array.from({ length: roll.exposures }, (_, index) => index + 1).map((number) => {
              const frame = byNumber.get(number);
              return frame ? (
                <FrameCell key={number} rollId={roll.id} frame={frame} />
              ) : (
                <Link
                  key={number}
                  className="frame-cell frame-cell--empty"
                  to={`/rolls/${roll.id}/frames/new?number=${number}`}
                  aria-label={`Enregistrer la vue ${number}`}
                >
                  <span className="frame-number">{number}</span>
                </Link>
              );
            })}
            {/* Il arrive qu'un film donne une pose de plus que prévu. */}
            {frames
              .filter((frame) => frame.number > roll.exposures)
              .map((frame) => (
                <FrameCell key={frame.id} rollId={roll.id} frame={frame} />
              ))}
          </div>
        )}
      </Section>

      <Section title="Suivi">
        <div className="stack">
          {nextStatus && (
            <button
              type="button"
              className="btn btn--block"
              onClick={() => advanceStatus(nextStatus)}
            >
              Marquer comme « {ROLL_STATUS_LABELS[nextStatus]} »
            </button>
          )}
          <Link className="btn btn--block" to={`/rolls/${roll.id}/development`}>
            <IconFlask size={17} />
            Journal de développement
          </Link>
          <Link className="btn btn--block" to={`/export?roll=${roll.id}`}>
            <IconExport size={17} />
            Exporter les métadonnées
          </Link>
        </div>
      </Section>

      <Section
        title="Détails"
        action={
          <button
            type="button"
            className="btn btn--sm btn--ghost"
            onClick={() => setShowDetails((visible) => !visible)}
          >
            {showDetails ? 'Masquer' : 'Modifier'}
          </button>
        }
      >
        {showDetails ? (
          <RollDetailsForm rollId={roll.id} />
        ) : (
          <div className="card">
            <KeyValue label="Statut">{ROLL_STATUS_LABELS[roll.status]}</KeyValue>
            <KeyValue label="Chargé le">{formatDate(roll.loadedAt)}</KeyValue>
            {roll.finishedAt && (
              <KeyValue label="Terminé le">{formatDate(roll.finishedAt)}</KeyValue>
            )}
            {roll.lab && <KeyValue label="Laboratoire">{roll.lab}</KeyValue>}
            {roll.archiveRef && <KeyValue label="Référence">{roll.archiveRef}</KeyValue>}
            {totalCost > 0 && (
              <>
                <KeyValue label="Coût total">{formatMoney(totalCost, settings.currency)}</KeyValue>
                {frames.length > 0 && (
                  <KeyValue label="Coût par vue">
                    {formatMoney(totalCost / frames.length, settings.currency)}
                  </KeyValue>
                )}
              </>
            )}
            {roll.notes && <p className="card-meta" style={{ marginTop: 10 }}>{roll.notes}</p>}
          </div>
        )}
      </Section>

      <button type="button" className="btn btn--danger btn--block" onClick={deleteRoll}>
        <IconTrash size={17} />
        Supprimer le rouleau
      </button>
    </main>
  );
}

/**
 * Premier numéro de vue disponible. On ne se contente pas de `frames.length`
 * pour rester juste quand une vue a été supprimée au milieu du rouleau.
 */
function findNextFreeNumber(byNumber: Map<number, Frame>, exposures: number): number | null {
  for (let number = 1; number <= exposures; number += 1) {
    if (!byNumber.has(number)) return number;
  }
  return null;
}

function FrameCell({ rollId, frame }: { rollId: string; frame: Frame }) {
  const thumbUrl = useAttachmentUrl(frame.refPhotoId);
  const modifier =
    frame.status === 'reject'
      ? ' frame-cell--reject'
      : frame.status === 'keep' || frame.status === 'printed'
        ? ' frame-cell--keep'
        : '';

  return (
    <Link className={`frame-cell${modifier}`} to={`/rolls/${rollId}/frames/${frame.id}`}>
      {thumbUrl && <img className="frame-thumb" src={thumbUrl} alt="" />}
      <span className="frame-number" style={{ position: 'relative' }}>
        {frame.number}
        {frame.location && <IconPin size={9} />}
      </span>
      <span className="frame-settings" style={{ position: 'relative' }}>
        {frame.shutter ?? '—'}
        <br />
        {formatAperture(frame.aperture)}
      </span>
      {frame.subject && (
        <span className="frame-subject" style={{ position: 'relative' }}>
          {frame.subject}
        </span>
      )}
    </Link>
  );
}

/** Champs éditables du rouleau : laboratoire, référence, coûts, notes. */
function RollDetailsForm({ rollId }: { rollId: string }) {
  const roll = useRoll(rollId);
  const settings = useSettings();
  if (!roll) return null;

  const save = (patch: Parameters<typeof db.rolls.update>[1]) =>
    db.rolls.update(rollId, { ...patch, updatedAt: now() });

  const saveCost = (key: keyof NonNullable<typeof roll.costs>, value: string) =>
    save({
      costs: {
        ...roll.costs,
        [key]: value === '' ? undefined : Number(value.replace(',', '.')),
      },
    });

  return (
    <div className="card">
      <Field label="Statut">
        <select
          value={roll.status}
          onChange={(e) =>
            save({
              status: e.target.value as RollStatus,
              ...(e.target.value === 'finished' && !roll.finishedAt ? { finishedAt: now() } : {}),
            })
          }
        >
          {ROLL_STATUSES.map((status) => (
            <option key={status} value={status}>
              {ROLL_STATUS_LABELS[status]}
            </option>
          ))}
        </select>
      </Field>

      <Field label="Libellé">
        <input
          type="text"
          value={roll.label ?? ''}
          onChange={(e) => save({ label: e.target.value || undefined })}
          maxLength={80}
        />
      </Field>

      <div className="field-inline">
        <Field label="Laboratoire">
          <input
            type="text"
            value={roll.lab ?? ''}
            onChange={(e) => save({ lab: e.target.value || undefined })}
            placeholder={settings.defaultLab ?? '—'}
          />
        </Field>
        <Field label="Référence d’archive" hint="Pour retrouver la pochette de négatifs.">
          <input
            type="text"
            value={roll.archiveRef ?? ''}
            onChange={(e) => save({ archiveRef: e.target.value || undefined })}
            placeholder="2026-014"
          />
        </Field>
      </div>

      <p className="eyebrow">Coûts ({settings.currency})</p>
      <div className="field-inline">
        <Field label="Film">
          <input
            type="number"
            inputMode="decimal"
            step="0.01"
            min="0"
            value={roll.costs?.film ?? ''}
            onChange={(e) => saveCost('film', e.target.value)}
          />
        </Field>
        <Field label="Développement">
          <input
            type="number"
            inputMode="decimal"
            step="0.01"
            min="0"
            value={roll.costs?.development ?? ''}
            onChange={(e) => saveCost('development', e.target.value)}
          />
        </Field>
      </div>
      <div className="field-inline">
        <Field label="Scan">
          <input
            type="number"
            inputMode="decimal"
            step="0.01"
            min="0"
            value={roll.costs?.scan ?? ''}
            onChange={(e) => saveCost('scan', e.target.value)}
          />
        </Field>
        <Field label="Tirages">
          <input
            type="number"
            inputMode="decimal"
            step="0.01"
            min="0"
            value={roll.costs?.prints ?? ''}
            onChange={(e) => saveCost('prints', e.target.value)}
          />
        </Field>
      </div>

      <Field label="Notes">
        <textarea
          value={roll.notes ?? ''}
          onChange={(e) => save({ notes: e.target.value || undefined })}
          placeholder="Conditions particulières, incidents, remarques pour le labo…"
        />
      </Field>
    </div>
  );
}
