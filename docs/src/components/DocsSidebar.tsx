import { A, useLocation } from "@solidjs/router";
import { For, createMemo } from "solid-js";

interface NavItem {
  title: string;
  href: string;
}

interface NavSection {
  title: string;
  items: NavItem[];
}

const navigation: NavSection[] = [
  {
    title: "Getting Started",
    items: [
      { title: "Introduction", href: "/docs" },
      { title: "Quick Start", href: "/docs/getting-started" },
      { title: "Installation", href: "/docs/installation" },
    ],
  },
  {
    title: "Core Concepts",
    items: [
      { title: "Boards & Tasks", href: "/docs/boards-and-tasks" },
      { title: "AI Agents", href: "/docs/ai-agents" },
      { title: "Hooks System", href: "/docs/hooks" },
    ],
  },
  {
    title: "Guides",
    items: [
      { title: "Task Refinement", href: "/docs/task-refinement" },
      { title: "Git Integration", href: "/docs/git-integration" },
      { title: "Custom Hooks", href: "/docs/custom-hooks" },
    ],
  },
  {
    title: "API Reference",
    items: [
      { title: "REST API", href: "/docs/api" },
      { title: "MCP Server", href: "/docs/mcp" },
    ],
  },
];

function NavLink(props: { href: string; title: string }) {
  const location = useLocation();
  const isActive = () => location.pathname === props.href;

  return (
    <li>
      <A
        href={props.href}
        class="block px-3 py-2 rounded-lg text-sm transition-colors"
        classList={{
          "bg-brand-500/10 text-brand-400 border-l-2 border-brand-500": isActive(),
          "text-gray-400 hover:text-white hover:bg-gray-800": !isActive(),
        }}
      >
        {props.title}
      </A>
    </li>
  );
}

export default function DocsSidebar() {
  return (
    <nav class="w-64 flex-shrink-0 border-r border-gray-800 bg-gray-950">
      <div class="sticky top-16 p-6 h-[calc(100vh-4rem)] overflow-y-auto">
        <For each={navigation}>
          {(section) => (
            <div class="mb-6">
              <h3 class="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                {section.title}
              </h3>
              <ul class="space-y-1">
                <For each={section.items}>
                  {(item) => <NavLink href={item.href} title={item.title} />}
                </For>
              </ul>
            </div>
          )}
        </For>
      </div>
    </nav>
  );
}
