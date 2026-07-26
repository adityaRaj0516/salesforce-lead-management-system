/**
 * LeadController
 *
 * REST entry point for Lead CRUD + list queries.
 *
 * /services/apexrest/leads/{Id}   GET/PUT/DELETE  - single record
 * /services/apexrest/leads        GET             - list, filtered by
 *                                                    one of: ?priority=hot,
 *                                                    ?industry=X, ?search=Y,
 *                                                    ?minRevenue=Z
 * /services/apexrest/leads        POST            - create
 *
 * Inbound JSON is never deserialized straight into a Lead SObject.
 * That pattern (JSON.deserialize(body, Lead.class)) lets a caller set
 * any field on the object — including OwnerId, IsConverted, or Id —
 * which is a mass-assignment risk on an externally-exposed endpoint.
 * Instead, buildLeadFromJson() explicitly whitelists which fields a
 * caller may set.
 */
@RestResource(urlMapping='/leads/*')
global with sharing class LeadController {

    private static final String CONTENT_TYPE = 'application/json';

    // Fields an external caller is allowed to set via the API.
    // Deliberately excludes Id, OwnerId, IsConverted, and any scoring
    // output fields (Lead_Score__c etc.) — those are system-computed.
    private static final Set<String> WRITABLE_FIELDS = new Set<String>{
        'FirstName', 'LastName', 'Company', 'Email', 'Phone', 'Industry',
        'AnnualRevenue', 'NumberOfEmployees', 'Website', 'LeadSource',
        'ProductInterest__c', 'NumberofLocations__c'
    };

    private class BadRequestException extends Exception {}

    // ============================================================
    // GET  /leads/{Id}  or  /leads?priority=hot|industry=X|search=Y|minRevenue=Z
    // ============================================================
    @HttpGet
    global static void getLead() {
        try {
            if (!Schema.sObjectType.Lead.isAccessible()) {
                sendError(403, 'Insufficient permissions to read leads.');
                return;
            }

            String leadIdParam = extractIdFromUri();

            if (String.isNotBlank(leadIdParam)) {
                handleGetSingle(leadIdParam);
            } else {
                handleGetList();
            }
        } catch (BadRequestException ex) {
            sendError(400, ex.getMessage());
        } catch (Exception ex) {
            sendError(500, ex.getMessage());
        }
    }

    private static void handleGetSingle(String leadIdParam) {

        Id leadId = parseId(leadIdParam);
        Lead lead = LeadService.getLeadById(leadId);

        if (lead == null) {
            sendError(404, 'Lead not found.');
            return;
        }

        sendSuccess(200, lead);
    }

    private static void handleGetList() {

        Map<String, String> params = RestContext.request.params;
        List<Lead> results;

        if (params.containsKey('priority') && params.get('priority').equalsIgnoreCase('hot')) {
            results = LeadService.getHotLeads();
        } else if (params.containsKey('industry')) {
            results = LeadService.getLeadsByIndustry(params.get('industry'));
        } else if (params.containsKey('search')) {
            results = LeadService.searchLeads(params.get('search'));
        } else if (params.containsKey('minRevenue')) {
            results = LeadRepository.getHighValueLeads(
                Decimal.valueOf(params.get('minRevenue')), 200
            );
        } else {
            throw new BadRequestException(
                'Provide a Lead Id, or a query parameter: priority=hot, industry, search, or minRevenue.'
            );
        }

        sendSuccess(200, results);
    }

    // ============================================================
    // POST /leads
    // ============================================================
    @HttpPost
    global static void createLead() {
        try {
            if (!Schema.sObjectType.Lead.isCreateable()) {
                sendError(403, 'Insufficient permissions to create leads.');
                return;
            }

            String body = RestContext.request.requestBody?.toString();

            if (String.isBlank(body)) {
                sendError(400, 'Request body is required.');
                return;
            }

            Lead lead = buildLeadFromJson(body);
            Lead createdLead = LeadService.createLead(lead);
            sendSuccess(201, createdLead);

        } catch (BadRequestException ex) {
            sendError(400, ex.getMessage());
        } catch (LeadService.LeadServiceException ex) {
            sendError(400, ex.getMessage());
        } catch (JSONException ex) {
            sendError(400, 'Malformed JSON: ' + ex.getMessage());
        } catch (Exception ex) {
            sendError(500, ex.getMessage());
        }
    }

    // ============================================================
    // PUT /leads/{Id}
    // ============================================================
    @HttpPut
    global static void updateLead() {
        try {
            if (!Schema.sObjectType.Lead.isUpdateable()) {
                sendError(403, 'Insufficient permissions to update leads.');
                return;
            }

            String leadIdParam = extractIdFromUri();

            if (String.isBlank(leadIdParam)) {
                sendError(400, 'Lead Id is required in the URL.');
                return;
            }

            Id leadId = parseId(leadIdParam);

            String body = RestContext.request.requestBody?.toString();
            if (String.isBlank(body)) {
                sendError(400, 'Request body is required.');
                return;
            }

            Lead lead = buildLeadFromJson(body);
            lead.Id = leadId; // URL Id always wins over anything in the body

            Lead updatedLead = LeadService.updateLead(lead);
            sendSuccess(200, updatedLead);

        } catch (BadRequestException ex) {
            sendError(400, ex.getMessage());
        } catch (LeadService.LeadServiceException ex) {
            sendError(400, ex.getMessage());
        } catch (JSONException ex) {
            sendError(400, 'Malformed JSON: ' + ex.getMessage());
        } catch (Exception ex) {
            sendError(500, ex.getMessage());
        }
    }

    // ============================================================
    // DELETE /leads/{Id}
    // ============================================================
    @HttpDelete
    global static void deleteLead() {
        try {
            if (!Schema.sObjectType.Lead.isDeletable()) {
                sendError(403, 'Insufficient permissions to delete leads.');
                return;
            }

            String leadIdParam = extractIdFromUri();

            if (String.isBlank(leadIdParam)) {
                sendError(400, 'Lead Id is required in the URL.');
                return;
            }

            Id leadId = parseId(leadIdParam);
            LeadService.deleteLead(leadId);

            RestContext.response.statusCode = 204;

        } catch (BadRequestException ex) {
            sendError(400, ex.getMessage());
        } catch (LeadService.LeadServiceException ex) {
            sendError(400, ex.getMessage());
        } catch (Exception ex) {
            sendError(500, ex.getMessage());
        }
    }

    // ============================================================
    // Helpers
    // ============================================================

    /**
     * Pulls the Id segment off the URL, e.g. /leads/00Q123 -> "00Q123".
     * Returns null when the request targets the collection endpoint
     * (/leads or /leads/) rather than a specific record.
     */
    private static String extractIdFromUri() {

        String uri = RestContext.request.requestURI;
        String candidate = uri.substringAfterLast('/');

        if (String.isBlank(candidate) || candidate.equalsIgnoreCase('leads')) {
            return null;
        }

        return candidate;
    }

    /**
     * Casting a malformed String to Id throws a raw system exception
     * with a confusing message if left uncaught. Wrapping it here lets
     * every caller return a clean 400 instead of leaking a 500.
     */
    private static Id parseId(String rawId) {
        try {
            return (Id) rawId;
        } catch (Exception ex) {
            throw new BadRequestException('"' + rawId + '" is not a valid Lead Id.');
        }
    }

    /**
     * Deserializes the request body into an untyped map first, then
     * copies over only whitelisted fields onto a new Lead. This is the
     * mass-assignment guard: a caller cannot use this endpoint to set
     * Id, OwnerId, IsConverted, or any other field outside WRITABLE_FIELDS.
     */
    private static Lead buildLeadFromJson(String body) {

        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(body);
        Lead lead = new Lead();

        for (String fieldName : WRITABLE_FIELDS) {
            if (raw.containsKey(fieldName)) {
                lead.put(fieldName, raw.get(fieldName));
            }
        }

        return lead;
    }

    private static void sendSuccess(Integer statusCode, Object data) {
        Map<String, Object> envelope = new Map<String, Object>{
            'success' => true,
            'data' => data
        };
        sendResponse(statusCode, envelope);
    }

    private static void sendError(Integer statusCode, String message) {
        Map<String, Object> envelope = new Map<String, Object>{
            'success' => false,
            'message' => message
        };
        sendResponse(statusCode, envelope);
    }

    private static void sendResponse(Integer statusCode, Object body) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', CONTENT_TYPE);
        if (body != null) {
            RestContext.response.responseBody = Blob.valueOf(JSON.serializePretty(body));
        }
    }
}