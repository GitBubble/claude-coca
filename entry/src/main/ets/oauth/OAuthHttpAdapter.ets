import { http } from '@kit.NetworkKit';

/**
 * Minimal, mockable HTTP surface used only by OAuthService. Kept narrow on
 * purpose so the unit tests in entry/src/ohosTest/ can supply a fake
 * without depending on @kit.NetworkKit.
 *
 * The repository's existing RepositoryHttpClient is per-provider (uses
 * Map<string,string> headers) and is wired into the Repository providers'
 * authentication path; reusing it here would create a circular dependency
 * because the OAuth flow PRODUCES the credential that RepositoryHttpClient
 * uses. So we keep this layer self-contained.
 */
export interface OAuthHttpResponse {
  statusCode: number;
  body: string;
}

export interface OAuthHttpClient {
  /** Issues a form-encoded POST and returns the raw body + status. */
  postForm(url: string, body: string): Promise<OAuthHttpResponse>;
}

const ACCEPT_JSON: string = 'application/json';
const FORM_CONTENT_TYPE: string = 'application/x-www-form-urlencoded';

/**
 * Default implementation backed by @kit.NetworkKit's HTTP module.
 *
 * GitHub returns form-urlencoded by default and only switches to JSON when
 * `Accept: application/json` is sent — we always send it so parsing in
 * OAuthParsing.ts can assume JSON bodies.
 */
export class NetworkKitOAuthHttpClient implements OAuthHttpClient {
  public async postForm(url: string, body: string): Promise<OAuthHttpResponse> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'Accept': ACCEPT_JSON,
        'Content-Type': FORM_CONTENT_TYPE
      };
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING
      };
      const response: http.HttpResponse = await request.request(url, options);
      const rawBody: string | ArrayBuffer | Object = response.result;
      const stringBody: string = typeof rawBody === 'string' ? rawBody as string : '';
      const result: OAuthHttpResponse = {
        statusCode: response.responseCode,
        body: stringBody
      };
      return result;
    } finally {
      request.destroy();
    }
  }
}
