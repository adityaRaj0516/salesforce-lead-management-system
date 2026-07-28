/**
 * @description Test class for ForecastService. Covers single-record and bulk
 * behavior, null-safety, boundary conditions on both revenue and confidence
 * thresholds, and out-of-range probability normalization.
 */

@isTest
private class ForecastServiceTest {

    // Null / empty input handling
    @isTest
    static void testGenerateForecast_nullSingleLead_doesNotThrow() {
        Test.startTest();
        ForecastService.generateForecast((Lead) null);
        Test.stopTest();
        // No assertion needed beyond "did not throw" -- method should be a safe no-op.
        System.assert(true, 'Passing null Lead should not throw an exception.');
    }

    @isTest
    static void testGenerateForecast_nullList_doesNotThrow() {
        Test.startTest();
        ForecastService.generateForecast((List<Lead>) null);
        Test.stopTest();
        System.assert(true, 'Passing null list should not throw an exception.');
    }

    @isTest
    static void testGenerateForecast_emptyList_doesNotThrow() {
        Test.startTest();
        ForecastService.generateForecast(new List<Lead>());
        Test.stopTest();
        System.assert(true, 'Passing an empty list should not throw an exception.');
    }

    @isTest
    static void testGenerateForecast_listContainingNullElement_isSkipped() {
        Lead validLead = buildLead(200000, 0.5);
        List<Lead> leads = new List<Lead>{ validLead, null };

        Test.startTest();
        ForecastService.generateForecast(leads);
        Test.stopTest();

        System.assertEquals(100000, validLead.Expected_Revenue__c,
            'Valid lead in a list with a null element should still be processed.');
    }

    @isTest
    static void testGenerateForecast_missingRevenueAndProbability_defaultsToZeroAndLow() {
        Lead lead = new Lead(LastName = 'NoData', Company = 'Acme');
        // AnnualRevenue and Conversion_Probability__c both left null.

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals(0, lead.Expected_Revenue__c,
            'Missing revenue/probability should result in zero expected revenue.');
        System.assertEquals('Low', lead.Forecast_Category__c);
        System.assertEquals('Low', lead.Forecast_Confidence__c);
    }

    // Expected revenue calculation

    @isTest
    static void testExpectedRevenue_calculatedCorrectly() {
        Lead lead = buildLead(1000000, 0.5);

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals(500000, lead.Expected_Revenue__c,
            'Expected revenue should equal AnnualRevenue * Conversion Probability.');
    }

    // Forecast Category boundary conditions

    @isTest
    static void testForecastCategory_highBoundary_isInclusive() {
        Lead lead = buildLead(500000, 1); // expected revenue == 500000 exactly

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals('High', lead.Forecast_Category__c,
            'Expected revenue exactly at 500000 should be High (inclusive boundary).');
    }

    @isTest
    static void testForecastCategory_justBelowHighBoundary_isMedium() {
        Lead lead = buildLead(499999, 1);

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals('Medium', lead.Forecast_Category__c,
            'Expected revenue just below 500000 should fall to Medium.');
    }

    @isTest
    static void testForecastCategory_mediumBoundary_isInclusive() {
        Lead lead = buildLead(100000, 1);

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals('Medium', lead.Forecast_Category__c,
            'Expected revenue exactly at 100000 should be Medium (inclusive boundary).');
    }

    @isTest
    static void testForecastCategory_justBelowMediumBoundary_isLow() {
        Lead lead = buildLead(99999, 1);

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals('Low', lead.Forecast_Category__c,
            'Expected revenue just below 100000 should fall to Low.');
    }

    // Forecast Confidence boundary conditions

    @isTest
    static void testForecastConfidence_highBoundary_isInclusive() {
        Lead lead = buildLead(100000, 0.80);

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals('High', lead.Forecast_Confidence__c,
            'Probability exactly at 0.80 should be High confidence (inclusive boundary).');
    }

    @isTest
    static void testForecastConfidence_mediumBoundary_isInclusive() {
        Lead lead = buildLead(100000, 0.60);

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals('Medium', lead.Forecast_Confidence__c,
            'Probability exactly at 0.60 should be Medium confidence (inclusive boundary).');
    }

    @isTest
    static void testForecastConfidence_justBelowMediumBoundary_isLow() {
        Lead lead = buildLead(100000, 0.59);

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals('Low', lead.Forecast_Confidence__c,
            'Probability just below 0.60 should be Low confidence.');
    }

    // Defensive normalization of out-of-range probability values

    @isTest
    static void testProbability_negativeValue_isClampedToZero() {
        Lead lead = buildLead(100000, -0.25);

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals(0, lead.Expected_Revenue__c,
            'Negative probability should be clamped to 0 for revenue calculation.');
        System.assertEquals('Low', lead.Forecast_Confidence__c);
    }

    @isTest
    static void testProbability_greaterThanOne_isClampedToOne() {
        // Simulates bad data, e.g. someone entering "80" meaning 80% instead of 0.80.
        Lead lead = buildLead(100000, 80);

        Test.startTest();
        ForecastService.generateForecast(lead);
        Test.stopTest();

        System.assertEquals(100000, lead.Expected_Revenue__c,
            'Probability above 1 should be clamped to 1, capping revenue at AnnualRevenue.');
        System.assertEquals('High', lead.Forecast_Confidence__c);
    }

    // Bulk behavior

    @isTest
    static void testGenerateForecast_bulkListOf200_processesAllRecords() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            leads.add(buildLead(600000, 0.9));
        }

        Test.startTest();
        ForecastService.generateForecast(leads);
        Test.stopTest();

        for (Lead lead : leads) {
            System.assertEquals(540000, lead.Expected_Revenue__c);
            System.assertEquals('High', lead.Forecast_Category__c);
            System.assertEquals('High', lead.Forecast_Confidence__c);
        }
    }

    // Test data helper
    private static Lead buildLead(Decimal annualRevenue, Decimal conversionProbability) {
        return new Lead(
            LastName = 'Test',
            Company = 'Test Co',
            AnnualRevenue = annualRevenue,
            Conversion_Probability__c = conversionProbability
        );
    }
}