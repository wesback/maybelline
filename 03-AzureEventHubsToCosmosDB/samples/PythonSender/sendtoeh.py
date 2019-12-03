import time
import os
import random
import json
from datetime import datetime
from azure.eventhub import EventHubClient, EventData, EventHubSharedKeyCredential


artist  = ['Metallica', 'Led Zeppelin', 'Queen', 'Jimi Hendrix', 'Slayer', 'Pennywise', 'Joe Satriani', 'Steve Vai', 'Joe Bonamassa', 'Stevie Ray Vaughan', 'Whitesnake', 'KaAtaKilla']
user = ['Wesley', 'Bart', 'Jakub', 'Gitte', 'Kristof', 'Satya', 'Jan', 'Rimma']

HOSTNAME = os.environ['EVENT_HUB_HOSTNAME']  # <mynamespace>.servicebus.windows.net
EVENT_HUB = os.environ['EVENT_HUB_NAME']
USER = os.environ['EVENT_HUB_SAS_POLICY']
KEY = os.environ['EVENT_HUB_SAS_KEY']
REPEATS = os.environ['REPEATS']

client = EventHubClient(host=HOSTNAME, event_hub_path=EVENT_HUB, credential=EventHubSharedKeyCredential(USER, KEY),
                        network_tracing=False)
producer = client.create_producer(partition_id="0")

start_time = time.time()
with producer:
    for i in range(int(REPEATS)):
        randomArtist = random.choice(artist)
        randomUser = random.choice(user)
        dt = datetime.now()

        msg = {
        "artist": randomArtist,
        "user": randomUser,
        "timestamp": dt.strftime("%Y-%m-%d, %H:%M:%S")
        }

        jsonMsg = json.dumps(msg)
     
        ed = EventData(jsonMsg)
        print("Sending message:" + jsonMsg)
        producer.send(ed)
print("Sent " + REPEATS + " messages in {} seconds".format(time.time() - start_time))
