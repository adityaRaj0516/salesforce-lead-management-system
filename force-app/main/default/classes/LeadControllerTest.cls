@isTest
private class LeadControllerTest {

    private static RestRequest buildRequest(String method, String uri, String body, Map<String, String> params) {

        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = method;

        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        if (params != null) {
            for (String key : params.keySet()) {
                req.params.put(key, params.get(key));
            }
        }

        return req;
    }

    private static Map<String, Object> parseResponse() {
        String responseBody = RestContext.response.responseBody.toString();
        return (Map<String, Object>) JSON.deserializeUntyped(responseBody);
    }

    @isTest
    static void testGetLead_ReturnsRecord() {

        Lead l = new Lead(LastName = 'Getter', Company = 'GetterCo');
        insert l;

        RestContext.request = buildRequest('GET', '/services/apexrest/leads/' + l.Id, null, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.getLead();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> parsed = parseResponse();
        System.assertEquals(true, parsed.get('success'));
    }

    @isTest
    static void testGetLead_InvalidId_Returns400() {

        RestContext.request = buildRequest('GET', '/services/apexrest/leads/not-a-real-id', null, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.getLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testGetLead_NotFound_Returns404() {

        Lead temp = new Lead(LastName = 'Temp', Company = 'TempCo');
        insert temp;
        Id fakeId = temp.Id;
        delete temp;

        RestContext.request = buildRequest('GET', '/services/apexrest/leads/' + fakeId, null, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.getLead();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }

    @isTest
    static void testGetLead_ListByIndustry() {

        insert new Lead(LastName = 'IndA', Company = 'IndACo', Industry = 'Finance');
        insert new Lead(LastName = 'IndB', Company = 'IndBCo', Industry = 'Retail');

        RestContext.request = buildRequest(
            'GET', '/services/apexrest/leads',
            null, new Map<String, String>{ 'industry' => 'Finance' }
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.getLead();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    @isTest
    static void testGetLead_NoIdNoFilter_Returns400() {

        RestContext.request = buildRequest('GET', '/services/apexrest/leads', null, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.getLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testCreateLead_Success() {

        String body = JSON.serialize(new Map<String, Object>{
            'FirstName' => 'New',
            'LastName' => 'Lead',
            'Company' => 'NewLeadCo',
            'Industry' => 'Technology'
        });

        RestContext.request = buildRequest('POST', '/services/apexrest/leads', body, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.createLead();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode);
        System.assertEquals(1, [SELECT COUNT() FROM Lead WHERE Company = 'NewLeadCo']);
    }

    @isTest
    static void testCreateLead_IgnoresNonWritableFields() {

        // Attempt to set OwnerId and Id directly - should be silently ignored
        String body = JSON.serialize(new Map<String, Object>{
            'LastName' => 'Sneaky',
            'Company' => 'SneakyCo',
            'OwnerId' => UserInfo.getUserId(),
            'IsConverted' => true
        });

        RestContext.request = buildRequest('POST', '/services/apexrest/leads', body, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.createLead();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode);

        Lead created = [SELECT IsConverted FROM Lead WHERE Company = 'SneakyCo'];
        System.assertEquals(false, created.IsConverted, 'IsConverted should not be settable via the API');
    }

    @isTest
    static void testCreateLead_BlankBody_Returns400() {

        RestContext.request = buildRequest('POST', '/services/apexrest/leads', '', null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.createLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testCreateLead_ValidationFailure_Returns400() {

        String body = JSON.serialize(new Map<String, Object>{ 'LastName' => 'NoCompany' });

        RestContext.request = buildRequest('POST', '/services/apexrest/leads', body, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.createLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testUpdateLead_Success() {

        Lead l = new Lead(LastName = 'Original', Company = 'OriginalCo', Industry = 'Education');
        insert l;

        String body = JSON.serialize(new Map<String, Object>{ 'Industry' => 'Technology' });

        RestContext.request = buildRequest('PUT', '/services/apexrest/leads/' + l.Id, body, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.updateLead();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Lead updated = [SELECT Industry FROM Lead WHERE Id = :l.Id];
        System.assertEquals('Technology', updated.Industry);
    }

    @isTest
    static void testUpdateLead_MissingId_Returns400() {

        String body = JSON.serialize(new Map<String, Object>{ 'Industry' => 'Technology' });

        RestContext.request = buildRequest('PUT', '/services/apexrest/leads', body, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.updateLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void testDeleteLead_Success() {

        Lead l = new Lead(LastName = 'ToDelete', Company = 'DeleteCo');
        insert l;

        RestContext.request = buildRequest('DELETE', '/services/apexrest/leads/' + l.Id, null, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.deleteLead();
        Test.stopTest();

        System.assertEquals(204, RestContext.response.statusCode);
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE Id = :l.Id]);
    }

    @isTest
    static void testDeleteLead_MissingId_Returns400() {

        RestContext.request = buildRequest('DELETE', '/services/apexrest/leads', null, null);
        RestContext.response = new RestResponse();

        Test.startTest();
        LeadController.deleteLead();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }
}