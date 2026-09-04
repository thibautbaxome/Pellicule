import { useMemo, useState } from 'react';
import { Dial, Field, KeyValue, Note, ScreenHeader, Segmented } from '../components/ui';
import { useFilmStocks, useLenses } from '../hooks/useData';
import { useSettings } from '../hooks/useSettings';
import {
  APERTURES_FULL,
  BULB,
  formatAperture,
  formatStops,
  shutterScale,
  shutterToSeconds,
} from '../lib/exposure';
import { correctReciprocity, formatDuration } from '../lib/reciprocity';
import { depthOfField, formatDistance, hyperfocalDistance } from '../lib/depthOfField';
import { FILTER_PRESETS, combinedStops, factorToStops } from '../lib/filters';
import {
  COMMON_DEVELOPERS,
  COMMON_DILUTIONS,
  developmentTime,
  formatDevTime,
  parseDevTime,
  REFERENCE_TEMP_C,
} from '../lib/development';
import { LIGHT_CONDITIONS, evForCondition, sunny16Suggestions } from '../lib/sunny16';
import type { DevTimeReference } from '../db/types';

type Tool = 'sunny16' | 'reciprocity' | 'dof' | 'filters' | 'development';

const TOOLS: { value: Tool; label: string }[] = [
  { value: 'sunny16', label: 'f/16' },
  { value: 'reciprocity', label: 'Pose longue' },
  { value: 'dof', label: 'Netteté' },
  { value: 'filters', label: 'Filtres' },
  { value: 'development', label: 'Dév.' },
];

export default function ToolsScreen() {
  const [tool, setTool] = useState<Tool>('sunny16');

  return (
    <main className="screen">
      <ScreenHeader title="Outils" subtitle="Les calculs qu’on ne fait pas de tête" />

      <div style={{ marginBottom: 20 }}>
        <Segmented label="Calculateur" value={tool} onChange={setTool} options={TOOLS} />
      </div>

      {tool === 'sunny16' && <Sunny16Tool />}
      {tool === 'reciprocity' && <ReciprocityTool />}
      {tool === 'dof' && <DepthOfFieldTool />}
      {tool === 'filters' && <FiltersTool />}
      {tool === 'development' && <DevelopmentTool />}
    </main>
  );
}

// ---------------------------------------------------------------------------
// Règle du f/16
// ---------------------------------------------------------------------------

const COMMON_ISOS = [50, 100, 125, 200, 400, 800, 1600, 3200];

function Sunny16Tool() {
  const [iso, setIso] = useState(400);
  const [conditionId, setConditionId] = useState(LIGHT_CONDITIONS[1].id);
  const [comp, setComp] = useState(0);

  const condition = LIGHT_CONDITIONS.find((c) => c.id === conditionId) ?? LIGHT_CONDITIONS[1];
  const suggestions = sunny16Suggestions(iso, condition, comp);

  return (
    <>
      <Field label="Sensibilité">
        <Dial label="Sensibilité" values={COMMON_ISOS} selected={iso} onSelect={setIso} />
      </Field>

      <Field label="Lumière">
        <div className="list">
          {LIGHT_CONDITIONS.map((item) => (
            <button
              key={item.id}
              type="button"
              className="card"
              onClick={() => setConditionId(item.id)}
              style={
                item.id === conditionId
                  ? { borderColor: 'var(--accent)', background: 'var(--surface-2)' }
                  : undefined
              }
            >
              <div className="card-row">
                <div>
                  <p className="card-title">{item.label}</p>
                  <p className="card-meta">{item.description}</p>
                </div>
                <span className="badge mono">{formatAperture(item.aperture)}</span>
              </div>
            </button>
          ))}
        </div>
      </Field>

      <Field label="Correction">
        <Dial
          label="Correction d’exposition"
          values={[-2, -1, -0.5, 0, 0.5, 1, 2]}
          selected={comp}
          onSelect={setComp}
          format={(stops) => (stops === 0 ? '0' : stops > 0 ? `+${stops}` : `${stops}`)}
        />
      </Field>

      <div className="result">
        <p className="result-label">
          Couples équivalents · IL {Math.round(evForCondition(condition, iso) + comp)}
        </p>
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th>Ouverture</th>
                <th className="num">Vitesse</th>
              </tr>
            </thead>
            <tbody>
              {suggestions.map((suggestion) => (
                <tr key={suggestion.aperture}>
                  <td className="mono">{formatAperture(suggestion.aperture)}</td>
                  <td className="num">{suggestion.shutter}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <Note>
        La règle donne l’exposition d’un sujet moyen éclairé de face. Un sujet à contre-jour
        demande un à deux diaphragmes de plus, une scène très claire — neige, façade blanche —
        un de moins si l’on veut la garder lumineuse.
      </Note>
    </>
  );
}

// ---------------------------------------------------------------------------
// Réciprocité
// ---------------------------------------------------------------------------

function ReciprocityTool() {
  const films = useFilmStocks();
  const [filmId, setFilmId] = useState('');
  const [measured, setMeasured] = useState('4');

  const film = films.find((item) => item.id === filmId);
  const seconds = Number(measured.replace(',', '.'));
  const result =
    film && Number.isFinite(seconds) && seconds > 0
      ? correctReciprocity(seconds, film.reciprocity)
      : null;

  return (
    <>
      <Field label="Pellicule">
        <select value={filmId} onChange={(e) => setFilmId(e.target.value)}>
          <option value="">Choisir une pellicule…</option>
          {films.map((item) => (
            <option key={item.id} value={item.id}>
              {item.brand} {item.name}
            </option>
          ))}
        </select>
      </Field>

      <Field label="Temps mesuré par la cellule (secondes)">
        <input
          type="number"
          inputMode="decimal"
          step="0.5"
          min="0.1"
          value={measured}
          onChange={(e) => setMeasured(e.target.value)}
        />
      </Field>

      <Field label="">
        <Dial
          label="Temps courants"
          values={[1, 2, 4, 8, 15, 30, 60, 120]}
          selected={seconds}
          onSelect={(value) => setMeasured(String(value))}
          format={(value) => `${value} s`}
        />
      </Field>

      {result && (
        <div className="result">
          <p className="result-label">Temps de pose réel</p>
          <p className="result-value">{formatDuration(result.correctedSec)}</p>
          <div style={{ marginTop: 12 }}>
            <KeyValue label="Supplément">{formatStops(result.extraStops)}</KeyValue>
            <KeyValue label="Exposant du film">{film!.reciprocity.exponent}</KeyValue>
            <KeyValue label="Seuil de correction">{film!.reciprocity.thresholdSec} s</KeyValue>
          </div>
          {result.belowThreshold && (
            <p className="field-hint">
              Sous le seuil de ce film : la correction est négligeable, posez le temps mesuré.
            </p>
          )}
          {result.colorShiftNote && <p className="field-hint">{result.colorShiftNote}</p>}
        </div>
      )}

      <Note>
        Ces valeurs suivent la loi de puissance publiée par les fabricants. Elles cadrent une
        pose longue, mais chaque émulsion a ses écarts : sur un sujet important, doublez la
        vue avec un demi-diaphragme de plus.
      </Note>
    </>
  );
}

// ---------------------------------------------------------------------------
// Profondeur de champ
// ---------------------------------------------------------------------------

function DepthOfFieldTool() {
  const lenses = useLenses();
  const settings = useSettings();
  const [focal, setFocal] = useState(50);
  const [aperture, setAperture] = useState(8);
  const [distance, setDistance] = useState('3');

  const focalChoices = useMemo(() => {
    const fromLenses = lenses.flatMap((lens) =>
      lens.focalMin === lens.focalMax ? [lens.focalMin] : [lens.focalMin, lens.focalMax],
    );
    const standard = [21, 24, 28, 35, 50, 85, 105, 135, 200];
    return [...new Set([...fromLenses, ...standard])].sort((a, b) => a - b);
  }, [lenses]);

  const subjectDistance = Number(distance.replace(',', '.'));
  const result = depthOfField(focal, aperture, subjectDistance, settings.circleOfConfusion);
  const hyperfocal = hyperfocalDistance(focal, aperture, settings.circleOfConfusion);

  return (
    <>
      <Field label="Focale (mm)">
        <Dial label="Focale" values={focalChoices} selected={focal} onSelect={setFocal} />
      </Field>

      <Field label="Ouverture">
        <Dial
          label="Ouverture"
          values={APERTURES_FULL.filter((a) => a >= 1.4 && a <= 32)}
          selected={aperture}
          onSelect={setAperture}
          format={(value) => formatAperture(value).replace('f/', '')}
        />
      </Field>

      <Field label="Distance de mise au point (m)">
        <input
          type="number"
          inputMode="decimal"
          step="0.1"
          min="0.1"
          value={distance}
          onChange={(e) => setDistance(e.target.value)}
        />
      </Field>

      <Field label="">
        <Dial
          label="Distances courantes"
          values={[0.5, 1, 1.5, 2, 3, 5, 10, 20]}
          selected={subjectDistance}
          onSelect={(value) => setDistance(String(value))}
          format={(value) => (value < 1 ? `${value * 100} cm` : `${value} m`)}
        />
      </Field>

      {result && (
        <div className="result">
          <p className="result-label">Zone de netteté</p>
          <p className="result-value">
            {formatDistance(result.near)} → {result.farIsInfinite ? '∞' : formatDistance(result.far)}
          </p>
          <div style={{ marginTop: 12 }}>
            <KeyValue label="Étendue">
              {result.farIsInfinite ? 'Infinie' : formatDistance(result.total)}
            </KeyValue>
            <KeyValue label="Hyperfocale">{formatDistance(hyperfocal)}</KeyValue>
            <KeyValue label="Net dès">{formatDistance(hyperfocal / 2)}</KeyValue>
          </div>
          <p className="field-hint">
            Réglée sur l’hyperfocale ({formatDistance(hyperfocal)}), la netteté court de{' '}
            {formatDistance(hyperfocal / 2)} à l’infini — c’est le réglage du photographe de rue
            qui veut pouvoir déclencher sans mettre au point.
          </p>
        </div>
      )}

      <Note>
        Calculs faits pour un cercle de confusion de {settings.circleOfConfusion} mm, la valeur
        usuelle en 24×36 pour un tirage 20×25. Un grand tirage ou un examen à la loupe demande
        une valeur plus sévère, modifiable dans les réglages.
      </Note>
    </>
  );
}

// ---------------------------------------------------------------------------
// Filtres
// ---------------------------------------------------------------------------

function FiltersTool() {
  const [selected, setSelected] = useState<string[]>([]);
  const [baseShutter, setBaseShutter] = useState('1/125');

  const factors = selected
    .map((id) => FILTER_PRESETS.find((preset) => preset.id === id)?.factor ?? 1)
    .filter((factor) => factor > 0);
  const stops = combinedStops(factors);

  const baseSeconds = shutterToSeconds(baseShutter);
  const correctedSeconds = baseSeconds != null ? baseSeconds * Math.pow(2, stops) : null;

  const toggle = (id: string) =>
    setSelected((current) =>
      current.includes(id) ? current.filter((item) => item !== id) : [...current, id],
    );

  return (
    <>
      <Field label="Vitesse mesurée sans filtre">
        <Dial
          label="Vitesse mesurée"
          values={shutterScale('full').filter((value) => value !== BULB)}
          selected={baseShutter}
          onSelect={setBaseShutter}
          wide
        />
      </Field>

      <Field label="Filtres empilés">
        <div className="list">
          {FILTER_PRESETS.map((preset) => (
            <button
              key={preset.id}
              type="button"
              className="card"
              onClick={() => toggle(preset.id)}
              style={
                selected.includes(preset.id)
                  ? { borderColor: 'var(--accent)', background: 'var(--surface-2)' }
                  : undefined
              }
            >
              <div className="card-row">
                <div style={{ minWidth: 0 }}>
                  <p className="card-title">{preset.name}</p>
                  {preset.effect && <p className="card-meta">{preset.effect}</p>}
                </div>
                <span className="badge mono">
                  {preset.factor === 1 ? '—' : `+${Math.round(factorToStops(preset.factor) * 10) / 10} IL`}
                </span>
              </div>
            </button>
          ))}
        </div>
      </Field>

      <div className="result">
        <p className="result-label">Compensation totale</p>
        <p className="result-value">{formatStops(stops)}</p>
        {correctedSeconds != null && (
          <div style={{ marginTop: 12 }}>
            <KeyValue label="Nouvelle vitesse">{formatDuration(correctedSeconds)}</KeyValue>
            <KeyValue label="Ou ouvrir de">{formatStops(stops, 'diaph.')}</KeyValue>
          </div>
        )}
      </div>

      <Note>
        Un boîtier à mesure à travers l’objectif tient déjà compte du filtre : la correction
        ci-dessus ne s’applique qu’à une mesure faite sans filtre, à la cellule à main ou au
        posemètre externe.
      </Note>
    </>
  );
}

// ---------------------------------------------------------------------------
// Développement
// ---------------------------------------------------------------------------

function DevelopmentTool() {
  const films = useFilmStocks();
  const [filmId, setFilmId] = useState('');
  const [baseTime, setBaseTime] = useState('9:45');
  const [tempC, setTempC] = useState(20);
  const [pushStops, setPushStops] = useState(0);
  const [developer, setDeveloper] = useState('');
  const [dilution, setDilution] = useState('');

  const film = films.find((item) => item.id === filmId);
  const baseSec = parseDevTime(baseTime);
  const result = baseSec ? developmentTime(baseSec, { tempC, pushPullStops: pushStops }) : null;

  /** Reprend un temps de référence du catalogue dans le formulaire. */
  const applyReference = (entry: DevTimeReference) => {
    const minutes = Math.floor(entry.timeSec / 60);
    const seconds = entry.timeSec % 60;
    setBaseTime(`${minutes}:${String(seconds).padStart(2, '0')}`);
    setDeveloper(entry.developer);
    setDilution(entry.dilution);
    setTempC(entry.tempC);
  };

  return (
    <>
      <Field label="Pellicule">
        <select
          value={filmId}
          onChange={(e) => {
            setFilmId(e.target.value);
            setPushStops(0);
          }}
        >
          <option value="">Choisir une pellicule…</option>
          {films.map((item) => (
            <option key={item.id} value={item.id}>
              {item.brand} {item.name}
            </option>
          ))}
        </select>
      </Field>

      {film?.devTimes && film.devTimes.length > 0 && (
        <Field label="Temps de référence" hint="Touchez une ligne pour la reprendre.">
          <div className="list">
            {film.devTimes.map((entry, index) => (
              <button key={index} type="button" className="card" onClick={() => applyReference(entry)}>
                <div className="card-row">
                  <div>
                    <p className="card-title" style={{ fontSize: '0.94rem' }}>
                      {entry.developer} {entry.dilution}
                    </p>
                    <p className="card-meta">{entry.iso} ISO</p>
                  </div>
                  <span className="badge mono">
                    {formatDevTime(entry.timeSec)} · {entry.tempC} °C
                  </span>
                </div>
              </button>
            ))}
          </div>
        </Field>
      )}

      <div className="field-inline">
        <Field label="Révélateur">
          <input
            type="text"
            value={developer}
            onChange={(e) => setDeveloper(e.target.value)}
            list="developers"
            placeholder="Kodak D-76"
          />
          <datalist id="developers">
            {COMMON_DEVELOPERS.map((name) => (
              <option key={name} value={name} />
            ))}
          </datalist>
        </Field>
        <Field label="Dilution">
          <input
            type="text"
            value={dilution}
            onChange={(e) => setDilution(e.target.value)}
            list="dilutions"
            placeholder="1+1"
          />
          <datalist id="dilutions">
            {COMMON_DILUTIONS.map((value) => (
              <option key={value} value={value} />
            ))}
          </datalist>
        </Field>
      </div>

      <Field label="Temps de la notice" hint="Format « 9:45 », « 9 min 45 » ou secondes.">
        <input type="text" value={baseTime} onChange={(e) => setBaseTime(e.target.value)} />
      </Field>

      <Field label={`Température du bain : ${tempC} °C`}>
        <input
          type="range"
          min="14"
          max="30"
          step="0.5"
          value={tempC}
          onChange={(e) => setTempC(Number(e.target.value))}
          style={{ width: '100%', accentColor: 'var(--accent)' }}
        />
      </Field>

      <Field label="Push / pull">
        <Dial
          label="Écart de développement"
          values={[-2, -1, 0, 1, 2, 3]}
          selected={pushStops}
          onSelect={setPushStops}
          format={(stops) => (stops === 0 ? 'Nominal' : stops > 0 ? `+${stops}` : `${stops}`)}
          wide
        />
      </Field>

      {result && (
        <div className="result">
          <p className="result-label">Temps corrigé</p>
          <p className="result-value">{formatDevTime(result.correctedSec)}</p>
          <div style={{ marginTop: 12 }}>
            <KeyValue label="Temps de la notice">{formatDevTime(result.baseSec)}</KeyValue>
            <KeyValue label="Facteur température">
              ×{Math.round(result.temperatureFactor * 100) / 100}
            </KeyValue>
            <KeyValue label="Facteur push/pull">
              ×{Math.round(result.pushPullFactor * 100) / 100}
            </KeyValue>
          </div>
          {result.warnings.map((warning) => (
            <p key={warning} className="field-hint">
              ⚠ {warning}
            </p>
          ))}
        </div>
      )}

      <Note>
        Correction de température par coefficient 2,5 pour 10 °C, à partir de la référence de{' '}
        {REFERENCE_TEMP_C} °C. Le push allonge d’environ 35 % par diaphragme. Notez le résultat
        réel dans le journal du rouleau : au bout de quelques films, vos propres temps valent
        mieux que n’importe quelle table.
      </Note>
    </>
  );
}
