/**
 * Jeu d'icônes de l'application.
 *
 * Dessinées à la main plutôt que reprises d'une bibliothèque : le vocabulaire
 * dont on a besoin — une amorce de pellicule, un diaphragme, une cellule — n'existe
 * nulle part, et les emoji donnaient à l'interface un air de brouillon.
 *
 * Toutes sont tracées sur une grille de 24, au trait, sans remplissage : elles
 * héritent donc de la couleur du texte et restent lisibles à 18 comme à 32 px.
 */

import type { SVGProps } from 'react';

type IconProps = SVGProps<SVGSVGElement> & { size?: number };

function Icon({ size = 22, children, ...props }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      {children}
    </svg>
  );
}

/** Amorce de pellicule 135, perforations comprises. */
export const IconFilm = (props: IconProps) => (
  <Icon {...props}>
    <rect x="2.5" y="5" width="19" height="14" rx="2" />
    <path d="M2.5 8.5h19M2.5 15.5h19" />
    <path d="M5.5 6.7v.1M8.5 6.7v.1M11.5 6.7v.1M14.5 6.7v.1M17.5 6.7v.1" strokeWidth={1.7} />
    <path d="M5.5 17.2v.1M8.5 17.2v.1M11.5 17.2v.1M14.5 17.2v.1M17.5 17.2v.1" strokeWidth={1.7} />
  </Icon>
);

/** Boîtier reflex vu de face. */
export const IconCamera = (props: IconProps) => (
  <Icon {...props}>
    <path d="M3 8.5a2 2 0 0 1 2-2h2.2l1.3-2h6l1.3 2H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
    <circle cx="12" cy="13" r="3.6" />
    <path d="M17.8 9.6v.1" strokeWidth={1.8} />
  </Icon>
);

/** Diaphragme à lamelles, pour tout ce qui touche au calcul d'exposition. */
export const IconAperture = (props: IconProps) => (
  <Icon {...props}>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 3v7.2M20.8 9.2l-6.9 2.2M17.4 20.1l-4.3-5.9M6.6 20.1l4.3-5.9M3.2 9.2l6.9 2.2" />
  </Icon>
);

/** Curseurs de réglage, préférés à l'engrenage : c'est bien d'ajustements qu'il s'agit. */
export const IconSliders = (props: IconProps) => (
  <Icon {...props}>
    <path d="M4 7h10M18 7h2M4 12h3M11 12h9M4 17h8M16 17h4" />
    <circle cx="16" cy="7" r="2" />
    <circle cx="9" cy="12" r="2" />
    <circle cx="14" cy="17" r="2" />
  </Icon>
);

export const IconPin = (props: IconProps) => (
  <Icon {...props}>
    <path d="M12 21s7-5.7 7-11a7 7 0 1 0-14 0c0 5.3 7 11 7 11z" />
    <circle cx="12" cy="10" r="2.5" />
  </Icon>
);

export const IconShutter = (props: IconProps) => (
  <Icon {...props}>
    <circle cx="12" cy="12" r="8.5" />
    <circle cx="12" cy="12" r="3" />
    <path d="M12 3.5v3M12 17.5v3M3.5 12h3M17.5 12h3" />
  </Icon>
);

export const IconPlus = (props: IconProps) => (
  <Icon {...props}>
    <path d="M12 5v14M5 12h14" strokeWidth={1.9} />
  </Icon>
);

export const IconChevronLeft = (props: IconProps) => (
  <Icon {...props}>
    <path d="M14.5 5 8 12l6.5 7" strokeWidth={1.9} />
  </Icon>
);

export const IconChevronRight = (props: IconProps) => (
  <Icon {...props}>
    <path d="M9.5 5 16 12l-6.5 7" strokeWidth={1.9} />
  </Icon>
);

export const IconTrash = (props: IconProps) => (
  <Icon {...props}>
    <path d="M4 7h16M9.5 7V4.8h5V7M6.5 7l.9 12.2a1.8 1.8 0 0 0 1.8 1.6h5.6a1.8 1.8 0 0 0 1.8-1.6L17.5 7" />
    <path d="M10.5 11v6M13.5 11v6" />
  </Icon>
);

export const IconExport = (props: IconProps) => (
  <Icon {...props}>
    <path d="M12 15.5V3.5M8.2 7.3 12 3.5l3.8 3.8" />
    <path d="M4.5 14.5v4a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2v-4" />
  </Icon>
);

export const IconFlask = (props: IconProps) => (
  <Icon {...props}>
    <path d="M9.5 3.5h5M10.5 3.5v6L5.6 18a2 2 0 0 0 1.7 3h9.4a2 2 0 0 0 1.7-3l-4.9-8.5v-6" />
    <path d="M7.9 14.5h8.2" />
  </Icon>
);

export const IconChart = (props: IconProps) => (
  <Icon {...props}>
    <path d="M4 20h16" />
    <path d="M7 20v-6M12 20V6M17 20v-9" strokeWidth={1.9} />
  </Icon>
);

export const IconCheck = (props: IconProps) => (
  <Icon {...props}>
    <path d="M4.5 12.8 9.5 18 19.5 6.5" strokeWidth={1.9} />
  </Icon>
);

export const IconClose = (props: IconProps) => (
  <Icon {...props}>
    <path d="M6 6l12 12M18 6 6 18" strokeWidth={1.9} />
  </Icon>
);

export const IconMap = (props: IconProps) => (
  <Icon {...props}>
    <path d="M9 4.5 3.5 6.8v12.7L9 17.2l6 2.3 5.5-2.3V4.5L15 6.8z" />
    <path d="M9 4.5v12.7M15 6.8v12.7" />
  </Icon>
);

export const IconLens = (props: IconProps) => (
  <Icon {...props}>
    <circle cx="12" cy="12" r="8.5" />
    <circle cx="12" cy="12" r="4.5" />
    <path d="M12 3.5v2M12 18.5v2M3.5 12h2M18.5 12h2" />
  </Icon>
);
