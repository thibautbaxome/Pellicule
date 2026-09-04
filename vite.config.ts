import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  // Chemins relatifs : l'application fonctionne à la racine d'un domaine
  // comme dans un sous-dossier, sans reconfiguration.
  base: './',

  plugins: [
    react(),
    VitePWA({
      // L'application se met à jour toute seule au prochain lancement, sans
      // demander confirmation : il n'y a pas de version à gérer côté
      // utilisateur, et les données vivent hors du cache.
      registerType: 'autoUpdate',
      includeAssets: ['icons/apple-touch-icon.png', 'icons/favicon-32.png'],
      manifest: {
        name: 'Pellicule — carnet argentique',
        short_name: 'Pellicule',
        description:
          'Carnet de prise de vue argentique : rouleaux, réglages vue par vue, ' +
          'développement et export des métadonnées vers les scans.',
        lang: 'fr',
        dir: 'ltr',
        start_url: './',
        scope: './',
        display: 'standalone',
        orientation: 'portrait',
        background_color: '#100f12',
        theme_color: '#100f12',
        categories: ['photo', 'productivity', 'utilities'],
        icons: [
          { src: './icons/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: './icons/icon-512.png', sizes: '512x512', type: 'image/png' },
          {
            src: './icons/icon-512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
        ],
      },
      workbox: {
        // Tout l'applicatif est préchargé : une fois installée, l'application
        // n'a plus jamais besoin du réseau.
        globPatterns: ['**/*.{js,css,html,png,svg,woff2}'],
        // Le routage se faisant par fragment d'URL, une seule page à servir.
        navigateFallback: 'index.html',
        cleanupOutdatedCaches: true,
      },
      devOptions: {
        // Permet de vérifier le comportement hors ligne sans passer par un
        // build de production.
        enabled: false,
      },
    }),
  ],
});
