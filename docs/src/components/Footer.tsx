import { A } from "@solidjs/router";

export default function Footer() {
  return (
    <footer class="border-t border-gray-800 bg-gray-950">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
          {/* Brand */}
          <div class="col-span-1">
            <div class="flex items-center gap-2 mb-4">
              <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-brand-500 to-brand-700 flex items-center justify-center">
                <span class="text-white font-bold text-sm">V</span>
              </div>
              <span class="text-xl font-bold text-white">Viban</span>
            </div>
            <p class="text-gray-400 text-sm">
              AI-Powered Kanban for developers. Autonomous task execution with
              Claude Code integration.
            </p>
          </div>

          {/* Product */}
          <div>
            <h3 class="text-white font-semibold mb-4">Product</h3>
            <ul class="space-y-2">
              <li>
                <A href="/features" class="text-gray-400 hover:text-white text-sm transition-colors">
                  Features
                </A>
              </li>
              <li>
                <A href="/docs" class="text-gray-400 hover:text-white text-sm transition-colors">
                  Documentation
                </A>
              </li>
              <li>
                <A href="/docs/getting-started" class="text-gray-400 hover:text-white text-sm transition-colors">
                  Getting Started
                </A>
              </li>
            </ul>
          </div>

          {/* Resources */}
          <div>
            <h3 class="text-white font-semibold mb-4">Resources</h3>
            <ul class="space-y-2">
              <li>
                <a
                  href="https://github.com/nxy7/viban"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-gray-400 hover:text-white text-sm transition-colors"
                >
                  GitHub
                </a>
              </li>
              <li>
                <A href="/docs/api" class="text-gray-400 hover:text-white text-sm transition-colors">
                  API Reference
                </A>
              </li>
            </ul>
          </div>

          {/* Company */}
          <div>
            <h3 class="text-white font-semibold mb-4">Company</h3>
            <ul class="space-y-2">
              <li>
                <A href="/contact" class="text-gray-400 hover:text-white text-sm transition-colors">
                  Contact
                </A>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-12 pt-8 border-t border-gray-800">
          <p class="text-gray-500 text-sm text-center">
            &copy; {new Date().getFullYear()} Viban. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  );
}
