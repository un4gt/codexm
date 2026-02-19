import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';

import { getActiveWorkspaceId } from './store';
import { createWorkspace, deleteWorkspace, getAllWorkspaces, setActiveWorkspace } from './workspaceManager';
import type { Workspace, WorkspaceId } from './types';

type WorkspacesState = {
  loading: boolean;
  error: string | null;
  workspaces: Workspace[];
  activeWorkspaceId: WorkspaceId | null;
};

type WorkspacesActions = {
  refresh(): Promise<void>;
  setActive(id: WorkspaceId | null): Promise<void>;
  createEmpty(name: string): Promise<Workspace>;
  remove(id: WorkspaceId): Promise<void>;
};

type WorkspacesContextValue = WorkspacesState & WorkspacesActions;

const WorkspacesContext = createContext<WorkspacesContextValue | null>(null);

export function WorkspacesProvider({ children }: { children: React.ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [workspaces, setWorkspaces] = useState<Workspace[]>([]);
  const [activeWorkspaceId, setActiveWorkspaceId] = useState<WorkspaceId | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [all, activeId] = await Promise.all([getAllWorkspaces(), getActiveWorkspaceId()]);
      setWorkspaces(all);
      setActiveWorkspaceId(activeId);
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      setError(message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const setActive = useCallback(async (id: WorkspaceId | null) => {
    await setActiveWorkspace(id);
    setActiveWorkspaceId(id);
  }, []);

  const createEmpty = useCallback(
    async (name: string) => {
      const ws = await createWorkspace({ name });
      await setActiveWorkspace(ws.id);
      await refresh();
      return ws;
    },
    [refresh]
  );

  const remove = useCallback(
    async (id: WorkspaceId) => {
      await deleteWorkspace(id);
      await refresh();
    },
    [refresh]
  );

  const value = useMemo(
    () => ({
      loading,
      error,
      workspaces,
      activeWorkspaceId,
      refresh,
      setActive,
      createEmpty,
      remove,
    }),
    [activeWorkspaceId, createEmpty, error, loading, refresh, remove, setActive, workspaces]
  );

  return <WorkspacesContext.Provider value={value}>{children}</WorkspacesContext.Provider>;
}

export function useWorkspaces() {
  const ctx = useContext(WorkspacesContext);
  if (!ctx) throw new Error('useWorkspaces must be used within <WorkspacesProvider>');
  return ctx;
}

