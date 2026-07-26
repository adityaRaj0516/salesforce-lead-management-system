/**
 * LeadService
 *
 * Orchestration layer between LeadTrigger / LeadController and the
 * Validator / ScoringService / Repository classes.
 *
 * IMPORTANT: Validation and scoring are owned exclusively by
 * processLeads(), which runs from LeadTrigger on every insert/update.
 * createLead/updateLead/createLeads/updateLeads intentionally do NOT
 * call LeadValidator or LeadScoringService directly — doing so would
 * run that logic a second time (once here, once when the DML below
 * fires the trigger), which wastes CPU/SOQL and creates two places
 * that could drift out of sync. The trigger is the single source of
 * truth for when a Lead gets validated and scored.
 */
public with sharing class LeadService {

    public class LeadServiceException extends Exception {}

    // Fields that, if changed on update, warrant re-scoring. Anything
    // outside this list (Status, Description, OwnerId, etc.) does not
    // need a full re-score.
    private static final Set<String> SCORING_RELEVANT_FIELDS = new Set<String>{
        'Industry', 'AnnualRevenue', 'NumberOfEmployees', 'Website',
        'Email', 'LeadSource', 'ProductInterest__c', 'NumberofLocations__c'
    };

    // Trigger Entry Point
    public static void processLeads(
        List<Lead> leads,
        Map<Id, Lead> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (leads == null || leads.isEmpty()) {
            return;
        }

        LeadValidator.validate(leads);

        List<Lead> leadsToScore = isUpdate
            ? filterScoringRelevantChanges(leads, oldMap)
            : leads;

        if (!leadsToScore.isEmpty()) {
            LeadScoringService.calculateScore(leadsToScore);
        }
    }

    // Read Operations
    public static Lead getLeadById(Id leadId) {
        return LeadRepository.getLeadById(leadId);
    }

    public static List<Lead> getHotLeads() {
        return LeadRepository.getHotLeads();
    }

    public static List<Lead> getLeadsByIndustry(String industry) {
        return LeadRepository.getLeadsByIndustry(industry);
    }

    public static List<Lead> getHighValueLeads() {
        return LeadRepository.getHighValueLeads();
    }

    public static List<Lead> searchLeads(String keyword) {
        return LeadRepository.searchLeads(keyword);
    }

    // Operations
    // These deliberately do NOT call LeadValidator / LeadScoringService
    // directly — see class-level comment. Validation errors surface as
    // DmlException from addError() inside the trigger's before-save
    // context, which we catch and re-throw as a clean, caller-friendly
    // LeadServiceException.

    public static Lead createLead(Lead lead) {
        List<Lead> created = createLeads(new List<Lead>{ lead });
        return created.isEmpty() ? null : created[0];
    }

    public static List<Lead> createLeads(List<Lead> leads) {

        if (leads == null || leads.isEmpty()) {
            return new List<Lead>();
        }

        try {
            insert leads;
        } catch (DmlException e) {
            throw new LeadServiceException(
                'Failed to create lead(s): ' + e.getMessage()
            );
        }

        return leads;
    }

    public static Lead updateLead(Lead lead) {
        List<Lead> updated = updateLeads(new List<Lead>{ lead });
        return updated.isEmpty() ? null : updated[0];
    }

    public static List<Lead> updateLeads(List<Lead> leads) {

        if (leads == null || leads.isEmpty()) {
            return new List<Lead>();
        }

        try {
            update leads;
        } catch (DmlException e) {
            throw new LeadServiceException(
                'Failed to update lead(s): ' + e.getMessage()
            );
        }

        return leads;
    }

    public static void deleteLead(Id leadId) {
        if (leadId != null) {
            deleteLeads(new List<Id>{ leadId });
        }
    }

    public static void deleteLeads(List<Id> leadIds) {

        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        List<Database.DeleteResult> results = Database.delete(leadIds, false);

        List<String> errors = new List<String>();
        for (Database.DeleteResult result : results) {
            if (!result.isSuccess()) {
                for (Database.Error err : result.getErrors()) {
                    errors.add(err.getMessage());
                }
            }
        }

        if (!errors.isEmpty()) {
            throw new LeadServiceException(
                'Failed to delete one or more leads: ' + String.join(errors, '; ')
            );
        }
    }

    // Helpers
    /**
     * Returns only the leads where at least one scoring-relevant field
     * differs from its prior value. Leads updated for reasons unrelated
     * to scoring (status change, owner reassignment, notes, etc.) are
     * skipped to avoid unnecessary recomputation.
     */
    private static List<Lead> filterScoringRelevantChanges(
        List<Lead> leads,
        Map<Id, Lead> oldMap
    ) {
        List<Lead> changed = new List<Lead>();

        if (oldMap == null) {
            return leads;
        }

        for (Lead newLead : leads) {

            Lead oldLead = oldMap.get(newLead.Id);

            if (oldLead == null || hasScoringRelevantChange(newLead, oldLead)) {
                changed.add(newLead);
            }
        }

        return changed;
    }

    private static Boolean hasScoringRelevantChange(Lead newLead, Lead oldLead) {

        for (String fieldName : SCORING_RELEVANT_FIELDS) {
            if (newLead.get(fieldName) != oldLead.get(fieldName)) {
                return true;
            }
        }

        return false;
    }
}