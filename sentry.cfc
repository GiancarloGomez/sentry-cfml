/**
* Sentry SDK for ColdFusion
*
* This CFC is based on the original raven-cfml client developed
* by jmacul2 (https://github.com/jmacul2/raven-cfml)
*
* The CFC has been updated to full script with support to instantiate
* and use as a singleton. Also some functions have been rewritten to
* use either new ColdFusion language enhancements or existing ACF functions.
*
* This CFC is for use with ColdFusion 2016 testing on earlier
* versions of ColdFusion has not been done.
*
* Sentry SDK Documentation
* https://docs.sentry.io/clientdev/
*
*/
component displayname="sentry" output="false" accessors="true"{

	property name="environment" type="string";
	property name="levels" type="array";
	property name="logger" type="string" default="sentry-cfml";
	property name="platform" type="string" default="cfml";
	property name="release" type="string";
	property name="privateKey";
	property name="projectID";
	property name="publicKey";
	property name="version" type="string" default="1.0.0" hint="sentry-cfml version";
	property name="sentryUrl" type="string" default="https://sentry.io";
	property name="sentryVersion" type="string" default="7";
	property name="serverName" type="string";

	/**
	* @release The release version of the application.
	* @environment The environment name, such as ‘production’ or ‘staging’.
	* @DSN A DSN string to connect to Sentry's API, the values can also be passed as individual arguments
	* @publicKey The Public Key for your Sentry Account
	* @privateKey The Private Key for your Sentry Account
	* @projectID The ID Sentry Project
	* @sentryUrl The Sentry API url which defaults to https://sentry.io
	* @serverName The name of the server, defaults to cgi.server_name
	*/
	function init(
		required string release,
		required string environment,
		string DSN,
		string publicKey,
		string privateKey,
		numeric projectID,
		string sentryUrl,
		string serverName = cgi.server_name
	) {
		// set keys via DSN or arguments
		if (structKeyExists(arguments,"DSN") && len(trim(arguments.DSN))){
			parseDSN(arguments.DSN);
		}
		else if (
			( structKeyExists(arguments,"publicKey") && len(trim(arguments.publicKey)) ) &&
			( structKeyExists(arguments,"privateKey") && len(trim(arguments.privateKey)) ) &&
			( structKeyExists(arguments,"projectID") && len(trim(arguments.projectID)) )
		) {
			setPublicKey(arguments.publicKey);
			setPrivateKey(arguments.privateKey);
			setProjectID(arguments.projectID);
		}
		else {
			throw(message = "You must pass in a valid DSN or Project Keys and ID to instantiate the Sentry CFML Client.");
		}
		// set defaults
		setLevels(["fatal","error","warning","info","debug"]);
		// set required
		setEnvironment(arguments.environment);
		setRelease(arguments.release);
		// set optional
		setServerName(arguments.serverName);
		// overwrite defaults
		if ( structKeyExists(arguments,"sentryUrl") && len(trim(arguments.sentryUrl)) )
			setSentryUrl(arguments.sentryUrl);
	}

	/**
	* Parses a valid Legacy Sentry DSN
	* {PROTOCOL}://{PUBLIC_KEY}:{SECRET_KEY}@{HOST}/{PATH}{PROJECT_ID}
	* https://docs.sentry.io/clientdev/overview/#parsing-the-dsn
	*/
	private void function parseDSN(required string DSN) {
		var pattern = "^(?:(\w+):)?\/\/(\w+):(\w+)?@([\w\.-]+)\/(.*)";
		var result 	= reFind(pattern,arguments.DSN,1,true);
		var segments = [];

		for(var i=2; i LTE ArrayLen(result.pos); i++){
			segments.append(mid(arguments.DSN, result.pos[i], result.len[i]));
		}		

		if (compare(segments.len(),5)){
			throw(message="Error parsing DSN");
		}


		// set the properties
		else {
			setSentryUrl(segments[1] & "://" & segments[4]);
			setPublicKey(segments[2]);
			setPrivateKey(segments[3]);
			setProjectID(segments[5]);
		}
	}

	/**
	* Validates that a correct level was set for a capture
	* The allowed levels are:
	* 	"fatal","error","warning","info","debug"
	*/
	private void function validateLevel(required string level) {
		if(!getLevels().find(arguments.level))
			throw(message="Error Type must be one of the following : " & getLevels().toString());
	}

	/**
	* Capture a message
	* https://docs.sentry.io/clientdev/interfaces/message/
	*
	* @message the raw message string ( max length of 1000 characters )
	* @level The level to log
	* @path The path to the script currently executing
	* @params an optional list of formatting parameters
	* @cgiVars Parameters to send to Sentry, defaults to the CGI Scope
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface
	*/
	public any function captureMessage(
		required string message,
		string level = "info",
		string path = "",
		array params,
		any cgiVars = cgi,
		boolean useThread = false,
		struct userInfo = {}
	) {
		var sentryMessage = {};

		validateLevel(arguments.level);

		if (len(trim(arguments.message)) > 1000)
			arguments.message = left(arguments.message,997) & "...";

		sentryMessage = {
			"message" : arguments.message,
			"level" : arguments.level,
			"sentry.interfaces.Message" : {
				"message" : arguments.message
			}
		};

		if(structKeyExists(arguments,"params"))
			sentryMessage["sentry.interfaces.Message"]["params"] = arguments.params;

		capture(
			captureStruct 	: sentryMessage,
			path 			: arguments.path,
			cgiVars 		: arguments.cgiVars,
			useThread 		: arguments.useThread,
			userInfo 		: arguments.userInfo
		);
	}

	/**
	* @exception The exception
	* @level The level to log
	* @path The path to the script currently executing
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface
	* @showJavaStackTrace Passes Java Stack Trace as a string to the extra attribute
	* @oneLineStackTrace Set to true to render only 1 tag context. This is not the Java Stack Trace this is simply for the code output in Sentry
	* @removeTabsOnJavaStackTrace Removes the tab on the child lines in the Stack Trace
	* @additionalData Additional metadata to store with the event - passed into the extra attribute
	* @cgiVars Parameters to send to Sentry, defaults to the CGI Scope
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface	*
	*/
	public any function captureException(
		required any exception,
		string level = "error",
		string path = "",
		boolean oneLineStackTrace = false,
		boolean showJavaStackTrace = false,
		boolean removeTabsOnJavaStackTrace = false,
		any additionalData,
		any cgiVars = cgi,
		boolean useThread = false,
		struct userInfo = {}
	) {
		var sentryException 		= {};
		var sentryExceptionExtra 	= {};
		var file 					= "";
		var fileArray 				= "";
		var currentTemplate 		= "";
		var tagContext 				= arguments.exception.TagContext;
		var i 						= 1;
		var st 						= "";

		validateLevel(arguments.level);

		/*
		* CORE AND OPTIONAL ATTRIBUTES
		* https://docs.sentry.io/clientdev/attributes/
		*/
		sentryException = {
			"message" 	: arguments.exception.message & " " & arguments.exception.detail,
			"level" 	: arguments.level,
			"culprit" 	: arguments.exception.message
		};

		if (arguments.showJavaStackTrace){
			st = reReplace(arguments.exception.StackTrace, "\r", "", "All");
			if (arguments.removeTabsOnJavaStackTrace)
				st = reReplace(st, "\t", "", "All");
			sentryExceptionExtra["Java StackTrace"] = listToArray(st,chr(10));
		}

		if (!isNull(arguments.additionalData))
			sentryExceptionExtra["Additional Data"] = arguments.additionalData;

		if (structCount(sentryExceptionExtra))
			sentryException["extra"] = sentryExceptionExtra;

		/*
		* EXCEPTION INTERFACE
		* https://docs.sentry.io/clientdev/interfaces/exception/
		*/
		sentryException["sentry.interfaces.Exception"] = {
			"value" : arguments.exception.message & " " & arguments.exception.detail,
			"type" 	: arguments.exception.type & " Error"
		};

		/*
		* STACKTRACE INTERFACE
		* https://docs.sentry.io/clientdev/interfaces/stacktrace/
		*/
		if (arguments.oneLineStackTrace)
			tagContext = [tagContext[1]];

		sentryException["sentry.interfaces.Stacktrace"] = {
			"frames" : []
		};

		for (i=1; i <= arrayLen(tagContext); i++) {
			if (compareNoCase(tagContext[i]["TEMPLATE"],currentTemplate)) {
				fileArray = [];
				if (fileExists(tagContext[i]["TEMPLATE"])) {
					file = fileOpen(tagContext[i]["TEMPLATE"], "read");
					while (!fileIsEOF(file))
						arrayAppend(fileArray, fileReadLine(file));
					fileClose(file);
				}
				currentTemplate = tagContext[i]["TEMPLATE"];
			}

			sentryException["sentry.interfaces.Stacktrace"]["frames"][i] = {
				"abs_path" 	= tagContext[i]["TEMPLATE"],
				"filename" 	= tagContext[i]["TEMPLATE"],
				"lineno" 	= tagContext[i]["LINE"]
			};

			// The name of the function being called
			if (i == 1)
				sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["function"] = "column #tagContext[i]["COLUMN"]#";
			else
				sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["function"] = tagContext[i]["ID"];

			// for source code rendering
			sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["pre_context"] = [];
			if (tagContext[i]["LINE"]-3 >= 1)
				sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["pre_context"][1] = fileArray[tagContext[i]["LINE"]-3];
			if (tagContext[i]["LINE"]-2 >= 1)
				sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["pre_context"][1] = fileArray[tagContext[i]["LINE"]-2];
			if (tagContext[i]["LINE"]-1 >= 1)
				sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["pre_context"][2] = fileArray[tagContext[i]["LINE"]-1];
			if (arrayLen(fileArray))
				sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["context_line"] = fileArray[tagContext[i]["LINE"]];

			sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["post_context"] = [];
			if (arrayLen(fileArray) >= tagContext[i]["LINE"]+1)
				sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["post_context"][1] = fileArray[tagContext[i]["LINE"]+1];
			if (arrayLen(fileArray) >= tagContext[i]["LINE"]+2)
				sentryException["sentry.interfaces.Stacktrace"]["frames"][i]["post_context"][2] = fileArray[tagContext[i]["LINE"]+2];
		}

		capture(
			captureStruct 	: sentryException,
			path 			: arguments.path,
			cgiVars 		: arguments.cgiVars,
			useThread 		: arguments.useThread,
			userInfo 		: arguments.userInfo
		);
	}

	/**
	* Prepare message to post to Sentry
	*
	* @captureStruct The struct we are passing to Sentry
	* @cgiVars Parameters to send to Sentry, defaults to the CGI Scope
	* @path The path to the script currently executing
	* @useThread Option to send post to Sentry in its own thread
	* @userInfo Optional Struct that gets passed to the Sentry User Interface
	*/
	public void function capture(
		required any captureStruct,
		any cgiVars = cgi,
		string path = "",
		boolean useThread = false,
		struct userInfo = {}
	) {
		var jsonCapture 	= "";
		var signature 		= "";
		var header 			= "";
		var timeVars 		= getTimeVars();
		var httpRequestData = getHTTPRequestData();

		// Add global metadata
		arguments.captureStruct["event_id"] 	= lcase(replace(createUUID(), "-", "", "all"));
		arguments.captureStruct["timestamp"] 	= timeVars.timeStamp;
		arguments.captureStruct["logger"] 		= getLogger();
		arguments.captureStruct["project"] 		= getProjectID();
		arguments.captureStruct["server_name"] 	= getServerName();
		arguments.captureStruct["platform"] 	= getPlatform();
		arguments.captureStruct["release"] 		= getRelease();
		arguments.captureStruct["environment"] 	= getEnvironment();

		/*
		* User interface
		* https://docs.sentry.io/clientdev/interfaces/user/
		*
		* {
		*     "id" : "unique_id"
		*     "email" : "my_user"
		*     "ip_address" : "foo@example.com"
		*     "username" : ""127.0.0.1"
		* }
		*
		* All other keys are stored as extra information but not specifically processed by sentry.
		*/
		if (!structIsEmpty(arguments.userInfo))
			arguments.captureStruct["sentry.interfaces.User"] = arguments.userInfo;

		// Prepare path for HTTP Interface
		arguments.path = trim(arguments.path);
		if (!len(arguments.path))
			arguments.path = "http" & (arguments.cgiVars.server_port_secure ? "s" : "") & "://" & arguments.cgiVars.server_name & arguments.cgiVars.script_name;

		// HTTP interface
		// https://docs.sentry.io/clientdev/interfaces/http/
		arguments.captureStruct["sentry.interfaces.Http"] = {
			"sessions" 		: (isDefined('session'))?session:{},
			"url" 			: arguments.path,
			"method" 		: arguments.cgiVars.request_method,
			"data" 			: form,
			"query_string" 	: arguments.cgiVars.query_string,
			"cookies" 		: cookie,
			"env" 			: arguments.cgiVars,
			"headers" 		: httpRequestData.headers
		};

		// encode data
		jsonCapture = jsonEncode(arguments.captureStruct);
		// prepare header
		header = "Sentry sentry_version=#getSentryVersion()#, sentry_timestamp=#timeVars.time#, sentry_key=#getPublicKey()#, sentry_secret=#getPrivateKey()#, sentry_client=#getLogger()#/#getVersion()#";
		// post message
		if (arguments.useThread){
			cfthread(
				action 			= "run",
				name 			= "sentry-thread-" & createUUID(),
				header   		= header,
				jsonCapture 	= jsonCapture
			){
				post(header,jsonCapture);
			}
		} else {
			post(header,jsonCapture);
		}
	}

	/**
	* Post message to Sentry
	*/
	private void function post(
		required string header,
		required string json
	) {
		var http = {};
		// send to sentry via REST API Call
		cfhttp(
			url 	: getSentryUrl() & "/api/store/",
			method 	: "post",
			timeout : "2",
			result 	: "http"
		){
			cfhttpparam(type="header",name="X-Sentry-Auth",value=arguments.header);
			cfhttpparam(type="body",value=arguments.json);
		}

		// TODO : Honor Sentry’s HTTP 429 Retry-After header any other errors
		if (!find("200",http.statuscode)){
		}
	}

	/**
	* Custom Serializer that converts data from CF to JSON format
	* in a better way
	*/
	private string function jsonEncode(
		required any data,
		string queryFormat = "query",
		string queryKeyCase = "lower",
		boolean stringNumbers = false,
		boolean formatDates = false,
		string columnListFormat = "string"
	) {
		var jsonString 		= "";
		var tempVal 		= "";
		var arKeys 			= "";
		var colPos 			= 1;
		var i 				= 1;
		var column 			= "";
		var row 			= {};
		var datakey 		= "";
		var recordcountkey 	= "";
		var columnlist 		= "";
		var columnlistkey 	= "";
		var dJSONString 	= "";
		var escapeToVals 	= "\\,\"",\/,\b,\t,\n,\f,\r";
		var escapeVals 		= "\,"",/,#Chr(8)#,#Chr(9)#,#Chr(10)#,#Chr(12)#,#Chr(13)#";
		var _data 			= arguments.data;
		var rtn 			= "";

		// BOOLEAN
		if (isBoolean(_data) && !isNumeric(_data) && !listFindNoCase("Yes,No", _data)){
			rtn = lCase(toString(_data));
		}
		// NUMBER
		else if (!stringNumbers && isNumeric(_data) && !reFind("^0+[^\.]",_data)){
			rtn = toString(_data);
		}
		// DATE
		else if (isDate(_data) && arguments.formatDates){
			rtn = '"' & dateTimeFormat(_data, "medium") & '"';
		}
		// STRING
		else if (isSimpleValue(_data)){
			rtn = '"' & replaceList(_data, escapeVals, escapeToVals) & '"';
		}
		// ARRAY
		else if (isArray(_data)){
			dJSONString = createObject("java","java.lang.StringBuffer").init("");
			for (i = 1; i <= arrayLen(_data); i++){
				if (arrayIsDefined(_data,i))
					tempVal = jsonEncode( _data[i], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat );
				else
					tempVal = jsonEncode( "null", arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat );

				if (len(dJSONString.toString()))
					dJSONString.append("," & tempVal);
				else
					dJSONString.append(tempVal);
			}
			rtn = "[" & dJSONString.toString() & "]";
		}
		// STRUCT
		else if (isStruct(_data)){
			dJSONString = createObject("java","java.lang.StringBuffer").init("");
			arKeys 		= structKeyArray(_data);
			for (i = 1; i <= arrayLen(arKeys); i++){
				tempVal = jsonEncode( _data[ arKeys[i] ], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat );

				if (len(dJSONString.toString()))
					dJSONString.append(',"' & arKeys[i] & '":' & tempVal);
				else
					dJSONString.append('"' & arKeys[i] & '":' & tempVal);
			}
			rtn = "{" & dJSONString.toString() & "}";
		}
		//  QUERY
		else if (isQuery(_data)){
			dJSONString = createObject("java","java.lang.StringBuffer").init("");

			// Add query meta data
			if (!compareNoCase(arguments.queryKeyCase,"lower")){
				recordcountKey 	= "recordcount";
				columnlistKey 	= "columnlist";
				columnlist 		= lCase(_data.columnlist);
				dataKey 		= "data";
			} else {
				recordcountKey 	= "RECORDCOUNT";
				columnlistKey 	= "COLUMNLIST";
				columnlist 		= _data.columnlist;
				dataKey 		= "DATA";
			}

			dJSONString.append('"#recordcountKey#":' & _data.recordcount);

			if (!compareNoCase(arguments.columnListFormat,"array")){
				columnlist = "[" & ListQualify(columnlist, '"') & "]";
				dJSONString.append(',"#columnlistKey#":' & columnlist);
			} else {
				dJSONString.append(',"#columnlistKey#":"' & columnlist & '"');
			}

			dJSONString.append(',"#dataKey#":');

			// Make query a structure of arrays
			if (!compareNoCase(arguments.queryFormat,"query")){
				dJSONString.append("{");
				colPos = 1;

				for (column in _data.columnlist){
					if (colPos > 1)
						dJSONString.append(",");
					if (!compareNoCase(arguments.queryKeyCase,"lower"))
						column = lCase(column);

					dJSONString.append('"' & column & '":[');
					i = 1;
					for (row in _data){
						if (i > 1)
							dJSONString.append(",");
						tempVal = jsonEncode( row[column], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat );
						dJSONString.append(tempVal);
						i++;
					}
					dJSONString.append("]");
					colPos++;
				}

				dJSONString.append("}");
			}
			// Make query an array of structures
			else {
				dJSONString.append("[");
				i = 1;

				for (row in _data){
					if (i > 1)
						dJSONString.append(",");
					dJSONString.append("{");
					colPos = 1;

					for (column in _data.columnlist){
						if (colPos > 1)
							dJSONString.append(",");
						if (!compareNoCase(arguments.queryKeyCase,"lower"))
							column = lCase(column);
						tempVal = jsonEncode( row[column], arguments.queryFormat, arguments.queryKeyCase, arguments.stringNumbers, arguments.formatDates, arguments.columnListFormat );
						dJSONString.append('"' & column & '":' & tempVal);
						colPos++;
					}
					dJSONString.append("}");
				}
				dJSONString.append("]");
			}
			// Wrap all query data into an object
			rtn = "{" & dJSONString.toString() & "}";
		}
		// FUNCTION
		else if (listFindNoCase(StructKeyList(getFunctionList()), _data) || isCustomFunction(_data)){
			rtn = '"' & "function()" & '"';
		}
		// UNKNOWN OBJECT TYPE
		else {
			rtn = '"' & "unknown-obj" & '"';
		}

		return rtn;
	}

	/**
	* Get UTC time values
	*/
	private struct function getTimeVars() {
		var time 		= now();
		var timeVars 	= {
			"time" 			: time.getTime(),
			"utcNowTime" 	: dateConvert("Local2UTC", time)
		};
		timeVars.timeStamp = dateformat(timeVars.utcNowTime, "yyyy-mm-dd") & "T" & timeFormat(timeVars.utcNowTime, "HH:mm:ss");
		return timeVars;
	}
}
