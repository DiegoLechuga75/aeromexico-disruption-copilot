global with sharing class GetDisruptionImpact {
    global class Request {
        @InvocableVariable(label='Flight number' description='Flight number exactly as written, for example AM 9402' required=true)
        global String flightNumber;
    }
    global class Result {
        @InvocableVariable(label='Ranked passengers' description='Affected passengers, highest priority first, with booking Id and reasons')
        global String rankedPassengers;
        @InvocableVariable(label='Affected count' description='Number of affected bookings')
        global Integer affectedCount;
    }

    @InvocableMethod(label='Get Disruption Impact'
        description='Use when a flight is cancelled or delayed. Marks its bookings as Affected and returns the passengers ranked by priority, each with the reasons for its rank.')
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) { // agents send one request per call
            results.add(rank(req.flightNumber));
        }
        return results;
    }

    private static Result rank(String flightNumber) {
        List<PriorityScorer.Scored> ranked = PriorityScorer.rankFlight(flightNumber);
        Result res = new Result();
        res.affectedCount = ranked.size();
        if (ranked.isEmpty()) {
            res.rankedPassengers = 'No active bookings found on flight ' + flightNumber + '.';
            return res;
        }

        List<Booking__c> toMark = new List<Booking__c>();
        List<String> lines = new List<String>();
        Integer position = 1;
        for (PriorityScorer.Scored s : ranked) {
            toMark.add(new Booking__c(Id = s.booking.Id, Status__c = 'Affected'));
            String why = s.reasons.isEmpty() ? 'no special factors' : String.join(s.reasons, '; ');
            lines.add(String.valueOf(position++) + '. ' + s.booking.Passenger__r.Name
                + ' | booking ' + s.booking.Id + ' | PNR ' + s.booking.PNR__c
                + ' | score ' + s.score + ' | ' + why);
        }
        update toMark;
        res.rankedPassengers = String.join(lines, '\n');
        return res;
    }
}