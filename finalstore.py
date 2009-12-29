#!/usr/bin/env python -Wall
# This is only run from launchd
# @author Filipp Lepalaan <filipp@tvtools.fi>
# @updated 28.12.2009
# @created 09.12.2009

import sys, time, os, glob, traceback
from config import *
from subprocess import *

"""
	Time saver for posting Growl notifications
"""
def growl(str):
	icon = sys.path[0] + "/fcs.png"
	cmd = ["/usr/local/bin/growlnotify", "-s", "-m", str, "--image", icon]
	try:
		Popen(cmd, shell=False).communicate()
	except Exception, e:
		print "Failed to initialize Growl"

"""
	Forward the files to awcli
	Wait for presstore to finish
"""
def doit(task, f, ap):
	assets = []
	# Gather up all the assets marked for processing
	for l in f.readlines():
		s = l.strip()
		print "Processing " + l
		if not s: break
		assets.append(s)
	
	# Get rid of these as soon as possible
	f.close()
	os.unlink(f.name)
	
	awcli = sys.path[0] + "/awcli.sh"
	r = Popen([awcli, task, ap] + assets, stdout=PIPE, shell=False).communicate()
	jid = r[0].strip()
	
	if jid == "-1":
		growl("Asset already archived")
		sys.exit(0)
	
	print task + " job ID is " + jid
	ac = len(assets)
	sfx = "s"
	if ac == 1 : sfx = ""
	growl("Started %s job %s (%d asset%s)" % (task, jid, ac, sfx))
	
	# Wait for the job to finish
	sock = "awsock:/%s:%s@%s:%s" % (AWUSER, AWPASSWORD, AWHOST, AWPORT)
	cmd = "Job %s status" % (jid)
	
	while True:
		try:
			check = Popen([NC, "-s", sock , "-c", cmd], stdout=PIPE, shell=False)
			s = check.communicate()[0].strip()
		except Exception, e:
			print traceback.print_exc(file=sys.stdout)
		if s == "completed" or s == "cancelled" : break
		time.sleep(2)
	
	growl("%s %s job %s" % (s.capitalize(), task, jid))

# DO IT
try:
	for f in glob.glob("/tmp/finalstore/archive/*.txt"):
		d = open(f, "r")
		doit("archive", d, ARCHIVEPLAN)
except Exception, e:
	print "Nothing to archive"

try:
	for f in glob.glob("/tmp/finalstore/restore/*.txt"):
		d = open(f, "r")
		doit("restore", d, ARCHIVEPLAN)
except Exception, e:
	print "Nothing ro restore"

# To not upset launchd
time.sleep(5)
sys.exit(0)
