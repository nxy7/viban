import { JSX } from "solid-js";
import Header from "./Header";
import Footer from "./Footer";
import DocsSidebar from "./DocsSidebar";

interface DocsLayoutProps {
  children: JSX.Element;
}

export default function DocsLayout(props: DocsLayoutProps) {
  return (
    <div class="min-h-screen flex flex-col">
      <Header />
      <div class="flex-1 pt-16 flex">
        <DocsSidebar />
        <main class="flex-1 min-w-0">
          <div class="max-w-4xl mx-auto px-8 py-12">
            <article class="prose prose-lg prose-invert max-w-none">
              {props.children}
            </article>
          </div>
        </main>
      </div>
      <Footer />
    </div>
  );
}
