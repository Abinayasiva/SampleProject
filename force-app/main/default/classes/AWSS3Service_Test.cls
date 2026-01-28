@IsTest
private class AWSS3Service_Test {

    private class MockHttpSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"objectLabel":"Contacts","records":[]}');
            return res;
        }
    }

    private class MockHttpError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(403);
            res.setBody('Access Denied');
            return res;
        }
    }

    @IsTest
    static void testGetObjectFromS3_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        String result = AWSS3Service.getObjectFromS3('test-bucket', 'data/test.json', 'us-east-1');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('Contacts'), 'Result should contain expected data');
    }

    @IsTest
    static void testGetObjectFromS3_Error() {
        Test.setMock(HttpCalloutMock.class, new MockHttpError());

        Test.startTest();
        try {
            AWSS3Service.getObjectFromS3('test-bucket', 'data/test.json', 'us-east-1');
            System.assert(false, 'Should have thrown exception');
        } catch (AWSS3Service.AWSS3Exception e) {
            System.assert(e.getMessage().contains('S3 Error'), 'Error message should contain S3 Error');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetObjectFromPresignedUrl_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        String result = AWSS3Service.getObjectFromPresignedUrl('https://s3.amazonaws.com/test-bucket/test.json?signature=abc');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @IsTest
    static void testGetObjectFromPresignedUrl_Error() {
        Test.setMock(HttpCalloutMock.class, new MockHttpError());

        Test.startTest();
        try {
            AWSS3Service.getObjectFromPresignedUrl('https://s3.amazonaws.com/test-bucket/test.json');
            System.assert(false, 'Should have thrown exception');
        } catch (AWSS3Service.AWSS3Exception e) {
            System.assert(e.getMessage().contains('Presigned URL Error'), 'Error should reference presigned URL');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetObjectWithCredentials_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        String result = AWSS3Service.getObjectWithCredentials(
            'AKIAIOSFODNN7EXAMPLE',
            'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
            'test-bucket',
            'data/test.json',
            'us-east-1'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    @IsTest
    static void testGetObjectWithCredentials_Error() {
        Test.setMock(HttpCalloutMock.class, new MockHttpError());

        Test.startTest();
        try {
            AWSS3Service.getObjectWithCredentials(
                'AKIAIOSFODNN7EXAMPLE',
                'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
                'test-bucket',
                'data/test.json',
                'us-east-1'
            );
            System.assert(false, 'Should have thrown exception');
        } catch (AWSS3Service.AWSS3Exception e) {
            System.assert(e.getMessage().contains('S3 Auth Error'), 'Error should reference auth error');
        }
        Test.stopTest();
    }
}
