public with sharing class LeadService {

    public static void processLeads(
        List<Lead> leads,
        Map<Id, Lead> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {

        // Validate incoming Leads
        LeadValidator.validate(leads);

        // Calculate lead score
        LeadScoringService.calculateScore(leads);

    }

}