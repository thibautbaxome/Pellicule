import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useCameras, useFilmStocksById, useLenses, useRolls } from '../hooks/useData';
import { useSettings } from '../hooks/useSettings';
import { Field, Note, ScreenHeader, Section } from '../components/ui';
import { IconAperture, IconChevronRight, IconShutter } from '../components/icons';
import { isRollOpen, type Camera, type Lens } from '../db/types';
import { apertureScale, aperturesForLens, formatAperture, shutterScale } from '../lib/exposure';
import { formatDistance } from '../lib/depthOfField';
import { LIGHT_CONDITIONS } from '../lib/sunny16';
import {
  INTENTS,
  advise,
  apertureForIntent,
  distanceForIntent,
  intentById,
  nearestValue,
  shuttersForCamera,
  type Advice,
  type Intent,
} from '../lib/assistant';
import { METER_STATUS_MESSAGES, startMeter, type MeterSession } from '../lib/lightMeter';

/** Distances proposées au curseur, en mètres, réparties à l'oreille. */
const DISTANCES = [0.5, 0.7, 1, 1.5, 2, 3, 5, 8, 12, 20, 50, 1000];

export default function AssistantScreen() {
  const settings = useSettings();
  const cameras = useCameras();
  const lenses = useLenses();
  const films = useFilmStocksById();
  const rolls = useRolls();

  // Le rouleau en cours donne le contexte le plus probable : c'est ce film-là
  // qui est dans le boîtier, à cette sensibilité-là.
  const openRoll = rolls.find((roll) => isRollOpen(roll.status));
  const openFilm = openRoll ? films[openRoll.filmStockId] : undefined;

  const [cameraId, setCameraId] = useState('');
  const [lensId, setLensId] = useState('');
  const [iso, setIso] = useState(400);
  const [conditionId, setConditionId] = useState(LIGHT_CONDITIONS[1].id);
  const [intent, setIntent] = useState<Intent>('portrait');
  const [aperture, setAperture] = useState(8);
  const [focal, setFocal] = useState(50);
  const [distanceIndex, setDistanceIndex] = useState(4);
  const [touched, setTouched] = useState(false);

  const camera: Camera | undefined = cameras.find((item) => item.id === cameraId);
  const lens: Lens | undefined = lenses.find((item) => item.id === lensId);

  // Amorçage : on suit le rouleau chargé, puis les réglages par défaut.
  useEffect(() => {
    if (cameraId) return;
    const preferred = openRoll?.cameraId ?? settings.defaultCameraId;
    if (preferred && cameras.some((item) => item.id === preferred)) setCameraId(preferred);
    else if (cameras.length > 0) setCameraId(cameras[0].id);
  }, [cameraId, cameras, openRoll?.cameraId, settings.defaultCameraId]);

  useEffect(() => {
    if (lensId || lenses.length === 0) return;
    const preferred = settings.defaultLensId;
    setLensId(preferred && lenses.some((item) => item.id === preferred) ? preferred : lenses[0].id);
  }, [lensId, lenses, settings.defaultLensId]);

  useEffect(() => {
    if (openRoll) setIso(openRoll.shotIso);
  }, [openRoll]);

  // Ouvertures et vitesses réellement disponibles sur le matériel choisi.
  const availableApertures = useMemo(() => {
    const scale = apertureScale(settings.stopIncrement);
    if (lens) return aperturesForLens(scale, lens.maxAperture, lens.minAperture);
    if (camera?.fixedLens) {
      return aperturesForLens(scale, camera.fixedLens.maxAperture, camera.fixedLens.minAperture ?? 22);
    }
    return aperturesForLens(scale, 1.4, 22);
  }, [lens, camera, settings.stopIncrement]);

  const availableShutters = useMemo(
    () =>
      shuttersForCamera(
        shutterScale(settings.stopIncrement),
        camera?.shutterFastest,
        camera?.shutterSlowest,
      ),
    [camera, settings.stopIncrement],
  );

  // La focale suit l'optique : fixe imposée, zoom recadré dans sa plage.
  useEffect(() => {
    if (lens) setFocal((current) => (lens.focalMin === lens.focalMax ? lens.focalMin : Math.min(Math.max(current, lens.focalMin), lens.focalMax)));
    else if (camera?.fixedLens) setFocal(camera.fixedLens.focal);
  }, [lens, camera]);

  const spec = intentById(intent);
  const condition = LIGHT_CONDITIONS.find((item) => item.id === conditionId) ?? LIGHT_CONDITIONS[1];

  const [measuredEv, setMeasuredEv] = useState<number | null>(null);
  const ev100 = measuredEv ?? condition.ev100;

  // Changer d'intention repositionne les réglages ; les curseurs reprennent
  // ensuite la main sans être écrasés.
  useEffect(() => {
    const target = apertureForIntent(spec, availableApertures, ev100, iso);
    setAperture(target);
    setDistanceIndex(
      nearestDistanceIndex(distanceForIntent(spec, focal, target, settings.circleOfConfusion)),
    );
    setTouched(false);
    // La focale n'entre pas volontairement dans les dépendances : ajuster le
    // zoom ne doit pas réinitialiser l'ouverture choisie.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [intent, availableApertures.length, settings.circleOfConfusion, ev100, iso]);

  const distance = DISTANCES[distanceIndex];

  const result = useMemo(
    () =>
      advise({
        ev100,
        iso,
        aperture,
        focal,
        distance,
        circleOfConfusion: settings.circleOfConfusion,
        handheld: spec.handheld,
        availableShutters,
        availableApertures,
        reciprocity: openFilm?.reciprocity,
        desiredShutterSeconds: spec.drives === 'shutter' ? (spec.target as number) : undefined,
      }),
    [ev100, iso, aperture, focal, distance, settings.circleOfConfusion, spec, availableShutters, availableApertures, openFilm],
  );

  const apertureIndex = Math.max(0, availableApertures.indexOf(nearestValue(availableApertures, aperture)));

  if (cameras.length === 0) {
    return (
      <main className="screen">
        <ScreenHeader eyebrow="Aide à la décision" title="Assistant" />
        <Note>
          L’assistant a besoin de connaître votre boîtier : c’est lui qui détermine les
          vitesses disponibles et donc ce qui est réalisable.
        </Note>
        <Link className="btn btn--primary btn--block" to="/gear/cameras/new">
          Déclarer un boîtier
        </Link>
      </main>
    );
  }

  return (
    <main className="screen">
      <ScreenHeader
        eyebrow="Aide à la décision"
        title="Assistant"
        subtitle={
          openRoll && openFilm
            ? `${openFilm.brand} ${openFilm.name} chargée à ${openRoll.shotIso} ISO`
            : 'Réglez le contexte, lisez le résultat'
        }
      />

      {/* Le résultat d'abord, et collé en haut : c'est ce qu'on vient lire, et il
          doit rester sous les yeux pendant qu'on manipule les réglages en dessous. */}
      <div className="verdict verdict--sticky">
        <div className="verdict-values">
          <span className="verdict-shutter">{result.shutter ?? '—'}</span>
          <span className="verdict-aperture">{formatAperture(aperture)}</span>
        </div>
        <p className="verdict-meta">
          IL {Math.round(ev100 + Math.log2(iso / 100))} · {iso} ISO · {focal} mm
          {result.shutter == null ? ' · hors plage du boîtier' : ''}
        </p>
        <DofBar
          near={result.dof?.near}
          far={result.dof?.far}
          subject={distance}
        />
      </div>

      {/* ---- Ce que je veux faire ---- */}
      <Section title="Intention">
        <div className="chip-row">
          {INTENTS.map((item) => (
            <button
              key={item.id}
              type="button"
              className="chip"
              aria-pressed={intent === item.id}
              onClick={() => setIntent(item.id)}
            >
              {item.label}
            </button>
          ))}
        </div>
        <p className="field-hint">{spec.goal}</p>
      </Section>

      {/* ---- La lumière ---- */}
      <Section title="Lumière">
        <div className="chip-row">
          {LIGHT_CONDITIONS.map((item) => (
            <button
              key={item.id}
              type="button"
              className="chip"
              aria-pressed={measuredEv == null && conditionId === item.id}
              onClick={() => {
                setConditionId(item.id);
                setMeasuredEv(null);
              }}
            >
              {item.label}
            </button>
          ))}
        </div>
        <p className="field-hint">
          {measuredEv == null
            ? condition.description
            : 'Valeur mesurée par la caméra. Touchez une scène pour revenir à l’estimation.'}
        </p>
        <LightMeterPanel onMeasure={setMeasuredEv} iso={iso} />
      </Section>

      {/* ---- Les curseurs : voir la conséquence de chaque geste ---- */}
      <Section title="Ajuster">
        <Field
          label={`Ouverture · ${formatAperture(aperture)}`}
          hint="Vers la gauche, l’arrière-plan fond. Vers la droite, la zone nette s’étend. La vitesse compense toute seule."
        >
          <input
            type="range"
            min={0}
            max={Math.max(0, availableApertures.length - 1)}
            step={1}
            value={apertureIndex}
            onChange={(event) => {
              setAperture(availableApertures[Number(event.target.value)]);
              setTouched(true);
            }}
          />
          <div className="range-ends">
            <span>Fond flou</span>
            <span>Tout net</span>
          </div>
        </Field>

        <Field label={`Distance du sujet · ${distance >= 1000 ? '∞' : formatDistance(distance)}`}>
          <input
            type="range"
            min={0}
            max={DISTANCES.length - 1}
            step={1}
            value={distanceIndex}
            onChange={(event) => {
              setDistanceIndex(Number(event.target.value));
              setTouched(true);
            }}
          />
          <div className="range-ends">
            <span>50 cm</span>
            <span>Infini</span>
          </div>
        </Field>

        {lens && lens.focalMin !== lens.focalMax && (
          <Field label={`Focale · ${focal} mm`}>
            <input
              type="range"
              min={lens.focalMin}
              max={lens.focalMax}
              step={1}
              value={focal}
              onChange={(event) => {
                setFocal(Number(event.target.value));
                setTouched(true);
              }}
            />
            <div className="range-ends">
              <span>{lens.focalMin} mm</span>
              <span>{lens.focalMax} mm</span>
            </div>
          </Field>
        )}

        {touched && (
          <button
            type="button"
            className="btn btn--sm btn--ghost"
            onClick={() => setIntent(intent)}
          >
            Revenir au réglage conseillé
          </button>
        )}
      </Section>

      {/* ---- Ce qu'il faut savoir ---- */}
      {result.advice.length > 0 && (
        <Section title="À surveiller">
          <div className="list">
            {result.advice.map((item) => (
              <AdviceCard key={item.title} advice={item} />
            ))}
          </div>
          {result.suggestedAperture != null && (
            <button
              type="button"
              className="btn btn--primary btn--block"
              style={{ marginTop: 12 }}
              onClick={() => {
                setAperture(result.suggestedAperture!);
                setTouched(true);
              }}
            >
              Corriger à {formatAperture(result.suggestedAperture)}
            </button>
          )}
        </Section>
      )}

      {/* ---- Le matériel, en bas : on n'y touche qu'une fois ---- */}
      <Section title="Matériel">
        <div className="field-inline">
          <Field label="Boîtier">
            <select value={cameraId} onChange={(event) => setCameraId(event.target.value)}>
              {cameras.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Objectif">
            <select value={lensId} onChange={(event) => setLensId(event.target.value)}>
              <option value="">
                {camera?.fixedLens ? `Fixe ${camera.fixedLens.focal} mm` : 'Non précisé'}
              </option>
              {lenses.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name}
                </option>
              ))}
            </select>
          </Field>
        </div>

        <Field label={`Sensibilité · ${iso} ISO`}>
          <div className="chip-row">
            {[50, 100, 200, 400, 800, 1600, 3200].map((value) => (
              <button
                key={value}
                type="button"
                className="chip"
                aria-pressed={iso === value}
                onClick={() => setIso(value)}
              >
                {value}
              </button>
            ))}
          </div>
        </Field>

        {camera && !camera.shutterFastest && (
          <Note>
            La plage de vitesses de ce boîtier n’est pas renseignée : l’assistant ne peut pas
            vous prévenir qu’un réglage sort de ses capacités.{' '}
            <Link to={`/gear/cameras/${camera.id}`}>La compléter</Link>.
          </Note>
        )}
      </Section>

      <Link className="btn btn--block" to="/tools/calc">
        <IconAperture size={17} />
        Calculateurs détaillés
        <IconChevronRight size={15} />
      </Link>
    </main>
  );
}

// ---------------------------------------------------------------------------
// Sous-composants
// ---------------------------------------------------------------------------

function AdviceCard({ advice }: { advice: Advice }) {
  return (
    <div className={`advice advice--${advice.level}`}>
      <p className="advice-title">{advice.title}</p>
      <p className="advice-detail">{advice.detail}</p>
    </div>
  );
}

/**
 * Zone de netteté, sur une échelle logarithmique : c'est ainsi que se répartit
 * réellement la profondeur de champ, très serrée de près et très étalée au
 * loin. Une échelle linéaire écraserait tout le premier plan.
 */
function DofBar({ near, far, subject }: { near?: number; far?: number; subject: number }) {
  const MIN = 0.3;
  const MAX = 200;
  const position = (metres: number) =>
    Math.min(100, Math.max(0, ((Math.log(Math.min(Math.max(metres, MIN), MAX)) - Math.log(MIN)) /
      (Math.log(MAX) - Math.log(MIN))) * 100));

  if (near == null) return null;
  const left = position(near);
  const right = far == null || !Number.isFinite(far) ? 100 : position(far);

  return (
    <div className="dofbar">
      <div className="dofbar-track">
        <div
          className="dofbar-zone"
          style={{ left: `${left}%`, width: `${Math.max(1.5, right - left)}%` }}
        />
        <div className="dofbar-subject" style={{ left: `${position(subject)}%` }} />
      </div>
      <div className="dofbar-legend">
        <span>{formatDistance(near)}</span>
        <span className="faint">zone nette</span>
        <span>{far == null || !Number.isFinite(far) ? '∞' : formatDistance(far)}</span>
      </div>
    </div>
  );
}

/**
 * Mesure par la caméra. Le panneau ne s'ouvre qu'à la demande et annonce
 * franchement son indisponibilité là où le navigateur ne publie pas les
 * réglages d'exposition — plutôt que d'afficher un chiffre sans fondement.
 */
function LightMeterPanel({
  onMeasure,
  iso,
}: {
  onMeasure: (ev100: number | null) => void;
  iso: number;
}) {
  const [session, setSession] = useState<MeterSession | null>(null);
  const [status, setStatus] = useState<string>();
  const [busy, setBusy] = useState(false);

  useEffect(() => () => session?.stop(), [session]);

  async function measure() {
    setBusy(true);
    setStatus(undefined);
    const outcome = await startMeter();

    if (outcome.status !== 'ready') {
      setStatus(METER_STATUS_MESSAGES[outcome.status]);
      setBusy(false);
      return;
    }

    const reading = outcome.session.read();
    outcome.session.stop();
    setSession(null);

    if (!reading) {
      setStatus(METER_STATUS_MESSAGES['no-exposure-data']);
    } else {
      onMeasure(reading.ev100);
      setStatus(
        `Mesuré : IL ${Math.round(reading.ev100)} à 100 ISO, soit IL ` +
          `${Math.round(reading.ev100 + Math.log2(iso / 100))} pour votre film.`,
      );
    }
    setBusy(false);
  }

  return (
    <>
      <button
        type="button"
        className="btn btn--block btn--sm"
        onClick={measure}
        disabled={busy}
        style={{ marginTop: 10 }}
      >
        <IconShutter size={16} />
        {busy ? 'Mesure…' : 'Mesurer avec la caméra'}
      </button>
      {status && <p className="field-hint">{status}</p>}
    </>
  );
}

/** Indice de la distance proposée la plus proche d'une valeur calculée. */
function nearestDistanceIndex(metres: number): number {
  let best = 0;
  let bestError = Infinity;
  DISTANCES.forEach((value, index) => {
    const error = Math.abs(Math.log(value) - Math.log(Math.max(metres, 0.1)));
    if (error < bestError) {
      bestError = error;
      best = index;
    }
  });
  return best;
}
