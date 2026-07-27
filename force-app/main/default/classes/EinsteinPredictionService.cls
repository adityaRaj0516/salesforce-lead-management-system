/**
 * EinsteinPredictionService
 *
 * Integration layer between LeadScoringService (rule-based scoring)
 * and an ML-driven conversion prediction.
 *
 * CURRENT PHASE: Mock only.
 * No HTTP callouts, Named Credentials, or Queueables exist yet. This
 * class is deliberately structured so that when a real Einstein
 * Prediction Builder model or external ML endpoint is ready, only
 * getMockPrediction() needs to be replaced with an actual callout —
 * predict(), validateLead(), and the PredictionResult contract used by
 * LeadScoringService do not need to change.
 *
 * buildRequestPayload() is included now, unused, as the JSON shape a
 * future callout would send. It costs nothing to keep and saves
 * re-deriving the payload structure later.
 */
public with sharing class EinsteinPredictionService {

    public class EinsteinPredictionException extends Exception {}

    /**
     * Structured result so callers can tell "the model predicted a low
     * probability" apart from "there was nothing to predict from, keep
     * the rule-based score" — collapsing both into a single Decimal
     * would make failures indistinguishable from a real low score.
     */
    public class PredictionResult {
        public Decimal probability;
        public String modelVersion;
        public Boolean fromFallback;

        public PredictionResult(Decimal probability, String modelVersion, Boolean fromFallback) {
            this.probability = probability;
            this.modelVersion = modelVersion;
            this.fromFallback = fromFallback;
        }
    }

    /**
     * Entry point used by LeadScoringService.
     * Synchronous and callout-free in this phase, so it is safe to
     * call directly from trigger context.
     */
    public static PredictionResult predict(Lead lead) {

        try {
            validateLead(lead);
        } catch (EinsteinPredictionException ex) {
            return fallback();
        }

        // Payload construction is exercised now even though nothing
        // consumes it yet, so buildRequestPayload() has real test
        // coverage before Phase 2 wires it into an actual callout.
        String payload = buildRequestPayload(lead);

        Decimal prediction = getMockPrediction(lead);

        return new PredictionResult(clamp(prediction), 'mock-v0', false);
    }

    /**
     * Validates that the lead carries enough information for a
     * prediction to be meaningful. A real model would reject a
     * near-empty record the same way — this mirrors that behavior so
     * the fallback path is exercised by a realistic condition rather
     * than never triggering at all.
     */
    private static void validateLead(Lead lead) {

        if (lead == null) {
            throw new EinsteinPredictionException('Lead cannot be null.');
        }

        if (String.isBlank(lead.Company)) {
            throw new EinsteinPredictionException('Lead is missing Company; insufficient data to predict.');
        }

        Boolean hasAnySignal = lead.Industry != null
            || lead.AnnualRevenue != null
            || lead.NumberOfEmployees != null;

        if (!hasAnySignal) {
            throw new EinsteinPredictionException(
                'Lead has no Industry, AnnualRevenue, or NumberOfEmployees; insufficient data to predict.'
            );
        }
    }

    /**
     * Builds the request payload a real callout would eventually send.
     * Not transmitted anywhere in this phase.
     */
    private static String buildRequestPayload(Lead lead) {

        Map<String, Object> features = new Map<String, Object>{
            'industry'          => lead.Industry,
            'annualRevenue'     => lead.AnnualRevenue,
            'employees'         => lead.NumberOfEmployees,
            'leadSource'        => lead.LeadSource,
            'hasWebsite'        => String.isNotBlank(lead.Website),
            'productInterest'   => lead.ProductInterest__c,
            'numberOfLocations' => lead.NumberofLocations__c,
            'ruleBasedScore'    => lead.Lead_Score__c
        };

        return JSON.serialize(features);
    }

    /**
     * Deterministic mock derived from the lead's own rule-based score,
     * rather than a fixed constant. This keeps predictions varied and
     * plausible across leads instead of every "Einstein" lead showing
     * an identical number, while still requiring zero external
     * dependencies.
     *
     * Deliberately deterministic (no randomness) so tests are
     * reproducible: the same lead always yields the same mock
     * prediction.
     */
    private static Decimal getMockPrediction(Lead lead) {

        Decimal ruleScore = lead.Lead_Score__c == null ? 0 : lead.Lead_Score__c;
        Decimal base = ruleScore / 100.0;
        Decimal adjustment = 0.05;

        return base + adjustment;
    }

    /**
     * Clamps any prediction into a valid 0-1 probability range,
     * regardless of source (mock now, real model later).
     */
    private static Decimal clamp(Decimal prediction) {

        if (prediction == null) {
            return 0;
        }
        if (prediction < 0) {
            return 0;
        }
        if (prediction > 1) {
            return 1;
        }

        return prediction.setScale(2);
    }

    /**
     * Returned when validation fails - i.e. there isn't enough data on
     * the lead to produce a meaningful prediction. fromFallback = true
     * tells LeadScoringService to leave the existing rule-based
     * Conversion_Probability__c and Score_Source__c untouched.
     */
    private static PredictionResult fallback() {
        return new PredictionResult(null, null, true);
    }
}