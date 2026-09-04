import { NavLink, Route, Routes, useLocation } from 'react-router-dom';
import { useSettings, useThemeEffect } from './hooks/useSettings';
import { IconAperture, IconCamera, IconFilm, IconSliders } from './components/icons';
import RollsScreen from './screens/RollsScreen';
import RollNewScreen from './screens/RollNewScreen';
import RollScreen from './screens/RollScreen';
import FrameScreen from './screens/FrameScreen';
import DevelopmentScreen from './screens/DevelopmentScreen';
import GearScreen from './screens/GearScreen';
import CameraEditScreen from './screens/CameraEditScreen';
import LensEditScreen from './screens/LensEditScreen';
import FilmEditScreen from './screens/FilmEditScreen';
import ToolsScreen from './screens/ToolsScreen';
import SettingsScreen from './screens/SettingsScreen';
import StatsScreen from './screens/StatsScreen';
import ExportScreen from './screens/ExportScreen';

/** Onglets de la barre inférieure, dans l'ordre d'affichage. */
const TABS = [
  { to: '/', Icon: IconFilm, label: 'Rouleaux' },
  { to: '/gear', Icon: IconCamera, label: 'Matériel' },
  { to: '/tools', Icon: IconAperture, label: 'Outils' },
  { to: '/settings', Icon: IconSliders, label: 'Réglages' },
];

/**
 * Les écrans de saisie et de formulaire occupent tout l'écran : masquer la
 * barre d'onglets évite les sorties accidentelles en pleine saisie de vue.
 */
const FULLSCREEN_PATTERNS = [
  /^\/rolls\/new$/,
  /^\/rolls\/[^/]+\/frames\//,
  /^\/rolls\/[^/]+\/development$/,
  /^\/gear\/(cameras|lenses)\//,
  /^\/gear\/films\//,
];

export default function App() {
  const settings = useSettings();
  const location = useLocation();
  useThemeEffect(settings.theme);

  const hideTabBar = FULLSCREEN_PATTERNS.some((pattern) => pattern.test(location.pathname));

  return (
    <div className="app">
      <Routes>
        <Route path="/" element={<RollsScreen />} />
        <Route path="/rolls/new" element={<RollNewScreen />} />
        <Route path="/rolls/:rollId" element={<RollScreen />} />
        <Route path="/rolls/:rollId/frames/:frameId" element={<FrameScreen />} />
        <Route path="/rolls/:rollId/development" element={<DevelopmentScreen />} />
        <Route path="/gear" element={<GearScreen />} />
        <Route path="/gear/cameras/:cameraId" element={<CameraEditScreen />} />
        <Route path="/gear/lenses/:lensId" element={<LensEditScreen />} />
        <Route path="/gear/films/:filmId" element={<FilmEditScreen />} />
        <Route path="/tools" element={<ToolsScreen />} />
        <Route path="/stats" element={<StatsScreen />} />
        <Route path="/export" element={<ExportScreen />} />
        <Route path="/settings" element={<SettingsScreen />} />
        <Route path="*" element={<RollsScreen />} />
      </Routes>

      {!hideTabBar && (
        <nav className="tabbar">
          {TABS.map(({ to, Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              className={({ isActive }) => (isActive ? 'active' : '')}
            >
              <Icon size={21} />
              {label}
            </NavLink>
          ))}
        </nav>
      )}
    </div>
  );
}
