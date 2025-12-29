import { createHandler, StartServer } from "@solidjs/start/server";

export default createHandler(() => (
  <StartServer
    document={({ assets, children, scripts }) => (
      <html lang="en" class="bg-gray-950">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="description" content="Viban - AI-Powered Kanban for developers. Autonomous task execution with Claude Code integration." />
          <link rel="icon" href="/favicon.ico" />
          {assets}
        </head>
        <body class="bg-gray-950 text-gray-100 antialiased">
          <div id="app">{children}</div>
          {scripts}
        </body>
      </html>
    )}
  />
));
