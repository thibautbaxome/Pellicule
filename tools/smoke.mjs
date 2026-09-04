/**
 * Parcours de bout en bout dans un iPhone simulé : créer un boîtier, un
 * objectif, charger un rouleau, saisir deux vues, puis visiter les outils,
 * l'export, les statistiques et les réglages. Chaque étape produit une
 * capture d'écran, et le script échoue à la moindre erreur de console.
 *
 * Lancer un serveur au préalable (`npm run build && npm run preview`), puis :
 *
 *     node tools/smoke.mjs
 *
 * Variables d'environnement : BASE_URL, SHOTS_DIR.
 */
import { mkdirSync } from 'node:fs';
import { chromium, devices } from 'playwright';

const OUT = process.env.SHOTS_DIR ?? 'captures';
const BASE = process.env.BASE_URL ?? 'http://127.0.0.1:4173/';

const errors = [];

mkdirSync(OUT, { recursive: true });

// CHROMIUM_PATH permet de viser un binaire déjà présent sur la machine plutôt
// que celui téléchargé par Playwright.
const browser = await chromium.launch(
  process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {},
);
const context = await browser.newContext({
  ...devices['iPhone 14'],
  permissions: ['geolocation'],
  geolocation: { latitude: 47.7986, longitude: -4.3719 },
  locale: 'fr-FR',
});
const page = await context.newPage();

page.on('console', (msg) => {
  if (msg.type() === 'error') errors.push(`console: ${msg.text()}`);
});
page.on('pageerror', (error) => errors.push(`pageerror: ${error.message}`));

const shot = async (name) => {
  await page.waitForTimeout(350);
  await page.screenshot({ path: `${OUT}/${name}.png` });
  console.log(`  → ${name}`);
};

const step = async (label, fn) => {
  console.log(`\n▸ ${label}`);
  await fn();
};

await step('Accueil vide', async () => {
  await page.goto(BASE, { waitUntil: 'networkidle' });
  await page.waitForSelector('.screen-title');
  await shot('01-accueil-vide');
});

await step('Créer un boîtier', async () => {
  await page.goto(`${BASE}#/gear/cameras/new`);
  await page.fill('input[type="text"]', 'Nikon FM2');
  await page.locator('input[placeholder="Nikon F"]').first().fill('Nikon F');
  await shot('02-nouveau-boitier');
  await page.getByRole('button', { name: 'Enregistrer' }).click();
  await page.waitForURL(/#\/gear/);
});

await step('Créer un objectif', async () => {
  await page.goto(`${BASE}#/gear/lenses/new`);
  await page.locator('input[placeholder="Nikkor 50 mm f/1.4 AI-S"]').fill('Nikkor 50 mm f/1.4');
  await page.locator('input[placeholder="50"]').fill('50');
  await page.locator('input[placeholder="1.4"]').fill('1.4');
  await page.locator('input[placeholder="16"]').fill('16');
  await page.getByRole('button', { name: 'Enregistrer' }).click();
  await page.waitForURL(/#\/gear/);
  await shot('03-materiel');
});

await step('Charger un rouleau', async () => {
  await page.goto(`${BASE}#/rolls/new`);
  await page.waitForSelector('select');
  await page.selectOption('select >> nth=0', 'kodak-tri-x-400');
  await page.waitForTimeout(200);
  await page.fill('input[maxlength="80"]', 'Pointe du Raz');
  await shot('04-nouveau-rouleau');
  // Pousser la Tri-X à 1600.
  await page.getByRole('group', { name: 'Sensibilité utilisée' }).getByRole('button', { name: '1600' }).click();
  await shot('05-rouleau-push');
  await page.getByRole('button', { name: 'Charger le rouleau' }).click();
  await page.waitForURL(/#\/rolls\/[^/]+$/);
  await shot('06-detail-rouleau');
});

await step('Saisir la vue 1', async () => {
  await page.getByRole('link', { name: /Enregistrer la vue n° 1/ }).click();
  await page.waitForURL(/frames\/new/);
  await page.getByRole('group', { name: "Vitesse d’obturation" }).getByRole('button', { name: '1/250', exact: true }).click();
  await page.getByRole('group', { name: 'Ouverture' }).getByRole('button', { name: '8', exact: true }).click();
  await page.fill('input[placeholder="Phare d’Eckmühl au couchant"]', 'Le phare dans la brume');
  await shot('07-saisie-vue');
  await page.getByRole('button', { name: '+ Plus de détails' }).click();
  await shot('08-saisie-details');
  await page.getByRole('button', { name: '+ Suivante' }).click();
  await page.waitForTimeout(500);
});

await step('Saisir la vue 2 avec pose longue', async () => {
  await page.getByRole('group', { name: "Vitesse d’obturation" }).getByRole('button', { name: '8s', exact: true }).click();
  await page.waitForTimeout(300);
  await shot('09-reciprocite-en-saisie');
  await page.getByRole('button', { name: 'Enregistrer', exact: true }).click();
  await page.waitForURL(/#\/rolls\/[^/]+$/);
  await shot('10-grille-vues');
});

await step('Accueil peuplé', async () => {
  await page.goto(`${BASE}#/`);
  await shot('11-accueil');
});

await step('Outils', async () => {
  await page.goto(`${BASE}#/tools`);
  await page.waitForSelector('.segmented');
  await shot('12-outils-sunny16');
  await page.getByRole('button', { name: 'Netteté' }).click();
  await shot('13-outils-nettete');
  await page.getByRole('button', { name: 'Dév.' }).click();
  await page.selectOption('select >> nth=0', 'kodak-tri-x-400');
  await page.waitForTimeout(300);
  await shot('14-outils-developpement');
  await page.getByRole('button', { name: 'Pose longue' }).click();
  await page.selectOption('select >> nth=0', 'kodak-tri-x-400');
  await page.waitForTimeout(300);
  await shot('15-outils-reciprocite');
});

await step('Export', async () => {
  await page.goto(`${BASE}#/export`);
  await page.waitForSelector('.result');
  await shot('16-export');
});

await step('Statistiques et réglages', async () => {
  await page.goto(`${BASE}#/stats`);
  await page.waitForTimeout(400);
  await shot('17-stats');
  await page.goto(`${BASE}#/settings`);
  await page.waitForTimeout(400);
  await shot('18-reglages');
  // Mode chambre noire.
  await page.getByRole('button', { name: 'Labo' }).click();
  await page.waitForTimeout(300);
  await shot('19-mode-labo');
});

await browser.close();

console.log(`\n${errors.length === 0 ? '✅ Aucune erreur console.' : `❌ ${errors.length} erreur(s) :`}`);
for (const error of errors) console.log(`   ${error}`);
process.exit(errors.length === 0 ? 0 : 1);
