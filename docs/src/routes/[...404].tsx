import { Title, Meta } from "@solidjs/meta";
import { A } from "@solidjs/router";
import Layout from "~/components/Layout";

export default function NotFound() {
  return (
    <Layout>
      <Title>Page Not Found - Viban</Title>
      <Meta name="description" content="The page you're looking for doesn't exist." />

      <section class="min-h-[70vh] flex items-center justify-center">
        <div class="max-w-2xl mx-auto px-4 text-center">
          {/* 404 Visual */}
          <div class="mb-8">
            <div class="inline-flex items-center justify-center w-32 h-32 rounded-2xl bg-brand-500/10 border border-brand-500/20 mb-6">
              <span class="text-6xl font-bold bg-gradient-to-r from-brand-400 to-brand-600 bg-clip-text text-transparent">
                404
              </span>
            </div>
          </div>

          {/* Message */}
          <h1 class="text-4xl sm:text-5xl font-bold text-white mb-4">
            Page Not Found
          </h1>
          <p class="text-xl text-gray-400 mb-10 max-w-lg mx-auto">
            The page you're looking for doesn't exist or has been moved.
            Let's get you back on track.
          </p>

          {/* Action Buttons */}
          <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
            <A
              href="/"
              class="px-8 py-4 bg-brand-600 hover:bg-brand-500 text-white rounded-xl font-semibold text-lg transition-colors"
            >
              Go Home
            </A>
            <A
              href="/docs"
              class="px-8 py-4 bg-gray-800 hover:bg-gray-700 text-white rounded-xl font-semibold text-lg transition-colors"
            >
              View Documentation
            </A>
          </div>

          {/* Helpful Links */}
          <div class="mt-16 pt-8 border-t border-gray-800">
            <p class="text-gray-500 mb-4">Looking for something specific?</p>
            <div class="flex flex-wrap items-center justify-center gap-6">
              <A
                href="/docs/getting-started"
                class="text-brand-400 hover:text-brand-300 transition-colors"
              >
                Getting Started
              </A>
              <A
                href="/features"
                class="text-brand-400 hover:text-brand-300 transition-colors"
              >
                Features
              </A>
              <A
                href="/docs/api"
                class="text-brand-400 hover:text-brand-300 transition-colors"
              >
                API Reference
              </A>
              <A
                href="/contact"
                class="text-brand-400 hover:text-brand-300 transition-colors"
              >
                Contact
              </A>
            </div>
          </div>
        </div>
      </section>
    </Layout>
  );
}
