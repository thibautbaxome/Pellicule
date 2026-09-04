import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import App from './App';
import { initDatabase } from './db/db';
import './styles.css';

/**
 * Le routage utilise HashRouter plutôt que BrowserRouter : les URL en
 * `#/rolls/...` fonctionnent sur n'importe quel hébergement statique, sans
 * réécriture côté serveur, et survivent au rechargement d'une page profonde
 * quand l'application tourne hors ligne depuis l'écran d'accueil.
 */
initDatabase().catch((error) => {
  console.error('Initialisation de la base impossible', error);
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <HashRouter>
      <App />
    </HashRouter>
  </StrictMode>,
);
