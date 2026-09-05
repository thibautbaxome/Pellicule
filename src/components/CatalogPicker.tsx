import { useState, type ReactNode } from 'react';
import { IconClose, IconPlus } from './icons';

/**
 * Sélecteur de recherche dans une banque de matériel.
 *
 * Volontairement ouvert : on tape quelques lettres, on choisit, les champs du
 * formulaire se remplissent — et rien n'empêche ensuite de tout corriger à la
 * main. La banque accélère la saisie, elle ne la contraint pas ; un boîtier
 * absent du catalogue se déclare exactement comme avant.
 */
export function CatalogPicker<T>({
  label,
  placeholder,
  search,
  renderItem,
  onPick,
  emptyHint,
}: {
  label: string;
  placeholder: string;
  /** Rend les résultats correspondant à la saisie. */
  search: (query: string) => T[];
  renderItem: (item: T) => { title: string; meta?: string; badge?: string };
  onPick: (item: T) => void;
  /** Message affiché quand la recherche ne donne rien. */
  emptyHint?: ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');

  const results = open ? search(query) : [];

  if (!open) {
    return (
      <button
        type="button"
        className="btn btn--block"
        style={{ marginBottom: 20 }}
        onClick={() => setOpen(true)}
      >
        <IconPlus size={17} />
        {label}
      </button>
    );
  }

  return (
    <div className="picker">
      <div className="picker-head">
        <input
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={placeholder}
          autoFocus
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
        />
        <button
          type="button"
          className="btn btn--sm btn--ghost"
          onClick={() => {
            setOpen(false);
            setQuery('');
          }}
          aria-label="Fermer la recherche"
        >
          <IconClose size={17} />
        </button>
      </div>

      {results.length > 0 ? (
        <div className="picker-results">
          {results.map((item, index) => {
            const { title, meta, badge } = renderItem(item);
            return (
              <button
                key={`${title}-${index}`}
                type="button"
                className="picker-item"
                onClick={() => {
                  onPick(item);
                  setOpen(false);
                  setQuery('');
                }}
              >
                <span style={{ minWidth: 0 }}>
                  <span className="picker-title">{title}</span>
                  {meta && <span className="picker-meta">{meta}</span>}
                </span>
                {badge && <span className="badge">{badge}</span>}
              </button>
            );
          })}
        </div>
      ) : (
        <p className="field-hint" style={{ padding: '10px 2px 2px' }}>
          {query.trim()
            ? 'Aucun résultat. Saisissez les caractéristiques à la main ci-dessous.'
            : (emptyHint ?? 'Tapez une marque ou un modèle.')}
        </p>
      )}
    </div>
  );
}
