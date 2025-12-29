import { createCollection } from "@tanstack/db";
import { electricCollectionOptions } from "@tanstack/electric-db-collection";
import { useLiveQuery } from "@tanstack/solid-db";

export interface TestMessage {
  id: string;
  text: string;
  inserted_at: string;
  updated_at: string;
}

export const messagesCollection = createCollection(
  electricCollectionOptions<TestMessage>({
    id: "test_messages",
    getKey: (item) => item.id,
    shapeOptions: {
      url: `/api/shapes/test_messages`,
    },
  }),
);

export function useTestMessages() {
  const query = useLiveQuery((q) =>
    q.from({ messages: messagesCollection }).select(({ messages }) => ({
      id: messages.id,
      text: messages.text,
      inserted_at: messages.inserted_at,
      updated_at: messages.updated_at,
    })),
  );

  return {
    messages: () => query.data,
    isLoading: () => query.isLoading(),
    error: () => (query.isError() ? query.status() : null),
  };
}

export async function randomizeMessage(): Promise<TestMessage> {
  const response = await fetch(`/api/messages/randomize`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to randomize message: ${response.statusText}`);
  }

  const data = await response.json();
  if (!data.ok) {
    throw new Error(data.error || "Unknown error");
  }

  return data.result;
}
