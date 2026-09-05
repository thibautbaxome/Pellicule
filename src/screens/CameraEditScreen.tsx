import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, newId, now } from '../db/db';
import { Field, Note, ScreenHeader } from '../components/ui';
import { CatalogPicker } from '../components/CatalogPicker';
import {
  CAMERA_TYPE_LABELS,
  FIXED_MOUNT,
  searchCameras,
  type CatalogCamera,
} from '../db/cameraCatalog';
import { BULB, shutterScale } from '../lib/exposure';
import type { Camera } from '../db/types';

/** Graduation complète, proposée pour délimiter la plage du boîtier. */
const ALL_SHUTTERS = shutterScale('full');

export default function CameraEditScreen() {
  const { cameraId } = useParams();
  const navigate = useNavigate();
  const isNew = cameraId === 'new';

  const existing = useLiveQuery(
    () => (cameraId && !isNew ? db.cameras.get(cameraId) : undefined),
    [cameraId, isNew],
  );

  const [name, setName] = useState('');
  const [mount, setMount] = useState('');
  const [serial, setSerial] = useState('');
  const [meterBias, setMeterBias] = useState('');
  const [notes, setNotes] = useState('');
  const [fastest, setFastest] = useState('');
  const [slowest, setSlowest] = useState('');
  const [fixedFocal, setFixedFocal] = useState('');
  const [fixedAperture, setFixedAperture] = useState('');
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    if (isNew || loaded || !existing) return;
    setName(existing.name);
    setMount(existing.mount ?? '');
    setSerial(existing.serial ?? '');
    setMeterBias(existing.meterBiasStops != null ? String(existing.meterBiasStops) : '');
    setNotes(existing.notes ?? '');
    setFastest(existing.shutterFastest ?? '');
    setSlowest(existing.shutterSlowest ?? '');
    setFixedFocal(existing.fixedLens ? String(existing.fixedLens.focal) : '');
    setFixedAperture(existing.fixedLens ? String(existing.fixedLens.maxAperture) : '');
    setLoaded(true);
  }, [existing, isNew, loaded]);

  async function save(event: React.FormEvent) {
    event.preventDefault();
    if (!name.trim()) return;

    const timestamp = now();
    const payload: Omit<Camera, 'id' | 'createdAt'> = {
      name: name.trim(),
      mount: mount.trim() || undefined,
      serial: serial.trim() || undefined,
      meterBiasStops: meterBias ? Number(meterBias.replace(',', '.')) : undefined,
      shutterFastest: fastest || undefined,
      shutterSlowest: slowest || undefined,
      fixedLens:
        fixedFocal && fixedAperture
          ? {
              focal: Number(fixedFocal),
              maxAperture: Number(fixedAperture.replace(',', '.')),
            }
          : undefined,
      notes: notes.trim() || undefined,
      archived: existing?.archived ?? false,
      updatedAt: timestamp,
    };

    if (isNew) {
      await db.cameras.add({ ...payload, id: newId(), createdAt: timestamp });
    } else if (existing) {
      await db.cameras.update(existing.id, payload);
    }
    navigate('/gear', { replace: true });
  }

  async function remove() {
    if (!existing) return;
    const used = await db.rolls.where('cameraId').equals(existing.id).count();
    if (used > 0) {
      // Supprimer laisserait des rouleaux orphelins : on archive à la place.
      if (
        !window.confirm(
          `Ce boîtier est utilisé par ${used} rouleau(x). Il sera archivé plutôt que ` +
            `supprimé, pour que l’historique reste lisible. Continuer ?`,
        )
      ) {
        return;
      }
      await db.cameras.update(existing.id, { archived: true, updatedAt: now() });
    } else {
      if (!window.confirm('Supprimer ce boîtier ?')) return;
      await db.cameras.delete(existing.id);
    }
    navigate('/gear', { replace: true });
  }

  return (
    <main className="screen screen--full">
      <ScreenHeader
        title={isNew ? 'Nouveau boîtier' : 'Modifier le boîtier'}
        back={{ to: '/gear', label: 'Matériel' }}
      />

      <form onSubmit={save}>
        <CatalogPicker
          label="Chercher dans la banque de boîtiers"
          placeholder="minolta x-300, canon ae-1, trip 35…"
          search={searchCameras}
          emptyHint="Plus de 150 boîtiers référencés : marque, modèle ou monture."
          renderItem={(camera: CatalogCamera) => ({
            title: `${camera.brand} ${camera.model}`,
            meta: [
              CAMERA_TYPE_LABELS[camera.type],
              camera.mount,
              camera.years,
              camera.fixedLens ? `${camera.fixedLens.focal} mm f/${camera.fixedLens.maxAperture}` : null,
            ]
              .filter(Boolean)
              .join(' · '),
            badge: camera.shutterFastest,
          })}
          onPick={(camera: CatalogCamera) => {
            setName(`${camera.brand} ${camera.model}`);
            setMount(camera.mount === FIXED_MOUNT ? '' : camera.mount);
            setFastest(camera.shutterFastest ?? '');
            setSlowest(camera.shutterSlowest ?? '');
            setFixedFocal(camera.fixedLens ? String(camera.fixedLens.focal) : '');
            setFixedAperture(camera.fixedLens ? String(camera.fixedLens.maxAperture) : '');
            if (camera.notes && !notes.trim()) setNotes(camera.notes);
          }}
        />

        <Field label="Nom" hint="Tel que vous l’appelez au quotidien.">
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Minolta X-300"
            required
            maxLength={60}
            autoFocus={isNew}
          />
        </Field>

        <div className="field-inline">
          <Field label="Monture">
            <input
              type="text"
              value={mount}
              onChange={(e) => setMount(e.target.value)}
              placeholder="Nikon F"
              maxLength={30}
            />
          </Field>
          <Field label="Numéro de série">
            <input
              type="text"
              value={serial}
              onChange={(e) => setSerial(e.target.value)}
              maxLength={40}
            />
          </Field>
        </div>

        <p className="eyebrow">Obturateur</p>
        <div className="field-inline">
          <Field label="Vitesse la plus rapide">
            <select value={fastest} onChange={(e) => setFastest(e.target.value)}>
              <option value="">Inconnue</option>
              {ALL_SHUTTERS.map((value) => (
                <option key={value} value={value}>
                  {value}
                </option>
              ))}
            </select>
          </Field>
          <Field label="La plus lente">
            <select value={slowest} onChange={(e) => setSlowest(e.target.value)}>
              <option value="">Inconnue</option>
              {[...ALL_SHUTTERS, BULB].map((value) => (
                <option key={value} value={value}>
                  {value}
                </option>
              ))}
            </select>
          </Field>
        </div>

        <p className="eyebrow">Objectif solidaire</p>
        <div className="field-inline">
          <Field label="Focale (mm)" hint="À remplir seulement pour un compact.">
            <input
              type="number"
              inputMode="numeric"
              value={fixedFocal}
              onChange={(e) => setFixedFocal(e.target.value)}
              placeholder="—"
            />
          </Field>
          <Field label="Ouverture maxi">
            <input
              type="number"
              inputMode="decimal"
              step="0.1"
              value={fixedAperture}
              onChange={(e) => setFixedAperture(e.target.value)}
              placeholder="—"
            />
          </Field>
        </div>

        <Field
          label="Décalage du posemètre (IL)"
          hint="Si la cellule du boîtier sous-expose systématiquement, notez l’écart ici : −0,5 pour une demi-valeur trop sombre."
        >
          <input
            type="number"
            inputMode="decimal"
            step="0.1"
            value={meterBias}
            onChange={(e) => setMeterBias(e.target.value)}
            placeholder="0"
          />
        </Field>

        <Field label="Notes">
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Révision, joints de lumière, particularités…"
          />
        </Field>

        {existing?.archived && <Note>Ce boîtier est archivé : il n’apparaît plus au chargement d’un rouleau.</Note>}

        <div className="action-bar">
          <button type="button" className="btn" onClick={() => navigate('/gear')}>
            Annuler
          </button>
          <button type="submit" className="btn btn--primary" disabled={!name.trim()}>
            Enregistrer
          </button>
        </div>
      </form>

      {!isNew && existing && (
        <button type="button" className="btn btn--danger btn--block" onClick={remove}>
          Supprimer le boîtier
        </button>
      )}
    </main>
  );
}
