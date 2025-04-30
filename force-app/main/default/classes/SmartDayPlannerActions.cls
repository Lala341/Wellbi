public without sharing class SmartDayPlannerActions {

    @InvocableMethod(
        label='Save Planning'
        description='Save the planning on the calendar of the user.'
    )
    public static List<ConfirmPlanningResponse> confirmActionsSchedules(List<ConfirmPlanningRequest> requests) {
        List<ConfirmPlanningResponse> responses = new List<ConfirmPlanningResponse>();

        for (ConfirmPlanningRequest req : requests) {
            try {
                // Manually parse the JSON strings into lists of objects
                List<TaskSchedule> scheduleTasks = parseTaskSchedules(req.scheduleTasks);
                List<EventReschedule> rescheduleEvents = parseEventReschedules(req.rescheduleEvents);
                List<TaskDefer> deferTasks = parseTaskDefers(req.deferTasks);
                List<TaskDoNothing> doNothingTasks = parseTaskDoNothings(req.doNothingTasks);
                
                 if (!scheduleTasks.isEmpty()) {
                    for (TaskSchedule task : scheduleTasks) {
                        scheduleTask(task);
                    }
                }
                
                // Handle rescheduling events
                if (!rescheduleEvents.isEmpty()) {
                    for (EventReschedule event : rescheduleEvents) {
                        rescheduleEvent(event);
                    }
                }

                // Handle deferring tasks
                if (!deferTasks.isEmpty()) {
                    for (TaskDefer task : deferTasks) {
                        deferTask(task);
                    }
                }

                // Handle tasks that need no action
                if (!doNothingTasks.isEmpty()) {
                    for (TaskDoNothing task : doNothingTasks) {
                        // No action needed
                    }
                }
                
                responses.add(new ConfirmPlanningResponse('Success', 'Task and Event scheduled successfully.'));
            } catch (Exception e) {
                responses.add(new ConfirmPlanningResponse('Failed', 'Error: ' + e.getMessage()));
            }
        }

        return responses;
    }

    // Manually parse schedule tasks from the JSON string
    private static List<TaskSchedule> parseTaskSchedules(String scheduleTasksJson) {
        List<TaskSchedule> taskList = new List<TaskSchedule>();
        
        if (scheduleTasksJson != null && scheduleTasksJson != '[]') {
            // Remove the enclosing square brackets and split by the object separator
            String[] taskObjects = scheduleTasksJson.substring(1, scheduleTasksJson.length() - 1).split('},\\{');
            for (String taskStr : taskObjects) {
                // Manually parse each task object string
                taskStr = taskStr.replaceAll('[\\{\\}\\"]', '');  // Remove curly braces and quotes
                String[] taskFields = taskStr.split(',');
                TaskSchedule task = new TaskSchedule();
                for (String field : taskFields) {
                    String[] fieldParts = field.split(':');
                    if (fieldParts[0] == 'taskId') task.taskId = fieldParts[1];
                    if (fieldParts[0] == 'proposedStart') task.proposedStart = field.replace('proposedStart:','');
                    if (fieldParts[0] == 'proposedEnd') task.proposedEnd = field.replace('proposedEnd:','');
                }
                
                
                taskList.add(task);
                
            }
           
        }
        return taskList;
    }
    
    // Utility function to safely parse DateTime
    private static Datetime parseDateTime(String dateTimeString) {
   try {
            Datetime original = Datetime.valueOf(dateTimeString);
            return original.addHours(-15).addMinutes(-30);
        } catch (Exception e) {
            throw new IllegalArgumentException('Invalid date/time format: ' + dateTimeString);
        }    
    }

    // Manually parse rescheduled events from the JSON string
    private static List<EventReschedule> parseEventReschedules(String rescheduleEventsJson) {
        List<EventReschedule> eventList = new List<EventReschedule>();
        if (rescheduleEventsJson != null && rescheduleEventsJson != '[]') {
            String[] eventObjects = rescheduleEventsJson.substring(1, rescheduleEventsJson.length() - 1).split('},\\{');
            for (String eventStr : eventObjects) {
                eventStr = eventStr.replaceAll('[\\{\\}\\"]', '');  // Remove curly braces and quotes
                String[] eventFields = eventStr.split(',');
                EventReschedule event = new EventReschedule();
                for (String field : eventFields) {
                    String[] fieldParts = field.split(':');
                    if (fieldParts[0] == 'eventId') event.eventId = fieldParts[1];
                    if (fieldParts[0] == 'newStart') event.newStart = field.replace('newStart:','');
                    if (fieldParts[0] == 'newEnd') event.newEnd = field.replace('newEnd:','');
                }
                
                eventList.add(event);
            }
        }
        return eventList;
    }

    // Manually parse deferred tasks from the JSON string
    private static List<TaskDefer> parseTaskDefers(String deferTasksJson) {
        List<TaskDefer> taskList = new List<TaskDefer>();
        if (deferTasksJson != null && deferTasksJson != '[]') {
            String[] taskObjects = deferTasksJson.substring(1, deferTasksJson.length() - 1).split('},\\{');
            for (String taskStr : taskObjects) {
                taskStr = taskStr.replaceAll('[\\{\\}\\"]', '');
                String[] taskFields = taskStr.split(',');
                TaskDefer task = new TaskDefer();
                for (String field : taskFields) {
                    String[] fieldParts = field.split(':');
                    if (fieldParts[0] == 'taskId') task.taskId = fieldParts[1];
                    
                }
                taskList.add(task);
            }
        }
        return taskList;
    }

    // Manually parse "do nothing" tasks from the JSON string
    private static List<TaskDoNothing> parseTaskDoNothings(String doNothingTasksJson) {
        List<TaskDoNothing> taskList = new List<TaskDoNothing>();
        if (doNothingTasksJson != null && doNothingTasksJson != '[]') {
            String[] taskObjects = doNothingTasksJson.substring(1, doNothingTasksJson.length() - 1).split('},\\{');
            for (String taskStr : taskObjects) {
                taskStr = taskStr.replaceAll('[\\{\\}\\"]', '');
                String[] taskFields = taskStr.split(',');
                TaskDoNothing task = new TaskDoNothing();
                for (String field : taskFields) {
                    String[] fieldParts = field.split(':');
                    if (fieldParts[0] == 'taskId') task.taskId = fieldParts[1];
                    
                }
                taskList.add(task);
            }
        }
        return taskList;
    }

    // Method to schedule a task
    private static void scheduleTask(TaskSchedule taskRequest) {
    
    Task task = [SELECT Id,OwnerId,Subject,Description FROM Task WHERE Id = :taskRequest.taskId LIMIT 1];
        
        // Convert proposedStart and proposedEnd from String to Datetime
        Datetime startDatetime = parseDateTime(taskRequest.proposedStart);
        Datetime endDatetime = taskRequest.proposedEnd != null ? parseDateTime(taskRequest.proposedEnd) : null;
        
        // Set the status and the start/end date of the task
        // task.Status = 'In Progress';  // Assuming "Scheduled" is the status when the task is scheduled
        if (endDatetime != null) {
            task.Description = 'Scheduled until: ' + endDatetime.format(); 
             }
        
        update task;
   
   // Now create an Event in the calendar, using the task's details
    Event newEvent = new Event(
        Subject = task.subject +' - Task ' + task.Id ,  // Use the same subject as the task
        StartDateTime = startDatetime,  // Set start time from task
        EndDateTime = endDatetime,  // Set end time from task (if available)
        Description = task.Description,  // Set the description of the event (same as task's description)
        OwnerId = task.OwnerId,
        IsAllDayEvent = false  
    );
    
    // Insert the new Event to the database
    insert newEvent;
    
    System.debug('Event created successfully with ID: ' + newEvent.Id);
   
         
        
        
        
    }

    

    // Method to reschedule an event
    private static void rescheduleEvent(EventReschedule eventRequest) {
        Event event = [SELECT Id,Subject,StartDateTime,EndDateTime,Description FROM Event WHERE Id = :eventRequest.eventId LIMIT 1];
        
        // Convert newStart and newEnd from String to Datetime
        Datetime newStartDatetime = parseDateTime(eventRequest.newStart);
        Datetime newEndDatetime = parseDateTime(eventRequest.newEnd);
        
        // Update the event start and end time
        event.StartDateTime = newStartDatetime;
        event.EndDateTime = newEndDatetime;
        
        // Optionally, modify the description
        event.Description = 'Rescheduled event';  // Optional description modification

        update event;  // Save the rescheduled event
    }

    // Method to defer a task (set status to Deferred)
    private static void deferTask(TaskDefer taskRequest) {
        Task task = [SELECT Id,Status FROM Task WHERE Id = :taskRequest.taskId LIMIT 1];
        
        // Update the status to "Deferred"
        task.Status = 'Deferred';
        
        update task;  // Save the deferred task
    }

    // Inner classes for request and response
    public class ConfirmPlanningResponse {
        @InvocableVariable(label='Action Status' description='The status of the action (Success or Failure)')
        public String status;

        @InvocableVariable(label='Message' description='Message detailing success or failure')
        public String message;

        public ConfirmPlanningResponse(String status, String message) {
            this.status = status;
            this.message = message;
        }
    }

    public class ConfirmPlanningRequest {
        @InvocableVariable(label='Schedule Tasks' description='List of tasks to be scheduled.')
        public String scheduleTasks;  // This will be a string representation of the list

        @InvocableVariable(label='Reschedule Events' description='List of events to be rescheduled.')
        public String rescheduleEvents;  // This will be a string representation of the list

        @InvocableVariable(label='Defer Tasks' description='List of tasks to be deferred.')
        public String deferTasks;  // This will be a string representation of the list

        @InvocableVariable(label='Do Nothing Tasks' description='List of tasks with no action needed.')
        public String doNothingTasks;  // This will be a string representation of the list
    }

    public class TaskSchedule {
        @InvocableVariable(label='Task ID' description='The task to be scheduled.')
        public String taskId;
        
        @InvocableVariable(label='Proposed Start Date' description='Start time for scheduling the task as string.')
        public String proposedStart;

        @InvocableVariable(label='Proposed End Date' description='End time for scheduling the task as string.')
        public String proposedEnd;
    }

    public class EventReschedule {
        @InvocableVariable(label='Event ID' description='The event to be rescheduled.')
        public String eventId;
        
        @InvocableVariable(label='New Start Date' description='New start time for rescheduling the event as string.')
        public String newStart;

        @InvocableVariable(label='New End Date' description='New end time for rescheduling the event as string.')
        public String newEnd;
    }

    public class TaskDefer {
        @InvocableVariable(label='Task ID' description='The task to be deferred.')
        public Id taskId;
    }

    public class TaskDoNothing {
        @InvocableVariable(label='Task ID' description='The task where no action is needed.')
        public Id taskId;
    }
}