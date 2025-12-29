/**
 * VCS (Version Control System) types for provider-agnostic git integration.
 * Supports GitHub, GitLab, and other providers.
 */

export type VCSProvider = "github" | "gitlab";

export interface VCSRepo {
  id: string;
  name: string;
  full_name: string;
  description: string | null;
  private: boolean;
  html_url: string;
  clone_url: string;
  ssh_url: string;
  default_branch: string;
  owner: {
    login: string;
    avatar_url: string;
  };
  permissions: {
    admin: boolean;
    push: boolean;
    pull: boolean;
  };
  updated_at: string;
  pushed_at: string;
}

export interface VCSBranch {
  name: string;
  protected: boolean;
}

export interface PullRequest {
  id: string;
  number: number;
  title: string;
  body: string | null;
  state: "open" | "closed" | "merged";
  html_url: string;
  head_branch: string;
  base_branch: string;
  head_sha: string;
  created_at: string;
  updated_at: string;
  merged_at: string | null;
  user: {
    login: string;
    avatar_url: string;
  };
}

export interface PRComment {
  id: string;
  body: string;
  html_url: string;
  created_at: string;
  user: {
    login: string;
    avatar_url: string;
  };
}

export interface CreatePullRequestParams {
  title: string;
  body?: string;
  head: string;
  base: string;
}

export interface UpdatePullRequestParams {
  title?: string;
  body?: string;
  state?: "open" | "closed";
}

export interface CreateBoardWithRepoInput {
  name: string;
  description?: string;
  repo: {
    id: string;
    full_name: string;
    name: string;
    clone_url: string;
    html_url: string;
    default_branch: string;
  };
}
