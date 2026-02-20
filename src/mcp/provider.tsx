import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';

import type { McpServer, McpServerCreateParams, McpServerId } from './types';
import { addMcpServer, deleteMcpServer, listMcpServers, updateMcpServer } from './store';

type McpState = {
  loading: boolean;
  error: string | null;
  servers: McpServer[];
};

type McpActions = {
  refresh: () => Promise<void>;
  add: (params: McpServerCreateParams) => Promise<McpServer>;
  update: (id: McpServerId, patch: Partial<McpServerCreateParams>) => Promise<McpServer>;
  remove: (id: McpServerId) => Promise<void>;
};

type McpContextValue = McpState & McpActions;

const McpContext = createContext<McpContextValue | null>(null);

export function McpProvider({ children }: { children: React.ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [servers, setServers] = useState<McpServer[]>([]);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const all = await listMcpServers();
      setServers(all);
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

  const add = useCallback(
    async (params: McpServerCreateParams) => {
      const s = await addMcpServer(params);
      await refresh();
      return s;
    },
    [refresh]
  );

  const update = useCallback(
    async (id: McpServerId, patch: Partial<McpServerCreateParams>) => {
      const s = await updateMcpServer(id, patch);
      await refresh();
      return s;
    },
    [refresh]
  );

  const remove = useCallback(
    async (id: McpServerId) => {
      await deleteMcpServer(id);
      await refresh();
    },
    [refresh]
  );

  const value = useMemo(
    () => ({
      loading,
      error,
      servers,
      refresh,
      add,
      update,
      remove,
    }),
    [add, error, loading, refresh, remove, servers, update]
  );

  return <McpContext.Provider value={value}>{children}</McpContext.Provider>;
}

export function useMcp() {
  const ctx = useContext(McpContext);
  if (!ctx) throw new Error('useMcp must be used within <McpProvider>');
  return ctx;
}

