defmodule Viban.BoardNameGeneratorTest do
  use ExUnit.Case, async: true

  alias Viban.BoardNameGenerator

  describe "from_repo_name/1" do
    test "converts hyphenated repo name to title case" do
      assert BoardNameGenerator.from_repo_name("vibe-junction") == "Vibe Junction"
    end

    test "strips owner prefix from full_name" do
      assert BoardNameGenerator.from_repo_name("nxy7/vibe-junction") == "Vibe Junction"
    end

    test "handles underscores as word separators" do
      assert BoardNameGenerator.from_repo_name("my_awesome_project") == "My Awesome Project"
    end

    test "handles mixed separators" do
      assert BoardNameGenerator.from_repo_name("owner/my-awesome_project") == "My Awesome Project"
    end

    test "handles single word repo names" do
      assert BoardNameGenerator.from_repo_name("viban") == "Viban"
    end

    test "handles repo with organization prefix" do
      assert BoardNameGenerator.from_repo_name("anthropics/claude-code") == "Claude Code"
    end

    test "handles deeply nested paths" do
      assert BoardNameGenerator.from_repo_name("org/subgroup/my-repo") == "My Repo"
    end

    test "handles empty string" do
      assert BoardNameGenerator.from_repo_name("") == ""
    end

    test "handles nil" do
      assert BoardNameGenerator.from_repo_name(nil) == ""
    end

    test "preserves already capitalized words" do
      assert BoardNameGenerator.from_repo_name("AWS-SDK") == "AWS SDK"
    end

    test "handles numbers in repo name" do
      assert BoardNameGenerator.from_repo_name("project-v2") == "Project V2"
    end
  end
end
