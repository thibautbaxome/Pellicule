import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { db, newId, now, updateSettings } from '../db/db';
import { useCameras, useFilmStocks } from '../hooks/useData';
import { useSettings } from '../hooks/useSettings';
import { Dial, Field, Note, ScreenHeader } from '../components/ui';
import { formatStops, pushPullStops } from '../lib/exposure';
import { toLocalInputValue, fromLocalInputValue } from '../lib/format';
import type { FilmStock, Roll } from '../db/types';

const FILM_TYPE_LABELS = {
  bw: 'Noir et blanc',
  color_neg: 'Négatif couleur',
  slide: 'Diapositive',
} as const;

const EXPOSURE_CHOICES = [12, 24, 27, 36];

/**
 * Sensibilités proposées autour de l'ISO nominal, de deux diaphragmes en
 * dessous à trois au-dessus : c'est la plage sur laquelle un labo accepte de
 * corriger le développement.
 */
function isoChoices(boxIso: number): number[] {
  return [-2, -1, 0, 1, 2, 3]
    .map((stops) => Math.round(boxIso * Math.pow(2, stops)))
    .filter((iso) => iso >= 6 && iso <= 25_600);
}

export default function RollNewScreen() {
  const navigate = useNavigate();
  const settings = useSettings();
  const films = useFilmStocks();
  const cameras = useCameras();

  const [filmStockId, setFilmStockId] = useState('');
  const [cameraId, setCameraId] = useState('');
  const [shotIso, setShotIso] = useState<number | null>(null);
  const [exposures, setExposures] = useState(settings.defaultExposures);
  const [label, setLabel] = useState('');
  const [loadedAt, setLoadedAt] = useState(() => toLocalInputValue(new Date().toISOString()));
  const [filmCost, setFilmCost] = useState('');
  const [saving, setSaving] = useState(false);

  // Les valeurs par défaut arrivent de façon asynchrone : on ne les applique
  // qu'une fois, et seulement si l'utilisateur n'a encore rien choisi.
  useEffect(() => {
    if (!filmStockId && settings.defaultFilmStockId) setFilmStockId(settings.defaultFilmStockId);
  }, [settings.defaultFilmStockId, filmStockId]);

  useEffect(() => {
    if (cameraId) return;
    if (settings.defaultCameraId) setCameraId(settings.defaultCameraId);
    else if (cameras.length === 1) setCameraId(cameras[0].id);
  }, [settings.defaultCameraId, cameras, cameraId]);

  const selectedFilm: FilmStock | undefined = useMemo(
    () => films.find((film) => film.id === filmStockId),
    [films, filmStockId],
  );

  // Tant que la sensibilité n'est pas touchée, elle suit l'ISO nominal du film.
  const effectiveIso = shotIso ?? selectedFilm?.iso ?? 400;
  const pushStops = selectedFilm ? pushPullStops(effectiveIso, selectedFilm.iso) : 0;

  const groupedFilms = useMemo(() => {
    const groups: Record<string, FilmStock[]> = { bw: [], color_neg: [], slide: [] };
    for (const film of films) {
      if (!film.discontinued || film.id === filmStockId) groups[film.type].push(film);
    }
    return groups;
  }, [films, filmStockId]);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (!selectedFilm || !cameraId || saving) return;
    setSaving(true);

    const timestamp = now();
    const roll: Roll = {
      id: newId(),
      label: label.trim() || undefined,
      filmStockId: selectedFilm.id,
      cameraId,
      shotIso: effectiveIso,
      exposures,
      loadedAt: fromLocalInputValue(loadedAt),
      status: 'loaded',
      costs: filmCost ? { film: Number(filmCost.replace(',', '.')) } : undefined,
      createdAt: timestamp,
      updatedAt: timestamp,
    };

    await db.rolls.add(roll);
    // Le prochain rouleau repartira sur le même matériel neuf fois sur dix.
    await updateSettings({
      defaultCameraId: cameraId,
      defaultFilmStockId: selectedFilm.id,
      defaultExposures: exposures,
    });
    navigate(`/rolls/${roll.id}`, { replace: true });
  }

  if (cameras.length === 0) {
    return (
      <main className="screen screen--full">
        <ScreenHeader title="Charger un rouleau" back={{ to: '/', label: 'Rouleaux' }} />
        <Note>
          Aucun boîtier n’est encore enregistré. Déclarez-en un d’abord : il sera proposé
          par défaut aux rouleaux suivants et servira à renseigner les métadonnées de vos
          scans.
        </Note>
        <Link className="btn btn--primary btn--block" to="/gear/cameras/new">
          Ajouter un boîtier
        </Link>
      </main>
    );
  }

  return (
    <main className="screen screen--full">
      <ScreenHeader title="Charger un rouleau" back={{ to: '/', label: 'Rouleaux' }} />

      <form onSubmit={handleSubmit}>
        <Field label="Pellicule">
          <select
            value={filmStockId}
            onChange={(event) => {
              setFilmStockId(event.target.value);
              // Repartir du nominal : la poussée du film précédent n'a aucune
              // raison de s'appliquer au suivant.
              setShotIso(null);
              const film = films.find((f) => f.id === event.target.value);
              if (film) setExposures(film.defaultExposures);
            }}
            required
          >
            <option value="">Choisir une pellicule…</option>
            {(Object.keys(FILM_TYPE_LABELS) as (keyof typeof FILM_TYPE_LABELS)[]).map((type) => (
              <optgroup key={type} label={FILM_TYPE_LABELS[type]}>
                {groupedFilms[type].map((film) => (
                  <option key={film.id} value={film.id}>
                    {film.brand} {film.name} — {film.iso} ISO
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
        </Field>

        <Field label="Boîtier">
          <select value={cameraId} onChange={(e) => setCameraId(e.target.value)} required>
            <option value="">Choisir un boîtier…</option>
            {cameras.map((camera) => (
              <option key={camera.id} value={camera.id}>
                {camera.name}
              </option>
            ))}
          </select>
        </Field>

        {selectedFilm && (
          <Field
            label="Sensibilité utilisée"
            hint={
              Math.abs(pushStops) < 0.05
                ? `Exposition nominale (${selectedFilm.iso} ISO boîte).`
                : `${formatStops(pushStops)} par rapport aux ${selectedFilm.iso} ISO de la boîte. ` +
                  `Pensez à le signaler au labo : le développement doit être adapté.`
            }
          >
            <Dial
              label="Sensibilité utilisée"
              values={isoChoices(selectedFilm.iso)}
              selected={effectiveIso}
              onSelect={setShotIso}
              format={(iso) => `${iso}`}
            />
          </Field>
        )}

        <Field label="Nombre de poses">
          <Dial
            label="Nombre de poses"
            values={EXPOSURE_CHOICES}
            selected={exposures}
            onSelect={setExposures}
          />
        </Field>

        <Field label="Libellé" hint="Facultatif. Par exemple « Week-end à Belle-Île ».">
          <input
            type="text"
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            placeholder={selectedFilm ? `${selectedFilm.brand} ${selectedFilm.name}` : 'Sans titre'}
            maxLength={80}
          />
        </Field>

        <div className="field-inline">
          <Field label="Chargé le">
            <input
              type="datetime-local"
              value={loadedAt}
              onChange={(e) => setLoadedAt(e.target.value)}
            />
          </Field>
          <Field label={`Prix du film (${settings.currency})`}>
            <input
              type="number"
              inputMode="decimal"
              step="0.01"
              min="0"
              value={filmCost}
              onChange={(e) => setFilmCost(e.target.value)}
              placeholder="—"
            />
          </Field>
        </div>

        <div className="action-bar">
          <button
            type="submit"
            className="btn btn--primary"
            disabled={!selectedFilm || !cameraId || saving}
          >
            Charger le rouleau
          </button>
        </div>
      </form>
    </main>
  );
}
