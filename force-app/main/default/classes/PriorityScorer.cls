public with sharing class PriorityScorer {
    public class Scored implements Comparable {
        public Booking__c booking;
        public Integer score = 0;
        public List<String> reasons = new List<String>();
        public Integer compareTo(Object other) {
            return ((Scored) other).score - this.score; // highest score first
        }
    }

    private static final Map<String, Integer> TIER_POINTS =
        new Map<String, Integer>{ 'Titanium' => 20, 'Platinum' => 15, 'Gold' => 10 };

    // Ranks the active bookings of a flight, highest priority first.
    // Shared by Get Disruption Impact and Propose Rebooking Plan, so both use the same order.
    public static List<Scored> rankFlight(String flightNumber) {
        List<Booking__c> bookings = [
            SELECT Id, PNR__c, Status__c, Passenger__c, Passenger__r.Name,
                    Passenger__r.Loyalty_Tier__c, Passenger__r.Special_Assistance__c
            FROM Booking__c
            WHERE Flight__r.Name = :flightNumber AND Status__c IN ('Confirmed', 'Affected')
        ];
        Set<Id> passengerIds = new Set<Id>();
        for (Booking__c b : bookings) passengerIds.add(b.Passenger__c);

        Map<Id, Case> urgentByPassenger = new Map<Id, Case>();
        for (Case c : [SELECT ContactId, Description FROM Case
                        WHERE ContactId IN :passengerIds AND Time_Critical__c = true
                        AND CreatedDate = LAST_N_DAYS:30]) {
            urgentByPassenger.put(c.ContactId, c);
        }

        List<Scored> ranked = new List<Scored>();
        for (Booking__c b : bookings) {
            ranked.add(score(b, urgentByPassenger.get(b.Passenger__c)));
        }
        ranked.sort();
        return ranked;
    }

    public static Scored score(Booking__c b, Case timeCriticalCase) {
        Scored s = new Scored();
        s.booking = b;
        String assistance = b.Passenger__r.Special_Assistance__c;
        if (assistance != null) {
            if (assistance.contains('Unaccompanied minor')) add(s, 60, 'unaccompanied minor');
            if (assistance.contains('Medical')) add(s, 50, 'medical assistance');
            if (assistance.contains('Wheelchair')) add(s, 40, 'wheelchair assistance');
        }
        if (timeCriticalCase != null) {
            add(s, 50, 'time-critical trip: ' + timeCriticalCase.Description);
        }
        String tier = b.Passenger__r.Loyalty_Tier__c;
        if (TIER_POINTS.containsKey(tier)) add(s, TIER_POINTS.get(tier), tier + ' member');
        return s;
    }

    private static void add(Scored s, Integer points, String reason) {
        s.score += points;
        s.reasons.add(reason);
    }
}