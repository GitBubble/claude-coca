export type HttpMethod = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';

export type RepositoryQueryValue = string | number | boolean | undefined;
export type RepositoryBodyValue = Object | string | number | boolean | null;

export interface RepositoryHttpRequest {
  method: HttpMethod;
  url: string;
  headers?: Map<string, string>;
  query?: Map<string, RepositoryQueryValue>;
  body?: string | Map<string, RepositoryBodyValue>;
}

export interface RepositoryHttpResponse<T> {
  statusCode: number;
  headers: Map<string, string>;
  data: T;
}

export interface RepositoryHttpClient {
  send<T>(request: RepositoryHttpRequest): Promise<RepositoryHttpResponse<T>>;
}

export function buildUrl(baseUrl: string, path: string, query?: Map<string, RepositoryQueryValue>): string {
  const normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  const queryString = buildQueryString(query);
  return queryString.length === 0 ? `${normalizedBase}${normalizedPath}` : `${normalizedBase}${normalizedPath}?${queryString}`;
}

function buildQueryString(query?: Map<string, RepositoryQueryValue>): string {
  if (!query) {
    return '';
  }
  const parts: string[] = [];
  query.forEach((value: RepositoryQueryValue, key: string) => {
    if (value === undefined) {
      return;
    }
    parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
  });
  return parts.join('&');
}
