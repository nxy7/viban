import type { ActionConfig } from "./generated/ash";
import { showError } from "./notifications";

interface AshRpcError {
  type: string;
  message: string;
  short_message?: string;
  vars?: Record<string, unknown>;
  fields?: string[];
  path?: string[];
  details?: Record<string, unknown>;
}

interface RpcResult {
  success: boolean;
  errors?: AshRpcError[];
  data?: unknown;
}

export async function afterActionRequest(
  action: string,
  _response: Response,
  result: RpcResult | null,
  _config: ActionConfig,
): Promise<void> {
  if (!result) return;

  if (!result.success && result.errors && result.errors.length > 0) {
    const firstError = result.errors[0];
    const errorTitle = getErrorTitle(action, firstError);
    const errorMessage = formatErrorMessage(firstError);

    showError(errorTitle, errorMessage);
  }
}

function getErrorTitle(action: string, error: AshRpcError): string {
  if (error.type === "network_error") {
    return "Network Error";
  }

  if (error.type === "not_found") {
    return "Not Found";
  }

  const actionName = formatActionName(action);
  return `${actionName} Failed`;
}

function formatActionName(action: string): string {
  return action
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

function formatErrorMessage(error: AshRpcError): string {
  if (error.short_message) {
    return error.short_message;
  }

  if (error.message) {
    const interpolated = interpolateMessage(error.message, error.vars);
    if (interpolated && interpolated !== "Unknown error") {
      return interpolated;
    }
  }

  const details = [
    error.type && `type: ${error.type}`,
    error.fields?.length && `fields: ${error.fields.join(", ")}`,
  ].filter(Boolean);

  if (details.length > 0) {
    return `Error (${details.join(", ")})`;
  }

  return "An unexpected error occurred";
}

function interpolateMessage(
  template: string,
  vars?: Record<string, unknown>,
): string {
  if (!vars) return template;

  let result = template;
  for (const [key, value] of Object.entries(vars)) {
    result = result.replace(new RegExp(`%{${key}}`, "g"), String(value));
  }
  return result;
}
