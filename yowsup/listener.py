#! /usr/bin/python

### NOTICE ###

# This file is heavliy based on the src/Examples/ListenerClient.py file. So you can always find an "original" version there.
# Also, this comment was so helpful regarding media upload:
# https://github.com/tgalal/yowsup/issues/178#issuecomment-33261219

# Install dependencies: pip install -r requirements.txt
import os, sys, threading, time, datetime, argparse, base64, hashlib, requests, json, yaml
parentdir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.sys.path.insert(0,parentdir)
from Yowsup.connectionmanager import YowsupConnectionManager
from Yowsup.Media.downloader import MediaDownloader
from Yowsup.Media.uploader import MediaUploader

class WhatsappListenerClient:

	def __init__(self, keepAlive = False, sendReceipts = False):
		self.sendReceipts = sendReceipts
		self.keepAlive = keepAlive

		connectionManager = YowsupConnectionManager()
		connectionManager.setAutoPong(keepAlive)

		self.signalsInterface = connectionManager.getSignalsInterface()
		self.methodsInterface = connectionManager.getMethodsInterface()
		self.cm = connectionManager

		self.signalsInterface.registerListener("auth_success", self.onAuthSuccess)
		self.signalsInterface.registerListener("auth_fail", self.onAuthFailed)
		self.signalsInterface.registerListener("message_received", self.onMessageReceived)
		self.signalsInterface.registerListener("disconnected", self.onDisconnected)
		self.signalsInterface.registerListener("media_uploadRequestSuccess", self.onmedia_uploadRequestSuccess)
		self.signalsInterface.registerListener("media_uploadRequestFailed", self.onmedia_uploadRequestFailed)
		self.signalsInterface.registerListener("media_uploadRequestDuplicate", self.onmedia_uploadRequestDuplicate)

	def login(self, jid, password):
		self.jid = jid
		processed_password = base64.b64decode(bytes(password.encode('utf-8')))
		self.methodsInterface.call("auth_login", (jid, processed_password))

		while True:
			# Do some processing to check whether we should terminate or not
			time.sleep(1.0)

	def onAuthSuccess(self, username):
		self.connectedSince = datetime.datetime.now()
		self.methodsInterface.call("ready")

	def onAuthFailed(self, username, err):
		print("Authenticating %s Failed, Error: " %(username, str(err)))
		exit()

	def onDisconnected(self, reason):
		print("Connected Since: " + str(self.connectedSince) + " | Duration: " + str(datetime.datetime.now() - self.connectedSince))
		print("Disconnected because %s" %reason)
		exit()

	def onmedia_uploadRequestSuccess(self,_hash, url, resumeFrom):
		self.uploadImage(url)

	def onmedia_uploadRequestFailed(self,_hash):
		_hash # This is a stub just to fill in the function
		# print("Request Fail: hash: %s"%(_hash))

	def onmedia_uploadRequestDuplicate(self,_hash, url):
		self.doSendImage(url)

	def uploadImage(self, url):
		uploader = MediaUploader(self.jid, self.username, self.onUploadSuccess, self.onUploadError, self.onProgressUpdated)
		uploader.upload(self.path,url)

	def onUploadSuccess(self, url):
		self.doSendImage(url)

	def onUploadError(self):
		stub = "stup instruction"

	def onProgressUpdated(self, progress):
		stub = "stub"

	def doSendImage(self, url):
		statinfo = os.stat(self.path)
		name=os.path.basename(self.path)
		msgId = self.methodsInterface.call("message_imageSend", (self.jid, url, name,str(statinfo.st_size), "yes"))
		self.sentCache[msgId] = [int(time.time()), self.path]

	def onMessageReceived(self, messageId, jid, messageContent, timestamp, wantsReceipt, pushName, isBroadCast):

		payload={'jid': jid, 'content': messageContent}
		# r = requests.get('http://localhost:4567/', params=payload)
		r = requests.post('http://localhost:4567/', data=payload)
		res = r.json()
		res['type'] = res['type'].encode('utf-8')
		res['content'] = res['content'].encode('utf-8')
		if res['type'] == b'text':
			self.methodsInterface.call("message_send", (jid, res['content']))
		elif res['type'] == b'image':
			stub = 'stub'
			
	def sendImage(self,jid,path):

		fp = open(path, 'rb')

		try:
			sha1 = hashlib.sha256()
			sha1.update(fp.read())
			hsh = base64.b64encode(sha1.digest())
			mtype = "image"
			self.methodsInterface.call("media_requestUpload", (hsh, mtype, os.path.getsize(self.path)))

		finally:
			fp.close()

		# Code here for requesting and responding
		
#		if wantsReceipt and self.sendReceipts:
#			self.methodsInterface.call("message_ack", (jid, messageId))

# End of WhatsappListenerClient Class

# Program code goes below

credentials = yaml.load(open(os.path.abspath(os.path.dirname(os.path.realpath(__file__)) + '/../config/credentials.yml'),'r'))

# Parsing command line arguments is no longer needed because we will not pass password
# as command line agrument since that generates security issues. 
# We are now reading credentials from yaml file as shown in the code above,
# an alternative approach is to set them as environment vairables when executing
# this script. Example: $ PASSWORD=WHATEVER python this_script_file.py

#parser = argparse.ArgumentParser(description='Yowsup Middleware Command Line Options')
#parser.add_argument("--jid", help='The Phone Number with CC but without + or 00')
#parser.add_argument("--pw", help='The Password')
#args = vars(parser.parse_args())

wa = WhatsappListenerClient(True, True)
wa.login(credentials['phone'], credentials['password'])
