/**
 * Vérifie que l'application reste utilisable une fois le réseau coupé.
 *
 * Charge la page, attend l'installation du service worker, saisit une donnée,
 * puis passe le contexte hors ligne et recharge : l'application doit repartir
 * et retrouver ses données. C'est exactement ce qui se passe en pleine
 * campagne sans réseau.
 *
 *     node tools/offline-check.mjs
 */
import { chromium, devices } from 'playwright';

const BASE = process.env.BASE_URL ?? 'http://127.0.0.1:4173/';

const browser = await chromium.launch(
  process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {},
);
const context = await browser.newContext({ ...devices['iPhone 14'], locale: 'fr-FR' });
const page = await context.newPage();

const fail = async (message) => {
  console.error(`❌ ${message}`);
  await browser.close();
  process.exit(1);
};

console.log('▸ Chargement initial');
await page.goto(BASE, { waitUntil: 'networkidle' });
await page.waitForSelector('.screen-title');

console.log('▸ Attente du service worker');
const registered = await page.evaluate(async () => {
  if (!('serviceWorker' in navigator)) return false;
  const registration = await navigator.serviceWorker.ready;
  return Boolean(registration.active);
});
if (!registered) await fail('Aucun service worker actif.');
console.log('  service worker actif');

console.log('▸ Saisie d’un boîtier');
await page.goto(`${BASE}#/gear/cameras/new`);
await page.fill('input[type="text"]', 'Olympus OM-1');
await page.getByRole('button', { name: 'Enregistrer' }).click();
await page.waitForURL(/#\/gear$/);

// Laisser au service worker le temps de finir sa mise en cache.
await page.waitForTimeout(1500);

console.log('▸ Coupure du réseau et rechargement');
await context.setOffline(true);
await page.goto(BASE);
await page.waitForSelector('.screen-title', { timeout: 10_000 });

const title = await page.locator('.screen-title').first().textContent();
if (title?.trim() !== 'Pellicule') await fail(`Titre inattendu hors ligne : « ${title} »`);
console.log('  application chargée hors ligne');

console.log('▸ Vérification des données hors ligne');
await page.goto(`${BASE}#/gear`);
await page.waitForSelector('.card-title', { timeout: 10_000 });
const cameraName = await page.locator('.card-title').first().textContent();
if (cameraName?.trim() !== 'Olympus OM-1') {
  await fail(`Boîtier introuvable hors ligne : « ${cameraName} »`);
}
console.log('  données retrouvées');

console.log('▸ Écriture hors ligne');
await page.goto(`${BASE}#/gear/lenses/new`);
await page.locator('input[placeholder="MD 50mm f/1.7"]').fill('Zuiko 50 mm f/1.8');
await page.locator('input[placeholder="50"]').fill('50');
await page.getByRole('button', { name: 'Enregistrer' }).click();
await page.waitForURL(/#\/gear$/);
await page.waitForTimeout(400);
const lensCount = await page.locator('.segmented button', { hasText: 'Objectifs' }).textContent();
if (!lensCount?.includes('(1)')) await fail(`Objectif non enregistré hors ligne : ${lensCount}`);
console.log('  écriture acceptée hors ligne');

await browser.close();
console.log('\n✅ L’application fonctionne intégralement hors ligne.');
