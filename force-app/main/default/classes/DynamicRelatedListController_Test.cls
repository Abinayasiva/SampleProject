@IsTest
private class DynamicRelatedListController_Test {

    private static final String MOCK_S3_JSON = '{'
        + '"objectLabel": "External Contacts",'
        + '"objectApiName": "Contact",'
        + '"iconName": "standard:contact",'
        + '"fields": ['
        + '  {"fieldName": "Name", "label": "Full Name", "type": "text", "sortable": true},'
        + '  {"fieldName": "Email", "label": "Email Address", "type": "email", "sortable": true},'
        + '  {"fieldName": "Phone", "label": "Phone", "type": "phone"},'
        + '  {"fieldName": "Company", "label": "Company", "type": "text"}'
        + '],'
        + '"records": ['
        + '  {"Id": "EXT001", "Name": "Alice Johnson", "Email": "alice@example.com", "Phone": "555-0101", "Company": "Acme Corp"},'
        + '  {"Id": "EXT002", "Name": "Bob Smith", "Email": "bob@example.com", "Phone": "555-0102", "Company": "Global Inc"},'
        + '  {"Id": "EXT003", "Name": "Charlie Brown", "Email": "charlie@example.com", "Phone": "555-0103", "Company": "Acme Corp"},'
        + '  {"Id": "EXT004", "Name": "Diana Prince", "Email": "diana@example.com", "Phone": "555-0104", "Company": "Wayne Tech"},'
        + '  {"Id": "EXT005", "Name": "Eve Wilson", "Email": "eve@example.com", "Phone": "555-0105", "Company": "Global Inc"}'
        + ']'
        + '}';

    private class MockS3Success implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(MOCK_S3_JSON);
            return res;
        }
    }

    private class MockS3Error implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    @IsTest
    static void testGetRelatedListData_AllFields() {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());

        Test.startTest();
        DynamicRelatedListController.RelatedListResult result =
            DynamicRelatedListController.getRelatedListData(
                'test-bucket', 'data/contacts.json', 'us-east-1',
                'named_credential', null, null, null,
                '', '', 'asc', 0, '', ''
            );
        Test.stopTest();

        System.assertEquals('External Contacts', result.objectLabel);
        System.assertEquals('Contact', result.objectApiName);
        System.assertEquals('standard:contact', result.iconName);
        System.assertEquals(4, result.columns.size(), 'Should have 4 columns');
        System.assertEquals(5, result.records.size(), 'Should have 5 records');
        System.assertEquals(5, result.totalCount, 'Total count should be 5');
    }

    @IsTest
    static void testGetRelatedListData_SpecificFields() {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());

        Test.startTest();
        DynamicRelatedListController.RelatedListResult result =
            DynamicRelatedListController.getRelatedListData(
                'test-bucket', 'data/contacts.json', 'us-east-1',
                'named_credential', null, null, null,
                'Name,Email', '', 'asc', 0, '', ''
            );
        Test.stopTest();

        System.assertEquals(2, result.columns.size(), 'Should only have 2 columns (Name, Email)');
        System.assertEquals('Name', result.columns[0].fieldName);
        System.assertEquals('Email', result.columns[1].fieldName);
    }

    @IsTest
    static void testGetRelatedListData_WithFilter() {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());

        Test.startTest();
        DynamicRelatedListController.RelatedListResult result =
            DynamicRelatedListController.getRelatedListData(
                'test-bucket', 'data/contacts.json', 'us-east-1',
                'named_credential', null, null, null,
                '', '', 'asc', 0, 'Company', 'Acme'
            );
        Test.stopTest();

        System.assertEquals(2, result.records.size(), 'Should have 2 records from Acme Corp');
        System.assertEquals(2, result.totalCount);
    }

    @IsTest
    static void testGetRelatedListData_WithSorting() {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());

        Test.startTest();
        DynamicRelatedListController.RelatedListResult result =
            DynamicRelatedListController.getRelatedListData(
                'test-bucket', 'data/contacts.json', 'us-east-1',
                'named_credential', null, null, null,
                'Name', 'Name', 'desc', 0, '', ''
            );
        Test.stopTest();

        System.assertEquals(5, result.records.size());
        // First record (desc) should be Eve Wilson
        System.assertEquals('Eve Wilson', result.records[0].get('Name'));
    }

    @IsTest
    static void testGetRelatedListData_WithLimit() {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());

        Test.startTest();
        DynamicRelatedListController.RelatedListResult result =
            DynamicRelatedListController.getRelatedListData(
                'test-bucket', 'data/contacts.json', 'us-east-1',
                'named_credential', null, null, null,
                '', '', 'asc', 3, '', ''
            );
        Test.stopTest();

        System.assertEquals(3, result.records.size(), 'Should be limited to 3 records');
        System.assertEquals(5, result.totalCount, 'Total count should still be 5');
    }

    @IsTest
    static void testGetRelatedListData_PresignedUrlMode() {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());

        Test.startTest();
        DynamicRelatedListController.RelatedListResult result =
            DynamicRelatedListController.getRelatedListData(
                '', '', 'us-east-1',
                'presigned_url', 'https://s3.amazonaws.com/test-bucket/data/contacts.json?sig=abc',
                null, null,
                '', '', 'asc', 0, '', ''
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(5, result.records.size());
    }

    @IsTest
    static void testGetRelatedListData_DirectMode() {
        Test.setMock(HttpCalloutMock.class, new MockS3Success());

        Test.startTest();
        DynamicRelatedListController.RelatedListResult result =
            DynamicRelatedListController.getRelatedListData(
                'test-bucket', 'data/contacts.json', 'us-east-1',
                'direct', null,
                'AKIAIOSFODNN7EXAMPLE', 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
                '', '', 'asc', 0, '', ''
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(5, result.records.size());
    }

    @IsTest
    static void testGetRelatedListData_S3Error() {
        Test.setMock(HttpCalloutMock.class, new MockS3Error());

        Test.startTest();
        try {
            DynamicRelatedListController.getRelatedListData(
                'test-bucket', 'data/contacts.json', 'us-east-1',
                'named_credential', null, null, null,
                '', '', 'asc', 0, '', ''
            );
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error fetching data'), 'Should contain error message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testProcessS3Data_NullFields() {
        String jsonData = '{'
            + '"objectLabel": "Test",'
            + '"objectApiName": "Test__c",'
            + '"fields": [{"fieldName": "Name", "label": "Name", "type": "text"}],'
            + '"records": [{"Id": "1", "Name": null}, {"Id": "2", "Name": "Test"}]'
            + '}';

        Test.startTest();
        DynamicRelatedListController.RelatedListResult result =
            DynamicRelatedListController.processS3Data(jsonData, '', 'Name', 'asc', 0, '', '');
        Test.stopTest();

        System.assertEquals(2, result.records.size());
    }

    @IsTest
    static void testProcessS3Data_FilterNoMatch() {
        String jsonData = '{'
            + '"objectLabel": "Test",'
            + '"objectApiName": "Test__c",'
            + '"fields": [{"fieldName": "Name", "label": "Name", "type": "text"}],'
            + '"records": [{"Id": "1", "Name": "Alpha"}, {"Id": "2", "Name": "Beta"}]'
            + '}';

        Test.startTest();
        DynamicRelatedListController.RelatedListResult result =
            DynamicRelatedListController.processS3Data(jsonData, '', '', 'asc', 0, 'Name', 'Gamma');
        Test.stopTest();

        System.assertEquals(0, result.records.size(), 'No records should match filter');
    }

    @IsTest
    static void testColumnDefinition() {
        DynamicRelatedListController.ColumnDefinition col = new DynamicRelatedListController.ColumnDefinition();
        col.fieldName = 'Name';
        col.label = 'Full Name';
        col.type = 'text';
        col.sortable = true;
        col.typeAttributes = null;
        col.cellAttributes = null;

        System.assertEquals('Name', col.fieldName);
        System.assertEquals('Full Name', col.label);
        System.assertEquals('text', col.type);
        System.assertEquals(true, col.sortable);
    }
}
