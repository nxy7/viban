import { Title, Meta } from "@solidjs/meta";
import { A } from "@solidjs/router";
import Layout from "~/components/Layout";

function FeatureCard(props: {
  icon: string;
  title: string;
  description: string;
}) {
  return (
    <div class="p-6 rounded-xl bg-gray-900/50 border border-gray-800 hover:border-gray-700 transition-colors">
      <div class="w-12 h-12 rounded-lg bg-brand-500/10 flex items-center justify-center mb-4">
        <span class="text-2xl">{props.icon}</span>
      </div>
      <h3 class="text-lg font-semibold text-white mb-2">{props.title}</h3>
      <p class="text-gray-400">{props.description}</p>
    </div>
  );
}

export default function Home() {
  return (
    <Layout>
      <Title>Viban - AI-Powered Kanban for Developers</Title>
      <Meta
        name="description"
        content="Viban is an AI-powered Kanban board that lets Claude Code work on your tasks autonomously. Describe what you want, drag to 'In Progress', and let AI handle the rest."
      />

      {/* Hero Section */}
      <section class="relative overflow-hidden">
        {/* Background gradient */}
        <div class="absolute inset-0 bg-gradient-to-b from-brand-950/50 to-transparent pointer-events-none" />

        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-16">
          <div class="text-center max-w-4xl mx-auto">
            {/* Badge */}
            <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-brand-500/10 border border-brand-500/20 mb-8">
              <span class="w-2 h-2 rounded-full bg-brand-500 animate-pulse" />
              <span class="text-sm text-brand-400">
                Powered by Claude Code
              </span>
            </div>

            {/* Headline */}
            <h1 class="text-5xl sm:text-6xl lg:text-7xl font-bold text-white mb-6 leading-tight">
              AI-Powered Kanban
              <br />
              <span class="bg-gradient-to-r from-brand-400 to-brand-600 bg-clip-text text-transparent">
                for Developers
              </span>
            </h1>

            {/* Subheadline */}
            <p class="text-xl text-gray-400 mb-10 max-w-2xl mx-auto">
              Describe your task, drag it to "In Progress", and let Claude Code
              handle the implementation. Real-time streaming output, git
              worktrees, and autonomous execution.
            </p>

            {/* CTA Buttons */}
            <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
              <A
                href="/docs/getting-started"
                class="px-8 py-4 bg-brand-600 hover:bg-brand-500 text-white rounded-xl font-semibold text-lg transition-colors"
              >
                Get Started
              </A>
              <a
                href="https://github.com/nxy7/viban"
                target="_blank"
                rel="noopener noreferrer"
                class="px-8 py-4 bg-gray-800 hover:bg-gray-700 text-white rounded-xl font-semibold text-lg transition-colors flex items-center gap-2"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path
                    fill-rule="evenodd"
                    d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                    clip-rule="evenodd"
                  />
                </svg>
                View on GitHub
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section class="py-24 bg-gray-900/30">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-16">
            <h2 class="text-3xl sm:text-4xl font-bold text-white mb-4">
              Everything you need for AI-assisted development
            </h2>
            <p class="text-gray-400 text-lg max-w-2xl mx-auto">
              Viban combines the power of Kanban with autonomous AI agents to
              streamline your development workflow.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <FeatureCard
              icon="🤖"
              title="Autonomous Execution"
              description="Claude Code works on your tasks independently. Watch real-time streaming output as it codes, tests, and iterates."
            />
            <FeatureCard
              icon="🔀"
              title="Git Worktrees"
              description="Each task gets its own isolated git worktree. No branch conflicts, clean separation, easy review."
            />
            <FeatureCard
              icon="✨"
              title="Task Refinement"
              description="One-click AI refinement transforms simple descriptions into high-quality, actionable prompts."
            />
            <FeatureCard
              icon="🔄"
              title="Real-time Sync"
              description="Built on Electric SQL for instant synchronization. See changes the moment they happen."
            />
            <FeatureCard
              icon="🎯"
              title="Hook System"
              description="Automate workflows with hooks. Run tests on completion, deploy on merge, notify on error."
            />
            <FeatureCard
              icon="📡"
              title="MCP Integration"
              description="Connect to the Model Context Protocol for AI-to-AI communication and extended capabilities."
            />
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section class="py-24">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-16">
            <h2 class="text-3xl sm:text-4xl font-bold text-white mb-4">
              How It Works
            </h2>
            <p class="text-gray-400 text-lg max-w-2xl mx-auto">
              Three simple steps from idea to implementation.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div class="text-center">
              <div class="w-16 h-16 rounded-2xl bg-brand-500/10 border border-brand-500/20 flex items-center justify-center mx-auto mb-6">
                <span class="text-3xl font-bold text-brand-400">1</span>
              </div>
              <h3 class="text-xl font-semibold text-white mb-2">
                Create a Task
              </h3>
              <p class="text-gray-400">
                Write a simple description of what you want. Use the AI refine
                button to enhance it with best practices.
              </p>
            </div>

            <div class="text-center">
              <div class="w-16 h-16 rounded-2xl bg-brand-500/10 border border-brand-500/20 flex items-center justify-center mx-auto mb-6">
                <span class="text-3xl font-bold text-brand-400">2</span>
              </div>
              <h3 class="text-xl font-semibold text-white mb-2">
                Drag to In Progress
              </h3>
              <p class="text-gray-400">
                Move your task to the "In Progress" column. Claude Code
                automatically starts working on it.
              </p>
            </div>

            <div class="text-center">
              <div class="w-16 h-16 rounded-2xl bg-brand-500/10 border border-brand-500/20 flex items-center justify-center mx-auto mb-6">
                <span class="text-3xl font-bold text-brand-400">3</span>
              </div>
              <h3 class="text-xl font-semibold text-white mb-2">
                Review & Merge
              </h3>
              <p class="text-gray-400">
                Watch the AI work in real-time. Review the changes in the
                isolated worktree, then merge when ready.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section class="py-24 bg-gradient-to-b from-brand-950/50 to-gray-950">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="text-3xl sm:text-4xl font-bold text-white mb-6">
            Ready to supercharge your workflow?
          </h2>
          <p class="text-gray-400 text-lg mb-10">
            Get started with Viban today and let AI handle the heavy lifting.
          </p>
          <A
            href="/docs/getting-started"
            class="inline-flex px-8 py-4 bg-brand-600 hover:bg-brand-500 text-white rounded-xl font-semibold text-lg transition-colors"
          >
            Get Started Now
          </A>
        </div>
      </section>
    </Layout>
  );
}
