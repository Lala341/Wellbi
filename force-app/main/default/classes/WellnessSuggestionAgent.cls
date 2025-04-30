public without sharing class WellnessSuggestionAgent {

    @InvocableMethod(
        label='Suggest Wellness Activity'
        description='Analyzes the user’s sentiment, workload, and company wellness protocols to suggest a wellness activity.'
    )
    public static List<WellnessResponse> suggestWellnessActivity(List<WellnessRequest> requests) {
        Id userId = requests[0].userId;
        String userInput = requests[0].userInput;

        // Step 1: Analyze Sentiment
        String sentiment = analyzeSentimentHerokuServer(userInput);

        // Step 2: Analyze User Workload
        String workloadStatus = analyzeUserWorkload(userId);

        // Step 3: Generate Suggestion
        String wellnessSuggestion = generateWellnessSuggestion(sentiment, workloadStatus);

        // Step 4: Fetch Wellness Protocol from Knowledge Base
        String protocolInfo = fetchWellnessProtocol();

        // Step 5: Prepare Response
        WellnessResponse response = new WellnessResponse();
        response.suggestedActivity = wellnessSuggestion;
        response.protocolSummary = protocolInfo;
        response.sentimentDetected = sentiment;
        response.workloadStatus = workloadStatus;

        
        return new List<WellnessResponse>{ response };
    }

    // Request Class
    public class WellnessRequest {
        @InvocableVariable(required=true label='User ID')
        public Id userId;

        @InvocableVariable(required=true label='User Input Text')
        public String userInput;
    }

    // Response Class
    public class WellnessResponse {
        @InvocableVariable(description='Suggested wellness activity for the user.')
        public String suggestedActivity;

        @InvocableVariable(description='Summary of wellness protocols from Knowledge Base.')
        public String protocolSummary;

        @InvocableVariable(description='Sentiment detected from user input.')
        public String sentimentDetected;

        @InvocableVariable(description='Workload analysis result.')
        public String workloadStatus;
    }

    // --- PRIVATE SUPPORT METHODS ---
     public class HerokuSentimentResponse {
        public String sentiment;
        public Double polarity;
    }
    
    public static String analyzeSentimentHerokuServer(String userText) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://your-sentiment-api-5609a44f9229.herokuapp.com/analyze');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, String>{ 'text' => userText }));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            HerokuSentimentResponse response = (HerokuSentimentResponse) JSON.deserialize(res.getBody(), HerokuSentimentResponse.class);
            return response.sentiment + ' (score: ' + response.polarity + ')';
        } else {
            return 'Error: ' + res.getStatusCode();
        }
    }


    private static String analyzeUserWorkload(Id userId) {
        Integer openTasks = [SELECT COUNT() FROM Task WHERE OwnerId = :userId AND Status != 'Completed'];
        Integer todayMeetings = [SELECT COUNT() FROM Event WHERE OwnerId = :userId AND StartDateTime = TODAY];

        if (openTasks > 10 || todayMeetings > 5) {
            return 'overloaded';
        }
        return 'manageable';
    }

    private static String generateWellnessSuggestion(String sentiment, String workloadStatus) {
        if (sentiment == 'negative' || workloadStatus == 'overloaded') {
            return 'You might be stressed. Take a 5-minute meditation or go for a walk.';
        }
        if (sentiment == 'neutral') {
            return 'You seem balanced. Consider stretching or quick hydration.';
        }
        return 'Positive vibes detected! Keep a healthy rhythm with regular breaks.';
    }

    private static String fetchWellnessProtocol() {
    List<Knowledge__kav> articles = [
        SELECT Title, Summary, UrlName 
        FROM Knowledge__kav 
        WHERE PublishStatus = 'Online' 
        AND Language = 'en_US' 
        LIMIT 5
    ];

    String summary = '';

    for (Knowledge__kav article : articles) {
        summary += '- ' + article.Title + ': ' + article.Summary + '\n';
    }

    if (summary == null || summary == '') {
        return 'No wellness protocols found.';
    }

    return summary;
}



    private static String summarizeText(String fullText) {
        if (String.isEmpty(fullText)) {
            return 'No content available.';
        }
        if (fullText.length() > 400) {
            return fullText.substring(0, 400) + '... (summary trimmed)';
        }
        return fullText;
    }

    

    // Exception for Authentication failures
    public class AuthenticationException extends Exception {}
}