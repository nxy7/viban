import { createResource, createSignal, Show } from "solid-js";
import { get_download_url, get_update_status } from "~/lib/generated/ash";
import { getStoredString, setStoredString } from "~/lib/storageUtils";
import Button from "./design-system/Button";

const DISMISSED_VERSION_KEY = "viban_dismissed_update_version";

const getDismissedVersion = () => getStoredString(DISMISSED_VERSION_KEY);
const setDismissedVersion = (version: string) =>
  setStoredString(DISMISSED_VERSION_KEY, version);

export default function UpdateBanner() {
  const [dismissed, setDismissed] = createSignal(false);
  const [downloading, setDownloading] = createSignal(false);

  const [status] = createResource(async () => {
    const result = await get_update_status({});
    if (!result.success) {
      return null;
    }
    return result.data;
  });

  const shouldShow = () => {
    const s = status();
    if (!s || !s.update_available || !s.latest_version) return false;
    if (dismissed()) return false;
    if (getDismissedVersion() === s.latest_version) return false;
    return true;
  };

  const handleDismiss = () => {
    const s = status();
    if (s?.latest_version) {
      setDismissedVersion(s.latest_version);
    }
    setDismissed(true);
  };

  const handleDownload = async () => {
    setDownloading(true);
    try {
      const result = await get_download_url({});
      if (result.success && result.data.url) {
        window.open(result.data.url, "_blank");
      } else if (result.success && result.data.all_platforms) {
        const releaseUrl = status()?.release_notes_url;
        if (releaseUrl) {
          window.open(releaseUrl, "_blank");
        }
      }
    } finally {
      setDownloading(false);
    }
  };

  return (
    <Show when={shouldShow()}>
      <div class="fixed top-0 left-0 right-0 z-50 bg-amber-900/95 border-b border-amber-500/50 backdrop-blur-sm">
        <div class="max-w-screen-xl mx-auto px-4 py-2 flex items-center justify-between gap-4">
          <div class="flex items-center gap-3">
            <svg
              class="w-5 h-5 text-amber-400 flex-shrink-0"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
              />
            </svg>
            <span class="text-amber-200 text-sm">
              <span class="font-medium">Update available:</span>{" "}
              <span class="text-amber-100">
                {status()?.current_version} → {status()?.latest_version}
              </span>
            </span>
          </div>
          <div class="flex items-center gap-2">
            <Button
              variant="secondary"
              buttonSize="sm"
              onClick={handleDownload}
              loading={downloading()}
              class="bg-amber-600 hover:bg-amber-700 text-white"
            >
              Download
            </Button>
            <button
              onClick={handleDismiss}
              class="p-1.5 rounded-lg text-amber-400 hover:text-amber-200 hover:bg-amber-800/50 transition-colors"
              aria-label="Dismiss"
            >
              <svg
                class="w-4 h-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </Show>
  );
}
