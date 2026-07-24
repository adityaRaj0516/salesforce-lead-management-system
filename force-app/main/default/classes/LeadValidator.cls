public with sharing class LeadValidator {

    public static void validate(List<Lead> leads) {

        for (Lead lead : leads) {

            validateCompany(lead);
            validateRevenue(lead);
            validateEmployees(lead);
            validateWebsite(lead);

        }
    }

    private static void validateCompany(Lead lead) {

        if (String.isBlank(lead.Company)) {
            lead.Company.addError('Company is required.');
        }

    }

    private static void validateRevenue(Lead lead) {

        if (lead.AnnualRevenue != null && lead.AnnualRevenue < 0) {
            lead.AnnualRevenue.addError('Annual Revenue cannot be negative.');
        }

    }

    private static void validateEmployees(Lead lead) {

        if (lead.NumberOfEmployees != null && lead.NumberOfEmployees < 0) {
            lead.NumberOfEmployees.addError('Number of Employees cannot be negative.');
        }

    }

    private static void validateWebsite(Lead lead) {

        if (!String.isBlank(lead.Website)) {

            if (!(lead.Website.startsWith('http://') ||
                  lead.Website.startsWith('https://'))) {

                lead.Website.addError(
                    'Website must start with http:// or https://'
                );

            }

        }

    }

}