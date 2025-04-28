#!/usr/bin/env python3

import os
import time
from BeatNet.BeatNet import BeatNet
FIFO_PATH = "/tmp/beatnet_fifo"

# Create FIFO if it doesn't exist
if not os.path.exists(FIFO_PATH):
    os.mkfifo(FIFO_PATH)

# Initialize BeatNet in streaming mode
estimator = BeatNet(1, mode='stream', inference_model='PF', plot=[], thread=False)

with open(FIFO_PATH, 'w') as fifo:
    for beat in estimator.process():
        # beat is [beat_time, downbeat_flag]
        # Write "beat" or "downbeat" to FIFO
        if beat[1] == 1:
            fifo.write("downbeat\n")
        else:
            fifo.write("beat\n")
        fifo.flush()
        time.sleep(0.01)