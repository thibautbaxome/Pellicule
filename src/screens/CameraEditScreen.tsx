import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, newId, now } from '../db/db';
import { Field, Note, ScreenHeader } from '../components/ui';
import type { Camera } from '../db/types';

/** Boîtiers courants proposés en suggestion à la saisie du nom. */
const SUGGESTIONS = [
  'Canon AE-1',
  'Canon A-1',
  'Minolta X-700',
  'Nikon F3',
  'Nikon FM2',
  'Nikon FE',
  'Olympus OM-1',
  'Olympus Trip 35',
  'Pentax K1000',
  'Pentax MX',
  'Leica M6',
  'Contax T2',
  'Yashica Electro 35',
];

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
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    if (isNew || loaded || !existing) return;
    setName(existing.name);
    setMount(existing.mount ?? '');
    setSerial(existing.serial ?? '');
    setMeterBias(existing.meterBiasStops != null ? String(existing.meterBiasStops) : '');
    setNotes(existing.notes ?? '');
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
        <Field label="Nom" hint="Tel que vous l’appelez au quotidien.">
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            list="camera-suggestions"
            placeholder="Nikon FM2"
            required
            maxLength={60}
            autoFocus={isNew}
          />
          <datalist id="camera-suggestions">
            {SUGGESTIONS.map((suggestion) => (
              <option key={suggestion} value={suggestion} />
            ))}
          </datalist>
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
