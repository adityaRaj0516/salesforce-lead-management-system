/**
 * LeadScoringService
 *
 * Rule-based lead scoring engine. All scoring weights live in static
 * config maps at the top of the class so new industries / lead sources /
 * product tiers can be added or re-weighted without touching the scoring
 * logic itself.
 *
 * Score_Source__c = 'Rule' is written here. When the Einstein-driven path
 * is wired in, it should call a separate entry point and set Score_Source__c = 'Einstein' instead of
 * being merged into this method.
 */

public with sharing class LeadScoringService {

    // Config: Industry weights
    private static final Map<String, Integer> INDUSTRY_SCORES = new Map<String, Integer>{
        'Technology'    => 20,
        'Finance'       => 18,
        'Healthcare'    => 16,
        'Manufacturing' => 12,
        'Education'     => 10
    };
    private static final Integer INDUSTRY_DEFAULT_SCORE = 5;

    // Config: Lead source weights
    private static final Map<String, Integer> LEAD_SOURCE_SCORES = new Map<String, Integer>{
        'Referral'         => 10,
        'Webinar'          => 10,
        'Web'              => 8,
        'Partner Referral' => 8,
        'Trade Show'       => 6,
        'Cold Call'        => 3,
        'Purchased List'   => 2
    };
    private static final Integer LEAD_SOURCE_DEFAULT_SCORE = 5;

    // Config: Product interest weights
    private static final Map<String, Integer> PRODUCT_INTEREST_SCORES = new Map<String, Integer>{
        'Enterprise'   => 10,
        'Premium'      => 8,
        'Professional' => 6,
        'Basic'        => 4
    };

    // Config: Priority zone thresholds
    private static final Integer HOT_THRESHOLD  = 80;
    private static final Integer WARM_THRESHOLD = 50;
    private static final Integer MAX_SCORE       = 100;

    private static final Set<String> FREE_EMAIL_DOMAINS = new Set<String>{
        'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com'
    };

    public static void calculateScore(List<Lead> leads) {

        for (Lead lead : leads) {

            List<String> reasons = new List<String>();

            Integer industryScore = scoreIndustry(lead, reasons);
            lead.Industry_Score__c = industryScore;

            Integer score = industryScore
                + scoreRevenue(lead, reasons)
                + scoreEmployees(lead, reasons)
                + scoreWebsite(lead, reasons)
                + scoreCorporateEmail(lead, reasons)
                + scoreLeadSource(lead, reasons)
                + scoreProductInterest(lead, reasons)
                + scoreLocations(lead, reasons);

            score = Math.min(score, MAX_SCORE);

            lead.Lead_Score__c            = score;
            lead.Priority_Zone__c         = calculatePriority(score);
            lead.Conversion_Probability__c = calculateProbability(score);
            lead.Score_Status__c          = 'Fresh';
            lead.Score_Source__c          = 'Rule';
            lead.Score_Reason__c          = buildReason(reasons, score);
            lead.Last_Scored_Date__c      = System.now();
        }
    }


    // Industry Score
    private static Integer scoreIndustry(Lead lead, List<String> reasons) {

        if (String.isBlank(lead.Industry)) {
            return 0;
        }

        Integer points = INDUSTRY_SCORES.containsKey(lead.Industry)
            ? INDUSTRY_SCORES.get(lead.Industry)
            : INDUSTRY_DEFAULT_SCORE;

        reasons.add(lead.Industry + ' Industry +' + points);
        return points;
    }

    // Revenue Score (tiered)
    private static Integer scoreRevenue(Lead lead, List<String> reasons) {

        if (lead.AnnualRevenue == null) {
            return 0;
        }

        Decimal revenue = lead.AnnualRevenue;

        if (revenue >= 50000000) {
            reasons.add('Revenue >= 5 Cr +20');
            return 20;
        }
        if (revenue >= 10000000) {
            reasons.add('Revenue >= 1 Cr +15');
            return 15;
        }
        if (revenue >= 1000000) {
            reasons.add('Revenue >= 10 Lakh +10');
            return 10;
        }

        reasons.add('Revenue Available +5');
        return 5;
    }

    // Employee Score (tiered)
    private static Integer scoreEmployees(Lead lead, List<String> reasons) {

        if (lead.NumberOfEmployees == null) {
            return 0;
        }

        Integer employees = lead.NumberOfEmployees;

        if (employees >= 500) {
            reasons.add('500+ Employees +15');
            return 15;
        }
        if (employees >= 100) {
            reasons.add('100+ Employees +10');
            return 10;
        }
        if (employees >= 20) {
            reasons.add('20+ Employees +6');
            return 6;
        }

        reasons.add('Small Company +2');
        return 2;
    }

    // Website Score
    private static Integer scoreWebsite(Lead lead, List<String> reasons) {

        if (String.isBlank(lead.Website)) {
            return 0;
        }

        reasons.add('Website Available +10');
        return 10;
    }

    // Corporate Email Score
    private static Integer scoreCorporateEmail(Lead lead, List<String> reasons) {

        if (String.isBlank(lead.Email) || !lead.Email.contains('@')) {
            return 0;
        }

        String domain = lead.Email.toLowerCase().substringAfter('@');

        if (FREE_EMAIL_DOMAINS.contains(domain)) {
            return 0;
        }

        reasons.add('Corporate Email +10');
        return 10;
    }

    // Lead Source Score
    private static Integer scoreLeadSource(Lead lead, List<String> reasons) {

        if (String.isBlank(lead.LeadSource)) {
            return 0;
        }

        Integer points = LEAD_SOURCE_SCORES.containsKey(lead.LeadSource)
            ? LEAD_SOURCE_SCORES.get(lead.LeadSource)
            : LEAD_SOURCE_DEFAULT_SCORE;

        reasons.add(lead.LeadSource + ' Lead Source +' + points);
        return points;
    }

    // Product Interest Score
    private static Integer scoreProductInterest(Lead lead, List<String> reasons) {

        if (String.isBlank(lead.ProductInterest__c)
            || !PRODUCT_INTEREST_SCORES.containsKey(lead.ProductInterest__c)) {
            return 0;
        }

        Integer points = PRODUCT_INTEREST_SCORES.get(lead.ProductInterest__c);
        reasons.add(lead.ProductInterest__c + ' Interest +' + points);
        return points;
    }

    // Location Score (tiered)
    private static Integer scoreLocations(Lead lead, List<String> reasons) {

        if (lead.NumberofLocations__c == null) {
            return 0;
        }

        Decimal locations = lead.NumberofLocations__c;

        if (locations >= 10) {
            reasons.add('10+ Locations +5');
            return 5;
        }
        if (locations >= 5) {
            reasons.add('5+ Locations +4');
            return 4;
        }
        if (locations >= 2) {
            reasons.add('2+ Locations +3');
            return 3;
        }

        reasons.add('Single Location +1');
        return 1;
    }

    // Priority Zone
    private static String calculatePriority(Integer score) {

        if (score >= HOT_THRESHOLD) {
            return 'Hot';
        }
        if (score >= WARM_THRESHOLD) {
            return 'Warm';
        }
        return 'Cold';
    }

    private static Decimal calculateProbability(Integer score) {

        Decimal normalized = score / 100.0;
        Decimal curved = normalized * normalized * (3 - 2 * normalized); // smoothstep
        return (curved * 100).setScale(2);
    }

    // Score Explanation
    private static String buildReason(List<String> reasons, Integer score) {

        reasons.add('--------------------------------');
        reasons.add('Final Score = ' + score);

        return String.join(reasons, '\n');
    }

}