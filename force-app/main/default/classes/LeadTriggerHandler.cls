public with sharing class LeadTriggerHandler {

    public static void handle(
        List<Lead> newLeads,
        Map<Id, Lead> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {

        LeadService.processLeads(
            newLeads,
            oldMap,
            isInsert,
            isUpdate
        );

    }
}