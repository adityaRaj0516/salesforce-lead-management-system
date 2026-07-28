@isTest
private class EinsteinPredictionServiceTest {

    @isTest
    static void testPredict_ValidLead_ReturnsPrediction() {

        Lead l = new Lead(
            LastName = 'Valid', Company = 'ValidCo',
            Industry = 'Technology', AnnualRevenue = 60000000, NumberOfEmployees = 150
        );
        insert l; // trigger runs rule scoring + applyEinsteinPrediction

        Lead scored = [
            SELECT Lead_Score__c, Conversion_Probability__c, Score_Source__c
            FROM Lead WHERE Id = :l.Id
        ];

        System.assertEquals('Einstein', scored.Score_Source__c);
        System.assert(scored.Conversion_Probability__c > 0);
    }

    @isTest
    static void testPredict_DirectCall_ReturnsExpectedProbability() {

        Lead l = new Lead(
            LastName = 'Direct', Company = 'DirectCo',
            Industry = 'Technology', AnnualRevenue = 60000000, NumberOfEmployees = 150
        );
        insert l;

        // NOTE: buildRequestPayload() reads Industry, AnnualRevenue,
        // NumberOfEmployees, LeadSource, Website, ProductInterest__c,
        // NumberofLocations__c, and Lead_Score__c off the Lead. Every
        // one of those fields must be in this SELECT list, or Salesforce
        // throws "SObject row was retrieved via SOQL without querying
        // the requested field" the moment predict() touches a field
        // that wasn't queried — even though the field exists and is
        // simply null/unset on this record.
        Lead scored = [
            SELECT Id,
                Company,
                Industry,
                AnnualRevenue,
                NumberOfEmployees,
                LeadSource,
                Website,
                ProductInterest__c,
                NumberofLocations__c,
                Lead_Score__c
            FROM Lead
            WHERE Id = :l.Id
        ];

        Test.startTest();
        EinsteinPredictionService.PredictionResult result = EinsteinPredictionService.predict(scored);
        Test.stopTest();

        System.assertEquals(false, result.fromFallback);
        System.assertEquals('mock-v0', result.modelVersion);

        Decimal expected = ((scored.Lead_Score__c / 100.0) + 0.05).setScale(2);
        if (expected > 1) {
            expected = 1;
        }
        System.assertEquals(expected, result.probability);
    }

    @isTest
    static void testPredict_NullLead_ReturnsFallback() {

        Test.startTest();
        EinsteinPredictionService.PredictionResult result = EinsteinPredictionService.predict(null);
        Test.stopTest();

        System.assertEquals(true, result.fromFallback);
        System.assertEquals(null, result.probability);
        System.assertEquals(null, result.modelVersion);
    }

    @isTest
    static void testPredict_MissingCompany_ReturnsFallback() {

        // Not inserted - Company intentionally left blank to test
        // validateLead() directly without hitting the required-field
        // validation rule on insert.
        Lead l = new Lead(LastName = 'NoCompany', Industry = 'Technology');

        Test.startTest();
        EinsteinPredictionService.PredictionResult result = EinsteinPredictionService.predict(l);
        Test.stopTest();

        System.assertEquals(true, result.fromFallback);
    }

    @isTest
    static void testPredict_NoSignalFields_ReturnsFallback() {

        Lead l = new Lead(LastName = 'NoSignals', Company = 'NoSignalsCo');

        Test.startTest();
        EinsteinPredictionService.PredictionResult result = EinsteinPredictionService.predict(l);
        Test.stopTest();

        System.assertEquals(true, result.fromFallback);
    }

    @isTest
    static void testFallback_LeavesRuleBasedScoreUntouched() {

        // A lead with Company but no Industry/Revenue/Employees passes
        // LeadValidator (Company is the only hard requirement) but
        // fails EinsteinPredictionService's own validation, so
        // Score_Source__c should remain 'Rule'.
        Lead l = new Lead(LastName = 'Fallback', Company = 'FallbackCo');
        insert l;

        Lead result = [SELECT Score_Source__c, Conversion_Probability__c, Lead_Score__c FROM Lead WHERE Id = :l.Id];

        System.assertEquals('Rule', result.Score_Source__c);
        System.assertEquals(result.Lead_Score__c, result.Conversion_Probability__c);
    }

    @isTest
    static void testPredictionResult_ConstructorAssignsFieldsCorrectly() {

        EinsteinPredictionService.PredictionResult result =
            new EinsteinPredictionService.PredictionResult(0.65, 'mock-v0', false);

        System.assertEquals(0.65, result.probability);
        System.assertEquals('mock-v0', result.modelVersion);
        System.assertEquals(false, result.fromFallback);
    }
}