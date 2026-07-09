FROM python:3.12-slim

WORKDIR /app
COPY server.py /app/server.py

ENV ACTION_DB_PATH=/data/actions.db
EXPOSE 3002

CMD ["python", "/app/server.py"]
