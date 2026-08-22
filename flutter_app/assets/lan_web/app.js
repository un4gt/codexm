const state = {
  csrfToken: null,
  locale: navigator.language.toLowerCase().startsWith('en') ? 'en' : 'zh',
  workspaces: [],
  selectedWorkspaceId: null,
  selectedSessionId: null,
  messages: [],
  hasMoreMessages: false,
  nextBefore: null,
  activeTurn: null,
  revision: 0,
  socket: null,
  reconnectTimer: null,
  reconnectDelay: 1000,
  dialog: null,
  pendingRender: false,
};

const strings = {
  zh: {
    skip: '跳到对话内容',
    pairTitle: '连接 CodexM',
    pairSubtitle: '输入手机上显示的一次性配对码',
    pairingCode: '配对码',
    connect: '连接',
    connecting: '正在连接...',
    workspaces: '工作区',
    noWorkspaces: '手机上还没有工作区',
    noSessions: '没有会话',
    newSession: '新建会话',
    renameSession: '重命名会话',
    sessionName: '会话名称',
    cancel: '取消',
    save: '保存',
    chooseSession: '选择一个会话',
    chooseSessionHeader: '选择会话',
    defaultMode: '默认',
    planMode: '计划',
    message: '消息',
    placeholder: '在这里输入消息...',
    send: '发送消息',
    stop: '停止当前轮次',
    loadOlder: '加载更早消息',
    online: '已连接',
    reconnecting: '连接已中断，正在重试...',
    disconnect: '断开此浏览器',
    assistant: 'Codex',
    user: '你',
    system: '系统',
    browserDisconnected: '浏览器已断开。',
    sessionCreated: '会话已创建。',
    sessionRenamed: '会话已重命名。',
    modeUpdated: '会话模式已更新。',
    invalidCode: '请输入 6 位配对码。',
    invalidName: '请输入会话名称。',
    requestFailed: '操作失败，请重试。',
    runningHere: '当前会话正在运行',
    runningElsewhere: (title, origin) => `“${title}”正在${origin === 'web' ? '网页端' : '手机端'}运行，点击查看`,
    context: (workspace, session) => `${workspace} / ${session}`,
  },
  en: {
    skip: 'Skip to conversation',
    pairTitle: 'Connect to CodexM',
    pairSubtitle: 'Enter the one-time pairing code shown on your phone',
    pairingCode: 'Pairing code',
    connect: 'Connect',
    connecting: 'Connecting...',
    workspaces: 'Workspaces',
    noWorkspaces: 'No workspaces on the phone yet',
    noSessions: 'No sessions',
    newSession: 'New session',
    renameSession: 'Rename session',
    sessionName: 'Session name',
    cancel: 'Cancel',
    save: 'Save',
    chooseSession: 'Choose a session',
    chooseSessionHeader: 'Choose session',
    defaultMode: 'Default',
    planMode: 'Plan',
    message: 'Message',
    placeholder: 'Type a message...',
    send: 'Send message',
    stop: 'Stop current turn',
    loadOlder: 'Load earlier messages',
    online: 'Connected',
    reconnecting: 'Connection lost. Reconnecting...',
    disconnect: 'Disconnect this browser',
    assistant: 'Codex',
    user: 'You',
    system: 'System',
    browserDisconnected: 'Browser disconnected.',
    sessionCreated: 'Session created.',
    sessionRenamed: 'Session renamed.',
    modeUpdated: 'Session mode updated.',
    invalidCode: 'Enter the 6-digit pairing code.',
    invalidName: 'Enter a session name.',
    requestFailed: 'The operation failed. Try again.',
    runningHere: 'This session is running',
    runningElsewhere: (title, origin) => `“${title}” is running on ${origin === 'web' ? 'the web' : 'the phone'}. Open it`,
    context: (workspace, session) => `${workspace} / ${session}`,
  },
};

const $ = (selector) => document.querySelector(selector);
const dom = {
  pairView: $('#pair-view'),
  pairForm: $('#pair-form'),
  pairCode: $('#pair-code'),
  pairError: $('#pair-error'),
  pairSubmit: $('#pair-submit'),
  workspaceView: $('#workspace-view'),
  sidebar: $('#sidebar'),
  drawerScrim: $('#drawer-scrim'),
  workspaceTree: $('#workspace-tree'),
  workspaceCount: $('#workspace-count'),
  currentWorkspace: $('#current-workspace'),
  currentSession: $('#current-session'),
  modeControl: $('#mode-control'),
  emptyState: $('#empty-state'),
  messageColumn: $('#message-column'),
  messageList: $('#message-list'),
  messageRegion: $('#main-content'),
  loadOlder: $('#load-older'),
  composerForm: $('#composer-form'),
  composerInput: $('#composer-input'),
  composerContext: $('#composer-context'),
  sendButton: $('#send-button'),
  activeTurnBanner: $('#active-turn-banner'),
  reconnectBanner: $('#reconnect-banner'),
  connectionDot: $('#connection-dot'),
  connectionLabel: $('#connection-label'),
  sessionDialog: $('#session-dialog'),
  sessionForm: $('#session-form'),
  sessionDialogTitle: $('#session-dialog-title'),
  sessionName: $('#session-name'),
  sessionError: $('#session-error'),
  saveSession: $('#save-session'),
  toast: $('#toast'),
};

const iconPaths = {
  menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
  x: '<path d="m18 6-12 12M6 6l12 12"/>',
  logout: '<path d="M10 17l5-5-5-5M15 12H3"/><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>',
  folder: '<path d="M3 7a2 2 0 0 1 2-2h5l2 2h7a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>',
  message: '<path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4Z"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4Z"/>',
  send: '<path d="m5 12 7-7 7 7M12 5v14"/>',
  stop: '<rect width="10" height="10" x="7" y="7" rx="1"/>',
};

function icon(name) {
  return `<svg viewBox="0 0 24 24" aria-hidden="true">${iconPaths[name]}</svg>`;
}

function setButtonIcon(selector, name) {
  const button = $(selector);
  if (button) button.innerHTML = icon(name);
}

setButtonIcon('#open-sidebar', 'menu');
setButtonIcon('#close-sidebar', 'x');
setButtonIcon('#close-dialog', 'x');
setButtonIcon('#logout-button', 'logout');
dom.sendButton.innerHTML = icon('send');

function t(key, ...args) {
  const value = strings[state.locale][key] ?? strings.zh[key] ?? key;
  return typeof value === 'function' ? value(...args) : value;
}

function applyStrings() {
  document.documentElement.lang = state.locale === 'en' ? 'en' : 'zh-CN';
  $('.skip-link').textContent = t('skip');
  $('#pair-title').textContent = t('pairTitle');
  $('#pair-subtitle').textContent = t('pairSubtitle');
  $('#pair-label').textContent = t('pairingCode');
  dom.pairSubmit.textContent = t('connect');
  $('#workspaces-heading').textContent = t('workspaces');
  $('#mode-control [data-mode="standard"]').textContent = t('defaultMode');
  $('#mode-control [data-mode="plan"]').textContent = t('planMode');
  $('#composer-label').textContent = t('message');
  dom.composerInput.placeholder = t('placeholder');
  dom.loadOlder.textContent = t('loadOlder');
  $('#reconnect-text').textContent = t('reconnecting');
  $('#logout-button').setAttribute('aria-label', t('disconnect'));
  $('#session-name-label').textContent = t('sessionName');
  $('#cancel-dialog').textContent = t('cancel');
  dom.saveSession.textContent = t('save');
  renderComposer();
}

class ApiError extends Error {
  constructor(status, code, message, payload) {
    super(message);
    this.status = status;
    this.code = code;
    this.payload = payload;
  }
}

async function api(path, options = {}) {
  const method = options.method ?? 'GET';
  const headers = new Headers(options.headers ?? {});
  let body;
  if (options.body !== undefined) {
    headers.set('content-type', 'application/json');
    body = JSON.stringify(options.body);
  }
  if (state.csrfToken && !['GET', 'HEAD'].includes(method)) {
    headers.set('x-codexm-csrf', state.csrfToken);
  }
  const response = await fetch(path, {
    method,
    headers,
    body,
    credentials: 'same-origin',
    cache: 'no-store',
  });
  const contentType = response.headers.get('content-type') ?? '';
  const data = contentType.includes('application/json')
    ? await response.json()
    : null;
  if (!response.ok) {
    const error = data?.error ?? {};
    throw new ApiError(
      response.status,
      error.code ?? 'request_failed',
      error.message ?? t('requestFailed'),
      error,
    );
  }
  return data;
}

async function initialize() {
  applyStrings();
  try {
    const auth = await api('/api/v1/auth/session');
    state.csrfToken = auth.csrfToken;
    await enterWorkspace();
  } catch (error) {
    if (!(error instanceof ApiError) || error.status !== 401) {
      dom.pairError.textContent = error.message ?? t('requestFailed');
    }
    showPairView();
  }
}

function showPairView() {
  dom.workspaceView.hidden = true;
  dom.pairView.hidden = false;
  window.setTimeout(() => dom.pairCode.focus(), 0);
}

async function enterWorkspace() {
  dom.pairView.hidden = true;
  dom.workspaceView.hidden = false;
  await loadBootstrap();
  connectSocket();
}

dom.pairCode.addEventListener('input', () => {
  dom.pairCode.value = dom.pairCode.value.replace(/\D/g, '').slice(0, 6);
  dom.pairError.textContent = '';
});

dom.pairForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const code = dom.pairCode.value.trim();
  if (!/^\d{6}$/.test(code)) {
    dom.pairError.textContent = t('invalidCode');
    dom.pairCode.focus();
    return;
  }
  dom.pairSubmit.disabled = true;
  dom.pairSubmit.textContent = t('connecting');
  try {
    const paired = await api('/api/v1/auth/pair', {
      method: 'POST',
      body: { code },
    });
    state.csrfToken = paired.csrfToken;
    dom.pairCode.value = '';
    dom.pairError.textContent = '';
    await enterWorkspace();
  } catch (error) {
    dom.pairError.textContent = error.message ?? t('requestFailed');
    dom.pairCode.focus();
  } finally {
    dom.pairSubmit.disabled = false;
    dom.pairSubmit.textContent = t('connect');
  }
});

async function loadBootstrap({ loadCurrentMessages = true } = {}) {
  const data = await api('/api/v1/bootstrap');
  state.revision = Math.max(state.revision, data.revision ?? 0);
  state.locale = data.locale === 'en' ? 'en' : 'zh';
  state.workspaces = data.workspaces ?? [];
  state.activeTurn = data.activeTurn ?? null;
  resolveSelection();
  applyStrings();
  renderTree();
  renderHeader();
  renderActiveTurnBanner();
  if (loadCurrentMessages) await loadMessages();
}

function routeSelection() {
  const match = location.hash.match(/^#\/workspaces\/([^/]+)\/sessions\/([^/]+)$/);
  return match
    ? {
        workspaceId: decodeURIComponent(match[1]),
        sessionId: decodeURIComponent(match[2]),
      }
    : null;
}

function resolveSelection() {
  const routed = routeSelection();
  const candidates = [
    routed,
    {
      workspaceId: state.selectedWorkspaceId,
      sessionId: state.selectedSessionId,
    },
  ];
  for (const candidate of candidates) {
    if (!candidate?.workspaceId || !candidate?.sessionId) continue;
    const workspace = state.workspaces.find((item) => item.id === candidate.workspaceId);
    if (workspace?.sessions.some((item) => item.id === candidate.sessionId)) {
      state.selectedWorkspaceId = candidate.workspaceId;
      state.selectedSessionId = candidate.sessionId;
      return;
    }
  }
  const workspace = state.workspaces.find((item) => item.sessions.length > 0);
  state.selectedWorkspaceId = workspace?.id ?? null;
  state.selectedSessionId = workspace?.sessions[0]?.id ?? null;
  if (state.selectedSessionId) updateHash(false);
}

function selectedWorkspace() {
  return state.workspaces.find((item) => item.id === state.selectedWorkspaceId) ?? null;
}

function selectedSession() {
  return selectedWorkspace()?.sessions.find((item) => item.id === state.selectedSessionId) ?? null;
}

function updateHash(push = true) {
  if (!state.selectedWorkspaceId || !state.selectedSessionId) return;
  const hash = `#/workspaces/${encodeURIComponent(state.selectedWorkspaceId)}/sessions/${encodeURIComponent(state.selectedSessionId)}`;
  if (location.hash === hash) return;
  if (push) history.pushState(null, '', hash);
  else history.replaceState(null, '', hash);
}

async function selectSession(workspaceId, sessionId, { push = true } = {}) {
  if (workspaceId === state.selectedWorkspaceId && sessionId === state.selectedSessionId) {
    closeSidebar();
    return;
  }
  state.selectedWorkspaceId = workspaceId;
  state.selectedSessionId = sessionId;
  updateHash(push);
  state.messages = [];
  renderTree();
  renderHeader();
  renderMessages();
  closeSidebar();
  await loadMessages();
  dom.messageRegion.focus();
}

function renderTree() {
  dom.workspaceTree.replaceChildren();
  dom.workspaceCount.textContent = `${state.workspaces.length}`;
  if (state.workspaces.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'tree-empty';
    empty.textContent = t('noWorkspaces');
    dom.workspaceTree.append(empty);
    return;
  }
  for (const workspace of state.workspaces) {
    const group = document.createElement('section');
    group.className = 'workspace-group';
    const row = document.createElement('div');
    row.className = 'workspace-row';
    row.innerHTML = icon('folder');
    const name = document.createElement('span');
    name.className = 'workspace-name';
    name.textContent = workspace.name;
    name.title = workspace.name;
    const add = document.createElement('button');
    add.type = 'button';
    add.className = 'new-session-button';
    add.setAttribute('aria-label', `${t('newSession')} · ${workspace.name}`);
    add.innerHTML = icon('plus');
    add.disabled = Boolean(state.activeTurn);
    add.addEventListener('click', () => openSessionDialog('create', workspace.id));
    row.append(name, add);
    group.append(row);

    const sessions = document.createElement('div');
    sessions.className = 'session-list';
    if (workspace.sessions.length === 0) {
      const empty = document.createElement('p');
      empty.className = 'tree-empty';
      empty.textContent = t('noSessions');
      sessions.append(empty);
    }
    for (const session of workspace.sessions) {
      const sessionRow = document.createElement('div');
      sessionRow.className = 'session-row';
      if (session.id === state.selectedSessionId) sessionRow.classList.add('selected');
      const select = document.createElement('button');
      select.type = 'button';
      select.className = 'session-select';
      select.innerHTML = icon('message');
      const label = document.createElement('span');
      label.textContent = session.title;
      label.title = session.title;
      select.append(label);
      select.addEventListener('click', () => selectSession(workspace.id, session.id));
      const rename = document.createElement('button');
      rename.type = 'button';
      rename.className = 'rename-session-button';
      rename.setAttribute('aria-label', `${t('renameSession')} · ${session.title}`);
      rename.innerHTML = icon('edit');
      rename.disabled = Boolean(state.activeTurn);
      rename.addEventListener('click', () => openSessionDialog('rename', workspace.id, session));
      sessionRow.append(select, rename);
      sessions.append(sessionRow);
    }
    group.append(sessions);
    dom.workspaceTree.append(group);
  }
}

function renderHeader() {
  const workspace = selectedWorkspace();
  const session = selectedSession();
  dom.currentWorkspace.textContent = workspace?.name ?? '';
  dom.currentSession.textContent = session?.title ?? t('chooseSessionHeader');
  dom.composerContext.textContent = workspace && session
    ? t('context', workspace.name, session.title)
    : '';
  for (const button of dom.modeControl.querySelectorAll('button')) {
    button.classList.toggle('active', button.dataset.mode === session?.mode);
    button.disabled = !session || Boolean(state.activeTurn);
  }
  dom.emptyState.querySelector('h2').textContent = t('chooseSession');
  renderComposer();
}

for (const button of dom.modeControl.querySelectorAll('button')) {
  button.addEventListener('click', async () => {
    const workspace = selectedWorkspace();
    const session = selectedSession();
    if (!workspace || !session || state.activeTurn) return;
    try {
      const data = await api(
        `/api/v1/workspaces/${encodeURIComponent(workspace.id)}/sessions/${encodeURIComponent(session.id)}`,
        { method: 'PATCH', body: { mode: button.dataset.mode } },
      );
      session.mode = data.session.mode;
      renderHeader();
      showToast(t('modeUpdated'));
    } catch (error) {
      showToast(error.message ?? t('requestFailed'));
    }
  });
}

async function loadMessages({ older = false } = {}) {
  const workspace = selectedWorkspace();
  const session = selectedSession();
  if (!workspace || !session) {
    state.messages = [];
    state.hasMoreMessages = false;
    renderMessages();
    return;
  }
  const query = new URLSearchParams({ limit: '100' });
  if (older && state.nextBefore) query.set('before', state.nextBefore);
  try {
    const data = await api(
      `/api/v1/workspaces/${encodeURIComponent(workspace.id)}/sessions/${encodeURIComponent(session.id)}/messages?${query}`,
    );
    if (workspace.id !== state.selectedWorkspaceId || session.id !== state.selectedSessionId) return;
    const previousHeight = dom.messageRegion.scrollHeight;
    state.messages = older ? [...data.messages, ...state.messages] : data.messages;
    state.hasMoreMessages = data.hasMore;
    state.nextBefore = data.nextBefore;
    renderMessages();
    if (older) {
      dom.messageRegion.scrollTop += dom.messageRegion.scrollHeight - previousHeight;
    } else {
      scrollToBottom(false);
    }
  } catch (error) {
    showToast(error.message ?? t('requestFailed'));
  }
}

dom.loadOlder.addEventListener('click', () => loadMessages({ older: true }));

function renderMessages() {
  const session = selectedSession();
  dom.emptyState.hidden = Boolean(session);
  dom.messageColumn.hidden = !session;
  dom.messageList.replaceChildren();
  dom.loadOlder.hidden = !state.hasMoreMessages;
  for (const message of state.messages) {
    dom.messageList.append(messageElement(message));
  }
  renderPendingTurn();
}

function messageElement(message, { pending = false } = {}) {
  const item = document.createElement('li');
  item.className = `message ${message.role}`;
  if (pending) item.classList.add('pending');
  const meta = document.createElement('div');
  meta.className = 'message-meta';
  const role = document.createElement('span');
  role.className = 'message-role';
  role.textContent = message.role === 'assistant'
    ? t('assistant')
    : message.role === 'user'
    ? t('user')
    : t('system');
  const time = document.createElement('time');
  time.dateTime = new Date(message.createdAt).toISOString();
  time.textContent = new Intl.DateTimeFormat(state.locale === 'en' ? 'en' : 'zh-CN', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(message.createdAt));
  meta.append(role, time);
  const body = document.createElement('div');
  body.className = 'message-body';
  if (message.role === 'assistant') {
    body.classList.add('markdown');
    renderMarkdown(body, message.content || (pending ? ' ' : ''));
  } else {
    body.textContent = message.content;
  }
  item.append(meta, body);
  if (message.parts?.length) {
    const parts = document.createElement('div');
    parts.className = 'message-parts';
    for (const part of message.parts) {
      const details = document.createElement('details');
      details.className = 'message-part';
      const summary = document.createElement('summary');
      summary.textContent = part.title || part.kind;
      const content = document.createElement('div');
      content.className = 'message-part-content';
      content.textContent = part.content ?? '';
      details.append(summary, content);
      parts.append(details);
    }
    item.append(parts);
  }
  return item;
}

function renderMarkdown(target, source) {
  if (window.marked && window.DOMPurify) {
    const raw = window.marked.parse(source, { gfm: true, breaks: true });
    target.innerHTML = window.DOMPurify.sanitize(raw, {
      USE_PROFILES: { html: true },
      FORBID_TAGS: ['style', 'form', 'input', 'button', 'textarea', 'select', 'iframe', 'object'],
      FORBID_ATTR: ['style'],
    });
    for (const link of target.querySelectorAll('a')) {
      link.target = '_blank';
      link.rel = 'noopener noreferrer';
    }
    return;
  }
  target.textContent = source;
}

function renderPendingTurn() {
  $('#pending-turn-message')?.remove();
  const active = state.activeTurn;
  if (!active || active.workspaceId !== state.selectedWorkspaceId || active.sessionId !== state.selectedSessionId) {
    return;
  }
  const pending = messageElement({
    role: 'assistant',
    createdAt: active.startedAt,
    content: active.assistantText ?? '',
    parts: active.assistantParts ?? [],
  }, { pending: true });
  pending.id = 'pending-turn-message';
  dom.messageList.append(pending);
}

function schedulePendingRender() {
  if (state.pendingRender) return;
  state.pendingRender = true;
  window.setTimeout(() => {
    state.pendingRender = false;
    const shouldFollow = dom.messageRegion.scrollHeight - dom.messageRegion.scrollTop - dom.messageRegion.clientHeight < 160;
    renderPendingTurn();
    if (shouldFollow) scrollToBottom(true);
    renderComposer();
    renderActiveTurnBanner();
  }, 70);
}

function scrollToBottom(smooth) {
  dom.messageRegion.scrollTo({
    top: dom.messageRegion.scrollHeight,
    behavior: smooth && !window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'smooth' : 'auto',
  });
}

function renderComposer() {
  const session = selectedSession();
  const active = state.activeTurn;
  const activeHere = active && active.workspaceId === state.selectedWorkspaceId && active.sessionId === state.selectedSessionId;
  dom.composerInput.disabled = !session || Boolean(active);
  dom.sendButton.disabled = !session || (!activeHere && dom.composerInput.value.trim().length === 0) || (Boolean(active) && !activeHere);
  dom.sendButton.classList.toggle('stop', Boolean(activeHere));
  dom.sendButton.innerHTML = icon(activeHere ? 'stop' : 'send');
  dom.sendButton.setAttribute('aria-label', activeHere ? t('stop') : t('send'));
  dom.sendButton.title = activeHere ? t('stop') : t('send');
}

dom.composerInput.addEventListener('input', renderComposer);
dom.composerInput.addEventListener('keydown', (event) => {
  if (event.key === 'Enter' && !event.shiftKey && !event.isComposing) {
    event.preventDefault();
    dom.composerForm.requestSubmit();
  }
});

dom.composerForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const active = state.activeTurn;
  const activeHere = active && active.workspaceId === state.selectedWorkspaceId && active.sessionId === state.selectedSessionId;
  if (activeHere) {
    dom.sendButton.disabled = true;
    try {
      await api(`/api/v1/turns/${encodeURIComponent(active.turnId)}`, { method: 'DELETE' });
    } catch (error) {
      showToast(error.message ?? t('requestFailed'));
    }
    return;
  }
  const workspace = selectedWorkspace();
  const session = selectedSession();
  const text = dom.composerInput.value.trim();
  if (!workspace || !session || !text || state.activeTurn) return;
  dom.sendButton.disabled = true;
  try {
    await api(
      `/api/v1/workspaces/${encodeURIComponent(workspace.id)}/sessions/${encodeURIComponent(session.id)}/turns`,
      { method: 'POST', body: { text, mode: session.mode } },
    );
    dom.composerInput.value = '';
    await loadMessages();
    renderComposer();
  } catch (error) {
    if (error.code === 'turn_busy' && error.payload?.activeTurn) {
      state.activeTurn = error.payload.activeTurn;
      renderActiveTurnBanner();
      renderComposer();
    }
    showToast(error.message ?? t('requestFailed'));
  }
});

function renderActiveTurnBanner() {
  const active = state.activeTurn;
  const activeHere = active && active.workspaceId === state.selectedWorkspaceId && active.sessionId === state.selectedSessionId;
  dom.activeTurnBanner.hidden = !active || Boolean(activeHere);
  if (active && !activeHere) {
    dom.activeTurnBanner.textContent = t('runningElsewhere', active.sessionTitle, active.origin);
  }
}

dom.activeTurnBanner.addEventListener('click', () => {
  const active = state.activeTurn;
  if (active) selectSession(active.workspaceId, active.sessionId);
});

function openSessionDialog(mode, workspaceId, session = null) {
  state.dialog = { mode, workspaceId, sessionId: session?.id ?? null };
  dom.sessionDialogTitle.textContent = mode === 'create' ? t('newSession') : t('renameSession');
  dom.sessionName.value = session?.title ?? '';
  dom.sessionError.textContent = '';
  dom.sessionDialog.showModal();
  window.setTimeout(() => dom.sessionName.focus(), 0);
}

function closeSessionDialog() {
  state.dialog = null;
  dom.sessionDialog.close();
}

$('#close-dialog').addEventListener('click', closeSessionDialog);
$('#cancel-dialog').addEventListener('click', closeSessionDialog);

dom.sessionForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const dialog = state.dialog;
  const title = dom.sessionName.value.trim();
  if (!dialog || !title) {
    dom.sessionError.textContent = t('invalidName');
    dom.sessionName.focus();
    return;
  }
  dom.saveSession.disabled = true;
  try {
    if (dialog.mode === 'create') {
      const data = await api(
        `/api/v1/workspaces/${encodeURIComponent(dialog.workspaceId)}/sessions`,
        { method: 'POST', body: { title } },
      );
      closeSessionDialog();
      await loadBootstrap({ loadCurrentMessages: false });
      await selectSession(dialog.workspaceId, data.session.id);
      showToast(t('sessionCreated'));
    } else {
      await api(
        `/api/v1/workspaces/${encodeURIComponent(dialog.workspaceId)}/sessions/${encodeURIComponent(dialog.sessionId)}`,
        { method: 'PATCH', body: { title } },
      );
      closeSessionDialog();
      await loadBootstrap();
      showToast(t('sessionRenamed'));
    }
  } catch (error) {
    dom.sessionError.textContent = error.message ?? t('requestFailed');
  } finally {
    dom.saveSession.disabled = false;
  }
});

async function connectSocket() {
  if (!state.csrfToken) return;
  try {
    const auth = await api('/api/v1/auth/session');
    state.csrfToken = auth.csrfToken;
  } catch (error) {
    if (error instanceof ApiError && error.status === 401) {
      state.csrfToken = null;
      state.socket = null;
      state.activeTurn = null;
      window.clearTimeout(state.reconnectTimer);
      showPairView();
      return;
    }
    scheduleReconnect();
    return;
  }
  if (state.socket) {
    const previous = state.socket;
    state.socket = null;
    previous.close();
  }
  const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
  const socket = new WebSocket(`${protocol}//${location.host}/api/v1/events`);
  state.socket = socket;
  socket.addEventListener('open', () => {
    state.reconnectDelay = 1000;
    dom.reconnectBanner.hidden = true;
    dom.connectionDot.classList.add('online');
    dom.connectionLabel.textContent = t('online');
  });
  socket.addEventListener('message', async (event) => {
    let message;
    try {
      message = JSON.parse(event.data);
    } catch (_) {
      return;
    }
    const revision = message.revision ?? state.revision;
    const missedUpdates = message.type === 'hello'
      ? revision > state.revision
      : revision > state.revision + 1;
    if (missedUpdates) {
      await loadBootstrap();
    }
    state.revision = Math.max(state.revision, revision);
    if (message.type === 'hello' || message.type === 'turn.state') {
      const wasActive = state.activeTurn;
      state.activeTurn = message.payload?.activeTurn ?? null;
      schedulePendingRender();
      renderTree();
      renderHeader();
      if (wasActive && !state.activeTurn) {
        await loadBootstrap({ loadCurrentMessages: false });
        await loadMessages();
      }
      return;
    }
    if (message.type === 'tree.changed') {
      await loadBootstrap({ loadCurrentMessages: false });
      return;
    }
    if (message.type === 'data.changed') {
      await loadBootstrap();
    }
  });
  socket.addEventListener('close', () => {
    if (state.socket === socket) scheduleReconnect();
  });
  socket.addEventListener('error', () => {
    if (state.socket === socket) socket.close();
  });
}

function scheduleReconnect() {
  if (!state.csrfToken) return;
  dom.reconnectBanner.hidden = false;
  dom.connectionDot.classList.remove('online');
  dom.connectionLabel.textContent = t('reconnecting');
  window.clearTimeout(state.reconnectTimer);
  state.reconnectTimer = window.setTimeout(() => {
    void connectSocket();
  }, state.reconnectDelay);
  state.reconnectDelay = Math.min(10000, state.reconnectDelay * 1.8);
}

function openSidebar() {
  dom.sidebar.classList.add('open');
  dom.drawerScrim.hidden = false;
}

function closeSidebar() {
  dom.sidebar.classList.remove('open');
  dom.drawerScrim.hidden = true;
}

$('#open-sidebar').addEventListener('click', openSidebar);
$('#close-sidebar').addEventListener('click', closeSidebar);
dom.drawerScrim.addEventListener('click', closeSidebar);

$('#logout-button').addEventListener('click', async () => {
  try {
    await api('/api/v1/auth/logout', { method: 'POST' });
  } catch (_) {
    // Local state is still cleared so a stale page cannot issue commands.
  }
  state.csrfToken = null;
  state.socket?.close();
  state.socket = null;
  state.workspaces = [];
  state.messages = [];
  showPairView();
  showToast(t('browserDisconnected'));
});

window.addEventListener('hashchange', async () => {
  const routed = routeSelection();
  if (!routed) return;
  await selectSession(routed.workspaceId, routed.sessionId, { push: false });
});

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && dom.sidebar.classList.contains('open')) closeSidebar();
});

let toastTimer;
function showToast(message) {
  window.clearTimeout(toastTimer);
  dom.toast.textContent = message;
  dom.toast.hidden = false;
  toastTimer = window.setTimeout(() => {
    dom.toast.hidden = true;
  }, 4000);
}

initialize();
