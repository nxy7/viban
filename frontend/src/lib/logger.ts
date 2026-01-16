type LogLevel = "debug" | "info" | "warn" | "error";

interface LogContext {
  [key: string]: unknown;
}

const LOG_LEVELS: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

const MIN_LEVEL: LogLevel =
  import.meta.env.PROD ? "info" : "debug";

function shouldLog(level: LogLevel): boolean {
  return LOG_LEVELS[level] >= LOG_LEVELS[MIN_LEVEL];
}

function formatMessage(
  level: LogLevel,
  module: string,
  message: string,
  context?: LogContext,
): string {
  const prefix = `[${module}]`;
  if (context && Object.keys(context).length > 0) {
    return `${prefix} ${message}`;
  }
  return `${prefix} ${message}`;
}

function log(
  level: LogLevel,
  module: string,
  message: string,
  context?: LogContext,
): void {
  if (!shouldLog(level)) return;

  const formatted = formatMessage(level, module, message, context);

  switch (level) {
    case "debug":
      if (context) {
        console.debug(formatted, context);
      } else {
        console.debug(formatted);
      }
      break;
    case "info":
      if (context) {
        console.log(formatted, context);
      } else {
        console.log(formatted);
      }
      break;
    case "warn":
      if (context) {
        console.warn(formatted, context);
      } else {
        console.warn(formatted);
      }
      break;
    case "error":
      if (context) {
        console.error(formatted, context);
      } else {
        console.error(formatted);
      }
      break;
  }
}

export function createLogger(module: string) {
  return {
    debug: (message: string, context?: LogContext) =>
      log("debug", module, message, context),
    info: (message: string, context?: LogContext) =>
      log("info", module, message, context),
    warn: (message: string, context?: LogContext) =>
      log("warn", module, message, context),
    error: (message: string, context?: LogContext) =>
      log("error", module, message, context),
  };
}

export type Logger = ReturnType<typeof createLogger>;
