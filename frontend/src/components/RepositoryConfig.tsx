import { createEffect, createSignal, on, Show } from "solid-js";
import * as sdk from "~/lib/generated/ash";
import ErrorBanner from "~/components/ui/ErrorBanner";
import { ChevronRightIcon, ExternalLinkIcon } from "~/components/ui/Icons";
import { type Repository, unwrap, useRepositories } from "~/lib/useKanban";

interface RepositoryConfigProps {
  boardId: string;
  singleMode?: boolean;
}

// Repository display component (shared between modes)
interface RepositoryDisplayProps {
  repository: Repository;
  compact?: boolean;
}

function getRepoUrl(provider: string, fullName: string): string | null {
  if (provider === "local") {
    return null;
  }
  if (provider === "gitlab") {
    return `https://gitlab.com/${fullName}`;
  }
  return `https://github.com/${fullName}`;
}

function RepositoryDisplay(props: RepositoryDisplayProps) {
  const isLocal = () => props.repository.provider === "local";
  const repoUrl = () =>
    getRepoUrl(props.repository.provider, props.repository.full_name ?? "");
  const displayName = () =>
    props.repository.full_name || props.repository.name || "Unnamed Repository";

  return (
    <div
      class={`${props.compact ? "p-3" : "p-4"} bg-gray-800${props.compact ? "" : "/50"} border border-gray-700 rounded-lg`}
    >
      <div class="flex-1 min-w-0">
        <Show
          when={!isLocal() && repoUrl()}
          fallback={<span class="font-medium text-white">{displayName()}</span>}
        >
          <a
            href={repoUrl()!}
            target="_blank"
            rel="noopener noreferrer"
            class="font-medium text-white hover:text-brand-400 transition-colors inline-flex items-center gap-1.5"
          >
            {displayName()}
            <ExternalLinkIcon class="w-3.5 h-3.5" />
          </a>
        </Show>
        <div class="flex flex-wrap gap-2 mt-2 text-xs text-gray-500">
          <Show when={isLocal() && props.repository.local_path}>
            <span
              class="px-2 py-0.5 bg-gray-700 rounded font-mono truncate max-w-full"
              title={props.repository.local_path ?? undefined}
            >
              {props.repository.local_path}
            </span>
          </Show>
          <Show
            when={!props.compact}
            fallback={
              <span class="px-2 py-0.5 bg-gray-700 rounded flex items-center gap-1">
                <ChevronRightIcon class="w-3 h-3" />
                {props.repository.default_branch}
              </span>
            }
          >
            <span class="px-2 py-0.5 bg-gray-700 rounded">
              Branch: {props.repository.default_branch}
            </span>
          </Show>
        </div>
      </div>
    </div>
  );
}

// Repository edit form component
interface RepositoryFormProps {
  name: string;
  onNameChange: (value: string) => void;
  path: string;
  onPathChange: (value: string) => void;
  defaultBranch: string;
  onDefaultBranchChange: (value: string) => void;
  isSaving: boolean;
  onSave: () => void;
  onCancel: () => void;
}

function RepositoryForm(props: RepositoryFormProps) {
  return (
    <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
      <div>
        <label class="block text-sm text-gray-400 mb-1">Name</label>
        <input
          type="text"
          value={props.name}
          onInput={(e) => props.onNameChange(e.currentTarget.value)}
          placeholder="e.g., My Project"
          class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
      </div>

      <div>
        <label class="block text-sm text-gray-400 mb-1">Path</label>
        <input
          type="text"
          value={props.path}
          onInput={(e) => props.onPathChange(e.currentTarget.value)}
          placeholder="/path/to/your/git/repository"
          class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white text-sm font-mono focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
        <p class="text-xs text-gray-500 mt-1">
          Absolute path to the git repository on the server
        </p>
      </div>

      <div>
        <label class="block text-sm text-gray-400 mb-1">Default Branch</label>
        <input
          type="text"
          value={props.defaultBranch}
          onInput={(e) => props.onDefaultBranchChange(e.currentTarget.value)}
          placeholder="main"
          class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
        />
        <p class="text-xs text-gray-500 mt-1">
          Base branch for creating new task worktrees
        </p>
      </div>

      <div class="flex gap-2 pt-2">
        <button
          onClick={props.onCancel}
          class="flex-1 py-2 px-4 bg-gray-700 hover:bg-gray-600 text-gray-300 rounded-lg text-sm transition-colors"
        >
          Cancel
        </button>
        <button
          onClick={props.onSave}
          disabled={props.isSaving}
          class="flex-1 py-2 px-4 bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 disabled:cursor-not-allowed text-white rounded-lg text-sm transition-colors"
        >
          {props.isSaving ? "Saving..." : "Save"}
        </button>
      </div>
    </div>
  );
}

// Empty state component
interface EmptyStateProps {
  onConfigure: () => void;
  singleMode?: boolean;
}

function EmptyState(props: EmptyStateProps) {
  return (
    <div
      class={`${props.singleMode ? "p-4 bg-gray-800/50" : "text-center py-4"} border border-dashed border-gray-700 rounded-lg`}
    >
      <p class="text-gray-500 text-sm mb-3">
        <Show
          when={props.singleMode}
          fallback='No repository configured. Click "Configure" to link a git repository.'
        >
          No repository configured. Link a git repository to enable task
          worktrees.
        </Show>
      </p>
      <button
        onClick={props.onConfigure}
        class={`px-3 py-1.5 bg-brand-600 hover:bg-brand-700 text-white text-sm rounded-lg transition-colors ${props.singleMode ? "" : "block mx-auto"}`}
      >
        Configure Repository
      </button>
    </div>
  );
}

export default function RepositoryConfig(props: RepositoryConfigProps) {
  const { repositories, isLoading } = useRepositories(() => props.boardId);
  const [isEditing, setIsEditing] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);

  // Form state
  const [name, setName] = createSignal("");
  const [path, setPath] = createSignal("");
  const [defaultBranch, setDefaultBranch] = createSignal("main");
  const [isSaving, setIsSaving] = createSignal(false);

  // Get the single repository
  const repository = () => repositories()[0] ?? null;

  // Reset form when repository changes - use `on` to prevent running on every signal change
  createEffect(
    on(
      repository,
      (repo) => {
        if (repo && !isEditing()) {
          setName(repo.name ?? "");
          setPath(repo.local_path ?? "");
          setDefaultBranch(repo.default_branch ?? "main");
        }
      },
      { defer: true },
    ),
  );

  const resetForm = () => {
    const repo = repository();
    if (repo) {
      setName(repo.name ?? "");
      setPath(repo.local_path ?? "");
      setDefaultBranch(repo.default_branch ?? "main");
    } else {
      setName("");
      setPath("");
      setDefaultBranch("main");
    }
    setError(null);
  };

  const startEdit = () => {
    resetForm();
    setIsEditing(true);
  };

  const cancelEdit = () => {
    resetForm();
    setIsEditing(false);
  };

  const handleSave = async () => {
    if (!name().trim() || !path().trim()) {
      setError("Name and path are required");
      return;
    }

    setIsSaving(true);
    setError(null);

    const repo = repository();
    let result;
    if (repo) {
      result = await sdk
        .update_repository({
          identity: repo.id,
          input: {
            name: name().trim(),
            local_path: path().trim(),
            default_branch: defaultBranch().trim() || "main",
          },
        })
        .then(unwrap);
    } else {
      result = await sdk
        .create_repository({
          input: {
            name: name().trim(),
            local_path: path().trim(),
            default_branch: defaultBranch().trim() || "main",
            board_id: props.boardId,
          },
        })
        .then(unwrap);
    }

    setIsSaving(false);
    if (result) {
      setIsEditing(false);
    }
  };

  const handleDelete = async () => {
    const repo = repository();
    if (!repo) return;
    if (
      !confirm("Are you sure you want to remove the repository configuration?")
    )
      return;

    const result = await sdk
      .destroy_repository({ identity: repo.id })
      .then(unwrap);
    if (result !== null) {
      resetForm();
    }
  };

  // Content renderer - shared between both modes
  const renderContent = () => (
    <>
      <Show when={isLoading()}>
        <div class="text-gray-400 text-sm">Loading...</div>
      </Show>

      <Show when={!isLoading()}>
        <Show
          when={isEditing()}
          fallback={
            <Show
              when={repository()}
              fallback={
                <EmptyState
                  onConfigure={startEdit}
                  singleMode={props.singleMode}
                />
              }
            >
              {(repo) => (
                <RepositoryDisplay
                  repository={repo()}
                  compact={!props.singleMode}
                />
              )}
            </Show>
          }
        >
          <RepositoryForm
            name={name()}
            onNameChange={setName}
            path={path()}
            onPathChange={setPath}
            defaultBranch={defaultBranch()}
            onDefaultBranchChange={setDefaultBranch}
            isSaving={isSaving()}
            onSave={handleSave}
            onCancel={cancelEdit}
          />
        </Show>
      </Show>
    </>
  );

  // Use Show instead of early return for proper SolidJS reactivity
  return (
    <Show
      when={props.singleMode}
      fallback={
        <div class="space-y-4">
          <p class="text-sm text-gray-400">
            Configure the git repository for creating task worktrees.
          </p>
          <ErrorBanner message={error()} />
          {renderContent()}
        </div>
      }
    >
      <div class="space-y-3">
        <ErrorBanner message={error()} />
        {renderContent()}
      </div>
    </Show>
  );
}
