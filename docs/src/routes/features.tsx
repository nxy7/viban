import { Title, Meta } from "@solidjs/meta";
import Layout from "~/components/Layout";

function FeatureSection(props: {
  title: string;
  description: string;
  features: { title: string; description: string }[];
  reversed?: boolean;
}) {
  return (
    <section class="py-20 border-b border-gray-800">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-16">
          <h2 class="text-3xl sm:text-4xl font-bold text-white mb-4">
            {props.title}
          </h2>
          <p class="text-gray-400 text-lg max-w-2xl mx-auto">
            {props.description}
          </p>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {props.features.map((feature) => (
            <div class="p-6 rounded-xl bg-gray-900/50 border border-gray-800">
              <h3 class="text-lg font-semibold text-white mb-2">
                {feature.title}
              </h3>
              <p class="text-gray-400">{feature.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export default function Features() {
  return (
    <Layout>
      <Title>Features - Viban</Title>
      <Meta
        name="description"
        content="Explore Viban's powerful features for AI-powered task management and autonomous development."
      />

      {/* Hero */}
      <section class="pt-24 pb-16 bg-gradient-to-b from-brand-950/50 to-transparent">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h1 class="text-5xl sm:text-6xl font-bold text-white mb-6">
            Features
          </h1>
          <p class="text-xl text-gray-400 max-w-2xl mx-auto">
            Everything you need to supercharge your development workflow with
            AI-powered automation.
          </p>
        </div>
      </section>

      {/* AI Execution */}
      <FeatureSection
        title="Autonomous AI Execution"
        description="Let AI handle the implementation while you focus on what matters."
        features={[
          {
            title: "Multiple AI Agents",
            description:
              "Choose from Claude Code, Codex, Gemini, or Cursor Agent based on your needs.",
          },
          {
            title: "Real-time Streaming",
            description:
              "Watch AI work in real-time with live output streaming to your browser.",
          },
          {
            title: "Parallel Execution",
            description:
              "Run multiple tasks simultaneously with isolated environments.",
          },
          {
            title: "Smart Retries",
            description:
              "Automatic error handling and intelligent retry mechanisms.",
          },
          {
            title: "Resource Management",
            description:
              "Configurable concurrency limits and timeout settings.",
          },
          {
            title: "Execution History",
            description:
              "Complete audit trail of all AI actions and outputs.",
          },
        ]}
      />

      {/* Task Management */}
      <FeatureSection
        title="Intelligent Task Management"
        description="Organize and refine your work with AI assistance."
        features={[
          {
            title: "AI Task Refinement",
            description:
              "Transform simple ideas into detailed, actionable specifications with one click.",
          },
          {
            title: "Kanban Workflow",
            description:
              "Visual board with drag-and-drop for intuitive task management.",
          },
          {
            title: "Real-time Sync",
            description:
              "Instant synchronization across all clients with Electric SQL.",
          },
          {
            title: "Task Templates",
            description:
              "Create reusable templates for common task types.",
          },
          {
            title: "Priority Management",
            description:
              "Organize tasks by priority and let AI handle them in order.",
          },
          {
            title: "Status Tracking",
            description:
              "Clear visibility into task progress from creation to completion.",
          },
        ]}
      />

      {/* Git Integration */}
      <FeatureSection
        title="Seamless Git Integration"
        description="Professional-grade version control built into every task."
        features={[
          {
            title: "Git Worktrees",
            description:
              "Each task gets its own isolated worktree. No branch conflicts.",
          },
          {
            title: "Automatic Branching",
            description:
              "Tasks automatically create branches from your base branch.",
          },
          {
            title: "GitHub Integration",
            description:
              "Connect repositories and automatically create pull requests.",
          },
          {
            title: "Clean Rollback",
            description:
              "Easily discard changes if a task doesn't work out.",
          },
          {
            title: "Merge Automation",
            description:
              "One-click merge when you're happy with the changes.",
          },
          {
            title: "Branch Protection",
            description:
              "Respects your repository's branch protection rules.",
          },
        ]}
      />

      {/* Automation */}
      <FeatureSection
        title="Powerful Automation"
        description="Build custom workflows with hooks and integrations."
        features={[
          {
            title: "Composable Hook System",
            description:
              "Composable hook system allowing creation of tailored workflows. Run custom scripts on task events like start, complete, or merge.",
          },
          {
            title: "CI/CD Integration",
            description:
              "Trigger pipelines automatically when tasks complete.",
          },
          {
            title: "Notifications",
            description:
              "Send alerts to Slack, Discord, or any webhook endpoint.",
          },
          {
            title: "Test Automation",
            description:
              "Automatically run tests after AI completes its work.",
          },
          {
            title: "Deploy Previews",
            description:
              "Auto-deploy preview environments for review.",
          },
          {
            title: "Custom Scripts",
            description:
              "Run any shell script or HTTP request as part of your workflow.",
          },
        ]}
      />

      {/* Developer Experience */}
      <FeatureSection
        title="Developer Experience"
        description="Built by developers, for developers."
        features={[
          {
            title: "MCP Protocol",
            description:
              "AI-to-AI communication for advanced automation scenarios.",
          },
          {
            title: "REST API",
            description:
              "Full API access for custom integrations and tooling.",
          },
          {
            title: "Self-Hostable",
            description:
              "Run Viban on your own infrastructure with full control.",
          },
          {
            title: "Open Source",
            description:
              "Transparent codebase you can audit, modify, and contribute to.",
          },
          {
            title: "Fast Setup",
            description:
              "Get started in minutes with minimal configuration.",
          },
          {
            title: "Active Community",
            description:
              "Join a growing community of developers using AI for development.",
          },
        ]}
      />

      {/* CTA */}
      <section class="py-24 bg-gradient-to-b from-gray-950 to-brand-950/30">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="text-3xl sm:text-4xl font-bold text-white mb-6">
            Ready to get started?
          </h2>
          <p class="text-gray-400 text-lg mb-10">
            Set up Viban in minutes and start letting AI handle your
            development tasks.
          </p>
          <a
            href="/docs/getting-started"
            class="inline-flex px-8 py-4 bg-brand-600 hover:bg-brand-500 text-white rounded-xl font-semibold text-lg transition-colors"
          >
            View Documentation
          </a>
        </div>
      </section>
    </Layout>
  );
}
