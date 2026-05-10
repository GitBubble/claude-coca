import {
  ChatRequest,
  ModelMetadata,
  ModelProviderKind,
  StreamEvent
} from '../domain/ModelTypes';

export class ChatAbortSignal {
  private cancelled: boolean = false;

  public isCancelled(): boolean {
    return this.cancelled;
  }

  public cancel(): void {
    this.cancelled = true;
  }
}

export interface ModelProvider {
  getMetadata(): ModelMetadata;

  validateApiKey(apiKey: string): Promise<boolean>;

  streamChat(
    request: ChatRequest,
    apiKey: string | undefined,
    onEvent: (event: StreamEvent) => void,
    abortSignal: ChatAbortSignal
  ): Promise<void>;
}

export function createDefaultModelSelection(): ModelProviderKind {
  return ModelProviderKind.Mock;
}