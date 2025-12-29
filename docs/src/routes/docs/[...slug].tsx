import { Title, Meta } from "@solidjs/meta";
import { useParams } from "@solidjs/router";
import { Show } from "solid-js";
import DocsLayout from "~/components/DocsLayout";
import { getDocContent } from "~/lib/content";

export default function DocPage() {
  const params = useParams<{ slug?: string }>();
  const slug = () => params.slug || "index";
  // getDocContent reads from the pre-built cache (bundled at build time via import.meta.glob)
  const doc = () => getDocContent(slug());

  return (
    <DocsLayout>
      <Show when={doc()} fallback={<NotFound />}>
        {(docData) => (
          <>
            <Title>{docData().title} - Viban Docs</Title>
            <Meta name="description" content={docData().description} />
            <div
              class="prose prose-lg prose-invert max-w-none
                     prose-headings:text-white prose-headings:font-bold
                     prose-h1:text-4xl prose-h1:mb-4
                     prose-h2:text-2xl prose-h2:mt-8 prose-h2:mb-4
                     prose-h3:text-xl prose-h3:mt-6 prose-h3:mb-3
                     prose-p:text-gray-300 prose-p:leading-relaxed
                     prose-a:text-brand-400 prose-a:no-underline hover:prose-a:underline
                     prose-strong:text-white
                     prose-code:text-brand-300 prose-code:bg-gray-800 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded
                     prose-pre:bg-gray-900 prose-pre:border prose-pre:border-gray-700
                     prose-ul:text-gray-300 prose-ol:text-gray-300
                     prose-li:marker:text-gray-500
                     prose-table:border-collapse
                     prose-th:bg-gray-800 prose-th:px-4 prose-th:py-2 prose-th:text-left prose-th:font-semibold
                     prose-td:px-4 prose-td:py-2 prose-td:border-b prose-td:border-gray-700"
              innerHTML={docData().html}
            />
          </>
        )}
      </Show>
    </DocsLayout>
  );
}

function NotFound() {
  return (
    <>
      <Title>Not Found - Viban Docs</Title>
      <div class="text-center py-20">
        <h1 class="text-4xl font-bold text-white mb-4">Page Not Found</h1>
        <p class="text-gray-400 mb-8">
          The documentation page you're looking for doesn't exist.
        </p>
        <a
          href="/docs"
          class="px-6 py-3 bg-brand-600 hover:bg-brand-500 text-white rounded-lg font-medium transition-colors"
        >
          Go to Documentation
        </a>
      </div>
    </>
  );
}
