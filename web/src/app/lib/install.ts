/**
 * Installing the web app (Batch J): the service worker for the offline shell, and Chrome's
 * install prompt kept for the "Install on your phone" button. Safari has no prompt; the
 * instructions explain Add to Home Screen.
 */
interface InstallPrompt extends Event { prompt: () => Promise<void> }

let deferred: InstallPrompt | null = null;

export function setUpInstall() {
  if ('serviceWorker' in navigator) void navigator.serviceWorker.register('/app-sw.js', { scope: '/app' }).catch(() => {});
  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    deferred = event as InstallPrompt;
  });
}

export const canPromptInstall = () => deferred !== null;

export async function promptInstall(): Promise<void> {
  const prompt = deferred;
  deferred = null;
  await prompt?.prompt();
}

/** Already opened from the Home Screen. */
export const isInstalled = () => window.matchMedia('(display-mode: standalone)').matches
  || (navigator as Navigator & { standalone?: boolean }).standalone === true;
