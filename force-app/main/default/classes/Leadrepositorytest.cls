@isTest
private class LeadRepositoryTest {

    @testSetup
    static void setup() {

        List<Lead> leads = new List<Lead>();

        leads.add(new Lead(
            LastName = 'HotOne', Company = 'HotCo', Industry = 'Technology',
            AnnualRevenue = 60000000, Email = 'a@hotco.com'
        ));
        leads.add(new Lead(
            LastName = 'HotTwo', Company = 'HotCo2', Industry = 'Technology',
            AnnualRevenue = 55000000, Email = 'b@hotco2.com'
        ));
        leads.add(new Lead(
            LastName = 'ColdOne', Company = 'SmallCo', Industry = 'Retail',
            Email = 'c@smallco.com'
        ));
        leads.add(new Lead(
            LastName = 'Finance Person', Company = 'FinCo', Industry = 'Finance',
            AnnualRevenue = 20000000, Email = 'd@finco.com'
        ));

        insert leads;
    }

    @isTest
    static void testGetLeadById_ReturnsRecord() {

        Lead source = [SELECT Id FROM Lead WHERE Company = 'HotCo' LIMIT 1];

        Test.startTest();
        Lead result = LeadRepository.getLeadById(source.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('HotCo', result.Company);
    }

    @isTest
    static void testGetLeadById_NullId_ReturnsNull() {

        Test.startTest();
        Lead result = LeadRepository.getLeadById(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @isTest
    static void testGetLeadById_NonExistentId_ReturnsNull() {

        Lead temp = new Lead(LastName = 'Temp', Company = 'TempCo');
        insert temp;
        Id fakeId = temp.Id;
        delete temp;

        Test.startTest();
        Lead result = LeadRepository.getLeadById(fakeId);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @isTest
    static void testGetHotLeads_ReturnsOnlyHotPriority() {

        // Priority_Zone__c is set by LeadScoringService on insert, so
        // pull whatever actually landed Hot rather than assuming values.
        List<Lead> hot = [SELECT Id FROM Lead WHERE Priority_Zone__c = 'Hot'];

        Test.startTest();
        List<Lead> result = LeadRepository.getHotLeads();
        Test.stopTest();

        System.assertEquals(hot.size(), result.size());
        for (Lead l : result) {
            System.assertEquals('Hot', l.Priority_Zone__c);
        }
    }

    @isTest
    static void testGetHotLeads_RespectsCustomLimit() {

        Test.startTest();
        List<Lead> result = LeadRepository.getHotLeads(1);
        Test.stopTest();

        System.assert(result.size() <= 1);
    }

    @isTest
    static void testGetLeadsByIndustry_FiltersCorrectly() {

        Test.startTest();
        List<Lead> result = LeadRepository.getLeadsByIndustry('Finance');
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('FinCo', result[0].Company);
    }

    @isTest
    static void testGetLeadsByIndustry_BlankIndustry_ReturnsEmpty() {

        Test.startTest();
        List<Lead> result = LeadRepository.getLeadsByIndustry('');
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetHighValueLeads_DefaultThreshold() {

        Test.startTest();
        List<Lead> result = LeadRepository.getHighValueLeads();
        Test.stopTest();

        for (Lead l : result) {
            System.assert(l.AnnualRevenue >= 10000000);
        }
    }

    @isTest
    static void testGetHighValueLeads_CustomThreshold() {

        Test.startTest();
        List<Lead> result = LeadRepository.getHighValueLeads(50000000, 50);
        Test.stopTest();

        System.assertEquals(2, result.size());
    }

    @isTest
    static void testSearchLeads_MatchesCompanyName() {

        Test.startTest();
        List<Lead> result = LeadRepository.searchLeads('HotCo');
        Test.stopTest();

        System.assertEquals(2, result.size());
    }

    @isTest
    static void testSearchLeads_EscapesWildcardCharacters() {

        Lead weird = new Lead(LastName = 'Weird', Company = '50% Off Deals Inc');
        insert weird;

        Test.startTest();
        // A literal "%" search should not match every record via wildcard expansion
        List<Lead> result = LeadRepository.searchLeads('50%');
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('50% Off Deals Inc', result[0].Company);
    }

    @isTest
    static void testSearchLeads_BlankKeyword_ReturnsEmpty() {

        Test.startTest();
        List<Lead> result = LeadRepository.searchLeads('');
        Test.stopTest();

        System.assertEquals(0, result.size());
    }
}