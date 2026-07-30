import json
import logging
import time
from flask import Flask, request, Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

REQUEST_COUNTER = Counter(
    'app_requests_total',
    'Total number of requests',
    ['method', 'endpoint']
)
ERROR_COUNTER = Counter(
    'app_errors_total',
    'Total number of errors'
)


class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        })


handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger = logging.getLogger("app")
logger.setLevel(logging.INFO)
logger.addHandler(handler)
logger.propagate = False


@app.before_request
def log_request():
    logger.info(f"{request.method} {request.path} - incoming request")


@app.route("/")
def index():
    REQUEST_COUNTER.labels(method="GET", endpoint="/").inc()
    logger.info("Handled GET /")
    return {"status": "ok", "message": "App is running"}, 200


@app.route("/health")
def health():
    REQUEST_COUNTER.labels(method="GET", endpoint="/health").inc()
    return {"status": "healthy"}, 200


@app.route("/error")
def trigger_error():
    REQUEST_COUNTER.labels(method="GET", endpoint="/error").inc()
    ERROR_COUNTER.inc()
    logger.error("Simulated error triggered")
    return {"status": "error", "message": "Simulated error"}, 500


@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
