import { JSX } from "solid-js";
import Header from "./Header";
import Footer from "./Footer";

interface LayoutProps {
  children: JSX.Element;
}

export default function Layout(props: LayoutProps) {
  return (
    <div class="min-h-screen flex flex-col">
      <Header />
      <main class="flex-1 pt-16">{props.children}</main>
      <Footer />
    </div>
  );
}
