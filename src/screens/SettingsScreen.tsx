import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { db, updateSettings } from '../db/db';
import { useCameras, useLenses } from '../hooks/useData';
import { useSettings } from '../hooks/useSettings';
import { Field, KeyValue, Note, ScreenHeader, Section, Segmented } from '../components/ui';
import type { StopIncrement, ThemeMode } from '../db/types';
import {
  createBackup,
  restoreBackup,
  shareOrDownload,
  timestampedName,
  type BackupFile,
} from '../lib/backup';
import { formatBytes, requestPersistentStorage, storageEstimate } from '../lib/media';

export default function SettingsScreen() {
  const settings = useSettings();
  const cameras = useCameras();
  const lenses = useLenses();
  const fileInput = useRef<HTMLInputElement>(null);

  const [storage, setStorage] = useState<{ usage: number; quota: number } | null>(null);
  const [persistent, setPersistent] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string>();

  useEffect(() => {
    storageEstimate().then(setStorage);
    navigator.storage?.persisted?.().then(setPersistent);
  }, []);

  async function exportBackup(includePhotos: boolean) {
    setBusy(true);
    setMessage(undefined);
    try {
      const backup = await createBackup(includePhotos);
      await shareOrDownload(
        timestampedName('pellicule-sauvegarde', 'json'),
        JSON.stringify(backup, null, 2),
        'application/json',
      );
      setMessage('Sauvegarde générée.');
    } catch (error) {
      console.error('Sauvegarde impossible', error);
      setMessage('La sauvegarde a échoué.');
    } finally {
      setBusy(false);
    }
  }

  async function importBackup(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;

    const mode = window.confirm(
      'Remplacer intégralement les données actuelles ?\n\n' +
        'OK : tout est effacé puis remplacé par la sauvegarde.\n' +
        'Annuler : la sauvegarde est fusionnée avec les données existantes.',
    )
      ? 'replace'
      : 'merge';

    setBusy(true);
    setMessage(undefined);
    try {
      const backup = JSON.parse(await file.text()) as BackupFile;
      const report = await restoreBackup(backup, mode);
      setMessage(
        `Restauré : ${report.rolls} rouleaux, ${report.frames} vues, ` +
          `${report.cameras} boîtiers, ${report.attachments} photos.`,
      );
      setStorage(await storageEstimate());
    } catch (error) {
      console.error('Restauration impossible', error);
      setMessage(
        error instanceof Error ? error.message : 'Ce fichier n’a pas pu être restauré.',
      );
    } finally {
      setBusy(false);
    }
  }

  async function enablePersistence() {
    const granted = await requestPersistentStorage();
    setPersistent(granted);
    setMessage(
      granted
        ? 'Stockage rendu persistant.'
        : 'Le navigateur a refusé. Installez l’application sur l’écran d’accueil, puis réessayez.',
    );
  }

  async function eraseEverything() {
    if (
      !window.confirm(
        'Effacer toutes les données de l’application ? Rouleaux, vues, photos et ' +
          'matériel seront définitivement perdus. Pensez à faire une sauvegarde avant.',
      )
    ) {
      return;
    }
    if (!window.confirm('Dernière confirmation : cette suppression est irréversible.')) return;

    await db.delete();
    window.location.reload();
  }

  return (
    <main className="screen">
      <ScreenHeader title="Réglages" />

      <Section title="Apparence">
        <Field label="Thème">
          <Segmented
            label="Thème"
            value={settings.theme}
            onChange={(theme: ThemeMode) => updateSettings({ theme })}
            options={[
              { value: 'auto', label: 'Auto' },
              { value: 'light', label: 'Clair' },
              { value: 'dark', label: 'Sombre' },
              { value: 'darkroom', label: 'Labo' },
            ]}
          />
          <p className="field-hint">
            Le mode « Labo » n’affiche que du rouge sombre : utilisable en chambre noire sans
            voiler le papier ni perdre sa vision nocturne.
          </p>
        </Field>
      </Section>

      <Section title="Saisie">
        <Field
          label="Graduation des réglages"
          hint="Finesse des sélecteurs de vitesse et d’ouverture. Les boîtiers mécaniques travaillent par valeurs pleines, les électroniques par tiers."
        >
          <Segmented
            label="Graduation"
            value={settings.stopIncrement}
            onChange={(stopIncrement: StopIncrement) => updateSettings({ stopIncrement })}
            options={[
              { value: 'full', label: 'Pleines' },
              { value: 'half', label: 'Demies' },
              { value: 'third', label: 'Tiers' },
            ]}
          />
        </Field>

        <label className="checkbox">
          <input
            type="checkbox"
            checked={settings.autoGeolocate}
            onChange={(e) => updateSettings({ autoGeolocate: e.target.checked })}
          />
          Géolocaliser automatiquement chaque nouvelle vue
        </label>

        <Field label="Boîtier par défaut">
          <select
            value={settings.defaultCameraId ?? ''}
            onChange={(e) => updateSettings({ defaultCameraId: e.target.value || undefined })}
          >
            <option value="">Aucun</option>
            {cameras.map((camera) => (
              <option key={camera.id} value={camera.id}>
                {camera.name}
              </option>
            ))}
          </select>
        </Field>

        <Field label="Objectif par défaut">
          <select
            value={settings.defaultLensId ?? ''}
            onChange={(e) => updateSettings({ defaultLensId: e.target.value || undefined })}
          >
            <option value="">Aucun</option>
            {lenses.map((lens) => (
              <option key={lens.id} value={lens.id}>
                {lens.name}
              </option>
            ))}
          </select>
        </Field>

        <div className="field-inline">
          <Field label="Laboratoire habituel">
            <input
              type="text"
              value={settings.defaultLab ?? ''}
              onChange={(e) => updateSettings({ defaultLab: e.target.value || undefined })}
              maxLength={60}
            />
          </Field>
          <Field label="Monnaie">
            <select
              value={settings.currency}
              onChange={(e) => updateSettings({ currency: e.target.value })}
            >
              <option value="EUR">Euro (€)</option>
              <option value="CHF">Franc suisse</option>
              <option value="GBP">Livre (£)</option>
              <option value="USD">Dollar ($)</option>
            </select>
          </Field>
        </div>

        <Field
          label="Cercle de confusion (mm)"
          hint="Sert aux calculs de profondeur de champ. 0,03 convient à un tirage courant en 24×36 ; descendez à 0,02 pour les grands tirages."
        >
          <input
            type="number"
            inputMode="decimal"
            step="0.005"
            min="0.005"
            max="0.1"
            value={settings.circleOfConfusion}
            onChange={(e) =>
              updateSettings({ circleOfConfusion: Number(e.target.value) || 0.03 })
            }
          />
        </Field>
      </Section>

      <Section title="Données">
        <div className="stack">
          <button
            type="button"
            className="btn btn--primary btn--block"
            onClick={() => exportBackup(true)}
            disabled={busy}
          >
            Sauvegarder (avec les photos)
          </button>
          <button
            type="button"
            className="btn btn--block"
            onClick={() => exportBackup(false)}
            disabled={busy}
          >
            Sauvegarder (sans les photos)
          </button>
          <button
            type="button"
            className="btn btn--block"
            onClick={() => fileInput.current?.click()}
            disabled={busy}
          >
            Restaurer une sauvegarde
          </button>
          <input
            ref={fileInput}
            type="file"
            accept="application/json,.json"
            className="sr-only"
            onChange={importBackup}
          />
          <Link className="btn btn--block" to="/export">
            Exporter les métadonnées d’un rouleau
          </Link>
        </div>

        {message && <p className="field-hint">{message}</p>}

        <div className="card" style={{ marginTop: 12 }}>
          {storage && (
            <>
              <KeyValue label="Espace utilisé">{formatBytes(storage.usage)}</KeyValue>
              {storage.quota > 0 && (
                <KeyValue label="Espace disponible">{formatBytes(storage.quota)}</KeyValue>
              )}
            </>
          )}
          <KeyValue label="Stockage persistant">
            {persistent === null ? '…' : persistent ? 'Oui' : 'Non'}
          </KeyValue>
        </div>

        {persistent === false && (
          <button type="button" className="btn btn--block" onClick={enablePersistence}>
            Rendre le stockage persistant
          </button>
        )}

        <Note>
          Toutes vos données restent sur cet appareil : aucun serveur, aucun compte, aucune
          synchronisation. C’est ce qui rend l’application utilisable hors ligne — et ce qui
          rend la sauvegarde indispensable. Déposez le fichier dans iCloud Drive après chaque
          rouleau développé.
        </Note>
      </Section>

      <Section title="À propos">
        <div className="card">
          <KeyValue label="Application">Pellicule</KeyValue>
          <KeyValue label="Format 135">24×36</KeyValue>
          <KeyValue label="Données">Locales, hors ligne</KeyValue>
        </div>
        <Link className="btn btn--block" to="/stats" style={{ marginTop: 10 }}>
          Statistiques
        </Link>
      </Section>

      <button type="button" className="btn btn--danger btn--block" onClick={eraseEverything}>
        Effacer toutes les données
      </button>
    </main>
  );
}
