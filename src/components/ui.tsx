import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { IconChevronLeft } from './icons';

/**
 * En-tête d'écran.
 *
 * Le `eyebrow` reprend les mentions imprimées sur une boîte de film : en
 * capitales monospace largement interlettrées, il porte le contexte chiffré
 * (« 135 · 36 POSES · ISO 400 ») et laisse au titre toute sa place.
 */
export function ScreenHeader({
  eyebrow,
  title,
  subtitle,
  action,
  back,
}: {
  eyebrow?: ReactNode;
  title: string;
  subtitle?: ReactNode;
  action?: ReactNode;
  back?: { to: string; label?: string };
}) {
  return (
    <>
      {back && (
        <Link className="back-link" to={back.to}>
          <IconChevronLeft size={15} />
          {back.label ?? 'Retour'}
        </Link>
      )}
      <header className="screen-header">
        <div style={{ minWidth: 0 }}>
          {eyebrow && <p className="eyebrow">{eyebrow}</p>}
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
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: 12,
          }}
        >
          <p className="eyebrow" style={{ flex: 1 }}>
            {title}
          </p>
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
      {label && <label className="field-label">{label}</label>}
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
  icon: ReactNode;
  title: string;
  children?: ReactNode;
}) {
  return (
    <div className="empty">
      <span className="empty-icon">{icon}</span>
      <p className="empty-title">{title}</p>
      {children}
    </div>
  );
}

/**
 * Graduation à faire défiler horizontalement.
 *
 * Reprend le geste d'une bague d'objectif : les valeurs passent sous le pouce,
 * chaque cran est séparé d'un filet, et la valeur retenue se bloque en ambre.
 * On garde la graduation complète du boîtier plutôt que de l'enfermer dans un
 * menu déroulant — c'est plus rapide, et cela reste lisible au soleil.
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

/** Bande de perforations, utilisée comme séparateur thématique. */
export function Sprockets({ dim }: { dim?: boolean }) {
  return <div className={`sprockets${dim ? ' sprockets--dim' : ''}`} aria-hidden="true" />;
}
