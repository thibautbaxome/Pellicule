import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, newId, now } from '../db/db';
import { Field, Note, ScreenHeader } from '../components/ui';
import { CatalogPicker } from '../components/CatalogPicker';
import { searchLenses, type CatalogLens } from '../db/lensCatalog';
import { useCameras } from '../hooks/useData';
import type { Lens } from '../db/types';

export default function LensEditScreen() {
  const { lensId } = useParams();
  const navigate = useNavigate();
  const isNew = lensId === 'new';

  const existing = useLiveQuery(
    () => (lensId && !isNew ? db.lenses.get(lensId) : undefined),
    [lensId, isNew],
  );

  // La monture du matériel déjà déclaré oriente la recherche : sans rien
  // taper, on se voit proposer ce qui se monte réellement sur son boîtier.
  const cameras = useCameras();
  const ownedMounts = [...new Set(cameras.map((camera) => camera.mount).filter(Boolean))] as string[];

  const [name, setName] = useState('');
  const [focalMin, setFocalMin] = useState('');
  const [focalMax, setFocalMax] = useState('');
  const [maxAperture, setMaxAperture] = useState('');
  const [minAperture, setMinAperture] = useState('');
  const [filterThread, setFilterThread] = useState('');
  const [mount, setMount] = useState('');
  const [notes, setNotes] = useState('');
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    if (isNew || loaded || !existing) return;
    setName(existing.name);
    setFocalMin(String(existing.focalMin));
    setFocalMax(existing.focalMax !== existing.focalMin ? String(existing.focalMax) : '');
    setMaxAperture(existing.maxAperture != null ? String(existing.maxAperture) : '');
    setMinAperture(existing.minAperture != null ? String(existing.minAperture) : '');
    setFilterThread(existing.filterThread != null ? String(existing.filterThread) : '');
    setMount(existing.mount ?? '');
    setNotes(existing.notes ?? '');
    setLoaded(true);
  }, [existing, isNew, loaded]);

  const parsedFocalMin = Number(focalMin);
  const valid = name.trim().length > 0 && Number.isFinite(parsedFocalMin) && parsedFocalMin > 0;

  async function save(event: React.FormEvent) {
    event.preventDefault();
    if (!valid) return;

    const timestamp = now();
    const number = (value: string) => {
      const parsed = Number(value.replace(',', '.'));
      return value !== '' && Number.isFinite(parsed) ? parsed : undefined;
    };

    const payload: Omit<Lens, 'id' | 'createdAt'> = {
      name: name.trim(),
      focalMin: parsedFocalMin,
      // Un champ « focale maxi » laissé vide décrit une focale fixe.
      focalMax: number(focalMax) ?? parsedFocalMin,
      maxAperture: number(maxAperture),
      minAperture: number(minAperture),
      filterThread: number(filterThread),
      mount: mount.trim() || undefined,
      notes: notes.trim() || undefined,
      archived: existing?.archived ?? false,
      updatedAt: timestamp,
    };

    if (isNew) {
      await db.lenses.add({ ...payload, id: newId(), createdAt: timestamp });
    } else if (existing) {
      await db.lenses.update(existing.id, payload);
    }
    navigate('/gear', { replace: true });
  }

  async function remove() {
    if (!existing) return;
    const used = await db.frames.where('lensId').equals(existing.id).count();
    if (used > 0) {
      if (
        !window.confirm(
          `Cet objectif est associé à ${used} vue(s). Il sera archivé plutôt que supprimé. Continuer ?`,
        )
      ) {
        return;
      }
      await db.lenses.update(existing.id, { archived: true, updatedAt: now() });
    } else {
      if (!window.confirm('Supprimer cet objectif ?')) return;
      await db.lenses.delete(existing.id);
    }
    navigate('/gear', { replace: true });
  }

  return (
    <main className="screen screen--full">
      <ScreenHeader
        title={isNew ? 'Nouvel objectif' : 'Modifier l’objectif'}
        back={{ to: '/gear', label: 'Matériel' }}
      />

      <form onSubmit={save}>
        <CatalogPicker
          label="Chercher dans la banque d’objectifs"
          placeholder="50mm, takumar, zuiko…"
          search={(query) =>
            ownedMounts.length === 1
              ? searchLenses(query, ownedMounts[0])
              : searchLenses(query)
          }
          emptyHint={
            ownedMounts.length > 0
              ? `Objectifs en monture ${ownedMounts.join(', ')} et au-delà.`
              : 'Tapez une marque, une focale ou une monture.'
          }
          renderItem={(lens: CatalogLens) => ({
            title: lens.name,
            meta: `${lens.brand} · ${lens.mount}`,
            badge:
              lens.focalMin === lens.focalMax
                ? `${lens.focalMin} mm`
                : `${lens.focalMin}–${lens.focalMax}`,
          })}
          onPick={(lens: CatalogLens) => {
            setName(lens.name);
            setFocalMin(String(lens.focalMin));
            setFocalMax(lens.focalMax !== lens.focalMin ? String(lens.focalMax) : '');
            setMaxAperture(String(lens.maxAperture));
            setMinAperture(String(lens.minAperture));
            setFilterThread(lens.filterThread ? String(lens.filterThread) : '');
            setMount(lens.mount);
            if (lens.notes && !notes.trim()) setNotes(lens.notes);
          }}
        />

        <Field label="Nom">
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="MD 50mm f/1.7"
            required
            maxLength={70}
            autoFocus={isNew}
          />
        </Field>

        <div className="field-inline">
          <Field label="Focale (mm)">
            <input
              type="number"
              inputMode="numeric"
              min="1"
              value={focalMin}
              onChange={(e) => setFocalMin(e.target.value)}
              placeholder="50"
              required
            />
          </Field>
          <Field label="Focale maxi" hint="À remplir seulement pour un zoom.">
            <input
              type="number"
              inputMode="numeric"
              min="1"
              value={focalMax}
              onChange={(e) => setFocalMax(e.target.value)}
              placeholder="—"
            />
          </Field>
        </div>

        <div className="field-inline">
          <Field label="Ouverture maxi" hint="Le plus petit nombre : 1.4">
            <input
              type="number"
              inputMode="decimal"
              step="0.1"
              min="0.7"
              value={maxAperture}
              onChange={(e) => setMaxAperture(e.target.value)}
              placeholder="1.4"
            />
          </Field>
          <Field label="Ouverture mini" hint="Le plus grand nombre : 16">
            <input
              type="number"
              inputMode="decimal"
              step="1"
              value={minAperture}
              onChange={(e) => setMinAperture(e.target.value)}
              placeholder="16"
            />
          </Field>
        </div>

        <div className="field-inline">
          <Field label="Diamètre de filtre (mm)">
            <input
              type="number"
              inputMode="numeric"
              value={filterThread}
              onChange={(e) => setFilterThread(e.target.value)}
              placeholder="52"
            />
          </Field>
          <Field label="Monture">
            <input
              type="text"
              value={mount}
              onChange={(e) => setMount(e.target.value)}
              placeholder="Nikon F"
              maxLength={30}
            />
          </Field>
        </div>

        <Field label="Notes">
          <textarea value={notes} onChange={(e) => setNotes(e.target.value)} />
        </Field>

        <Note>
          Les ouvertures extrêmes servent à limiter la graduation proposée à la saisie d’une
          vue : inutile de faire défiler jusqu’à f/1.4 sur un objectif qui ouvre à f/3.5.
        </Note>

        <div className="action-bar">
          <button type="button" className="btn" onClick={() => navigate('/gear')}>
            Annuler
          </button>
          <button type="submit" className="btn btn--primary" disabled={!valid}>
            Enregistrer
          </button>
        </div>
      </form>

      {!isNew && existing && (
        <button type="button" className="btn btn--danger btn--block" onClick={remove}>
          Supprimer l’objectif
        </button>
      )}
    </main>
  );
}
