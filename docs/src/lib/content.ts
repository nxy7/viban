import { marked } from "marked";

export interface DocMeta {
  title: string;
  description: string;
  slug: string;
}

export interface DocContent extends DocMeta {
  content: string;
  html: string;
}

// Parse frontmatter from markdown
function parseFrontmatter(content: string): { meta: Record<string, string>; content: string } {
  const frontmatterRegex = /^---\n([\s\S]*?)\n---\n([\s\S]*)$/;
  const match = content.match(frontmatterRegex);

  if (!match) {
    return { meta: {}, content };
  }

  const frontmatter = match[1];
  const body = match[2];

  const meta: Record<string, string> = {};
  frontmatter.split("\n").forEach((line) => {
    const [key, ...valueParts] = line.split(":");
    if (key && valueParts.length) {
      meta[key.trim()] = valueParts.join(":").trim();
    }
  });

  return { meta, content: body };
}

// Use Vite's import.meta.glob to load all markdown files at build time
// This works for both SSR and client-side by bundling the content
const markdownModules = import.meta.glob<string>("../../content/docs/*.md", {
  query: "?raw",
  import: "default",
  eager: true,
});

// Pre-process all docs at module initialization (build time)
const docsCache: Record<string, DocContent> = {};

for (const [path, content] of Object.entries(markdownModules)) {
  // Extract slug from path: ../../content/docs/getting-started.md -> getting-started
  const match = path.match(/\/([^/]+)\.md$/);
  if (match) {
    const slug = match[1];
    const { meta, content: body } = parseFrontmatter(content);
    const html = marked.parse(body) as string;

    docsCache[slug] = {
      title: meta.title || slug,
      description: meta.description || "",
      slug,
      content: body,
      html,
    };
  }
}

// Get doc content by slug - works on both server and client
export function getDocContent(slug: string): DocContent | null {
  return docsCache[slug] || null;
}

// Get all docs metadata
export function getAllDocsMeta(): DocMeta[] {
  return Object.values(docsCache).map(({ title, description, slug }) => ({
    title,
    description,
    slug: slug === "index" ? "" : slug,
  }));
}
