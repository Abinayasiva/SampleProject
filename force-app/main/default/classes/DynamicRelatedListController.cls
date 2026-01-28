/**
 * @description Controller for the Dynamic Related List LWC component.
 *              Fetches data from AWS S3 and returns it in a format the LWC can render
 *              as a standard-looking related list for any object.
 */
public with sharing class DynamicRelatedListController {

    /**
     * @description Fetches related list data from AWS S3 bucket.
     * @param bucketName  The S3 bucket name
     * @param objectKey   The S3 object key / file path (JSON file)
     * @param region      The AWS region (e.g., 'us-east-1')
     * @param authMode    Authentication mode: 'named_credential', 'presigned_url', or 'direct'
     * @param presignedUrl  (Optional) Pre-signed URL when authMode is 'presigned_url'
     * @param accessKey   (Optional) AWS Access Key when authMode is 'direct'
     * @param secretKey   (Optional) AWS Secret Key when authMode is 'direct'
     * @param fieldsList  Comma-separated list of field API names to display
     * @param sortBy      Field API name to sort by
     * @param sortDirection 'asc' or 'desc'
     * @param recordLimit Maximum number of records to return
     * @param filterField (Optional) Field name to filter on
     * @param filterValue (Optional) Value to filter by
     * @return RelatedListResult containing columns and rows
     */
    @AuraEnabled(cacheable=true)
    public static RelatedListResult getRelatedListData(
        String bucketName,
        String objectKey,
        String region,
        String authMode,
        String presignedUrl,
        String accessKey,
        String secretKey,
        String fieldsList,
        String sortBy,
        String sortDirection,
        Integer recordLimit,
        String filterField,
        String filterValue
    ) {
        try {
            // Fetch raw JSON from S3
            String rawJson = fetchFromS3(bucketName, objectKey, region, authMode, presignedUrl, accessKey, secretKey);

            // Parse and process the data
            return processS3Data(rawJson, fieldsList, sortBy, sortDirection, recordLimit, filterField, filterValue);
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching data: ' + e.getMessage());
        }
    }

    /**
     * @description Fetches raw JSON data from S3 based on the chosen auth mode.
     */
    private static String fetchFromS3(
        String bucketName, String objectKey, String region,
        String authMode, String presignedUrl, String accessKey, String secretKey
    ) {
        if (authMode == 'presigned_url' && String.isNotBlank(presignedUrl)) {
            return AWSS3Service.getObjectFromPresignedUrl(presignedUrl);
        } else if (authMode == 'direct' && String.isNotBlank(accessKey) && String.isNotBlank(secretKey)) {
            return AWSS3Service.getObjectWithCredentials(accessKey, secretKey, bucketName, objectKey, region);
        } else {
            // Default: Named Credential
            return AWSS3Service.getObjectFromS3(bucketName, objectKey, region);
        }
    }

    /**
     * @description Processes raw S3 JSON data into a structured RelatedListResult.
     *              Expected S3 JSON format:
     *              {
     *                "objectLabel": "Contacts",
     *                "objectApiName": "Contact",
     *                "iconName": "standard:contact",
     *                "fields": [
     *                  { "fieldName": "Name", "label": "Full Name", "type": "text" },
     *                  { "fieldName": "Email", "label": "Email", "type": "email" },
     *                  ...
     *                ],
     *                "records": [
     *                  { "Id": "001...", "Name": "John Doe", "Email": "john@test.com", ... },
     *                  ...
     *                ]
     *              }
     */
    @TestVisible
    private static RelatedListResult processS3Data(
        String rawJson, String fieldsList, String sortBy,
        String sortDirection, Integer recordLimit,
        String filterField, String filterValue
    ) {
        RelatedListResult result = new RelatedListResult();

        Map<String, Object> jsonData = (Map<String, Object>) JSON.deserializeUntyped(rawJson);

        // Extract metadata
        result.objectLabel = (String) jsonData.get('objectLabel');
        result.objectApiName = (String) jsonData.get('objectApiName');
        result.iconName = (String) jsonData.get('iconName');

        // Process field definitions (columns)
        List<Object> fieldDefs = (List<Object>) jsonData.get('fields');
        List<String> requestedFields = new List<String>();

        if (String.isNotBlank(fieldsList)) {
            for (String f : fieldsList.split(',')) {
                requestedFields.add(f.trim());
            }
        }

        result.columns = new List<ColumnDefinition>();
        Set<String> validFields = new Set<String>();

        if (fieldDefs != null) {
            for (Object fieldObj : fieldDefs) {
                Map<String, Object> fieldMap = (Map<String, Object>) fieldObj;
                String fieldName = (String) fieldMap.get('fieldName');

                // If fieldsList is specified, only include those fields
                if (!requestedFields.isEmpty() && !requestedFields.contains(fieldName)) {
                    continue;
                }

                ColumnDefinition col = new ColumnDefinition();
                col.fieldName = fieldName;
                col.label = (String) fieldMap.get('label');
                col.type = (String) fieldMap.get('type');
                col.sortable = fieldMap.containsKey('sortable') ? (Boolean) fieldMap.get('sortable') : true;

                if (fieldMap.containsKey('typeAttributes')) {
                    col.typeAttributes = fieldMap.get('typeAttributes');
                }

                if (fieldMap.containsKey('cellAttributes')) {
                    col.cellAttributes = fieldMap.get('cellAttributes');
                }

                result.columns.add(col);
                validFields.add(fieldName);
            }
        }

        // Process records (rows)
        List<Object> records = (List<Object>) jsonData.get('records');
        result.records = new List<Map<String, Object>>();

        if (records != null) {
            for (Object recObj : records) {
                Map<String, Object> record = (Map<String, Object>) recObj;

                // Apply filtering
                if (String.isNotBlank(filterField) && String.isNotBlank(filterValue)) {
                    Object fieldVal = record.get(filterField);
                    if (fieldVal == null || !String.valueOf(fieldVal).containsIgnoreCase(filterValue)) {
                        continue;
                    }
                }

                // Only include valid fields + Id
                Map<String, Object> filteredRecord = new Map<String, Object>();
                filteredRecord.put('Id', record.get('Id'));

                for (String vf : validFields) {
                    if (record.containsKey(vf)) {
                        filteredRecord.put(vf, record.get(vf));
                    }
                }

                result.records.add(filteredRecord);
            }
        }

        // Apply sorting
        if (String.isNotBlank(sortBy) && !result.records.isEmpty()) {
            result.records = sortRecords(result.records, sortBy, sortDirection);
        }

        // Store total count before limiting
        result.totalCount = result.records.size();

        // Apply record limit
        if (recordLimit != null && recordLimit > 0 && result.records.size() > recordLimit) {
            List<Map<String, Object>> limited = new List<Map<String, Object>>();
            for (Integer i = 0; i < recordLimit && i < result.records.size(); i++) {
                limited.add(result.records[i]);
            }
            result.records = limited;
        }

        return result;
    }

    /**
     * @description Sorts a list of record maps by a given field.
     */
    private static List<Map<String, Object>> sortRecords(
        List<Map<String, Object>> records, String sortBy, String sortDirection
    ) {
        // Wrap records for sorting
        List<SortableRecord> sortable = new List<SortableRecord>();
        for (Map<String, Object> rec : records) {
            sortable.add(new SortableRecord(rec, sortBy));
        }
        sortable.sort();

        List<Map<String, Object>> sorted = new List<Map<String, Object>>();
        if (sortDirection != null && sortDirection.equalsIgnoreCase('desc')) {
            for (Integer i = sortable.size() - 1; i >= 0; i--) {
                sorted.add(sortable[i].record);
            }
        } else {
            for (SortableRecord sr : sortable) {
                sorted.add(sr.record);
            }
        }

        return sorted;
    }

    /**
     * @description Wrapper class to make records sortable.
     */
    private class SortableRecord implements Comparable {
        public Map<String, Object> record;
        private String sortField;

        public SortableRecord(Map<String, Object> record, String sortField) {
            this.record = record;
            this.sortField = sortField;
        }

        public Integer compareTo(Object other) {
            SortableRecord otherRec = (SortableRecord) other;
            Object val1 = this.record.get(sortField);
            Object val2 = otherRec.record.get(sortField);

            if (val1 == null && val2 == null) return 0;
            if (val1 == null) return -1;
            if (val2 == null) return 1;

            String str1 = String.valueOf(val1);
            String str2 = String.valueOf(val2);
            return str1.compareTo(str2);
        }
    }

    /**
     * @description Wrapper class for the related list result returned to LWC.
     */
    public class RelatedListResult {
        @AuraEnabled public String objectLabel;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String iconName;
        @AuraEnabled public List<ColumnDefinition> columns;
        @AuraEnabled public List<Map<String, Object>> records;
        @AuraEnabled public Integer totalCount;
    }

    /**
     * @description Wrapper class for column/field definitions.
     */
    public class ColumnDefinition {
        @AuraEnabled public String fieldName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean sortable;
        @AuraEnabled public Object typeAttributes;
        @AuraEnabled public Object cellAttributes;
    }
}
