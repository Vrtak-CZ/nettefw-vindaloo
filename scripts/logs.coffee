# Description:
#   Simple store chat logs
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   None
#
# URLS:
#   None

mongoose = require 'mongoose'

generateMongoUrl = (obj) ->
	obj.hostname = obj.hostname || 'localhost'
	obj.port = obj.port || 27017
	obj.db = obj.db || 'test'
	if obj.username && obj.password
		return "mongodb://#{obj.username}:#{obj.password}@#{obj.hostname}:#{obj.port}/#{obj.db}"
	else
		return "mongodb://#{obj.hostname}:#{obj.port}/#{obj.db}"

messageSchema = new mongoose.Schema
	user: String
	text: String
	datetime:
		type: Date
		default: Date.now

messageSchema.statics.findLatests = (count = 30) ->
	@find({}).limit(count).sort '-datetime'

joinSchema = new mongoose.Schema
	user: String
	datetime:
		type: Date
		default: Date.now

leaveSchema = new mongoose.Schema
	user: String
	datetime:
		type: Date
		default: Date.now

model =
	message: mongoose.model('message', messageSchema)
	join: mongoose.model('join', joinSchema)
	leave: mongoose.model('leave', leaveSchema)

template = (data) ->
	messages = ""
	for message in data
		datetime = message.datetime;

		date = datetime.getFullYear()
		date += '-'
		month = (datetime.getMonth() + 1).toString()
		date += if month.length == 1 then "0#{month}" else month
		date += '-'
		day = datetime.getDate().toString()
		date += if day.length == 1 then "0#{day}" else day

		time = datetime.toLocaleTimeString()

		messages += "[<span date-datetime=\"#{datetime.toISOString()}\">#{date} #{time}</span>] #{message.user}: #{message.text}\n"

	"""
<html>
	<head>
		<title>Nette FW - IRC - Logs</title>
		<script src="http://code.jquery.com/jquery-1.8.1.min.js"></script>
		<script>
			formatDate = function(date) {
				var day, hours, minutes, month, seconds;
				if (typeof date !== 'object') {
					date = new Date(date);
				}
				date = new Date(date.toISOString());
				month = date.getMonth() + 1;
				if (("" + month).length < 2) {
					month = "0" + month;
				}
				day = date.getDate();
				if (("" + day).length < 2) {
					day = "0" + day;
				}
				hours = date.getHours();
				if (("" + hours).length < 2) {
					hours = "0" + hours;
				}
				minutes = date.getMinutes();
				if (("" + minutes).length < 2) {
					minutes = "0" + minutes;
				}
				seconds = date.getSeconds();
				if (("" + seconds).length < 2) {
					seconds = "0" + seconds;
				}
				return "" + (date.getFullYear()) + "-" + month + "-" + day + " " + hours + ":" + minutes + ":" + seconds;
			};
			$('date-datetime').each(function(i, el) {
				$el = $(el);
				datetime = $el.attr('date-datetime');
				$el.attr('date-datetime', formatDate(datetime));
			});
		</script>
	</head>
	<body>
		<h1>Nette FW - IRC - Logs</h1>
		<pre>#{messages}</pre>
	</body>
</html>
	"""

module.exports = (robot) ->
	if not process.env.VCAP_SERVICES?
		return

	config = JSON.parse(process.env.VCAP_SERVICES)
	mongoose.connect generateMongoUrl(config['mongodb-1.8'][0]['credentials'])

	robot.hear /.*$/i, (msg) ->
		message =
			user: msg.message.user.name
			text: msg.message.text

		# ignore topic and other messages
		if not msg.message.user.id?
			return
		else
			message.userId = msg.message.user.id

		# ignore if not set this variables
		return if not msg.message.user.room?
		return if not process.env.HUBOT_IRC_ROOMS?

		# ignore if is not in room
		return if msg.message.user.room not in process.env.HUBOT_IRC_ROOMS.split(',')

		doc = new model.message message
		do doc.save

	robot.enter (msg) ->
		return if not msg.message.user.id?

		doc = new model.join {user: msg.message.user.name}
		do doc.save

	robot.leave (msg) ->
		return if not msg.message.user.id?

		doc = new model.leave {user: msg.message.user.name}
		do doc.save

	robot.route "/", (req, res) ->
		model.message.findLatests().exec (err, messages) ->
			if err
				console.err err
				res.end 'error 500'

			res.setHeader 'content-type', 'text/html'
			res.end template messages
