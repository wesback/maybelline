FROM python:3
ADD sendtoeh.py /
RUN apt-get update && apt-get -y install build-essential cmake && rm -rf /var/lib/apt/lists/*
RUN pip install --pre azure-eventhub
CMD [ "python", "./sendtoeh.py" ]
