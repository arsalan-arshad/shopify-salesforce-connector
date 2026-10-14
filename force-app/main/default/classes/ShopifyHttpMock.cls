/**
 * @description HTTP Callout Mock implementation for Shopify API testing.
 */
@IsTest
public class ShopifyHttpMock implements HttpCalloutMock {

    private Integer statusCode;
    private String responseBody;

    public ShopifyHttpMock(Integer statusCode, String responseBody) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(this.statusCode);
        res.setBody(this.responseBody);
        return res;
    }
}
