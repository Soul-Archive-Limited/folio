/** Where a photo view is in loading one photo: which rendition it's on and how many retries. */
export interface PhotoLoad { id: string; step: number; attempt: number }

/**
 * The load state for `id` (Batch K): state left over from another photo — a card whose photo was
 * replaced — never carries over, so the new photo starts at its best rendition.
 */
export function photoLoadFor(load: PhotoLoad, id: string): PhotoLoad {
  return load.id === id ? load : { id, step: 0, attempt: 0 };
}
