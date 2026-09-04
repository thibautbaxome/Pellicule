import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, newId, now } from '../db/db';
import { Field, KeyValue, Note, ScreenHeader, Segmented } from '../components/ui';
import type { FilmProcess, FilmStock, FilmType } from '../db/types';
import { correctReciprocity, formatDuration } from '../lib/reciprocity';
import { formatDevTime } from '../lib/development';

const TYPES: { value: FilmType; label: string }[] = [
  { value: 'bw', label: 'N&B' },
  { value: 'color_neg', label: 'Négatif' },
  { value: 'slide', label: 'Diapo' },
];

const PROCESSES: FilmProcess[] = ['N&B', 'C-41', 'E-6', 'ECN-2'];

/** Aperçu de la réciprocité à des temps parlants sur le terrain. */
const PREVIEW_TIMES = [1, 4, 15, 60];

export default function FilmEditScreen() {
  const { filmId } = useParams();
  const navigate = useNavigate();
  const isNew = filmId === 'new';

  const existing = useLiveQuery(
    () => (filmId && !isNew ? db.filmStocks.get(filmId) : undefined),
    [filmId, isNew],
  );

  const [brand, setBrand] = useState('');
  const [name, setName] = useState('');
  const [iso, setIso] = useState('400');
  const [type, setType] = useState<FilmType>('bw');
  const [process, setProcess] = useState<FilmProcess>('N&B');
  const [exposures, setExposures] = useState('36');
  const [exponent, setExponent] = useState('1.3');
  const [threshold, setThreshold] = useState('1');
  const [notes, setNotes] = useState('');
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    if (isNew || loaded || !existing) return;
    setBrand(existing.brand);
    setName(existing.name);
    setIso(String(existing.iso));
    setType(existing.type);
    setProcess(existing.process);
    setExposures(String(existing.defaultExposures));
    setExponent(String(existing.reciprocity.exponent));
    setThreshold(String(existing.reciprocity.thresholdSec));
    setNotes(existing.notes ?? '');
    setLoaded(true);
  }, [existing, isNew, loaded]);

  // Le procédé découle du type dans l'immense majorité des cas ; on le
  // pré-remplit sans l'imposer, pour laisser passer les cas particuliers
  // comme la XP2 (noir et blanc traité en C-41).
  useEffect(() => {
    if (!isNew && !loaded) return;
    setProcess((current) => {
      if (type === 'bw' && current === 'E-6') return 'N&B';
      if (type === 'color_neg' && current !== 'C-41' && current !== 'ECN-2') return 'C-41';
      if (type === 'slide') return 'E-6';
      return current;
    });
  }, [type, isNew, loaded]);

  const parsedIso = Number(iso);
  const parsedExponent = Number(exponent.replace(',', '.')) || 1;
  const parsedThreshold = Number(threshold.replace(',', '.')) || 1;
  const valid = name.trim().length > 0 && Number.isFinite(parsedIso) && parsedIso > 0;

  async function save(event: React.FormEvent) {
    event.preventDefault();
    if (!valid) return;

    const timestamp = now();
    const payload: Omit<FilmStock, 'id' | 'createdAt'> = {
      brand: brand.trim() || 'Sans marque',
      name: name.trim(),
      iso: parsedIso,
      type,
      process,
      defaultExposures: Number(exposures) || 36,
      reciprocity: { exponent: parsedExponent, thresholdSec: parsedThreshold },
      devTimes: existing?.devTimes,
      notes: notes.trim() || undefined,
      isCustom: existing?.isCustom ?? true,
      discontinued: existing?.discontinued,
      updatedAt: timestamp,
    };

    if (isNew) {
      await db.filmStocks.add({ ...payload, id: newId(), createdAt: timestamp });
    } else if (existing) {
      await db.filmStocks.update(existing.id, payload);
    }
    navigate('/gear', { replace: true });
  }

  async function remove() {
    if (!existing) return;
    const used = await db.rolls.where('filmStockId').equals(existing.id).count();
    if (used > 0) {
      window.alert(
        `Cette pellicule est utilisée par ${used} rouleau(x) : la supprimer rendrait leur ` +
          `historique illisible.`,
      );
      return;
    }
    if (!window.confirm('Supprimer cette pellicule du catalogue ?')) return;
    await db.filmStocks.delete(existing.id);
    navigate('/gear', { replace: true });
  }

  return (
    <main className="screen screen--full">
      <ScreenHeader
        title={isNew ? 'Nouvelle pellicule' : `${brand} ${name}`.trim() || 'Pellicule'}
        back={{ to: '/gear', label: 'Matériel' }}
      />

      <form onSubmit={save}>
        <div className="field-inline">
          <Field label="Marque">
            <input
              type="text"
              value={brand}
              onChange={(e) => setBrand(e.target.value)}
              placeholder="Kodak"
              maxLength={40}
            />
          </Field>
          <Field label="Nom">
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Tri-X 400"
              required
              maxLength={50}
              autoFocus={isNew}
            />
          </Field>
        </div>

        <Field label="Type">
          <Segmented label="Type de pellicule" value={type} onChange={setType} options={TYPES} />
        </Field>

        <div className="field-inline">
          <Field label="Sensibilité nominale">
            <input
              type="number"
              inputMode="numeric"
              min="1"
              value={iso}
              onChange={(e) => setIso(e.target.value)}
              required
            />
          </Field>
          <Field label="Poses">
            <input
              type="number"
              inputMode="numeric"
              min="1"
              value={exposures}
              onChange={(e) => setExposures(e.target.value)}
            />
          </Field>
        </div>

        <Field label="Procédé">
          <select value={process} onChange={(e) => setProcess(e.target.value as FilmProcess)}>
            {PROCESSES.map((value) => (
              <option key={value} value={value}>
                {value}
              </option>
            ))}
          </select>
        </Field>

        <p className="eyebrow">Réciprocité</p>
        <div className="field-inline">
          <Field label="Exposant" hint="1,0 = aucun défaut. 1,3 = valeur courante en N&B.">
            <input
              type="number"
              inputMode="decimal"
              step="0.01"
              min="1"
              max="2"
              value={exponent}
              onChange={(e) => setExponent(e.target.value)}
            />
          </Field>
          <Field label="Seuil (s)" hint="En deçà, aucune correction.">
            <input
              type="number"
              inputMode="decimal"
              step="0.5"
              min="0"
              value={threshold}
              onChange={(e) => setThreshold(e.target.value)}
            />
          </Field>
        </div>

        <div className="result">
          <p className="result-label">Temps réels à appliquer</p>
          {PREVIEW_TIMES.map((seconds) => {
            const corrected = correctReciprocity(seconds, {
              exponent: parsedExponent,
              thresholdSec: parsedThreshold,
            });
            return (
              <KeyValue key={seconds} label={`Cellule : ${seconds} s`}>
                {formatDuration(corrected.correctedSec)}
              </KeyValue>
            );
          })}
        </div>

        <div className="spacer" />

        <Field label="Notes">
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Rendu, particularités, conseils d’exposition…"
          />
        </Field>

        {existing?.devTimes && existing.devTimes.length > 0 && (
          <>
            <p className="eyebrow">Temps de développement de référence</p>
            <div className="card">
              {existing.devTimes.map((entry, index) => (
                <KeyValue
                  key={index}
                  label={`${entry.developer} ${entry.dilution} · ${entry.iso} ISO`}
                >
                  {formatDevTime(entry.timeSec)} à {entry.tempC} °C
                </KeyValue>
              ))}
            </div>
          </>
        )}

        {existing && !existing.isCustom && (
          <Note>
            Pellicule du catalogue livré. Vos modifications sont conservées et ne seront pas
            écrasées par une mise à jour de l’application.
          </Note>
        )}

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
          Supprimer la pellicule
        </button>
      )}
    </main>
  );
}
