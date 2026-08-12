class AiService {
  Future<Map<String, dynamic>> getRecommendation() async {
    // Simulate network delay to mimic the Python server processing
    await Future.delayed(const Duration(seconds: 2));

    // Return mock data for the XAI guidance
    return {
      "recommendation": "Invest LKR 25,000 in Treasury Bonds",
      "confidence": 0.89, // 89% confidence
      "factors": [
        {
          "name": "Market Sentiment", 
          "value": "Negative", 
          "impact": "positive", 
          "reason": "Treasury bonds are safer during current stock market downturns."
        },
        {
          "name": "Your Risk Profile", 
          "value": "Conservative", 
          "impact": "positive", 
          "reason": "Matches your preference for low-risk, guaranteed return assets."
        },
        {
          "name": "Predicted Next Month Expense", 
          "value": "High", 
          "impact": "negative", 
          "reason": "You have high projected expenses next month, slightly limiting ideal investment capital."
        },
      ]
    };
  }
}
