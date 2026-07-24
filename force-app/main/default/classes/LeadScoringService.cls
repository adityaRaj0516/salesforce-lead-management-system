public with sharing class LeadScoringService {

    public static void calculateScore(List<Lead> leads) {

        for (Lead lead : leads) {

            Integer score = 0;
            List<String> reasons = new List<String>();

            // Technology Industry
            if (lead.Industry == 'Technology') {
                score += 20;
                reasons.add('Technology Industry +20');
            }

            // Revenue > 5 Crore
            if (lead.AnnualRevenue != null && lead.AnnualRevenue > 50000000) {
                score += 15;
                reasons.add('Revenue > 5 Cr +15');
            }

            // Employees > 100
            if (lead.NumberOfEmployees != null && lead.NumberOfEmployees > 100) {
                score += 10;
                reasons.add('Employees > 100 +10');
            }

            // Website Present
            if (!String.isBlank(lead.Website)) {
                score += 5;
                reasons.add('Website Available +5');
            }

            // Corporate Email
            if (!String.isBlank(lead.Email)) {

                String email = lead.Email.toLowerCase();

                if (!(email.endsWith('@gmail.com')
                    || email.endsWith('@yahoo.com')
                    || email.endsWith('@hotmail.com')
                    || email.endsWith('@outlook.com'))) {

                    score += 10;
                    reasons.add('Corporate Email +10');
                }
            }
            
            if (score > 100) {
                score = 100;
            }
            
            lead.Lead_Score__c = score;
            lead.Priority_Zone__c = calculatePriority(score);
            lead.Conversion_Probability__c = calculateProbability(score);
            lead.Score_Status__c = 'Fresh';
            lead.Score_Source__c = 'Rule';
            lead.Score_Reason__c = buildReason(reasons, score);
            lead.Last_Scored_Date__c = System.now();

        }
    }

    private static String calculatePriority(Integer score) {

        if (score >= 80)
            return 'Hot';

        if (score >= 50)
            return 'Warm';

        return 'Cold';

    }

    private static Decimal calculateProbability(Integer score) {

        return Decimal.valueOf(score);

    }

    private static String buildReason(List<String> reasons, Integer score) {

        reasons.add('Total Score = ' + score);

        return String.join(reasons, '\n');

    }

}