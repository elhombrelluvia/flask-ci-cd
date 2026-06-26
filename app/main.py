from flask import Flask,jsonify
from requests import get

# Initialize the Flask application
app = Flask(__name__)

# Define the route for the home page
@app.route('/')
def home():
    try:
        return jsonify({"status": "ok","code":200,"message":"Hola MUNDO!"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
# Run the local development server
if __name__ == '__main__':
    app.run(debug=True)
