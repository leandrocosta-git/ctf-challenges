FROM python:3.11-slim

WORKDIR /app

COPY server.py .

ENV PORT=1337

EXPOSE ${PORT}

CMD ["python", "server.py"]
