defmodule VibanWeb.Hologram.Components.CreatePRModal do
  use Hologram.Component

  prop :is_open, :boolean, default: false
  prop :task, :map, default: nil
  prop :branches, :list, default: []
  prop :is_loading_branches, :boolean, default: false
  prop :is_submitting, :boolean, default: false
  prop :error, :string, default: nil
  prop :title, :string, default: ""
  prop :body, :string, default: ""
  prop :base_branch, :string, default: nil

  @impl Hologram.Component
  def template do
    ~HOLO"""
    {%if @is_open && @task}
      <div class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="fixed inset-0 bg-black/60 transition-opacity" $click={action: :close_create_pr_modal, target: "page"}></div>
          <div class="relative transform overflow-hidden rounded-xl bg-gray-900 border border-gray-800 shadow-xl transition-all w-full max-w-lg">
            <div class="flex items-center justify-between p-4 border-b border-gray-800">
              <h3 class="text-lg font-semibold text-white">Create Pull Request</h3>
              <button
                type="button"
                class="text-gray-400 hover:text-white transition-colors"
                $click={action: :close_create_pr_modal, target: "page"}
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div class="p-4">
              <form $submit={action: :submit_create_pr, target: "page"} class="space-y-4">
                {%if @error}
                  <div class="p-3 bg-red-900/50 border border-red-800 rounded-lg text-red-200 text-sm">
                    {@error}
                  </div>
                {/if}

                <div class="p-3 bg-gray-800 rounded-lg space-y-2">
                  <div class="flex items-center gap-2">
                    <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <span class="text-sm text-gray-400">Head branch:</span>
                    {%if @task.worktree_branch}
                      <span class="text-sm font-mono text-white">{@task.worktree_branch}</span>
                    {%else}
                      <span class="text-sm text-gray-500 italic">No branch</span>
                    {/if}
                  </div>
                  {%if @is_loading_branches}
                    <div class="flex items-center gap-2 text-sm text-gray-500">
                      <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      Loading branches...
                    </div>
                  {/if}
                </div>

                {%if length(@branches) > 0}
                  <div>
                    <label for="baseBranch" class="block text-sm font-medium text-gray-300 mb-1">
                      Base branch
                    </label>
                    <select
                      id="baseBranch"
                      class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                      $change={action: :update_base_branch, target: "page"}
                    >
                      {%for branch <- @branches}
                        <option value={branch.name} selected={branch.name == @base_branch}>
                          {branch.name}{%if branch.is_default} (default){/if}
                        </option>
                      {/for}
                    </select>
                  </div>
                {/if}

                <div>
                  <label for="pr_title" class="block text-sm font-medium text-gray-300 mb-1">
                    Title *
                  </label>
                  <input
                    id="pr_title"
                    type="text"
                    class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                    placeholder="Enter PR title..."
                    value={@title}
                    $change={action: :update_pr_title, target: "page"}
                    autofocus
                  />
                </div>

                <div>
                  <label for="pr_body" class="block text-sm font-medium text-gray-300 mb-1">
                    Description
                  </label>
                  <textarea
                    id="pr_body"
                    rows="6"
                    class="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent resize-none"
                    placeholder="Enter PR description..."
                    $change={action: :update_pr_body, target: "page"}
                  >{@body}</textarea>
                </div>

                <div class="flex gap-3 pt-2">
                  <button
                    type="button"
                    class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-800 hover:bg-gray-700 rounded-lg transition-colors"
                    $click={action: :close_create_pr_modal, target: "page"}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    disabled={@is_submitting || @base_branch == nil || @title == ""}
                  >
                    {%if @is_submitting}
                      Creating...
                    {%else}
                      {%if @is_loading_branches}
                        Loading...
                      {%else}
                        Create PR
                      {/if}
                    {/if}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    {/if}
    """
  end
end
