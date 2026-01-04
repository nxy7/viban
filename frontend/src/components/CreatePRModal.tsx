import {
  createEffect,
  createResource,
  createSignal,
  For,
  on,
  Show,
} from "solid-js";
import { Button, Input, Select, Textarea } from "~/components/design-system";
import { type Branch, type Task, unwrap } from "~/hooks/useKanban";
import * as sdk from "~/lib/generated/ash";
import ErrorBanner from "./ui/ErrorBanner";
import { LoadingSpinner, PRIcon } from "./ui/Icons";
import Modal from "./ui/Modal";

const PREFERRED_BASE_BRANCH_KEY = "viban:preferred-base-branch";

function getPreferredBaseBranch(): string | null {
  try {
    return localStorage.getItem(PREFERRED_BASE_BRANCH_KEY);
  } catch {
    return null;
  }
}

function setPreferredBaseBranch(branch: string): void {
  try {
    localStorage.setItem(PREFERRED_BASE_BRANCH_KEY, branch);
  } catch {
    // Ignore localStorage errors
  }
}

interface CreatePRModalProps {
  isOpen: boolean;
  onClose: () => void;
  task: Task;
  onSuccess?: (prUrl: string) => void;
}

export default function CreatePRModal(props: CreatePRModalProps) {
  const [title, setTitle] = createSignal("");
  const [body, setBody] = createSignal("");
  const [baseBranch, setBaseBranch] = createSignal<string | undefined>();
  const [isSubmitting, setIsSubmitting] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);

  const [branches] = createResource(
    () => (props.isOpen ? props.task.id : null),
    async (taskId): Promise<Branch[]> => {
      if (!taskId) return [];
      try {
        const result = await sdk
          .list_branches({ input: { task_id: taskId } })
          .then(unwrap);
        return result as Branch[];
      } catch {
        return [];
      }
    },
  );

  createEffect(
    on(
      () => props.isOpen,
      (isOpen) => {
        if (isOpen) {
          setTitle(props.task.title);
          setBody(props.task.description || "");
          setError(null);
        }
      },
    ),
  );

  createEffect(() => {
    const branchList = branches();
    if (branchList && branchList.length > 0) {
      const current = baseBranch();
      const isCurrentValid =
        current && branchList.some((b) => b.name === current);

      if (!isCurrentValid) {
        const preferredBranch = getPreferredBaseBranch();
        const defaultBranch = branchList.find((b) => b.is_default);

        if (
          preferredBranch &&
          branchList.some((b) => b.name === preferredBranch)
        ) {
          setBaseBranch(preferredBranch);
        } else if (defaultBranch) {
          setBaseBranch(defaultBranch.name);
        } else {
          setBaseBranch(branchList[0].name);
        }
      }
    }
  });

  const handleBaseBranchChange = (branch: string) => {
    setBaseBranch(branch);
    setPreferredBaseBranch(branch);
  };

  const handleSubmit = async (e: Event) => {
    e.preventDefault();

    if (!title().trim()) {
      setError("Title is required");
      return;
    }

    setIsSubmitting(true);
    setError(null);

    const result = await sdk
      .create_task_pr({
        input: {
          task_id: props.task.id,
          title: title().trim(),
          body: body().trim() || undefined,
          base_branch: baseBranch(),
        },
      })
      .then(unwrap);

    setIsSubmitting(false);
    if (result) {
      props.onSuccess?.(result.pr_url);
      props.onClose();
    }
  };

  return (
    <Modal
      isOpen={props.isOpen}
      onClose={props.onClose}
      title="Create Pull Request"
    >
      <form onSubmit={handleSubmit} class="space-y-4">
        <div class="p-3 bg-gray-800 rounded-lg space-y-2">
          <div class="flex items-center gap-2">
            <PRIcon status="draft" class="w-4 h-4 text-gray-400" />
            <span class="text-sm text-gray-400">Head branch:</span>
            <span class="text-sm font-mono text-brand-400">
              {props.task.worktree_branch}
            </span>
          </div>
          <Show when={branches.loading}>
            <div class="flex items-center gap-2 text-sm text-gray-500">
              <LoadingSpinner class="h-3 w-3" />
              Loading branches...
            </div>
          </Show>
        </div>

        <Show when={branches() && branches()!.length > 0}>
          <div>
            <label
              for="baseBranch"
              class="block text-sm font-medium text-gray-300 mb-1"
            >
              Base branch
            </label>
            <Select
              id="baseBranch"
              value={baseBranch() || ""}
              onChange={(e) => handleBaseBranchChange(e.currentTarget.value)}
              fullWidth
            >
              <For each={branches()}>
                {(branch) => (
                  <option value={branch.name}>
                    {branch.name}
                    {branch.is_default ? " (default)" : ""}
                  </option>
                )}
              </For>
            </Select>
          </div>
        </Show>

        <div>
          <label
            for="title"
            class="block text-sm font-medium text-gray-300 mb-1"
          >
            Title *
          </label>
          <Input
            id="title"
            type="text"
            value={title()}
            onInput={(e) => setTitle(e.currentTarget.value)}
            placeholder="Enter PR title..."
            autofocus
          />
        </div>

        <div>
          <label
            for="body"
            class="block text-sm font-medium text-gray-300 mb-1"
          >
            Description
          </label>
          <Textarea
            id="body"
            value={body()}
            onInput={(e) => setBody(e.currentTarget.value)}
            rows={6}
            placeholder="Enter PR description..."
            resizable={false}
          />
        </div>

        <ErrorBanner message={error()} />

        <div class="flex gap-3 pt-2">
          <Button
            type="button"
            onClick={props.onClose}
            variant="secondary"
            fullWidth
          >
            Cancel
          </Button>
          <Button
            type="submit"
            disabled={isSubmitting() || !baseBranch()}
            loading={isSubmitting()}
            fullWidth
          >
            <Show when={!isSubmitting()}>
              {branches.loading ? "Loading..." : "Create PR"}
            </Show>
            <Show when={isSubmitting()}>Creating...</Show>
          </Button>
        </div>
      </form>
    </Modal>
  );
}
