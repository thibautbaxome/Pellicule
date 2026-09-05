/**
 * Point d'entrée unique des trois banques de matériel.
 *
 * Sert à `tools/export-catalogs.mjs`, qui les réunit en un module pour en
 * produire la projection JSON lue par la version native. Ce fichier n'est pas
 * utilisé par l'application elle-même, qui importe chaque catalogue
 * directement.
 */
export { FILM_CATALOG } from './filmCatalog';
export { CAMERA_CATALOG } from './cameraCatalog';
export { LENS_CATALOG } from './lensCatalog';
