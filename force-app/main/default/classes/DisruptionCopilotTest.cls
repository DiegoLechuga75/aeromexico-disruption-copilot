@IsTest
private class DisruptionCopilotTest {
    @TestSetup
    static void setup() {
        Datetime now = Datetime.now();
        Flight__c cancelled = new Flight__c(Name = 'AM 9402', Origin__c = 'MEX', Destination__c = 'MTY',
            Departure__c = now.addHours(2), Arrival__c = now.addHours(3), Status__c = 'Cancelled', Seats_Available__c = 0);
        Flight__c later = new Flight__c(Name = 'AM 9410', Origin__c = 'MEX', Destination__c = 'MTY',
            Departure__c = now.addHours(4), Arrival__c = now.addHours(5), Status__c = 'Scheduled', Seats_Available__c = 2);
        insert new List<Flight__c>{ cancelled, later };

        Contact urgent = new Contact(LastName = 'Urgent', Loyalty_Tier__c = 'Classic');
        Contact regular = new Contact(LastName = 'Regular', Loyalty_Tier__c = 'Classic');
        insert new List<Contact>{ urgent, regular };
        insert new List<Booking__c>{
            new Booking__c(Passenger__c = regular.Id, Flight__c = cancelled.Id, PNR__c = 'AAA111', Status__c = 'Confirmed'),
            new Booking__c(Passenger__c = urgent.Id, Flight__c = cancelled.Id, PNR__c = 'BBB222', Status__c = 'Confirmed')
        };
        insert new Case(ContactId = urgent.Id, Subject = 'Surgery trip', Description = 'Surgery tomorrow', Time_Critical__c = true);
    }

    @IsTest
    static void rankingPutsTimeCriticalPassengerFirst() {
        GetDisruptionImpact.Request req = new GetDisruptionImpact.Request();
        req.flightNumber = 'AM 9402';
        GetDisruptionImpact.Result res = GetDisruptionImpact.run(new List<GetDisruptionImpact.Request>{ req })[0];

        Assert.areEqual(2, res.affectedCount);
        Assert.isTrue(res.rankedPassengers.startsWith('1. Urgent'), res.rankedPassengers);
        Assert.areEqual(0, [SELECT COUNT() FROM Booking__c WHERE Status__c = 'Confirmed']);
    }

    @IsTest
    static void rebookTakesASeatAndOpensACase() {
        Booking__c b = [SELECT Id FROM Booking__c WHERE PNR__c = 'BBB222'];
        RebookPassenger.Request req = new RebookPassenger.Request();
        req.bookingId = b.Id;
        req.newFlightNumber = 'AM 9410';
        RebookPassenger.Result res = RebookPassenger.run(new List<RebookPassenger.Request>{ req })[0];

        Assert.isNotNull(res.caseId);
        Assert.areEqual(1, [SELECT Seats_Available__c FROM Flight__c WHERE Name = 'AM 9410'].Seats_Available__c);
        Assert.areEqual('Rebooked', [SELECT Status__c FROM Booking__c WHERE Id = :b.Id].Status__c);
    }

    @IsTest
    static void compensationAboveLimitIsNotApplied() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        IssueCompensation.Request req = new IssueCompensation.Request();
        req.caseId = c.Id;
        req.compensationType = 'Travel credit';
        req.amountMxn = IssueCompensation.AUTO_APPROVAL_LIMIT_MXN + 1;
        IssueCompensation.Result res = IssueCompensation.run(new List<IssueCompensation.Request>{ req })[0];

        Assert.isTrue(res.outcome.startsWith('NEEDS_SUPERVISOR_APPROVAL'));
        Case after = [SELECT Compensation_Amount__c, Compensation_Status__c FROM Case WHERE Id = :c.Id];
        Assert.isNull(after.Compensation_Amount__c);
        Assert.areEqual('Pending supervisor', after.Compensation_Status__c);
    }
}