import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { db, now } from '../db/db';
import { useFilmStocksById, useRoll } from '../hooks/useData';
import { Field, KeyValue, Note, ScreenHeader, Segmented } from '../components/ui';
import {
  COMMON_DEVELOPERS,
  COMMON_DILUTIONS,
  developmentTime,
  formatDevTime,
  parseDevTime,
} from '../lib/development';
import { formatStops, pushPullStops } from '../lib/exposure';
import { toLocalInputValue, fromLocalInputValue } from '../lib/format';

const AGITATIONS = [
  'Ilford : 4 retournements par minute',
  'Kodak : 5 s toutes les 30 s',
  'Continue la première minute, puis 10 s par minute',
  'Semi-stand : 1 retournement à mi-parcours',
  'Rotative (Jobo)',
];

export default function DevelopmentScreen() {
  const { rollId } = useParams();
  const navigate = useNavigate();
  const roll = useRoll(rollId);
  const films = useFilmStocksById();

  const [self, setSelf] = useState<'self' | 'lab'>('lab');
  const [developer, setDeveloper] = useState('');
  const [dilution, setDilution] = useState('');
  const [time, setTime] = useState('');
  const [tempC, setTempC] = useState('20');
  const [agitation, setAgitation] = useState('');
  const [developedAt, setDevelopedAt] = useState('');
  const [notes, setNotes] = useState('');
  const [lab, setLab] = useState('');
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    if (loaded || !roll) return;
    const development = roll.development;
    setSelf(development?.self ? 'self' : 'lab');
    setDeveloper(development?.developer ?? '');
    setDilution(development?.dilution ?? '');
    setTime(development?.timeSec ? secondsToInput(development.timeSec) : '');
    setTempC(development?.tempC != null ? String(development.tempC) : '20');
    setAgitation(development?.agitation ?? '');
    setDevelopedAt(
      development?.developedAt
        ? toLocalInputValue(development.developedAt)
        : toLocalInputValue(new Date().toISOString()),
    );
    setNotes(development?.notes ?? '');
    setLab(roll.lab ?? '');
    setLoaded(true);
  }, [roll, loaded]);

  if (!roll) {
    return (
      <main className="screen screen--full">
        <ScreenHeader title="Rouleau introuvable" back={{ to: '/', label: 'Rouleaux' }} />
      </main>
    );
  }

  const film = films[roll.filmStockId];
  const pushStops = film ? pushPullStops(roll.shotIso, film.iso) : 0;
  const reference = film?.devTimes?.find(
    (entry) =>
      (!developer || entry.developer === developer) && (!dilution || entry.dilution === dilution),
  );

  // Le rouleau ayant été poussé ou retenu à la prise de vue, le temps de la
  // notice ne s'applique pas tel quel : on montre la correction attendue.
  const suggestion =
    reference && Math.abs(pushStops) > 0.05
      ? developmentTime(reference.timeSec, {
          tempC: Number(tempC) || 20,
          referenceTempC: reference.tempC,
          pushPullStops: pushStops,
        })
      : reference
        ? developmentTime(reference.timeSec, {
            tempC: Number(tempC) || 20,
            referenceTempC: reference.tempC,
          })
        : null;

  async function save(event: React.FormEvent) {
    event.preventDefault();
    if (!roll) return;

    await db.rolls.update(roll.id, {
      lab: self === 'lab' ? lab.trim() || undefined : undefined,
      development: {
        self: self === 'self',
        developer: developer.trim() || undefined,
        dilution: dilution.trim() || undefined,
        timeSec: parseDevTime(time) ?? undefined,
        tempC: tempC ? Number(tempC.replace(',', '.')) : undefined,
        agitation: agitation.trim() || undefined,
        developedAt: developedAt ? fromLocalInputValue(developedAt) : undefined,
        notes: notes.trim() || undefined,
      },
      // Enregistrer un développement fait forcément avancer le rouleau.
      ...(['loaded', 'shooting', 'finished', 'at_lab'].includes(roll.status)
        ? { status: 'developed' as const }
        : {}),
      updatedAt: now(),
    });
    navigate(`/rolls/${roll.id}`, { replace: true });
  }

  return (
    <main className="screen screen--full">
      <ScreenHeader
        title="Journal de développement"
        subtitle={`${film ? `${film.brand} ${film.name}` : 'Rouleau'} · exposée à ${roll.shotIso} ISO`}
        back={{ to: `/rolls/${roll.id}`, label: 'Rouleau' }}
      />

      {Math.abs(pushStops) > 0.05 && film && (
        <Note variant="warning">
          Rouleau exposé {formatStops(pushStops)} par rapport aux {film.iso} ISO nominaux. Le
          développement doit être allongé ou raccourci en conséquence — précisez-le au labo si
          vous le confiez.
        </Note>
      )}

      <form onSubmit={save}>
        <Field label="Développé par">
          <Segmented
            label="Développé par"
            value={self}
            onChange={setSelf}
            options={[
              { value: 'lab', label: 'Un laboratoire' },
              { value: 'self', label: 'Moi-même' },
            ]}
          />
        </Field>

        {self === 'lab' ? (
          <Field label="Laboratoire">
            <input
              type="text"
              value={lab}
              onChange={(e) => setLab(e.target.value)}
              placeholder="Nom du labo"
              maxLength={60}
            />
          </Field>
        ) : (
          <>
            <div className="field-inline">
              <Field label="Révélateur">
                <input
                  type="text"
                  value={developer}
                  onChange={(e) => setDeveloper(e.target.value)}
                  list="dev-developers"
                  placeholder="Kodak D-76"
                />
                <datalist id="dev-developers">
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
                  list="dev-dilutions"
                  placeholder="1+1"
                />
                <datalist id="dev-dilutions">
                  {COMMON_DILUTIONS.map((value) => (
                    <option key={value} value={value} />
                  ))}
                </datalist>
              </Field>
            </div>

            {suggestion && (
              <div className="result">
                <p className="result-label">Temps suggéré</p>
                <p className="result-value">{formatDevTime(suggestion.correctedSec)}</p>
                <div style={{ marginTop: 10 }}>
                  <KeyValue label="Notice">
                    {formatDevTime(suggestion.baseSec)} à {reference!.tempC} °C
                  </KeyValue>
                  <KeyValue label="Corrections">
                    ×{Math.round(suggestion.temperatureFactor * 100) / 100} (temp.) ×
                    {Math.round(suggestion.pushPullFactor * 100) / 100} (push)
                  </KeyValue>
                </div>
                <button
                  type="button"
                  className="btn btn--sm"
                  style={{ marginTop: 10 }}
                  onClick={() => setTime(secondsToInput(Math.round(suggestion.correctedSec)))}
                >
                  Reprendre ce temps
                </button>
              </div>
            )}

            <div className="field-inline">
              <Field label="Temps" hint="« 9:45 » ou « 9 min 45 »">
                <input
                  type="text"
                  value={time}
                  onChange={(e) => setTime(e.target.value)}
                  placeholder="9:45"
                />
              </Field>
              <Field label="Température (°C)">
                <input
                  type="number"
                  inputMode="decimal"
                  step="0.5"
                  value={tempC}
                  onChange={(e) => setTempC(e.target.value)}
                />
              </Field>
            </div>

            <Field label="Agitation">
              <input
                type="text"
                value={agitation}
                onChange={(e) => setAgitation(e.target.value)}
                list="agitations"
                placeholder="4 retournements par minute"
              />
              <datalist id="agitations">
                {AGITATIONS.map((value) => (
                  <option key={value} value={value} />
                ))}
              </datalist>
            </Field>
          </>
        )}

        <Field label="Date du développement">
          <input
            type="datetime-local"
            value={developedAt}
            onChange={(e) => setDevelopedAt(e.target.value)}
          />
        </Field>

        <Field label="Notes" hint="Ce que vous changeriez la prochaine fois.">
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Négatifs un peu denses, réduire de 30 s la prochaine fois…"
          />
        </Field>

        <div className="action-bar">
          <button type="button" className="btn" onClick={() => navigate(`/rolls/${roll.id}`)}>
            Annuler
          </button>
          <button type="submit" className="btn btn--primary">
            Enregistrer
          </button>
        </div>
      </form>
    </main>
  );
}

/** Secondes vers la saisie « M:SS » attendue par le champ de temps. */
function secondsToInput(totalSeconds: number): string {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = Math.round(totalSeconds % 60);
  return `${minutes}:${String(seconds).padStart(2, '0')}`;
}
