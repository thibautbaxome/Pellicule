/**
 * Exporte les banques de matériel en JSON, pour que la version native lise
 * exactement les mêmes données que la version web.
 *
 * Les fichiers TypeScript restent la source de vérité : ils portent les
 * commentaires, les regroupements par marque et les notes qui expliquent d'où
 * viennent les valeurs — tout ce que JSON ne sait pas contenir. Le JSON en est
 * la projection, régénérée à chaque modification et versionnée avec elle.
 *
 *     npm run catalogs
 *
 * Retaper deux cent cinquante entrées dans un second langage aurait garanti
 * une divergence silencieuse entre les deux applications.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { build } from 'esbuild';

// Les catalogues s'importent entre eux sans extension de fichier, ce que Node
// refuse en ESM. On passe donc par esbuild — déjà présent via Vite — pour les
// réunir en un module unique, chargé ensuite en mémoire.
const bundled = await build({
  entryPoints: [new URL('../src/db/catalogEntry.ts', import.meta.url).pathname],
  bundle: true,
  format: 'esm',
  platform: 'node',
  write: false,
});
const { FILM_CATALOG, CAMERA_CATALOG, LENS_CATALOG } = await import(
  `data:text/javascript;base64,${Buffer.from(bundled.outputFiles[0].text).toString('base64')}`
);

// Les fichiers sont générés directement là où SwiftPM sait les empaqueter :
// un seul exemplaire dans le dépôt, pas de copie à tenir synchronisée.
const OUT = new URL('../native/PelliculeCore/Sources/PelliculeCore/Resources/', import.meta.url);
mkdirSync(OUT, { recursive: true });

/** Les identifiants d'objectifs et de boîtiers se déduisent de leur nom. */
const slug = (value) =>
  value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

const catalogs = {
  films: FILM_CATALOG,
  // Boîtiers et objectifs n'ont pas d'identifiant côté web — ils n'en avaient
  // pas besoin. Le natif décode dans des types nommés, on leur en donne un,
  // dérivé du nom pour rester stable d'une génération à l'autre.
  cameras: CAMERA_CATALOG.map((camera) => ({
    id: slug(`${camera.brand}-${camera.model}`),
    ...camera,
  })),
  lenses: LENS_CATALOG.map((lens) => ({
    id: slug(`${lens.brand}-${lens.name}`),
    ...lens,
  })),
};

for (const [name, entries] of Object.entries(catalogs)) {
  const path = new URL(`${name}.json`, OUT);
  writeFileSync(path, `${JSON.stringify(entries, null, 2)}\n`, 'utf8');
  console.log(`Resources/${name}.json — ${entries.length} entrées`);
}

// Un identifiant dupliqué ferait silencieusement disparaître une entrée au
// décodage : mieux vaut casser la génération que livrer un catalogue amputé.
for (const [name, entries] of Object.entries(catalogs)) {
  const ids = entries.map((entry) => entry.id).filter(Boolean);
  const duplicates = ids.filter((id, index) => ids.indexOf(id) !== index);
  if (duplicates.length > 0) {
    console.error(`\n✗ Identifiants dupliqués dans ${name} : ${[...new Set(duplicates)].join(', ')}`);
    process.exit(1);
  }
}
console.log('\n✓ Aucun identifiant dupliqué.');
