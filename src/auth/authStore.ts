import * as SecureStore from 'expo-secure-store';

import { uuidV4 } from '@/src/utils/uuid';

import type { AuthRef, StoredAuth } from './types';

// expo-secure-store keys are restricted (letters/numbers/._-). Avoid ':'.
const KEY_PREFIX = 'codexm_auth_';

export async function saveAuth(auth: StoredAuth): Promise<AuthRef> {
  const ref: AuthRef = `${KEY_PREFIX}${uuidV4()}`;
  await SecureStore.setItemAsync(ref, JSON.stringify(auth));
  return ref;
}

export async function loadAuth<T extends StoredAuth = StoredAuth>(ref: AuthRef): Promise<T | null> {
  const raw = await SecureStore.getItemAsync(ref);
  if (!raw) return null;
  return JSON.parse(raw) as T;
}

export async function deleteAuth(ref: AuthRef) {
  await SecureStore.deleteItemAsync(ref);
}
