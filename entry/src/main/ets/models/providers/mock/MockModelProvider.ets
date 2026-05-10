import { ModelErrorCode, ModelException } from '../../domain/ModelErrors';
import {
  ChatRequest,
  ModelMessageRole,
  ModelMetadata,
  ModelProviderKind,
  StreamEvent,
  StreamEventType
} from '../../domain/ModelTypes';
import { ChatAbortSignal, ModelProvider } from '../ModelProvider';

export class MockModelProvider implements ModelProvider {
  public getMetadata(): ModelMetadata {
    return {
      kind: ModelProviderKind.Mock,
      displayName: 'Mock Local',
      defaultModelId: 'mock-claude-coca-v1',
      requiresApiKey: false,
      capability: {
        streaming: true,
        cancellation: true,
        retry: true
      }
    };
  }

  public async validateApiKey(_apiKey: string): Promise<boolean> {
    return true;
  }

  public async streamChat(
    request: ChatRequest,
    _apiKey: string | undefined,
    onEvent: (event: StreamEvent) => void,
    abortSignal: ChatAbortSignal
  ): Promise<void> {
    const prompt = getLastUserMessage(request);
    if (prompt.trim().length === 0) {
      throw new ModelException({
        code: ModelErrorCode.InvalidRequest,
        message: 'Prompt is empty.',
        provider: ModelProviderKind.Mock
      });
    }

    simulateFailureIfRequested(prompt);

    const startedEvent: StreamEvent = { type: StreamEventType.Started };
    onEvent(startedEvent);

    const chunks = buildMockChunks(prompt);
    let aggregated = '';
    for (let index = 0; index < chunks.length; index++) {
      if (abortSignal.isCancelled()) {
        throw new ModelException({
          code: ModelErrorCode.Cancelled,
          message: 'Chat request cancelled.',
          provider: ModelProviderKind.Mock
        });
      }
      const chunk = chunks[index];
      aggregated += chunk;
      const deltaEvent: StreamEvent = { type: StreamEventType.Delta, textDelta: chunk };
      onEvent(deltaEvent);
      await wait(70);
    }

    const completedEvent: StreamEvent = { type: StreamEventType.Completed, fullText: aggregated };
    onEvent(completedEvent);
  }
}

function getLastUserMessage(request: ChatRequest): string {
  const lastMessage = request.messages[request.messages.length - 1];
  if (!lastMessage || lastMessage.role !== ModelMessageRole.User) {
    return '';
  }
  return lastMessage.content;
}

function simulateFailureIfRequested(prompt: string): void {
  if (prompt.includes('/error invalid-key')) {
    throw new ModelException({
      code: ModelErrorCode.InvalidApiKey,
      message: 'Invalid API key.',
      provider: ModelProviderKind.Mock
    });
  }
  if (prompt.includes('/error network')) {
    throw new ModelException({
      code: ModelErrorCode.NetworkFailure,
      message: 'Network request failed.',
      provider: ModelProviderKind.Mock
    });
  }
  if (prompt.includes('/error rate-limit')) {
    throw new ModelException({
      code: ModelErrorCode.RateLimited,
      message: 'Rate limit reached.',
      provider: ModelProviderKind.Mock,
      retryAfterMs: 3000
    });
  }
  if (prompt.includes('/error unsupported')) {
    throw new ModelException({
      code: ModelErrorCode.UnsupportedModel,
      message: 'Model is not available for this provider.',
      provider: ModelProviderKind.Mock
    });
  }
}

function buildMockChunks(prompt: string): string[] {
  const response = `Acknowledged.\n\nYou said:\n${prompt}\n\nNext steps:\n1. Validate request shape.\n2. Build provider request payload.\n3. Stream partial output into chat UI.\n4. Support cancel and retry.`;
  const chunks: string[] = [];
  let cursor = 0;
  const chunkSize = 26;
  while (cursor < response.length) {
    chunks.push(response.substring(cursor, Math.min(cursor + chunkSize, response.length)));
    cursor += chunkSize;
  }
  return chunks;
}

function wait(timeoutMs: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(() => resolve(), timeoutMs);
  });
}