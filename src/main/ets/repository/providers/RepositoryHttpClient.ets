export type HttpMethod = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';

export interface RepositoryHttpRequest {
  method: HttpMethod;
  url: string;
  headers?: Record<string, string>;
  query?: Record<string, string | number | boolean | undefined>;
  body?: string | Record<string, Object | string | number | boolean | null>;
}

export interface RepositoryHttpResponse<T> {
  statusCode: number;
  headers: Record<string, string>;
  data: T;
}

export interface RepositoryHttpClient {
  send<T>(request: RepositoryHttpRequest): Promise<RepositoryHttpResponse<T>>;
}

export function buildUrl(baseUrl: string, path: string, query?: Record<string, string | number | boolean | undefined>): string {
  const normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  const queryString = buildQueryString(query);
  return queryString.length === 0 ? `${normalizedBase}${normalizedPath}` : `${normalizedBase}${normalizedPath}?${queryString}`;
}

function buildQueryString(query?: Record<string, string | number | boolean | undefined>): string {
  if (!query) {
    return '';
  }
  const parts: string[] = [];
  Object.keys(query).forEach((key: string) => {
    const value = query[key];
    if (value === undefined) {
      return;
    }
    parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
  });
  return parts.join('&');
}
