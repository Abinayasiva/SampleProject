/**
 * @description Service class for AWS S3 bucket operations.
 *              Handles authentication (AWS Signature V4) and data retrieval from S3.
 *              Requires a Named Credential 'AWS_S3' or custom metadata for configuration.
 */
public with sharing class AWSS3Service {

    private static final String AWS_SERVICE = 's3';
    private static final String AWS_ALGORITHM = 'AWS4-HMAC-SHA256';
    private static final String AWS_REQUEST_TYPE = 'aws4_request';

    /**
     * @description Fetches a JSON file from an S3 bucket using Named Credential.
     * @param bucketName The S3 bucket name
     * @param objectKey  The S3 object key (file path)
     * @param region     The AWS region (e.g., 'us-east-1')
     * @return The raw JSON string from S3
     */
    public static String getObjectFromS3(String bucketName, String objectKey, String region) {
        // First try Named Credential approach
        String endpoint = 'callout:AWS_S3/' + bucketName + '/' + EncodingUtil.urlEncode(objectKey, 'UTF-8').replace('+', '%20');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            throw new AWSS3Exception(
                'S3 Error: ' + res.getStatusCode() + ' - ' + res.getBody()
            );
        }
    }

    /**
     * @description Fetches data from S3 using a pre-signed URL.
     *              Use this when Named Credentials are not configured.
     * @param presignedUrl The pre-signed S3 URL
     * @return The raw response body string
     */
    public static String getObjectFromPresignedUrl(String presignedUrl) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(presignedUrl);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            throw new AWSS3Exception(
                'S3 Presigned URL Error: ' + res.getStatusCode() + ' - ' + res.getBody()
            );
        }
    }

    /**
     * @description Fetches data from S3 using direct credentials with AWS Signature V4.
     * @param accessKey  AWS Access Key ID
     * @param secretKey  AWS Secret Access Key
     * @param bucketName The S3 bucket name
     * @param objectKey  The S3 object key (file path)
     * @param region     The AWS region
     * @return The raw response body string
     */
    public static String getObjectWithCredentials(
        String accessKey, String secretKey,
        String bucketName, String objectKey, String region
    ) {
        String host = bucketName + '.s3.' + region + '.amazonaws.com';
        String endpoint = 'https://' + host + '/' + objectKey;

        Datetime now = Datetime.now();
        String amzDate = now.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'');
        String dateStamp = now.formatGmt('yyyyMMdd');

        // Create canonical request
        String canonicalUri = '/' + objectKey;
        String canonicalQuerystring = '';
        String canonicalHeaders = 'host:' + host + '\n' + 'x-amz-date:' + amzDate + '\n';
        String signedHeaders = 'host;x-amz-date';
        String payloadHash = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(''))
        );

        String canonicalRequest = 'GET\n' + canonicalUri + '\n' + canonicalQuerystring + '\n'
            + canonicalHeaders + '\n' + signedHeaders + '\n' + payloadHash;

        // Create string to sign
        String credentialScope = dateStamp + '/' + region + '/' + AWS_SERVICE + '/' + AWS_REQUEST_TYPE;
        String stringToSign = AWS_ALGORITHM + '\n' + amzDate + '\n' + credentialScope + '\n'
            + EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(canonicalRequest))
            );

        // Create signing key
        Blob signingKey = getSignatureKey(secretKey, dateStamp, region, AWS_SERVICE);

        // Create signature
        String signature = EncodingUtil.convertToHex(
            Crypto.generateMac('HmacSHA256', Blob.valueOf(stringToSign), signingKey)
        );

        // Create authorization header
        String authorizationHeader = AWS_ALGORITHM + ' Credential=' + accessKey + '/' + credentialScope
            + ', SignedHeaders=' + signedHeaders + ', Signature=' + signature;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('x-amz-date', amzDate);
        req.setHeader('Authorization', authorizationHeader);
        req.setHeader('x-amz-content-sha256', payloadHash);
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            throw new AWSS3Exception(
                'S3 Auth Error: ' + res.getStatusCode() + ' - ' + res.getBody()
            );
        }
    }

    /**
     * @description Generates the AWS Signature V4 signing key.
     */
    private static Blob getSignatureKey(String key, String dateStamp, String region, String service) {
        Blob kDate = Crypto.generateMac('HmacSHA256', Blob.valueOf(dateStamp), Blob.valueOf('AWS4' + key));
        Blob kRegion = Crypto.generateMac('HmacSHA256', Blob.valueOf(region), kDate);
        Blob kService = Crypto.generateMac('HmacSHA256', Blob.valueOf(service), kRegion);
        Blob kSigning = Crypto.generateMac('HmacSHA256', Blob.valueOf(AWS_REQUEST_TYPE), kService);
        return kSigning;
    }

    public class AWSS3Exception extends Exception {}
}
