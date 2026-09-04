import { useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  useCamerasById,
  useFilmStocksById,
  useFrames,
  useLensesById,
  useRolls,
} from '../hooks/useData';
import { Field, Note, ScreenHeader, Section } from '../components/ui';
import {
  DEFAULT_FILENAME_PATTERN,
  buildMetadataRow,
  toCsv,
  toExiftoolScript,
  toReadableCsv,
  type ExportContext,
} from '../lib/exifExport';
import { shareOrDownload } from '../lib/backup';
import { plural } from '../lib/format';

export default function ExportScreen() {
  const [searchParams, setSearchParams] = useSearchParams();
  const rolls = useRolls();
  const films = useFilmStocksById();
  const cameras = useCamerasById();
  const lenses = useLensesById();

  const rollId = searchParams.get('roll') ?? rolls[0]?.id ?? '';
  const roll = rolls.find((item) => item.id === rollId);
  const frames = useFrames(rollId);

  const [pattern, setPattern] = useState(DEFAULT_FILENAME_PATTERN);
  const [status, setStatus] = useState<string>();

  const context: ExportContext | null = useMemo(() => {
    if (!roll) return null;
    return {
      roll,
      frames,
      film: films[roll.filmStockId],
      camera: cameras[roll.cameraId],
      lenses,
    };
  }, [roll, frames, films, cameras, lenses]);

  const rows = useMemo(
    () => (context ? context.frames.map((frame) => buildMetadataRow(context, frame, pattern)) : []),
    [context, pattern],
  );

  const rollTitle = roll
    ? roll.label || (films[roll.filmStockId] ? `${films[roll.filmStockId].brand} ${films[roll.filmStockId].name}` : 'Rouleau')
    : '';
  const baseName = (roll?.archiveRef || rollTitle || 'rouleau')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

  async function exportFile(kind: 'csv' | 'script' | 'readable') {
    if (!context) return;
    try {
      if (kind === 'csv') {
        await shareOrDownload(`${baseName}-exiftool.csv`, toCsv(rows), 'text/csv');
      } else if (kind === 'script') {
        await shareOrDownload(
          `${baseName}-metadonnees.sh`,
          toExiftoolScript(rows, rollTitle),
          'text/x-shellscript',
        );
      } else {
        await shareOrDownload(`${baseName}-carnet.csv`, toReadableCsv(context), 'text/csv');
      }
      setStatus('Fichier généré.');
    } catch (error) {
      console.error('Export impossible', error);
      setStatus('L’export a échoué.');
    }
  }

  return (
    <main className="screen">
      <ScreenHeader
        title="Exporter"
        subtitle="Injecter vos réglages dans les scans du labo"
        back={{ to: roll ? `/rolls/${roll.id}` : '/', label: 'Retour' }}
      />

      <Field label="Rouleau">
        <select
          value={rollId}
          onChange={(e) => setSearchParams({ roll: e.target.value }, { replace: true })}
        >
          {rolls.map((item) => {
            const film = films[item.filmStockId];
            return (
              <option key={item.id} value={item.id}>
                {item.label || (film ? `${film.brand} ${film.name}` : 'Rouleau')}
                {item.archiveRef ? ` — ${item.archiveRef}` : ''}
              </option>
            );
          })}
        </select>
      </Field>

      {!roll ? (
        <Note>Aucun rouleau à exporter pour l’instant.</Note>
      ) : frames.length === 0 ? (
        <Note>Ce rouleau ne contient aucune vue enregistrée.</Note>
      ) : (
        <>
          <Field
            label="Nom des fichiers scannés"
            hint={
              <>
                Jetons disponibles : <code>{'{n}'}</code> numéro de vue,{' '}
                <code>{'{nn}'}</code> sur deux chiffres, <code>{'{nnn}'}</code> sur trois,{' '}
                <code>{'{roll}'}</code> référence du rouleau.
              </>
            }
          >
            <input
              type="text"
              value={pattern}
              onChange={(e) => setPattern(e.target.value)}
              spellCheck={false}
              autoCapitalize="none"
            />
          </Field>

          <div className="result">
            <p className="result-label">Aperçu · {plural(rows.length, 'vue')}</p>
            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Fichier</th>
                    <th>Date</th>
                    <th className="num">Vitesse</th>
                    <th className="num">f/</th>
                    <th>Objectif</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.slice(0, 6).map((row) => (
                    <tr key={row.SourceFile}>
                      <td className="mono">{row.SourceFile}</td>
                      <td>{row.DateTimeOriginal.slice(0, 10).replace(/:/g, '-')}</td>
                      <td className="num">{row.ExposureTime || '—'}</td>
                      <td className="num">{row.FNumber || '—'}</td>
                      <td>{row.LensModel || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {rows.length > 6 && (
              <p className="field-hint">… et {rows.length - 6} autres vues.</p>
            )}
          </div>

          <Section title="Formats">
            <div className="stack">
              <button type="button" className="btn btn--primary btn--block" onClick={() => exportFile('csv')}>
                CSV pour exiftool
              </button>
              <button type="button" className="btn btn--block" onClick={() => exportFile('script')}>
                Script shell prêt à lancer
              </button>
              <button type="button" className="btn btn--block" onClick={() => exportFile('readable')}>
                Carnet en CSV (tableur)
              </button>
            </div>
            {status && <p className="field-hint">{status}</p>}
          </Section>

          <Section title="Mode d’emploi">
            <div className="card">
              <p className="card-meta" style={{ marginTop: 0 }}>
                Une fois les scans récupérés du labo, placez-les dans un dossier sur un
                ordinateur disposant d’<strong>exiftool</strong> (<code>brew install exiftool</code>{' '}
                sur Mac, <code>apt install libimage-exiftool-perl</code> sous Linux).
              </p>
              <p className="card-meta">
                Avec le CSV, une seule commande suffit depuis ce dossier :
              </p>
              <pre
                className="mono"
                style={{
                  background: 'var(--surface)',
                  padding: 11,
                  borderRadius: 'var(--radius-sm)',
                  overflowX: 'auto',
                  fontSize: '0.8rem',
                  margin: '8px 0',
                }}
              >
                exiftool -csv={baseName}-exiftool.csv .
              </pre>
              <p className="card-meta">
                Les noms de fichiers du CSV doivent correspondre exactement à ceux de vos
                scans : ajustez le motif ci-dessus, ou renommez les fichiers. Les vues
                manquantes sont simplement ignorées.
              </p>
            </div>
          </Section>

          <Note>
            exiftool conserve une copie de chaque original sous le suffixe{' '}
            <code>_original</code>. Vérifiez le résultat avant de supprimer ces copies.
          </Note>
        </>
      )}
    </main>
  );
}
