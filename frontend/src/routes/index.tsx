import { A } from "@solidjs/router";
import { createSignal, For, Show } from "solid-js";
import ErrorBanner from "~/components/ui/ErrorBanner";
import { ClipboardListIcon, CloseIcon, PlusIcon } from "~/components/ui/Icons";
import { useAuth } from "~/hooks/useAuth";
import { useBoards } from "~/hooks/useKanban";
import { createBoardWithRepo, useVCSRepos, type VCSRepo } from "~/hooks/useVCS";
import { getErrorMessage } from "~/lib/errorUtils";

const SKELETON_COUNT = 3;

function GitHubIcon(props: { class?: string }) {
  return (
    <svg
      class={props.class ?? "w-5 h-5"}
      fill="currentColor"
      viewBox="0 0 24 24"
    >
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
    </svg>
  );
}

export default function Home() {
  const { boards, isLoading, error } = useBoards();
  const auth = useAuth();
  const [isCreating, setIsCreating] = createSignal(false);
  const [newBoardName, setNewBoardName] = createSignal("");
  const [newBoardDescription, setNewBoardDescription] = createSignal("");
  const [selectedRepo, setSelectedRepo] = createSignal<VCSRepo | null>(null);
  const [createError, setCreateError] = createSignal<string | null>(null);
  const [isSubmitting, setIsSubmitting] = createSignal(false);
  const [repoSearchQuery, setRepoSearchQuery] = createSignal("");

  const {
    repos,
    isLoading: isLoadingRepos,
    error: reposError,
    refetch: refetchRepos,
  } = useVCSRepos();

  const filteredRepos = () => {
    const allRepos = repos() || [];
    const query = repoSearchQuery().toLowerCase();
    if (!query) return allRepos;
    return allRepos.filter(
      (repo) =>
        repo.name.toLowerCase().includes(query) ||
        repo.full_name.toLowerCase().includes(query) ||
        (repo.description?.toLowerCase().includes(query) ?? false),
    );
  };

  const handleCreateBoard = async (e: Event) => {
    e.preventDefault();

    if (!newBoardName().trim()) {
      setCreateError("Board name is required");
      return;
    }

    const repo = selectedRepo();
    if (!repo) {
      setCreateError("Please select a repository");
      return;
    }

    setIsSubmitting(true);
    setCreateError(null);

    try {
      await createBoardWithRepo({
        name: newBoardName().trim(),
        description: newBoardDescription().trim() || undefined,
        repo: {
          id: repo.id,
          full_name: repo.full_name,
          name: repo.name,
          clone_url: repo.clone_url,
          html_url: repo.html_url,
          default_branch: repo.default_branch,
        },
      });

      resetForm();
      setIsCreating(false);
    } catch (err) {
      setCreateError(getErrorMessage(err, "Failed to create board"));
    } finally {
      setIsSubmitting(false);
    }
  };

  const startCreating = () => {
    if (!auth.isAuthenticated()) {
      auth.login();
      return;
    }
    setIsCreating(true);
    refetchRepos();
  };

  const resetForm = () => {
    setNewBoardName("");
    setNewBoardDescription("");
    setSelectedRepo(null);
    setRepoSearchQuery("");
    setCreateError(null);
  };

  return (
    <main class="min-h-screen bg-gray-950 text-white p-8">
      <div class="max-w-4xl mx-auto">
        {/* Header */}
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-3xl font-bold text-brand-500">Viban Kanban</h1>
            <p class="text-gray-400 mt-1">Manage your projects with ease</p>
          </div>
          <div class="flex items-center gap-4">
            {/* User Menu */}
            <Show
              when={auth.isAuthenticated()}
              fallback={
                <button
                  onClick={() => auth.login()}
                  disabled={auth.isLoading()}
                  class="px-4 py-2 bg-gray-800 hover:bg-gray-700 text-white rounded-lg transition-colors flex items-center gap-2"
                >
                  <GitHubIcon class="w-5 h-5" />
                  Sign in with GitHub
                </button>
              }
            >
              {(() => {
                const user = auth.user();
                return (
                  <div class="flex items-center gap-3">
                    <Show when={user?.avatar_url}>
                      <img
                        src={user?.avatar_url ?? ""}
                        alt={user?.provider_login ?? "User"}
                        class="w-8 h-8 rounded-full"
                      />
                    </Show>
                    <span class="text-gray-300">{user?.provider_login}</span>
                    <button
                      onClick={() => auth.logout()}
                      class="text-gray-400 hover:text-gray-200 text-sm"
                    >
                      Logout
                    </button>
                  </div>
                );
              })()}
            </Show>

            {/* New Board Button */}
            <button
              onClick={startCreating}
              class="px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-lg transition-colors flex items-center gap-2"
            >
              <PlusIcon class="w-5 h-5" />
              New Board
            </button>
          </div>
        </div>

        {/* Create Board Form */}
        <Show when={isCreating()}>
          <div class="bg-gray-900/50 border border-gray-800 rounded-xl p-6 mb-8">
            <h2 class="text-lg font-semibold text-white mb-4">
              Create New Board
            </h2>
            <form onSubmit={handleCreateBoard} class="space-y-4">
              {/* Board Name */}
              <div>
                <label
                  for="boardName"
                  class="block text-sm font-medium text-gray-300 mb-1"
                >
                  Board Name *
                </label>
                <input
                  id="boardName"
                  type="text"
                  value={newBoardName()}
                  onInput={(e) => setNewBoardName(e.currentTarget.value)}
                  placeholder="Enter board name..."
                  class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                  autofocus
                />
              </div>

              {/* Board Description */}
              <div>
                <label
                  for="boardDescription"
                  class="block text-sm font-medium text-gray-300 mb-1"
                >
                  Description
                </label>
                <textarea
                  id="boardDescription"
                  value={newBoardDescription()}
                  onInput={(e) => setNewBoardDescription(e.currentTarget.value)}
                  placeholder="Enter board description..."
                  rows={2}
                  class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
                />
              </div>

              {/* Repository Selection */}
              <div>
                <label class="block text-sm font-medium text-gray-300 mb-1">
                  Repository *
                </label>

                <Show
                  when={selectedRepo()}
                  fallback={
                    <div class="space-y-2">
                      {/* Search Input */}
                      <input
                        type="text"
                        value={repoSearchQuery()}
                        onInput={(e) =>
                          setRepoSearchQuery(e.currentTarget.value)
                        }
                        placeholder="Search repositories..."
                        class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                      />

                      {/* Repos List */}
                      <div class="max-h-64 overflow-y-auto bg-gray-800 border border-gray-700 rounded-lg">
                        <Show
                          when={!isLoadingRepos()}
                          fallback={
                            <div class="p-4 text-center text-gray-400">
                              <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-brand-500 mx-auto mb-2" />
                              Loading repositories...
                            </div>
                          }
                        >
                          <Show when={reposError()}>
                            <div class="p-4 text-center text-red-400">
                              {reposError()}
                            </div>
                          </Show>

                          <Show
                            when={filteredRepos().length === 0 && !reposError()}
                          >
                            <div class="p-4 text-center text-gray-400">
                              No repositories found
                            </div>
                          </Show>

                          <For each={filteredRepos()}>
                            {(repo) => (
                              <button
                                type="button"
                                onClick={() => setSelectedRepo(repo)}
                                class="w-full p-3 text-left hover:bg-gray-700 border-b border-gray-700 last:border-b-0 transition-colors"
                              >
                                <div class="flex items-center gap-2">
                                  <img
                                    src={repo.owner.avatar_url}
                                    alt={repo.owner.login}
                                    class="w-5 h-5 rounded-full"
                                  />
                                  <span class="font-medium text-white">
                                    {repo.full_name}
                                  </span>
                                  <Show when={repo.private}>
                                    <span class="px-1.5 py-0.5 text-xs bg-amber-500/20 text-amber-400 rounded">
                                      Private
                                    </span>
                                  </Show>
                                </div>
                                <Show when={repo.description}>
                                  <p class="text-sm text-gray-400 mt-1 line-clamp-1">
                                    {repo.description}
                                  </p>
                                </Show>
                                <p class="text-xs text-gray-500 mt-1">
                                  Default branch: {repo.default_branch}
                                </p>
                              </button>
                            )}
                          </For>
                        </Show>
                      </div>
                    </div>
                  }
                >
                  {/* Selected Repo Display */}
                  {(() => {
                    const repo = selectedRepo();
                    if (!repo) return null;
                    return (
                      <div class="flex items-center justify-between p-3 bg-gray-800 border border-brand-500/50 rounded-lg">
                        <div class="flex items-center gap-2">
                          <img
                            src={repo.owner.avatar_url}
                            alt={repo.owner.login}
                            class="w-5 h-5 rounded-full"
                          />
                          <span class="font-medium text-white">
                            {repo.full_name}
                          </span>
                          <Show when={repo.private}>
                            <span class="px-1.5 py-0.5 text-xs bg-amber-500/20 text-amber-400 rounded">
                              Private
                            </span>
                          </Show>
                        </div>
                        <button
                          type="button"
                          onClick={() => setSelectedRepo(null)}
                          class="text-gray-400 hover:text-gray-200"
                        >
                          <CloseIcon class="w-5 h-5" />
                        </button>
                      </div>
                    );
                  })()}
                </Show>
              </div>

              {/* Error Display */}
              <ErrorBanner message={createError()} />

              {/* Form Actions */}
              <div class="flex gap-3">
                <button
                  type="button"
                  onClick={() => {
                    resetForm();
                    setIsCreating(false);
                  }}
                  class="flex-1 py-2 px-4 bg-gray-800 hover:bg-gray-700 text-gray-300 rounded-lg transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting()}
                  class="flex-1 py-2 px-4 bg-brand-600 hover:bg-brand-700 disabled:bg-brand-800 disabled:cursor-not-allowed text-white rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  <Show when={isSubmitting()} fallback="Create Board">
                    <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                    Creating...
                  </Show>
                </button>
              </div>
            </form>
          </div>
        </Show>

        {/* Boards List */}
        <Show
          when={!isLoading()}
          fallback={
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <For each={Array.from({ length: SKELETON_COUNT }, (_, i) => i)}>
                {() => (
                  <div class="bg-gray-900/50 border border-gray-800 rounded-xl p-6 animate-pulse">
                    <div class="h-6 w-32 bg-gray-800 rounded mb-2" />
                    <div class="h-4 w-48 bg-gray-800/50 rounded" />
                  </div>
                )}
              </For>
            </div>
          }
        >
          <Show
            when={!error()}
            fallback={
              <div class="bg-red-500/10 border border-red-500/30 rounded-xl p-6 text-red-400">
                Error loading boards. Please try again.
              </div>
            }
          >
            <Show
              when={boards().length > 0}
              fallback={
                <div class="bg-gray-900/50 border border-gray-800 border-dashed rounded-xl p-12 text-center">
                  <ClipboardListIcon class="w-12 h-12 text-gray-600 mx-auto mb-4" />
                  <h3 class="text-lg font-medium text-gray-400 mb-2">
                    No boards yet
                  </h3>
                  <p class="text-gray-500 mb-4">
                    <Show
                      when={auth.isAuthenticated()}
                      fallback="Sign in to create your first board"
                    >
                      Create your first board to get started
                    </Show>
                  </p>
                  <button
                    onClick={startCreating}
                    class="px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white rounded-lg transition-colors"
                  >
                    <Show
                      when={auth.isAuthenticated()}
                      fallback="Sign in with GitHub"
                    >
                      Create a Board
                    </Show>
                  </button>
                </div>
              }
            >
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <For each={boards()}>
                  {(board) => (
                    <A
                      href={`/board/${board.id}`}
                      class="block bg-gray-900/50 border border-gray-800 rounded-xl p-6 hover:border-brand-500/50 hover:bg-gray-900 transition-all group"
                    >
                      <h3 class="text-lg font-semibold text-white group-hover:text-brand-400 transition-colors">
                        {board.name}
                      </h3>
                      <Show when={board.description}>
                        <p class="text-gray-400 text-sm mt-1 line-clamp-2">
                          {board.description}
                        </p>
                      </Show>
                      <p class="text-xs text-gray-500 mt-4">
                        Updated{" "}
                        {new Date(board.updated_at).toLocaleDateString()}
                      </p>
                    </A>
                  )}
                </For>
              </div>
            </Show>
          </Show>
        </Show>

        {/* Footer */}
        <footer class="mt-16 pt-8 border-t border-gray-800 text-center text-gray-500 text-sm">
          <p>Powered by Elixir + Ash Framework + Phoenix Sync + SolidJS</p>
        </footer>
      </div>
    </main>
  );
}
