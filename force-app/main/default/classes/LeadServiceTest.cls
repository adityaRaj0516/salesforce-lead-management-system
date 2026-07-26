@isTest
private class LeadServiceTest {

    @isTest
    static void testCreateLead_Single() {

        Lead l = new Lead(LastName = 'Single', Company = 'SingleCo', Industry = 'Technology');

        Test.startTest();
        Lead created = LeadService.createLead(l);
        Test.stopTest();

        System.assertNotEquals(null, created.Id);
        Lead fromDb = [SELECT Lead_Score__c FROM Lead WHERE Id = :created.Id];
        System.assert(fromDb.Lead_Score__c > 0, 'Trigger should have scored the lead on insert');
    }

    @isTest
    static void testCreateLeads_Bulk() {

        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 50; i++) {
            leads.add(new Lead(LastName = 'Bulk' + i, Company = 'BulkCo' + i));
        }

        Test.startTest();
        List<Lead> created = LeadService.createLeads(leads);
        Test.stopTest();

        System.assertEquals(50, created.size());
        System.assertEquals(50, [SELECT COUNT() FROM Lead WHERE Company LIKE 'BulkCo%']);
    }

    @isTest
    static void testCreateLeads_EmptyList_ReturnsEmpty() {

        Test.startTest();
        List<Lead> result = LeadService.createLeads(new List<Lead>());
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @isTest
    static void testCreateLead_ValidationFailure_ThrowsServiceException() {

        Lead badLead = new Lead(LastName = 'NoCompany'); // Company required by validator

        Test.startTest();
        Boolean threw = false;
        try {
            LeadService.createLead(badLead);
        } catch (LeadService.LeadServiceException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Expected LeadServiceException wrapping the validation DmlException');
    }

    @isTest
    static void testUpdateLead_RescoresWhenRelevantFieldChanges() {

        Lead l = new Lead(LastName = 'Update', Company = 'UpdateCo', Industry = 'Education');
        insert l;

        Lead beforeChange = [SELECT Lead_Score__c, Last_Scored_Date__c FROM Lead WHERE Id = :l.Id];

        l.Industry = 'Technology'; // scoring-relevant change

        Test.startTest();
        LeadService.updateLead(l);
        Test.stopTest();

        Lead afterChange = [SELECT Lead_Score__c FROM Lead WHERE Id = :l.Id];
        System.assert(
            afterChange.Lead_Score__c != beforeChange.Lead_Score__c,
            'Score should change when a scoring-relevant field changes'
        );
    }

    @isTest
    static void testUpdateLead_SkipsRescoreWhenIrrelevantFieldChanges() {

        Lead l = new Lead(LastName = 'NoRescore', Company = 'NoRescoreCo', Industry = 'Technology');
        insert l;

        Lead before = [SELECT Lead_Score__c, Last_Scored_Date__c FROM Lead WHERE Id = :l.Id];

        l.Description = 'Just a note, nothing scoring-related';

        Test.startTest();
        LeadService.updateLead(l);
        Test.stopTest();

        Lead after = [SELECT Lead_Score__c, Last_Scored_Date__c FROM Lead WHERE Id = :l.Id];

        System.assertEquals(before.Lead_Score__c, after.Lead_Score__c);
        System.assertEquals(before.Last_Scored_Date__c, after.Last_Scored_Date__c);
    }

    @isTest
    static void testDeleteLead_RemovesRecord() {

        Lead l = new Lead(LastName = 'ToDelete', Company = 'DeleteCo');
        insert l;
        Id leadId = l.Id;

        Test.startTest();
        LeadService.deleteLead(leadId);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE Id = :leadId]);
    }

    @isTest
    static void testDeleteLead_NullId_NoOp() {

        Test.startTest();
        LeadService.deleteLead(null); // should not throw
        Test.stopTest();

        System.assert(true, 'No exception expected for null id');
    }

    @isTest
    static void testGetLeadById_DelegatesToRepository() {

        Lead l = new Lead(LastName = 'Fetch', Company = 'FetchCo');
        insert l;

        Test.startTest();
        Lead result = LeadService.getLeadById(l.Id);
        Test.stopTest();

        System.assertEquals('FetchCo', result.Company);
    }
}