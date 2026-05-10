import { ModelErrorCode, ModelException } from '../../domain/ModelErrors';
import { ChatRequest, ModelMetadata, ModelProviderKind, StreamEvent } from '../../domain/ModelTypes';
import { ChatAbortSignal, ModelProvider } from '../ModelProvider';

export class OpenAICompatibleProvider implements ModelProvider {
  public getMetadata(): ModelMetadata {
    return {
      kind: ModelProviderKind.OpenAICompatible,
      displayName: 'OpenAI Compatible',
      defaultModelId: 'gpt-4o-mini',
      requiresApiKey: true,
      capability: {
        streaming: true,
        cancellation: true,
        retry: true
      }
    };
  }

  public async validateApiKey(apiKey: string): Promise<boolean> {
    return apiKey.trim().length > 10;
  }

  public async streamChat(
    _request: ChatRequest,
    apiKey: string | undefined,
    _onEvent: (event: StreamEvent) => void,
    abortSignal: ChatAbortSignal
  ): Promise<void> {
    if (abortSignal.isCancelled()) {
      throw new ModelException({
        code: ModelErrorCode.Cancelled,
        message: 'Chat request cancelled.',
        provider: ModelProviderKind.OpenAICompatible
      });
    }

    if (!apiKey || apiKey.trim().length === 0) {
      throw new ModelException({
        code: ModelErrorCode.InvalidApiKey,
        message: 'API key is required.',
        provider: ModelProviderKind.OpenAICompatible
      });
    }

    throw new ModelException({
      code: ModelErrorCode.UnsupportedModel,
      message: 'OpenAI-compatible network client is not wired yet.',
      provider: ModelProviderKind.OpenAICompatible
    });
  }
}