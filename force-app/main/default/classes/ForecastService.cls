/**
 * @description Service class responsible for generating sales forecast details
 * (Expected Revenue, Forecast Category, and Forecast Confidence) for Leads.
 * Designed to be bulk-safe so it can be called from triggers, batch jobs,
 * or invocable actions without risking governor limit issues.
 *
 * @author Aditya Raj
 */
public with sharing class ForecastService {

    // Configuration constants (avoid magic numbers, ease maintenance)
    private static final Decimal HIGH_REVENUE_THRESHOLD    = 500000;
    private static final Decimal MEDIUM_REVENUE_THRESHOLD  = 100000;

    private static final Decimal HIGH_CONFIDENCE_THRESHOLD   = 0.80;
    private static final Decimal MEDIUM_CONFIDENCE_THRESHOLD = 0.60;

    private static final Decimal MIN_PROBABILITY = 0;
    private static final Decimal MAX_PROBABILITY = 1;

    public static final String CATEGORY_HIGH   = 'High';
    public static final String CATEGORY_MEDIUM = 'Medium';
    public static final String CATEGORY_LOW    = 'Low';

    /**
     * @description Generates and populates forecast fields for a single Lead.
     * Convenience overload that delegates to the bulk-safe implementation.
     * @param lead The Lead record to update. No-op if null.
     */
    public static void generateForecast(Lead lead) {
        if (lead == null) {
            return;
        }
        generateForecast(new List<Lead>{ lead });
    }

    /**
     * @description Generates and populates forecast fields for a list of Leads.
     * Bulk-safe: contains no SOQL/DML and performs pure in-memory computation,
     * so it can safely be invoked from trigger context on any batch size.
     * @param leads The list of Lead records to update. Null/empty lists are ignored.
     */
    public static void generateForecast(List<Lead> leads) {
        if (leads == null || leads.isEmpty()) {
            return;
        }

        for (Lead lead : leads) {
            if (lead == null) {
                continue;
            }

            Decimal probability = normalizeProbability(lead.Conversion_Probability__c);
            Decimal expectedRevenue = calculateExpectedRevenue(lead.AnnualRevenue, probability);

            lead.Expected_Revenue__c = expectedRevenue;
            lead.Forecast_Category__c = determineForecastCategory(expectedRevenue);
            lead.Forecast_Confidence__c = determineForecastConfidence(probability);
        }
    }

    /**
     * @description Calculates expected revenue as AnnualRevenue * Conversion Probability.
     * @param annualRevenue The Lead's annual revenue (may be null).
     * @param probability The normalized conversion probability (0-1, never null here).
     * @return The calculated expected revenue, never null.
     */
    private static Decimal calculateExpectedRevenue(Decimal annualRevenue, Decimal probability) {
        Decimal revenue = (annualRevenue == null) ? 0 : annualRevenue;
        return revenue * probability;
    }

    /**
     * @description Buckets expected revenue into a forecast category.
     * @param expectedRevenue The calculated expected revenue.
     * @return One of CATEGORY_HIGH, CATEGORY_MEDIUM, CATEGORY_LOW.
     */
    private static String determineForecastCategory(Decimal expectedRevenue) {
        if (expectedRevenue == null) {
            return CATEGORY_LOW;
        }
        if (expectedRevenue >= HIGH_REVENUE_THRESHOLD) {
            return CATEGORY_HIGH;
        }
        if (expectedRevenue >= MEDIUM_REVENUE_THRESHOLD) {
            return CATEGORY_MEDIUM;
        }
        return CATEGORY_LOW;
    }

    /**
     * @description Buckets conversion probability into a confidence level.
     * @param probability The normalized conversion probability (0-1).
     * @return One of CATEGORY_HIGH, CATEGORY_MEDIUM, CATEGORY_LOW.
     */
    private static String determineForecastConfidence(Decimal probability) {
        if (probability == null) {
            return CATEGORY_LOW;
        }
        if (probability >= HIGH_CONFIDENCE_THRESHOLD) {
            return CATEGORY_HIGH;
        }
        if (probability >= MEDIUM_CONFIDENCE_THRESHOLD) {
            return CATEGORY_MEDIUM;
        }
        return CATEGORY_LOW;
    }

    /**
     * @description Defensively normalizes a raw probability value: treats null as 0
     * and clamps out-of-range values into the valid [0,1] band so downstream
     * revenue math and category logic never operate on bad data (e.g. a value
     * entered as a percentage like 80 instead of 0.80).
     * @param rawProbability The raw Conversion_Probability__c value from the Lead.
     * @return A non-null Decimal between MIN_PROBABILITY and MAX_PROBABILITY.
     */
    private static Decimal normalizeProbability(Decimal rawProbability) {
        if (rawProbability == null) {
            return MIN_PROBABILITY;
        }
        if (rawProbability < MIN_PROBABILITY) {
            return MIN_PROBABILITY;
        }
        if (rawProbability > MAX_PROBABILITY) {
            return MAX_PROBABILITY;
        }
        return rawProbability;
    }
}