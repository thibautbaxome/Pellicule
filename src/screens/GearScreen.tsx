import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useCameras, useFilmStocks, useLenses } from '../hooks/useData';
import { EmptyState, ScreenHeader, Segmented } from '../components/ui';
import { isPrime } from '../db/types';
import { formatAperture } from '../lib/exposure';

type Tab = 'cameras' | 'lenses' | 'films';

const FILM_TYPE_LABELS = {
  bw: 'Noir et blanc',
  color_neg: 'Négatif couleur',
  slide: 'Diapositive',
} as const;

export default function GearScreen() {
  const [tab, setTab] = useState<Tab>('cameras');
  const cameras = useCameras();
  const lenses = useLenses();
  const films = useFilmStocks();

  return (
    <main className="screen">
      <ScreenHeader title="Matériel" subtitle="Boîtiers, objectifs et pellicules" />

      <div style={{ marginBottom: 18 }}>
        <Segmented
          label="Catégorie de matériel"
          value={tab}
          onChange={setTab}
          options={[
            { value: 'cameras', label: `Boîtiers (${cameras.length})` },
            { value: 'lenses', label: `Objectifs (${lenses.length})` },
            { value: 'films', label: `Pellicules (${films.length})` },
          ]}
        />
      </div>

      {tab === 'cameras' && (
        <>
          {cameras.length === 0 ? (
            <EmptyState icon="📷" title="Aucun boîtier enregistré">
              <p className="dim">Déclarez votre appareil pour commencer un rouleau.</p>
            </EmptyState>
          ) : (
            <div className="list">
              {cameras.map((camera) => (
                <Link key={camera.id} className="card" to={`/gear/cameras/${camera.id}`}>
                  <div className="card-row">
                    <div>
                      <p className="card-title">{camera.name}</p>
                      <p className="card-meta">
                        {[camera.mount && `Monture ${camera.mount}`, camera.serial && `N° ${camera.serial}`]
                          .filter(Boolean)
                          .join(' · ') || 'Aucun détail'}
                      </p>
                    </div>
                    <span className="dim">›</span>
                  </div>
                </Link>
              ))}
            </div>
          )}
          <Link className="btn btn--primary fab" to="/gear/cameras/new">
            + Boîtier
          </Link>
        </>
      )}

      {tab === 'lenses' && (
        <>
          {lenses.length === 0 ? (
            <EmptyState icon="🔍" title="Aucun objectif enregistré">
              <p className="dim">
                Facultatif, mais c’est ce qui permettra de renseigner la focale dans les
                métadonnées de vos scans.
              </p>
            </EmptyState>
          ) : (
            <div className="list">
              {lenses.map((lens) => (
                <Link key={lens.id} className="card" to={`/gear/lenses/${lens.id}`}>
                  <div className="card-row">
                    <div>
                      <p className="card-title">{lens.name}</p>
                      <p className="card-meta mono">
                        {isPrime(lens) ? `${lens.focalMin} mm` : `${lens.focalMin}–${lens.focalMax} mm`}
                        {lens.maxAperture ? ` · ${formatAperture(lens.maxAperture)}` : ''}
                        {lens.filterThread ? ` · ⌀${lens.filterThread}` : ''}
                      </p>
                    </div>
                    <span className="dim">›</span>
                  </div>
                </Link>
              ))}
            </div>
          )}
          <Link className="btn btn--primary fab" to="/gear/lenses/new">
            + Objectif
          </Link>
        </>
      )}

      {tab === 'films' && (
        <>
          <div className="list">
            {(Object.keys(FILM_TYPE_LABELS) as (keyof typeof FILM_TYPE_LABELS)[]).map((type) => {
              const typeFilms = films.filter((film) => film.type === type);
              if (typeFilms.length === 0) return null;
              return (
                <div key={type}>
                  <p className="section-title">{FILM_TYPE_LABELS[type]}</p>
                  {typeFilms.map((film) => (
                    <Link key={film.id} className="card" to={`/gear/films/${film.id}`}>
                      <div className="card-row">
                        <div style={{ minWidth: 0 }}>
                          <p className="card-title">
                            {film.brand} {film.name}
                          </p>
                          <p className="card-meta mono">
                            {film.iso} ISO · {film.process}
                            {film.reciprocity.exponent > 1
                              ? ` · réciprocité p=${film.reciprocity.exponent}`
                              : ' · réciprocité négligeable'}
                          </p>
                        </div>
                        <div className="badge-row" style={{ flex: '0 0 auto' }}>
                          {film.isCustom && <span className="badge badge--accent">Perso</span>}
                          {film.discontinued && <span className="badge">Arrêtée</span>}
                        </div>
                      </div>
                    </Link>
                  ))}
                </div>
              );
            })}
          </div>
          <Link className="btn btn--primary fab" to="/gear/films/new">
            + Pellicule
          </Link>
        </>
      )}
    </main>
  );
}
