# **Wellbi: A Smart Assistant for Employee Productivity & Well-being**

**Wellbi** is a smart assistant built with Salesforce Agentforce to automate task management, wellness suggestions, and event scheduling for employees. By analyzing workload, mood, and business protocols, Wellbi helps employees stay balanced and productive.

---

### **Features**

1. **Task Management & Prioritization**:
   - Suggests task reassignment, deferral, and prioritization to balance workload.
   - Helps in rescheduling non-critical meetings to clear overload.
   - Provides daily task summaries to keep users prepared and focused.

2. **Wellness Suggestions**:
   - Triggers personalized wellness messages based on the employee's workload and mood.
   - Provides reminders for breaks, self-care, or time-off.
   - Analyzes sentiment from user input to recommend appropriate wellness actions.

---

### **Metadata Retrieved**

Here are the metadata components that were retrieved as part of the project:

- **Apex Classes**:
  - `SmartDayPlanner.cls`
  - `SmartDayPlannerActions.cls`
  - `WellnessSuggestionAgent.cls`

- **Custom Fields**:
  - `Knowledge__kav.Answer_c__c`
  - `Knowledge__kav.File__c`

- **Custom Object**:
  - `Knowledge__kav`

- **Flows**:
  - `Get_User_Tasks.flow`
  - `Identify_User_ID_by_Full_Name.flow`

- **List Views**:
  - `Knowledge__kav.archived_articles`
  - `Knowledge__kav.draft_articles`
  - `Knowledge__kav.published_articles`

- **Record Type**:
  - `Knowledge__kav.Protocols`

---

### **External Sentiment Analysis Server**

The **sentiment analysis** functionality of Wellbi is powered by a custom server deployed on **Heroku**. This server is used to analyze the sentiment of the user's text input and provide personalized wellness recommendations based on emotional cues.

- **Server URL**: [Sentiment Analysis Server](https://your-heroku-app-url)
- **Technology**: Node.js, Sentiment Analysis Library
- **Purpose**: Analyze user mood based on the text they enter, determine whether the mood is positive, negative, or neutral, and trigger wellness actions based on the result.



### **How to Use Wellbi**

1. **Set Up Salesforce**:
   - Deploy the metadata from the `force-app` folder to your Salesforce org.
   - Ensure the custom objects, fields, and flows are set up correctly.

2. **Deploy Sentiment Analysis Server**:
   - The **sentiment-analysis-server** is deployed on Heroku. To get it running:
     - Go to your Heroku dashboard and find the sentiment analysis app.
     - Deploy the app using the Heroku CLI or the web interface.

3. **Integrate Sentiment Analysis with Salesforce**:
   - Modify your flows or Apex code to call the Heroku sentiment analysis API and send user input for mood analysis.
   - Based on the result, trigger wellness suggestions or actions.



### **Additional Notes**

- Ensure that you have the correct permissions to access and deploy metadata in your Salesforce org.
- The sentiment analysis server on Heroku uses a basic text analysis model; feel free to expand or improve it with more advanced sentiment models.
- The project relies on Salesforce's **Agentforce** capabilities for task management and well-being suggestions.



