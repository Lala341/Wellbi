public without sharing class SmartDayPlanner {

    @InvocableMethod(
        label='Plan Smart Day'
        description='Returns a planned task schedule for the given user based on today’s events and open tasks.'
    )
    public static List<PlanningResponse> planSmartDay(List<PlanningRequest> requests) {
        Id userId = requests[0].userId;
        
        // Fetch the user's time zone using their UserId
User user = [SELECT TimeZoneSidKey FROM User WHERE Id = :userId LIMIT 1];
String timeZoneId = user.TimeZoneSidKey;

        List<Task> tasks = getUserOpenTasks(userId);
        List<Event> events = getUserEvents(userId);
        List<TimeSlot> freeSlots = calculateFreeSlots(events, userId, timeZoneId);
        PlanningResult result = suggestTaskSchedule(tasks, freeSlots, timeZoneId);

        // Map Events to EventInfo
        List<EventInfo> todayEvents = new List<EventInfo>();
        for (Event e : events) {
            todayEvents.add(new EventInfo(e, timeZoneId));
        }

        result.eventsToday = todayEvents;

        PlanningResponse response = new PlanningResponse();
        response.proposedSchedule = result.proposedSchedule;
        response.unassignedTasks = result.unassignedTasks;
        response.eventsToday = result.eventsToday;
        response.freeslots=freeSlots;

        return new List<PlanningResponse>{ response };
    }

    // Invocable request class
    public class PlanningRequest {
        
        @InvocableVariable public Id userId;
    }

    // Invocable response class
    public class PlanningResponse {
        @InvocableVariable(description='List of proposed tasks with suggested schedule.')
        public List<ProposedTask> proposedSchedule;

        @InvocableVariable(description='List of tasks that couldn’t be scheduled.')
        public List<ProposedTask> unassignedTasks;

        @InvocableVariable(description='List of events scheduled for today.')
        public List<EventInfo> eventsToday;
        
        @InvocableVariable(description='List of freeSlots for today.')
        public List<TimeSlot> freeslots;
    }

    // ----------------- Utility Methods -----------------

    public static List<Task> getUserOpenTasks(Id currentUserId) {
        Set<String> openStatuses = new Set<String>{'Not Started', 'In Progress', 'Waiting on someone else'};
        return [
            SELECT Id, Subject, Priority, Status, ActivityDate, OwnerId
            FROM Task
            WHERE OwnerId = :currentUserId
            AND Status IN :openStatuses
            
        ];
    }

    public static List<Event> getUserEvents(Id currentUserId) {
    

  // Define the start and end of the day (9am and 5pm) in the user's local time zone
    DateTime startOfDay = DateTime.newInstance(Date.today(), Time.newInstance(1, 0, 0, 0));
    DateTime endOfDay = DateTime.newInstance(Date.today(), Time.newInstance(23, 0, 0, 0));
return [
            SELECT Id, Subject, StartDateTime, EndDateTime
            FROM Event
            WHERE OwnerId = :currentUserId
            AND StartDateTime >= :startOfDay
            AND EndDateTime <= :endOfDay
            ORDER BY StartDateTime ASC
        ];
    }

public static Datetime getUtcDatetimeForHour(String timeZoneId, Integer hour) {

// Get the current time in UTC (using DateTime.now() as reference and then converting to UTC)
        DateTime localDateTime = DateTime.newInstance(DateTime.now().date(), Time.newInstance(hour, 0, 0, 0)); 
            
        return localDateTime;
    }

public static List<TimeSlot> calculateFreeSlots(List<Event> events, Id userId, String timeZoneId) {
    List<TimeSlot> freeSlots = new List<TimeSlot>();


DateTime nowIST = DateTime.now(); // Always IST

TimeZone tzIST = TimeZone.getTimeZone('Asia/Kolkata');
TimeZone tzParis = TimeZone.getTimeZone('Europe/Paris');

// Offsets in seconds
Integer offsetIST = tzIST.getOffset(nowIST) / 1000;
Integer offsetParis = tzParis.getOffset(nowIST) / 1000;
Integer offsetISTtoParis = offsetParis - offsetIST; // shift IST to Paris time

// Step 1: Midnight IST
DateTime istMidnight = DateTime.newInstance(nowIST.year(), nowIST.month(), nowIST.day(), 0, 0, 0);

// Step 2: Convert IST midnight to Paris midnight
DateTime parisMidnightInIST = istMidnight.addSeconds(offsetISTtoParis);

// Step 3: Add 9 and 17 hours for 9AM and 5PM Paris
DateTime paris9AM_IST = parisMidnightInIST.addHours(9);
DateTime paris5PM_IST = parisMidnightInIST.addHours(17);

// Step 4: Convert to UTC by removing IST offset
DateTime startUtc = paris9AM_IST.addSeconds(-offsetIST);
DateTime endUtc = paris5PM_IST.addSeconds(-offsetIST);

    // If there are no events, just return the full time range in UTC
    if (events == null || events.isEmpty()) {
        freeSlots.add(new TimeSlot(startUtc, endUtc));
        return freeSlots;
    }

    
    // Step 4: Loop through the events and find the available time slots
    DateTime currentStart = startUtc;
    for (Event e : events) {
        // Skip events that are outside the range
        if (e.EndDateTime <= currentStart || e.StartDateTime >= endUtc) continue;

        // Adjust the event's start and end times to fit within the available range
        DateTime eventStart = e.StartDateTime < currentStart ? currentStart : e.StartDateTime;
        DateTime eventEnd = e.EndDateTime > endUtc ? endUtc : e.EndDateTime;

        // Add a free slot before the event if there is time between the available window and the event
        if (eventStart > currentStart) {
            freeSlots.add(new TimeSlot(currentStart, eventStart));
        }

        // Update the current start time after the event
        currentStart = eventEnd;
    }

    // If there is still time left after the last event, add it as a free slot
    if (currentStart < endUtc) {
        freeSlots.add(new TimeSlot(currentStart, endUtc));
    }

    // Step 5: Convert all free slots back to Paris time (CEST/CET)
    List<TimeSlot> finalSlotsInParisTime = new List<TimeSlot>();
    for (TimeSlot slot : freeSlots) {
        DateTime startParisTime = slot.start;
        DateTime endParisTime = slot.endTime;
        finalSlotsInParisTime.add(new TimeSlot(startParisTime, endParisTime));
    }

    return finalSlotsInParisTime;

    
}






    public static PlanningResult suggestTaskSchedule(List<Task> tasks, List<TimeSlot> slots, String timeZoneId) {
        List<ProposedTask> proposed = new List<ProposedTask>();
        List<ProposedTask> unassigned = new List<ProposedTask>();

        List<TaskWrapper> wrappedTasks = new List<TaskWrapper>();
        for (Task t : tasks) {
            wrappedTasks.add(new TaskWrapper(t));
        }
        wrappedTasks.sort();

        for (TaskWrapper wrapper : wrappedTasks) {
            Task t = wrapper.task;
            Integer duration = 30;

            Boolean fit = false;
            for (TimeSlot slot : slots) {
                Long availableMinutes = (slot.endTime.getTime() - slot.start.getTime()) / (1000 * 60);
                if (availableMinutes >= duration) {
                    DateTime proposedStart = slot.start;
                    DateTime proposedEnd = slot.start.addMinutes(duration);
                    proposed.add(new ProposedTask(t.Id, t.Subject, t.Status, t.Priority, duration, proposedStart, proposedEnd, timeZoneId));
                    slot.start = proposedEnd;
                    fit = true;
                    break;
                }
            }

            if (!fit) {
                unassigned.add(new ProposedTask(t.Id, t.Subject, t.Status, t.Priority, duration, null, null, timeZoneId));
            }
        }

        return new PlanningResult(proposed, unassigned, new List<EventInfo>());
    }

    // ----------------- Support Classes -----------------

    public class TimeSlot {
        public DateTime start;
        public DateTime endTime;

        public TimeSlot(DateTime s, DateTime e) {
            this.start = s;
            this.endTime = e;
        }
    }

    public class TaskWrapper implements Comparable {
        public Task task;
        public TaskWrapper(Task t) {
            this.task = t;
        }
        public Integer compareTo(Object obj) {
            TaskWrapper other = (TaskWrapper)obj;
            Integer priority1 = getPriorityValue(task.Priority);
            Integer priority2 = getPriorityValue(other.task.Priority);

            if (priority1 != priority2) {
                return priority1 - priority2;
            }

            Date d1 = task.ActivityDate;
            Date d2 = other.task.ActivityDate;
            if (d1 != null && d2 != null) {
                if (d1 < d2) return -1;
                if (d1 > d2) return 1;
            } else if (d1 == null && d2 != null) {
                return 1;
            } else if (d1 != null && d2 == null) {
                return -1;
            }
            return 0;
        }
        public Integer getPriorityValue(String priority) {
            if (priority == 'High') return 1;
            if (priority == 'Normal') return 2;
            if (priority == 'Low') return 3;
            return 4;
        }
    }
    
  

public static String convertUtcToUserTimeZone(DateTime utcDateTime, String timeZoneId) {
    if (utcDateTime == null) return null;

    // This returns a correctly adjusted string based on the timezone
    return utcDateTime.format('yyyy-MM-dd HH:mm:ss', timeZoneId);
}



   public class EventInfo {
    @InvocableVariable public Id id;
    @InvocableVariable public String subject;
    @InvocableVariable public String startDateTime;
    @InvocableVariable public String endDateTime;

    public EventInfo(Event e, String timeZoneId) {
        this.id = e.Id;
        this.subject = e.Subject;
        this.startDateTime = SmartDayPlanner.convertUtcToUserTimeZone(e.StartDateTime, timeZoneId);
        this.endDateTime = SmartDayPlanner.convertUtcToUserTimeZone(e.EndDateTime, timeZoneId);
    }
}

public class ProposedTask {
    @InvocableVariable public Id taskId;
    @InvocableVariable public String subject;
    @InvocableVariable public String status;
    @InvocableVariable public String priority;
    @InvocableVariable public Integer durationMinutes;
    @InvocableVariable public String proposedStart;
    @InvocableVariable public String proposedEnd;
    @InvocableVariable public String timeZoneId;

    public ProposedTask(Id id, String subj, String stat, String pri, Integer dur, DateTime start, DateTime endt, String timeZoneId) {
        this.taskId = id;
        this.subject = subj;
        this.status = stat;
        this.priority = pri;
        this.durationMinutes = dur;
        this.proposedStart = SmartDayPlanner.convertUtcToUserTimeZone(start, timeZoneId);
        this.proposedEnd = SmartDayPlanner.convertUtcToUserTimeZone(endt, timeZoneId);
        this.timeZoneId=timeZoneId;
    }
}




    public class PlanningResult {
        public List<ProposedTask> proposedSchedule;
        public List<ProposedTask> unassignedTasks;
        public List<EventInfo> eventsToday;

        public PlanningResult(List<ProposedTask> proposed, List<ProposedTask> unassigned, List<EventInfo> events) {
            this.proposedSchedule = proposed;
            this.unassignedTasks = unassigned;
            this.eventsToday = events;
        }
    }
}