global with sharing class RebookPassenger {
    global class Request {
        @InvocableVariable(label='Booking Id' description='Id of the affected booking' required=true)
        global Id bookingId;
        @InvocableVariable(label='New flight number' description='Flight to move the passenger to, for example AM 9410' required=true)
        global String newFlightNumber;
    }
    global class Result {
        @InvocableVariable(label='Confirmation' description='What was changed')
        global String confirmation;
        @InvocableVariable(label='Case Id' description='Disruption Case opened for this passenger')
        global Id caseId;
    }

    @InvocableMethod(label='Rebook Passenger'
        description='Moves an affected booking to another flight, takes one seat, and opens a disruption Case. Only call after the human agent has explicitly confirmed.')
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) results.add(rebook(req));
        return results;
    }

    private static Result rebook(Request req) {
        Result res = new Result();
        Booking__c b = [SELECT Id, Flight__c, Passenger__c, Passenger__r.Name
                        FROM Booking__c WHERE Id = :req.bookingId];
        List<Flight__c> target = [SELECT Id, Name, Departure__c, Seats_Available__c FROM Flight__c
                                    WHERE Name = :req.newFlightNumber AND Status__c = 'Scheduled'
                                    LIMIT 1 FOR UPDATE];
        if (target.isEmpty() || target[0].Seats_Available__c < 1) {
            res.confirmation = 'Not rebooked: flight ' + req.newFlightNumber + ' is not available.';
            return res;
        }
        Flight__c f = target[0];
        b.Original_Flight__c = b.Flight__c;
        b.Flight__c = f.Id;
        b.Status__c = 'Rebooked';
        f.Seats_Available__c -= 1;
        Case c = new Case(ContactId = b.Passenger__c, Booking__c = b.Id, Origin = 'Web',
            Priority = 'High', Subject = 'DEMO Rebooked to ' + f.Name,
            Description = 'Original flight cancelled. Rebooked through the Disruption Copilot.');
        update b;
        update f;
        insert c;
        res.caseId = c.Id;
        res.confirmation = b.Passenger__r.Name + ' rebooked on ' + f.Name + ', departing '
            + f.Departure__c.format('dd MMM HH:mm') + '. Case ' + c.Id + ' opened.';
        return res;
    }
}