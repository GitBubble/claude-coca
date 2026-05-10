export enum ModelProviderKind {
  Mock = 'mock',
  OpenAICompatible = 'openai-compatible',
  Anthropic = 'anthropic'
}

export enum ModelMessageRole {
  System = 'system',
  User = 'user',
  Assistant = 'assistant'
}

export enum StreamEventType {
  Started = 'started',
  Delta = 'delta',
  Completed = 'completed'
}

export interface ModelCapability {
  streaming: boolean;
  cancellation: boolean;
  retry: boolean;
}

export interface ModelMetadata {
  kind: ModelProviderKind;
  displayName: string;
  defaultModelId: string;
  requiresApiKey: boolean;
  capability: ModelCapability;
}

export interface ChatMessage {
  role: ModelMessageRole;
  content: string;
}

export interface ChatRequest {
  modelId: string;
  messages: ChatMessage[];
  temperature?: number;
}

export interface StreamEvent {
  type: StreamEventType;
  textDelta?: string;
  fullText?: string;
}