global with sharing class FindRebookingOptions {
    global class Request {
        @InvocableVariable(label='Booking Id' description='Id of the affected booking' required=true)
        global Id bookingId;
    }
    global class Result {
        @InvocableVariable(label='Options' description='Up to 3 later flights to the same destination with free seats')
        global String options;
    }

    @InvocableMethod(label='Find Rebooking Options'
        description='Returns up to 3 scheduled flights on the same route as the booking, departing after the original flight, that still have free seats.')
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Booking__c b = [SELECT Flight__r.Origin__c, Flight__r.Destination__c, Flight__r.Departure__c
                            FROM Booking__c WHERE Id = :req.bookingId];
            List<String> lines = new List<String>();
            for (Flight__c f : [SELECT Name, Departure__c, Arrival__c, Seats_Available__c FROM Flight__c
                                WHERE Origin__c = :b.Flight__r.Origin__c
                                AND Destination__c = :b.Flight__r.Destination__c
                                AND Status__c = 'Scheduled' AND Seats_Available__c > 0
                                AND Departure__c > :b.Flight__r.Departure__c
                                ORDER BY Departure__c LIMIT 3]) {
                lines.add(f.Name + ' | departs ' + f.Departure__c.format('dd MMM HH:mm')
                    + ' | arrives ' + f.Arrival__c.format('dd MMM HH:mm')
                    + ' | ' + f.Seats_Available__c + ' seats left');
            }
            Result r = new Result();
            r.options = lines.isEmpty() ? 'No later flights with free seats.' : String.join(lines, '\n');
            results.add(r);
        }
        return results;
    }
}