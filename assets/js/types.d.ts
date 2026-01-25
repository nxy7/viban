declare module "phoenix" {
  export class Socket {
    constructor(endPoint: string, opts?: object);
    connect(): void;
    disconnect(): void;
    channel(topic: string, params?: object): Channel;
    onOpen(callback: () => void): void;
    onClose(callback: () => void): void;
    onError(callback: (error: any) => void): void;
  }

  export class Channel {
    join(): Push;
    leave(): Push;
    push(event: string, payload?: object): Push;
    on(event: string, callback: (payload: any) => void): void;
    off(event: string): void;
  }

  export class Push {
    receive(status: string, callback: (response: any) => void): Push;
  }
}

declare module "phoenix_html" {
  const content: any;
  export default content;
}

declare module "phoenix_live_view" {
  import { Socket } from "phoenix";

  export interface LiveSocketOptions {
    params?: object | (() => object);
    hooks?: Record<string, object>;
    uploaders?: Record<string, object>;
    dom?: object;
    longPollFallbackMs?: number;
    timeout?: number;
  }

  export class LiveSocket {
    constructor(url: string, socket: typeof Socket, opts?: LiveSocketOptions);
    connect(): void;
    disconnect(): void;
    enableDebug(): void;
    disableDebug(): void;
    enableLatencySim(upperBoundMs: number): void;
    disableLatencySim(): void;
  }
}

declare module "*/vendor/topbar" {
  interface TopbarConfig {
    barColors?: Record<number, string>;
    shadowColor?: string;
    shadowBlur?: number;
    barThickness?: number;
    autoRun?: boolean;
  }

  interface Topbar {
    config(options: TopbarConfig): void;
    show(delay?: number): void;
    hide(): void;
    progress(value: number | string): void;
  }

  const topbar: Topbar;
  export default topbar;
}
