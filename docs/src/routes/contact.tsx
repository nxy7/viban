import { Title, Meta } from "@solidjs/meta";
import { createSignal } from "solid-js";
import Layout from "~/components/Layout";

export default function Contact() {
  const [name, setName] = createSignal("");
  const [email, setEmail] = createSignal("");
  const [message, setMessage] = createSignal("");
  const [submitted, setSubmitted] = createSignal(false);

  const handleSubmit = (e: Event) => {
    e.preventDefault();
    // In a real app, you'd send this to your backend
    console.log({ name: name(), email: email(), message: message() });
    setSubmitted(true);
  };

  return (
    <Layout>
      <Title>Contact - Viban</Title>
      <Meta
        name="description"
        content="Get in touch with the Viban team for support, feedback, or partnership inquiries."
      />

      <section class="pt-24 pb-16">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="max-w-3xl mx-auto">
            {/* Header */}
            <div class="text-center mb-12">
              <h1 class="text-4xl sm:text-5xl font-bold text-white mb-4">
                Contact Us
              </h1>
              <p class="text-xl text-gray-400">
                Have questions or feedback? We'd love to hear from you.
              </p>
            </div>

            {/* Contact Options */}
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-16">
              <a
                href="https://github.com/nxy7/viban/issues"
                target="_blank"
                rel="noopener noreferrer"
                class="p-6 rounded-xl bg-gray-900/50 border border-gray-800 hover:border-gray-700 transition-colors text-center"
              >
                <div class="w-12 h-12 rounded-lg bg-brand-500/10 flex items-center justify-center mx-auto mb-4">
                  <svg
                    class="w-6 h-6 text-brand-400"
                    fill="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-white mb-2">
                  GitHub Issues
                </h3>
                <p class="text-gray-400 text-sm">
                  Report bugs or request features
                </p>
              </a>

              <a
                href="https://discord.gg/viban"
                target="_blank"
                rel="noopener noreferrer"
                class="p-6 rounded-xl bg-gray-900/50 border border-gray-800 hover:border-gray-700 transition-colors text-center"
              >
                <div class="w-12 h-12 rounded-lg bg-brand-500/10 flex items-center justify-center mx-auto mb-4">
                  <svg
                    class="w-6 h-6 text-brand-400"
                    fill="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028 14.09 14.09 0 0 0 1.226-1.994.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z" />
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-white mb-2">Discord</h3>
                <p class="text-gray-400 text-sm">
                  Join our community for help and discussions
                </p>
              </a>

              <a
                href="mailto:support@viban.dev"
                class="p-6 rounded-xl bg-gray-900/50 border border-gray-800 hover:border-gray-700 transition-colors text-center"
              >
                <div class="w-12 h-12 rounded-lg bg-brand-500/10 flex items-center justify-center mx-auto mb-4">
                  <svg
                    class="w-6 h-6 text-brand-400"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                    />
                  </svg>
                </div>
                <h3 class="text-lg font-semibold text-white mb-2">Email</h3>
                <p class="text-gray-400 text-sm">
                  Reach out directly for support
                </p>
              </a>
            </div>

            {/* Contact Form */}
            <div class="bg-gray-900/50 border border-gray-800 rounded-2xl p-8">
              <h2 class="text-2xl font-bold text-white mb-6">Send a Message</h2>

              {submitted() ? (
                <div class="text-center py-12">
                  <div class="w-16 h-16 rounded-full bg-green-500/10 flex items-center justify-center mx-auto mb-4">
                    <svg
                      class="w-8 h-8 text-green-400"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M5 13l4 4L19 7"
                      />
                    </svg>
                  </div>
                  <h3 class="text-xl font-semibold text-white mb-2">
                    Message Sent!
                  </h3>
                  <p class="text-gray-400">
                    Thanks for reaching out. We'll get back to you soon.
                  </p>
                </div>
              ) : (
                <form onSubmit={handleSubmit} class="space-y-6">
                  <div>
                    <label
                      for="name"
                      class="block text-sm font-medium text-gray-300 mb-2"
                    >
                      Name
                    </label>
                    <input
                      type="text"
                      id="name"
                      value={name()}
                      onInput={(e) => setName(e.currentTarget.value)}
                      required
                      class="w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                      placeholder="Your name"
                    />
                  </div>

                  <div>
                    <label
                      for="email"
                      class="block text-sm font-medium text-gray-300 mb-2"
                    >
                      Email
                    </label>
                    <input
                      type="email"
                      id="email"
                      value={email()}
                      onInput={(e) => setEmail(e.currentTarget.value)}
                      required
                      class="w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                      placeholder="you@example.com"
                    />
                  </div>

                  <div>
                    <label
                      for="message"
                      class="block text-sm font-medium text-gray-300 mb-2"
                    >
                      Message
                    </label>
                    <textarea
                      id="message"
                      value={message()}
                      onInput={(e) => setMessage(e.currentTarget.value)}
                      required
                      rows={5}
                      class="w-full px-4 py-3 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent resize-none"
                      placeholder="How can we help you?"
                    />
                  </div>

                  <button
                    type="submit"
                    class="w-full px-6 py-3 bg-brand-600 hover:bg-brand-500 text-white rounded-lg font-semibold transition-colors"
                  >
                    Send Message
                  </button>
                </form>
              )}
            </div>
          </div>
        </div>
      </section>
    </Layout>
  );
}
