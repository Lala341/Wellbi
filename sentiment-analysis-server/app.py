from flask import Flask, request, jsonify
from textblob import TextBlob
import os

app = Flask(__name__)

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.get_json()
    text = data.get('text', '')
    blob = TextBlob(text)
    polarity = blob.sentiment.polarity
    sentiment = 'positive' if polarity > 0 else 'negative' if polarity < 0 else 'neutral'
    return jsonify({'sentiment': sentiment, 'polarity': polarity})

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
