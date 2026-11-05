import { useState } from 'react';
import { canPromptInstall, isInstalled, promptInstall } from '../../lib/install.ts';
import { Modal } from '../common.tsx';

/** "Install on your phone" (Batch J): how to put the web app on a Home Screen. */
export function InstallHelp({ onClose }: { onClose: () => void }) {
  const [prompted, setPrompted] = useState(false);
  return (
    <Modal title="Install Folio on your phone" onClose={onClose}
      message={isInstalled() ? 'You’re using the installed app.' : 'It opens like an app, full screen, and starts even offline. Your diary still stays only in memory until you unlock it.'}>
      {canPromptInstall() && !prompted && (
        <button className="btn primary" onClick={() => { setPrompted(true); void promptInstall(); }}>Install now</button>
      )}
      <ol className="install-steps">
        <li><b>iPhone or iPad (Safari):</b> tap Share, then <b>Add to Home Screen</b>, then Add.</li>
        <li><b>Android (Chrome):</b> tap the ⋮ menu, then <b>Install app</b> (or Add to Home screen).</li>
        <li><b>Computer (Chrome, Edge):</b> click the install icon at the end of the address bar.</li>
      </ol>
      <p className="caption ink3">On iPhone the Folio app from the App Store does more: dictation, widgets and offline writing.</p>
      <button className="btn" onClick={onClose}>Done</button>
    </Modal>
  );
}
