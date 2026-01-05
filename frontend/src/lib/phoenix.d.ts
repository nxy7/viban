declare module "phoenix" {
  export interface SocketOptions {
    params?: Record<string, unknown>;
    reconnectAfterMs?: (tries: number) => number;
  }

  export interface Push {
    receive(status: "ok", callback: (response: unknown) => void): Push;
    receive(status: "error", callback: (response: unknown) => void): Push;
    receive(status: "timeout", callback: () => void): Push;
  }

  export class Channel {
    state: "closed" | "errored" | "joined" | "joining" | "leaving";
    join(): Push;
    leave(): Push;
    push(event: string, payload?: Record<string, unknown>): Push;
    on(event: string, callback: (payload: unknown) => void): number;
    off(event: string, ref?: number): void;
  }

  export class Socket {
    constructor(endPoint: string, opts?: SocketOptions);
    connect(): void;
    disconnect(): void;
    isConnected(): boolean;
    channel(topic: string, params?: Record<string, unknown>): Channel;
    onOpen(callback: () => void): void;
    onClose(callback: () => void): void;
    onError(callback: (error: unknown) => void): void;
  }
}
