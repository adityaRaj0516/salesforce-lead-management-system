/*
 * LeadRepository
 *
 * Selector class centralizing all SOQL access to Lead records. Field lists
 * are defined once as constants so scoring-model changes (new fields on
 * Lead_Score__c-related logic) only need to be updated in one place.
 *
 * WITH SECURITY_ENFORCED is applied to every query so field-level security
 * is respected regardless of caller profile. Record-level sharing is
 * handled by the `with sharing` class declaration.
 */
public with sharing class LeadRepository {

    private static final Integer DEFAULT_LIMIT = 200;
    private static final Integer MAX_LIMIT = 2000;

    private static final String CORE_FIELDS =
        'Id, FirstName, LastName, Company, Email, Phone, Industry, ' +
        'AnnualRevenue, NumberOfEmployees, Website, LeadSource';

    private static final String SCORING_FIELDS =
        'Lead_Score__c, Industry_Score__c, Priority_Zone__c, ' +
        'Conversion_Probability__c, ProductInterest__c, NumberofLocations__c';

    private static final String SUMMARY_FIELDS =
        'Id, FirstName, LastName, Company, Email, Industry, ' +
        'Lead_Score__c, Priority_Zone__c';

    // Single record by Id
    public static Lead getLeadById(Id leadId) {

        if (leadId == null) {
            return null;
        }

        String query = 'SELECT ' + CORE_FIELDS + ', ' + SCORING_FIELDS +
            ' FROM Lead WHERE Id = :leadId WITH SECURITY_ENFORCED LIMIT 1';

        List<Lead> leads = Database.query(query);
        return leads.isEmpty() ? null : leads[0];
    }

    // Hot leads, ranked
    public static List<Lead> getHotLeads() {
        return getHotLeads(DEFAULT_LIMIT);
    }

    public static List<Lead> getHotLeads(Integer recordLimit) {

        Integer safeLimit = clampLimit(recordLimit);

        String query = 'SELECT ' + SUMMARY_FIELDS + ', Conversion_Probability__c' +
            ' FROM Lead WHERE Priority_Zone__c = \'Hot\'' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Lead_Score__c DESC' +
            ' LIMIT :safeLimit';

        return Database.query(query);
    }

    // Leads by industry, ranked
    public static List<Lead> getLeadsByIndustry(String industry) {
        return getLeadsByIndustry(industry, DEFAULT_LIMIT);
    }

    public static List<Lead> getLeadsByIndustry(String industry, Integer recordLimit) {

        if (String.isBlank(industry)) {
            return new List<Lead>();
        }

        Integer safeLimit = clampLimit(recordLimit);

        String query = 'SELECT ' + SUMMARY_FIELDS + ', Phone' +
            ' FROM Lead WHERE Industry = :industry' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Lead_Score__c DESC' +
            ' LIMIT :safeLimit';

        return Database.query(query);
    }

    // High annual revenue leads
    public static List<Lead> getHighValueLeads() {
        return getHighValueLeads(10000000, DEFAULT_LIMIT);
    }

    public static List<Lead> getHighValueLeads(Decimal minRevenue, Integer recordLimit) {

        Integer safeLimit = clampLimit(recordLimit);

        String query = 'SELECT ' + SUMMARY_FIELDS + ', AnnualRevenue' +
            ' FROM Lead WHERE AnnualRevenue >= :minRevenue' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY AnnualRevenue DESC' +
            ' LIMIT :safeLimit';

        return Database.query(query);
    }

    // Keyword search across name/company
    public static List<Lead> searchLeads(String keyword) {

        if (String.isBlank(keyword)) {
            return new List<Lead>();
        }

        String escaped = escapeLikeWildcards(keyword);
        String searchTerm = '%' + escaped + '%';

        String query = 'SELECT ' + SUMMARY_FIELDS +
            ' FROM Lead' +
            ' WHERE Company LIKE :searchTerm' +
            ' OR FirstName LIKE :searchTerm' +
            ' OR LastName LIKE :searchTerm' +
            ' WITH SECURITY_ENFORCED' +
            ' ORDER BY Lead_Score__c DESC' +
            ' LIMIT 50';

        return Database.query(query);
    }

    // Helpers
    /*
     * Prevents callers from requesting an unbounded or excessively large
     * result set (protects the 50,000 row SOQL limit and response size
     * if these methods back a REST endpoint).
     */
    private static Integer clampLimit(Integer requested) {

        if (requested == null || requested <= 0) {
            return DEFAULT_LIMIT;
        }

        return Math.min(requested, MAX_LIMIT);
    }

    /*
     * Escapes LIKE wildcard characters so user-supplied search text is
     * treated literally rather than as a SOQL wildcard pattern.
     */
    private static String escapeLikeWildcards(String input) {

        return input
            .replace('\\', '\\\\')
            .replace('%', '\\%')
            .replace('_', '\\_');
    }
}