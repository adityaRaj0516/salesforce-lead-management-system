@isTest
private class LeadScoringServiceTest {

    @isTest
    static void testBulkScoring_1000Leads() {

        List<Lead> leads = new List<Lead>();

        for (Integer i = 0; i < 1000; i++) {
            leads.add(new Lead(
                LastName = 'Test' + i,
                Company = 'Company' + i,
                Industry = 'Technology',
                AnnualRevenue = 60000000,
                NumberOfEmployees = 650,
                Website = 'https://example.com',
                Email = 'contact' + i + '@company.com',
                LeadSource = 'Referral',
                ProductInterest__c = 'Enterprise',
                NumberofLocations__c = 12
            ));
        }

        Test.startTest();
        insert leads;
        Test.stopTest();

        List<Lead> scored = [
            SELECT Lead_Score__c, Priority_Zone__c, Conversion_Probability__c,
                   Score_Status__c, Score_Source__c, Industry_Score__c
            FROM Lead
            WHERE Company LIKE 'Company%'
        ];

        System.assertEquals(1000, scored.size());

        for (Lead l : scored) {
            System.assertEquals(100, l.Lead_Score__c, 'Max-weight lead should cap at 100');
            System.assertEquals('Hot', l.Priority_Zone__c);
            System.assertEquals('Einstein', l.Score_Source__c);
            System.assertEquals('Fresh', l.Score_Status__c);
            System.assertEquals(20, l.Industry_Score__c);
            System.assert(l.Conversion_Probability__c > 0);
        }
    }

    @isTest
    static void testColdLead_MinimalData() {

        Lead l = new Lead(
            LastName = 'Cold',
            Company = 'NoDataCo'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead result = [SELECT Lead_Score__c, Priority_Zone__c FROM Lead WHERE Id = :l.Id];

        System.assertEquals('Cold', result.Priority_Zone__c);
        System.assert(result.Lead_Score__c < 50, 'Lead with no signals should score low');
    }

    @isTest
    static void testWarmThreshold_Boundary() {

        // Construct a lead that should land in the 50-79 Warm band
        Lead l = new Lead(
            LastName = 'Warm',
            Company = 'MidCo',
            Industry = 'Education',       // +10
            AnnualRevenue = 2000000,      // +10
            NumberOfEmployees = 30,       // +6
            Website = 'https://midco.com',// +10
            Email = 'info@midco.com',     // +10
            LeadSource = 'Trade Show'     // +6
            // total = 52
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead result = [SELECT Lead_Score__c, Priority_Zone__c FROM Lead WHERE Id = :l.Id];

        System.assertEquals('Warm', result.Priority_Zone__c);
    }

    @isTest
    static void testFreeEmailDomain_NoCorporateBonus() {

        Lead l = new Lead(
            LastName = 'Freemail',
            Company = 'PersonalCo',
            Email = 'someone@gmail.com'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead result = [SELECT Score_Reason__c FROM Lead WHERE Id = :l.Id];

        System.assert(
            !result.Score_Reason__c.contains('Corporate Email'),
            'Free email domain should not receive corporate email bonus'
        );
    }

    @isTest
    static void testUnknownIndustryAndLeadSource_UseDefaults() {

        Lead l = new Lead(
            LastName = 'Unknown',
            Company = 'MysteryCo',
            Industry = 'Something Unlisted',
            LeadSource = 'Something Else'
        );

        Test.startTest();
        insert l;
        Test.stopTest();

        Lead result = [SELECT Industry_Score__c, Score_Reason__c FROM Lead WHERE Id = :l.Id];

        System.assertEquals(5, result.Industry_Score__c, 'Unmapped industry should fall back to default weight');
    }

    @isTest
    static void testValidationBlocksInvalidWebsite() {

        Lead l = new Lead(
            LastName = 'BadSite',
            Company = 'BadSiteCo',
            Website = 'not-a-url'
        );

        Test.startTest();
        try {
            insert l;
            System.assert(false, 'Expected validation error for malformed website');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('http'));
        }
        Test.stopTest();
    }

    @isTest
    static void testValidationBlocksMissingCompany() {

        Lead l = new Lead(LastName = 'NoCompany');

        Test.startTest();
        try {
            insert l;
            System.assert(false, 'Expected validation error for missing company');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Company'));
        }
        Test.stopTest();
    }
}