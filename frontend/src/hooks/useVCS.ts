import { createResource } from "solid-js";
import type {
  CreateBoardWithRepoInput,
  CreatePullRequestParams,
  PRComment,
  PullRequest,
  UpdatePullRequestParams,
  VCSBranch,
  VCSRepo,
} from "~/lib/types/vcs";

// Re-export types for convenience
export type {
  CreateBoardWithRepoInput,
  CreatePullRequestParams,
  PRComment,
  PullRequest,
  UpdatePullRequestParams,
  VCSBranch,
  VCSProvider,
  VCSRepo,
} from "~/lib/types/vcs";

/** Pull request state filter options */
type PRState = "open" | "closed" | "all";

/**
 * Standard API response shape.
 * Uses index signature for dynamic data keys.
 */
interface ApiResponse {
  ok: boolean;
  error?: string;
  [key: string]: unknown;
}

/**
 * Generic fetch helper with consistent error handling.
 * Extracts data from the specified key in the response.
 */
async function apiFetch<T>(
  url: string,
  options: RequestInit,
  dataKey: string,
  errorMessage: string,
): Promise<T> {
  const response = await fetch(url, {
    credentials: "include",
    ...options,
  });

  const data: ApiResponse = await response.json();

  if (!data.ok) {
    throw new Error((data.error as string | undefined) ?? errorMessage);
  }

  return data[dataKey] as T;
}

/** HTTP methods for mutation operations */
type MutationMethod = "POST" | "PATCH";

/**
 * POST/PATCH helper for mutation operations.
 * Automatically handles JSON serialization and headers.
 */
async function apiMutate<T>(
  url: string,
  method: MutationMethod,
  body: Record<string, unknown> | undefined,
  dataKey: string,
  errorMessage: string,
): Promise<T> {
  return apiFetch<T>(
    url,
    {
      method,
      headers: { "Content-Type": "application/json" },
      ...(body ? { body: JSON.stringify(body) } : {}),
    },
    dataKey,
    errorMessage,
  );
}

// Repository operations

async function fetchRepos(): Promise<VCSRepo[]> {
  return apiFetch<VCSRepo[]>(
    "/api/vcs/repos",
    {},
    "repos",
    "Failed to fetch repositories",
  );
}

async function fetchBranches(
  owner: string,
  repo: string,
): Promise<VCSBranch[]> {
  return apiFetch<VCSBranch[]>(
    `/api/vcs/repos/${owner}/${repo}/branches`,
    {},
    "branches",
    "Failed to fetch branches",
  );
}

export function useVCSRepos() {
  const [repos, { refetch }] = createResource(fetchRepos);

  return {
    repos,
    isLoading: () => repos.loading,
    error: () => repos.error?.message,
    refetch,
  };
}

export function useVCSBranches(
  owner: () => string | undefined,
  repo: () => string | undefined,
) {
  const fetcher = async () => {
    const o = owner();
    const r = repo();
    if (!o || !r) return [];
    return fetchBranches(o, r);
  };

  const [branches, { refetch }] = createResource(
    () => ({ owner: owner(), repo: repo() }),
    fetcher,
  );

  return {
    branches,
    isLoading: () => branches.loading,
    error: () => branches.error?.message,
    refetch,
  };
}

// Pull request operations

async function fetchPullRequests(
  owner: string,
  repo: string,
  state: PRState = "open",
): Promise<PullRequest[]> {
  return apiFetch<PullRequest[]>(
    `/api/vcs/repos/${owner}/${repo}/pulls?state=${state}`,
    {},
    "pull_requests",
    "Failed to fetch pull requests",
  );
}

async function fetchPullRequest(
  owner: string,
  repo: string,
  prId: string | number,
): Promise<PullRequest> {
  return apiFetch<PullRequest>(
    `/api/vcs/repos/${owner}/${repo}/pulls/${prId}`,
    {},
    "pull_request",
    "Failed to fetch pull request",
  );
}

export async function createPullRequest(
  owner: string,
  repo: string,
  params: CreatePullRequestParams,
): Promise<PullRequest> {
  return apiMutate<PullRequest>(
    `/api/vcs/repos/${owner}/${repo}/pulls`,
    "POST",
    params,
    "pull_request",
    "Failed to create pull request",
  );
}

export async function updatePullRequest(
  owner: string,
  repo: string,
  prId: string | number,
  params: UpdatePullRequestParams,
): Promise<PullRequest> {
  return apiMutate<PullRequest>(
    `/api/vcs/repos/${owner}/${repo}/pulls/${prId}`,
    "PATCH",
    params,
    "pull_request",
    "Failed to update pull request",
  );
}

export function usePullRequests(
  owner: () => string | undefined,
  repo: () => string | undefined,
  state: () => PRState = () => "open",
) {
  const fetcher = async () => {
    const o = owner();
    const r = repo();
    if (!o || !r) return [];
    return fetchPullRequests(o, r, state());
  };

  const [pullRequests, { refetch }] = createResource(
    () => ({ owner: owner(), repo: repo(), state: state() }),
    fetcher,
  );

  return {
    pullRequests,
    isLoading: () => pullRequests.loading,
    error: () => pullRequests.error?.message,
    refetch,
  };
}

export function usePullRequest(
  owner: () => string | undefined,
  repo: () => string | undefined,
  prId: () => string | number | undefined,
) {
  const fetcher = async () => {
    const o = owner();
    const r = repo();
    const id = prId();
    if (!o || !r || !id) return null;
    return fetchPullRequest(o, r, id);
  };

  const [pullRequest, { refetch }] = createResource(
    () => ({ owner: owner(), repo: repo(), prId: prId() }),
    fetcher,
  );

  return {
    pullRequest,
    isLoading: () => pullRequest.loading,
    error: () => pullRequest.error?.message,
    refetch,
  };
}

// Comment operations

async function fetchPRComments(
  owner: string,
  repo: string,
  prId: string | number,
): Promise<PRComment[]> {
  return apiFetch<PRComment[]>(
    `/api/vcs/repos/${owner}/${repo}/pulls/${prId}/comments`,
    {},
    "comments",
    "Failed to fetch comments",
  );
}

export async function createPRComment(
  owner: string,
  repo: string,
  prId: string | number,
  body: string,
): Promise<PRComment> {
  return apiMutate<PRComment>(
    `/api/vcs/repos/${owner}/${repo}/pulls/${prId}/comments`,
    "POST",
    { body },
    "comment",
    "Failed to create comment",
  );
}

export function usePRComments(
  owner: () => string | undefined,
  repo: () => string | undefined,
  prId: () => string | number | undefined,
) {
  const fetcher = async () => {
    const o = owner();
    const r = repo();
    const id = prId();
    if (!o || !r || !id) return [];
    return fetchPRComments(o, r, id);
  };

  const [comments, { refetch }] = createResource(
    () => ({ owner: owner(), repo: repo(), prId: prId() }),
    fetcher,
  );

  return {
    comments,
    isLoading: () => comments.loading,
    error: () => comments.error?.message,
    refetch,
  };
}

// Board creation

interface CreateBoardResponse {
  board: {
    id: string;
    name: string;
  };
}

export async function createBoardWithRepo(
  input: CreateBoardWithRepoInput,
): Promise<CreateBoardResponse> {
  const response = await fetch("/api/boards", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify(input),
  });

  const data = await response.json();

  if (!data.ok) {
    throw new Error(data.error || "Failed to create board");
  }

  // Return full response since it contains multiple fields
  return data as CreateBoardResponse;
}
