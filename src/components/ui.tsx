import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';

/** En-tête d'écran : titre, sous-titre facultatif et zone d'action à droite. */
export function ScreenHeader({
  title,
  subtitle,
  action,
  back,
}: {
  title: string;
  subtitle?: ReactNode;
  action?: ReactNode;
  /** Cible du lien de retour. Omis, aucun lien n'est affiché. */
  back?: { to: string; label?: string };
}) {
  return (
    <>
      {back && (
        <Link className="back-link" to={back.to}>
          ‹ {back.label ?? 'Retour'}
        </Link>
      )}
      <header className="screen-header">
        <div>
          <h1 className="screen-title">{title}</h1>
          {subtitle && <p className="screen-subtitle">{subtitle}</p>}
        </div>
        {action}
      </header>
    </>
  );
}

export function Section({
  title,
  children,
  action,
}: {
  title?: string;
  children: ReactNode;
  action?: ReactNode;
}) {
  return (
    <section className="section">
      {title && (
        <div className="card-row" style={{ marginBottom: 9 }}>
          <h2 className="section-title" style={{ margin: 0 }}>
            {title}
          </h2>
          {action}
        </div>
      )}
      {children}
    </section>
  );
}

export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="field">
      <label className="field-label">{label}</label>
      {children}
      {hint && <p className="field-hint">{hint}</p>}
    </div>
  );
}

export function EmptyState({
  icon,
  title,
  children,
}: {
  icon: string;
  title: string;
  children?: ReactNode;
}) {
  return (
    <div className="empty">
      <span className="empty-icon" aria-hidden="true">
        {icon}
      </span>
      <p style={{ fontWeight: 620, color: 'var(--text)', margin: '0 0 6px' }}>{title}</p>
      {children}
    </div>
  );
}

/**
 * Rangée de valeurs à faire défiler horizontalement. Sert aux graduations de
 * vitesse et d'ouverture : le geste reprend celui d'une bague d'objectif, et
 * toutes les valeurs restent atteignables d'un pouce.
 */
export function Dial<T extends string | number>({
  values,
  selected,
  onSelect,
  format,
  wide,
  label,
}: {
  values: readonly T[];
  selected: T | undefined;
  onSelect: (value: T) => void;
  format?: (value: T) => string;
  wide?: boolean;
  label: string;
}) {
  return (
    <div className="dial" role="group" aria-label={label}>
      {values.map((value) => (
        <button
          key={String(value)}
          type="button"
          className={`dial-item${wide ? ' dial-item--wide' : ''}`}
          aria-pressed={selected === value}
          onClick={() => onSelect(value)}
        >
          {format ? format(value) : String(value)}
        </button>
      ))}
    </div>
  );
}

/** Sélecteur segmenté, pour deux à cinq choix courts et exclusifs. */
export function Segmented<T extends string>({
  options,
  value,
  onChange,
  label,
}: {
  options: { value: T; label: string }[];
  value: T;
  onChange: (value: T) => void;
  label: string;
}) {
  return (
    <div className="segmented" role="group" aria-label={label}>
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          aria-pressed={value === option.value}
          onClick={() => onChange(option.value)}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}

export function KeyValue({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="kv">
      <span className="kv-key">{label}</span>
      <span className="kv-value">{children}</span>
    </div>
  );
}

export function Note({
  children,
  variant = 'info',
}: {
  children: ReactNode;
  variant?: 'info' | 'warning';
}) {
  return <div className={`note${variant === 'warning' ? ' note--warning' : ''}`}>{children}</div>;
}
