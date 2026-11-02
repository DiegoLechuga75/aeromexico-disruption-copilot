global with sharing class IssueCompensation {
    @TestVisible
    private static final Decimal AUTO_APPROVAL_LIMIT_MXN = 2000; // sample policy, an assumption

    global class Request {
        @InvocableVariable(label='Case Id' description='Disruption Case of the passenger' required=true)
        global Id caseId;
        @InvocableVariable(label='Type' description='Meal voucher, Hotel, Travel credit or Refund' required=true)
        global String compensationType;
        @InvocableVariable(label='Amount (MXN)' required=true)
        global Decimal amountMxn;
    }
    global class Result {
        @InvocableVariable(label='Outcome' description='Applied, or why it was not applied')
        global String outcome;
    }

    @InvocableMethod(label='Issue Compensation'
        description='Records compensation on a disruption Case. Amounts above the auto-approval limit are not applied and need a supervisor.')
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result r = new Result();
            if (req.amountMxn > AUTO_APPROVAL_LIMIT_MXN) {
                update new Case(Id = req.caseId, Compensation_Status__c = 'Pending supervisor');
                r.outcome = 'NEEDS_SUPERVISOR_APPROVAL: ' + req.amountMxn + ' MXN is above the '
                    + AUTO_APPROVAL_LIMIT_MXN + ' MXN auto-approval limit. The amount was not applied; the Case is flagged for a supervisor.';
            } else {
                update new Case(Id = req.caseId, Compensation_Type__c = req.compensationType,
                    Compensation_Amount__c = req.amountMxn, Compensation_Status__c = 'Applied');
                r.outcome = 'Applied ' + req.compensationType + ' of ' + req.amountMxn
                    + ' MXN to Case ' + req.caseId + '.';
            }
            results.add(r);
        }
        return results;
    }
}