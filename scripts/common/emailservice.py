#!/bin/bash
# Kalum Umesh

import json
import urllib2
import sys
import os
import datetime
import logging
import logging.handlers as handlers
import time
import requests

sys.path.append(os.environ['DEV_OPS_HOME']+'/config')

import config

