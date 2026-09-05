/**
 * Produit une sauvegarde réelle depuis la version web, pour servir de
 * référence aux tests d'import de la version native.
 *
 * Une sauvegarde écrite à la main dériverait du format réel sans qu'on s'en
 * aperçoive ; celle-ci sort du bouton que l'utilisateur emploie vraiment.
 *
 *     node tools/make-backup-fixture.mjs
 */
import { mkdirSync } from 'node:fs';
import { chromium, devices } from 'playwright';

const BASE = process.env.BASE_URL ?? 'http://127.0.0.1:4173/';
const OUT = 'native/PelliculeCore/Tests/PelliculeCoreTests/Fixtures';
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch(
  process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {},
);
const context = await browser.newContext({
  ...devices['iPhone 14'],
  permissions: ['geolocation'],
  geolocation: { latitude: 47.7986, longitude: -4.3719 },
  locale: 'fr-FR',
  acceptDownloads: true,
});
const page = await context.newPage();

await page.goto(BASE, { waitUntil: 'networkidle' });

// Un boîtier et un objectif, pris dans les banques.
for (const [kind, query] of [['cameras', 'minolta x-300'], ['lenses', '50mm f/1.7']]) {
  await page.goto(`${BASE}#/gear/${kind}/new`);
  await page.waitForTimeout(400);
  await page.getByRole('button', { name: /banque/i }).click();
  await page.locator('input[type="search"]').fill(query);
  await page.waitForTimeout(350);
  await page.locator('.picker-item').first().click();
  await page.waitForTimeout(250);
  await page.getByRole('button', { name: 'Enregistrer' }).click();
  await page.waitForURL(/#\/gear$/);
}

// Un rouleau poussé de deux diaphragmes, avec deux vues contrastées :
// une vue courante, et une pose longue géolocalisée.
await page.goto(`${BASE}#/rolls/new`);
await page.waitForSelector('select');
await page.selectOption('select >> nth=0', 'kodak-tri-x-400');
await page.waitForTimeout(200);
await page.fill('input[maxlength="80"]', 'Pointe du Raz');
await page.getByRole('group', { name: 'Sensibilité utilisée' })
  .getByRole('button', { name: '1600' }).click();
await page.getByRole('button', { name: 'Charger le rouleau' }).click();
await page.waitForURL(/#\/rolls\/[^/]+$/);

await page.getByRole('link', { name: /Vue n° 1/ }).click();
await page.waitForURL(/frames\/new/);
await page.getByRole('group', { name: "Vitesse d’obturation" })
  .getByRole('button', { name: '1/250', exact: true }).click();
await page.getByRole('group', { name: 'Ouverture' })
  .getByRole('button', { name: '8', exact: true }).click();
await page.fill('input[placeholder="Phare d’Eckmühl au couchant"]', 'Le phare dans la brume');
await page.getByRole('button', { name: '+ Suivante' }).click();
await page.waitForTimeout(500);
await page.getByRole('group', { name: "Vitesse d’obturation" })
  .getByRole('button', { name: '8s', exact: true }).click();
await page.getByRole('button', { name: 'Enregistrer', exact: true }).click();
await page.waitForURL(/#\/rolls\/[^/]+$/);

// La sauvegarde elle-même, par le bouton que l'utilisateur emploie.
await page.goto(`${BASE}#/settings`);
await page.waitForTimeout(500);
const download = page.waitForEvent('download');
await page.getByRole('button', { name: /Sauvegarder \(sans les photos\)/ }).click();
const file = await download;
await file.saveAs(`${OUT}/backup-web.json`);

await browser.close();
console.log(`✓ ${OUT}/backup-web.json`);
