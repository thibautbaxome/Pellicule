/**
 * Banque de boîtiers 135.
 *
 * Sert de référence à la saisie : on cherche son appareil, on le sélectionne,
 * et la monture, la plage de vitesses et l'objectif fixe sont préremplis.
 * Rien n'est enregistré en base tant que l'utilisateur ne valide pas — la
 * liste de matériel ne contient donc que ce qu'il possède réellement.
 *
 * La plage de vitesses est ce qui compte le plus pour l'assistant de prise de
 * vue : c'est elle qui permet de dire « ce réglage sort de ce que ton boîtier
 * sait faire ». Elle n'est renseignée que lorsqu'elle est établie ; dans le
 * doute, le champ est laissé vide plutôt que deviné.
 */

export type CameraType = 'slr' | 'rangefinder' | 'compact' | 'viewfinder';

export const CAMERA_TYPE_LABELS: Record<CameraType, string> = {
  slr: 'Reflex',
  rangefinder: 'Télémétrique',
  compact: 'Compact',
  viewfinder: 'Viseur direct',
};

export interface CatalogCamera {
  brand: string;
  model: string;
  /** Monture d'objectif. `Fixe` pour un objectif solidaire du boîtier. */
  mount: string;
  type: CameraType;
  /** Années de commercialisation, à titre indicatif. */
  years?: string;
  /** Vitesse la plus rapide, en libellé canonique. */
  shutterFastest?: string;
  /** Vitesse mécanique la plus lente hors pose B. */
  shutterSlowest?: string;
  /** Objectif solidaire : focale en mm et ouverture maximale. */
  fixedLens?: { focal: number; maxAperture: number };
  notes?: string;
}

/** Monture conventionnelle des appareils à objectif non interchangeable. */
export const FIXED_MOUNT = 'Fixe';

export const CAMERA_CATALOG: CatalogCamera[] = [
  // ---------------------------------------------------------------------------
  // Minolta
  // ---------------------------------------------------------------------------
  { brand: 'Minolta', model: 'SR-T 101', mount: 'Minolta SR', type: 'slr', years: '1966–1975', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Minolta', model: 'SR-T 100', mount: 'Minolta SR', type: 'slr', years: '1971–1976', shutterFastest: '1/500', shutterSlowest: '1s' },
  { brand: 'Minolta', model: 'SR-T Super', mount: 'Minolta SR', type: 'slr', years: '1973–1976', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Minolta', model: 'XE-1', mount: 'Minolta SR', type: 'slr', years: '1974–1977', shutterFastest: '1/1000', shutterSlowest: '4s' },
  { brand: 'Minolta', model: 'XD-7', mount: 'Minolta SR', type: 'slr', years: '1977–1984', shutterFastest: '1/1000', shutterSlowest: '1s', notes: 'Premier reflex à double priorité. Vendu XD-11 aux États-Unis.' },
  { brand: 'Minolta', model: 'X-300', mount: 'Minolta SR', type: 'slr', years: '1984–1990', shutterFastest: '1/1000', shutterSlowest: '1s', notes: 'Priorité ouverture et manuel. Vendu X-370 aux États-Unis.' },
  { brand: 'Minolta', model: 'X-300s', mount: 'Minolta SR', type: 'slr', years: '1990–1999', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Minolta', model: 'X-500', mount: 'Minolta SR', type: 'slr', years: '1983–1990', shutterFastest: '1/1000', shutterSlowest: '4s', notes: 'Vendu X-570 aux États-Unis.' },
  { brand: 'Minolta', model: 'X-700', mount: 'Minolta SR', type: 'slr', years: '1981–1999', shutterFastest: '1/1000', shutterSlowest: '4s', notes: 'Le haut de gamme grand public de Minolta, mode programme inclus.' },
  { brand: 'Minolta', model: 'X-7A', mount: 'Minolta SR', type: 'slr', years: '1980–1985', shutterFastest: '1/1000', shutterSlowest: '4s' },
  { brand: 'Minolta', model: 'XG-1', mount: 'Minolta SR', type: 'slr', years: '1979–1982', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Minolta', model: 'XG-9', mount: 'Minolta SR', type: 'slr', years: '1979–1981', shutterFastest: '1/1000', shutterSlowest: '4s' },
  { brand: 'Minolta', model: 'XG-M', mount: 'Minolta SR', type: 'slr', years: '1981–1983', shutterFastest: '1/1000', shutterSlowest: '4s' },
  { brand: 'Minolta', model: 'Dynax 7000 (Maxxum 7000)', mount: 'Minolta A', type: 'slr', years: '1985–1988', shutterFastest: '1/2000', shutterSlowest: '30s', notes: 'Premier reflex autofocus à moteur intégré.' },
  { brand: 'Minolta', model: 'Dynax 9000', mount: 'Minolta A', type: 'slr', years: '1985–1989', shutterFastest: '1/4000', shutterSlowest: '30s' },
  { brand: 'Minolta', model: 'Dynax 7', mount: 'Minolta A', type: 'slr', years: '2000–2004', shutterFastest: '1/8000', shutterSlowest: '30s' },
  { brand: 'Minolta', model: 'Dynax 9', mount: 'Minolta A', type: 'slr', years: '1998–2003', shutterFastest: '1/12000', shutterSlowest: '30s' },
  { brand: 'Minolta', model: 'CLE', mount: 'Leica M', type: 'rangefinder', years: '1980–1985', shutterFastest: '1/1000', shutterSlowest: '4s' },
  { brand: 'Minolta', model: 'Hi-Matic 7s', mount: FIXED_MOUNT, type: 'rangefinder', years: '1966–1970', shutterFastest: '1/500', shutterSlowest: '1/4', fixedLens: { focal: 45, maxAperture: 1.8 } },
  { brand: 'Minolta', model: 'Hi-Matic AF2', mount: FIXED_MOUNT, type: 'compact', years: '1981', fixedLens: { focal: 38, maxAperture: 2.8 } },
  { brand: 'Minolta', model: 'TC-1', mount: FIXED_MOUNT, type: 'compact', years: '1996–2005', shutterFastest: '1/750', fixedLens: { focal: 28, maxAperture: 3.5 }, notes: 'Compact de luxe en titane, diaphragme à ouvertures circulaires.' },

  // ---------------------------------------------------------------------------
  // Canon
  // ---------------------------------------------------------------------------
  { brand: 'Canon', model: 'AE-1', mount: 'Canon FD', type: 'slr', years: '1976–1984', shutterFastest: '1/1000', shutterSlowest: '2s', notes: 'Priorité vitesse. Le reflex le plus vendu de son époque.' },
  { brand: 'Canon', model: 'AE-1 Program', mount: 'Canon FD', type: 'slr', years: '1981–1987', shutterFastest: '1/1000', shutterSlowest: '2s' },
  { brand: 'Canon', model: 'A-1', mount: 'Canon FD', type: 'slr', years: '1978–1985', shutterFastest: '1/1000', shutterSlowest: '30s', notes: 'Tous les modes d’exposition, affichage LED rouge dans le viseur.' },
  { brand: 'Canon', model: 'AV-1', mount: 'Canon FD', type: 'slr', years: '1979–1984', shutterFastest: '1/1000', shutterSlowest: '2s' },
  { brand: 'Canon', model: 'AT-1', mount: 'Canon FD', type: 'slr', years: '1977–1985', shutterFastest: '1/1000', shutterSlowest: '2s' },
  { brand: 'Canon', model: 'AL-1', mount: 'Canon FD', type: 'slr', years: '1982–1985', shutterFastest: '1/1000', shutterSlowest: '2s' },
  { brand: 'Canon', model: 'FTb', mount: 'Canon FD', type: 'slr', years: '1971–1976', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Canon', model: 'F-1', mount: 'Canon FD', type: 'slr', years: '1971–1976', shutterFastest: '1/2000', shutterSlowest: '1s' },
  { brand: 'Canon', model: 'New F-1', mount: 'Canon FD', type: 'slr', years: '1981–1992', shutterFastest: '1/2000', shutterSlowest: '8s' },
  { brand: 'Canon', model: 'T70', mount: 'Canon FD', type: 'slr', years: '1984–1986', shutterFastest: '1/1000', shutterSlowest: '2s' },
  { brand: 'Canon', model: 'T90', mount: 'Canon FD', type: 'slr', years: '1986–1991', shutterFastest: '1/4000', shutterSlowest: '30s', notes: 'Dessiné par Luigi Colani, ancêtre du dessin des EOS.' },
  { brand: 'Canon', model: 'EOS 650', mount: 'Canon EF', type: 'slr', years: '1987–1989', shutterFastest: '1/2000', shutterSlowest: '30s', notes: 'Premier boîtier de la monture EF.' },
  { brand: 'Canon', model: 'EOS-1', mount: 'Canon EF', type: 'slr', years: '1989–1994', shutterFastest: '1/8000', shutterSlowest: '30s' },
  { brand: 'Canon', model: 'EOS-1N', mount: 'Canon EF', type: 'slr', years: '1994–2000', shutterFastest: '1/8000', shutterSlowest: '30s' },
  { brand: 'Canon', model: 'EOS-1V', mount: 'Canon EF', type: 'slr', years: '2000–2018', shutterFastest: '1/8000', shutterSlowest: '30s', notes: 'Le dernier reflex argentique professionnel de Canon.' },
  { brand: 'Canon', model: 'EOS 3', mount: 'Canon EF', type: 'slr', years: '1998–2007', shutterFastest: '1/8000', shutterSlowest: '30s', notes: 'Mise au point commandée par le regard.' },
  { brand: 'Canon', model: 'EOS 5 (A2E)', mount: 'Canon EF', type: 'slr', years: '1992–1998', shutterFastest: '1/8000', shutterSlowest: '30s' },
  { brand: 'Canon', model: 'EOS 300', mount: 'Canon EF', type: 'slr', years: '1999–2002', shutterFastest: '1/2000', shutterSlowest: '30s' },
  { brand: 'Canon', model: 'EOS 300V', mount: 'Canon EF', type: 'slr', years: '2002–2004', shutterFastest: '1/4000', shutterSlowest: '30s' },
  { brand: 'Canon', model: 'EOS 500N', mount: 'Canon EF', type: 'slr', years: '1996–1999', shutterFastest: '1/2000', shutterSlowest: '30s' },
  { brand: 'Canon', model: 'Canonet QL17 GIII', mount: FIXED_MOUNT, type: 'rangefinder', years: '1972–1982', shutterFastest: '1/500', shutterSlowest: '4s', fixedLens: { focal: 40, maxAperture: 1.7 }, notes: 'Priorité vitesse, très compact. Une référence du télémétrique abordable.' },
  { brand: 'Canon', model: 'Canonet 28', mount: FIXED_MOUNT, type: 'rangefinder', years: '1971–1976', shutterFastest: '1/600', fixedLens: { focal: 40, maxAperture: 2.8 } },
  { brand: 'Canon', model: 'Sure Shot AF35M (Autoboy)', mount: FIXED_MOUNT, type: 'compact', years: '1979–1983', fixedLens: { focal: 38, maxAperture: 2.8 } },
  { brand: 'Canon', model: 'Prima Mini II (Sure Shot)', mount: FIXED_MOUNT, type: 'compact', years: '1993', fixedLens: { focal: 32, maxAperture: 3.5 } },
  { brand: 'Canon', model: 'P (Populaire)', mount: 'Leica M39', type: 'rangefinder', years: '1959–1961', shutterFastest: '1/1000', shutterSlowest: '1s' },

  // ---------------------------------------------------------------------------
  // Nikon
  // ---------------------------------------------------------------------------
  { brand: 'Nikon', model: 'F', mount: 'Nikon F', type: 'slr', years: '1959–1973', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Nikon', model: 'F2', mount: 'Nikon F', type: 'slr', years: '1971–1980', shutterFastest: '1/2000', shutterSlowest: '10s' },
  { brand: 'Nikon', model: 'F3', mount: 'Nikon F', type: 'slr', years: '1980–2001', shutterFastest: '1/2000', shutterSlowest: '8s' },
  { brand: 'Nikon', model: 'F4', mount: 'Nikon F', type: 'slr', years: '1988–1997', shutterFastest: '1/8000', shutterSlowest: '30s' },
  { brand: 'Nikon', model: 'F5', mount: 'Nikon F', type: 'slr', years: '1996–2004', shutterFastest: '1/8000', shutterSlowest: '30s' },
  { brand: 'Nikon', model: 'F6', mount: 'Nikon F', type: 'slr', years: '2004–2020', shutterFastest: '1/8000', shutterSlowest: '30s', notes: 'Le dernier reflex argentique produit par Nikon.' },
  { brand: 'Nikon', model: 'FM', mount: 'Nikon F', type: 'slr', years: '1977–1982', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Nikon', model: 'FM2n', mount: 'Nikon F', type: 'slr', years: '1984–2001', shutterFastest: '1/4000', shutterSlowest: '1s', notes: 'Entièrement mécanique, synchro flash au 1/250.' },
  { brand: 'Nikon', model: 'FM3A', mount: 'Nikon F', type: 'slr', years: '2001–2006', shutterFastest: '1/4000', shutterSlowest: '1s', notes: 'Obturateur hybride : mécanique sur toute la plage, plus priorité ouverture.' },
  { brand: 'Nikon', model: 'FE', mount: 'Nikon F', type: 'slr', years: '1978–1983', shutterFastest: '1/1000', shutterSlowest: '8s' },
  { brand: 'Nikon', model: 'FE2', mount: 'Nikon F', type: 'slr', years: '1983–1987', shutterFastest: '1/4000', shutterSlowest: '8s' },
  { brand: 'Nikon', model: 'FA', mount: 'Nikon F', type: 'slr', years: '1983–1988', shutterFastest: '1/4000', shutterSlowest: '1s', notes: 'Première mesure matricielle.' },
  { brand: 'Nikon', model: 'EM', mount: 'Nikon F', type: 'slr', years: '1979–1984', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Nikon', model: 'FG', mount: 'Nikon F', type: 'slr', years: '1982–1986', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Nikon', model: 'F301 (N2000)', mount: 'Nikon F', type: 'slr', years: '1985–1987', shutterFastest: '1/2000', shutterSlowest: '1s' },
  { brand: 'Nikon', model: 'F801 (N8008)', mount: 'Nikon F', type: 'slr', years: '1988–1991', shutterFastest: '1/8000', shutterSlowest: '30s' },
  { brand: 'Nikon', model: 'F90X (N90s)', mount: 'Nikon F', type: 'slr', years: '1994–2001', shutterFastest: '1/8000', shutterSlowest: '30s' },
  { brand: 'Nikon', model: 'F100', mount: 'Nikon F', type: 'slr', years: '1999–2006', shutterFastest: '1/8000', shutterSlowest: '30s' },
  { brand: 'Nikon', model: 'F80 (N80)', mount: 'Nikon F', type: 'slr', years: '2000–2006', shutterFastest: '1/4000', shutterSlowest: '30s' },
  { brand: 'Nikon', model: 'F65 (N65)', mount: 'Nikon F', type: 'slr', years: '2001–2006', shutterFastest: '1/2000', shutterSlowest: '30s' },
  { brand: 'Nikon', model: 'L35AF (Pikaichi)', mount: FIXED_MOUNT, type: 'compact', years: '1983–1986', fixedLens: { focal: 35, maxAperture: 2.8 } },
  { brand: 'Nikon', model: '35Ti', mount: FIXED_MOUNT, type: 'compact', years: '1993–1998', shutterFastest: '1/500', fixedLens: { focal: 35, maxAperture: 2.8 }, notes: 'Cadrans à aiguilles sur le capot, boîtier titane.' },
  { brand: 'Nikon', model: '28Ti', mount: FIXED_MOUNT, type: 'compact', years: '1994–2000', shutterFastest: '1/500', fixedLens: { focal: 28, maxAperture: 2.8 } },
  { brand: 'Nikon', model: 'Nikonos V', mount: 'Nikonos', type: 'viewfinder', years: '1984–2001', shutterFastest: '1/1000', shutterSlowest: '1/30', notes: 'Étanche sans caisson jusqu’à 50 mètres.' },

  // ---------------------------------------------------------------------------
  // Pentax
  // ---------------------------------------------------------------------------
  { brand: 'Pentax', model: 'Spotmatic SP', mount: 'M42', type: 'slr', years: '1964–1973', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Pentax', model: 'Spotmatic F', mount: 'M42', type: 'slr', years: '1973–1976', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Pentax', model: 'K1000', mount: 'Pentax K', type: 'slr', years: '1976–1997', shutterFastest: '1/1000', shutterSlowest: '1s', notes: 'Tout mécanique, sans automatisme. Le boîtier d’apprentissage par excellence.' },
  { brand: 'Pentax', model: 'KX', mount: 'Pentax K', type: 'slr', years: '1975–1977', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Pentax', model: 'MX', mount: 'Pentax K', type: 'slr', years: '1976–1985', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Pentax', model: 'ME Super', mount: 'Pentax K', type: 'slr', years: '1979–1984', shutterFastest: '1/2000', shutterSlowest: '4s' },
  { brand: 'Pentax', model: 'MG', mount: 'Pentax K', type: 'slr', years: '1982–1985', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Pentax', model: 'Super A (Super Program)', mount: 'Pentax K', type: 'slr', years: '1983–1987', shutterFastest: '1/2000', shutterSlowest: '15s' },
  { brand: 'Pentax', model: 'LX', mount: 'Pentax K', type: 'slr', years: '1980–2001', shutterFastest: '1/2000', shutterSlowest: '125s', notes: 'Boîtier professionnel tropicalisé, mesure à la surface du film.' },
  { brand: 'Pentax', model: 'P30', mount: 'Pentax K', type: 'slr', years: '1985–1988', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Pentax', model: 'MZ-5N (ZX-5N)', mount: 'Pentax KAF', type: 'slr', years: '1997–2001', shutterFastest: '1/2000', shutterSlowest: '30s' },
  { brand: 'Pentax', model: 'MZ-3', mount: 'Pentax KAF', type: 'slr', years: '1997–2001', shutterFastest: '1/4000', shutterSlowest: '30s' },
  { brand: 'Pentax', model: 'Espio Mini (UC-1)', mount: FIXED_MOUNT, type: 'compact', years: '1994–2000', fixedLens: { focal: 32, maxAperture: 3.5 } },
  { brand: 'Pentax', model: '17', mount: FIXED_MOUNT, type: 'compact', years: '2024–', shutterFastest: '1/350', fixedLens: { focal: 25, maxAperture: 3.5 }, notes: 'Demi-format : 72 vues sur un film de 36 poses.' },

  // ---------------------------------------------------------------------------
  // Olympus
  // ---------------------------------------------------------------------------
  { brand: 'Olympus', model: 'OM-1', mount: 'Olympus OM', type: 'slr', years: '1972–1979', shutterFastest: '1/1000', shutterSlowest: '1s', notes: 'Le reflex qui a lancé la mode des boîtiers compacts.' },
  { brand: 'Olympus', model: 'OM-2n', mount: 'Olympus OM', type: 'slr', years: '1979–1984', shutterFastest: '1/1000', shutterSlowest: '120s', notes: 'Mesure à la surface du film, y compris pendant la pose.' },
  { brand: 'Olympus', model: 'OM-4Ti', mount: 'Olympus OM', type: 'slr', years: '1986–2002', shutterFastest: '1/2000', shutterSlowest: '240s', notes: 'Mesure spot multiple avec moyenne.' },
  { brand: 'Olympus', model: 'OM-10', mount: 'Olympus OM', type: 'slr', years: '1979–1987', shutterFastest: '1/1000', shutterSlowest: '2s', notes: 'Mode manuel seulement avec l’adaptateur dédié.' },
  { brand: 'Olympus', model: 'OM-20 (OM-G)', mount: 'Olympus OM', type: 'slr', years: '1983–1987', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Olympus', model: 'OM-40 (OM-PC)', mount: 'Olympus OM', type: 'slr', years: '1985–1987', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Olympus', model: 'Trip 35', mount: FIXED_MOUNT, type: 'viewfinder', years: '1967–1984', fixedLens: { focal: 40, maxAperture: 2.8 }, notes: 'Cellule au sélénium, sans pile. Deux vitesses seulement.' },
  { brand: 'Olympus', model: 'XA', mount: FIXED_MOUNT, type: 'rangefinder', years: '1979–1985', shutterFastest: '1/500', shutterSlowest: '10s', fixedLens: { focal: 35, maxAperture: 2.8 }, notes: 'Télémétrique de poche à capot coulissant.' },
  { brand: 'Olympus', model: 'XA2', mount: FIXED_MOUNT, type: 'compact', years: '1980–1986', fixedLens: { focal: 35, maxAperture: 3.5 } },
  { brand: 'Olympus', model: 'mju II (Stylus Epic)', mount: FIXED_MOUNT, type: 'compact', years: '1997–2004', shutterFastest: '1/1000', fixedLens: { focal: 35, maxAperture: 2.8 }, notes: 'Étanche aux projections, objectif très lumineux pour un compact.' },
  { brand: 'Olympus', model: 'mju (Stylus)', mount: FIXED_MOUNT, type: 'compact', years: '1991–1996', fixedLens: { focal: 35, maxAperture: 3.5 } },
  { brand: 'Olympus', model: '35 RC', mount: FIXED_MOUNT, type: 'rangefinder', years: '1970–1977', shutterFastest: '1/500', shutterSlowest: '1/15', fixedLens: { focal: 42, maxAperture: 2.8 } },
  { brand: 'Olympus', model: '35 SP', mount: FIXED_MOUNT, type: 'rangefinder', years: '1969–1976', shutterFastest: '1/500', shutterSlowest: '1s', fixedLens: { focal: 42, maxAperture: 1.7 } },

  // ---------------------------------------------------------------------------
  // Leica
  // ---------------------------------------------------------------------------
  { brand: 'Leica', model: 'M3', mount: 'Leica M', type: 'rangefinder', years: '1954–1966', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Leica', model: 'M2', mount: 'Leica M', type: 'rangefinder', years: '1957–1968', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Leica', model: 'M4', mount: 'Leica M', type: 'rangefinder', years: '1966–1975', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Leica', model: 'M6', mount: 'Leica M', type: 'rangefinder', years: '1984–2002', shutterFastest: '1/1000', shutterSlowest: '1s', notes: 'Cellule à diodes dans le viseur, boîtier entièrement mécanique.' },
  { brand: 'Leica', model: 'M7', mount: 'Leica M', type: 'rangefinder', years: '2002–2018', shutterFastest: '1/1000', shutterSlowest: '32s' },
  { brand: 'Leica', model: 'MP', mount: 'Leica M', type: 'rangefinder', years: '2003–', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Leica', model: 'M-A', mount: 'Leica M', type: 'rangefinder', years: '2014–', shutterFastest: '1/1000', shutterSlowest: '1s', notes: 'Aucun posemètre, aucune électronique.' },
  { brand: 'Leica', model: 'R6.2', mount: 'Leica R', type: 'slr', years: '1992–2002', shutterFastest: '1/2000', shutterSlowest: '1s' },
  { brand: 'Leica', model: 'CL', mount: 'Leica M', type: 'rangefinder', years: '1973–1976', shutterFastest: '1/1000', shutterSlowest: '1/2' },
  { brand: 'Leica', model: 'Minilux', mount: FIXED_MOUNT, type: 'compact', years: '1995–2000', shutterFastest: '1/400', fixedLens: { focal: 40, maxAperture: 2.4 } },

  // ---------------------------------------------------------------------------
  // Contax et Yashica
  // ---------------------------------------------------------------------------
  { brand: 'Contax', model: 'RTS', mount: 'Contax/Yashica', type: 'slr', years: '1975–1982', shutterFastest: '1/2000', shutterSlowest: '4s' },
  { brand: 'Contax', model: '139 Quartz', mount: 'Contax/Yashica', type: 'slr', years: '1979–1987', shutterFastest: '1/1000', shutterSlowest: '11s' },
  { brand: 'Contax', model: 'S2', mount: 'Contax/Yashica', type: 'slr', years: '1992–1998', shutterFastest: '1/4000', shutterSlowest: '1s', notes: 'Mécanique, mesure spot uniquement.' },
  { brand: 'Contax', model: 'Aria', mount: 'Contax/Yashica', type: 'slr', years: '1998–2005', shutterFastest: '1/4000', shutterSlowest: '16s' },
  { brand: 'Contax', model: 'G2', mount: 'Contax G', type: 'rangefinder', years: '1996–2005', shutterFastest: '1/6000', shutterSlowest: '16s', notes: 'Télémétrique autofocus, objectifs Zeiss interchangeables.' },
  { brand: 'Contax', model: 'T2', mount: FIXED_MOUNT, type: 'compact', years: '1990–1998', shutterFastest: '1/500', fixedLens: { focal: 38, maxAperture: 2.8 }, notes: 'Sonnar Zeiss, boîtier titane. Priorité ouverture disponible.' },
  { brand: 'Contax', model: 'T3', mount: FIXED_MOUNT, type: 'compact', years: '2001–2005', shutterFastest: '1/1200', fixedLens: { focal: 35, maxAperture: 2.8 } },
  { brand: 'Yashica', model: 'FX-3 Super 2000', mount: 'Contax/Yashica', type: 'slr', years: '1986–2002', shutterFastest: '1/2000', shutterSlowest: '1s', notes: 'Mécanique et léger, accepte les objectifs Zeiss en monture C/Y.' },
  { brand: 'Yashica', model: 'Electro 35 GSN', mount: FIXED_MOUNT, type: 'rangefinder', years: '1973–1977', shutterFastest: '1/500', shutterSlowest: '30s', fixedLens: { focal: 45, maxAperture: 1.7 }, notes: 'Priorité ouverture, obturateur électronique très silencieux.' },
  { brand: 'Yashica', model: 'T4 (T5)', mount: FIXED_MOUNT, type: 'compact', years: '1990–1997', fixedLens: { focal: 35, maxAperture: 3.5 }, notes: 'Objectif Zeiss Tessar sur un boîtier de compact ordinaire.' },

  // ---------------------------------------------------------------------------
  // Autres marques japonaises
  // ---------------------------------------------------------------------------
  { brand: 'Konica', model: 'Autoreflex T3', mount: 'Konica AR', type: 'slr', years: '1973–1976', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Konica', model: 'Hexar AF', mount: FIXED_MOUNT, type: 'compact', years: '1993–2003', shutterFastest: '1/250', shutterSlowest: '30s', fixedLens: { focal: 35, maxAperture: 2 }, notes: 'Mode silencieux redoutablement discret.' },
  { brand: 'Konica', model: 'C35', mount: FIXED_MOUNT, type: 'rangefinder', years: '1968–1971', fixedLens: { focal: 38, maxAperture: 2.8 } },
  { brand: 'Ricoh', model: 'GR1v', mount: FIXED_MOUNT, type: 'compact', years: '2001–2005', shutterFastest: '1/500', shutterSlowest: '2s', fixedLens: { focal: 28, maxAperture: 2.8 }, notes: 'Ancêtre direct des GR numériques.' },
  { brand: 'Ricoh', model: 'GR1s', mount: FIXED_MOUNT, type: 'compact', years: '1998–2001', shutterFastest: '1/500', fixedLens: { focal: 28, maxAperture: 2.8 } },
  { brand: 'Ricoh', model: 'XR-7', mount: 'Pentax K', type: 'slr', years: '1981–1984', shutterFastest: '1/1000', shutterSlowest: '16s' },
  { brand: 'Fujifilm', model: 'Klasse W', mount: FIXED_MOUNT, type: 'compact', years: '2007–2013', shutterFastest: '1/500', fixedLens: { focal: 28, maxAperture: 2.8 } },
  { brand: 'Fujifilm', model: 'Natura Classica', mount: FIXED_MOUNT, type: 'compact', years: '2006–2011', fixedLens: { focal: 28, maxAperture: 2.8 } },
  { brand: 'Chinon', model: 'CE-4', mount: 'M42', type: 'slr', years: '1979–1982', shutterFastest: '1/1000', shutterSlowest: '4s' },
  { brand: 'Mamiya', model: 'ZE', mount: 'Mamiya ZE', type: 'slr', years: '1980–1983', shutterFastest: '1/1000', shutterSlowest: '4s' },
  { brand: 'Topcon', model: 'RE Super', mount: 'Exakta', type: 'slr', years: '1963–1971', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Miranda', model: 'Sensorex', mount: 'Miranda', type: 'slr', years: '1967–1972', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Petri', model: '7S', mount: FIXED_MOUNT, type: 'rangefinder', years: '1963–1970', fixedLens: { focal: 45, maxAperture: 1.8 } },
  { brand: 'Cosina', model: 'CT-1G', mount: 'Pentax K', type: 'slr', years: '1980s', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Vivitar', model: 'V3800N', mount: 'Pentax K', type: 'slr', years: '1990s–2000s', shutterFastest: '1/2000', shutterSlowest: '1s' },

  // ---------------------------------------------------------------------------
  // Europe
  // ---------------------------------------------------------------------------
  { brand: 'Voigtländer', model: 'Bessa R2A', mount: 'Leica M', type: 'rangefinder', years: '2004–2007', shutterFastest: '1/2000', shutterSlowest: '1s' },
  { brand: 'Voigtländer', model: 'Bessa R', mount: 'Leica M39', type: 'rangefinder', years: '2000–2002', shutterFastest: '1/2000', shutterSlowest: '1s' },
  { brand: 'Rollei', model: '35', mount: FIXED_MOUNT, type: 'viewfinder', years: '1966–1974', shutterFastest: '1/500', shutterSlowest: '1/2', fixedLens: { focal: 40, maxAperture: 3.5 }, notes: 'Objectif rétractable ; l’un des plus petits 24×36 jamais produits.' },
  { brand: 'Rollei', model: '35S', mount: FIXED_MOUNT, type: 'viewfinder', years: '1974–1980', shutterFastest: '1/500', shutterSlowest: '1/2', fixedLens: { focal: 40, maxAperture: 2.8 } },
  { brand: 'Rollei', model: '35AF', mount: FIXED_MOUNT, type: 'compact', years: '2024–', shutterFastest: '1/500', fixedLens: { focal: 35, maxAperture: 2.8 } },
  { brand: 'Praktica', model: 'MTL 5B', mount: 'M42', type: 'slr', years: '1985–1989', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Praktica', model: 'LTL3', mount: 'M42', type: 'slr', years: '1975–1978', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'Exakta', model: 'Varex IIa', mount: 'Exakta', type: 'slr', years: '1956–1963', shutterFastest: '1/1000', shutterSlowest: '12s' },
  { brand: 'Agfa', model: 'Silette', mount: FIXED_MOUNT, type: 'viewfinder', years: '1953–1974', fixedLens: { focal: 45, maxAperture: 2.8 } },
  { brand: 'Werra', model: 'Werra 1', mount: FIXED_MOUNT, type: 'viewfinder', years: '1954–1966', shutterFastest: '1/250', fixedLens: { focal: 50, maxAperture: 2.8 } },

  // ---------------------------------------------------------------------------
  // Union soviétique
  // ---------------------------------------------------------------------------
  { brand: 'Zenit', model: 'E', mount: 'M42', type: 'slr', years: '1965–1986', shutterFastest: '1/500', shutterSlowest: '1/30' },
  { brand: 'Zenit', model: '12XP', mount: 'M42', type: 'slr', years: '1983–1992', shutterFastest: '1/500', shutterSlowest: '1/30' },
  { brand: 'Zorki', model: '4', mount: 'Leica M39', type: 'rangefinder', years: '1956–1973', shutterFastest: '1/1000', shutterSlowest: '1s' },
  { brand: 'FED', model: '5', mount: 'Leica M39', type: 'rangefinder', years: '1977–1990', shutterFastest: '1/500', shutterSlowest: '1s' },
  { brand: 'Kiev', model: '4', mount: 'Contax RF', type: 'rangefinder', years: '1957–1980', shutterFastest: '1/1250', shutterSlowest: '1/2' },
  { brand: 'Lomo', model: 'LC-A', mount: FIXED_MOUNT, type: 'compact', years: '1984–2005', fixedLens: { focal: 32, maxAperture: 2.8 }, notes: 'Vignetage et saturation caractéristiques, à l’origine du mouvement lomographique.' },
  { brand: 'Lomo', model: 'Smena 8M', mount: FIXED_MOUNT, type: 'viewfinder', years: '1970–1995', shutterFastest: '1/250', shutterSlowest: '1/15', fixedLens: { focal: 40, maxAperture: 4 } },

  // ---------------------------------------------------------------------------
  // Lomography et jouets
  // ---------------------------------------------------------------------------
  { brand: 'Lomography', model: 'LC-A+', mount: FIXED_MOUNT, type: 'compact', years: '2006–', fixedLens: { focal: 32, maxAperture: 2.8 } },
  { brand: 'Lomography', model: 'Diana Mini', mount: FIXED_MOUNT, type: 'viewfinder', years: '2009–', fixedLens: { focal: 24, maxAperture: 8 } },
  { brand: 'Lomography', model: 'Sprocket Rocket', mount: FIXED_MOUNT, type: 'viewfinder', years: '2010–', fixedLens: { focal: 30, maxAperture: 10.8 }, notes: 'Panoramique exposant jusqu’aux perforations.' },
  { brand: 'Holga', model: '135BC', mount: FIXED_MOUNT, type: 'viewfinder', years: '2000s', shutterFastest: '1/100', fixedLens: { focal: 47, maxAperture: 8 } },
  { brand: 'Ilford', model: 'Sprite 35-II', mount: FIXED_MOUNT, type: 'viewfinder', years: '2020–', shutterFastest: '1/120', fixedLens: { focal: 31, maxAperture: 9 } },
  { brand: 'Kodak', model: 'M35', mount: FIXED_MOUNT, type: 'viewfinder', years: '2019–', shutterFastest: '1/120', fixedLens: { focal: 31, maxAperture: 10 } },
];

/** Montures distinctes présentes au catalogue, triées, pour filtrer les objectifs. */
export const CAMERA_MOUNTS: string[] = [
  ...new Set(CAMERA_CATALOG.map((camera) => camera.mount)),
]
  .filter((mount) => mount !== FIXED_MOUNT)
  .sort((a, b) => a.localeCompare(b, 'fr'));

/**
 * Recherche tolérante : insensible à la casse et aux accents, et acceptant les
 * mots dans le désordre, pour que « minolta 300 » trouve le X-300.
 */
export function searchCameras(query: string, limit = 24): CatalogCamera[] {
  const terms = normalise(query).split(/\s+/).filter(Boolean);
  if (terms.length === 0) return [];

  return CAMERA_CATALOG.filter((camera) => {
    const haystack = normalise(`${camera.brand} ${camera.model} ${camera.mount}`);
    return terms.every((term) => haystack.includes(term));
  }).slice(0, limit);
}

export function normalise(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}
