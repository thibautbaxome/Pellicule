import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { db, newId, now } from '../db/db';
import {
  useAttachmentUrl,
  useFilmStocksById,
  useFrame,
  useFrames,
  useLenses,
  useRoll,
} from '../hooks/useData';
import { useSettings } from '../hooks/useSettings';
import { Dial, Field, Note, ScreenHeader, Segmented } from '../components/ui';
import {
  FRAME_STATUS_LABELS,
  type Frame,
  type FrameStatus,
  type GeoLocation,
} from '../db/types';
import {
  BULB,
  apertureScale,
  aperturesForLens,
  formatAperture,
  formatStops,
  shutterScale,
} from '../lib/exposure';
import { FILTER_PRESETS, factorToStops } from '../lib/filters';
import { formatCoordinates, getCurrentLocation, mapsUrl } from '../lib/geo';
import { shrinkImage } from '../lib/media';
import { fromLocalInputValue, toLocalInputValue } from '../lib/format';
import { correctReciprocity, formatDuration } from '../lib/reciprocity';
import { shutterToSeconds } from '../lib/exposure';

/** Corrections d'exposition proposées, du sous-exposé au surexposé. */
const EXPOSURE_COMPS = [-3, -2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2, 3];

const LIGHT_NOTES = [
  'Plein soleil',
  'Soleil voilé',
  'Nuageux',
  'Très couvert',
  'Ombre',
  'Heure dorée',
  'Crépuscule',
  'Intérieur',
  'Nuit',
];

/** État du formulaire, dissocié de l'entité stockée. */
interface FormState {
  number: number;
  shotAt: string;
  shutter?: string;
  aperture?: number;
  lensId?: string;
  focal?: string;
  exposureComp: number;
  filterId: string;
  flash: boolean;
  focusDistance: string;
  subject: string;
  notes: string;
  tags: string;
  lightNote: string;
  meteringNote: string;
  status: FrameStatus;
  rating: number;
  location?: GeoLocation;
  refPhotoId?: string;
}

export default function FrameScreen() {
  const { rollId, frameId } = useParams();
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  const roll = useRoll(rollId);
  const frames = useFrames(rollId);
  const existing = useFrame(frameId);
  const lenses = useLenses();
  const films = useFilmStocksById();
  const settings = useSettings();

  const isNew = frameId === 'new';
  const [form, setForm] = useState<FormState | null>(null);
  const [showDetails, setShowDetails] = useState(false);
  const [geoStatus, setGeoStatus] = useState<'idle' | 'loading' | 'error'>('idle');
  const [geoError, setGeoError] = useState<string>();
  const [saving, setSaving] = useState(false);
  const fileInput = useRef<HTMLInputElement>(null);

  const film = roll ? films[roll.filmStockId] : undefined;

  // La vue la plus haute déjà saisie sert de modèle : sur un même rouleau, on
  // enchaîne souvent plusieurs déclenchements dans la même lumière.
  const lastFrame = useMemo(
    () => (frames.length > 0 ? frames[frames.length - 1] : undefined),
    [frames],
  );

  const requestedNumber = Number(searchParams.get('number')) || undefined;

  // Initialisation du formulaire, une seule fois, quand les données sont là.
  useEffect(() => {
    if (form || !roll) return;

    if (!isNew) {
      if (!existing) return;
      setForm(frameToForm(existing));
      // Une vue déjà saisie s'ouvre dépliée : on y revient pour compléter.
      setShowDetails(true);
      return;
    }

    const taken = new Set(frames.map((frame) => frame.number));
    let number = requestedNumber;
    if (!number) {
      number = 1;
      while (taken.has(number)) number += 1;
    }

    setForm({
      number,
      shotAt: toLocalInputValue(new Date().toISOString()),
      shutter: lastFrame?.shutter,
      aperture: lastFrame?.aperture,
      lensId: lastFrame?.lensId ?? settings.defaultLensId ?? (lenses.length === 1 ? lenses[0].id : undefined),
      focal: lastFrame?.focal ? String(lastFrame.focal) : '',
      exposureComp: 0,
      filterId: '',
      flash: false,
      focusDistance: '',
      subject: '',
      notes: '',
      tags: '',
      lightNote: lastFrame?.lightNote ?? '',
      meteringNote: '',
      status: 'shot',
      rating: 0,
    });
  }, [form, roll, isNew, existing, frames, requestedNumber, lastFrame, lenses, settings.defaultLensId]);

  // Géolocalisation automatique d'une nouvelle vue, sans bloquer la saisie.
  useEffect(() => {
    if (!isNew || !form || form.location || !settings.autoGeolocate || geoStatus !== 'idle') return;
    let cancelled = false;
    setGeoStatus('loading');
    getCurrentLocation().then((result) => {
      if (cancelled) return;
      if (result.location) {
        setForm((current) => (current ? { ...current, location: result.location } : current));
        setGeoStatus('idle');
      } else {
        setGeoError(result.error);
        setGeoStatus('error');
      }
    });
    return () => {
      cancelled = true;
    };
  }, [isNew, form, settings.autoGeolocate, geoStatus]);

  if (!roll || !form) {
    return (
      <main className="screen screen--full">
        <ScreenHeader title="Chargement…" back={{ to: `/rolls/${rollId}`, label: 'Rouleau' }} />
      </main>
    );
  }

  const patch = (changes: Partial<FormState>) =>
    setForm((current) => (current ? { ...current, ...changes } : current));

  const selectedLens = lenses.find((lens) => lens.id === form.lensId);
  const apertures = aperturesForLens(
    apertureScale(settings.stopIncrement),
    selectedLens?.maxAperture,
    selectedLens?.minAperture,
  );
  const shutters = [BULB, ...shutterScale(settings.stopIncrement)];

  // Sur une pose longue, la correction de réciprocité change tout : autant la
  // rappeler au moment où l'on note la vue.
  const measuredSeconds = shutterToSeconds(form.shutter);
  const reciprocity =
    film && measuredSeconds && measuredSeconds >= film.reciprocity.thresholdSec
      ? correctReciprocity(measuredSeconds, film.reciprocity)
      : null;

  async function refreshLocation() {
    setGeoStatus('loading');
    setGeoError(undefined);
    const result = await getCurrentLocation();
    if (result.location) {
      patch({ location: result.location });
      setGeoStatus('idle');
    } else {
      setGeoError(result.error);
      setGeoStatus('error');
    }
  }

  async function handlePhoto(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;

    try {
      const { blob, width, height } = await shrinkImage(file);
      const attachmentId = newId();
      await db.attachments.add({
        id: attachmentId,
        blob,
        mime: 'image/jpeg',
        width,
        height,
        createdAt: now(),
      });
      // Remplacer une photo de repérage libère l'ancienne au passage.
      if (form?.refPhotoId) await db.attachments.delete(form.refPhotoId);
      patch({ refPhotoId: attachmentId });
    } catch (error) {
      console.error('Photo de repérage illisible', error);
      window.alert('Cette image n’a pas pu être enregistrée.');
    }
  }

  async function removePhoto() {
    if (!form?.refPhotoId) return;
    await db.attachments.delete(form.refPhotoId);
    patch({ refPhotoId: undefined });
  }

  async function save(andNext: boolean) {
    if (!form || !roll || saving) return;
    setSaving(true);

    const filter = FILTER_PRESETS.find((preset) => preset.id === form.filterId);
    const timestamp = now();
    const payload: Omit<Frame, 'id' | 'createdAt'> = {
      rollId: roll.id,
      number: form.number,
      shotAt: fromLocalInputValue(form.shotAt),
      shutter: form.shutter,
      aperture: form.aperture,
      lensId: form.lensId,
      focal: form.focal ? Number(form.focal) : undefined,
      exposureComp: form.exposureComp || undefined,
      meteringNote: form.meteringNote.trim() || undefined,
      filter: filter ? { name: filter.name, factorStops: factorToStops(filter.factor) } : undefined,
      flash: form.flash || undefined,
      focusDistance: form.focusDistance ? Number(form.focusDistance.replace(',', '.')) : undefined,
      subject: form.subject.trim() || undefined,
      notes: form.notes.trim() || undefined,
      tags: form.tags
        .split(',')
        .map((tag) => tag.trim())
        .filter(Boolean),
      location: form.location,
      lightNote: form.lightNote.trim() || undefined,
      refPhotoId: form.refPhotoId,
      status: form.status,
      rating: form.rating || undefined,
      updatedAt: timestamp,
    };

    if (isNew) {
      await db.frames.add({ ...payload, id: newId(), createdAt: timestamp });
      // Le premier déclenchement fait passer le rouleau en prise de vue.
      if (roll.status === 'loaded') {
        await db.rolls.update(roll.id, { status: 'shooting', updatedAt: timestamp });
      }
    } else if (existing) {
      await db.frames.update(existing.id, payload);
    }

    if (andNext && form.number < roll.exposures) {
      // Repartir d'un formulaire neuf sur la vue suivante, en conservant les
      // réglages : c'est le geste courant en rafale de paysage.
      setForm({
        ...form,
        number: form.number + 1,
        shotAt: toLocalInputValue(new Date().toISOString()),
        subject: '',
        notes: '',
        tags: '',
        refPhotoId: undefined,
        exposureComp: 0,
      });
      setGeoStatus('idle');
      setSaving(false);
      window.scrollTo({ top: 0, behavior: 'smooth' });
      navigate(`/rolls/${roll.id}/frames/new`, { replace: true });
      return;
    }

    navigate(`/rolls/${roll.id}`, { replace: true });
  }

  async function deleteFrame() {
    if (!existing) return;
    if (!window.confirm(`Supprimer la vue n° ${existing.number} ?`)) return;
    if (existing.refPhotoId) await db.attachments.delete(existing.refPhotoId);
    await db.frames.delete(existing.id);
    navigate(`/rolls/${roll!.id}`, { replace: true });
  }

  const showAfterDevelopment = ['developed', 'scanned', 'archived'].includes(roll.status);

  return (
    <main className="screen screen--full">
      <ScreenHeader
        title={`Vue n° ${form.number}`}
        subtitle={`${roll.label || film?.name || 'Rouleau'} · ${roll.shotIso} ISO`}
        back={{ to: `/rolls/${roll.id}`, label: 'Rouleau' }}
      />

      {/* ---- Saisie rapide : les trois réglages que l'on note toujours ---- */}
      <Field label="Vitesse">
        <Dial
          label="Vitesse d’obturation"
          values={shutters}
          selected={form.shutter}
          onSelect={(shutter) => patch({ shutter })}
          wide
        />
      </Field>

      <Field label="Ouverture">
        <Dial
          label="Ouverture"
          values={apertures}
          selected={form.aperture}
          onSelect={(aperture) => patch({ aperture })}
          format={(aperture) => formatAperture(aperture).replace('f/', '')}
        />
      </Field>

      {lenses.length > 0 && (
        <Field label="Objectif">
          <select
            value={form.lensId ?? ''}
            onChange={(e) => patch({ lensId: e.target.value || undefined })}
          >
            <option value="">Non précisé</option>
            {lenses.map((lens) => (
              <option key={lens.id} value={lens.id}>
                {lens.name}
              </option>
            ))}
          </select>
        </Field>
      )}

      {selectedLens && selectedLens.focalMin !== selectedLens.focalMax && (
        <Field label="Focale utilisée (mm)">
          <input
            type="number"
            inputMode="numeric"
            min={selectedLens.focalMin}
            max={selectedLens.focalMax}
            value={form.focal}
            onChange={(e) => patch({ focal: e.target.value })}
            placeholder={`${selectedLens.focalMin}–${selectedLens.focalMax}`}
          />
        </Field>
      )}

      <Field label="Sujet">
        <input
          type="text"
          value={form.subject}
          onChange={(e) => patch({ subject: e.target.value })}
          placeholder="Phare d’Eckmühl au couchant"
          maxLength={120}
        />
      </Field>

      {reciprocity && !reciprocity.belowThreshold && (
        <Note variant="warning">
          Défaut de réciprocité : à {form.shutter}, il faut réellement poser{' '}
          <strong>{formatDuration(reciprocity.correctedSec)}</strong>, soit{' '}
          {formatStops(reciprocity.extraStops)}.
          {reciprocity.colorShiftNote ? ` ${reciprocity.colorShiftNote}` : ''}
        </Note>
      )}

      {/* ---- Repérage : position et cliché de référence ---- */}
      <div className="field">
        <label className="field-label">Repérage</label>
        <div className="card">
          <div className="card-row">
            <div style={{ minWidth: 0 }}>
              <p className="card-title" style={{ fontSize: '0.92rem' }}>
                Position
              </p>
              <p className="card-meta mono">
                {form.location
                  ? formatCoordinates(form.location) +
                    (form.location.accuracy ? ` (±${Math.round(form.location.accuracy)} m)` : '')
                  : geoStatus === 'loading'
                    ? 'Recherche…'
                    : (geoError ?? 'Non renseignée')}
              </p>
            </div>
            <div className="btn-row" style={{ flex: '0 0 auto' }}>
              {form.location && (
                <a
                  className="btn btn--sm btn--ghost"
                  href={mapsUrl(form.location)}
                  target="_blank"
                  rel="noreferrer"
                >
                  Carte
                </a>
              )}
              <button
                type="button"
                className="btn btn--sm"
                onClick={refreshLocation}
                disabled={geoStatus === 'loading'}
              >
                {form.location ? 'Actualiser' : 'Localiser'}
              </button>
            </div>
          </div>

          <div style={{ height: 10 }} />

          <RefPhoto
            attachmentId={form.refPhotoId}
            onPick={() => fileInput.current?.click()}
            onRemove={removePhoto}
          />
          <input
            ref={fileInput}
            type="file"
            accept="image/*"
            capture="environment"
            className="sr-only"
            onChange={handlePhoto}
          />
        </div>
      </div>

      {/* ---- Détails, repliés par défaut ---- */}
      <button
        type="button"
        className="btn btn--block btn--ghost"
        onClick={() => setShowDetails((visible) => !visible)}
        aria-expanded={showDetails}
      >
        {showDetails ? '− Masquer les détails' : '+ Plus de détails'}
      </button>

      {showDetails && (
        <div style={{ marginTop: 16 }}>
          <Field
            label="Correction d’exposition"
            hint="Écart appliqué par rapport à la mesure de la cellule."
          >
            <Dial
              label="Correction d’exposition"
              values={EXPOSURE_COMPS}
              selected={form.exposureComp}
              onSelect={(exposureComp) => patch({ exposureComp })}
              format={(stops) => (stops === 0 ? '0' : stops > 0 ? `+${stops}` : `${stops}`)}
            />
          </Field>

          <Field label="Filtre">
            <select
              value={form.filterId}
              onChange={(e) => patch({ filterId: e.target.value })}
            >
              <option value="">Aucun</option>
              {FILTER_PRESETS.map((preset) => (
                <option key={preset.id} value={preset.id}>
                  {preset.name} (×{preset.factor})
                </option>
              ))}
            </select>
          </Field>

          <Field label="Lumière">
            <Dial
              label="Conditions de lumière"
              values={LIGHT_NOTES}
              selected={form.lightNote}
              onSelect={(lightNote) =>
                patch({ lightNote: form.lightNote === lightNote ? '' : lightNote })
              }
              wide
            />
          </Field>

          <div className="field-inline">
            <Field label="Distance (m)">
              <input
                type="text"
                inputMode="decimal"
                value={form.focusDistance}
                onChange={(e) => patch({ focusDistance: e.target.value })}
                placeholder="—"
              />
            </Field>
            <Field label="Date et heure">
              <input
                type="datetime-local"
                value={form.shotAt}
                onChange={(e) => patch({ shotAt: e.target.value })}
              />
            </Field>
          </div>

          <label className="checkbox">
            <input
              type="checkbox"
              checked={form.flash}
              onChange={(e) => patch({ flash: e.target.checked })}
            />
            Flash utilisé
          </label>

          <Field label="Mesure" hint="Par exemple « spot sur les ombres » ou « cellule à main ».">
            <input
              type="text"
              value={form.meteringNote}
              onChange={(e) => patch({ meteringNote: e.target.value })}
              maxLength={80}
            />
          </Field>

          <Field label="Mots-clés" hint="Séparés par des virgules.">
            <input
              type="text"
              value={form.tags}
              onChange={(e) => patch({ tags: e.target.value })}
              placeholder="portrait, bord de mer"
            />
          </Field>

          <Field label="Notes">
            <textarea
              value={form.notes}
              onChange={(e) => patch({ notes: e.target.value })}
              placeholder="Ce que vous voulez vous rappeler au moment du tirage."
            />
          </Field>

          {showAfterDevelopment && (
            <>
              <Field label="Après développement">
                <Segmented
                  label="Statut de la vue"
                  value={form.status}
                  onChange={(status) => patch({ status })}
                  options={(Object.keys(FRAME_STATUS_LABELS) as FrameStatus[]).map((status) => ({
                    value: status,
                    label: FRAME_STATUS_LABELS[status],
                  }))}
                />
              </Field>

              <Field label="Note">
                <Dial
                  label="Note de la vue"
                  values={[0, 1, 2, 3, 4, 5]}
                  selected={form.rating}
                  onSelect={(rating) => patch({ rating })}
                  format={(value) => (value === 0 ? '—' : '★'.repeat(value))}
                  wide
                />
              </Field>
            </>
          )}

          {!isNew && (
            <button type="button" className="btn btn--danger btn--block" onClick={deleteFrame}>
              Supprimer cette vue
            </button>
          )}
        </div>
      )}

      <div className="action-bar">
        <button
          type="button"
          className="btn"
          onClick={() => navigate(`/rolls/${roll.id}`)}
          disabled={saving}
        >
          Annuler
        </button>
        <button
          type="button"
          className="btn btn--primary"
          onClick={() => save(false)}
          disabled={saving}
        >
          Enregistrer
        </button>
        {isNew && form.number < roll.exposures && (
          <button
            type="button"
            className="btn btn--primary"
            onClick={() => save(true)}
            disabled={saving}
          >
            + Suivante
          </button>
        )}
      </div>
    </main>
  );
}

function RefPhoto({
  attachmentId,
  onPick,
  onRemove,
}: {
  attachmentId?: string;
  onPick: () => void;
  onRemove: () => void;
}) {
  const url = useAttachmentUrl(attachmentId);

  if (!url) {
    return (
      <button type="button" className="btn btn--block" onClick={onPick}>
        📸 Photo de repérage
      </button>
    );
  }

  return (
    <div>
      <img
        src={url}
        alt="Photo de repérage"
        style={{ width: '100%', borderRadius: 'var(--radius-sm)', display: 'block' }}
      />
      <div className="btn-row" style={{ marginTop: 8 }}>
        <button type="button" className="btn btn--sm" onClick={onPick}>
          Remplacer
        </button>
        <button type="button" className="btn btn--sm btn--danger" onClick={onRemove}>
          Retirer
        </button>
      </div>
    </div>
  );
}

/** Convertit une vue stockée en état de formulaire. */
function frameToForm(frame: Frame): FormState {
  const filterPreset = FILTER_PRESETS.find((preset) => preset.name === frame.filter?.name);
  return {
    number: frame.number,
    shotAt: toLocalInputValue(frame.shotAt),
    shutter: frame.shutter,
    aperture: frame.aperture,
    lensId: frame.lensId,
    focal: frame.focal ? String(frame.focal) : '',
    exposureComp: frame.exposureComp ?? 0,
    filterId: filterPreset?.id ?? '',
    flash: frame.flash ?? false,
    focusDistance: frame.focusDistance ? String(frame.focusDistance) : '',
    subject: frame.subject ?? '',
    notes: frame.notes ?? '',
    tags: frame.tags.join(', '),
    lightNote: frame.lightNote ?? '',
    meteringNote: frame.meteringNote ?? '',
    status: frame.status,
    rating: frame.rating ?? 0,
    location: frame.location,
    refPhotoId: frame.refPhotoId,
  };
}
